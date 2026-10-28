import { z } from "zod";
import {
  ScrapedListing,
  type RawListing,
  type ScrapeQuery,
} from "../contracts/schema.js";
import type { ListingRepository } from "./repository.js";
import { tokens } from "./normalize.js";
import { bounded } from "./deadline.js";

// This is the single translation boundary between scraper records and database RPCs.
export class SupabaseListingRepository implements ListingRepository {
  private base: string;
  constructor(
    url: string,
    private key: string,
    private demo = false,
    private request: typeof fetch = fetch,
  ) {
    const parsed = new URL(url);
    if (
      parsed.protocol !== "https:" &&
      !(
        ["127.0.0.1", "localhost"].includes(parsed.hostname) &&
        parsed.protocol === "http:"
      )
    )
      throw Error("SUPABASE_URL must use HTTPS (except localhost)");
    this.base = url.replace(/\/$/, "") + "/rest/v1/rpc/";
  }
  private async rpc(
    name: string,
    body: unknown,
    signal: AbortSignal,
  ): Promise<unknown> {
    const response = await bounded(
      () =>
        this.request(this.base + name, {
          method: "POST",
          signal,
          headers: {
            apikey: this.key,
            Authorization: `Bearer ${this.key}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(body),
        }),
      signal,
    );
    if (!response.ok)
      throw Error(`Database request failed (${response.status})`);
    if (response.status === 204) return null;
    const text = await bounded(() => response.text(), signal);
    return text ? JSON.parse(text) : null;
  }
  async search(query: ScrapeQuery, signal: AbortSignal): Promise<RawListing[]> {
    return z.array(ScrapedListing).parse(
      await this.rpc(
        "grocery_search_listings",
        {
          p_query: tokens(query.query).join(" "),
          p_postal_code: this.demo ? "" : (query.postalCode ?? ""),
          p_limit: Math.min(query.maxResults ?? 20, 100),
          p_demo: this.demo,
        },
        signal,
      ),
    );
  }
  async upsert(
    listings: RawListing[],
    query: ScrapeQuery,
    signal: AbortSignal,
  ): Promise<void> {
    const validated = z.array(ScrapedListing).max(100).parse(listings);
    if (!validated.length) return;
    await this.rpc(
      "grocery_upsert_listings",
      {
        p_listings: validated,
        p_postal_code: this.demo ? "" : (query.postalCode ?? ""),
        p_demo: this.demo,
      },
      signal,
    );
  }
}
