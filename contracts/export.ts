import { writeFile } from "node:fs/promises";
import { z } from "zod";
import {
  SearchRequest,
  SearchResponse,
  ScrapedListing,
  BasketQuoteRequest,
  BasketQuoteResponse,
} from "./schema.js";
for (const [name, schema] of Object.entries({
  "chat-search.request": SearchRequest,
  "chat-search.response": SearchResponse,
  "scraped-listing": ScrapedListing,
  "onboarding-basket.request": BasketQuoteRequest,
  "onboarding-basket.response": BasketQuoteResponse,
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
