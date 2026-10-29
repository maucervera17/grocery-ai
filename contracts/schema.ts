import { z } from "zod";
export const Money = z
  .number()
  .int()
  .nonnegative()
  .max(Number.MAX_SAFE_INTEGER);
export const Quantity = z.number().positive().max(100000).multipleOf(0.001);
export const Unit = z.enum(["g", "kg", "ml", "L", "piece", "package", "dozen"]);
export const ProductCategory = z.enum([
  "produce",
  "dairy",
  "eggs",
  "meat",
  "bakery",
  "pantry",
  "beverages",
  "frozen",
  "household",
  "personal_care",
  "other",
]);
export const RetailerId = z.enum([
  "chedraui",
  "bodega_aurrera",
  "walmart",
  "unknown",
]);
export const WebUrl = z
  .string()
  .url()
  .regex(/^https?:\/\//);
export const DraftItem = z
  .object({
    client_item_id: z.string().min(1).max(128),
    name: z.string().trim().min(1).max(160),
    quantity: Quantity,
    unit: Unit,
    notes: z.string().max(500).nullable(),
    category_id: ProductCategory.optional(),
  })
  .strict();
export const DraftItems = z
  .array(DraftItem)
  .max(20)
  .refine(
    (a) => new Set(a.map((i) => i.client_item_id)).size === a.length,
    "Duplicate item IDs",
  );
const location = z
  .object({
    postal_code: z.string().regex(/^\d{5}$/),
    fulfillment: z.enum(["delivery", "pickup"]).optional(),
    pickup_store: z.literal("chedraui-bellavista").optional(),
  })
  .strict()
  .nullable()
  .optional();
export const SearchRequest = z.discriminatedUnion("action", [
  z
    .object({
      action: z.literal("product_prices"),
      price_scope: z.enum(["published", "local"]).optional(),
      message: z.string().trim().min(1).max(2000),
      items: DraftItems,
      location,
    })
    .strict(),
  z
    .object({
      action: z.literal("update_draft"),
      message: z.string().trim().min(1).max(2000),
      items: DraftItems,
      location,
    })
    .strict(),
  z
    .object({
      action: z.literal("compare"),
      price_scope: z.enum(["published", "local"]).optional(),
      message: z.null().optional(),
      items: DraftItems,
      location,
      preferences: z
        .object({ max_stores: z.number().int().min(1).max(2) })
        .strict()
        .optional(),
    })
    .strict(),
]);
export const ScrapedListing = z
  .object({
    source: z.string().min(1),
    retailer: z.string().min(1),
    storeName: z.string().optional(),
    productName: z.string().min(1).max(300),
    brand: z.string().optional(),
    quantity: Quantity.optional(),
    unit: Unit.optional(),
    priceCents: Money.max(100000000),
    regularPriceCents: Money.max(100000000).optional(),
    currency: z.literal("MXN"),
    productUrl: WebUrl,
    imageUrl: z
      .string()
      .url()
      .regex(/^https:\/\//)
      .optional(),
    checkedAt: z.string().datetime(),
    locationEvidence: z
      .object({
        postalCode: z.string().regex(/^\d{5}$/),
        fulfillment: z.enum(["delivery", "pickup"]),
        storeName: z.string().optional(),
        availability: z.literal("in_stock"),
        text: z.string().min(1).max(1000),
      })
      .strict()
      .optional(),
  })
  .strict();
export const PlanLine = z
  .object({
    client_item_id: z.string(),
    listing_id: z.string(),
    product_name: z.string(),
    brand: z.string().nullable(),
    category_id: ProductCategory,
    requested_quantity: Quantity,
    requested_unit: Unit,
    package_quantity: Quantity,
    package_unit: Unit,
    package_count: z.number().int().positive(),
    price_cents: Money,
    regular_price_cents: Money.nullable(),
    line_total_cents: Money,
    unit_price_cents_per_100: Money.nullable(),
    product_url: WebUrl,
    image_url: z
      .string()
      .url()
      .regex(/^https:\/\//)
      .optional(),
    checked_at: z.string().datetime(),
    data_status: z.enum(["verified", "stale", "demo"]),
    match_type: z.enum(["exact", "similar"]),
    verified_fulfillment: z.enum(["delivery", "pickup"]).optional(),
    verified_postal_code: z
      .string()
      .regex(/^\d{5}$/)
      .optional(),
  })
  .strict();
export const UnmatchedItem = z
  .object({
    client_item_id: z.string(),
    name: z.string(),
    reason: z.enum([
      "NO_MATCH",
      "INCOMPATIBLE_UNIT",
      "STORE_LIMIT",
      "SOURCE_FAILED",
      "NOTES_REQUIRE_REVIEW",
    ]),
  })
  .strict();
export const Plan = z
  .object({
    total_price_cents: Money,
    estimated_savings_cents: Money.nullable(),
    currency: z.literal("MXN"),
    stores: z.array(
      z
        .object({
          retailer_id: RetailerId,
          retailer_name: z.string().min(1),
          // Transitional field for the web client. Remove after it migrates.
          retailer: z.string(),
          store_name: z.string().nullable(),
          subtotal_cents: Money,
          items: z.array(PlanLine),
        })
        .strict(),
    ),
    unmatched_items: z.array(UnmatchedItem),
  })
  .strict();
export const SearchError = z
  .object({
    code: z.string(),
    message: z.string(),
    client_item_id: z.string().nullable(),
    retryable: z.boolean(),
  })
  .strict();
export const ProductComparison = z
  .object({
    query: z.string(),
    scope: z.enum(["published", "local"]),
    data_mode: z.enum(["demo", "live"]),
    requested_postal_code: z.string().nullable(),
    offers: z.array(
      z
        .object({
          listing: ScrapedListing,
          unit_price_cents_per_100: Money,
          basis: z.enum(["g", "ml", "piece", "package"]),
        })
        .strict(),
    ),
    winner_url: WebUrl.nullable(),
    unit_winners: z
      .array(
        z
          .object({
            basis: z.enum(["g", "ml", "piece", "package"]),
            winner_url: WebUrl,
          })
          .strict(),
      )
      .optional(),
  })
  .strict();
export const SearchResponse = z
  .object({
    reply: z.string(),
    status: z.enum(["complete", "partial", "error"]),
    draft_items: DraftItems,
    plan: Plan.nullable(),
    comparison: ProductComparison.optional(),
    errors: z.array(SearchError),
  })
  .strict();
export type Item = z.infer<typeof DraftItem>;
export type SearchInput = z.infer<typeof SearchRequest>;
export type RawListing = z.infer<typeof ScrapedListing>;
export type Line = z.infer<typeof PlanLine>;
export type ShoppingPlan = z.infer<typeof Plan>;
export type Failure = z.infer<typeof SearchError>;
export type Response = z.infer<typeof SearchResponse>;
export type ScrapeQuery = {
  query: string;
  postalCode?: string;
  maxResults?: number;
  fulfillment?: "delivery" | "pickup";
  pickupStore?: "chedraui-bellavista";
};
export type Offer = { listing: RawListing; status: Line["data_status"] };
