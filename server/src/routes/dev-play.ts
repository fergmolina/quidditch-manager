import type { Hono } from "hono";
import { readStatic } from "../http/static.js";
import { PLAY_CSP } from "../http/security.js";
import type { AppEnv } from "../types.js";
import { gate } from "./api.js";

export function registerDevPlay(app: Hono<AppEnv>, dir: string, open = false): void {
  app.get("/play", (c) => c.redirect("/play/", 308));
  app.get("/play/*", async (c) => {
    const rel = c.req.path.slice("/play/".length) || "index.html";
    if (rel === "index.html") {
      if (!open) {
        const g = await gate(c);
        if (g.status !== 200) return g;
      }
      c.header("Cache-Control", "no-store");
    } else {
      c.header("Cache-Control", "no-cache");
    }
    const file = await readStatic(dir, rel);
    if (!file) return c.notFound();
    c.header("Content-Type", file.type);
    c.header("Content-Security-Policy-Report-Only", PLAY_CSP);
    return c.body(file.body as Uint8Array<ArrayBuffer>);
  });
}
