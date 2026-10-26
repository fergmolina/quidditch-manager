import type { Context, Hono } from "hono";
import { BurstLimiter, hitRateLimit } from "../auth/rate-limit.js";
import { deleteSession, listSessions, revokeSession, type SessionUser } from "../auth/sessions.js";
import { deleteUserAccount, profileStatus } from "../auth/users.js";
import { clearSessionCookie, readSessionToken } from "../http/cookies.js";
import { loginErrorPath, redirect303, safeNext } from "../http/redirect.js";
import { noStore, privateJson } from "../http/respond.js";
import { getViewer, page, pathForStatus, tOf, viewerStatus } from "../http/viewer.js";
import { tooMany } from "./auth.js";
import { accountBody, ACCOUNT_SAVED, deleteBody, deletedBody, type AccountSaved, type AccountState } from "../pages/account.js";
import { staticUrl } from "../pages/layout.js";
import { profileScript } from "../pages/profile-form.js";
import { registerBody, type RegisterMode, type RegisterState } from "../pages/register.js";
import { countryFromHeader, normalizeCountry } from "../profile/countries.js";
import { findRegion, regionsFor, searchCities, toHit } from "../profile/geo.js";
import {
  acceptTerms,
  changeUsername,
  collectErrors,
  completeProfile,
  exportUserData,
  formValues,
  parseLocation,
  parseNames,
  parseUsername,
  ProfileWriteError,
  registerProfile,
  updateProfile,
  usernameAvailable,
  valuesFromUser,
  type FieldErrors,
  type ProfileFormValues,
} from "../profile/profile.js";
import { checkUsername, usernameCooldownUntilMs } from "../profile/username.js";
import type { AppEnv } from "../types.js";

type C = Context<AppEnv>;

export const PROFILE_WRITE_LIMIT = { bucket: "profile_write", limit: 30, windowMs: 15 * 60_000 } as const;
export const USERNAME_CHECK_PER_MINUTE = 30;

async function formOf(c: C): Promise<Record<string, string>> {
  const body = await c.req.parseBody().catch(() => ({}) as Record<string, unknown>);
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(body)) if (typeof v === "string") out[k] = v;
  return out;
}

export function registerNext(raw: string | null | undefined): string {
  const next = safeNext(raw, "/play/");
  return next.startsWith("/register") || next.startsWith("/login") ? "/play/" : next;
}

function toLogin(c: C, next: string): Response {
  return redirect303(c, `/login?${new URLSearchParams({ next }).toString()}`, "/login");
}

async function writeAllowed(c: C, v: SessionUser): Promise<boolean> {
  const { db, now } = c.get("deps");
  return hitRateLimit(db, { ...PROFILE_WRITE_LIMIT, subject: `user:${v.user.id}` }, now());
}

function script(): ReturnType<typeof profileScript> {
  return profileScript(staticUrl("register.js"));
}

function registerState(c: C, v: SessionUser, mode: RegisterMode, next: string, values: ProfileFormValues, errors: FieldErrors, termsChecked: boolean): RegisterState {
  const { config } = c.get("deps");
  return {
    lang: c.get("lang"),
    mode,
    next,
    values,
    errors,
    hasUsername: v.user.username !== null,
    currentUsername: v.user.username,
    termsDue: v.user.termsVersion !== config.termsVersion,
    termsChecked,
    minAge: config.minAge,
    email: v.user.email,
  };
}

async function renderRegister(c: C, s: RegisterState, status: 200 | 400 | 409 = 200): Promise<Response> {
  const t = tOf(c);
  const title = s.mode === "terms" ? t("web.register.terms_title") : s.mode === "rename" ? t("web.register.rename_title") : t("web.register.title");
  return page(c, { title, status, body: registerBody(t, s), head: s.mode === "terms" ? undefined : script() });
}

function errorStatus(errors: FieldErrors): 400 | 409 {
  return errors.username === "username_taken" || errors.form === "conflict" ? 409 : 400;
}

