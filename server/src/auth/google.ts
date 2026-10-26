import { createHash } from "node:crypto";
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";
import { randomToken, safeEqual, signPayload, verifySigned } from "./tokens.js";

export const GOOGLE_AUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth";
export const GOOGLE_TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";
export const GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs";
export const GOOGLE_ISSUERS = ["https://accounts.google.com", "accounts.google.com"];
export const OAUTH_STATE_TTL_S = 600;
const CLOCK_TOLERANCE_S = 60;
const MAX_ID_TOKEN_LENGTH = 8192;

export class GoogleOAuthError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
    this.name = "GoogleOAuthError";
  }
}

export function pkceVerifier(): string {
  return randomToken();
}

export function pkceChallenge(verifier: string): string {
  return createHash("sha256").update(verifier).digest("base64url");
}

export interface GoogleAuthUrlInput {
  clientId: string;
  redirectUri: string;
  state: string;
  nonce: string;
  codeVerifier: string;
  language?: string;
}

export function googleAuthUrl({ clientId, redirectUri, state, nonce, codeVerifier, language }: GoogleAuthUrlInput): string {
  const url = new URL(GOOGLE_AUTH_ENDPOINT);
  url.searchParams.set("client_id", clientId);
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", "openid email profile");
  url.searchParams.set("state", state);
  url.searchParams.set("nonce", nonce);
  url.searchParams.set("code_challenge", pkceChallenge(codeVerifier));
  url.searchParams.set("code_challenge_method", "S256");
  url.searchParams.set("prompt", "select_account");
  if (language) url.searchParams.set("hl", language);
  return url.toString();
}

export interface OAuthState {
  state: string;
  verifier: string;
  nonce: string;
  next: string;
  lang: string;
  expiresAtSec: number;
}

export function newOAuthState(next: string, lang: string, nowMs = Date.now()): OAuthState {
  return { state: randomToken(16), verifier: pkceVerifier(), nonce: randomToken(16), next, lang, expiresAtSec: Math.floor(nowMs / 1000) + OAUTH_STATE_TTL_S };
}

export function encodeOAuthState(key: Buffer, s: OAuthState): string {
  return signPayload(key, s);
}

export function decodeOAuthState(key: Buffer, cookie: string | null | undefined, stateParam: string | null | undefined, nowMs = Date.now()): OAuthState | null {
  if (!stateParam) return null;
  const s = verifySigned<Partial<OAuthState>>(key, cookie);
  if (!s || typeof s.state !== "string" || typeof s.verifier !== "string" || typeof s.nonce !== "string") return null;
  if (typeof s.expiresAtSec !== "number" || s.expiresAtSec * 1000 <= nowMs) return null;
  if (!safeEqual(s.state, stateParam)) return null;
  return { state: s.state, verifier: s.verifier, nonce: s.nonce, next: typeof s.next === "string" ? s.next : "/play/", lang: typeof s.lang === "string" ? s.lang : "en", expiresAtSec: s.expiresAtSec };
}

export interface ExchangeInput {
  code: string;
  codeVerifier: string;
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  fetchImpl?: typeof fetch;
}

export async function exchangeGoogleCode({ code, codeVerifier, clientId, clientSecret, redirectUri, fetchImpl = fetch }: ExchangeInput): Promise<{ idToken: string }> {
  const res = await fetchImpl(GOOGLE_TOKEN_ENDPOINT, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
    body: new URLSearchParams({
      code,
      code_verifier: codeVerifier,
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: redirectUri,
      grant_type: "authorization_code",
    }),
    signal: AbortSignal.timeout(10_000),
  });
  const body = (await res.json().catch(() => null)) as { id_token?: unknown; error?: string } | null;
  if (!res.ok || typeof body?.id_token !== "string") {
    throw new GoogleOAuthError(`token exchange failed: ${body?.error ?? res.status}`, res.status);
  }
  return { idToken: body.id_token };
}

export interface GoogleClaims {
  sub: string;
  email: string;
  emailVerified: boolean;
}

let remoteKeys: JWTVerifyGetKey | null = null;
export function googleRemoteKeys(): JWTVerifyGetKey {
  return (remoteKeys ??= createRemoteJWKSet(new URL(GOOGLE_JWKS_URL)));
}

export async function verifyGoogleIdToken(
  idToken: string,
  opts: { clientId: string; nonce: string; getKey: JWTVerifyGetKey; currentDate?: Date },
): Promise<GoogleClaims> {
  if (!idToken || idToken.length > MAX_ID_TOKEN_LENGTH) throw new GoogleOAuthError("malformed id_token");
  let payload: Record<string, unknown>;
  try {
    ({ payload } = await jwtVerify(idToken, opts.getKey, {
      issuer: GOOGLE_ISSUERS,
      audience: opts.clientId,
      algorithms: ["RS256"],
      clockTolerance: CLOCK_TOLERANCE_S,
      ...(opts.currentDate ? { currentDate: opts.currentDate } : {}),
    }));
  } catch (e) {
    throw new GoogleOAuthError(`invalid id_token: ${e instanceof Error ? e.message : String(e)}`);
  }
  if (typeof payload.nonce !== "string" || !safeEqual(payload.nonce, opts.nonce)) throw new GoogleOAuthError("nonce mismatch");
  const sub = typeof payload.sub === "string" ? payload.sub : "";
  const email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "";
  if (!sub || !email || email.length > 254) throw new GoogleOAuthError("id_token without sub/email");
  return { sub, email, emailVerified: payload.email_verified === true || payload.email_verified === "true" };
}
