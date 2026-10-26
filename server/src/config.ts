import { randomBytes } from "node:crypto";
import { z } from "zod";

export const DEFAULT_TERMS_VERSION = "2026-11-01";
export const MIN_AGE = 13;

const bool = z
  .string()
  .trim()
  .toLowerCase()
  .transform((v) => !["0", "false", "off", "no", ""].includes(v));

const optionalText = z
  .string()
  .trim()
  .transform((v) => (v === "" ? undefined : v))
  .optional();

const intFrom = (def: number, min = 0) =>
  z
    .string()
    .trim()
    .optional()
    .transform((v, ctx) => {
      if (v === undefined || v === "") return def;
      const n = Number.parseInt(v, 10);
      if (!Number.isFinite(n) || n < min) {
        ctx.addIssue({ code: "custom", message: `expected an integer >= ${min}` });
        return z.NEVER;
      }
      return n;
    });

const offAtZero = (n: number): number | null => (n === 0 ? null : n);

export const DEFAULT_TRUSTED_PROXY_HEADER = "cf-connecting-ip";
const HEADER_NAME_RE = /^[a-z0-9-]+$/;

const envSchema = z.object({
  NODE_ENV: z.enum(["production", "development", "test"]).default("development"),
  HOST: z.string().trim().default("0.0.0.0"),
  PORT: intFrom(8080, 1),
  SITE_URL: optionalText,
  DATABASE_URL: optionalText,
  DB_POOL_MAX: intFrom(5, 1),
  GOOGLE_CLIENT_ID: optionalText,
  GOOGLE_CLIENT_SECRET: optionalText,
  RESEND_API_KEY: optionalText,
  MAIL_FROM: optionalText,
  LOGIN_EMAIL: bool.optional(),
  MAIL_DAILY_CAP: intFrom(90, 0),
  TERMS_VERSION: optionalText,
  AUTH_SECRET: optionalText,
  SESSION_RATE_PER_MINUTE: intFrom(60, 0),
  TRUSTED_PROXY_HEADER: optionalText,
  BACKUP_RETENTION_DAYS: intFrom(45, 1),
  DEV_PLAY_DIR: optionalText,
  DEV_PLAY_OPEN: optionalText,
  DOWNLOADS_URL: optionalText,
  FEEDBACK_TO: optionalText,
  LEGAL_CONTROLLER: optionalText,
  LEGAL_CONTACT_EMAIL: optionalText,
});

const LEGAL_EMAIL_RE = /^[^\s@<>()[\]"'`]{1,64}@[A-Za-z0-9.-]{1,190}\.[A-Za-z]{2,24}$/;

export interface GoogleConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
}

export interface Config {
  env: "production" | "development" | "test";
  isProd: boolean;
  host: string;
  port: number;
  siteUrl: string;
  siteOrigin: string;
  databaseUrl: string;
  dbPoolMax: number;
  google: GoogleConfig | null;
  mail: { enabled: boolean; resendApiKey: string | null; from: string; dailyCap: number | null };
  termsVersion: string;
  minAge: number;
  authSecret: Buffer;
  authSecretFromEnv: boolean;
  sessionRatePerMinute: number | null;
  trustedClientIpHeaders: readonly string[];
  backupRetentionDays: number;
  devPlayDir: string | null;
  devPlayOpen: boolean;
  downloadsUrl: string | null;
  feedbackTo: string | null;
  legal: { controller: string | null; contactEmail: string | null };
}

export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConfigError";
  }
}

