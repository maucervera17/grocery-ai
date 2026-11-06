import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  estimateRequests,
  precomputeBasket,
} from "../backend/basket-precompute.js";
import {
  OnboardingBasket,
  type RawListing,
  type ScrapeQuery,
} from "../contracts/schema.js";
import type { ListingRepository } from "../backend/repository.js";
import type { Scraper } from "../scrapers/firecrawl.js";

const full = OnboardingBasket.parse(
  JSON.parse(readFileSync("./fixtures/onboarding-basket.json", "utf8")),
);
const basket = { ...full, items: full.items.slice(0, 2) };
const [huevo, leche] = basket.items;
const host = {
  walmart: ["walmart", "Walmart"],
  bodega_aurrera: ["bodega-aurrera", "Bodega Aurrera"],
  chedraui: ["chedraui", "Chedraui"],
} as const;
const listing = (
  item: (typeof basket.items)[number],
  store: keyof typeof host,
  checkedAt = new Date().toISOString(),
): RawListing => ({
  source: host[store][0],
  retailer: host[store][1],
  productName: item.name,
  brand: item.brand,
  quantity: item.quantity,
  unit: item.unit,
  priceCents: 5000,
  currency: "MXN",
  productUrl: `https://example.com/${store}/${item.id}`,
  checkedAt,
});

function memoryRepository(rows: RawListing[] = []) {
  const upserts: { listings: RawListing[]; query: ScrapeQuery }[] = [];
  const repository: ListingRepository = {
    async search(query) {
      return rows.filter((r) =>
        r.productUrl.endsWith(
          `/${query.query === huevo.query ? huevo.id : leche.id}`,
        ),
      );
    },
    async upsert(listings, query) {
      upserts.push({ listings, query });
    },
  };
  return { repository, upserts };
}
function fakeScraper(
  answer: (q: ScrapeQuery) => Awaited<ReturnType<Scraper["scrape"]>>,
) {
  const calls: ScrapeQuery[] = [];
  const scraper: Scraper = {
    async scrape(q) {
      calls.push(q);
      return answer(q);
    },
  };
  return { scraper, calls };
}

test("estima el máximo de consultas de Firecrawl por corrida", () => {
  assert.deepEqual(estimateRequests(basket), { search: 6, scrapeMax: 12 });
});

test("consulta sin CP y guarda lo que encuentra, marcando las tiendas sin el producto", async () => {
  const { repository, upserts } = memoryRepository();
  const { scraper, calls } = fakeScraper((q) => {
    const item = q.query === huevo.query ? huevo : leche;
    return {
      listings: [listing(item, "walmart"), listing(item, "chedraui")],
      errors: [],
    };
  });
  const report = await precomputeBasket({ basket, scraper, repository });
  assert.equal(calls.length, 2);
  assert.ok(calls.every((q) => q.postalCode === undefined));
  assert.equal(upserts.length, 2);
  assert.equal(report.savedListings, 4);
  assert.deepEqual(report.items[0].retailers, {
    walmart: "scraped",
    bodega_aurrera: "missing",
    chedraui: "scraped",
  });
  assert.equal(report.fatal, null);
});

test("omite productos con precio reciente en las tres tiendas, salvo con force", async () => {
  const rows = (["walmart", "bodega_aurrera", "chedraui"] as const).map((s) =>
    listing(huevo, s),
  );
  const stale = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString();
  rows.push(listing(leche, "walmart", stale));
  const { repository } = memoryRepository(rows);
  const { scraper, calls } = fakeScraper(() => ({ listings: [], errors: [] }));
  const report = await precomputeBasket({ basket, scraper, repository });
  assert.deepEqual(
    calls.map((q) => q.query),
    [leche.query],
  );
  assert.equal(report.skippedItems, 1);
  assert.equal(report.items[1].retailers.walmart, "missing");
  await precomputeBasket({ basket, scraper, repository, force: true });
  assert.equal(calls.length, 3);
});

test("se detiene si Firecrawl se queda sin créditos", async () => {
  const { repository } = memoryRepository();
  const { scraper, calls } = fakeScraper(() => ({
    listings: [],
    errors: [
      {
        source: "walmart",
        code: "FIRECRAWL_CREDITS",
        message: "",
        retryable: false,
      },
    ],
  }));
  const report = await precomputeBasket({ basket, scraper, repository });
  assert.equal(calls.length, 1);
  assert.equal(report.fatal, "FIRECRAWL_CREDITS");
});
