import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { buildApp } from "../backend/app.js";
import { createSearch } from "../backend/service.js";
import { applyChanges, DemoDraftAgent } from "../backend/agent.js";
import { planBasket, candidate } from "../backend/planner.js";
import {
  SearchResponse,
  SearchRequest,
  type Item,
  type RawListing,
  type Offer,
} from "../contracts/schema.js";
import { FirecrawlScraper } from "../scrapers/firecrawl.js";
import {
  RETAILERS,
  parseProduct,
  productUrl,
  type Page,
} from "../scrapers/retailers.js";
const fixtures: RawListing[] = JSON.parse(
  readFileSync("./fixtures/listings.json", "utf8"),
);
const basket: Item[] = [
  {
    client_item_id: "milk",
    name: "leche",
    quantity: 2,
    unit: "L",
    notes: null,
  },
  {
    client_item_id: "eggs",
    name: "huevos",
    quantity: 12,
    unit: "piece",
    notes: null,
  },
  {
    client_item_id: "rice",
    name: "arroz",
    quantity: 1,
    unit: "kg",
    notes: null,
  },
];
const input = {
  action: "compare" as const,
  items: basket,
  preferences: { max_stores: 2 },
};
const pages = RETAILERS.map(
  (s) =>
    JSON.parse(readFileSync(`./fixtures/${s.id}.scrape.json`, "utf8")) as Page,
);
const urls = pages.map((p) => String(p.metadata!.sourceURL));
const mapped = (items: Item[], rows = fixtures) =>
  new Map(
    items.map((i) => [
      i.client_item_id,
      rows.map((listing) => ({ listing, status: "demo" as const })),
    ]),
  );

