import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  productImage,
  parseProduct,
  RETAILERS,
} from "../scrapers/retailers.js";
test("product photos come from primary metadata, not recommended items or logos", () => {
  for (const source of RETAILERS) {
    const page = JSON.parse(
      readFileSync(`fixtures/${source.id}.scrape.json`, "utf8"),
    );
    const image = productImage(page);
    assert.ok(image?.startsWith("https://"));
    assert.equal(parseProduct(source, page.metadata.url, page).imageUrl, image);
  }
});
test("invalid or unrelated images are omitted without breaking product parsing", () => {
  for (const url of [
    "javascript:alert(1)",
    "https://evil.example/photo.jpg",
    "https://i5.walmartimages.com/dfw/logo.png",
    "https://user:pass@i5-mx.walmartimages.com/asr/photo.jpg",
  ])
    assert.equal(productImage({ metadata: { ogImage: url } }), undefined);
  assert.equal(
    productImage({
      markdown: "![unrelated](https://i5-mx.walmartimages.com/asr/other.jpg)",
    }),
    undefined,
  );
});

test("a nonreturnable Axe product is not mistaken for out of stock", () => {
  const page = JSON.parse(readFileSync("fixtures/axe.scrape.json", "utf8"));
  const row = parseProduct(RETAILERS[1], page.metadata.url, page);
  assert.equal(row.priceCents, 8400);
  assert.equal(row.quantity, 150);
  assert.equal(row.unit, "ml");
  assert.ok(row.imageUrl);
  assert.throws(
    () =>
      parseProduct(RETAILERS[1], page.metadata.url, {
        ...page,
        markdown: page.markdown.replace("Agregar al carrito", "Agotado"),
      }),
    /Unavailable/,
  );
});

test("unavailable alternate variant does not hide selected Ariel price", () => {
  const page = JSON.parse(
    readFileSync("fixtures/ariel-variants.scrape.json", "utf8"),
  );
  const row = parseProduct(RETAILERS[2], page.metadata.url, page);
  assert.equal(row.quantity, 4);
  assert.equal(row.unit, "kg");
  assert.equal(row.priceCents, 17500);
  assert.throws(
    () =>
      parseProduct(RETAILERS[2], page.metadata.url, {
        ...page,
        markdown: page.markdown.replace(
          "Tamaño:1 Bolsa de 4 Kg",
          "Tamaño:1 Bolsa de 800 g",
        ),
      }),
    /Unavailable/,
  );
});
test("Chedraui discounted primary price can share its line with the previous price", () => {
  const page = JSON.parse(
    readFileSync("fixtures/pasta-discount.scrape.json", "utf8"),
  );
  const row = parseProduct(RETAILERS[0], page.metadata.url, page);
  assert.equal(row.priceCents, 1590);
  assert.equal(row.quantity, 400);
});
test("explicit per-kg meat has a one-kilo price basis; unspecified sizes still fail", () => {
  const original = JSON.parse(
    readFileSync("fixtures/walmart.scrape.json", "utf8"),
  );
  const page = structuredClone(original);
  page.markdown = "# Carne molida de res por kg\n\nPrecio actual MXN$180.00\n";
  page.metadata.ogTitle = "Carne molida de res por kg";
  const parsed = parseProduct(RETAILERS[2], page.metadata.url, page);
  assert.equal(parsed.quantity, 1);
  assert.equal(parsed.unit, "kg");
  assert.equal(parsed.priceCents, 18000);
  page.markdown = "# Carne molida de res\n\nPrecio actual MXN$180.00\n";
  page.metadata.ogTitle = "Carne molida de res";
  assert.throws(() => parseProduct(RETAILERS[2], page.metadata.url, page));
});

test("fresh-food price per kilo is not assigned to the approximate tray weight", () => {
  const page = JSON.parse(readFileSync("fixtures/walmart.scrape.json", "utf8"));
  const title =
    "Pechuga de pollo sin hueso por Kilogramo Peso Aproximado por Charola 600 g a 700 g";
  page.metadata.ogTitle = title;
  page.markdown = "# " + title + "\nPrecio actual $180.00/kg\n";
  const result = parseProduct(RETAILERS[2], page.metadata.url, page);
  assert.equal(result.quantity, 1);
  assert.equal(result.unit, "kg");
  assert.equal(result.priceCents, 18000);
});
