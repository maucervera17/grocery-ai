import type { Item } from "../contracts/schema.js";
export function canonical(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}
export function tokens(value: string): string[] {
  return canonical(value)
    .replace(/[^a-z0-9 ]/g, " ")
    .split(/\s+/)
    .filter((w) => w && !["de", "con", "el", "la", "los", "las"].includes(w))
    .map(
      (w) =>
        ({
          huevos: "huevo",
          desodorantes: "desodorante",
          antitranspirantes: "antitranspirante",
          detergentes: "detergente",
          leches: "leche",
          pastas: "pasta",
          axxe: "axe",
          spaghetti: "espagueti",
          espaguetis: "espagueti",
        })[w] ?? w,
    );
}
export function matches(name: string, query: string): boolean {
  // Preserve the relationship in "sin hueso": words elsewhere in the title
  // ("con hueso y sin piel") must not satisfy a boneless query.
  const qualifiers = [
    ...canonical(query).matchAll(
      /\b(sin|con)\s+(hueso|piel|azucar|lactosa|gluten|sal)\b/g,
    ),
  ];
  if (
    qualifiers.some(
      (q) => !new RegExp(`\\b${q[1]}\\s+${q[2]}\\b`).test(canonical(name)),
    )
  )
    return false;
  const hay = tokens(name),
    need = tokens(query).filter(
      (w) => !(w === "pasta" && tokens(query).includes("espagueti")),
    );
  return need.length > 0 && need.every((w) => hay.includes(w));
}
export function measure(
  quantity: number,
  unit: Item["unit"],
): { dimension: string; amount: number } {
  const factor =
    unit === "kg" || unit === "L" ? 1000 : unit === "dozen" ? 12 : 1;
  const dimension = ["g", "kg"].includes(unit)
    ? "mass"
    : ["ml", "L"].includes(unit)
      ? "volume"
      : ["piece", "dozen"].includes(unit)
        ? "count"
        : "package";
  // integer thousandths avoid float ceil errors at package boundaries.
  return { dimension, amount: Math.round(quantity * 1000) * factor };
}
