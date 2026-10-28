import test from "node:test";
import assert from "node:assert/strict";
import { savingsMarkup } from "../web/savings-view.js";

const money = (cents: number) => `$${(cents / 100).toFixed(2)}`;
const esc = (value: unknown) => String(value).replaceAll("<", "&lt;");

test("empty savings page distinguishes an unrecorded list from a purchase", () => {
  const html = savingsMarkup([], [{ id: "list", date: "2026-10-28", total: 32500, savings: null, stores: ["A"], products: ["Queso"] }], 0, money, esc);
  assert.match(html, /Sin compras aún/);
  assert.match(html, /Compras registradas<\/span><strong>0/);
  assert.match(html, /Solo estimación/);
  assert.match(html, /\$325\.00/);
  assert.doesNotMatch(html, /Ahorra(?:ste)? \$325/);
});

test("savings total includes only purchases with a complete habitual-price reference", () => {
  const html = savingsMarkup([
    { id: "one", date: "2026-10-28", items: [{ name: "Queso" }], paidCents: 8000, referenceCents: 10000, differenceCents: 2000 },
    { id: "two", date: "2026-10-27", items: [{ name: "Pollo" }], paidCents: 3000, referenceCents: null, differenceCents: null },
  ], [], 0, money, esc);
  assert.match(html, /\$20\.00/);
  assert.match(html, /Sin referencia/);
  assert.match(html, /\$110\.00/);
  assert.match(html, /Precio habitual que ingresaste/);
});

test("negative differences are not presented as savings", () => {
  const html = savingsMarkup([{ id: "loss", date: "2026-10-28", items: [], paidCents: 12000, referenceCents: 10000, differenceCents: -2000 }], [], 0, money, esc);
  assert.match(html, /Más que tu precio habitual declarado/);
  assert.match(html, /−\$20\.00/);
  assert.match(html, /negative/);
});