async function postRegister(c: C, v: SessionUser, mode: RegisterMode): Promise<Response> {
  const { db, config, now } = c.get("deps");
  const form = await formOf(c);
  const next = registerNext(form.next);
  const values = formValues(form);
  const termsChecked = form.terms === "yes";
  const state = (errors: FieldErrors) => registerState(c, v, mode, next, values, errors, termsChecked);
  if (form.action === "refresh" && mode === "register") return renderRegister(c, state({}));
  if (!(await writeAllowed(c, v))) return tooMany(c);

  const errors: FieldErrors = {};
  const done = (user: SessionUser["user"]) => redirect303(c, pathForStatus(profileStatus(user, config.termsVersion), next), "/play/");
  const fail = (e: unknown) => {
    if (!(e instanceof ProfileWriteError)) throw e;
    if (e.code === "username_taken" || e.code === "username_same") errors.username = e.code;
    else errors.form = e.code;
    return renderRegister(c, state(errors), errorStatus(errors));
  };

  if (mode === "terms") {
    if (!termsChecked) return renderRegister(c, state({ terms: "terms_required" }), 400);
    const user = await acceptTerms(db, v.user.id, config.termsVersion, now());
    return user ? done(user) : redirect303(c, loginErrorPath("blocked"));
  }

  if (mode === "rename") {
    const termsDue = v.user.termsVersion !== config.termsVersion;
    const username = parseUsername(values.username);
    Object.assign(errors, collectErrors(username));
    if (username.ok && v.user.username && username.value.toLowerCase() === v.user.username.toLowerCase()) errors.username = "username_same";
    if (termsDue && !termsChecked) errors.terms = "terms_required";
    if (username.ok && !errors.username && !(await usernameAvailable(db, username.value, v.user.id))) errors.username = "username_taken";
    if (!username.ok || Object.keys(errors).length) return renderRegister(c, state(errors), errorStatus(errors));
    try {
      const user = await db.transaction(async (tx) => {
        let u = await changeUsername(tx, v.user.id, username.value, now(), { forced: true });
        if (termsDue) u = (await acceptTerms(tx, v.user.id, config.termsVersion, now())) ?? u;
        return u;
      });
      return done(user);
    } catch (e) {
      return fail(e);
    }
  }

  const username = v.user.username === null ? parseUsername(values.username) : null;
  const names = parseNames(values);
  const location = parseLocation(values);
  Object.assign(errors, collectErrors(username, names, location));
  if (!termsChecked) errors.terms = "terms_required";
  if (username?.ok && !(await usernameAvailable(db, username.value, v.user.id))) errors.username = "username_taken";
  if (!names.ok || !location.ok || username?.ok === false || Object.keys(errors).length) return renderRegister(c, state(errors), errorStatus(errors));
  try {
    const profile = { ...names.value, location: location.value, termsVersion: config.termsVersion };
    const user = await (username ? registerProfile(db, v.user.id, { ...profile, username: username.value }, now()) : completeProfile(db, v.user.id, profile, now()));
    return done(user);
  } catch (e) {
    return fail(e);
  }
}

async function renderAccount(
  c: C,
  v: SessionUser,
  o: { profile?: ProfileFormValues; profileErrors?: FieldErrors; usernameValue?: string; usernameErrors?: FieldErrors; saved?: AccountSaved | null; status?: 200 | 400 | 409 },
): Promise<Response> {
  const { db, now } = c.get("deps");
  const t = tOf(c);
  const u = v.user;
  const state: AccountState = {
    lang: c.get("lang"),
    email: u.email,
    username: u.username ?? "",
    countryCode: u.countryCode,
    createdAt: u.createdAt,
    usernameLockedUntilMs: usernameCooldownUntilMs(u.usernameChangedAt, now()),
    profile: o.profile ?? valuesFromUser(u),
    profileErrors: o.profileErrors ?? {},
    usernameValue: o.usernameValue ?? "",
    usernameErrors: o.usernameErrors ?? {},
    sessions: await listSessions(db, u.id, v.session.publicId, now()),
    saved: o.saved ?? null,
  };
  return page(c, { title: t("web.account.title"), status: o.status ?? 200, body: accountBody(t, state), head: script() });
}

