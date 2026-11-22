import { z } from "zod";
import {
  ScrapedListing,
  type BasketQuote,
  type BasketQuoteInput,
  type Failure,
  type OnboardingBasketData,
  type RawListing,
} from "../contracts/schema.js";
import type { ListingRepository } from "./repository.js";
import { bounded } from "./deadline.js";
import { matches, measure } from "./normalize.js";
import { retailerIdentity } from "./retailer-identity.js";
import { failure } from "./service.js";

// Published prices observed by the regular pipeline stay usable for a week.
// The onboarding never scrapes: one basket × three stores per new user would
// exceed the Firecrawl plan and take minutes.
const MAX_CACHE_AGE_MS = 7 * 24 * 60 * 60 * 1000;
const NAMES = {
  walmart: "Walmart",
  bodega_aurrera: "Bodega Aurrera",
  chedraui: "Chedraui",
} as const;

export type BasketOptions = {
  mode: "demo" | "live";
  basket: OnboardingBasketData;
  basketFixtures: RawListing[];
  repository?: ListingRepository;
};

type BasketItem = OnboardingBasketData["items"][number];

export function isSameProduct(
  listing: RawListing,
  item: BasketItem,
  retailer: BasketQuoteInput["retailer_id"],
): boolean {
  if (!listing.quantity || !listing.unit) return false;
  if (retailerIdentity(listing.source, listing.retailer).id !== retailer)
    return false;
  if (!matches(`${listing.productName} ${listing.brand ?? ""}`, item.query))
    return false;
  const wanted = measure(item.quantity, item.unit),
    offered = measure(listing.quantity, listing.unit);
  return (
    wanted.dimension === offered.dimension && wanted.amount === offered.amount
  );
}

export async function quoteBasket(
  input: BasketQuoteInput,
  options: BasketOptions,
  signal: AbortSignal,
): Promise<BasketQuote> {
  const errors: Failure[] = [];
  const demo = options.mode === "demo";
  const pick = async (item: BasketItem): Promise<RawListing | undefined> => {
    let rows: RawListing[] = [];
    if (demo) rows = options.basketFixtures;
    else if (options.repository)
      try {
        rows = z
          .array(ScrapedListing)
          .parse(
            await bounded(
              () =>
                options.repository!.search(
                  { query: item.query, maxResults: 10 },
                  signal,
                ),
              signal,
            ),
          )
          .filter((r) => {
            const age = Date.now() - Date.parse(r.checkedAt);
            return age >= 0 && age < MAX_CACHE_AGE_MS;
          });
      } catch {
        errors.push(
          failure("CACHE_FAILED", "No fue posible leer la caché.", item.id, true),
        );
      }
    return rows
      .filter((r) => isSameProduct(r, item, input.retailer_id))
      .sort(
        (a, b) =>
          Date.parse(b.checkedAt) - Date.parse(a.checkedAt) ||
          a.priceCents - b.priceCents,
      )[0];
  };
  const picks = new Map<string, RawListing | undefined>();
  let cursor = 0;
  const items = options.basket.items;
  const worker = async () => {
    while (cursor < items.length) {
      const item = items[cursor++];
      picks.set(item.id, await pick(item));
    }
  };
  await Promise.all([worker(), worker(), worker(), worker()]);
  if (!demo && !options.repository)
    errors.push(
      failure(
        "CACHE_NOT_CONFIGURED",
        "No hay caché de precios configurada para la canasta.",
      ),
    );
  const dates = [...picks.values()]
    .filter((r): r is RawListing => !!r)
    .map((r) => r.checkedAt)
    .sort();
  return {
    retailer_id: input.retailer_id,
    retailer_name: NAMES[input.retailer_id],
    data_mode: options.mode,
    requested_postal_code: input.postal_code ?? null,
    prices_checked_at: dates.at(-1) ?? null,
    basket: options.basket,
    items: items.map((item) => {
      const r = picks.get(item.id);
      return r
        ? {
            basket_item_id: item.id,
            status: "priced",
            product_name: r.productName,
            price_cents: r.priceCents,
            product_url: r.productUrl,
            checked_at: r.checkedAt,
            data_status: demo ? "demo" : "verified",
          }
        : {
            basket_item_id: item.id,
            status: "unavailable",
            product_name: null,
            price_cents: null,
            product_url: null,
            checked_at: null,
            data_status: null,
          };
    }),
    errors,
  };
}
