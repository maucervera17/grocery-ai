import test from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../backend/app.js";

const authorization = "Basic " + Buffer.from("barasu:long-private-access-password").toString("base64");

test("remote deployment protects application and paid routes while exposing health", async () => {
  const app = buildApp(
    { mode: "demo", fixtures: [] },
    { apiKey: "private", agentId: "agent", fetcher: async () => new Response('{"token":"temporary"}') },
    "long-private-access-password",
  );
  try {
    assert.equal((await app.inject("/health")).statusCode, 200);
    for (const url of ["/privacidad", "/privacidad.html"]) {
      const privacy = await app.inject(url);
      assert.equal(privacy.statusCode, 200);
      assert.match(privacy.body, /Aviso de privacidad/);
    }
    const denied = await app.inject("/");
    assert.equal(denied.statusCode, 401);
    assert.match(String(denied.headers["www-authenticate"]), /Basic/);
    assert.equal((await app.inject({method:"POST",url:"/v1/chat/search",payload:{},headers:{authorization:"Basic " + Buffer.from("barasu:wrong").toString("base64")}})).statusCode, 401);
    assert.equal((await app.inject({method:"GET",url:"/v1/voice/status",headers:{authorization}})).statusCode, 200);
    const voice = await app.inject({method:"POST",url:"/v1/voice/session",remoteAddress:"10.0.0.2",headers:{authorization,host:"barasu-api.onrender.com",origin:"https://barasu-api.onrender.com"}});
    assert.equal(voice.statusCode, 200);
    assert.deepEqual(voice.json(), { conversation_token: "temporary" });
    const nativeVoice = await app.inject({method:"POST",url:"/v1/voice/session",remoteAddress:"10.0.0.3",headers:{authorization,host:"barasu-api.onrender.com"}});
    assert.equal(nativeVoice.statusCode, 200);
    assert.deepEqual(nativeVoice.json(), { conversation_token: "temporary" });
    const nativeDenied = await app.inject({method:"POST",url:"/v1/voice/session",remoteAddress:"10.0.0.3",headers:{host:"barasu-api.onrender.com"}});
    assert.equal(nativeDenied.statusCode, 401);
    const foreignOrigin = await app.inject({method:"POST",url:"/v1/voice/session",remoteAddress:"10.0.0.2",headers:{authorization,host:"barasu-api.onrender.com",origin:"https://other.example"}});
    assert.equal(foreignOrigin.statusCode, 403);
  } finally {
    await app.close();
  }
});

test("public Vercel search is capped per client while server assets stay protected", async () => {
  const origin = "https://barasu-web.vercel.app";
  // A daily cap keeps the test independent of minute boundaries.
  process.env.PUBLIC_SEARCH_PER_CLIENT_DAILY = "4";
  process.env.PUBLIC_SEARCH_PER_CLIENT_MINUTE = "100";
  const app = buildApp(
    { mode: "demo", fixtures: [] },
    { apiKey: "private", agentId: "agent", fetcher: async () => new Response('{"token":"temporary"}') },
    "long-private-access-password",
    origin,
  );
  try {
    assert.equal((await app.inject("/")).statusCode, 401);
    assert.equal((await app.inject("/v1/voice/status")).statusCode, 200);
    assert.equal((await app.inject({method:"POST",url:"/v1/chat/search",headers:{origin},payload:{}})).statusCode, 400);
    assert.equal((await app.inject({method:"POST",url:"/v1/chat/search",headers:{origin:"https://other.example"},payload:{}})).statusCode, 401);
    assert.equal((await app.inject({method:"POST",url:"/v1/chat/search",payload:{}})).statusCode, 401);
    const voice = await app.inject({method:"POST",url:"/v1/voice/session",remoteAddress:"10.0.0.2",headers:{origin,host:"barasu-api.onrender.com"}});
    assert.equal(voice.statusCode, 200);
    assert.deepEqual(voice.json(), {conversation_token:"temporary"});
    const searchAs = (client: string, extra: Record<string, string> = {origin}) =>
      app.inject({method:"POST",url:"/v1/chat/search",headers:{...extra,"x-forwarded-for":`${client}, 10.1.1.1`},payload:{action:"compare",items:[]}});
    for (let i = 0; i < 4; i++) assert.equal((await searchAs("203.0.113.7")).statusCode, 200);
    const capped = await searchAs("203.0.113.7");
    assert.equal(capped.statusCode, 429);
    assert.equal(capped.headers["retry-after"], "3600");
    assert.equal(capped.json().error, "PUBLIC_DEMO_LIMIT");
    // Another client is unaffected, and the password still bypasses the public caps.
    assert.equal((await searchAs("198.51.100.9")).statusCode, 200);
    assert.equal((await searchAs("203.0.113.7", {authorization})).statusCode, 200);
  } finally {
    delete process.env.PUBLIC_SEARCH_PER_CLIENT_DAILY;
    delete process.env.PUBLIC_SEARCH_PER_CLIENT_MINUTE;
    await app.close();
  }
});

test("public search has a global cap that spoofed client ids cannot escape", async () => {
  const origin = "https://barasu-web.vercel.app";
  process.env.PUBLIC_SEARCH_MINUTE = "3";
  const app = buildApp({ mode: "demo", fixtures: [] }, {}, "long-private-access-password", origin);
  try {
    const statuses = [];
    for (let i = 0; i < 5; i++) {
      const result = await app.inject({method:"POST",url:"/v1/chat/search",headers:{origin,"x-forwarded-for":`192.0.2.${i}`},payload:{action:"compare",items:[]}});
      statuses.push(result.statusCode);
    }
    assert.deepEqual(statuses, [200, 200, 200, 429, 429]);
  } finally {
    delete process.env.PUBLIC_SEARCH_MINUTE;
    await app.close();
  }
});
