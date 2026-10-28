import { z } from "zod";
import {
  ScrapedListing,
  type Response,
  type SearchInput,
  type RawListing,
} from "../contracts/schema.js";
import { type Options, failure } from "./service.js";
import { applyChanges } from "./agent.js";
import { bounded } from "./deadline.js";
import { matches, measure } from "./normalize.js";

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
    query = changes.items[0].name;
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
  const search = { query, maxResults: 2 };
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
        Date.now() - Date.parse(r.checkedAt) < 300000,
    );
    if (
      new Set(
        rows.filter((r) => matches(r.productName, query)).map((r) => r.source),
      ).size < 3 &&
      options.scraper
    ) {
      try {
        const batch = await bounded(
          () => options.scraper!.scrape(search, signal),
          signal,
        );
        const fetched = z.array(ScrapedListing).parse(batch.listings);
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
    if (matches(r.productName, query) && r.quantity && r.unit)
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
    offers.length > 0 && new Set(offers.map((o) => o.basis)).size === 1;
  const winner = comparable ? offers[0] : undefined;
  const money = (n: number) =>
    new Intl.NumberFormat("es-MX", {
      style: "currency",
      currency: "MXN",
    }).format(n / 100);
  const prefix = options.mode === "demo" ? "DEMO: precios de ejemplo. " : "";
  const reply = winner
    ? `${prefix}${winner.listing.retailer} tiene el menor precio por 100 ${winner.basis} entre las ${offers.length} opciones consultadas: ${winner.listing.productName}, ${money(winner.listing.priceCents)} por presentación (${money(winner.unit_price_cents_per_100)} / 100 ${winner.basis}). Comparamos presentaciones y marcas distintas. Son precios publicados; no confirman existencias ni entrega${input.location?.postal_code ? ` para CP ${input.location.postal_code}` : " en tu ubicación"}.`
    : offers.length
      ? "Encontré opciones con unidades distintas; no puedo declarar un ganador comparable."
      : "No pude obtener precios publicados del producto. No mostraré importes inventados.";
  return {
    ...base,
    errors,
    status: offers.length ? "partial" : "error",
    reply,
    comparison: {
      query,
      scope: "published",
      data_mode: options.mode,
      requested_postal_code: input.location?.postal_code ?? null,
      offers,
      winner_url: winner?.listing.productUrl ?? null,
    },
  };
}