function stripSlash(url: string): string {
  return url.replace(/\/+$/, "");
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env, randomKey: () => Buffer = defaultRandomKey): Config {
  const parsed = envSchema.safeParse(env);
  if (!parsed.success) {
    throw new ConfigError("invalid environment: " + parsed.error.issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; "));
  }
  const e = parsed.data;
  const isProd = e.NODE_ENV === "production";
  const problems: string[] = [];

  let siteUrl = e.SITE_URL ? stripSlash(e.SITE_URL) : isProd ? "" : `http://localhost:${e.PORT}`;
  let siteOrigin = "";
  if (!siteUrl) problems.push("SITE_URL is required in production");
  else {
    try {
      const u = new URL(siteUrl);
      siteOrigin = u.origin;
      if (u.pathname !== "/" && u.pathname !== "") problems.push("SITE_URL must be an origin without a path");
      if (isProd && u.protocol !== "https:") problems.push("SITE_URL must be https in production");
      siteUrl = siteOrigin;
    } catch {
      problems.push("SITE_URL is not a URL");
    }
  }

  const databaseUrl = e.DATABASE_URL ?? (isProd ? "" : "postgres://postgres:postgres@127.0.0.1:5432/qm");
  if (!databaseUrl) problems.push("DATABASE_URL is required in production");

  let google: GoogleConfig | null = null;
  if (e.GOOGLE_CLIENT_ID || e.GOOGLE_CLIENT_SECRET) {
    if (!e.GOOGLE_CLIENT_ID || !e.GOOGLE_CLIENT_SECRET) problems.push("GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET go together");
    else google = { clientId: e.GOOGLE_CLIENT_ID, clientSecret: e.GOOGLE_CLIENT_SECRET, redirectUri: `${siteUrl}/auth/google/callback` };
  }

  const loginEmail = e.LOGIN_EMAIL ?? true;
  if (isProd && loginEmail && !e.RESEND_API_KEY) problems.push("RESEND_API_KEY is required in production (or set LOGIN_EMAIL=off)");
  if (isProd && loginEmail && !e.MAIL_FROM) problems.push("MAIL_FROM is required in production when email login is on");
  if (isProd && !loginEmail && !google) problems.push("no login method: configure Google or turn email login on");

  const authSecretFromEnv = !!e.AUTH_SECRET;
  if (e.AUTH_SECRET && e.AUTH_SECRET.length < 32) problems.push("AUTH_SECRET must be at least 32 characters");

  const trustedProxyHeader = (e.TRUSTED_PROXY_HEADER ?? DEFAULT_TRUSTED_PROXY_HEADER).toLowerCase();
  if (!HEADER_NAME_RE.test(trustedProxyHeader)) problems.push("TRUSTED_PROXY_HEADER is not a header name");

  let devPlayDir: string | null = e.DEV_PLAY_DIR ?? null;
  if (devPlayDir && isProd) problems.push("DEV_PLAY_DIR is refused in production (Caddy serves /play/)");
  if (isProd) devPlayDir = null;
  const devPlayOpen = !isProd && devPlayDir !== null && ["1", "true", "yes"].includes(String(e.DEV_PLAY_OPEN ?? "").toLowerCase());
  if (e.DEV_PLAY_OPEN && isProd) problems.push("DEV_PLAY_OPEN is refused in production");

  let downloadsUrl: string | null = e.DOWNLOADS_URL ?? null;
  if (downloadsUrl) {
    try {
      if (new URL(downloadsUrl).protocol !== "https:") problems.push("DOWNLOADS_URL must be https");
    } catch {
      problems.push("DOWNLOADS_URL is not a URL");
    }
  }

  const feedbackTo = e.FEEDBACK_TO ?? null;
  if (feedbackTo && !z.email().max(254).safeParse(feedbackTo).success) problems.push("FEEDBACK_TO is not an email address");

  if (problems.length) throw new ConfigError(problems.join("; "));

  return {
    env: e.NODE_ENV,
    isProd,
    host: e.HOST,
    port: e.PORT,
    siteUrl,
    siteOrigin,
    databaseUrl,
    dbPoolMax: e.DB_POOL_MAX,
    google,
    mail: {
      enabled: loginEmail,
      resendApiKey: e.RESEND_API_KEY ?? null,
      from: e.MAIL_FROM ?? "Quidditch Manager <login@example.invalid>",
      dailyCap: offAtZero(e.MAIL_DAILY_CAP),
    },
    termsVersion: e.TERMS_VERSION ?? DEFAULT_TERMS_VERSION,
    minAge: MIN_AGE,
    authSecret: e.AUTH_SECRET ? Buffer.from(e.AUTH_SECRET, "utf8") : randomKey(),
    authSecretFromEnv,
    sessionRatePerMinute: offAtZero(e.SESSION_RATE_PER_MINUTE),
    trustedClientIpHeaders: isProd ? [trustedProxyHeader] : [trustedProxyHeader, "x-forwarded-for"],
    backupRetentionDays: e.BACKUP_RETENTION_DAYS,
    devPlayDir,
    devPlayOpen,
    downloadsUrl,
    feedbackTo,
    legal: {
      controller: e.LEGAL_CONTROLLER?.replace(/\s+/g, " ").slice(0, 200) ?? null,
      contactEmail: e.LEGAL_CONTACT_EMAIL && LEGAL_EMAIL_RE.test(e.LEGAL_CONTACT_EMAIL) ? e.LEGAL_CONTACT_EMAIL : null,
    },
  };
}

function defaultRandomKey(): Buffer {
  return randomBytes(32);
}

export function testConfig(overrides: Partial<Config> = {}): Config {
  const base = loadConfig({ NODE_ENV: "test", SITE_URL: "http://localhost:8080", AUTH_SECRET: "test-secret-test-secret-test-secret!!" });
  return { ...base, ...overrides };
}
