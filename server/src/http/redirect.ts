import type { Context } from "hono";
import type { AppEnv } from "../types.js";

export function isSafeNextPath(path: unknown): path is string {
  if (typeof path !== "string" || !path || path.length > 512) return false;
  if (!path.startsWith("/") || path.startsWith("//") || path.startsWith("/\\")) return false;
  return !/[\\\u0000-\u001f\u007f]/.test(path);
}

export const NEXT_PREFIXES = ["/play/", "/account", "/register", "/login", "/feedback", "/pending"] as const;

function underPrefix(path: string, prefix: string): boolean {
  if (prefix.endsWith("/")) return path.startsWith(prefix);
  return path === prefix || path.startsWith(prefix + "/") || path.startsWith(prefix + "?") || path.startsWith(prefix + "#");
}

export function isAllowedNext(path: unknown): path is string {
  if (!isSafeNextPath(path)) return false;
  if (path === "/" || path.startsWith("/?") || path.startsWith("/#")) return true;
  return NEXT_PREFIXES.some((p) => underPrefix(path, p));
}

export function safeNext(raw: string | null | undefined, fallback = "/play/"): string {
  return isAllowedNext(raw) ? raw : fallback;
}

export function redirect303(c: Context<AppEnv>, path: string | null | undefined, fallback = "/"): Response {
  const target = isAllowedNext(path) ? path : fallback;
  c.header("Cache-Control", "no-store");
  return c.redirect(target, 303);
}

export function loginErrorPath(code: string, next?: string | null): string {
  const q = new URLSearchParams({ error: code });
  if (next && isAllowedNext(next) && next !== "/") q.set("next", next);
  return `/login?${q.toString()}`;
}
