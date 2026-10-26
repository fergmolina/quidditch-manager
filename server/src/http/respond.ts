import type { Context } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import type { SafeHtml } from "./html.js";
import type { AppEnv } from "../types.js";

export const NO_STORE = "private, no-store";

export function noStore(c: Context<AppEnv>): void {
  c.header("Cache-Control", NO_STORE);
  c.header("Vary", "Cookie");
}

export function privateJson(c: Context<AppEnv>, body: unknown, status: ContentfulStatusCode = 200): Response {
  noStore(c);
  return c.json(body as object, status);
}

export function htmlPage(c: Context<AppEnv>, page: SafeHtml | string, status: ContentfulStatusCode = 200): Response {
  noStore(c);
  return c.html(String(page), status);
}
