import type { MiddlewareHandler } from "hono";
import type { AppEnv } from "../types.js";

export const PAGE_CSP = [
  "default-src 'none'",
  "script-src 'self'",
  "style-src 'self'",
  "img-src 'self' data:",
  "font-src 'self'",
  "connect-src 'self'",
  "form-action 'self'",
  "frame-ancestors 'none'",
  "base-uri 'none'",
].join("; ");

export const PLAY_CSP = [
  "default-src 'none'",
  "script-src 'self' 'wasm-unsafe-eval'",
  "style-src 'self'",
  "img-src 'self' blob: data:",
  "font-src 'self'",
  "connect-src 'self'",
  "worker-src 'self' blob:",
  "media-src 'self' blob:",
  "form-action 'self'",
  "frame-ancestors 'none'",
  "base-uri 'none'",
].join("; ");

const PERMISSIONS = "camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()";

export function securityHeaders(): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    await next();
    const h = c.res.headers;
    const set = (k: string, v: string) => {
      if (!h.has(k)) h.set(k, v);
    };
    if (!h.has("Content-Security-Policy-Report-Only")) set("Content-Security-Policy", PAGE_CSP);
    set("X-Content-Type-Options", "nosniff");
    set("X-Frame-Options", "DENY");
    set("Referrer-Policy", "strict-origin-when-cross-origin");
    set("Permissions-Policy", PERMISSIONS);
    set("Cross-Origin-Opener-Policy", "same-origin");
    set("Cross-Origin-Resource-Policy", "same-origin");
    if (c.get("deps").config.isProd) set("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
    // Indexable pages set "index, follow" themselves (page() with `seo`). robots.txt and the sitemap keep the
    // noindex: engines still read them, they just never show them as results.
    const path = c.req.path;
    if (path !== "/" && !path.startsWith("/static/")) set("X-Robots-Tag", "noindex, nofollow");
  };
}
