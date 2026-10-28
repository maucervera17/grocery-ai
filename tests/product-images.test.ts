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