test("HTTP acceptance: conversational draft -> three products -> two-store plan", async () => {
  const app = buildApp({ mode: "demo", fixtures });
  try {
    const draft = await app.inject({
      method: "POST",
      url: "/v1/chat/search",
      payload: {
        action: "update_draft",
        message: "Agrega 2 litros de leche, 12 huevos y 1 kg de arroz",
        items: [],
        location: null,
      },
    });
    assert.equal(draft.statusCode, 200);
    const d = SearchResponse.parse(draft.json());
    assert.equal(d.status, "complete");
    assert.equal(d.draft_items.length, 3);
    const res = await app.inject({
      method: "POST",
      url: "/v1/chat/search",
      payload: { ...input, items: d.draft_items },
    });
    const body = SearchResponse.parse(res.json());
    assert.equal(body.status, "complete");
    assert.equal(body.plan!.stores.length, 2);
    assert.equal(body.plan!.total_price_cents, 13400);
    assert.equal(body.plan!.estimated_savings_cents, 600);
    assert.ok(
      body
        .plan!.stores.flatMap((s) => s.items)
        .every((i) => i.data_status === "demo"),
    );
    assert.match(body.reply, /DEMO/);
  } finally {
    await app.close();
  }
});
test("draft operations preserve IDs, notes and unrelated items without mutation", async () => {
  const original = structuredClone(basket),
    agent = new DemoDraftAgent();
  const ops = await agent.interpret(
    "Cambia leche a 3 litros",
    basket,
    AbortSignal.timeout(1000),
  );
  const updated = applyChanges(basket, ops).items;
  assert.equal(updated[0].client_item_id, "milk");
  assert.equal(updated[0].quantity, 3);
  assert.deepEqual(updated.slice(1), basket.slice(1));
  assert.deepEqual(basket, original);
  const remove = await agent.interpret(
    "Quita huevos",
    updated,
    AbortSignal.timeout(1000),
  );
  assert.equal(applyChanges(updated, remove).items.length, 2);
});
test("unknown agent IDs and invalid quantities are rejected transactionally", () => {
  assert.throws(() =>
    applyChanges(basket, {
      operations: [{ type: "remove", client_item_id: "invented" }],
      clarification: null,
    }),
  );
  assert.throws(() =>
    applyChanges(basket, {
      operations: [
        {
          type: "add",
          item: { name: "leche", quantity: -1, unit: "L", notes: null },
        },
      ],
      clarification: null,
    }),
  );
  assert.equal(basket.length, 3);
});
test("clarification never applies partial agent operations", () => {
  const changed = applyChanges(basket, {
    operations: [{ type: "remove", client_item_id: "milk" }],
    clarification: "¿Cuál leche?",
  });
  assert.deepEqual(changed.items, basket);
});
test("agent failures return original draft and stable contract", async () => {
  const search = createSearch({
    mode: "live",
    fixtures,
    agent: {
      interpret: async () => {
        throw Error("secret provider error");
      },
    },
  });
  const out = await search({
    action: "update_draft",
    message: "agrega leche",
    items: basket,
  });
  assert.equal(out.status, "error");
  assert.deepEqual(out.draft_items, basket);
  assert.ok(!JSON.stringify(out).includes("secret"));
  SearchResponse.parse(out);
});
test("max_stores changes optimum and savings reference is complete one-store basket", () => {
  const p = planBasket(basket, mapped(basket), 1);
  assert.equal(p.stores.length, 1);
  assert.equal(p.total_price_cents, 14000);
  assert.equal(p.estimated_savings_cents, 0);
  const two = planBasket(basket, mapped(basket), 2);
  assert.equal(two.total_price_cents, 13400);
});
test("round up packages and convert kg/g, L/ml, dozen/piece without float off-by-one", () => {
  const milk = { ...basket[0], quantity: 1500, unit: "ml" as const };
  assert.equal(
    candidate(milk, { listing: fixtures[0], status: "demo" })!.line
      .package_count,
    2,
  );
  const rice = { ...basket[2], quantity: 1.2 };
  assert.equal(
    candidate(rice, {
      listing: { ...fixtures[2], quantity: 400, unit: "g" },
      status: "demo",
    })!.line.package_count,
    3,
  );
  assert.equal(
    candidate(
      { ...basket[1], quantity: 2, unit: "dozen" },
      { listing: fixtures[1], status: "demo" },
    )!.line.package_count,
    2,
  );
});
test("selected plan lines preserve optional product images", () => {
  const imageUrl = "https://cdn.example.com/products/milk.jpg";
  const line = candidate(basket[0], {
    listing: { ...fixtures[0], imageUrl },
    status: "verified",
  })!.line;
  assert.equal(line.image_url, imageUrl);
  assert.equal(
    candidate(basket[0], { listing: fixtures[0], status: "verified" })!.line
      .image_url,
    undefined,
  );
});
test("minimize actual spend, not unit price or cheapest package sticker", () => {
  const item = { ...basket[0], quantity: 1 };
  const rows = [
    { ...fixtures[0], quantity: 2, priceCents: 4000 },
    { ...fixtures[3], quantity: 1, priceCents: 3000 },
  ];
  assert.equal(
    planBasket([item], mapped([item], rows), 2).total_price_cents,
    3000,
  );
});
test("unknown sizes, incompatible units and dietary notes are not silently substituted", () => {
  assert.equal(
    candidate(basket[0], {
      listing: { ...fixtures[0], unit: "kg" },
      status: "demo",
    }),
    null,
  );
  assert.equal(
    candidate(basket[0], {
      listing: { ...fixtures[0], quantity: undefined },
      status: "demo",
    }),
    null,
  );
  const item = { ...basket[0], notes: "sin lactosa" };
  const p = planBasket([item], mapped([item]), 2);
  assert.equal(p.unmatched_items[0].reason, "NOTES_REQUIRE_REVIEW");
  assert.equal(p.estimated_savings_cents, null);
});
test("partial plan maximizes coverage, and never claims savings for incomplete baskets", () => {
  const items = [
    ...basket,
    {
      client_item_id: "x",
      name: "manzanas",
      quantity: 1,
      unit: "kg" as const,
      notes: null,
    },
  ];
  const p = planBasket(items, mapped(items), 2);
  assert.equal(p.unmatched_items.length, 1);
  assert.equal(p.estimated_savings_cents, null);
});
test("branch identity counts separate branches as separate stores", () => {
  const offers = new Map<string, Offer[]>(
    basket.map((i, n) => [
      i.client_item_id,
      [
        {
          listing: {
            ...fixtures[n],
            retailer: "Same",
            storeName: "Branch " + n,
          },
          status: "demo",
        },
      ],
    ]),
  );
  const p = planBasket(basket, offers, 2);
  assert.equal(p.stores.length, 2);
  assert.equal(p.unmatched_items.length, 1);
});
test("fresh candidates take precedence over stale cheaper offers", () => {
  const item = basket[0];
  const offers = new Map<string, Offer[]>([
    [
      "milk",
      [
        { listing: fixtures[0], status: "verified" },
        { listing: { ...fixtures[3], priceCents: 1 }, status: "stale" },
      ],
    ],
  ]);
  assert.equal(planBasket([item], offers, 2).total_price_cents, 6000);
});
test("live unconfigured mode never substitutes demo prices", async () => {
  const out = await createSearch({ mode: "live", fixtures })(input);
  assert.equal(out.status, "error");
  assert.equal(out.plan!.stores.length, 0);
});
test("fresh cache covers all retailers and avoids Firecrawl", async () => {
  let calls = 0;
  const search = createSearch({
    mode: "live",
    fixtures,
    repository: {
      search: async () =>
        [
          ...fixtures,
          ...fixtures.map((r) => ({
            ...r,
            source: "walmart",
            retailer: "Walmart",
            priceCents: 99999,
          })),
        ].map((r) => ({ ...r, checkedAt: new Date().toISOString() })),
      upsert: async () => {},
    },
    scraper: {
      scrape: async () => {
        calls++;
        return { listings: [], errors: [] };
      },
    },
  });
  const out = await search(input);
  assert.equal(calls, 0);
  assert.equal(out.plan!.total_price_cents, 13400);
  assert.equal(out.status, "partial");
  assert.ok(out.errors.some((e) => e.code === "LOCATION_UNVERIFIED"));
});
test("global timeout keeps stale cached data and terminates even noncooperative adapters", async () => {
  const search = createSearch({
    mode: "live",
    fixtures,
    timeoutMs: 25,
    repository: {
      search: async () =>
        fixtures.map((r) => ({ ...r, checkedAt: "2020-01-01T00:00:00Z" })),
      upsert: async () => {},
    },
    scraper: { scrape: async () => new Promise(() => {}) },
  });
  const timer = setTimeout(() => {}, 1000);
  try {
    const out = await search({ ...input, items: [basket[0]] });
    assert.equal(out.status, "partial");
    assert.equal(out.plan!.stores[0].items[0].data_status, "stale");
    assert.equal(out.plan!.estimated_savings_cents, null);
  } finally {
    clearTimeout(timer);
  }
});
test("HTTP rejects duplicate IDs, old contract, bad quantities and malformed JSON", async () => {
  const app = buildApp({ mode: "demo", fixtures });
  try {
    for (const payload of [
      { message: "leche" },
      { ...input, items: [basket[0], basket[0]] },
      { ...input, preferences: { max_stores: 3 } },
      { ...input, items: [{ ...basket[0], quantity: 0 }] },
    ]) {
      const res = await app.inject({
        method: "POST",
        url: "/v1/chat/search",
        payload,
      });
      assert.equal(res.statusCode, 400);
      SearchResponse.parse(res.json());
    }
    const res = await app.inject({
      method: "POST",
      url: "/v1/chat/search",
      headers: { "content-type": "application/json" },
      payload: "{",
    });
    assert.equal(res.statusCode, 400);
    SearchResponse.parse(res.json());
  } finally {
    await app.close();
  }
});
test("captured Chedraui page parses primary product price, not combo or related products", () => {
  const r = parseProduct(RETAILERS[0], urls[0], pages[0]);
  assert.equal(r.priceCents, 3300);
  assert.equal(r.quantity, 1);
  assert.equal(r.unit, "L");
  assert.equal(r.storeName, undefined);
});
test("captured Aurrera page preserves selected variant, cached timestamp and observed branch", () => {
  const r = parseProduct(RETAILERS[1], urls[1], pages[1]);
  assert.equal(r.priceCents, 3200);
  assert.equal(r.regularPriceCents, 3500);
  assert.equal(r.quantity, 1);
  assert.equal(r.storeName, "BA CANTIL");
  assert.equal(r.checkedAt, pages[1].metadata!.cachedAt);
});
test("parsers reject robots, stale hits without timestamp, redirects and ambiguous size", () => {
  assert.throws(() =>
    parseProduct(RETAILERS[0], urls[0], { markdown: "captcha" }),
  );
  assert.throws(() =>
    parseProduct(RETAILERS[1], urls[1], {
      ...pages[1],
      metadata: { ...pages[1].metadata, cachedAt: undefined },
    }),
  );
  assert.equal(
    productUrl(
      "https://www.bodegaaurrera.com.mx.evil.test/ip/x/123",
      RETAILERS[1],
    ),
    null,
  );
  assert.equal(
    productUrl("http://www.chedraui.com.mx/x/p", RETAILERS[0]),
    null,
  );
});
test("Firecrawl searches then scrapes only allowed product pages; snippets are not prices", async () => {
  let calls = 0;
  const fetcher: typeof fetch = async (url, init) => {
    calls++;
    const p = JSON.parse(init!.body as string);
    if (String(url).endsWith("/search")) {
      const i = RETAILERS.findIndex((r) => r.host === p.includeDomains[0]);
      return Response.json({
        success: true,
        data: { web: [{ url: urls[i] }, { url: "https://evil.test/product" }] },
      });
    }
    assert.equal(p.maxAge, 0);
    assert.equal(p.proxy, "basic");
    return Response.json({
      success: true,
      data: pages[urls.indexOf(p.url)],
    });
  };
  const result = await new FirecrawlScraper("test", fetcher).scrape(
    { query: "leche" },
    AbortSignal.timeout(1000),
  );
  assert.equal(calls, RETAILERS.length * 2);
  assert.equal(result.listings.length, RETAILERS.length);
  assert.equal(result.errors.length, 0);
});
test("Firecrawl does not retry auth errors; retries temporary errors once per source", async () => {
  let count = 0;
  const unauthorized = await new FirecrawlScraper("test", async () => {
    count++;
    return new Response("{}", { status: 401 });
  }).scrape({ query: "leche" }, AbortSignal.timeout(1000));
  assert.equal(count, RETAILERS.length);
  assert.equal(unauthorized.errors[0].code, "FIRECRAWL_AUTH");
  count = 0;
  await new FirecrawlScraper("test", async () => {
    count++;
    return new Response("{}", { status: 503 });
  }).scrape({ query: "leche" }, AbortSignal.timeout(2000));
  assert.equal(count, RETAILERS.length * 2);
});
test("empty comparison is valid and does not invent savings", async () => {
  const out = await createSearch({ mode: "demo", fixtures })({
    action: "compare",
    items: [],
  });
  SearchResponse.parse(out);
  assert.equal(out.plan!.total_price_cents, 0);
  assert.equal(out.plan!.estimated_savings_cents, null);
});
test("Walmart uses primary price and observed branch, rejecting related-only prices", () => {
  const r = parseProduct(RETAILERS[2], urls[2], pages[2]);
  assert.equal(r.retailer, "Walmart");
  assert.equal(r.priceCents, 2000);
  assert.equal(r.quantity, 1);
  assert.equal(r.unit, "L");
  assert.equal(r.storeName, "SC TOREO");
  assert.equal(productUrl(urls[2], RETAILERS[1]), null);
  assert.equal(
    productUrl(
      "https://www.walmart.com.mx.evil.test/ip/milk/123",
      RETAILERS[2],
    ),
    null,
  );
  assert.throws(
    () =>
      parseProduct(RETAILERS[2], urls[2], {
        ...pages[2],
        markdown:
          "# Leche Great Value entera 1 l\n## Artículos similares\nPrecio actual MXN$1.00",
      }),
    /Missing price/,
  );
});
test("third retailer can win while the planner preserves the one/two-store limit", () => {
  const walmart = {
    ...fixtures[0],
    source: "walmart",
    retailer: "Walmart",
    priceCents: 1000,
  };
  const offers = mapped(basket, [...fixtures, walmart]);
  const two = planBasket(basket, offers, 2);
  assert.ok(two.stores.some((s) => s.retailer === "Walmart"));
  assert.equal(two.stores.length, 2);
  assert.equal(two.unmatched_items.length, 0);
  const one = planBasket(basket, offers, 1);
  assert.equal(one.stores.length, 1);
  assert.equal(one.unmatched_items.length, 0);
});
test("two-source cache still refreshes to discover Walmart", async () => {
  let calls = 0;
  const item = basket[0];
  const search = createSearch({
    mode: "live",
    fixtures: [],
    repository: {
      search: async () =>
        fixtures.map((r) => ({ ...r, checkedAt: new Date().toISOString() })),
      upsert: async () => {},
    },
    scraper: {
      scrape: async () => {
        calls++;
        return {
          listings: [
            {
              ...fixtures[0],
              source: "walmart",
              retailer: "Walmart",
              priceCents: 1000,
              checkedAt: new Date().toISOString(),
            },
          ],
          errors: [],
        };
      },
    },
  });
  const result = await search({ ...input, items: [item] });
  assert.equal(calls, 1);
  assert.equal(result.plan!.stores[0].retailer, "Walmart");
});
test("second representative product: rice parses both original retailers", () => {
  RETAILERS.slice(0, 2).forEach((s, i) => {
    const page = JSON.parse(
      readFileSync(`./fixtures/${s.id}.rice.scrape.json`, "utf8"),
    );
    const r = parseProduct(s, page.metadata.sourceURL, page);
    assert.equal(r.unit, "kg");
    assert.equal(r.quantity, 1);
    assert.equal(r.priceCents, i === 0 ? 10100 : 3800);
  });
});
test("actual SDK agent executes structured output with a simulated language model", async () => {
  const { MockLanguageModelV4 } = await import("ai/test");
  const { AIDraftAgent } = await import("../backend/ai-agent.js");
  const model = new MockLanguageModelV4({
    doGenerate: async () => ({
      content: [
        {
          type: "text",
          text: JSON.stringify({
            operations: [
              {
                type: "set",
                client_item_id: "milk",
                item: { name: "leche", quantity: 3, unit: "L", notes: null },
              },
            ],
            clarification: null,
          }),
        },
      ],
      finishReason: { unified: "stop", raw: undefined },
      usage: {
        inputTokens: {
          total: 10,
          noCache: 10,
          cacheRead: undefined,
          cacheWrite: undefined,
        },
        outputTokens: { total: 20, text: 20, reasoning: undefined },
      },
      warnings: [],
    }),
  });
  const agent = new AIDraftAgent(model);
  const out = await agent.interpret(
    "Cambia leche a 3 litros",
    basket,
    AbortSignal.timeout(2000),
  );
  assert.equal(out.operations[0].type, "set");
  assert.equal(applyChanges(basket, out).items[0].quantity, 3);
  assert.equal(model.doGenerateCalls.length, 1);
});
