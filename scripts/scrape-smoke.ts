import { FirecrawlScraper } from "../scrapers/firecrawl.js";
import { ScrapedListing } from "../contracts/schema.js";
const key = process.env.FIRECRAWL_API_KEY;
if (!key)
  throw Error(
    "Configure FIRECRAWL_API_KEY in .env; MCP login is not an application API key.",
  );
const scraper = new FirecrawlScraper(key);
for (const query of ["leche", "arroz"]) {
  const result = await scraper.scrape(
    { query, maxResults: 2 },
    AbortSignal.timeout(25000),
  );
  for (const listing of result.listings) ScrapedListing.parse(listing);
  console.log(
    JSON.stringify(
      { query, listings: result.listings, errors: result.errors },
      null,
      2,
    ),
  );
  if (new Set(result.listings.map((r) => r.source)).size < 2)
    process.exitCode = 1;
}
