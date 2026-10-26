import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp, MAX_BODY_BYTES } from "../src/app.js";
import { sha256Hex } from "../src/auth/tokens.js";
import { PAGE_CSP } from "../src/http/security.js";
import { captureMailer, fakeDb, SAME_ORIGIN, SITE, testDeps, type Statement } from "./helpers.js";

const form = (o: Record<string, string>) => new URLSearchParams(o).toString();
const FORM = { "Content-Type": "application/x-www-form-urlencoded" };
const TOKEN = "T".repeat(43);

function sessionRow(user: Record<string, unknown> = {}) {
  const now = Date.now();
  return {
    session_id: sha256Hex(TOKEN),
    session_public_id: "00000000-0000-4000-8000-000000000001",
    session_created_at: new Date(now - 86_400_000),
    session_last_seen_at: new Date(now),
    session_expires_at: new Date(now + 20 * 86_400_000),
    session_absolute_expires_at: new Date(now + 170 * 86_400_000),
    via_previous: false,
    id: "11111111-1111-4111-8111-111111111111",
    email: "secret@example.com",
    email_verified: true,
    google_sub: null,
    username: "HarryFan",
    first_name: "Harry",
    last_name: "Fan",
    country_code: "AR",
    region_code: "07",
    city_geonameid: 3435910,
    city_name: "Buenos Aires",
    city_lat: -34.61,
    city_lon: -58.38,
    terms_version: "2026-11-01",
    terms_accepted_at: new Date(now),
    username_changed_at: null,
    must_rename: false,
    is_admin: false,
    blocked_at: null,
    approved_at: new Date(now),
    approved_by: null,
    created_at: new Date(now),
    last_login_at: new Date(now),
    ...user,
  };
}

function sessionDb(user: Record<string, unknown> = {}) {
  return fakeDb((s: Statement) => {
    if (s.text.startsWith("select s.id as session_id")) return s.values[0] === sha256Hex(TOKEN) ? [sessionRow(user)] : [];
    if (s.text.startsWith("update public.sessions set last_seen_at")) return [];
    return undefined;
  });
}

test("GET /: strict CSP and security headers, no inline script or style, English by default", async () => {
  const app = createApp(testDeps());
  const res = await app.request("/");
  assert.equal(res.status, 200);
  const h = res.headers;
  assert.equal(h.get("content-security-policy"), PAGE_CSP);
  assert.match(PAGE_CSP, /script-src 'self'(;|$)/);
  assert.doesNotMatch(PAGE_CSP, /unsafe-inline|unsafe-eval/);
  assert.equal(h.get("x-frame-options"), "DENY");
  assert.equal(h.get("x-content-type-options"), "nosniff");
  assert.equal(h.get("referrer-policy"), "strict-origin-when-cross-origin");
  assert.equal(h.get("cache-control"), "private, no-store");
  assert.equal(h.get("strict-transport-security"), null, "HSTS only in production");
  assert.equal(h.get("access-control-allow-origin"), null);
  const body = await res.text();
  assert.match(body, /<html lang="en">/);
  assert.doesNotMatch(body, /<script/i);
  assert.doesNotMatch(body, /\sstyle=/i);
  assert.match(body, /href="\/login\?next=%2Fplay%2F"/);
});

test("language: ?lang sets the qm_lang cookie; the cookie beats Accept-Language; the header beats English", async () => {
  const app = createApp(testDeps());
  const r1 = await app.request("/?lang=pt-BR");
  assert.match(await r1.text(), /<html lang="pt-BR">/);
  const c = r1.headers.getSetCookie().find((x) => x.startsWith("qm_lang="))!;
  assert.match(c, /^qm_lang=pt_BR;/);
  assert.doesNotMatch(c, /HttpOnly/);
  assert.match(await (await app.request("/", { headers: { "Accept-Language": "de-DE,de;q=0.9" } })).text(), /<html lang="de">/);
  assert.match(await (await app.request("/", { headers: { "Accept-Language": "sv-SE" } })).text(), /<html lang="en">/);
  assert.match(await (await app.request("/", { headers: { Cookie: "qm_lang=ja", "Accept-Language": "de" } })).text(), /<html lang="ja">/);
  const me = (await (await app.request("/api/me", { headers: { "Accept-Language": "ja" } })).json()) as { locale: string };
  assert.equal(me.locale, "ja", "the game reads the browser language through /api/me when no cookie is set");
});

