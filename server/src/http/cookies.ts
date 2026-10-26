import type { Context } from "hono";
import { deleteCookie, getCookie, setCookie } from "hono/cookie";
import type { AppEnv } from "../types.js";

export const SESSION_COOKIE_PROD = "__Host-qm_session";
export const SESSION_COOKIE_DEV = "qm_session";
export const OAUTH_COOKIE_PROD = "__Host-qm_oauth";
export const OAUTH_COOKIE_DEV = "qm_oauth";
export const LANG_COOKIE = "qm_lang";

export function sessionCookieName(isProd: boolean): string {
  return isProd ? SESSION_COOKIE_PROD : SESSION_COOKIE_DEV;
}

export function oauthCookieName(isProd: boolean): string {
  return isProd ? OAUTH_COOKIE_PROD : OAUTH_COOKIE_DEV;
}

type C = Context<AppEnv>;

const isProdOf = (c: C) => c.get("deps").config.isProd;

export function readSessionToken(c: C): string | null {
  const v = getCookie(c, sessionCookieName(isProdOf(c)));
  return v ? v : null;
}

export function setSessionCookie(c: C, token: string, expiresAt: string): void {
  setCookie(c, sessionCookieName(isProdOf(c)), token, {
    httpOnly: true,
    secure: isProdOf(c),
    sameSite: "Lax",
    path: "/",
    expires: new Date(expiresAt),
  });
}

export function clearSessionCookie(c: C): void {
  deleteCookie(c, sessionCookieName(isProdOf(c)), { path: "/", secure: isProdOf(c), httpOnly: true, sameSite: "Lax" });
}

export function readOauthCookie(c: C): string | null {
  return getCookie(c, oauthCookieName(isProdOf(c))) ?? null;
}

export function setOauthCookie(c: C, value: string, maxAgeSeconds: number): void {
  setCookie(c, oauthCookieName(isProdOf(c)), value, {
    httpOnly: true,
    secure: isProdOf(c),
    sameSite: "Lax",
    path: "/",
    maxAge: maxAgeSeconds,
  });
}

export function clearOauthCookie(c: C): void {
  deleteCookie(c, oauthCookieName(isProdOf(c)), { path: "/", secure: isProdOf(c), httpOnly: true, sameSite: "Lax" });
}

export function readLangCookie(c: C): string | null {
  return getCookie(c, LANG_COOKIE) ?? null;
}

export function setLangCookie(c: C, lang: string): void {
  setCookie(c, LANG_COOKIE, lang, { httpOnly: false, secure: isProdOf(c), sameSite: "Lax", path: "/", maxAge: 31_536_000 });
}
