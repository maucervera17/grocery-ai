import {registerLocation} from "./location.js";
import { registerVoice, type VoiceOptions } from "./voice.js";
import { readFile } from "node:fs/promises";
import { createHash, timingSafeEqual } from "node:crypto";
import Fastify from "fastify";
import { SearchRequest, SearchResponse } from "../contracts/schema.js";
import { createSearch, failure, type Options } from "./service.js";
export function buildApp(options: Options, voiceOptions: VoiceOptions = {}, accessPassword?: string, publicWebOrigin?: string) {
  const app = Fastify({
      bodyLimit: 32768,
      logger: false,
      requestTimeout: 100000,
    }),
    search = createSearch(options);
  if (accessPassword) {
    const expected = createHash("sha256").update(`barasu:${accessPassword}`).digest();
    const publicBudgets = new Map<string, { day: number; dayCount: number; minute: number; minuteCount: number }>();
    const publicLimits: Record<string, { daily: number; minute: number }> = {
      "/v1/chat/search": { daily: 40, minute: 5 },
      "/v1/location/resolve": { daily: 30, minute: 5 },
      "/v1/voice/session": { daily: 8, minute: 2 },
    };
    app.addHook("onRequest", async (request, reply) => {
      const path = request.url.split("?")[0];
      if (path === "/health") return;
      const header = request.headers.authorization;
      const match = /^Basic ([A-Za-z0-9+/=]+)$/.exec(header ?? "");
      let valid = false;
      if (match) {
        try {
          const actual = createHash("sha256")
            .update(Buffer.from(match[1], "base64").toString("utf8"))
            .digest();
          valid = timingSafeEqual(actual, expected);
        } catch { /* Invalid authorization header. */ }
      }
      if (valid) return;
      if (!header && publicWebOrigin &&
          ((path === "/v1/voice/status" && request.method === "GET") ||
           (request.method === "POST" && request.headers.origin === publicWebOrigin && path in publicLimits))) {
        const limit = publicLimits[path];
        if (!limit) return;
        const now = Date.now();
        const day = Math.floor(now / 86400000);
        const minute = Math.floor(now / 60000);
        const previous = publicBudgets.get(path);
        const bucket = {
          day, dayCount: previous?.day === day ? previous.dayCount : 0,
          minute, minuteCount: previous?.minute === minute ? previous.minuteCount : 0,
        };
        if (bucket.dayCount >= limit.daily || bucket.minuteCount >= limit.minute)
          return reply.header("Retry-After", bucket.dayCount >= limit.daily ? "3600" : "60")
            .header("Cache-Control", "no-store")
            .code(429).send({ error: "PUBLIC_DEMO_LIMIT", message: "La demo pública alcanzó su límite de consultas. Intenta más tarde." });
        bucket.dayCount++;
        bucket.minuteCount++;
        publicBudgets.set(path, bucket);
        return;
      }
      return reply.header("WWW-Authenticate", 'Basic realm="Barasu"')
        .header("Cache-Control", "no-store")
        .code(401).send({ error: "ACCESS_DENIED" });
    });
  }
  registerVoice(app, { ...voiceOptions, allowedOrigins: publicWebOrigin
    ? ["http://127.0.0.1:3000", "http://localhost:3000", publicWebOrigin]
    : voiceOptions.allowedOrigins, allowAuthenticatedRemote: Boolean(accessPassword) });
  registerLocation(app);
  const errorBody = (code: string, message: string) => ({
    reply: message,
    status: "error",
    draft_items: [],
    plan: null,
    errors: [failure(code, message)],
  });
  for (const [route, file, type] of [
    ["/", "index.html", "text/html; charset=utf-8"],
    ["/style.css", "style.css", "text/css"],
    ["/design-system.css", "design-system.css", "text/css"],
    ["/brand-light.svg", "brand-light.svg", "image/svg+xml"],
    ["/brand-dark.svg", "brand-dark.svg", "image/svg+xml"],
    ["/app.js", "app.js", "text/javascript"],
    ["/location.js", "location.js", "text/javascript"],
    ["/wishlist.js", "wishlist.js", "text/javascript"],
    ["/voice.js", "voice.js", "text/javascript"],
    ["/savings.js", "savings.js", "text/javascript"],
    ["/savings-view.js", "savings-view.js", "text/javascript"],
    ["/weekly.js", "weekly.js", "text/javascript"],
    ["/weekly-plan.js", "weekly-plan.js", "text/javascript"],
  ]) {
    app.get(route, async (_request, reply) =>
      reply
        .header("Cache-Control", "no-store")
        .type(type)
        .send(await readFile("./web/" + file, "utf8")),
    );
  }
  app.get("/voice-sdk.js", async (_req, reply) => reply.type("text/javascript").send(await readFile("./dist/web/voice-sdk.js")));
  app.get("/baras-logo.png", async (_request, reply) =>
    reply.type("image/png").send(await readFile("./web/baras-logo.png")),
  );
  app.get("/health", async () => ({
    status: "ok",
    mode: options.mode,
    agent: options.agent
      ? "configured"
      : options.mode === "demo"
        ? "demo"
        : "unconfigured",
    firecrawl: options.scraper ? "configured" : "unconfigured",
    database: options.repository ? "configured" : "unconfigured",
  }));
  app.setErrorHandler((error, request, reply) => {
    const issues = error && typeof error === "object" && "issues" in error
      ? error.issues : undefined;
    const code =
      error instanceof Error && "statusCode" in error
        ? Number(error.statusCode)
        : 500;
    const status = code >= 400 && code < 500 ? code : 500;
    console.error(
      JSON.stringify({
        event: "request_error",
        request_id: request.id,
        route: request.routeOptions.url,
        status,
        error_type: error instanceof Error ? error.name : "unknown",
        // Keep product names, credentials and provider responses out of logs.
        validation_issues: Array.isArray(issues)
          ? issues.map((issue: { code?: string; path?: PropertyKey[] }) => ({
              code: issue.code,
              path: issue.path?.map(String).join("."),
            }))
          : undefined,
      }),
    );
    reply.header("X-Request-ID", request.id)
      .code(status)
      .send(
        errorBody(
          status < 500 ? "INVALID_REQUEST" : "INTERNAL_ERROR",
          status < 500
            ? "Solicitud inválida. Revisa JSON y Content-Type."
            : "Error interno.",
        ),
      );
  });
  app.addHook("onResponse", async (req, res) => {
    console.info(
      JSON.stringify({
        event: "request",
        request_id: req.id,
        route: req.routeOptions.url,
        status: res.statusCode,
        duration_ms: Math.round(res.elapsedTime),
      }),
    );
  });
  app.post("/v1/chat/search", async (req, reply) => {
    const input = SearchRequest.safeParse(req.body);
    if (!input.success)
      return reply
        .code(400)
        .send(
          errorBody(
            "INVALID_REQUEST",
            "Revisa action, items, message, unidades e IDs únicos.",
          ),
        );
    return SearchResponse.parse(await search(input.data));
  });
  return app;
}
