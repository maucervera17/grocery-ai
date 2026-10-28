import { cp, mkdir, readdir, rm } from "node:fs/promises";

const output = new URL("../dist/vercel-web/", import.meta.url);
await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });
for (const name of await readdir(new URL("../web/", import.meta.url))) {
  if (name.endsWith(".d.ts") || name === "voice-sdk.js") continue;
  await cp(new URL(`../web/${name}`, import.meta.url), new URL(name, output));
}
await cp(new URL("../dist/web/voice-sdk.js", import.meta.url), new URL("voice-sdk.js", output));
