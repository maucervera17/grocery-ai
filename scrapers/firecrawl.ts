import { setTimeout as delay } from "node:timers/promises";
import type { RawListing, ScrapeQuery } from "../contracts/schema.js";
import { matches, tokens } from "../backend/normalize.js";
import { bounded } from "../backend/deadline.js";
import {
  postalActions,
  verifyPostal,
  PostalVerificationError,
  pickupActions,
  verifyPickup,
} from "./postal.js";
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
// Firecrawl's free tier allows 10 requests/minute per endpoint and two
// concurrent browsers. Let a small search finish in parallel, then wait only
// when the rolling limit is actually exhausted.
export class RequestWindow {
  private buckets = new Map<string, { starts: number[]; active: number }>();
  constructor(
    private maxRequests = 10,
    private windowMs = 60_000,
    private maxConcurrent = 2,
  ) {}
  async run<T>(
    path: string,
    task: () => Promise<T>,
    signal: AbortSignal,
  ): Promise<T> {
    let bucket = this.buckets.get(path);
    if (!bucket) {
      bucket = { starts: [], active: 0 };
      this.buckets.set(path, bucket);
    }
    while (true) {
      signal.throwIfAborted();
      const now = Date.now();
      bucket.starts = bucket.starts.filter(
        (start) => now - start < this.windowMs,
      );
      if (
        bucket.active < this.maxConcurrent &&
        bucket.starts.length < this.maxRequests
      ) {
        bucket.starts.push(now);
        bucket.active++;
        break;
      }
      const wait =
        bucket.active >= this.maxConcurrent
          ? 25
          : Math.max(1, bucket.starts[0] + this.windowMs - now);
      await delay(wait, undefined, { signal });
    }
    try {
      return await task();
    } finally {
      bucket.active--;
    }
  }
}
const requestWindow = new RequestWindow();
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
      signal.throwIfAborted();
      const request = () =>
        bounded(
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
      const response =
        this.request === fetch
          ? await requestWindow.run(path, request, signal)
          : await request();
      const transient = response.status >= 500;
      const hasPostalActions =
        typeof payload === "object" && payload !== null && "actions" in payload;
      if (transient && attempt === 0 && !hasPostalActions) {
        await delay(250, undefined, { signal });
        continue;
      }
      if (!response.ok)
        throw new SourceFailure(
          response.status === 429
            ? "FIRECRAWL_RATE_LIMIT"
            : response.status === 408
              ? "SOURCE_TIMEOUT"
              : response.status === 402
                ? "FIRECRAWL_CREDITS"
                : response.status === 401
                  ? "FIRECRAWL_AUTH"
                  : "SOURCE_FAILED",
          transient || response.status === 429 || response.status === 408,
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
      RETAILERS.filter(
        (source) => query.fulfillment !== "pickup" || source.id === "chedraui",
      ).map((source) => this.source(source, query, signal)),
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
          : error instanceof SourceFailure &&
              [
                "FIRECRAWL_AUTH",
                "FIRECRAWL_CREDITS",
                "FIRECRAWL_RATE_LIMIT",
              ].includes(error.code)
            ? error.code
            : query.postalCode && !(error instanceof PostalVerificationError)
              ? "LOCATION_VERIFICATION_FAILED"
              : error instanceof SourceFailure ||
                  error instanceof PostalVerificationError
                ? error.code
                : "SOURCE_INVALID",
        message:
          error instanceof SourceFailure &&
          error.code === "FIRECRAWL_RATE_LIMIT"
            ? "Firecrawl alcanzó el límite temporal de consultas. Intenta de nuevo en un minuto."
            : error instanceof PostalVerificationError
              ? error.message
              : query.postalCode
                ? `${source.retailer} no permitió verificar ${query.fulfillment === "pickup" ? "recogida en Bellavista" : "entrega"} para CP ${query.postalCode}. Confirma la zona directamente en la tienda.`
                : `No se pudo verificar una consulta de ${source.retailer}.`,
        retryable:
          signal.aborted || (error instanceof SourceFailure && error.retryable),
      });
    };
    try {
      if (
        query.fulfillment === "pickup" &&
        (query.pickupStore !== "chedraui-bellavista" ||
          query.postalCode !== "52994")
      )
        throw new PostalVerificationError(
          "PICKUP_STORE_REQUIRED",
          "Selecciona la sucursal de recogida Bellavista (CP 52994).",
        );
      const actions =
        query.fulfillment === "pickup"
          ? pickupActions()
          : query.postalCode
            ? postalActions(source, query.postalCode)
            : undefined;
      const search = (await this.call(
        "search",
        {
          query: `site:${source.host} ${query.query}`,
          includeDomains: [source.host],
          limit: 5,
          sources: [{ type: "web" }],
          domainTools: false,
          timeout: 10000,
        },
        signal,
      )) as { web?: { url: string; title?: string }[] };
      if (!Array.isArray(search.web))
        throw new SourceFailure("SOURCE_INVALID", false);
      const urls = [
        ...new Set(
          search.web
            .filter(
              (r) =>
                !r.title ||
                !/falsos?|simulaci[oó]n|utensilios?|contenedor|dispensador|taz[oó]n|cortador|tijeras|sazonador|tenedor/i.test(
                  r.title,
                ) ||
                /falso|utensilio|contenedor|dispensador|tazon|cortador|tijera|sazonador|tenedor/i.test(
                  query.query,
                ),
            )
            .sort(
              (a, b) =>
                Number(tokens(b.title ?? "")[0] === tokens(query.query)[0]) -
                Number(tokens(a.title ?? "")[0] === tokens(query.query)[0]),
            )
            .map((r) => productUrl(r.url, source))
            .filter((s): s is string => !!s),
        ),
      ].slice(0, 2);
      // Try a second search hit only if the fast path did not produce a
      // matching listing. Basket comparisons can still collect two options.
      for (const url of urls) {
        try {
          const page = (await this.call(
            "scrape",
            {
              url,
              formats: ["markdown"],
              maxAge: 0,
              proxy: "basic",
              timeout: actions ? 30000 : 20000,
              onlyMainContent: !actions,
              ...(actions ? { actions } : {}),
            },
            signal,
          )) as Page;
          const locationEvidence =
            query.fulfillment === "pickup"
              ? verifyPickup(page)
              : query.postalCode
                ? verifyPostal(source, page, query.postalCode)
                : undefined;
          const listing = {
            ...parseProduct(source, url, page),
            ...(locationEvidence?.storeName
              ? { storeName: locationEvidence.storeName }
              : {}),
            ...(locationEvidence ? { locationEvidence } : {}),
          };
          if (matches(listing.productName, query.query)) {
            batch.listings.push(listing);
            if (batch.listings.length >= Math.min(query.maxResults ?? 2, 2))
              break;
          }
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
