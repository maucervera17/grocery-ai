// Refreshes the cached prices that POST /v1/onboarding/basket reads, so the
// onboarding never scrapes per user. Usage:
//   npm run basket:precompute -- --dry-run   # cost estimate, no requests
//   npm run basket:precompute [-- --force]   # needs Firecrawl + Supabase keys
import { readFile } from "node:fs/promises";
import { OnboardingBasket } from "../contracts/schema.js";
import { FirecrawlScraper } from "../scrapers/firecrawl.js";
import { SupabaseListingRepository } from "../backend/supabase-repository.js";
import {
  estimateRequests,
  precomputeBasket,
} from "../backend/basket-precompute.js";

const args = new Set(process.argv.slice(2));
const basket = OnboardingBasket.parse(
  JSON.parse(await readFile("./fixtures/onboarding-basket.json", "utf8")),
);
const estimate = estimateRequests(basket);
console.info(
  `Canasta v${basket.version}: ${basket.items.length} productos × 3 tiendas. ` +
    `Máximo por corrida: ${estimate.search} búsquedas y ${estimate.scrapeMax} páginas de Firecrawl ` +
    `(los productos con precio de menos de 4 días en las 3 tiendas se omiten).`,
);
if (args.has("--dry-run")) process.exit(0);

const { FIRECRAWL_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } =
  process.env;
if (!FIRECRAWL_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY)
  throw Error(
    "Configura FIRECRAWL_API_KEY, SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY.",
  );
const report = await precomputeBasket({
  basket,
  scraper: new FirecrawlScraper(FIRECRAWL_API_KEY),
  repository: new SupabaseListingRepository(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
  ),
  force: args.has("--force"),
  log: (line) => console.info(line),
});
const priced = (id: "walmart" | "bodega_aurrera" | "chedraui") =>
  report.items.filter((i) => i.retailers[id] !== "missing").length;
console.info(
  JSON.stringify(
    {
      scraped_items: report.scrapedItems,
      skipped_items: report.skippedItems,
      saved_listings: report.savedListings,
      priced_items: {
        walmart: priced("walmart"),
        bodega_aurrera: priced("bodega_aurrera"),
        chedraui: priced("chedraui"),
      },
      fatal: report.fatal,
    },
    null,
    2,
  ),
);
if (report.fatal) process.exitCode = 1;
