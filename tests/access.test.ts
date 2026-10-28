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
    const foreignOrigin = await app.inject({method:"POST",url:"/v1/voice/session",remoteAddress:"10.0.0.2",headers:{authorization,host:"barasu-api.onrender.com",origin:"https://other.example"}});
    assert.equal(foreignOrigin.statusCode, 403);
  } finally {
    await app.close();
  }
});
