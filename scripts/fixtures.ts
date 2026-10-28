import { readFile, writeFile } from "node:fs/promises";
import { createSearch } from "../backend/service.js";
import { SearchResponse, type RawListing } from "../contracts/schema.js";
const fixtures: RawListing[] = JSON.parse(
  await readFile("fixtures/listings.json", "utf8"),
);
const search = createSearch({ mode: "demo", fixtures });
const update = {
  action: "update_draft" as const,
  message: "Agrega 2 litros de leche, 12 huevos y 1 kg de arroz",
  items: [],
  location: null,
};
const draft = await search(update);
draft.draft_items.forEach((item, i) => {
  item.client_item_id = [
    "00000000-0000-4000-8000-000000000001",
    "00000000-0000-4000-8000-000000000002",
    "00000000-0000-4000-8000-000000000003",
  ][i];
});
const compare = {
  action: "compare" as const,
  message: null,
  items: draft.draft_items,
  location: { postal_code: "06700" },
  preferences: { max_stores: 2 },
};
const complete = await search(compare);
const partial = await search({
  ...compare,
  items: [
    ...compare.items,
    {
      client_item_id: "00000000-0000-4000-8000-000000000004",
      name: "plátanos",
      quantity: 1,
      unit: "kg",
      notes: null,
    },
  ],
});
const empty = await search({ ...compare, items: [] });
const error = await createSearch({ mode: "live", fixtures })(compare);
for (const [file, body] of Object.entries({
  "update-draft.request": update,
  "update-draft.response": draft,
  "compare.request": compare,
  "compare.response": complete,
  "compare.partial.response": partial,
  "compare.empty.response": empty,
  "compare.error.response": error,
  "chat-search.response": complete,
})) {
  if (file.includes("response")) SearchResponse.parse(body);
  await writeFile(
    `fixtures/${file}.json`,
    JSON.stringify(body, null, 2) + "\n",
  );
}
console.log(
  "Fixtures regenerated. Demo total:",
  complete.plan!.total_price_cents,
  "Savings:",
  complete.plan!.estimated_savings_cents,
);
