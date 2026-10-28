import { writeFile } from "node:fs/promises";
import { z } from "zod";
import { SearchRequest, SearchResponse, ScrapedListing } from "./schema.js";
for (const [name, schema] of Object.entries({
  "chat-search.request": SearchRequest,
  "chat-search.response": SearchResponse,
  "scraped-listing": ScrapedListing,
})) {
  await writeFile(
    `contracts/${name}.schema.json`,
    JSON.stringify(
      z.toJSONSchema(schema, { unrepresentable: "any" }),
      null,
      2,
    ) + "\n",
  );
}
