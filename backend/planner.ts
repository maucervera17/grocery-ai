import { createHash } from "node:crypto";
import type { Item, Offer, Line, ShoppingPlan } from "../contracts/schema.js";
import { matches, measure } from "./normalize.js";
type Candidate = {
  store: string;
  retailer: string;
  store_name: string | null;
  line: Line;
};
export function candidate(item: Item, offer: Offer): Candidate | null {
  const r = offer.listing;
  if (
    item.notes?.trim() ||
    !matches(r.productName, item.name) ||
    !r.quantity ||
    !r.unit
  )
    return null;
  const wanted = measure(item.quantity, item.unit),
    pack = measure(r.quantity, r.unit);
  if (wanted.dimension !== pack.dimension) return null;
  const count = Math.ceil(wanted.amount / pack.amount),
    total = count * r.priceCents;
  if (!Number.isSafeInteger(total)) return null;
  const store = JSON.stringify([r.retailer, r.storeName ?? null]);
  return {
    store,
    retailer: r.retailer,
    store_name: r.storeName ?? null,
    line: {
      client_item_id: item.client_item_id,
      listing_id: createHash("sha256")
        .update(JSON.stringify([r.source, r.productUrl, r.storeName ?? null]))
        .digest("hex")
        .slice(0, 24),
      product_name: r.productName,
      brand: r.brand ?? null,
      requested_quantity: item.quantity,
      requested_unit: item.unit,
      package_quantity: r.quantity,
      package_unit: r.unit,
      package_count: count,
      price_cents: r.priceCents,
      regular_price_cents: r.regularPriceCents ?? null,
      line_total_cents: total,
      unit_price_cents_per_100: ["mass", "volume"].includes(pack.dimension)
        ? Math.round((r.priceCents * 100000) / pack.amount)
        : null,
      product_url: r.productUrl,
      ...(r.imageUrl ? { image_url: r.imageUrl } : {}),
      checked_at: r.checkedAt,
      data_status: offer.status,
      match_type: "similar",
      ...(r.locationEvidence
        ? {
            verified_postal_code: r.locationEvidence.postalCode,
            verified_fulfillment: r.locationEvidence.fulfillment,
          }
        : {}),
    },
  };
}
export function planBasket(
  items: Item[],
  offers: Map<string, Offer[]>,
  maxStores: number,
): ShoppingPlan {
  const candidates = items.map((item) => {
    const all = (offers.get(item.client_item_id) ?? [])
      .map((o) => candidate(item, o))
      .filter((c): c is Candidate => !!c);
    const current = all.filter((c) => c.line.data_status !== "stale");
    return current.length ? current : all;
  });
  const stores = [
    ...new Set(candidates.flatMap((c) => c.map((x) => x.store))),
  ].sort();
  const subsets = stores.map((s) => [s]);
  if (maxStores === 2)
    for (let i = 0; i < stores.length; i++)
      for (let j = i + 1; j < stores.length; j++)
        subsets.push([stores[i], stores[j]]);
  const solutions = subsets
    .map((subset) => {
      const lines = candidates.map(
        (cs) =>
          cs
            .filter((c) => subset.includes(c.store))
            .sort(
              (a, b) =>
                a.line.line_total_cents - b.line.line_total_cents ||
                a.line.listing_id.localeCompare(b.line.listing_id),
            )[0],
      );
      const chosen = lines.filter((c): c is Candidate => !!c);
      return {
        lines,
        chosen,
        total: chosen.reduce((sum, c) => sum + c.line.line_total_cents, 0),
        count: new Set(chosen.map((c) => c.store)).size,
      };
    })
    .sort(
      (a, b) =>
        b.chosen.length - a.chosen.length ||
        a.total - b.total ||
        a.count - b.count,
    );
  const best = solutions[0];
  const grouped = new Map<string, ShoppingPlan["stores"][number]>();
  for (const c of best?.chosen ?? []) {
    const group = grouped.get(c.store) ?? {
      retailer: c.retailer,
      store_name: c.store_name,
      subtotal_cents: 0,
      items: [],
    };
    group.items.push(c.line);
    group.subtotal_cents += c.line.line_total_cents;
    grouped.set(c.store, group);
  }
  const baseline = solutions
    .filter((s) => s.count === 1 && s.chosen.length === items.length)
    .sort((a, b) => a.total - b.total)[0];
  // A saving is meaningful only for complete baskets and consistent demo/current provenance.
  const statuses = new Set(
    [...(best?.chosen ?? []), ...(baseline?.chosen ?? [])].map(
      (c) => c.line.data_status,
    ),
  );
  const saving =
    best &&
    baseline &&
    best.chosen.length === items.length &&
    statuses.size === 1 &&
    !statuses.has("stale")
      ? Math.max(0, baseline.total - best.total)
      : null;
  return {
    total_price_cents: best?.total ?? 0,
    estimated_savings_cents: saving,
    currency: "MXN",
    stores: [...grouped.values()],
    unmatched_items: items.flatMap((item, i) =>
      best?.lines[i]
        ? []
        : [
            {
              client_item_id: item.client_item_id,
              name: item.name,
              reason: item.notes?.trim()
                ? "NOTES_REQUIRE_REVIEW"
                : candidates[i].length
                  ? "STORE_LIMIT"
                  : offers.get(item.client_item_id)?.length
                    ? "INCOMPATIBLE_UNIT"
                    : "NO_MATCH",
            },
          ],
    ),
  };
}
