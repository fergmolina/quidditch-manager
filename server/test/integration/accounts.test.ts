import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWK } from "jose";
import postgres from "postgres";
import { applyMigrations } from "../../scripts/migrate.js";
import { createApp } from "../../src/app.js";
import { listSessions, revokeSession, ROTATION_GRACE_MS, SESSION_TTL_MS } from "../../src/auth/sessions.js";
import { sha256Hex } from "../../src/auth/tokens.js";
import { deleteUserAccount } from "../../src/auth/users.js";
import { createPool, pgError, type PgPool } from "../../src/db.js";
import type { AppDeps } from "../../src/types.js";
import { captureMailer, SAME_ORIGIN, testDeps } from "../helpers.js";

const ADMIN_URL = process.env.TEST_DATABASE_URL;
const DB_NAME = `qm_it_${process.pid}_${Date.now().toString(36)}`;
const FORM = { "Content-Type": "application/x-www-form-urlencoded" };
const form = (o: Record<string, string>) => new URLSearchParams(o).toString();
const TERMS = "2026-11-01";

function dbUrl(name: string): string {
  const u = new URL(ADMIN_URL!);
  u.pathname = `/${name}`;
  return u.toString();
}

describe("accounts against a real Postgres", { skip: !ADMIN_URL && "TEST_DATABASE_URL is not set" }, () => {
  let pool: PgPool;
  let sql: PgPool["sql"];

  before(async () => {
    const admin = postgres(ADMIN_URL!, { max: 1, onnotice: () => undefined });
    await admin.unsafe(`create database ${DB_NAME}`);
    await admin.end();
    for (let i = 0; i < 3; i++) await applyMigrations(dbUrl(DB_NAME));
    pool = createPool(dbUrl(DB_NAME), 4);
    sql = pool.sql;
  });

  after(async () => {
    await pool?.close();
    const admin = postgres(ADMIN_URL!, { max: 1, onnotice: () => undefined });
    await admin.unsafe(`drop database if exists ${DB_NAME} with (force)`);
    await admin.end();
  });

  function deps(over: Partial<Omit<AppDeps, "config">> & { config?: NonNullable<Parameters<typeof testDeps>[0]>["config"] } = {}): AppDeps & { mailer: ReturnType<typeof captureMailer> } {
    const mailer = captureMailer();
    return { ...testDeps({ db: pool.db, mailer, ...over }), mailer } as AppDeps & { mailer: ReturnType<typeof captureMailer> };
  }

  function browser() {
    const jar = new Map<string, string>();
    return {
      jar,
      cookie: () => [...jar].map(([k, v]) => `${k}=${v}`).join("; "),
      take(res: Response) {
        for (const c of res.headers.getSetCookie()) {
          const [pair] = c.split(";");
          const i = pair!.indexOf("=");
          const k = pair!.slice(0, i);
          const v = pair!.slice(i + 1);
          if (!v || /Max-Age=0/i.test(c)) jar.delete(k);
          else jar.set(k, v);
        }
        return res;
      },
    };
  }

  async function magicLogin(app: ReturnType<typeof createApp>, mailer: ReturnType<typeof captureMailer>, email: string, b = browser(), ip = "203.0.113.7") {
    const r1 = await app.request("/auth/magic", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, "CF-Connecting-IP": ip, Cookie: b.cookie() }, body: form({ email, next: "/play/", lang: "fr" }) });
    assert.equal(r1.status, 200, await r1.clone().text());
    const link = /http:\/\/localhost:8080(\/auth\/magic\/verify\?token=[A-Za-z0-9_-]{43})/.exec(mailer.sent.at(-1)!.text)![1]!;
    const token = new URL(link, "http://x").searchParams.get("token")!;
    const landing = await app.request(link);
    assert.equal(landing.status, 200);
    const r2 = b.take(await app.request("/auth/magic/verify", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, Cookie: b.cookie() }, body: form({ token }) }));
    assert.equal(r2.status, 303);
    return { b, location: r2.headers.get("location"), token };
  }

  test("migrations: tables, prune function, least-privilege role", async () => {
    const tables = await sql`select table_name from information_schema.tables where table_schema = 'public' order by 1`;
    assert.deepEqual(tables.map((r) => r.table_name), ["auth_rate_events", "career_seasons", "careers", "feedback", "login_tokens", "sessions", "users"]);
    const [role] = await sql`select rolsuper, rolcreaterole, rolbypassrls from pg_roles where rolname = 'qm_api'`;
    assert.deepEqual({ ...role }, { rolsuper: false, rolcreaterole: false, rolbypassrls: false });
    const [priv] = await sql`select has_function_privilege('qm_api', 'public.prune_auth()', 'execute') as prune,
                                    has_table_privilege('qm_api', 'public.users', 'select,insert,update,delete') as users,
                                    has_schema_privilege('qm_api', 'public', 'create') as ddl`;
    assert.deepEqual({ ...priv }, { prune: false, users: true, ddl: false });
  });

  test("CHECK constraints reject malformed rows", async () => {
    const bad: Array<[string, string]> = [
      ["upper-case email", `insert into users (email) values ('A@example.com')`],
      ["username starting with a digit", `insert into users (email, username) values ('c1@example.com', '1abc')`],
      ["username too short", `insert into users (email, username) values ('c2@example.com', 'ab')`],
      ["username non-ASCII", `insert into users (email, username) values ('c3@example.com', 'аdmin')`],
      ["country alpha-3", `insert into users (email, country_code) values ('c4@example.com', 'ARG')`],
      ["region without country", `insert into users (email, region_code) values ('c5@example.com', '07')`],
      ["partial city", `insert into users (email, country_code, city_geonameid) values ('c6@example.com', 'AR', 1)`],
      ["latitude out of range", `insert into users (email, country_code, city_geonameid, city_name, city_lat, city_lon) values ('c7@example.com', 'AR', 1, 'X', 91, 0)`],
      ["terms version without time", `insert into users (email, terms_version) values ('c8@example.com', 'v1')`],
      ["first name too long", `insert into users (email, first_name) values ('c9@example.com', '${"x".repeat(51)}')`],
      ["bad lang on login token", `insert into login_tokens (email, token_hash, lang, expires_at) values ('x@example.com', 'h1', 'xx', now())`],
    ];
    for (const [name, stmt] of bad) {
      await assert.rejects(sql.unsafe(stmt), (e: unknown) => pgError(e).code === "23514", name);
    }
    const [u] = await sql`insert into users (email, country_code, region_code, city_geonameid, city_name, city_lat, city_lon)
                          values ('ok-city@example.com', 'AR', '07', 3435910, 'Buenos Aires', -34.61315, -58.37723) returning id`;
    await assert.rejects(
      sql`insert into sessions (id, user_id, expires_at, absolute_expires_at) values (${"a".repeat(64)}, ${u!.id}, now() + interval '2 days', now() + interval '1 day')`,
      (e: unknown) => pgError(e).code === "23514",
      "sliding expiry past the absolute cap",
    );
  });

  test("usernames are unique regardless of case, also under concurrency", async () => {
    await sql`insert into users (email, username) values ('u1@example.com', 'HarryFan')`;
    await assert.rejects(sql`insert into users (email, username) values ('u2@example.com', 'harryfan')`, (e: unknown) => {
      const p = pgError(e);
      return p.code === "23505" && p.constraint === "users_username_key";
    });
    const ids = await sql`insert into users (email) values ('r1@example.com'), ('r2@example.com') returning id`;
    const results = await Promise.allSettled(ids.map((r) => sql`update users set username = 'RaceName' where id = ${r.id}`));
    assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
    assert.equal(results.filter((r) => r.status === "rejected").length, 1);
  });

  test("full magic-link flow: login → incomplete gate → profile → gate 200 → /api/me → logout", async () => {
    const d = deps();
    const app = createApp(d);
    const { b, location } = await magicLogin(app, d.mailer, "Flow@Example.com");
    assert.equal(location, "/register?next=%2Fplay%2F");
    assert.match(d.mailer.sent.at(-1)!.subject, /Quidditch Manager|web\.mail\.magic_subject/);
    const [user] = await sql`select id, email, email_verified, last_login_at from users where email = 'flow@example.com'`;
    assert.ok(user && user.email_verified && user.last_login_at);
    const sessionCookie = b.jar.get("qm_session")!;
    assert.match(sessionCookie, /^[A-Za-z0-9_-]{43}$/);
    const [srow] = await sql`select id, user_agent_family, absolute_expires_at - created_at as abs from sessions where user_id = ${user.id}`;
    assert.equal(srow!.id, sha256Hex(sessionCookie));

    const me1 = await app.request("/api/me", { headers: { Cookie: b.cookie() } });
    assert.deepEqual(await me1.json(), { logged_in: true, username: null, country: null, locale: "en", profile_complete: false, pending: false });
    const g1 = await app.request("/api/gate", { headers: { Cookie: b.cookie(), "X-Forwarded-Uri": "/play/" } });
    assert.equal(g1.status, 302);
    assert.equal(g1.headers.get("location"), "/register?next=%2Fplay%2F");

    await sql`update users set username = 'FlowUser', country_code = 'FR', terms_version = ${TERMS}, terms_accepted_at = now() where id = ${user.id}`;
    const g2 = await app.request("/api/gate", { headers: { Cookie: b.cookie(), "X-Forwarded-Uri": "/play/" } });
    assert.equal(g2.status, 200);
    const me2 = await app.request("/api/me", { headers: { Cookie: `${b.cookie()}; qm_lang=fr` } });
    assert.deepEqual(await me2.json(), { logged_in: true, username: "FlowUser", country: "FR", locale: "fr", profile_complete: true, pending: false });

    await sql`update users set must_rename = true where id = ${user.id}`;
    assert.equal((await app.request("/api/gate", { headers: { Cookie: b.cookie() } })).headers.get("location"), "/register?next=%2Fplay%2F");
    await sql`update users set must_rename = false where id = ${user.id}`;

    b.take(await app.request("/auth/logout", { method: "POST", headers: { ...SAME_ORIGIN, Cookie: b.cookie() } }));
    assert.equal(b.jar.has("qm_session"), false);
    const me3 = await app.request("/api/me", { headers: { Cookie: `qm_session=${sessionCookie}` } });
    assert.equal(me3.status, 401, "the server-side session is gone, not just the cookie");
  });

  test("a magic link works once; GETs never consume it; the email goes out in the requesting page's language", async () => {
    const d = deps();
    const app = createApp(d);
    const { token } = await magicLogin(app, d.mailer, "once@example.com");
    const replay = await app.request("/auth/magic/verify", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN }, body: form({ token }) });
    assert.equal(replay.headers.get("location"), "/login?error=link");
    const [row] = await sql`select lang, ip_hash, consumed_at from login_tokens where token_hash = ${sha256Hex(token)}`;
    assert.equal(row!.lang, "fr");
    assert.match(row!.ip_hash, /^[0-9a-f]{32}$/);
    assert.ok(row!.consumed_at);
  });

  test("login deletes the browser's previous session (fixation hygiene)", async () => {
    const d = deps();
    const app = createApp(d);
    const first = await magicLogin(app, d.mailer, "fix@example.com");
    const old = first.b.jar.get("qm_session")!;
    await magicLogin(app, d.mailer, "fix@example.com", first.b, "203.0.113.8");
    assert.notEqual(first.b.jar.get("qm_session"), old);
    const rows = await sql`select 1 from sessions where id = ${sha256Hex(old)}`;
    assert.equal(rows.length, 0);
  });

  test("magic-link limits in the database: 3 per address per 15 min; failed sends do not count; global cap", async () => {
    const d = deps();
    const app = createApp(d);
    const post = (email: string, ip: string) =>
      app.request("/auth/magic", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, "CF-Connecting-IP": ip }, body: form({ email }) });
    d.mailer.fail = true;
    for (let i = 0; i < 5; i++) assert.equal((await post("limit@example.com", `198.51.100.${i}`)).status, 502);
    assert.equal((await sql`select count(*)::int as n from login_tokens where email = 'limit@example.com'`)[0]!.n, 0);
    d.mailer.fail = false;
    for (let i = 0; i < 3; i++) assert.equal((await post("limit@example.com", `198.51.100.${10 + i}`)).status, 200);
    const fourth = await post("limit@example.com", "198.51.100.20");
    assert.equal(fourth.status, 429);
    assert.match(await fourth.text(), /web\.login\.error\.rate_limited|Too many sign-in links/);

    for (let i = 0; i < 10; i++) assert.equal((await post(`v6-${i}@example.com`, `2001:db8:aa:bb::${i + 1}`)).status, 200);
    assert.equal((await post("v6-x@example.com", "2001:db8:aa:bb:ffff::1")).status, 429);
    assert.equal((await post("v6-y@example.com", "2001:db8:aa:bc::1")).status, 200, "another /64 is another bucket");

    const total = (await sql`select count(*)::int as n from login_tokens where created_at > now() - interval '1 day'`)[0]!.n as number;
    const capped = createApp(deps({ config: { mail: { enabled: true, resendApiKey: null, from: "x", dailyCap: total } } }));
    const r = await capped.request("/auth/magic", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, "CF-Connecting-IP": "192.0.2.50" }, body: form({ email: "cap@example.com" }) });
    assert.equal(r.status, 429);
    assert.match(await r.text(), /web\.login\.error\.mail_cap|too many emails today/);
  });

  test("rotation on renewal: new cookie, old token valid only for the grace period, absolute cap never moves", async () => {
    let clock = Date.now();
    const d = deps({ now: () => clock });
    const app = createApp(d);
    const { b } = await magicLogin(app, d.mailer, "rotate@example.com");
    const old = b.jar.get("qm_session")!;
    const [before] = await sql`select public_id, created_at, absolute_expires_at from sessions where id = ${sha256Hex(old)}`;
    clock += SESSION_TTL_MS - 10 * 86_400_000;
    const me = b.take(await app.request("/api/me", { headers: { Cookie: b.cookie() } }));
    assert.equal(me.status, 200);
    const fresh = b.jar.get("qm_session")!;
    assert.notEqual(fresh, old);
    const [afterRow] = await sql`select public_id, created_at, absolute_expires_at, expires_at, prev_id from sessions where id = ${sha256Hex(fresh)}`;
    assert.equal(afterRow!.public_id, before!.public_id, "same session in the inventory");
    assert.equal(+afterRow!.created_at, +before!.created_at);
    assert.equal(+afterRow!.absolute_expires_at, +before!.absolute_expires_at);
    assert.equal(+afterRow!.expires_at, clock + SESSION_TTL_MS);
    assert.equal(afterRow!.prev_id, sha256Hex(old));
    const parallel = await app.request("/api/me", { headers: { Cookie: `qm_session=${old}` } });
    assert.equal(parallel.status, 200);
    assert.deepEqual(parallel.headers.getSetCookie().filter((c) => c.startsWith("qm_session=")), []);
    clock += ROTATION_GRACE_MS + 1000;
    assert.equal((await app.request("/api/me", { headers: { Cookie: `qm_session=${old}` } })).status, 401, "old token dead after the grace period");
    assert.equal((await app.request("/api/me", { headers: { Cookie: `qm_session=${fresh}` } })).status, 200);
    clock = +before!.absolute_expires_at + 1000;
    assert.equal((await app.request("/api/me", { headers: { Cookie: `qm_session=${fresh}` } })).status, 401);
  });

  test("session inventory: list, revoke one, logout everywhere", async () => {
    const d = deps();
    const app = createApp(d);
    await magicLogin(app, d.mailer, "multi@example.com");
    await magicLogin(app, d.mailer, "multi@example.com", undefined, "203.0.113.9");
    const [u] = await sql`select id from users where email = 'multi@example.com'`;
    const list = await listSessions(pool.db, u!.id, null);
    assert.equal(list.length, 2);
    assert.ok(await revokeSession(pool.db, u!.id, list[0]!.publicId));
    assert.equal(await revokeSession(pool.db, "00000000-0000-4000-8000-000000000000", list[1]!.publicId), false, "only your own sessions");
    assert.equal((await listSessions(pool.db, u!.id, null)).length, 1);
    const c = await magicLogin(app, d.mailer, "multi@example.com", undefined, "203.0.113.10");
    const r = await app.request("/auth/logout-all", { method: "POST", headers: { ...SAME_ORIGIN, Cookie: c.b.cookie() } });
    assert.equal(r.status, 303);
    assert.equal((await listSessions(pool.db, u!.id, null)).length, 0);
  });

  test("Google: verified id_token creates or links by email; unverified email refused; nonce bound to the cookie", async () => {
    const { publicKey, privateKey } = await generateKeyPair("RS256");
    const jwk = { ...(await exportJWK(publicKey)), kid: "it", alg: "RS256" } as JWK;
    const clientId = "it-client.apps.googleusercontent.com";
    let claims: Record<string, unknown> = {};
    const fetchImpl = (async (_u: unknown, init?: RequestInit) => {
      const body = new URLSearchParams(String(init?.body));
      assert.ok(body.get("code_verifier"));
      const tok = await new SignJWT({ email_verified: true, ...claims })
        .setProtectedHeader({ alg: "RS256", kid: "it" })
        .setIssuer("https://accounts.google.com")
        .setAudience(clientId)
        .setSubject(String(claims.sub ?? "sub-x"))
        .setIssuedAt()
        .setExpirationTime("10m")
        .sign(privateKey);
      return new Response(JSON.stringify({ id_token: tok }), { status: 200 });
    }) as typeof fetch;
    const d = deps({ fetch: fetchImpl, googleKeys: createLocalJWKSet({ keys: [jwk] }), config: { google: { clientId, clientSecret: "s", redirectUri: "http://localhost:8080/auth/google/callback" } } });
    const app = createApp(d);

    async function googleLogin(c: Record<string, unknown>, nonceOverride?: string) {
      const b = browser();
      const start = b.take(await app.request("/auth/google?next=/account"));
      const loc = new URL(start.headers.get("location")!);
      claims = { ...c, nonce: nonceOverride ?? loc.searchParams.get("nonce") };
      const cb = b.take(await app.request(`/auth/google/callback?code=abc&state=${loc.searchParams.get("state")}`, { headers: { Cookie: b.cookie() } }));
      return { b, status: cb.status, location: cb.headers.get("location") };
    }

    await sql`insert into users (email, username, country_code, terms_version, terms_accepted_at) values ('linked@example.com', 'LinkedOne', 'DE', ${TERMS}, now())`;
    const r1 = await googleLogin({ sub: "g-linked", email: "Linked@Example.com" });
    assert.equal(r1.status, 303);
    assert.equal(r1.location, "/account");
    assert.ok(r1.b.jar.get("qm_session"));
    assert.equal(r1.b.jar.has("qm_oauth"), false, "state cookie cleared");
    const [linked] = await sql`select google_sub from users where email = 'linked@example.com'`;
    assert.equal(linked!.google_sub, "g-linked");
    const r2 = await googleLogin({ sub: "g-linked", email: "linked@example.com" });
    assert.equal(r2.location, "/account");
    const r3 = await googleLogin({ sub: "g-new", email: "newgoogle@example.com" });
    assert.equal(r3.location, "/register?next=%2Faccount");
    const r4 = await googleLogin({ sub: "g-unv", email: "unv@example.com", email_verified: false });
    assert.equal(r4.location, "/login?error=google_unverified&next=%2Faccount");
    assert.equal((await sql`select 1 from users where email = 'unv@example.com'`).length, 0);
    const r5 = await googleLogin({ sub: "g-nonce", email: "nonce@example.com" }, "replayed-nonce");
    assert.equal(r5.location, "/login?error=google_failed&next=%2Faccount");
  });

  test("account deletion cascades and removes the email's login tokens; prune_auth removes only dead rows", async () => {
    const d = deps();
    const app = createApp(d);
    await magicLogin(app, d.mailer, "gone@example.com");
    const [u] = await sql`select id from users where email = 'gone@example.com'`;
    assert.equal(await deleteUserAccount(pool.db, u!.id), true);
    assert.equal((await sql`select 1 from sessions where user_id = ${u!.id}`).length, 0);
    assert.equal((await sql`select 1 from login_tokens where email = 'gone@example.com'`).length, 0);
    assert.equal(await deleteUserAccount(pool.db, u!.id), false);

    const [p] = await sql`insert into users (email) values ('prune@example.com') returning id`;
    await sql`insert into sessions (id, user_id, created_at, expires_at, absolute_expires_at) values
      (${"1".repeat(64)}, ${p!.id}, now() - interval '40 days', now() - interval '1 day', now() + interval '100 days'),
      (${"2".repeat(64)}, ${p!.id}, now() - interval '181 days', now() - interval '1 second', now() - interval '1 second'),
      (${"3".repeat(64)}, ${p!.id}, now(), now() + interval '30 days', now() + interval '180 days')`;
    await sql`insert into login_tokens (email, token_hash, expires_at, created_at) values
      ('prune@example.com', 'old', now() - interval '2 days', now() - interval '2 days'),
      ('prune@example.com', 'recent', now() - interval '1 hour', now() - interval '2 hours')`;
    await sql`insert into auth_rate_events (bucket, subject, created_at) values ('t', 's', now() - interval '2 days'), ('t', 's', now())`;
    const result = await sql`select * from public.prune_auth()`;
    const by = Object.fromEntries(result.map((r) => [r.what, Number(r.deleted)]));
    assert.ok(by.sessions! >= 2);
    assert.ok(by.login_tokens! >= 1);
    assert.ok(by.auth_rate_events! >= 1);
    assert.deepEqual((await sql`select id from sessions where user_id = ${p!.id}`).map((r) => r.id), ["3".repeat(64)]);
    assert.deepEqual((await sql`select token_hash from login_tokens where email = 'prune@example.com'`).map((r) => r.token_hash), ["recent"]);
  });

  test("healthz reaches the database", async () => {
    const app = createApp(deps());
    const r = await app.request("/healthz");
    assert.equal(r.status, 200);
  });

  test("a transaction rolls back on throw; the tx handed out cannot open another one", async () => {
    await assert.rejects(
      pool.db.transaction(async (tx) => {
        await tx.query("insert into public.auth_rate_events (bucket, subject, created_at) values ('tx_pin', 'x', now())");
        assert.equal("transaction" in tx, false, "TxDb has no transaction(): nesting is a compile error, not an inline no-op");
        throw new Error("abort");
      }),
      /abort/,
    );
    assert.equal((await sql`select count(*)::int as n from auth_rate_events where bucket = 'tx_pin'`)[0]!.n, 0);
  });
});
