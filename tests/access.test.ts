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

test("public Vercel web origin can use capped API without exposing server assets", async () => {
  const origin = "https://barasu-web.vercel.app";
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
    for (let i = 0; i < 4; i++) await app.inject({method:"POST",url:"/v1/chat/search",headers:{origin},payload:{}});
    assert.equal((await app.inject({method:"POST",url:"/v1/chat/search",headers:{origin},payload:{}})).statusCode, 429);
  } finally {
    await app.close();
  }
});
