import type { z } from "zod";
import { RetailerId } from "../contracts/schema.js";
import { canonical } from "./normalize.js";

export type RetailerIdentity = {
  id: z.infer<typeof RetailerId>;
  name: string;
};

export function retailerIdentity(
  source: string,
  retailer: string,
): RetailerIdentity {
  const value = canonical(`${source} ${retailer}`);

  if (value.includes("bodega-aurrera") || value.includes("bodega aurrera"))
    return { id: "bodega_aurrera", name: "Bodega Aurrera" };
  if (value.includes("chedraui")) return { id: "chedraui", name: "Chedraui" };
  if (value.includes("walmart")) return { id: "walmart", name: "Walmart" };
  return {
    id: "unknown",
    name: retailer.replace(/\s*\(demo\)\s*$/i, "").trim(),
  };
}
