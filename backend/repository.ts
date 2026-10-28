import type { RawListing, ScrapeQuery } from "../contracts/schema.js";
// Implement this interface in coordination with the database owner; no SQL schema assumed.
export interface ListingRepository {
  search(query: ScrapeQuery, signal: AbortSignal): Promise<RawListing[]>;
  upsert(
    listings: RawListing[],
    query: ScrapeQuery,
    signal: AbortSignal,
  ): Promise<void>;
}
