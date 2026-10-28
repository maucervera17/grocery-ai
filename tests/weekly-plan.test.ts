import test from "node:test";
import assert from "node:assert/strict";
import {
  optimizeWeekly,
  weeklyExport,
  recordWeeklyPurchase,
} from "../web/weekly-plan.js";
const now = Date.now();
const offer = (
  retailer: string,
  price: number,
  id: string,
  quantity = 400,
  unit = "g",
) => ({
  listing: {
    retailer,
    priceCents: price,
    productUrl: "https://example.com/" + id,
    productName: id,
    quantity,
    unit,
    checkedAt: new Date(now).toISOString(),
  },
});
function row(id: string, offers: any[], usual = 10000) {
  return {
    id,
    name: id,
    offers,
    selected: offers[0].listing.productUrl,
    approved: offers.map((o) => o.listing.productUrl),
    packages: 1,
    usualPriceCents: usual,
  };
}
test("weekly basket compares a split basket to complete single-store baskets", () => {
  const rows = [
    row("cheese", [offer("A", 6000, "a"), offer("B", 8000, "b")]),
    row("eggs", [offer("A", 9000, "c"), offer("B", 7000, "d")]),
  ];
  const result = optimizeWeekly(rows, { now });
  assert.equal(result.cheapest.total, 13000);
  assert.equal(result.single.total, 15000);
  assert.equal(result.cheapest.savings, 7000);
  assert.equal(result.convenient, null);
  const withTravel = optimizeWeekly(rows, {
    now,
    travel: {
      A: { minutes: 30, costCents: 3000 },
      B: { minutes: 10, costCents: 0 },
    },
    hourlyCents: 6000,
  });
  assert.deepEqual(withTravel.convenient.stores, ["B"]);
  assert.equal(withTravel.convenient.effectiveTotal, 16000);
});
test("unapproved substitutions and incompatible dimensions never enter a basket", () => {
  const r = row("cheese", [
    offer("A", 6000, "a"),
    offer("B", 1, "b"),
    offer("C", 1, "c", 400, "ml"),
  ]);
  r.approved = [r.offers[0].listing.productUrl, r.offers[2].listing.productUrl];
  assert.equal(optimizeWeekly([r], { now }).cheapest.total, 6000);
});
test("missing products cannot produce a full-basket winner or savings", () => {
  const r = row("cheese", [offer("A", 6000, "a")]);
  const missing = { ...r, id: "meat", name: "meat", selected: null };
  const result = optimizeWeekly([r, missing], { now });
  assert.equal(result.cheapest, null);
  assert.equal(result.plans[0].complete, false);
  assert.equal(result.plans[0].savings, null);
  assert.deepEqual(result.plans[0].missing, ["meat"]);
});
test("package rounding, missing usual prices, negative savings and stale data", () => {
  const r = row(
    "cheese",
    [offer("A", 9000, "a", 500), offer("B", 4000, "b", 200)],
    5000,
  );
  const result = optimizeWeekly([r], { now });
  assert.equal(result.cheapest.total, 9000);
  assert.equal(result.cheapest.savings, -4000);
  r.usualPriceCents = null as any;
  assert.equal(optimizeWeekly([r], { now }).cheapest.savings, null);
  assert.equal(optimizeWeekly([r], { now: now + 3600001 }).cheapest, null);
  r.packages = 0;
  assert.equal(optimizeWeekly([r], { now }).cheapest, null);
});
test("unknown travel is never treated as zero, and export is a list not a created cart", () => {
  const r = row("cheese", [offer("A", 6000, "a")]);
  const result = optimizeWeekly([r], {
    now,
    travel: { A: { minutes: null, costCents: 0 } },
  });
  assert.equal(result.convenient, null);
  assert.match(weeklyExport(result.cheapest), /https:\/\/example.com\/a/);
  assert.match(weeklyExport(result.cheapest), /No se creó un carrito/);
});

test("weekly purchase freezes usual-price reference, rejects duplicates, and counts signed actual differences", () => {
  const snapshot = {
    id: "week-1",
    items: [{ usualReferenceCents: 10000 }, { usualReferenceCents: 5000 }],
  };
  const result = recordWeeklyPurchase(snapshot, [], 16000);
  assert.equal(result.differenceCents, -1000);
  snapshot.items[0].usualReferenceCents = 999;
  assert.equal(result.items[0].usualReferenceCents, 10000);
  assert.throws(() => recordWeeklyPurchase(snapshot, [result], 100));
  assert.equal(
    recordWeeklyPurchase({ id: "2", items: [{}] }, [], 500).differenceCents,
    null,
  );
  assert.throws(() => recordWeeklyPurchase(snapshot, [], -1));
});
test("explicit per-kg meat can be planned at half a kilo without rounding to a full package", () => {
  const o = offer("A", 18000, "Carne molida de res por kg", 1, "kg");
  const r = row("meat", [o], 20000);
  r.packages = 0.5;
  const result = optimizeWeekly([r], { now });
  assert.equal(result.cheapest.total, 9000);
  assert.equal(result.cheapest.reference, 10000);
  assert.equal(result.cheapest.lines[0].packages, 0.5);
});
