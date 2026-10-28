import assert from "node:assert/strict";
import { SearchResponse } from "../contracts/schema.js";
const base = process.env.API_BASE_URL ?? "http://127.0.0.1:3000";
async function post(body: unknown) {
  const response = await fetch(base + "/v1/chat/search", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(30000),
  });
  assert.equal(response.status, 200);
  return SearchResponse.parse(await response.json());
}
const draft = await post({
  action: "update_draft",
  message: "Agrega 2 litros de leche, 12 huevos y 1 kg de arroz",
  items: [],
});
assert.equal(draft.status, "complete");
assert.equal(draft.draft_items.length, 3);
const result = await post({
  action: "compare",
  items: draft.draft_items,
  preferences: { max_stores: 2 },
});
assert.equal(result.status, "complete");
assert.equal(result.plan!.stores.length, 2);
assert.equal(result.plan!.total_price_cents, 13400);
assert.equal(result.plan!.estimated_savings_cents, 600);
assert.ok(
  result
    .plan!.stores.flatMap((s) => s.items)
    .every((i) => i.data_status === "demo"),
);
console.log(
  "HTTP smoke passed: draft -> 3 items -> 2 stores -> $134.00 demo total, $6.00 demo saving.",
);
