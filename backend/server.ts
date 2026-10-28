import { SupabaseListingRepository } from "./supabase-repository.js";
import { createAnthropic } from "@ai-sdk/anthropic";
import { readFile } from "node:fs/promises";
import { z } from "zod";
import { ScrapedListing } from "../contracts/schema.js";
import { buildApp } from "./app.js";
import { FirecrawlScraper } from "../scrapers/firecrawl.js";
import { AIDraftAgent } from "./ai-agent.js";
const mode = z.enum(["demo", "live"]).parse(process.env.DATA_MODE ?? "demo");
const fixtures = z
  .array(ScrapedListing)
  .parse(JSON.parse(await readFile("./fixtures/listings.json", "utf8")));
const key = process.env.FIRECRAWL_API_KEY;
const agent =
  process.env.ANTHROPIC_API_KEY && process.env.CLAUDE_MODEL
    ? new AIDraftAgent(
        createAnthropic({ apiKey: process.env.ANTHROPIC_API_KEY })(
          process.env.CLAUDE_MODEL,
        ),
      )
    : process.env.AI_GATEWAY_API_KEY && process.env.AGENT_MODEL
      ? new AIDraftAgent(process.env.AGENT_MODEL)
      : undefined;
const app = buildApp({
  mode,
  fixtures,
  agent,
  repository:
    process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY
      ? new SupabaseListingRepository(
          process.env.SUPABASE_URL,
          process.env.SUPABASE_SERVICE_ROLE_KEY,
          mode === "demo",
        )
      : undefined,
  scraper: key ? new FirecrawlScraper(key) : undefined,
});
const port = z.coerce
  .number()
  .int()
  .min(1)
  .max(65535)
  .parse(process.env.PORT ?? 3000);
await app.listen({ host: process.env.HOST ?? "127.0.0.1", port });
console.info(
  `Grocery AI: http://${process.env.HOST ?? "127.0.0.1"}:${port} (${mode})`,
);
for (const signal of ["SIGINT", "SIGTERM"] as const)
  process.on(signal, () => {
    void app.close().then(() => process.exit(0));
  });
