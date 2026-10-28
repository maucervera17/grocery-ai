import { ScrapedListing, type RawListing } from "../contracts/schema.js";
export const RETAILERS = [
  { id: "chedraui", retailer: "Chedraui", host: "www.chedraui.com.mx" },
  {
    id: "bodega-aurrera",
    retailer: "Bodega Aurrera",
    host: "www.bodegaaurrera.com.mx",
  },
  { id: "walmart", retailer: "Walmart", host: "www.walmart.com.mx" },
] as const;
export type Retailer = (typeof RETAILERS)[number];
export type Page = { markdown?: string; metadata?: Record<string, unknown> };
export function productUrl(value: string, source: Retailer): string | null {
  try {
    const url = new URL(value);
    if (
      url.protocol !== "https:" ||
      url.hostname !== source.host ||
      url.username ||
      url.password ||
      url.port
    )
      return null;
    if (
      source.id === "chedraui"
        ? !url.pathname.endsWith("/p")
        : !/^\/ip\/(?:[^/]+\/)+\d+$/.test(url.pathname)
    )
      return null;
    url.search = "";
    url.hash = "";
    return url.href;
  } catch {
    return null;
  }
}
function cents(value: string): number {
  const clean = value.replace(/,/g, "");
  if (!/^\d+(\.\d{1,2})?$/.test(clean)) throw new Error("Invalid price");
  const [whole, decimal = ""] = clean.split(".");
  return Number(whole) * 100 + Number(decimal.padEnd(2, "0"));
}
export function unavailablePrimary(primary: string): boolean {
  const selected = primary
    .match(/Tamaño:\s*([^\n]+)/)?.[1]
    ?.trim()
    .toLowerCase();
  const stockText = primary
    .split("\n")
    .filter((line) => {
      if (/devoluci[oó]n(?:es)? no disponible/i.test(line)) return false;
      const variant = line.match(
        /^(.+),\s*\$[\d,.]+,\s*(?:Agotado|No disponible)\s*$/i,
      );
      if (selected && variant && variant[1].trim().toLowerCase() !== selected)
        return false;
      return true;
    })
    .join("\n");
  return /agotado|no disponible|sin existencia/i.test(stockText);
}
export function productImage(page: Page): string | undefined {
  const meta = page.metadata ?? {};
  const values = [meta.ogImage, meta["og:image"], meta["twitter:image"]].flat();
  for (const value of values) {
    if (typeof value !== "string") continue;
    try {
      const url = new URL(value);
      const allowed = [
        "i5-mx.walmartimages.com",
        "i5.walmartimages.com",
        "chedrauimx.vtexassets.com",
        "chedrauimx.vteximg.com.br",
      ];
      if (
        url.protocol === "https:" &&
        !url.username &&
        !url.password &&
        !url.port &&
        allowed.includes(url.hostname) &&
        /\/(asr|arquivos\/ids)\//.test(url.pathname)
      )
        return url.href;
    } catch {
      /* Missing or invalid metadata is not a reason to discard a price. */
    }
  }
  return undefined;
}
export function parseProduct(
  source: Retailer,
  url: string,
  page: Page,
  now = new Date().toISOString(),
): RawListing {
  const safe = productUrl(url, source);
  if (!safe) throw new Error("Invalid product URL");
  const metadata = page.metadata ?? {},
    markdown = (page.markdown ?? "").replace(/\\([`*_])/g, "$1");
  if (
    Number(metadata.statusCode ?? 200) >= 400 ||
    /robot or human|captcha|access denied/i.test(markdown.slice(0, 1000))
  )
    throw new Error("Blocked source");
  if (metadata.url && productUrl(String(metadata.url), source) !== safe)
    throw new Error("Redirected product");
  const title = String(metadata.ogTitle ?? metadata.title ?? "")
    .split("|")[0]
    .trim();
  if (!title) throw new Error("Missing product title");
  // Parse only the primary product section, never recommendations/reviews or other variants.
  const heading = markdown.indexOf("# " + title);
  if (heading < 0) throw new Error("Primary product not found");
  const primary = markdown
    .slice(heading)
    .split(
      /\n# Promociones|\n## Información|\nProductos relacionados|\n## Artículos similares/,
    )[0];
  if (unavailablePrimary(primary)) throw new Error("Unavailable product");
  let price: string | undefined,
    regular: string | undefined,
    storeName: string | undefined;
  if (source.id === "chedraui") {
    if (metadata["product:price:currency"] !== "MXN")
      throw new Error("Unknown currency");
    price = String(metadata["product:price:amount"] ?? "");
    const visible = primary.match(
      /\n\$([\d,]+(?:\.\d{2})?)(?:\s+\$[\d,]+(?:\.\d{2})?)?\s*\n/,
    );
    if (!visible || cents(visible[1]) !== cents(price))
      throw new Error("Price evidence mismatch");
  } else {
    price = primary.match(
      /Precio actual (?:MXN\s*)?\$([\d,]+(?:\.\d{2})?)/,
    )?.[1];
    regular = primary.match(/costaba \$([\d,]+(?:\.\d{2})?)/)?.[1];
    storeName = primary
      .match(/(?:Recoge en tienda,|Pickup sin costo,)[^\n]*? en ([^\n]+)/)?.[1]
      ?.trim();
  }
  if (!price) throw new Error("Missing price");
  // Multipacks must expose total contents unambiguously, e.g. 6 piezas de 1 L c/u.
  const sizeText =
    source.id !== "chedraui"
      ? (primary.match(/Tamaño:\s*([^\n]+)/)?.[1] ?? title)
      : title;
  const multi =
    /(\d+)\s*(?:piezas|pzas|pz)\s*(?:de|con)\s*(\d+(?:\.\d+)?)\s*(kg|g|ml|l)\b/i.exec(
      sizeText,
    );
  const sizes = [
    ...sizeText.matchAll(
      /(\d+(?:\.\d+)?)\s*(kg|g|ml|l|piezas?|pzas?|pz|docenas?)\b/gi,
    ),
  ];
  const perKg = /\bpor\s+(?:kg|kilo(?:gramo)?)\b/i.test(sizeText);
  if (!sizes.length && !perKg) throw new Error("Unknown package size");
  if (
    !perKg &&
    !multi &&
    /\b(pack|paquete|caja|empaque)\b/i.test(title) &&
    sizes.length > 1
  )
    throw new Error("Ambiguous multipack");
  const size = perKg ? ["por kg", "1", "kg"] : sizes[sizes.length - 1],
    rawUnit = (perKg ? "kg" : (multi?.[3] ?? size[2])).toLowerCase();
  const unit =
    rawUnit === "l"
      ? "L"
      : rawUnit.startsWith("docena")
        ? "dozen"
        : ["g", "kg", "ml"].includes(rawUnit)
          ? rawUnit
          : "piece";
  const quantity = perKg
    ? 1
    : multi
      ? Number(multi[1]) * Number(multi[2])
      : Number(size[1]);
  // Never turn an old Firecrawl cache hit into a newly verified price.
  const checkedAt =
    metadata.cacheState === "hit" ? String(metadata.cachedAt ?? "") : now;
  const result = ScrapedListing.parse({
    source: source.id,
    retailer: source.retailer,
    storeName,
    productName: title,
    brand:
      typeof metadata["product:brand"] === "string"
        ? metadata["product:brand"]
        : undefined,
    quantity,
    unit,
    priceCents: cents(price),
    regularPriceCents: regular ? cents(regular) : undefined,
    currency: "MXN",
    productUrl: safe,
    imageUrl: productImage(page),
    checkedAt,
  });
  if (Date.parse(result.checkedAt) > Date.parse(now) + 60000)
    throw new Error("Future date");
  if (
    result.regularPriceCents !== undefined &&
    result.regularPriceCents < result.priceCents
  )
    throw new Error("Invalid regular price");
  return result;
}
