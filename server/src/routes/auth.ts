import type { Context, Hono } from "hono";
import { encodeOAuthState, decodeOAuthState, exchangeGoogleCode, googleAuthUrl, newOAuthState, OAUTH_STATE_TTL_S, verifyGoogleIdToken } from "../auth/google.js";
import { consumeMagicLink, discardMagicLink, MAGIC_TTL_MS, magicLinkUrl, peekMagicLink, requestMagicLink } from "../auth/magic.js";
import { hitRateLimit } from "../auth/rate-limit.js";
import { magicFormSchema, verifyFormSchema } from "../auth/schemas.js";
import { createSession, deleteSession, deleteUserSessions } from "../auth/sessions.js";
import { findUserByGoogleSub, linkGoogle, profileStatus, recordLogin, upsertUserByEmail, type User } from "../auth/users.js";
import { clearOauthCookie, clearSessionCookie, readOauthCookie, readSessionToken, setOauthCookie, setSessionCookie } from "../http/cookies.js";
import { clientIp, ipKey } from "../http/ip.js";
import { isOwnOrigin, loginPostRejection, MAGIC_LANDING_REFERRER_POLICY } from "../http/origin.js";
import { loginErrorPath, redirect303, safeNext } from "../http/redirect.js";
import { userAgentFamily } from "../http/ua.js";
import { getViewer, page, pathForStatus, tOf, viewerStatus } from "../http/viewer.js";
import { bcp47, translator } from "../i18n/i18n.js";
import { normalizeLang } from "../i18n/negotiate.js";
import { magicLinkEmail } from "../mail/templates.js";
import { checkInboxBody, isLoginError, loginBody, type LoginError } from "../pages/login.js";
import { magicLandingBody } from "../pages/magic-landing.js";
import { messageCard } from "../pages/layout.js";
import type { AppEnv } from "../types.js";

type C = Context<AppEnv>;

export const VERIFY_LIMIT = { limit: 30, windowMs: 15 * 60_000 } as const;

async function formOf(c: C): Promise<Record<string, string>> {
  const body = await c.req.parseBody().catch(() => ({}) as Record<string, unknown>);
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(body)) if (typeof v === "string") out[k] = v;
  return out;
}

export function ipSubject(c: C): string {
  const { config } = c.get("deps");
  return ipKey(clientIp(c.req.raw.headers, config.trustedClientIpHeaders), config.authSecret);
}

async function renderLogin(c: C, opts: { next: string; error: LoginError | null; email?: string; status?: 200 | 400 | 429 | 502 }): Promise<Response> {
  const { config } = c.get("deps");
  const t = tOf(c);
  return page(c, {
    title: t("web.login.title"),
    status: opts.status ?? 200,
    body: loginBody(t, {
      lang: c.get("lang"),
      next: opts.next,
      error: opts.error,
      googleEnabled: !!config.google,
      emailEnabled: config.mail.enabled,
      ...(opts.email !== undefined ? { email: opts.email } : {}),
      signedIn: null,
    }),
  });
}

async function preventSessionFixation(c: C): Promise<void> {
  const { db } = c.get("deps");
  await deleteSession(db, readSessionToken(c)).catch(() => undefined);
}

async function finishLogin(c: C, user: User, next: string): Promise<Response> {
  const { db, now, config } = c.get("deps");
  await preventSessionFixation(c);
  const session = await createSession(db, user.id, { userAgentFamily: userAgentFamily(c.req.header("user-agent")) }, now());
  setSessionCookie(c, session.token, session.expiresAt);
  return redirect303(c, pathForStatus(profileStatus(user, config.termsVersion, config.accessMode), next), "/play/");
}

