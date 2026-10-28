import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { SupabaseListingRepository } from "../backend/supabase-repository.js";
import { buildApp } from "../backend/app.js";
import { SearchResponse, type RawListing } from "../contracts/schema.js";
const url = process.env.SUPABASE_URL,
  key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key)
  throw Error("Configure SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
const rows: RawListing[] = JSON.parse(
  await readFile("fixtures/listings.json", "utf8"),
);
const demo = new SupabaseListingRepository(url, key, true);
const live = new SupabaseListingRepository(url, key, false);
const signal = AbortSignal.timeout(15000);
await demo.upsert(rows, { query: "" }, signal);
await demo.upsert(rows, { query: "" }, signal);
assert.equal((await demo.search({ query: "queso Oaxaca" }, signal)).length, 2);
// Demo imports do not become current prices in the live namespace.
assert.equal(
  (await live.search({ query: "queso Oaxaca", postalCode: "00000" }, signal))
    .length,
  0,
);
const app = buildApp({ mode: "demo", fixtures: [], repository: demo });
try {
  const draft = SearchResponse.parse(
    (
      await app.inject({
        method: "POST",
        url: "/v1/chat/search",
        payload: {
          action: "update_draft",
          message: "Agrega 2 litros de leche, 12 huevos y 1 kg de arroz",
          items: [],
        },
      })
    ).json(),
  );
  const result = SearchResponse.parse(
    (
      await app.inject({
        method: "POST",
        url: "/v1/chat/search",
        payload: {
          action: "compare",
          items: draft.draft_items,
          location: { postal_code: "06700" },
        },
      })
    ).json(),
  );
  assert.equal(result.status, "complete");
  assert.equal(result.plan!.stores.length, 2);
  assert.equal(result.plan!.total_price_cents, 13400);
  assert.equal(result.plan!.estimated_savings_cents, 600);
  assert.ok(
    result
      .plan!.stores.flatMap((s) => s.items)
      .every((i) => i.data_status === "demo" && i.product_url && i.checked_at),
  );
  console.log(
    "Database E2E passed: API → Supabase → two stores; total 13400, savings 600; repeated import and demo/live isolation verified.",
  );
} finally {
  await app.close();
}
