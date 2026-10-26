import assert from "node:assert/strict";
import { test } from "node:test";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWK } from "jose";
import { createApp } from "../src/app.js";
import {
  decodeOAuthState,
  encodeOAuthState,
  exchangeGoogleCode,
  googleAuthUrl,
  GoogleOAuthError,
  newOAuthState,
  pkceChallenge,
  verifyGoogleIdToken,
} from "../src/auth/google.js";
import { fakeDb, testDeps } from "./helpers.js";

const KEY = Buffer.from("s".repeat(32));
const NOW = Date.UTC(2026, 9, 21, 12);
const CLIENT = "client-123.apps.googleusercontent.com";

test("PKCE S256 matches the RFC 7636 example", () => {
  assert.equal(pkceChallenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM");
});

test("googleAuthUrl: code flow with PKCE S256, state, nonce, openid email profile", () => {
  const u = new URL(googleAuthUrl({ clientId: CLIENT, redirectUri: "https://qm.example.org/auth/google/callback", state: "st", nonce: "no", codeVerifier: "v", language: "pt-BR" }));
  assert.equal(u.origin + u.pathname, "https://accounts.google.com/o/oauth2/v2/auth");
  const p = u.searchParams;
  assert.equal(p.get("response_type"), "code");
  assert.equal(p.get("scope"), "openid email profile");
  assert.equal(p.get("state"), "st");
  assert.equal(p.get("nonce"), "no");
  assert.equal(p.get("code_challenge"), pkceChallenge("v"));
  assert.equal(p.get("code_challenge_method"), "S256");
  assert.equal(p.get("hl"), "pt-BR");
  assert.equal(p.get("redirect_uri"), "https://qm.example.org/auth/google/callback");
});

test("OAuth state cookie: signed, bound to the echoed state, expires", () => {
  const s = newOAuthState("/play/", "es", NOW);
  const cookie = encodeOAuthState(KEY, s);
  assert.deepEqual(decodeOAuthState(KEY, cookie, s.state, NOW + 1000), s);
  assert.equal(decodeOAuthState(KEY, cookie, "other-state", NOW), null, "state mismatch (login CSRF)");
  assert.equal(decodeOAuthState(KEY, cookie, null, NOW), null);
  assert.equal(decodeOAuthState(KEY, cookie, s.state, NOW + 601_000), null, "expired after 10 minutes");
  assert.equal(decodeOAuthState(Buffer.from("t".repeat(32)), cookie, s.state, NOW), null, "planted cookie with another key");
  const unsigned = Buffer.from(JSON.stringify(s)).toString("base64url");
  assert.equal(decodeOAuthState(KEY, unsigned, s.state, NOW), null, "unsigned JSON state is refused");
});

async function keys() {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const jwk = { ...(await exportJWK(publicKey)), kid: "k1", alg: "RS256", use: "sig" } as JWK;
  return { privateKey, getKey: createLocalJWKSet({ keys: [jwk] }) };
}

type PrivateKey = Awaited<ReturnType<typeof generateKeyPair>>["privateKey"];

async function idToken(privateKey: PrivateKey, claims: Record<string, unknown>, opts: { iss?: string; aud?: string; exp?: number; alg?: string } = {}) {
  return new SignJWT({ email: "Player@Example.com", email_verified: true, nonce: "n-1", ...claims })
    .setProtectedHeader({ alg: opts.alg ?? "RS256", kid: "k1" })
    .setIssuer(opts.iss ?? "https://accounts.google.com")
    .setAudience(opts.aud ?? CLIENT)
    .setSubject("google-sub-1")
    .setIssuedAt(Math.floor(NOW / 1000))
    .setExpirationTime(opts.exp ?? Math.floor(NOW / 1000) + 3600)
    .sign(privateKey);
}

test("verifyGoogleIdToken: signature, issuer, audience, expiry and nonce are all enforced", async () => {
  const { privateKey, getKey } = await keys();
  const at = new Date(NOW);
  const ok = await verifyGoogleIdToken(await idToken(privateKey, {}), { clientId: CLIENT, nonce: "n-1", getKey, currentDate: at });
  assert.deepEqual(ok, { sub: "google-sub-1", email: "player@example.com", emailVerified: true });
  const unverified = await verifyGoogleIdToken(await idToken(privateKey, { email_verified: false }), { clientId: CLIENT, nonce: "n-1", getKey, currentDate: at });
  assert.equal(unverified.emailVerified, false);
  const legacyIss = await verifyGoogleIdToken(await idToken(privateKey, {}, { iss: "accounts.google.com" }), { clientId: CLIENT, nonce: "n-1", getKey, currentDate: at });
  assert.equal(legacyIss.sub, "google-sub-1");

  const bad: Array<[string, Promise<string>, string?]> = [
    ["wrong nonce", idToken(privateKey, { nonce: "other" })],
    ["no nonce", idToken(privateKey, { nonce: undefined })],
    ["wrong audience", idToken(privateKey, {}, { aud: "someone-else" })],
    ["wrong issuer", idToken(privateKey, {}, { iss: "https://evil.example" })],
    ["expired", idToken(privateKey, {}, { exp: Math.floor(NOW / 1000) - 3600 })],
    ["no email", idToken(privateKey, { email: undefined })],
  ];
  for (const [name, tok] of bad) {
    await assert.rejects(verifyGoogleIdToken(await tok, { clientId: CLIENT, nonce: "n-1", getKey, currentDate: at }), GoogleOAuthError, name);
  }
  const other = await keys();
  await assert.rejects(verifyGoogleIdToken(await idToken(other.privateKey, {}), { clientId: CLIENT, nonce: "n-1", getKey, currentDate: at }), GoogleOAuthError, "signed by another key");
  const hs = await new SignJWT({ email: "a@example.com", nonce: "n-1" }).setProtectedHeader({ alg: "HS256" }).setIssuer("https://accounts.google.com").setAudience(CLIENT).setSubject("s").setExpirationTime(Math.floor(NOW / 1000) + 60).sign(new Uint8Array(32));
  await assert.rejects(verifyGoogleIdToken(hs, { clientId: CLIENT, nonce: "n-1", getKey, currentDate: at }), GoogleOAuthError, "HS256 refused");
  const [h, p] = (await idToken(privateKey, {})).split(".");
  await assert.rejects(verifyGoogleIdToken(`${h}.${p}.`, { clientId: CLIENT, nonce: "n-1", getKey, currentDate: at }), GoogleOAuthError, "unsigned token refused");
});

test("exchangeGoogleCode: posts code + verifier; errors become GoogleOAuthError", async () => {
  let seen: URLSearchParams | null = null;
  const fetchOk = (async (_url: unknown, init?: RequestInit) => {
    seen = new URLSearchParams(String(init?.body));
    return new Response(JSON.stringify({ id_token: "tok" }), { status: 200 });
  }) as typeof fetch;
  const r = await exchangeGoogleCode({ code: "c", codeVerifier: "v", clientId: "id", clientSecret: "sec", redirectUri: "https://x/cb", fetchImpl: fetchOk });
  assert.equal(r.idToken, "tok");
  assert.equal(seen!.get("code_verifier"), "v");
  assert.equal(seen!.get("grant_type"), "authorization_code");
  const fetchBad = (async () => new Response(JSON.stringify({ error: "invalid_grant" }), { status: 400 })) as typeof fetch;
  await assert.rejects(exchangeGoogleCode({ code: "c", codeVerifier: "v", clientId: "id", clientSecret: "sec", redirectUri: "https://x/cb", fetchImpl: fetchBad }), GoogleOAuthError);
});

const google = { clientId: CLIENT, clientSecret: "secret", redirectUri: "http://localhost:8080/auth/google/callback" };

test("GET /auth/google: 302 to Google, signed HttpOnly state cookie on Path=/ (dev name)", async () => {
  const app = createApp(testDeps({ config: { google } }));
  const res = await app.request("/auth/google?next=/account&lang=ja");
  assert.equal(res.status, 302);
  const loc = new URL(res.headers.get("location")!);
  assert.equal(loc.hostname, "accounts.google.com");
  assert.equal(loc.searchParams.get("hl"), "ja");
  const cookies = res.headers.getSetCookie();
  const oauth = cookies.find((c) => c.startsWith("qm_oauth="))!;
  assert.ok(oauth, cookies.join(" | "));
  assert.match(oauth, /HttpOnly/);
  assert.match(oauth, /Path=\//);
  assert.match(oauth, /SameSite=Lax/);
  assert.match(oauth, /Max-Age=600/);
  const value = decodeURIComponent(oauth.split(";")[0]!.slice("qm_oauth=".length));
  const saved = decodeOAuthState(testDeps().config.authSecret, value, loc.searchParams.get("state"));
  assert.ok(saved);
  assert.equal(saved.next, "/account");
  assert.equal(saved.nonce, loc.searchParams.get("nonce"));
});

test("GET /auth/google in production: __Host-qm_oauth, Secure", async () => {
  const app = createApp(testDeps({ config: { google: { ...google, redirectUri: "https://qm.example.org/auth/google/callback" }, isProd: true, siteUrl: "https://qm.example.org", siteOrigin: "https://qm.example.org" } }));
  const res = await app.request("https://qm.example.org/auth/google");
  const oauth = res.headers.getSetCookie().find((c) => c.startsWith("__Host-qm_oauth="));
  assert.ok(oauth);
  assert.match(oauth, /Secure/);
  assert.match(oauth, /Path=\//);
  assert.doesNotMatch(oauth, /Domain=/);
});

test("callback without a valid state cookie fails before any network or database call", async () => {
  let fetched = false;
  const db = fakeDb(() => undefined);
  const app = createApp(testDeps({ db, config: { google }, fetch: (async () => ((fetched = true), new Response("{}"))) as typeof fetch }));
  const res = await app.request("/auth/google/callback?code=c&state=s", { headers: { Cookie: "qm_oauth=forged.value" } });
  assert.equal(res.status, 303);
  assert.equal(res.headers.get("location"), "/login?error=google_failed&next=%2Fplay%2F");
  assert.equal(fetched, false);
  assert.equal(db.log.length, 0);
});

test("Google disabled: /auth/google sends back to the login page", async () => {
  const app = createApp(testDeps());
  const res = await app.request("/auth/google");
  assert.equal(res.status, 303);
  assert.match(res.headers.get("location")!, /^\/login\?error=google_failed/);
});
