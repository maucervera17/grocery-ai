import { z } from "zod";
import { productPrices } from "./product-prices.js";
import {
  ScrapedListing,
  type SearchInput,
  type Response,
  type RawListing,
  type Failure,
  type Offer,
  type ScrapeQuery,
} from "../contracts/schema.js";
import type { ListingRepository } from "./repository.js";
import type { Scraper } from "../scrapers/firecrawl.js";
import { RETAILERS } from "../scrapers/retailers.js";
import { DemoDraftAgent, applyChanges, type DraftAgent } from "./agent.js";
import { matches } from "./normalize.js";
import { planBasket } from "./planner.js";
import { bounded } from "./deadline.js";
export type Options = {
  mode: "demo" | "live";
  fixtures: RawListing[];
  scraper?: Scraper;
  repository?: ListingRepository;
  agent?: DraftAgent;
  timeoutMs?: number;
  ttlMs?: number;
};
export function failure(
  code: string,
  message: string,
  id: string | null = null,
  retryable = false,
): Failure {
  return { code, message, client_item_id: id, retryable };
}
export function createSearch(options: Options) {
  return async (input: SearchInput): Promise<Response> => {
    const signal = AbortSignal.timeout(options.timeoutMs ?? 90000),
      errors: Failure[] = [];
    if (input.action === "product_prices")
      return productPrices(input, options, signal);
    if (input.action === "update_draft") {
      const agent =
        options.agent ??
        (options.mode === "demo" ? new DemoDraftAgent() : undefined);
      if (!agent)
        return {
          reply: "Configura el agente de IA.",
          status: "error",
          draft_items: input.items,
          plan: null,
          errors: [
            failure(
              "AGENT_NOT_CONFIGURED",
              "Configura ANTHROPIC_API_KEY y CLAUDE_MODEL, o AI_GATEWAY_API_KEY y AGENT_MODEL.",
            ),
          ],
        };
      try {
        const change = applyChanges(
          input.items,
          await bounded(
            () => agent.interpret(input.message, input.items, signal),
            signal,
          ),
        );
        return {
          reply:
            change.clarification ??
            "Borrador actualizado. Revisa productos, cantidades y unidades antes de comparar.",
          status: change.clarification ? "partial" : "complete",
          draft_items: change.items,
          plan: null,
          errors: change.clarification
            ? [failure("CLARIFICATION_REQUIRED", change.clarification)]
            : [],
        };
      } catch {
        return {
          reply:
            "No pude actualizar el borrador; se conserva la lista original.",
          status: "error",
          draft_items: input.items,
          plan: null,
          errors: [
            failure(
              "AGENT_FAILED",
              "La interpretación falló o excedió el tiempo disponible.",
              null,
              true,
            ),
          ],
        };
      }
    }
    const offers = new Map<string, Offer[]>();
    const fresh = (r: RawListing) => {
      const age = Date.now() - Date.parse(r.checkedAt);
      return age >= 0 && age < (options.ttlMs ?? 3600000);
    };
    // At most two items in flight (six source requests); one shared overall deadline.
    let cursor = 0;
    const worker = async () => {
      while (cursor < input.items.length) {
        const item = input.items[cursor++];
        const query: ScrapeQuery = {
          query: item.name,
          postalCode: input.location?.postal_code,
          maxResults: 10,
          fulfillment: input.location?.fulfillment ?? "delivery",
          pickupStore: input.location?.pickup_store,
        };
        if (options.mode === "demo") {
          let rows = options.fixtures;
          if (options.repository) {
            try {
              rows = z
                .array(ScrapedListing)
                .parse(
                  await bounded(
                    () => options.repository!.search(query, signal),
                    signal,
                  ),
                );
            } catch {
              errors.push(
                failure(
                  "CACHE_FAILED",
                  "La base demo no respondió; se usan los fixtures de respaldo.",
                  item.client_item_id,
                  true,
                ),
              );
            }
          }
          offers.set(
            item.client_item_id,
            rows
              .filter((r) => matches(r.productName, item.name))
              .map((listing) => ({ listing, status: "demo" })),
          );
          continue;
        }
        let cached: RawListing[] = [],
          fetched: RawListing[] = [];
        const scoped = (r: RawListing) =>
          !query.postalCode ||
          (r.locationEvidence?.postalCode === query.postalCode &&
            r.locationEvidence.fulfillment === query.fulfillment &&
            (query.fulfillment !== "pickup" ||
              (r.source === "chedraui" &&
                query.pickupStore === "chedraui-bellavista" &&
                r.locationEvidence.storeName ===
                  "Super Chedraui Bellavista")) &&
            r.locationEvidence.availability === "in_stock" &&
            Date.now() - Date.parse(r.checkedAt) >= 0 &&
            Date.now() - Date.parse(r.checkedAt) < 300000);
        if (options.repository)
          try {
            cached = z
              .array(ScrapedListing)
              .parse(
                await bounded(
                  () => options.repository!.search(query, signal),
                  signal,
                ),
              )
              .filter((r) => matches(r.productName, item.name) && scoped(r));
          } catch {
            errors.push(
              failure(
                "CACHE_FAILED",
                "No fue posible leer la caché.",
                item.client_item_id,
                true,
              ),
            );
          }
        // Refresh unless current cache covers every configured retailer.
        const coverage = new Set(
          cached
            .filter(fresh)
            .map((r) => r.source)
            .filter((s) => RETAILERS.some((r) => r.id === s)),
        );
        if (
          coverage.size <
            (query.fulfillment === "pickup" ? 1 : RETAILERS.length) ||
          cached.some((r) => !fresh(r))
        ) {
          if (!options.scraper)
            errors.push(
              failure(
                "SOURCES_NOT_CONFIGURED",
                "Falta la clave de Firecrawl.",
                item.client_item_id,
              ),
            );
          else
            try {
              const batch = await bounded(
                () => options.scraper!.scrape(query, signal),
                signal,
              );
              fetched = z
                .array(ScrapedListing)
                .parse(batch.listings)
                .filter((r) => matches(r.productName, item.name) && scoped(r));
              errors.push(
                ...batch.errors.map((e) =>
                  failure(e.code, e.message, item.client_item_id, e.retryable),
                ),
              );
            } catch {
              errors.push(
                failure(
                  signal.aborted ? "SOURCE_TIMEOUT" : "REFRESH_FAILED",
                  "No fue posible actualizar los precios.",
                  item.client_item_id,
                  true,
                ),
              );
            }
          if (fetched.length && options.repository)
            try {
              await bounded(
                () => options.repository!.upsert(fetched, query, signal),
                signal,
              );
            } catch {
              errors.push(
                failure(
                  "SAVE_FAILED",
                  "No se pudo guardar la actualización.",
                  item.client_item_id,
                  true,
                ),
              );
            }
        }
        const merged = new Map<string, Offer>();
        for (const listing of [...cached, ...fetched].sort(
          (a, b) => Date.parse(a.checkedAt) - Date.parse(b.checkedAt),
        ))
          merged.set(
            JSON.stringify([
              listing.source,
              listing.productUrl,
              listing.storeName,
            ]),
            { listing, status: fresh(listing) ? "verified" : "stale" },
          );
        offers.set(item.client_item_id, [...merged.values()]);
      }
    };
    await Promise.all([worker(), worker()]);
    const plan = planBasket(
      input.items,
      offers,
      input.preferences?.max_stores ?? 2,
    );
    for (const item of plan.unmatched_items)
      errors.push(
        failure(
          item.reason,
          "No se pudo asignar este producto a una oferta comparable.",
          item.client_item_id,
        ),
      );
    if (plan.stores.some((s) => s.items.some((i) => i.data_status === "stale")))
      errors.push(
        failure("STALE_DATA", "Algunos precios están vencidos.", null, true),
      );
    if (
      options.mode === "live" &&
      plan.stores.length &&
      (!input.location?.postal_code ||
        plan.stores.some((s) =>
          s.items.some(
            (i) => i.verified_postal_code !== input.location?.postal_code,
          ),
        ))
    )
      errors.push(
        failure(
          "LOCATION_UNVERIFIED",
          "Los precios publicados no se han validado para el código postal solicitado.",
        ),
      );
    const status = errors.length
      ? plan.stores.length
        ? "partial"
        : "error"
      : "complete";
    const prefix = options.mode === "demo" ? "DEMO: precios de ejemplo. " : "";
    return {
      reply:
        prefix +
        (input.items.length === 0
          ? "Agrega productos al borrador."
          : plan.stores.length
            ? `Comparación de ${plan.stores.reduce((n, s) => n + s.items.length, 0)} productos en ${plan.stores.length} tienda(s), entre las ofertas disponibles. Sustitutos marcados como similares. No incluye transporte ni entrega.`
            : "No encontré ofertas comparables para esta lista."),
      status,
      draft_items: input.items,
      plan,
      errors,
    };
  };
}