test("production adds HSTS", async () => {
  const app = createApp(testDeps({ config: { isProd: true, siteUrl: "https://qm.example.org", siteOrigin: "https://qm.example.org" } }));
  const res = await app.request("https://qm.example.org/");
  assert.equal(res.headers.get("strict-transport-security"), "max-age=31536000; includeSubDomains");
});

test("every POST needs a same-origin Origin (tier 1), before the route runs", async () => {
  const db = fakeDb(() => undefined);
  const app = createApp(testDeps({ db }));
  const cases: Array<Record<string, string>> = [{}, { Origin: "https://evil.example" }, { Origin: "null" }, { Origin: SITE, "Sec-Fetch-Site": "cross-site" }, { Origin: SITE, "Sec-Fetch-Site": "same-site" }];
  for (const path of ["/auth/magic", "/auth/logout", "/auth/logout-all", "/auth/magic/verify", "/anything"]) {
    for (const h of cases) {
      const res = await app.request(path, { method: "POST", headers: { ...FORM, ...h }, body: form({ email: "a@example.com" }) });
      assert.equal(res.status, 403, `${path} ${JSON.stringify(h)}`);
    }
  }
  assert.equal(db.log.length, 0, "nothing touched the database");
});

test("POST /auth/magic: invalid email re-renders the form with the input escaped (400)", async () => {
  const app = createApp(testDeps());
  const res = await app.request("/auth/magic", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN }, body: form({ email: `"><script>alert(1)</script>`, next: "/play/" }) });
  assert.equal(res.status, 400);
  const body = await res.text();
  assert.doesNotMatch(body, /<script>alert/);
  assert.match(body, /&quot;&gt;&lt;script&gt;/);
  assert.match(body, /web\.login\.error\.email_invalid|valid email/);
});

test("POST /auth/magic: sends the link in the form's language; a failed send is discarded (502)", async () => {
  const statements: string[] = [];
  const db = fakeDb((s) => {
    statements.push(s.text.slice(0, 40));
    if (s.text.startsWith("with usage as")) return [{ id: "22222222-2222-4222-8222-222222222222", mail_capped: false }];
    if (s.text.startsWith("delete from public.login_tokens where id")) return [];
    return undefined;
  });
  const mailer = captureMailer();
  const app = createApp(testDeps({ db, mailer }));
  const res = await app.request("/auth/magic", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, "CF-Connecting-IP": "2001:db8::1" }, body: form({ email: " A@Example.COM ", next: "//evil", lang: "es" }) });
  assert.equal(res.status, 200);
  assert.equal(mailer.sent.length, 1);
  const mail = mailer.sent[0]!;
  assert.equal(mail.to, "a@example.com");
  assert.match(mail.text, /http:\/\/localhost:8080\/auth\/magic\/verify\?token=[A-Za-z0-9_-]{43}/);
  const insert = db.log.find((s) => s.text.startsWith("with usage as"))!;
  assert.equal(insert.values[2], "/play/", "unsafe next replaced");
  assert.equal(insert.values[3], "es");
  assert.match(String(insert.values[4]), /^[0-9a-f]{32}$/, "keyed hash, no raw IP");
  assert.ok(!JSON.stringify(insert.values).includes("2001:db8"));

  mailer.fail = true;
  const res2 = await app.request("/auth/magic", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN }, body: form({ email: "b@example.com" }) });
  assert.equal(res2.status, 502);
  assert.ok(db.log.some((s) => s.text.startsWith("delete from public.login_tokens where id = $1::uuid")), "row discarded");
});

test("GET /auth/magic/verify: bad token → login error, never a DB write; valid → click-to-confirm page, no script", async () => {
  const good = "G".repeat(43);
  const db = fakeDb((s) => (s.text.startsWith("select 1 as ok from public.login_tokens") ? (s.values[0] === sha256Hex(good) ? [{ ok: 1 }] : []) : undefined));
  const app = createApp(testDeps({ db }));
  const bad = await app.request("/auth/magic/verify?token=%22%3E%3Cx");
  assert.equal(bad.status, 303);
  assert.equal(bad.headers.get("location"), "/login?error=link");
  const res = await app.request(`/auth/magic/verify?token=${good}`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("referrer-policy"), "same-origin");
  assert.equal(res.headers.get("cache-control"), "private, no-store");
  assert.match(res.headers.get("x-robots-tag") ?? "", /noindex/);
  const body = await res.text();
  assert.doesNotMatch(body, /<script/i, "no auto-submit");
  assert.match(body, /<form method="post" action="\/auth\/magic\/verify">/);
  assert.match(body, new RegExp(`name="token" value="${good}"`));
  assert.equal(db.writes().length, 0);
});

