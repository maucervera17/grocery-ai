import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const app = readFileSync("web/app.js", "utf8");
const weekly = readFileSync("web/weekly.js", "utf8");

test("main flows validate inline instead of using alert()", () => {
  assert.doesNotMatch(app, /\balert\(/);
  assert.doesNotMatch(weekly, /\balert\(/);
});
test("API errors keep the server message, rate limits and offline copy", () => {
  assert.match(app, /r\.status===429\?/);
  assert.match(app, /d\?\.reply\|\|d\?\.message/);
  assert.match(app, /e instanceof TypeError\?OFFLINE/);
  assert.doesNotMatch(app, /Failed to fetch/);
});
test("weekly list accepts labelled demo comparisons and never links demo offers", () => {
  assert.doesNotMatch(weekly, /data_mode === "live"/);
  assert.match(weekly, /Precios de ejemplo/);
  assert.match(weekly, /snapshot\.demo \?/);
});
test("the unreachable legacy basket flow is gone", () => {
  for (const name of ["selectionEditor", "renderBasket", "checkout", "quoteCart"])
    assert.doesNotMatch(app, new RegExp(name));
});
