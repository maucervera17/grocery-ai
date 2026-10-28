import { setTimeout as delay } from "node:timers/promises";
import type { RawListing, ScrapeQuery } from "../contracts/schema.js";
import { matches } from "../backend/normalize.js";
import { bounded } from "../backend/deadline.js";
import {
  RETAILERS,
  productUrl,
  parseProduct,
  type Retailer,
  type Page,
} from "./retailers.js";
export type SourceError = {
  code: string;
  source: string;
  message: string;
  retryable: boolean;
};
export type Batch = { listings: RawListing[]; errors: SourceError[] };
export interface Scraper {
  scrape(query: ScrapeQuery, signal: AbortSignal): Promise<Batch>;
}
class SourceFailure extends Error {
  constructor(
    public code: string,
    public retryable: boolean,
  ) {
    super(code);
  }
}
export class FirecrawlScraper implements Scraper {
  constructor(
    private key: string,
    private request: typeof fetch = fetch,
  ) {}
  private async call(
    path: string,
    payload: unknown,
    signal: AbortSignal,
  ): Promise<unknown> {
    for (let attempt = 0; attempt < 2; attempt++) {
      const response = await bounded(
        () =>
          this.request("https://api.firecrawl.dev/v2/" + path, {
            method: "POST",
            signal,
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${this.key}`,
            },
            body: JSON.stringify(payload),
          }),
        signal,
      );
      const transient = response.status === 429 || response.status >= 500;
      if (transient && attempt === 0) {
        await delay(250, undefined, { signal });
        continue;
      }
      if (!response.ok)
        throw new SourceFailure(
          response.status === 402
            ? "FIRECRAWL_CREDITS"
            : response.status === 401
              ? "FIRECRAWL_AUTH"
              : "SOURCE_FAILED",
          transient,
        );
      const body = (await bounded(() => response.json(), signal)) as {
        success?: boolean;
        data?: unknown;
      };
      if (body.success !== true)
        throw new SourceFailure("SOURCE_FAILED", false);
      return body.data;
    }
    throw new SourceFailure("SOURCE_FAILED", true);
  }
  async scrape(query: ScrapeQuery, signal: AbortSignal): Promise<Batch> {
    const batches = await Promise.all(
      RETAILERS.map((source) => this.source(source, query, signal)),
    );
    return {
      listings: batches.flatMap((b) => b.listings),
      errors: batches.flatMap((b) => b.errors),
    };
  }
  private async source(
    source: Retailer,
    query: ScrapeQuery,
    signal: AbortSignal,
  ): Promise<Batch> {
    const batch: Batch = { listings: [], errors: [] };
    const failed = (error: unknown) => {
      batch.errors.push({
        source: source.id,
        code: signal.aborted
          ? "SOURCE_TIMEOUT"
          : error instanceof SourceFailure
            ? error.code
            : "SOURCE_INVALID",
        message: `No se pudo verificar una consulta de ${source.retailer}.`,
        retryable:
          signal.aborted || (error instanceof SourceFailure && error.retryable),
      });
    };
    try {
      const search = (await this.call(
        "search",
        {
          query: query.query,
          includeDomains: [source.host],
          limit: 5,
          sources: [{ type: "web" }],
          domainTools: false,
          timeout: 10000,
        },
        signal,
      )) as { web?: { url: string }[] };
      if (!Array.isArray(search.web))
        throw new SourceFailure("SOURCE_INVALID", false);
      const urls = [
        ...new Set(
          search.web
            .map((r) => productUrl(r.url, source))
            .filter((s): s is string => !!s),
        ),
      ].slice(0, Math.min(query.maxResults ?? 2, 2));
      // Sequential per source: four simultaneous requests maximum across two basket workers.
      for (const url of urls) {
        try {
          const page = (await this.call(
            "scrape",
            {
              url,
              formats: ["markdown"],
              maxAge: 0,
              proxy: "basic",
              timeout: 10000,
              onlyMainContent: true,
            },
            signal,
          )) as Page;
          const listing = parseProduct(source, url, page);
          if (matches(listing.productName, query.query))
            batch.listings.push(listing);
        } catch (error) {
          failed(error);
        }
      }
    } catch (error) {
      failed(error);
    }
    return batch;
  }
}
