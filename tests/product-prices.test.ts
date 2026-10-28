import test from "node:test";
import assert from "node:assert/strict";
import { createSearch } from "../backend/service.js";
import {
  SearchResponse,
  SearchRequest,
  type RawListing,
} from "../contracts/schema.js";
const milk = {
  client_item_id: "old",
  name: "leche",
  quantity: 2,
  unit: "L" as const,
  notes: null,
};
const question = {
  action: "product_prices" as const,
  message:
    "Hola, quiero revisar el queso oaxaca en que tienda tiene el mejor precio?",
  items: [milk],
  location: { postal_code: "52997" },
};
const agent = {
  interpret: async (_text: string, items: unknown[]) => {
    assert.deepEqual(items, []);
    return {
      operations: [
        {
          type: "add" as const,
          item: {
            name: "queso oaxaca",
            quantity: 1,
            unit: "piece" as const,
            notes: null,
          },
        },
      ],
      clarification: null,
    };
  },
};
const listing = (
  source: string,
  priceCents: number,
  quantity: number,
  unit: "g" | "kg",
): RawListing => ({
  source,
  retailer: source,
  productName: "Queso Oaxaca " + quantity + unit,
  quantity,
  unit,
  priceCents,
  currency: "MXN",
  checkedAt: new Date().toISOString(),
  productUrl: "https://www.walmart.com.mx/ip/queso/00" + priceCents,
});
test("natural language price query compares normalized presentations without modifying old basket or claiming postal stock", async () => {
  let requested = false;
  const search = createSearch({
    mode: "live",
    fixtures: [],
    agent,
    scraper: {
      scrape: async (q) => {
        requested = true;
        assert.equal(q.query, "queso oaxaca");
        assert.equal(q.postalCode, undefined);
        return {
          listings: [
            listing("A", 6400, 400, "g"),
            listing("B", 14000, 1, "kg"),
          ],
          errors: [],
        };
      },
    },
  });
  const result = SearchResponse.parse(
    await search(SearchRequest.parse(question)),
  );
  assert.ok(requested);
  assert.deepEqual(result.draft_items, [milk]);
  assert.equal(result.plan, null);
  assert.equal(result.comparison!.offers[0].listing.retailer, "B");
  assert.equal(result.comparison!.offers[0].unit_price_cents_per_100, 1400);
  assert.equal(result.comparison!.requested_postal_code, "52997");
  assert.match(result.reply, /no confirman existencias/);
  assert.equal(result.status, "partial");
});
test("a failed source does not suppress real alternatives", async () => {
  const result = await createSearch({
    mode: "live",
    fixtures: [],
    agent,
    scraper: {
      scrape: async () => ({
        listings: [listing("A", 6400, 400, "g"), listing("B", 9200, 400, "g")],
        errors: [
          {
            source: "chedraui",
            code: "SOURCE_FAILED",
            message: "Chedraui no respondió",
            retryable: true,
          },
        ],
      }),
    },
  })(question);
  assert.equal(result.comparison!.offers.length, 2);
  assert.equal(result.errors[0].code, "SOURCE_FAILED");
  assert.match(result.reply, /A tiene/);
});
test("no source data never becomes a fabricated winner", async () => {
  const result = await createSearch({
    mode: "live",
    fixtures: [listing("fake", 100, 400, "g")],
    agent,
    scraper: { scrape: async () => ({ listings: [], errors: [] }) },
  })(question);
  assert.equal(result.status, "error");
  assert.equal(result.comparison!.winner_url, null);
  assert.equal(result.comparison!.offers.length, 0);
});
test("clarification preserves the draft and does not scrape", async () => {
  const result = await createSearch({
    mode: "live",
    fixtures: [],
    agent: {
      interpret: async () => ({
        operations: [],
        clarification: "¿Qué producto?",
      }),
    },
    scraper: {
      scrape: async () => {
        throw Error("must not call");
      },
    },
  })(question);
  assert.equal(result.reply, "¿Qué producto?");
  assert.deepEqual(result.draft_items, [milk]);
  assert.equal(result.comparison, undefined);
});

test("each local postal query excludes another postal code and unverified offers", async () => {
  for (const cp of ["06170", "09410", "03104"]) {
    const row = listing("A", 6400, 400, "g");
    const valid = {
      ...row,
      locationEvidence: {
        postalCode: cp,
        fulfillment: "delivery" as const,
        availability: "in_stock" as const,
        text: "Synthetic confirmed destination",
      },
    };
    let queried = "";
    const result = await createSearch({
      mode: "live",
      fixtures: [],
      agent,
      repository: {
        search: async () => [
          row,
          {
            ...valid,
            locationEvidence: {
              ...valid.locationEvidence,
              postalCode: "52997",
            },
          },
        ],
        upsert: async () => {},
      },
      scraper: {
        scrape: async (q) => {
          queried = q.postalCode!;
          return { listings: [valid, row], errors: [] };
        },
      },
    })({
      ...question,
      price_scope: "local" as const,
      location: { postal_code: cp },
    });
    assert.equal(queried, cp);
    assert.equal(result.comparison!.scope, "local");
    assert.equal(result.comparison!.offers.length, 1);
    assert.equal(
      result.comparison!.offers[0].listing.locationEvidence!.postalCode,
      cp,
    );
    assert.match(result.reply, new RegExp(cp));
  }
});
test("local failure cannot silently return published prices", async () => {
  const result = await createSearch({
    mode: "live",
    fixtures: [],
    agent,
    scraper: {
      scrape: async () => ({
        listings: [listing("A", 6400, 400, "g")],
        errors: [],
      }),
    },
  })({ ...question, price_scope: "local" as const });
  assert.equal(result.comparison!.offers.length, 0);
  assert.equal(result.comparison!.winner_url, null);
});

test("mixed presentations have separate unit winners, never a grams-versus-milliliters winner", async () => {
  const ml = (source: string, price: number) => ({
    ...listing(source, price, 150, "g"),
    unit: "ml" as const,
  });
  const result = await createSearch({
    mode: "live",
    fixtures: [],
    agent,
    scraper: {
      scrape: async () => ({
        listings: [ml("A", 8400), ml("B", 8500), listing("C", 7200, 45, "g")],
        errors: [],
      }),
    },
  })(question);
  assert.equal(result.comparison!.winner_url, null);
  assert.equal(result.comparison!.unit_winners!.length, 1);
  assert.equal(result.comparison!.unit_winners![0].basis, "ml");
  assert.match(result.reply, /A tiene el menor/);
});
