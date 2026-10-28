import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { SupabaseListingRepository } from "../backend/supabase-repository.js";
import { createSearch } from "../backend/service.js";
import {
  SearchResponse,
  type RawListing,
  type Item,
} from "../contracts/schema.js";
const rows: RawListing[] = JSON.parse(
  readFileSync("fixtures/listings.json", "utf8"),
);
const item: Item = {
  client_item_id: "q",
  name: "queso Oaxaca",
  quantity: 400,
  unit: "g",
  notes: null,
};
test("Supabase adapter validates output and isolates demo and postal scopes", async () => {
  const calls: { url: string; body: any }[] = [];
  const repo = new SupabaseListingRepository(
    "http://127.0.0.1:54321",
    "test",
    false,
    async (url, init) => {
      calls.push({ url: String(url), body: JSON.parse(String(init?.body)) });
      return Response.json(rows);
    },
  );
  await repo.search(
    { query: "huevos", postalCode: "06700" },
    AbortSignal.timeout(1000),
  );
  assert.equal(calls[0].body.p_query, "huevo");
  assert.equal(calls[0].body.p_postal_code, "06700");
  assert.equal(calls[0].body.p_demo, false);
  await repo.upsert(
    rows,
    { query: "leche", postalCode: "12345" },
    AbortSignal.timeout(1000),
  );
  assert.equal(calls[1].body.p_postal_code, "12345");
  assert.deepEqual(calls[1].body.p_listings, rows);
  const bad = new SupabaseListingRepository(
    "https://example.com",
    "test",
    false,
    async () => Response.json([{ priceCents: 1 }]),
  );
  await assert.rejects(
    bad.search({ query: "leche" }, AbortSignal.timeout(1000)),
  );
});
test("database error does not leak server credentials", async () => {
  const repo = new SupabaseListingRepository(
    "https://example.com",
    "secret",
    false,
    async () => new Response("secret failure", { status: 403 }),
  );
  await assert.rejects(
    repo.search({ query: "leche" }, AbortSignal.timeout(1000)),
    (e) => e instanceof Error && !e.message.includes("secret"),
  );
});
test("demo database is used for pricing; Oaxaca is ranked by the shared planner", async () => {
  let reads = 0;
  const search = createSearch({
    mode: "demo",
    fixtures: [],
    repository: {
      search: async () => {
        reads++;
        return rows;
      },
      upsert: async () => {},
    },
  });
  const out = await search({ action: "compare", items: [item] });
  SearchResponse.parse(out);
  assert.equal(reads, 1);
  assert.equal(out.status, "complete");
  assert.equal(out.plan!.total_price_cents, 7900);
  assert.equal(out.plan!.stores[0].retailer, "Bodega Aurrera (demo)");
  assert.equal(out.plan!.stores[0].items[0].data_status, "demo");
});
test("demo DB failure uses explicit demo fallback, never verified provenance", async () => {
  const out = await createSearch({
    mode: "demo",
    fixtures: rows,
    repository: {
      search: async () => {
        throw Error("offline");
      },
      upsert: async () => {},
    },
  })({ action: "compare", items: [item] });
  assert.equal(out.status, "partial");
  assert.equal(out.plan!.stores[0].items[0].data_status, "demo");
  assert.ok(out.errors.some((e) => e.code === "CACHE_FAILED"));
});
test("refresh saves results and cannot overwrite a newer cached observation with an older scrape", async () => {
  const cached = rows
    .filter((r) => r.productName === "Queso Oaxaca")
    .map((r) => ({ ...r, checkedAt: new Date().toISOString() }));
  let saved = 0;
  const out = await createSearch({
    mode: "live",
    fixtures: [],
    repository: {
      search: async () => [cached[0]],
      upsert: async (rows) => {
        saved = rows.length;
      },
    },
    scraper: {
      scrape: async () => ({
        listings: [
          { ...cached[0], priceCents: 1, checkedAt: "2020-01-01T00:00:00Z" },
        ],
        errors: [],
      }),
    },
  })({ action: "compare", items: [item] });
  assert.equal(saved, 1);
  assert.equal(out.plan!.total_price_cents, 8900);
  assert.equal(out.plan!.stores[0].items[0].data_status, "verified");
});
test("one failing retailer still returns the healthy source", async () => {
  const out = await createSearch({
    mode: "live",
    fixtures: [],
    scraper: {
      scrape: async () => ({
        listings: rows
          .filter(
            (r) => r.productName === "Queso Oaxaca" && r.source === "chedraui",
          )
          .map((r) => ({ ...r, checkedAt: new Date().toISOString() })),
        errors: [
          {
            code: "SOURCE_TIMEOUT",
            source: "bodega-aurrera",
            message: "Tiempo agotado",
            retryable: true,
          },
        ],
      }),
    },
  })({ action: "compare", items: [item] });
  assert.equal(out.status, "partial");
  assert.equal(out.plan!.stores.length, 1);
  assert.ok(out.errors.some((e) => e.code === "SOURCE_TIMEOUT"));
});

test('HTTP never serves credentials or server files, even through encoded traversal', async () => {
  const { buildApp } = await import('../backend/app.js');
  const app = buildApp({ mode:'demo', fixtures:rows });
  try {
    for (const url of ['/.env','/backend/server.ts','/..%2f.env','/web/../.env']) {
      const result = await app.inject({method:'GET',url});
      assert.equal(result.statusCode,404);
      assert.ok(!result.body.includes('ANTHROPIC_API_KEY'));
    }
    const result=await app.inject({method:'POST',url:'/v1/chat/search',headers:{'content-type':'text/plain'},payload:'not JSON'});
    assert.equal(result.statusCode,400);
    SearchResponse.parse(result.json());
  } finally {await app.close()}
});
