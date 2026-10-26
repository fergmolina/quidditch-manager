import type { Context, Hono } from "hono";
import { seasonReportSchema, storeSeasonReport } from "../career/report.js";
import { BurstLimiter } from "../auth/rate-limit.js";
import { rotateSessionIfDue, touchSession } from "../auth/sessions.js";
import { clearSessionCookie, readSessionToken, setSessionCookie } from "../http/cookies.js";
import { clientIp, ipBucket } from "../http/ip.js";
import { safeNext } from "../http/redirect.js";
import { privateJson } from "../http/respond.js";
import { getViewer, pathForStatus, viewerStatus } from "../http/viewer.js";
import type { AppEnv } from "../types.js";

type C = Context<AppEnv>;

/** The JSON body of GET /api/me. Never contains the email, the real names or the location. */
export interface MeResponse {
  logged_in: boolean;
  username: string | null;
  /** ISO 3166-1 alpha-2 (or XK) */
  country: string | null;
  /** the negotiated page language (game code: es, en, …, pt_BR, zh_CN) */
  locale: string;
  profile_complete: boolean;
  /** the profile is done but the account waits for the operator (ACCESS_MODE=approval); profile_complete is then false */
  pending: boolean;
}

export function gateNext(forwardedUri: string | null | undefined): string {
  if (forwardedUri && forwardedUri.startsWith("/play/")) return safeNext(forwardedUri.split("#")[0], "/play/");
  return "/play/";
}

export function registerApiRoutes(app: Hono<AppEnv>, burst: BurstLimiter | null): void {
  // Caddy forward_auth for the /play/ HTML: 200 lets Caddy serve it; anything else is passed to the browser as is.
  // Never renews the session (Caddy drops a 2xx's headers, so a Set-Cookie here would be lost).
  // Registered before the burst middleware so Caddy's probes never spend the player's allowance.
  app.on(["GET", "HEAD"], "/api/gate", (c) => gate(c));

  if (burst) {
    app.use("/api/*", async (c, next) => {
      const v = await getViewer(c).catch(() => null);
      const { config } = c.get("deps");
      const subject = v ? `user:${v.user.id}` : `ip:${ipBucket(clientIp(c.req.raw.headers, config.trustedClientIpHeaders))}`;
      const d = burst.take(subject);
      if (!d.allowed) {
        c.header("Retry-After", String(d.retryAfter));
        return privateJson(c, { error: "rate_limited" }, 429);
      }
      return next();
    });
  }

  app.get("/api/me", async (c) => {
    const { db, now } = c.get("deps");
    const v = await getViewer(c);
    if (!v) {
      if (readSessionToken(c)) clearSessionCookie(c);
      const body: MeResponse = { logged_in: false, username: null, country: null, locale: c.get("lang"), profile_complete: false, pending: false };
      return privateJson(c, body, 401);
    }
    const rotated = await rotateSessionIfDue(db, v.session, now()).catch(() => null);
    if (rotated) setSessionCookie(c, rotated.token, rotated.expiresAt);
    else await touchSession(db, v.session, now()).catch(() => undefined);
    const status = viewerStatus(c, v);
    const body: MeResponse = {
      logged_in: true,
      username: v.user.username,
      country: v.user.countryCode,
      locale: c.get("lang"),
      profile_complete: status === "complete",
      pending: status === "pending",
    };
    return privateJson(c, body);
  });

  app.post("/api/career/season", async (c) => {
    const { db, now } = c.get("deps");
    const v = await getViewer(c);
    if (!v || viewerStatus(c, v) !== "complete") return privateJson(c, { error: "not_signed_in" }, 401);
    const len = Number(c.req.header("content-length") ?? "0");
    if (!Number.isFinite(len) || len > 4096) return privateJson(c, { error: "too_large" }, 413);
    let raw: unknown;
    try {
      raw = await c.req.json();
    } catch {
      return privateJson(c, { error: "bad_json" }, 400);
    }
    const parsed = seasonReportSchema.safeParse(raw);
    if (!parsed.success) return privateJson(c, { error: "invalid_report" }, 400);
    const out = await storeSeasonReport(db, v.user.id, parsed.data, now());
    switch (out.status) {
      case "stored":
        return privateJson(c, { ok: true, flagged: out.flagged });
      case "duplicate":
        return privateJson(c, { ok: true, duplicate: true });
      case "conflict":
        return privateJson(c, { error: out.error }, 409);
      case "limited":
        return privateJson(c, { error: out.error }, 429);
    }
  });
}

export async function gate(c: C): Promise<Response> {
  c.header("Cache-Control", "no-store");
  const next = gateNext(c.req.header("x-forwarded-uri") ?? c.req.query("next"));
  const method = (c.req.header("x-forwarded-method") ?? "GET").toUpperCase();
  const navigation = method === "GET" || method === "HEAD";
  const v = await getViewer(c);
  if (!v) {
    if (!navigation) return c.body(null, 401);
    return c.redirect(`/login?${new URLSearchParams({ next }).toString()}`, 302);
  }
  const status = viewerStatus(c, v);
  if (status === "complete") return c.body(null, 200);
  if (!navigation) return c.body(null, 401);
  return c.redirect(pathForStatus(status, next), 302);
}

export function registerHealth(app: Hono<AppEnv>): void {
  app.get("/healthz", async (c) => {
    c.header("Cache-Control", "no-store");
    try {
      await c.get("deps").db.query("select 1 as ok");
      return c.text("ok");
    } catch {
      return c.text("db unavailable", 503);
    }
  });
}
