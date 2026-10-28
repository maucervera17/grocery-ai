import {registerLocation} from "./location.js";
import { registerVoice, type VoiceOptions } from "./voice.js";
import { readFile } from "node:fs/promises";
import Fastify from "fastify";
import { SearchRequest, SearchResponse } from "../contracts/schema.js";
import { createSearch, failure, type Options } from "./service.js";
export function buildApp(options: Options, voiceOptions: VoiceOptions = {}) {
  const app = Fastify({
      bodyLimit: 32768,
      logger: false,
      requestTimeout: 100000,
    }),
    search = createSearch(options);
  registerVoice(app, voiceOptions);
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
    ["/app.js", "app.js", "text/javascript"],
    ["/location.js", "location.js", "text/javascript"],
    ["/wishlist.js", "wishlist.js", "text/javascript"],
    ["/voice.js", "voice.js", "text/javascript"],
    ["/savings.js", "savings.js", "text/javascript"],
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
    const code =
      error instanceof Error && "statusCode" in error
        ? Number(error.statusCode)
        : 500;
    const status = code >= 400 && code < 500 ? code : 500;
    console.error(
      JSON.stringify({
        event: "request_error",
        request_id: request.id,
        status,
      }),
    );
    reply
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
