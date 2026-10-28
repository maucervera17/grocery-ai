import type { RawListing } from "../contracts/schema.js";
import { unavailablePrimary, type Page, type Retailer } from "./retailers.js";

export class PostalVerificationError extends Error {
  constructor(
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

// UI actions only: never manufacture cookies, alter responses, or solve challenges.
export function postalActions(source: Retailer, postalCode: string) {
  if (!/^\d{5}$/.test(postalCode)) throw new Error("Invalid postal code");
  if (source.id === "chedraui")
    throw new PostalVerificationError(
      "LOCATION_REQUIRES_ADDRESS",
      "Chedraui requiere una dirección o sucursal; el código postal no confirma la entrega.",
    );
  return [
    {
      type: "executeJavascript",
      script: `const button = [...document.querySelectorAll('button')].find(b => /\\b\\d{5}\\b/.test(b.textContent || '') && /cambiar de tienda/i.test(b.getAttribute('aria-label') || '')); if (!button) throw new Error('Postal selector unavailable'); button.click();`,
    },
    { type: "wait", selector: 'input[name="postalCode"]' },
    { type: "click", selector: 'input[name="postalCode"]' },
    { type: "press", key: "CTRL+A" },
    { type: "write", text: postalCode },
    {
      type: "executeJavascript",
      script: `const button = [...document.querySelectorAll('button')].find(b => b.textContent?.trim() === 'Guardar'); if (!button) throw new Error('Postal save unavailable'); button.click();`,
    },
    { type: "wait", milliseconds: 2000 },
  ];
}

// Evidence must be on the product page after the store applies the destination.
// An input value, request parameter, pickup branch, or default location is not proof.
export function verifyPostal(
  source: Retailer,
  page: Page,
  postalCode: string,
): NonNullable<RawListing["locationEvidence"]> {
  const markdown = page.markdown ?? "";
  if (
    /robot o humano|robot or human|captcha|access denied|problemas técnicos/i.test(
      markdown,
    )
  )
    throw new PostalVerificationError(
      "LOCATION_VERIFICATION_BLOCKED",
      `${source.retailer} no permitió confirmar la zona. Abre la tienda para verificarla.`,
    );
  const title = String(page.metadata?.ogTitle ?? page.metadata?.title ?? "")
    .split("|")[0]
    .trim();
  const index = markdown.indexOf("# " + title);
  if (!title || index < 0)
    throw new PostalVerificationError(
      "LOCATION_UNVERIFIED",
      "No se encontró la ficha principal para validar la zona.",
    );
  const primary = markdown
    .slice(index)
    .split(
      /\n## Información|\n## Artículos similares|\nProductos relacionados/,
    )[0];
  if (unavailablePrimary(primary))
    throw new PostalVerificationError(
      "OUT_OF_STOCK",
      `${source.retailer} no muestra existencias del producto en la consulta.`,
    );
  if (
    /no (?:hay|tenemos) (?:cobertura|entrega)|no disponible para env[ií]o/i.test(
      primary,
    )
  )
    throw new PostalVerificationError(
      "DELIVERY_UNAVAILABLE",
      `${source.retailer} no confirma entrega de este producto.`,
    );
  const delivery = primary.match(
    /Env[ií]o desde tienda,[^\n]*\ba\s*\n+[^\n]*\b(\d{5})\b/i,
  );
  if (
    !delivery ||
    delivery[1] !== postalCode ||
    !/Agregar al carrito/.test(primary)
  )
    throw new PostalVerificationError(
      "LOCATION_UNVERIFIED",
      `${source.retailer} no confirmó precio y disponibilidad de entrega para CP ${postalCode}.`,
    );
  return {
    postalCode,
    fulfillment: "delivery",
    availability: "in_stock",
    text: delivery[0].slice(0, 1000),
  };
}

export const BELLAVISTA = {
  name: "Super Chedraui Bellavista",
  postalCode: "52994",
  address: "Blvd. Bellavista 22, Lomas de Bellavista, Ciudad López Mateos",
  id: "chedrauimx0161_PP0161",
};
export function pickupActions() {
  return [
    {
      type: "executeJavascript",
      script: `const b=[...document.querySelectorAll('button')].find(b=>/Agregar una.*Dirección|Recoger en:/i.test(b.textContent||'')); if(!b) throw new Error('Location selector missing'); b.click();`,
    },
    { type: "wait", milliseconds: 500 },
    {
      type: "executeJavascript",
      script: `const b=[...document.querySelectorAll('button')].find(b=>b.textContent?.trim()==='Recoger en'); if(!b) throw new Error('Pickup selector missing'); b.click();`,
    },
    {
      type: "click",
      selector: 'input[placeholder="Ejemplo: Av. Miguel de Cervantes No. 397"]',
    },
    { type: "write", text: BELLAVISTA.address },
    {
      type: "wait",
      selector: ".chedrauimx-locator-2-x-InputSelect__content_select_list_item",
    },
    {
      type: "executeJavascript",
      script: `const e=[...document.querySelectorAll('.chedrauimx-locator-2-x-InputSelect__content_select_list_item')].find(e=>e.textContent?.startsWith('Blvd. Bellavista 22,')&&e.textContent?.includes('Lomas de Bellavista')); if(!e) throw new Error('Exact address missing'); e.click();`,
    },
    { type: "wait", selector: 'input[value="chedrauimx0161_PP0161"]' },
    { type: "click", selector: 'input[value="chedrauimx0161_PP0161"]' },
    {
      type: "executeJavascript",
      script: `const b=[...document.querySelectorAll('button')].find(b=>b.textContent?.trim()==='Recoger en esta tienda'); if(!b||b.disabled) throw new Error('Cannot select pickup'); b.click();`,
    },
    { type: "wait", milliseconds: 2000 },
  ];
}
export function verifyPickup(
  page: Page,
): NonNullable<RawListing["locationEvidence"]> {
  const md = page.markdown ?? "";
  const title = String(page.metadata?.ogTitle ?? page.metadata?.title ?? "")
    .split("|")[0]
    .trim();
  const heading = md.indexOf("# " + title);
  if (!title || heading < 0)
    throw new PostalVerificationError(
      "LOCATION_UNVERIFIED",
      "No se encontró la ficha de producto para esta sucursal.",
    );
  const before = md.slice(0, heading).replace(/[#*]/g, "").replace(/\s+/g, " ");
  const primary = md
    .slice(heading)
    .split(/\n# Promociones|\n## Información/)[0];
  if (
    !/Recoger en:\s*Super Chedraui Bellavista\b/i.test(before) ||
    /Estamos actualizando|¿Dónde te entregaremos\?|robot|captcha/i.test(md)
  )
    throw new PostalVerificationError(
      "LOCATION_UNVERIFIED",
      "Chedraui no confirmó la sucursal Bellavista en la ficha del producto.",
    );
  if (
    /agotado|no disponible|sin existencia/i.test(primary) ||
    !/^Agregar\s*$/m.test(primary)
  )
    throw new PostalVerificationError(
      "OUT_OF_STOCK",
      "No se confirmó disponibilidad para recoger este producto en Bellavista.",
    );
  return {
    postalCode: BELLAVISTA.postalCode,
    fulfillment: "pickup",
    storeName: BELLAVISTA.name,
    availability: "in_stock",
    text:
      "Recoger en: " +
      BELLAVISTA.name +
      "; Agregar disponible en la ficha principal.",
  };
}
