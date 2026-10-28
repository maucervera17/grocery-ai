import { z } from "zod";
import {
  ScrapedListing,
  type Response,
  type SearchInput,
  type RawListing,
  type ScrapeQuery,
} from "../contracts/schema.js";
import { type Options, failure } from "./service.js";
import { applyChanges } from "./agent.js";
import { bounded } from "./deadline.js";
import { matches, measure, tokens } from "./normalize.js";

// A product price enquiry is not a basket purchase. Do not invent a requested weight.
// Published prices remain explicitly separate from destination-verified availability.
export async function productPrices(
  input: Extract<SearchInput, { action: "product_prices" }>,
  options: Options,
  signal: AbortSignal,
): Promise<Response> {
  const base = {
    draft_items: input.items,
    plan: null,
    errors: [] as Response["errors"],
  };
  if (!options.agent)
    return {
      ...base,
      status: "error",
      reply: "No está configurado el agente para interpretar tu consulta.",
    };
  let query: string;
  try {
    const changes = applyChanges(
      [],
      await bounded(
        () => options.agent!.interpret(input.message, [], signal),
        signal,
      ),
    );
    if (changes.clarification || changes.items.length !== 1)
      return {
        ...base,
        status: "partial",
        reply:
          changes.clarification ??
          "Indica un producto para comparar sus presentaciones.",
      };
    query = tokens(changes.items[0].name).join(" ");
    if (changes.items[0].notes)
      return {
        ...base,
        status: "partial",
        reply:
          "Para comparar restricciones o detalles especiales necesito comprobarlos en cada producto. Prueba con nombre y marca.",
      };
  } catch {
    return {
      ...base,
      status: "error",
      reply: "No pude identificar el producto. Intenta escribir su nombre.",
    };
  }
  const errors = base.errors;
  let rows: RawListing[] = [];
  const local = input.price_scope === "local";
  if (local && !input.location)
    return {
      ...base,
      status: "error",
      reply: "Indica un código postal para consultar disponibilidad local.",
    };
  const search: ScrapeQuery = {
    query,
    maxResults: 2,
    ...(local
      ? {
          postalCode: input.location!.postal_code,
          fulfillment: input.location!.fulfillment ?? "delivery",
          pickupStore: input.location!.pickup_store,
        }
      : {}),
  };
  const inScope = (r: RawListing) =>
    !local ||
    (!!r.locationEvidence &&
      r.locationEvidence.postalCode === search.postalCode &&
      r.locationEvidence.fulfillment === search.fulfillment &&
      r.locationEvidence.availability === "in_stock" &&
      (search.fulfillment !== "pickup" ||
        (search.pickupStore === "chedraui-bellavista" &&
          r.source === "chedraui" &&
          r.locationEvidence.storeName === "Super Chedraui Bellavista")) &&
      Date.now() - Date.parse(r.checkedAt) >= 0 &&
      Date.now() - Date.parse(r.checkedAt) < 300000);
  if (options.mode === "demo") rows = options.fixtures;
  else {
    if (options.repository)
      try {
        rows = z
          .array(ScrapedListing)
          .parse(
            await bounded(
              () => options.repository!.search(search, signal),
              signal,
            ),
          );
      } catch {
        errors.push(failure("CACHE_FAILED", "No pude consultar la caché."));
      }
    // Reuse only a short-lived published observation. Never relabel it as postal evidence.
    rows = rows.filter(
      (r) =>
        Date.now() - Date.parse(r.checkedAt) >= 0 &&
        Date.now() - Date.parse(r.checkedAt) < 300000 &&
        inScope(r),
    );
    if (
      (new Set(
        rows.filter((r) => matches(r.productName, query)).map((r) => r.source),
      ).size < 3 ||
        rows.some((r) => matches(r.productName, query) && !r.imageUrl)) &&
      options.scraper
    ) {
      try {
        const batch = await bounded(
          () => options.scraper!.scrape(search, signal),
          signal,
        );
        const fetched = z
          .array(ScrapedListing)
          .parse(batch.listings)
          .filter(inScope);
        rows.push(...fetched);
        errors.push(
          ...batch.errors.map((e) =>
            failure(e.code, e.message, null, e.retryable),
          ),
        );
        if (fetched.length && options.repository)
          try {
            await bounded(
              () => options.repository!.upsert(fetched, search, signal),
              signal,
            );
          } catch {
            errors.push(
              failure(
                "SAVE_FAILED",
                "Los precios se consultaron pero no se pudieron guardar.",
              ),
            );
          }
      } catch {
        errors.push(
          failure(
            "SOURCE_TIMEOUT",
            "Una fuente no terminó la consulta a tiempo.",
            null,
            true,
          ),
        );
      }
    }
  }
  const unique = new Map<string, RawListing>();
  for (const r of rows.sort(
    (a, b) => Date.parse(a.checkedAt) - Date.parse(b.checkedAt),
  ))
    if (matches(r.productName, query) && r.quantity && r.unit && inScope(r))
      unique.set(r.productUrl, r);
  const offers = [...unique.values()]
    .map((listing) => {
      const m = measure(listing.quantity!, listing.unit!);
      const basis =
        m.dimension === "mass"
          ? "g"
          : m.dimension === "volume"
            ? "ml"
            : m.dimension === "count"
              ? "piece"
              : "package";
      return {
        listing,
        basis,
        unit_price_cents_per_100: Math.round(
          (listing.priceCents * 100000) / m.amount,
        ),
      } as const;
    })
    .sort(
      (a, b) =>
        a.unit_price_cents_per_100 - b.unit_price_cents_per_100 ||
        a.listing.priceCents - b.listing.priceCents,
    );
  const comparable =
    offers.length > 0 &&
    new Set(offers.map((o) => o.basis)).size === 1 &&
    new Set(offers.map((o) => o.listing.source)).size > 1;
  const winner = comparable ? offers[0] : undefined;
  const unitWinners = [...new Set(offers.map((o) => o.basis))].flatMap(
    (basis) => {
      const group = offers.filter((o) => o.basis === basis);
      return new Set(group.map((o) => o.listing.source)).size > 1
        ? [group[0]]
        : [];
    },
  );
  const money = (n: number) =>
    new Intl.NumberFormat("es-MX", {
      style: "currency",
      currency: "MXN",
    }).format(n / 100);
  const prefix = options.mode === "demo" ? "DEMO: precios de ejemplo. " : "";
  const reply = winner
    ? `${prefix}${winner.listing.retailer} tiene el menor precio por 100 ${winner.basis} entre las ${offers.length} opciones consultadas: ${winner.listing.productName}, ${money(winner.listing.priceCents)} por presentación (${money(winner.unit_price_cents_per_100)} / 100 ${winner.basis}). Comparamos presentaciones y marcas distintas. ${local ? `La fuente confirmó ${search.fulfillment === "pickup" ? "recogida" : "entrega"} para CP ${search.postalCode} al consultar; está sujeto a cambios.` : `Son precios publicados; no confirman existencias ni entrega${input.location?.postal_code ? ` para CP ${input.location.postal_code}` : " en tu ubicación"}.`}`
    : offers.length
      ? new Set(offers.map((o) => o.listing.source)).size < 2
        ? `Solo obtuve precios de una tienda${local ? ` para CP ${search.postalCode}` : ""}; todavía no puedo determinar cuál tienda tiene el mejor precio.`
        : unitWinners.length
          ? unitWinners
              .map(
                (o) =>
                  `Entre presentaciones en ${o.basis}, ${o.listing.retailer} tiene el menor precio por unidad: ${o.listing.productName}, ${money(o.listing.priceCents)} (${money(o.unit_price_cents_per_100)} / 100 ${o.basis}).`,
              )
              .join(" ") +
            " No comparo gramos con mililitros. Son precios publicados; disponibilidad local sin confirmar."
          : "Encontré opciones con unidades distintas; no puedo declarar un ganador comparable."
      : local
        ? `No pude confirmar precio y disponibilidad para CP ${search.postalCode}. Puedes elegir precios publicados para ver referencias sin confirmación local.`
        : "No pude obtener precios publicados del producto. No mostraré importes inventados.";
  return {
    ...base,
    errors,
    status: offers.length ? "partial" : "error",
    reply,
    comparison: {
      query,
      scope: local ? "local" : "published",
      data_mode: options.mode,
      requested_postal_code: input.location?.postal_code ?? null,
      offers,
      winner_url: winner?.listing.productUrl ?? null,
      unit_winners: unitWinners.map((o) => ({
        basis: o.basis,
        winner_url: o.listing.productUrl,
      })),
    },
  };
}