export function registerAuthRoutes(app: Hono<AppEnv>): void {
  app.get("/login", async (c) => {
    const next = safeNext(c.req.query("next"), "/play/");
    const err = c.req.query("error");
    const v = await getViewer(c);
    if (v && !isLoginError(err)) {
      const t = tOf(c);
      const status = viewerStatus(c, v);
      return page(c, {
        title: t("web.login.title"),
        body: loginBody(t, {
          lang: c.get("lang"),
          next,
          error: null,
          googleEnabled: false,
          emailEnabled: false,
          signedIn: { username: status === "complete" || status === "pending" ? v.user.username : null, continueHref: pathForStatus(status, next) },
        }),
      });
    }
    return renderLogin(c, { next, error: isLoginError(err) ? err : null });
  });

  app.post("/auth/magic", async (c) => {
    const { db, config, mailer, now, log } = c.get("deps");
    if (!config.mail.enabled) return redirect303(c, "/login");
    const form = await formOf(c);
    const parsed = magicFormSchema.safeParse(form);
    const next = safeNext(form.next, "/play/");
    if (!parsed.success) return renderLogin(c, { next, error: "email_invalid", email: (form.email ?? "").slice(0, 254), status: 400 });
    const lang = normalizeLang(parsed.data.lang) ?? c.get("lang");
    const email = parsed.data.email;
    const result = await requestMagicLink(db, { email, ipHash: ipSubject(c), nextPath: next, lang, dailyCap: config.mail.dailyCap }, now());
    if (!result.ok) return renderLogin(c, { next, error: result.error, email, status: 429 });
    const t = translator(lang);
    const minutes = Math.round(MAGIC_TTL_MS / 60_000);
    try {
      await mailer.send({ to: email, ...magicLinkEmail(t, magicLinkUrl(config.siteUrl, result.token), minutes) });
    } catch (e) {
      log.error(`[auth] magic link mail failed: ${e instanceof Error ? e.message : String(e)}`);
      await discardMagicLink(db, result.id).catch(() => undefined);
      return renderLogin(c, { next, error: "mail_failed", email, status: 502 });
    }
    return page(c, { title: tOf(c)("web.check.title"), body: checkInboxBody(tOf(c), { email, minutes, next }) });
  });

  app.get("/auth/magic/verify", async (c) => {
    const { db, now } = c.get("deps");
    const token = c.req.query("token") ?? "";
    if (!(await peekMagicLink(db, token, now()))) return redirect303(c, loginErrorPath("link"));
    c.header("Referrer-Policy", MAGIC_LANDING_REFERRER_POLICY);
    const t = tOf(c);
    return page(c, { title: t("web.magic.title"), body: magicLandingBody(t, token), bare: true });
  });

  app.post("/auth/magic/verify", async (c) => {
    const { db, config, now } = c.get("deps");
    const rejection = loginPostRejection(c.req.raw.headers, (o) => isOwnOrigin(o, config.siteOrigin, config.isProd));
    if (rejection) return forbidden(c);
    if (!(await hitRateLimit(db, { bucket: "magic_verify", subject: ipSubject(c), ...VERIFY_LIMIT }, now()))) return tooMany(c);
    const form = await formOf(c);
    const parsed = verifyFormSchema.safeParse(form);
    const link = parsed.success ? await consumeMagicLink(db, parsed.data.token, now()) : null;
    if (!link) return redirect303(c, loginErrorPath("link"));
    const user = await upsertUserByEmail(db, { email: link.email }, now());
    if (user.blockedAt) return redirect303(c, loginErrorPath("blocked"));
    return finishLogin(c, user, safeNext(link.nextPath, "/play/"));
  });

  app.get("/auth/google", async (c) => {
    const { config, now } = c.get("deps");
    const next = safeNext(c.req.query("next"), "/play/");
    if (!config.google) return redirect303(c, loginErrorPath("google_failed", next));
    const lang = c.get("lang");
    const s = newOAuthState(next, lang, now());
    setOauthCookie(c, encodeOAuthState(config.authSecret, s), OAUTH_STATE_TTL_S);
    c.header("Cache-Control", "no-store");
    return c.redirect(
      googleAuthUrl({ clientId: config.google.clientId, redirectUri: config.google.redirectUri, state: s.state, nonce: s.nonce, codeVerifier: s.verifier, language: bcp47(lang) }),
      302,
    );
  });

  app.get("/auth/google/callback", async (c) => {
    const { db, config, now, log, fetch: fetchImpl, googleKeys } = c.get("deps");
    const saved = decodeOAuthState(config.authSecret, readOauthCookie(c), c.req.query("state"), now());
    clearOauthCookie(c);
    const next = safeNext(saved?.next, "/play/");
    const fail = (code: LoginError) => redirect303(c, loginErrorPath(code, next));
    if (!config.google || !saved || c.req.query("error")) return fail("google_failed");
    const code = c.req.query("code");
    if (!code || code.length > 2048) return fail("google_failed");
    if (!(await hitRateLimit(db, { bucket: "google_callback", subject: ipSubject(c), ...VERIFY_LIMIT }, now()))) return tooMany(c);
    try {
      const { idToken } = await exchangeGoogleCode({
        code,
        codeVerifier: saved.verifier,
        clientId: config.google.clientId,
        clientSecret: config.google.clientSecret,
        redirectUri: config.google.redirectUri,
        fetchImpl,
      });
      const claims = await verifyGoogleIdToken(idToken, { clientId: config.google.clientId, nonce: saved.nonce, getKey: googleKeys, currentDate: new Date(now()) });
      if (!claims.emailVerified) return fail("google_unverified");
      let user = await findUserByGoogleSub(db, claims.sub);
      if (user) user = (await recordLogin(db, user.id, now())) ?? user;
      else {
        user = await upsertUserByEmail(db, { email: claims.email }, now());
        await linkGoogle(db, { sub: claims.sub, userId: user.id });
      }
      if (user.blockedAt) return fail("blocked");
      return finishLogin(c, user, next);
    } catch (e) {
      log.warn(`[auth] google callback: ${e instanceof Error ? e.message : String(e)}`);
      return fail("google_failed");
    }
  });

  app.post("/auth/logout", async (c) => {
    const { db } = c.get("deps");
    await deleteSession(db, readSessionToken(c)).catch(() => undefined);
    clearSessionCookie(c);
    return redirect303(c, "/");
  });

  app.post("/auth/logout-all", async (c) => {
    const { db } = c.get("deps");
    const v = await getViewer(c);
    if (v) await deleteUserSessions(db, v.user.id);
    clearSessionCookie(c);
    return redirect303(c, "/");
  });
}

export async function forbidden(c: C): Promise<Response> {
  const t = tOf(c);
  if (c.req.path.startsWith("/api/")) {
    c.header("Cache-Control", "no-store");
    return c.json({ error: "origin" }, 403);
  }
  return page(c, {
    title: t("web.error.title"),
    status: 403,
    body: messageCard({ title: t("web.error.title"), paragraphs: [t("web.login.error.origin")], actions: undefined }),
  });
}

export async function tooMany(c: C): Promise<Response> {
  const t = tOf(c);
  if (c.req.path.startsWith("/api/")) {
    c.header("Cache-Control", "no-store");
    return c.json({ error: "rate_limited" }, 429);
  }
  return page(c, { title: t("web.error.title"), status: 429, body: messageCard({ title: t("web.error.title"), paragraphs: [t("web.error.429")] }) });
}