test("POST /auth/magic/verify: tier 2 refuses Sec-Fetch-Site none (typed URL) even with our Origin", async () => {
  const db = fakeDb(() => undefined);
  const app = createApp(testDeps({ db }));
  const res = await app.request("/auth/magic/verify", { method: "POST", headers: { ...FORM, Origin: SITE, "Sec-Fetch-Site": "none" }, body: form({ token: "G".repeat(43) }) });
  assert.equal(res.status, 403);
  assert.equal(db.log.length, 0);
});

test("GET /api/me logged out: 401 JSON, private no-store, Vary: Cookie; stale cookie cleared", async () => {
  const app = createApp(testDeps({ db: sessionDb() }));
  const res = await app.request("/api/me", { headers: { Cookie: `qm_session=${"X".repeat(43)}` } });
  assert.equal(res.status, 401);
  assert.equal(res.headers.get("cache-control"), "private, no-store");
  assert.equal(res.headers.get("vary"), "Cookie");
  assert.deepEqual(await res.json(), { logged_in: false, username: null, country: null, locale: "en", profile_complete: false, pending: false });
  assert.ok(res.headers.getSetCookie().some((c) => c.startsWith("qm_session=;")));
});

test("GET /api/me logged in: username, country, locale, profile_complete; never email, names or location", async () => {
  const app = createApp(testDeps({ db: sessionDb() }));
  const res = await app.request("/api/me?lang=ru", { headers: { Cookie: `qm_session=${TOKEN}` } });
  assert.equal(res.status, 200);
  const text = await res.text();
  assert.deepEqual(JSON.parse(text), { logged_in: true, username: "HarryFan", country: "AR", locale: "ru", profile_complete: true, pending: false });
  for (const secret of ["secret@example.com", "\"Harry\"", "\"Fan\"", "Buenos", "3435910", "-34.61", "07"]) assert.ok(!text.includes(secret), secret);
});

test("ACCESS_MODE=approval: an unapproved account is pending on /api/me, sent to /pending by the gate, refused by the season report", async () => {
  const pending = createApp(testDeps({ db: sessionDb({ approved_at: null }), config: { accessMode: "approval" } }));
  const me = (await (await pending.request("/api/me", { headers: { Cookie: `qm_session=${TOKEN}` } })).json()) as Record<string, unknown>;
  assert.deepEqual(me, { logged_in: true, username: "HarryFan", country: "AR", locale: "en", profile_complete: false, pending: true });
  const gate = await pending.request("/api/gate", { headers: { Cookie: `qm_session=${TOKEN}`, "X-Forwarded-Uri": "/play/" } });
  assert.equal(gate.status, 302);
  assert.equal(gate.headers.get("location"), "/pending");
  assert.equal((await pending.request("/api/gate", { headers: { Cookie: `qm_session=${TOKEN}`, "X-Forwarded-Method": "POST" } })).status, 401);
  const report = await pending.request("/api/career/season", { method: "POST", headers: { ...SAME_ORIGIN, Cookie: `qm_session=${TOKEN}`, "Content-Type": "application/json" }, body: "{}" });
  assert.equal(report.status, 401);

  const approved = createApp(testDeps({ db: sessionDb(), config: { accessMode: "approval" } }));
  assert.equal((await approved.request("/api/gate", { headers: { Cookie: `qm_session=${TOKEN}` } })).status, 200);
  const open = createApp(testDeps({ db: sessionDb({ approved_at: null }) }));
  assert.equal((await open.request("/api/gate", { headers: { Cookie: `qm_session=${TOKEN}` } })).status, 200, "open access ignores approved_at");
  const blocked = createApp(testDeps({ db: sessionDb({ approved_at: null, blocked_at: new Date() }), config: { accessMode: "approval" } }));
  assert.equal((await blocked.request("/api/gate", { headers: { Cookie: `qm_session=${TOKEN}` } })).headers.get("location"), "/login?error=blocked");
});

