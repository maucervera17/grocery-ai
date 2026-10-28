import test from "node:test";
import assert from "node:assert/strict";
import { matches, tokens } from "../backend/normalize.js";
test("plural supermarket categories and explicit common typo normalize without changing unrelated brands", () => {
  assert.deepEqual(tokens("Desodorantes Axxe"), ["desodorante", "axe"]);
  assert.ok(
    matches(
      "Desodorante en aerosol Axe dark temptation 150 ml",
      "desodorantes Axxe",
    ),
  );
  assert.ok(matches("Huevo blanco San Juan 30 piezas", "huevos"));
  assert.ok(matches("Detergente Ariel líquido 1 L", "detergentes Ariel"));
  assert.equal(tokens("Dove")[0], "dove");
});