async function completeViewer(c: C, here: string): Promise<SessionUser | Response> {
  const v = await getViewer(c);
  if (!v) return toLogin(c, here);
  const status = viewerStatus(c, v);
  if (status !== "complete") return redirect303(c, pathForStatus(status, here), "/");
  return v;
}

async function ownerViewer(c: C, here: string): Promise<SessionUser | Response> {
  const v = await getViewer(c);
  if (!v) return toLogin(c, here);
  if (v.user.blockedAt) return redirect303(c, loginErrorPath("blocked"));
  return v;
}

export function registerProfileRoutes(app: Hono<AppEnv>): void {
  const usernameChecks = new BurstLimiter({ limit: USERNAME_CHECK_PER_MINUTE });

  app.get("/register", async (c) => {
    const next = registerNext(c.req.query("next"));
    const v = await getViewer(c);
    if (!v) return toLogin(c, next);
    const status = viewerStatus(c, v);
    if (status === "complete") return redirect303(c, next, "/play/");
    if (status === "blocked") return redirect303(c, loginErrorPath("blocked"));
    const values = valuesFromUser(v.user);
    if (status === "rename") values.username = "";
    if (!values.country) values.country = countryFromHeader(c.req.header("cf-ipcountry")) ?? "";
    return renderRegister(c, registerState(c, v, status, next, values, {}, false));
  });

  app.post("/register", async (c) => {
    const v = await getViewer(c);
    if (!v) return toLogin(c, "/play/");
    const status = viewerStatus(c, v);
    if (status === "blocked") return redirect303(c, loginErrorPath("blocked"));
    if (status === "complete") {
      const form = await formOf(c);
      return redirect303(c, registerNext(form.next), "/play/");
    }
    return postRegister(c, v, status);
  });

  app.get("/account", async (c) => {
    const v = await completeViewer(c, "/account");
    if (v instanceof Response) return v;
    const saved = c.req.query("saved");
    return renderAccount(c, v, { saved: (ACCOUNT_SAVED as readonly string[]).includes(saved ?? "") ? (saved as AccountSaved) : null });
  });

  app.post("/account/profile", async (c) => {
    const v = await completeViewer(c, "/account");
    if (v instanceof Response) return v;
    const form = await formOf(c);
    const values = { ...formValues(form), username: v.user.username ?? "" };
    if (form.action === "refresh") return renderAccount(c, v, { profile: values });
    if (!(await writeAllowed(c, v))) return tooMany(c);
    const names = parseNames(values);
    const location = parseLocation(values);
    if (!names.ok || !location.ok) return renderAccount(c, v, { profile: values, profileErrors: collectErrors(names, location), status: 400 });
    const { db } = c.get("deps");
    const user = await updateProfile(db, v.user.id, { ...names.value, location: location.value });
    if (!user) return redirect303(c, loginErrorPath("blocked"));
    return redirect303(c, "/account?saved=profile#profile-section", "/account");
  });

  app.post("/account/username", async (c) => {
    const v = await completeViewer(c, "/account");
    if (v instanceof Response) return v;
    const { db, now } = c.get("deps");
    if (usernameCooldownUntilMs(v.user.usernameChangedAt, now())) return redirect303(c, "/account#username-section", "/account");
    const form = await formOf(c);
    const raw = (form.username ?? "").slice(0, 64);
    if (raw.trim() === v.user.username) return redirect303(c, "/account#username-section", "/account");
    if (!(await writeAllowed(c, v))) return tooMany(c);
    const username = parseUsername(raw);
    const errors = collectErrors(username);
    if (username.ok && !(await usernameAvailable(db, username.value, v.user.id))) errors.username = "username_taken";
    if (!username.ok || errors.username) return renderAccount(c, v, { usernameValue: raw, usernameErrors: errors, status: errorStatus(errors) });
    try {
      await changeUsername(db, v.user.id, username.value, now(), { forced: false });
    } catch (e) {
      if (!(e instanceof ProfileWriteError)) throw e;
      errors.username = e.code;
      return renderAccount(c, v, { usernameValue: raw, usernameErrors: errors, status: errorStatus(errors) });
    }
    return redirect303(c, "/account?saved=username#username-section", "/account");
  });

  app.post("/account/sessions/revoke", async (c) => {
    const v = await ownerViewer(c, "/account");
    if (v instanceof Response) return v;
    const { db } = c.get("deps");
    const id = ((await formOf(c)).id ?? "").slice(0, 64);
    if (id === v.session.publicId) {
      await deleteSession(db, readSessionToken(c));
      clearSessionCookie(c);
      return redirect303(c, "/");
    }
    await revokeSession(db, v.user.id, id);
    return redirect303(c, "/account?saved=session#sessions-section", "/account");
  });

  app.get("/account/export", async (c) => {
    const v = await ownerViewer(c, "/account");
    if (v instanceof Response) return v;
    const { db, now } = c.get("deps");
    const data = await exportUserData(db, v.user.id, now());
    if (!data) return toLogin(c, "/account");
    const day = new Date(now()).toISOString().slice(0, 10);
    c.header("Content-Disposition", `attachment; filename="quidditch-manager-account-${day}.json"`);
    noStore(c);
    return c.body(JSON.stringify(data, null, 2) + "\n", 200, { "Content-Type": "application/json; charset=utf-8" });
  });

  app.get("/account/delete", async (c) => {
    const v = await ownerViewer(c, "/account/delete");
    if (v instanceof Response) return v;
    const t = tOf(c);
    const { config } = c.get("deps");
    return page(c, { title: t("web.account.delete_title"), body: deleteBody(t, { username: v.user.username, backupRetentionDays: config.backupRetentionDays }) });
  });

  app.post("/account/delete", async (c) => {
    const v = await ownerViewer(c, "/account/delete");
    if (v instanceof Response) return v;
    const { db, log, config } = c.get("deps");
    const form = await formOf(c);
    const typed = (form.confirm ?? "").trim();
    const ok = v.user.username ? typed.toLowerCase() === v.user.username.toLowerCase() : typed === "yes";
    if (!ok) {
      const t = tOf(c);
      return page(c, {
        title: t("web.account.delete_title"),
        status: 400,
        body: deleteBody(t, { username: v.user.username, backupRetentionDays: config.backupRetentionDays, error: "confirm_mismatch" }),
      });
    }
    await deleteUserAccount(db, v.user.id);
    clearSessionCookie(c);
    log.info("[account] an account was deleted by its owner");
    return redirect303(c, "/account/deleted");
  });

  app.get("/account/deleted", async (c) => {
    const t = tOf(c);
    return page(c, { title: t("web.account.deleted_title"), body: deletedBody(t) });
  });

  app.get("/api/geo/regions", async (c) => {
    if (!(await getViewer(c))) return privateJson(c, { error: "unauthorized" }, 401);
    const country = normalizeCountry(c.req.query("country"));
    if (!country) return privateJson(c, { error: "country_invalid" }, 400);
    return privateJson(c, { country, regions: regionsFor(country, c.get("lang")) });
  });

  app.get("/api/geo/cities", async (c) => {
    if (!(await getViewer(c))) return privateJson(c, { error: "unauthorized" }, 401);
    const country = normalizeCountry(c.req.query("country"));
    if (!country) return privateJson(c, { error: "country_invalid" }, 400);
    const region = (c.req.query("region") ?? "").trim();
    if (region && !findRegion(country, region)) return privateJson(c, { error: "region_invalid" }, 400);
    const q = (c.req.query("q") ?? "").slice(0, 60);
    return privateJson(c, { cities: searchCities(country, { region: region || null, q }).map((x) => toHit(country, x)) });
  });

  app.get("/api/username-available", async (c) => {
    const v = await getViewer(c);
    if (!v) return privateJson(c, { error: "unauthorized" }, 401);
    const d = usernameChecks.take(v.user.id);
    if (!d.allowed) {
      c.header("Retry-After", String(d.retryAfter));
      return privateJson(c, { error: "rate_limited" }, 429);
    }
    const check = checkUsername(c.req.query("u") ?? "");
    if (!check.ok) return privateJson(c, { available: false, error: check.error });
    const { db } = c.get("deps");
    const available = await usernameAvailable(db, check.value, v.user.id);
    return privateJson(c, { available, error: available ? null : "username_taken" });
  });
}