test("GET /api/gate: 302 to /login without session, /register when incomplete, 200 when complete; never sets cookies", async () => {
  const anon = createApp(testDeps({ db: sessionDb() }));
  const r1 = await anon.request("/api/gate", { headers: { "X-Forwarded-Uri": "/play/?lang=es", "X-Forwarded-Method": "GET" } });
  assert.equal(r1.status, 302);
  assert.equal(r1.headers.get("location"), "/login?next=%2Fplay%2F%3Flang%3Des");
  const r1b = await anon.request("/api/gate", { headers: { "X-Forwarded-Uri": "/somewhere-else" } });
  assert.equal(r1b.headers.get("location"), "/login?next=%2Fplay%2F");
  const r1c = await anon.request("/api/gate", { headers: { "X-Forwarded-Method": "POST" } });
  assert.equal(r1c.status, 401);

  const incomplete = createApp(testDeps({ db: sessionDb({ username: null }) }));
  const r2 = await incomplete.request("/api/gate", { headers: { Cookie: `qm_session=${TOKEN}`, "X-Forwarded-Uri": "/play/" } });
  assert.equal(r2.status, 302);
  assert.equal(r2.headers.get("location"), "/register?next=%2Fplay%2F");

  const oldTerms = createApp(testDeps({ db: sessionDb({ terms_version: "2020-01-01" }) }));
  assert.equal((await oldTerms.request("/api/gate", { headers: { Cookie: `qm_session=${TOKEN}` } })).headers.get("location"), "/register?next=%2Fplay%2F");

  const blocked = createApp(testDeps({ db: sessionDb({ blocked_at: new Date() }) }));
  assert.equal((await blocked.request("/api/gate", { headers: { Cookie: `qm_session=${TOKEN}` } })).headers.get("location"), "/login?error=blocked");

  const db = sessionDb();
  const ok = createApp(testDeps({ db }));
  const r3 = await ok.request("/api/gate", { headers: { Cookie: `qm_session=${TOKEN}` } });
  assert.equal(r3.status, 200);
  assert.deepEqual(r3.headers.getSetCookie(), []);
  assert.equal(db.writes().length, 0, "the gate never renews or touches the session");
});

test("/api/gate is mounted outside the /api/* burst limiter; a null rate turns the limiter off", async () => {
  const app = createApp(testDeps({ db: sessionDb(), config: { sessionRatePerMinute: 1 } }));
  const gate = () => app.request("/api/gate", { headers: { "X-Forwarded-Uri": "/play/" } });
  for (let i = 0; i < 3; i++) assert.equal((await gate()).status, 302);
  assert.equal((await app.request("/api/me")).status, 401, "the first call spends the only slot");
  const limited = await app.request("/api/me");
  assert.equal(limited.status, 429);
  assert.ok(limited.headers.get("retry-after"));
  assert.equal((await gate()).status, 302, "Caddy's probes never see 429");
  const off = createApp(testDeps({ db: sessionDb(), config: { sessionRatePerMinute: null } }));
  for (let i = 0; i < 3; i++) assert.equal((await off.request("/api/me")).status, 401);
});

test("pages escape user data from the database (a hostile username)", async () => {
  const app = createApp(testDeps({ db: sessionDb({ username: "Bad<img src=x>" }) }));
  const body = await (await app.request("/login", { headers: { Cookie: `qm_session=${TOKEN}` } })).text();
  assert.doesNotMatch(body, /<img src=x>/);
  assert.match(body, /Bad&lt;img src=x&gt;/);
});

test("logout clears the cookie and redirects home with 303", async () => {
  const db = fakeDb((s) => (s.text.startsWith("delete from public.sessions where id = $1 or prev_id = $1") ? [] : undefined));
  const app = createApp(testDeps({ db }));
  const res = await app.request("/auth/logout", { method: "POST", headers: { ...SAME_ORIGIN, Cookie: `qm_session=${TOKEN}` } });
  assert.equal(res.status, 303);
  assert.equal(res.headers.get("location"), "/");
  assert.ok(res.headers.getSetCookie().some((c) => c.startsWith("qm_session=;") && /Max-Age=0/.test(c)));
  assert.equal(db.log[0]!.values[0], sha256Hex(TOKEN));
});

test("healthz, static files, 404 and the body limit", async () => {
  const db = fakeDb((s) => (s.text === "select 1 as ok" ? [{ ok: 1 }] : undefined));
  const app = createApp(testDeps({ db }));
  const h = await app.request("/healthz");
  assert.equal(h.status, 200);
  assert.equal(await h.text(), "ok");
  const css = await app.request("/static/site.css");
  assert.equal(css.status, 200);
  assert.equal(css.headers.get("content-type"), "text/css; charset=utf-8");
  assert.equal((await app.request("/static/../package.json")).status, 404);
  assert.equal((await app.request("/static/fonts/OFL-AlegreyaSans.txt")).status, 200);
  const nf = await app.request("/nope");
  assert.equal(nf.status, 404);
  assert.match(await nf.text(), /href="\/"/);
  assert.equal((await app.request("/api/nope")).status, 404);
  const big = await app.request("/auth/magic", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN }, body: "email=" + "a".repeat(MAX_BODY_BYTES + 10) });
  assert.equal(big.status, 413);
});
