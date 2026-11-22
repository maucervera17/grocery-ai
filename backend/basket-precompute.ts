import { z } from "zod";
import {
  QuotableRetailerId,
  ScrapedListing,
  type OnboardingBasketData,
  type RawListing,
  type ScrapeQuery,
} from "../contracts/schema.js";
import type { ListingRepository } from "./repository.js";
import type { Scraper } from "../scrapers/firecrawl.js";
import { isSameProduct } from "./onboarding-basket.js";

type RetailerId = z.infer<typeof QuotableRetailerId>;
type BasketItem = OnboardingBasketData["items"][number];
export type RetailerStatus = "cached" | "scraped" | "missing";
export type ItemReport = {
  id: string;
  name: string;
  retailers: Record<RetailerId, RetailerStatus>;
  errors: string[];
};
export type PrecomputeReport = {
  items: ItemReport[];
  scrapedItems: number;
  skippedItems: number;
  savedListings: number;
  fatal: string | null;
};
export type PrecomputeOptions = {
  basket: OnboardingBasketData;
  scraper: Scraper;
  repository: ListingRepository;
  // Items priced at every store more recently than this are not scraped again.
  // Shorter than the 7-day window the onboarding reads, so a twice-weekly run
  // refreshes each item before it expires.
  freshForMs?: number;
  force?: boolean;
  itemTimeoutMs?: number;
  log?: (line: string) => void;
};

const RETAILERS = QuotableRetailerId.options;
const FATAL = ["FIRECRAWL_AUTH", "FIRECRAWL_CREDITS"];
const DAY_MS = 24 * 60 * 60 * 1000;

// Upper bound per run: one search per store per item and at most two product
// pages per store (see FirecrawlScraper.source).
export function estimateRequests(basket: OnboardingBasketData) {
  const n = basket.items.length * RETAILERS.length;
  return { search: n, scrapeMax: n * 2 };
}

const fresh = (r: RawListing, maxAgeMs: number) => {
  const age = Date.now() - Date.parse(r.checkedAt);
  return age >= 0 && age < maxAgeMs;
};

export async function precomputeBasket(
  options: PrecomputeOptions,
): Promise<PrecomputeReport> {
  const report: PrecomputeReport = {
    items: [],
    scrapedItems: 0,
    skippedItems: 0,
    savedListings: 0,
    fatal: null,
  };
  const log = options.log ?? (() => {});
  const freshFor = options.freshForMs ?? 4 * DAY_MS;
  for (const item of options.basket.items) {
    const entry = await precomputeItem(item, options, freshFor);
    report.items.push(entry.report);
    if (entry.scraped) report.scrapedItems++;
    else report.skippedItems++;
    report.savedListings += entry.saved;
    log(
      `${item.id}: ${RETAILERS.map((id) => `${id}=${entry.report.retailers[id]}`).join(" ")}` +
        (entry.report.errors.length
          ? ` (${entry.report.errors.join(", ")})`
          : ""),
    );
    const fatal = entry.report.errors.find((code) => FATAL.includes(code));
    if (fatal) {
      report.fatal = fatal;
      break;
    }
  }
  return report;
}

async function precomputeItem(
  item: BasketItem,
  options: PrecomputeOptions,
  freshFor: number,
) {
  const signal = AbortSignal.timeout(options.itemTimeoutMs ?? 180_000);
  const query: ScrapeQuery = { query: item.query, maxResults: 2 };
  const errors: string[] = [];
  let cached: RawListing[] = [];
  try {
    cached = z
      .array(ScrapedListing)
      .parse(await options.repository.search(query, signal))
      .filter((r) => fresh(r, freshFor));
  } catch {
    errors.push("CACHE_FAILED");
  }
  const has = (rows: RawListing[], id: RetailerId) =>
    rows.some((r) => isSameProduct(r, item, id));
  const retailers = Object.fromEntries(
    RETAILERS.map((id) => [id, has(cached, id) ? "cached" : "missing"]),
  ) as Record<RetailerId, RetailerStatus>;
  const report: ItemReport = {
    id: item.id,
    name: item.name,
    retailers,
    errors,
  };
  if (!options.force && RETAILERS.every((id) => retailers[id] === "cached"))
    return { report, scraped: false, saved: 0 };
  let saved = 0;
  try {
    const batch = await options.scraper.scrape(query, signal);
    errors.push(...new Set(batch.errors.map((e) => e.code)));
    const listings = z.array(ScrapedListing).parse(batch.listings);
    if (listings.length) {
      try {
        await options.repository.upsert(listings, query, signal);
        saved = listings.length;
        for (const id of RETAILERS)
          if (has(listings, id)) retailers[id] = "scraped";
      } catch {
        errors.push("SAVE_FAILED");
      }
    }
  } catch {
    errors.push(signal.aborted ? "SOURCE_TIMEOUT" : "SOURCE_FAILED");
  }
  return { report, scraped: true, saved };
}
