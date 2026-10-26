import type { HeaderBag } from "./ip.js";

const LOCAL_ORIGIN_RE = /^http:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/;

export function isOwnOrigin(origin: string | null | undefined, siteOrigin: string, isProd: boolean): boolean {
  if (!origin) return false;
  return origin === siteOrigin || (!isProd && LOCAL_ORIGIN_RE.test(origin));
}

export type OriginRejection = "fetch_site" | "origin";

export function sameOriginRejection(headers: HeaderBag, originOk: (origin: string) => boolean): OriginRejection | null {
  const origin = headers.get("origin");
  if (!origin || !originOk(origin)) return "origin";
  const fetchSite = headers.get("sec-fetch-site");
  if (fetchSite) {
    const v = fetchSite.trim().toLowerCase();
    if (v !== "same-origin" && v !== "none") return "fetch_site";
  }
  return null;
}

/**
 * Referrer-Policy of the magic landing page. Its URL carries the login token, so no other origin may see it as a referrer,
 * while its own POST still sends a full Referer: loginPostRejection falls back on it when the browser sends no Origin.
 */
export const MAGIC_LANDING_REFERRER_POLICY = "same-origin";

export function loginPostRejection(headers: HeaderBag, originOk: (origin: string) => boolean): OriginRejection | null {
  const fetchSite = headers.get("sec-fetch-site");
  if (fetchSite !== null && fetchSite !== undefined && fetchSite.trim().toLowerCase() !== "same-origin") return "fetch_site";
  const origin = headers.get("origin");
  if (origin !== null && origin !== undefined) return originOk(origin) ? null : "origin";
  const referer = headers.get("referer");
  if (!referer) return "origin";
  try {
    return originOk(new URL(referer).origin) ? null : "origin";
  } catch {
    return "origin";
  }
}
