import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { buildApp } from "../backend/app.js";
import { isSameProduct, quoteBasket } from "../backend/onboarding-basket.js";
import {
  BasketQuoteResponse,
  OnboardingBasket,
  ScrapedListing,
  type RawListing,
} from "../contracts/schema.js";
import type { ListingRepository } from "../backend/repository.js";

const basket = OnboardingBasket.parse(
  JSON.parse(readFileSync("./fixtures/onboarding-basket.json", "utf8")),
);
const basketFixtures: RawListing[] = JSON.parse(
  readFileSync("./fixtures/onboarding-basket.listings.json", "utf8"),
).map((r: unknown) => ScrapedListing.parse(r));
const signal = () => AbortSignal.timeout(5000);

test("la canasta del onboarding tiene 40 a 50 productos con marca y presentación", () => {
  assert.ok(basket.items.length >= 40 && basket.items.length <= 50);
  for (const item of basket.items) {
    assert.ok(item.brand.length > 0);
    assert.ok(item.quantity > 0);
  }
});

test("cada producto de la canasta existe en los fixtures demo de al menos dos tiendas", () => {
  for (const item of basket.items) {
    const stores = (["walmart", "bodega_aurrera", "chedraui"] as const).filter(
      (id) => basketFixtures.some((r) => isSameProduct(r, item, id)),
    );
    assert.ok(stores.length >= 2, item.id);
  }
});

test("el demo trae algunos faltantes para probar \"No disponible\"", async () => {
  const quote = await quoteBasket(
    { retailer_id: "chedraui" },
    { mode: "demo", basket, basketFixtures },
    signal(),
  );
  assert.equal(quote.items.find((i) => i.basket_item_id === "agua")?.status, "unavailable");
});

test("demo cotiza Walmart con el mismo producto y marca lo que falta", async () => {
  const harina = basket.items.find((i) => i.id === "harina")!;
  const quote = await quoteBasket(
    { retailer_id: "walmart", postal_code: "06700" },
    {
      mode: "demo",
      basket,
      basketFixtures: basketFixtures.filter((r) => !isSameProduct(r, harina, "walmart")),
    },
    signal(),
  );
  BasketQuoteResponse.parse(quote);
  assert.equal(quote.retailer_name, "Walmart");
  assert.equal(quote.requested_postal_code, "06700");
  const missing = quote.items.find((i) => i.basket_item_id === "harina");
  assert.equal(missing?.status, "unavailable");
  assert.equal(missing?.price_cents, null);
  const huevo = quote.items.find((i) => i.basket_item_id === "huevo");
  assert.equal(huevo?.status, "priced");
  assert.equal(huevo?.data_status, "demo");
  assert.match(huevo?.product_name ?? "", /Bachoco 18/);
  assert.ok(quote.prices_checked_at);
});

test("no acepta otra presentación como el mismo producto", () => {
  const item = basket.items.find((i) => i.id === "leche")!;
  const other = { ...basketFixtures.find((r) => isSameProduct(r, item, "walmart"))!, quantity: 1.5 };
  assert.equal(isSameProduct(other, item, "walmart"), false);
});

test("live solo lee la caché reciente y nunca llama al scraper", async () => {
  let searches = 0;
  const fresh = new Date(Date.now() - 2 * 86400000).toISOString();
  const old = new Date(Date.now() - 9 * 86400000).toISOString();
  const repository: ListingRepository = {
    async search(query) {
      searches++;
      return basketFixtures
        .filter((r) => r.source === "chedraui")
        .map((r) => ({ ...r, retailer: "Chedraui", checkedAt: query.query.startsWith("huevo") ? old : fresh }));
    },
    async upsert() {
      throw new Error("no debe escribir");
    },
  };
  const quote = await quoteBasket(
    { retailer_id: "chedraui" },
    { mode: "live", basket, basketFixtures: [], repository },
    signal(),
  );
  assert.equal(searches, basket.items.length);
  assert.equal(quote.items.find((i) => i.basket_item_id === "huevo")?.status, "unavailable");
  assert.equal(quote.items.find((i) => i.basket_item_id === "leche")?.data_status, "verified");
});

test("live sin caché responde honesto, sin precios", async () => {
  const quote = await quoteBasket(
    { retailer_id: "walmart" },
    { mode: "live", basket, basketFixtures },
    signal(),
  );
  assert.ok(quote.items.every((i) => i.status === "unavailable"));
  assert.equal(quote.errors[0]?.code, "CACHE_NOT_CONFIGURED");
});

test("POST /v1/onboarding/basket valida y responde el contrato", async () => {
  const app = buildApp({ mode: "demo", fixtures: [], basket, basketFixtures });
  const bad = await app.inject({ method: "POST", url: "/v1/onboarding/basket", payload: { retailer_id: "soriana" } });
  assert.equal(bad.statusCode, 400);
  const ok = await app.inject({ method: "POST", url: "/v1/onboarding/basket", payload: { retailer_id: "bodega_aurrera", postal_code: "06700" } });
  assert.equal(ok.statusCode, 200);
  const body = BasketQuoteResponse.parse(ok.json());
  assert.deepEqual(
    body.items.filter((i) => i.status !== "priced").map((i) => i.basket_item_id),
    ["queso-amarillo"],
  );
  await app.close();
});

test("la ruta de la canasta exige contraseña cuando hay acceso configurado", async () => {
  const app = buildApp({ mode: "demo", fixtures: [], basket, basketFixtures }, {}, "prueba-local");
  const denied = await app.inject({ method: "POST", url: "/v1/onboarding/basket", payload: { retailer_id: "walmart" } });
  assert.equal(denied.statusCode, 401);
  await app.close();
});
