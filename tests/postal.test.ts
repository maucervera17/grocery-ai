import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { verifyPostal, postalActions } from "../scrapers/postal.js";
import { RETAILERS, parseProduct, type Page } from "../scrapers/retailers.js";
import { createSearch } from "../backend/service.js";
const page: Page = JSON.parse(
  readFileSync("fixtures/walmart.scrape.json", "utf8"),
);
const source = RETAILERS[2];
const item = {
  client_item_id: "milk",
  name: "leche entera",
  quantity: 1,
  unit: "L" as const,
  notes: null,
};
const row = parseProduct(source, String(page.metadata!.url), page);
const proof = verifyPostal(source, page, "11220");
test("postal proof comes from delivery section, never from input or another CP", () => {
  assert.equal(proof.postalCode, "11220");
  assert.throws(() => verifyPostal(source, page, "52997"), /52997/);
  assert.throws(() =>
    verifyPostal(
      source,
      {
        ...page,
        markdown:
          page.markdown!.replace("11220", "00000") + "\nCódigo postal: 52997",
      },
      "52997",
    ),
  );
});
test("blocked, unavailable and related-product evidence cannot verify destination", () => {
  for (const text of [
    "¿Robot o humano?",
    "Agotado",
    "No disponible para envío",
  ])
    assert.throws(() =>
      verifyPostal(
        source,
        {
          ...page,
          markdown: page.markdown!.replace(
            "# Leche Great Value entera 1 l",
            "# Leche Great Value entera 1 l\n" + text,
          ),
        },
        "11220",
      ),
    );
  assert.throws(() =>
    verifyPostal(
      source,
      {
        ...page,
        markdown:
          "# Leche Great Value entera 1 l\nPrecio actual MXN$20.00\n## Artículos similares\nEnvío desde tienda, hoy a\nCiudad, 11220\nAgregar al carrito",
      },
      "11220",
    ),
  );
});
test("postal actions reject malformed codes and address-only retailers", () => {
  assert.throws(() => postalActions(source, "52997;code"));
  assert.throws(() => postalActions(RETAILERS[0], "52997"), /dirección/);
  assert.ok(
    postalActions(source, "52997").some(
      (a) => "text" in a && a.text === "52997",
    ),
  );
});
async function compare(rows: (typeof row)[]) {
  return createSearch({
    mode: "live",
    fixtures: [],
    repository: { search: async () => rows, upsert: async () => {} },
    scraper: { scrape: async () => ({ listings: [], errors: [] }) },
  })({ action: "compare", items: [item], location: { postal_code: "11220" } });
}
test("legacy cache, mismatched CP and expired availability are excluded", async () => {
  for (const r of [
    row,
    { ...row, locationEvidence: { ...proof, postalCode: "52997" } },
    {
      ...row,
      locationEvidence: proof,
      checkedAt: new Date(Date.now() - 301000).toISOString(),
    },
  ]) {
    const result = await compare([r]);
    assert.equal(result.plan!.stores.length, 0);
  }
});
test("fresh proven delivery can be complete and exposes verified postal code", async () => {
  const result = await compare([
    { ...row, locationEvidence: proof, checkedAt: new Date().toISOString() },
  ]);
  assert.equal(result.status, "complete");
  assert.equal(result.plan!.stores[0].items[0].verified_postal_code, "11220");
  assert.ok(!result.errors.some((e) => e.code === "LOCATION_UNVERIFIED"));
});

test("pickup proof requires applied branch and available primary product", async () => {
  const { verifyPickup } = await import("../scrapers/postal.js");
  // Synthetic page shapes, not a live price observation.
  const pickupPage = {
    metadata: { title: "Leche Santa Clara Entera 1L" },
    markdown:
      "Recoger en: Super Chedraui Bellavista\n# Leche Santa Clara Entera 1L\n$33.00\nAgregar\n## Información",
  };
  assert.equal(verifyPickup(pickupPage).fulfillment, "pickup");
  assert.equal(verifyPickup(pickupPage).postalCode, "52994");
  for (const markdown of [
    pickupPage.markdown.replace("Bellavista", "Otra sucursal"),
    pickupPage.markdown.replace("Agregar", "Agotado"),
    pickupPage.markdown + "\nEstamos actualizando",
    pickupPage.markdown.replace("Agregar", "## Información\nAgregar"),
  ])
    assert.throws(() => verifyPickup({ ...pickupPage, markdown }));
});

test("pickup and delivery cache cannot cross fulfillment or retailer", async () => {
  const pickupProof = {
    postalCode: "52994",
    fulfillment: "pickup" as const,
    storeName: "Super Chedraui Bellavista",
    availability: "in_stock" as const,
    text: "Synthetic test evidence",
  };
  const picked = {
    ...row,
    source: "chedraui",
    storeName: pickupProof.storeName,
    locationEvidence: pickupProof,
    checkedAt: new Date().toISOString(),
  };
  const request = {
    action: "compare" as const,
    items: [item],
    location: {
      postal_code: "52994",
      fulfillment: "pickup" as const,
      pickup_store: "chedraui-bellavista" as const,
    },
  };
  for (const candidate of [
    picked,
    { ...picked, source: "walmart" },
    {
      ...picked,
      locationEvidence: { ...pickupProof, fulfillment: "delivery" as const },
    },
  ]) {
    const search = createSearch({
      mode: "live",
      fixtures: [],
      repository: { search: async () => [candidate], upsert: async () => {} },
      scraper: { scrape: async () => ({ listings: [], errors: [] }) },
    });
    const result = await search(request);
    assert.equal(result.plan!.stores.length, candidate === picked ? 1 : 0);
    const delivery = await search({
      ...request,
      location: { postal_code: "52994", fulfillment: "delivery" },
    });
    if (candidate.locationEvidence.fulfillment === "pickup")
      assert.equal(delivery.plan!.stores.length, 0);
  }
});
