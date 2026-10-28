import type { z } from "zod";
import { ProductCategory } from "../contracts/schema.js";
import { canonical } from "./normalize.js";

export type ProductCategoryId = z.infer<typeof ProductCategory>;

export function productCategory(name: string): ProductCategoryId {
  const value = canonical(name);

  if (/\b(huevo|huevos)\b/.test(value)) return "eggs";
  if (/\b(leche|queso|yogur|yogurt|crema|mantequilla)\b/.test(value))
    return "dairy";
  if (/\b(pollo|pechuga|carne|res|cerdo|pescado|atun|jamon)\b/.test(value))
    return "meat";
  if (
    /\b(manzanas?|platanos?|bananas?|jitomates?|tomates?|aguacates?|lechugas?|frutas?|verduras?)\b/.test(
      value,
    )
  )
    return "produce";
  if (/\b(pan|bolillos?|tortillas?)\b/.test(value)) return "bakery";
  if (/\b(agua|jugo|refresco|cafe|te)\b/.test(value)) return "beverages";
  if (/\b(congelado|helado)\b/.test(value)) return "frozen";
  if (
    /\b(papel|detergente|jabon para ropa|limpiador|servilleta|bolsa de basura)\b/.test(
      value,
    )
  )
    return "household";
  if (
    /\b(shampoo|acondicionador|desodorante|pasta dental|jabon corporal)\b/.test(
      value,
    )
  )
    return "personal_care";
  if (
    /\b(arroz|pasta|aceite|frijol|harina|azucar|sal|cereal|sopa)\b/.test(value)
  )
    return "pantry";
  return "other";
}
