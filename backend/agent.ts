import { randomUUID } from "node:crypto";
import { z } from "zod";
import { DraftItem, DraftItems, type Item } from "../contracts/schema.js";
import { canonical } from "./normalize.js";
const Fields = DraftItem.omit({ client_item_id: true });
export const Operations = z
  .object({
    operations: z
      .array(
        z.discriminatedUnion("type", [
          z.object({ type: z.literal("add"), item: Fields }).strict(),
          z
            .object({
              type: z.literal("set"),
              client_item_id: z.string(),
              item: Fields,
            })
            .strict(),
          z
            .object({ type: z.literal("remove"), client_item_id: z.string() })
            .strict(),
        ]),
      )
      .max(40),
    clarification: z.string().max(500).nullable(),
  })
  .strict();
export type Changes = z.infer<typeof Operations>;
export interface DraftAgent {
  interpret(
    message: string,
    items: Item[],
    signal: AbortSignal,
  ): Promise<Changes>;
}
export function applyChanges(
  items: Item[],
  raw: unknown,
): { items: Item[]; clarification: string | null } {
  const changes = Operations.parse(raw);
  if (changes.clarification)
    return {
      items: structuredClone(items),
      clarification: changes.clarification,
    };
  const next = structuredClone(items);
  for (const op of changes.operations) {
    if (op.type === "add") {
      next.push({ ...op.item, client_item_id: randomUUID() });
      continue;
    }
    const i = next.findIndex(
      (item) => item.client_item_id === op.client_item_id,
    );
    if (i < 0) throw new Error("Unknown item ID");
    if (op.type === "remove") next.splice(i, 1);
    else next[i] = { ...op.item, client_item_id: op.client_item_id };
  }
  return { items: DraftItems.parse(next), clarification: null };
}
// Explicit offline demo grammar; live mode never silently falls back to it.
export class DemoDraftAgent implements DraftAgent {
  async interpret(
    message: string,
    items: Item[],
    signal: AbortSignal,
  ): Promise<Changes> {
    signal.throwIfAborted();
    const text = canonical(message),
      operations: Changes["operations"] = [];
    if (/\b(ignora|instrucciones|historial|anterior|borra todo)\b/.test(text))
      return {
        operations: [],
        clarification:
          "Indica productos y cantidades; el historial se selecciona desde la app.",
      };
    const remove = /^(quita|elimina|borra)\s+(.+)$/.exec(text);
    if (remove) {
      const found = items.filter((i) => canonical(i.name) === remove[2]);
      return found.length === 1
        ? {
            operations: [
              { type: "remove", client_item_id: found[0].client_item_id },
            ],
            clarification: null,
          }
        : {
            operations: [],
            clarification:
              "Indica el nombre exacto de un producto del borrador.",
          };
    }
    const setting = /^(cambia|pon|actualiza)\s+(.+?)\s+a\s+(.+)$/.exec(text);
    const input = setting
      ? setting[3] + " " + setting[2]
      : text.replace(/^(agrega|anade|quiero|necesito)\s+/, "");
    const seen = new Set<string>();
    for (const part of input.split(/,\s*(?!\d)|;|\n|\s+y\s+/)) {
      const m =
        /^(?:(\d+(?:[.,]\d+)?)\s*)?(?:(kilogramos?|kilos?|kg|gramos?|g|litros?|l|mililitros?|ml|piezas?|pz|docenas?|paquetes?)\b\s*(?:de\s+)?)?(.+)$/.exec(
          part.trim(),
        );
      if (!m)
        return {
          operations: [],
          clarification:
            "Prueba: Agrega 2 litros de leche, 12 huevos y 1 kg de arroz.",
        };
      const unitText = m[2] ?? "piece";
      const unit: Item["unit"] = /^(kg|kilo)/.test(unitText)
        ? "kg"
        : /^(g|gramo)/.test(unitText)
          ? "g"
          : /^(ml|mililitro)/.test(unitText)
            ? "ml"
            : /^(l|litro)/.test(unitText)
              ? "L"
              : /^docena/.test(unitText)
                ? "dozen"
                : /^paquete/.test(unitText)
                  ? "package"
                  : "piece";
      const name = m[3].replace(/^de\s+/, "").trim();
      if (
        !/^(leche|huevos?|arroz|queso oaxaca|queso parmesano|parmesano)(\s+(entera|blanco|rallado))?$/.test(
          name,
        )
      )
        return {
          operations: [],
          clarification:
            "El parser demo admite leche, huevos, arroz, queso Oaxaca y parmesano. Configura el agente IA para lenguaje libre.",
        };
      if (seen.has(name))
        return {
          operations: [],
          clarification:
            "Agrupa cada producto en una sola cantidad para el parser demo.",
        };
      seen.add(name);
      const item = {
        name,
        quantity: Number((m[1] ?? "1").replace(",", ".")),
        unit,
        notes: null,
      };
      const existing = items.filter(
        (i) => canonical(i.name) === canonical(setting?.[2] ?? name),
      );
      if (setting && existing.length !== 1)
        return {
          operations: [],
          clarification: "No identifiqué un único producto para modificar.",
        };
      if (existing.length === 1) {
        if (!setting) {
          if (existing[0].unit !== unit)
            return {
              operations: [],
              clarification:
                "Usa la misma unidad o cambia la cantidad explícitamente.",
            };
          item.quantity += existing[0].quantity;
        }
        operations.push({
          type: "set",
          client_item_id: existing[0].client_item_id,
          item: { ...item, notes: existing[0].notes },
        });
      } else operations.push({ type: "add", item });
    }
    return Operations.parse({ operations, clarification: null });
  }
}
