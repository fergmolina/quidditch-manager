import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";
import postgres from "postgres";
import { applyMigrations } from "../../scripts/migrate.js";
import { createApp } from "../../src/app.js";
import { createPool, type PgPool } from "../../src/db.js";
import type { AppDeps } from "../../src/types.js";
import { captureMailer, SAME_ORIGIN, testDeps } from "../helpers.js";

const ADMIN_URL = process.env.TEST_DATABASE_URL;
const DB_NAME = `qm_itp_${process.pid}_${Date.now().toString(36)}`;
const FORM = { "Content-Type": "application/x-www-form-urlencoded" };
const form = (o: Record<string, string>) => new URLSearchParams(o).toString();
const DAY = 86_400_000;

function dbUrl(name: string): string {
  const u = new URL(ADMIN_URL!);
  u.pathname = `/${name}`;
  return u.toString();
}

describe("registration and account against a real Postgres", { skip: !ADMIN_URL && "TEST_DATABASE_URL is not set" }, () => {
  let pool: PgPool;
  let sql: PgPool["sql"];

  before(async () => {
    const admin = postgres(ADMIN_URL!, { max: 1, onnotice: () => undefined });
    await admin.unsafe(`create database ${DB_NAME}`);
    await admin.end();
    await applyMigrations(dbUrl(DB_NAME));
    pool = createPool(dbUrl(DB_NAME), 6);
    sql = pool.sql;
  });

  after(async () => {
    await pool?.close();
    const admin = postgres(ADMIN_URL!, { max: 1, onnotice: () => undefined });
    await admin.unsafe(`drop database if exists ${DB_NAME} with (force)`);
    await admin.end();
  });

  function setup(over: Partial<Omit<AppDeps, "config">> & { config?: NonNullable<Parameters<typeof testDeps>[0]>["config"] } = {}) {
    const mailer = captureMailer();
    const deps = testDeps({ db: pool.db, mailer, ...over });
    return { app: createApp(deps), mailer, deps };
  }

  async function login(app: ReturnType<typeof createApp>, mailer: ReturnType<typeof captureMailer>, email: string, ip = "203.0.113.20"): Promise<{ cookie: string; location: string | null }> {
    const r1 = await app.request("/auth/magic", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, "CF-Connecting-IP": ip }, body: form({ email, next: "/play/" }) });
    assert.equal(r1.status, 200, await r1.clone().text());
    const token = /token=([A-Za-z0-9_-]{43})/.exec(mailer.sent.at(-1)!.text)![1]!;
    const r2 = await app.request("/auth/magic/verify", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, "CF-Connecting-IP": ip }, body: form({ token }) });
    assert.equal(r2.status, 303);
    const set = r2.headers.getSetCookie().find((c) => c.startsWith("qm_session="))!;
    return { cookie: set.split(";")[0]!, location: r2.headers.get("location") };
  }

  const post = (app: ReturnType<typeof createApp>, cookie: string, path: string, body: Record<string, string>) =>
    app.request(path, { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, Cookie: cookie }, body: form(body) });

  test("first visit: login → /register → profile with region and city → gate 200 → /api/me", async () => {
    const { app, mailer } = setup();
    const { cookie, location } = await login(app, mailer, "first@example.com");
    assert.equal(location, "/register?next=%2Fplay%2F");
    const page = await app.request(location!, { headers: { Cookie: cookie, "CF-IPCountry": "AR" } });
    assert.equal(page.status, 200);
    assert.match(await page.text(), /<option value="AR" selected>/);

    const bad = await post(app, cookie, "/register", { next: "/play/", username: "FirstOne", country: "AR" });
    assert.equal(bad.status, 400, "terms not accepted");
    const ok = await post(app, cookie, "/register", { next: "/play/", username: "FirstOne", first_name: "Ana", last_name: "", country: "AR", region: "", city: "3435910", terms: "yes" });
    assert.equal(ok.status, 303, await ok.clone().text());
    assert.equal(ok.headers.get("location"), "/play/");
    const [u] = await sql`select username, first_name, last_name, country_code, region_code, city_geonameid, city_name, city_lat, city_lon, terms_version, terms_accepted_at, username_changed_at from users where email = 'first@example.com'`;
    assert.deepEqual(
      { ...u, terms_accepted_at: !!u!.terms_accepted_at },
      { username: "FirstOne", first_name: "Ana", last_name: null, country_code: "AR", region_code: "07", city_geonameid: 3435910, city_name: "Buenos Aires", city_lat: -34.6131, city_lon: -58.3772, terms_version: "2026-11-01", terms_accepted_at: true, username_changed_at: null },
    );
    assert.equal((await app.request("/api/gate", { headers: { Cookie: cookie, "X-Forwarded-Uri": "/play/" } })).status, 200);
    assert.deepEqual(await (await app.request("/api/me", { headers: { Cookie: cookie } })).json(), { logged_in: true, username: "FirstOne", country: "AR", locale: "en", profile_complete: true, pending: false });
    const again = await post(app, cookie, "/register", { next: "/play/", username: "Sneaky", country: "AR", terms: "yes" });
    assert.equal(again.status, 303);
    assert.equal((await sql`select username from users where email = 'first@example.com'`)[0]!.username, "FirstOne");
  });

  test("two simultaneous sign-ups for the same name (different case): exactly one wins", async () => {
    const { app, mailer } = setup();
    const a = await login(app, mailer, "race-a@example.com", "203.0.113.30");
    const b = await login(app, mailer, "race-b@example.com", "203.0.113.31");
    const [ra, rb] = await Promise.all([
      post(app, a.cookie, "/register", { username: "RaceWinner", country: "FR", terms: "yes" }),
      post(app, b.cookie, "/register", { username: "racewinner", country: "DE", terms: "yes" }),
    ]);
    const statuses = [ra.status, rb.status].sort();
    assert.deepEqual(statuses, [303, 409]);
    const loser = ra.status === 409 ? ra : rb;
    assert.match(await loser.text(), /data-code="username_taken"/);
    assert.equal((await sql`select count(*)::int as n from users where lower(username) = 'racewinner'`)[0]!.n, 1);
  });

  test("username change: 30-day cooldown in SQL, old name free at once, case-insensitive uniqueness", async () => {
    const { app, mailer } = setup();
    const owner = await login(app, mailer, "renamer@example.com", "203.0.113.40");
    assert.equal((await post(app, owner.cookie, "/register", { username: "OldName", country: "ES", terms: "yes" })).status, 303);
    const other = await login(app, mailer, "other@example.com", "203.0.113.41");
    assert.equal((await post(app, other.cookie, "/register", { username: "Other", country: "IT", terms: "yes" })).status, 303);

    const taken = await post(app, owner.cookie, "/account/username", { username: "OTHER" });
    assert.equal(taken.status, 409);
    const r1 = await post(app, owner.cookie, "/account/username", { username: "NewName" });
    assert.equal(r1.headers.get("location"), "/account?saved=username#username-section");
    const third = await login(app, mailer, "third@example.com", "203.0.113.42");
    assert.equal((await post(app, third.cookie, "/register", { username: "oldname", country: "PT", terms: "yes" })).status, 303);

    const r2 = await post(app, owner.cookie, "/account/username", { username: "Newer" });
    assert.equal(r2.status, 303);
    assert.equal((await sql`select username from users where email = 'renamer@example.com'`)[0]!.username, "NewName", "cooldown holds");
    const acc = await (await app.request("/account", { headers: { Cookie: owner.cookie } })).text();
    assert.doesNotMatch(acc, /action="\/account\/username"/);

    await sql`update users set username_changed_at = username_changed_at - interval '31 days' where email = 'renamer@example.com'`;
    const r3 = await post(app, owner.cookie, "/account/username", { username: "Newer" });
    assert.equal(r3.headers.get("location"), "/account?saved=username#username-section");
    assert.equal((await sql`select username from users where email = 'renamer@example.com'`)[0]!.username, "Newer");
  });

  test("moderation rename and a terms bump both route through /register and clear correctly", async () => {
    const { app, mailer } = setup();
    const u = await login(app, mailer, "mod@example.com", "203.0.113.50");
    assert.equal((await post(app, u.cookie, "/register", { username: "BadName", country: "NL", terms: "yes" })).status, 303);
    await sql`update users set must_rename = true where email = 'mod@example.com'`;
    assert.equal((await app.request("/api/gate", { headers: { Cookie: u.cookie } })).headers.get("location"), "/register?next=%2Fplay%2F");
    assert.equal((await post(app, u.cookie, "/register", { username: "badname" })).status, 400);
    const ok = await post(app, u.cookie, "/register", { username: "GoodName", next: "/play/" });
    assert.equal(ok.headers.get("location"), "/play/");
    const [row] = await sql`select username, must_rename, username_changed_at from users where email = 'mod@example.com'`;
    assert.equal(row!.username, "GoodName");
    assert.equal(row!.must_rename, false);
    assert.ok(row!.username_changed_at);

    const bumped = setup({ config: { termsVersion: "2027-01-01" } });
    assert.equal((await bumped.app.request("/api/gate", { headers: { Cookie: u.cookie } })).headers.get("location"), "/register?next=%2Fplay%2F");
    assert.equal((await post(bumped.app, u.cookie, "/register", { next: "/play/" })).status, 400);
    assert.equal((await post(bumped.app, u.cookie, "/register", { next: "/play/", terms: "yes" })).headers.get("location"), "/play/");
    assert.equal((await sql`select terms_version from users where email = 'mod@example.com'`)[0]!.terms_version, "2027-01-01");
    assert.equal((await bumped.app.request("/api/gate", { headers: { Cookie: u.cookie } })).status, 200);
  });

  test("account: profile edit, session revoke, export with every users column, delete cascades", async () => {
    const { app, mailer } = setup();
    const a = await login(app, mailer, "owner@example.com", "203.0.113.60");
    assert.equal((await post(app, a.cookie, "/register", { username: "HouseOwner", country: "GB", terms: "yes" })).status, 303);
    const b = await login(app, mailer, "owner@example.com", "203.0.113.61");

    const edit = await post(app, a.cookie, "/account/profile", { first_name: "O’Neill", last_name: "", country: "US", region: "CA", city: "5368361" });
    assert.equal(edit.status, 303, [...(await edit.clone().text()).matchAll(/data-code="([a-z_]+)"/g)].map((m) => m[1]).join(","));
    const [p] = await sql`select first_name, country_code, region_code, city_name from users where email = 'owner@example.com'`;
    assert.deepEqual({ ...p }, { first_name: "O’Neill", country_code: "US", region_code: "CA", city_name: "Los Angeles" });
    const none = await post(app, a.cookie, "/account/profile", { first_name: "O’Neill", country: "US", region: "", city: "other" });
    assert.equal(none.status, 303);
    const [p2] = await sql`select region_code, city_geonameid, city_name, city_lat from users where email = 'owner@example.com'`;
    assert.deepEqual({ ...p2 }, { region_code: null, city_geonameid: null, city_name: null, city_lat: null });

    const [sb] = await sql`select public_id from sessions where id = encode(sha256(convert_to(${b.cookie.split("=")[1]!}, 'UTF8')), 'hex')`;
    assert.equal((await post(app, a.cookie, "/account/sessions/revoke", { id: sb!.public_id })).status, 303);
    assert.equal((await app.request("/api/me", { headers: { Cookie: b.cookie } })).status, 401);
    assert.equal((await app.request("/api/me", { headers: { Cookie: a.cookie } })).status, 200);

    const exp = await app.request("/account/export", { headers: { Cookie: a.cookie } });
    assert.equal(exp.status, 200);
    const data = (await exp.json()) as any;
    const cols = (await sql`select column_name from information_schema.columns where table_schema = 'public' and table_name = 'users'`).map((r) => r.column_name as string);
    // approved_by is the approving admin's id, another person's data: the one column the export leaves out.
    assert.deepEqual(Object.keys(data.account).sort(), cols.filter((c) => c !== "approved_by").sort(), "every column of users but approved_by");
    assert.ok(cols.includes("approved_by") && "approved_at" in data.account);
    assert.equal(data.account.email, "owner@example.com");
    assert.equal(data.sessions.length, 1);
    assert.ok(data.sign_in_links.length >= 2);
    assert.ok(!JSON.stringify(data).includes("token_hash"));

    const [uid] = await sql`select id from users where email = 'owner@example.com'`;
    assert.equal((await post(app, a.cookie, "/account/delete", { confirm: "nope" })).status, 400);
    const del = await post(app, a.cookie, "/account/delete", { confirm: "houseowner" });
    assert.equal(del.headers.get("location"), "/account/deleted");
    assert.equal((await sql`select 1 from users where id = ${uid!.id}`).length, 0);
    assert.equal((await sql`select 1 from sessions where user_id = ${uid!.id}`).length, 0);
    assert.equal((await sql`select 1 from login_tokens where email = 'owner@example.com'`).length, 0);
    assert.equal((await app.request("/api/me", { headers: { Cookie: a.cookie } })).status, 401);
    const c = await login(app, mailer, "next-owner@example.com", "203.0.113.62");
    assert.equal((await post(app, c.cookie, "/register", { username: "HouseOwner", country: "GB", terms: "yes" })).status, 303);
  });

  test("an unfinished account can be deleted from /register; the geo API serves logged-in users", async () => {
    const { app, mailer } = setup();
    const u = await login(app, mailer, "quitter@example.com", "203.0.113.70");
    const regions = (await (await app.request("/api/geo/regions?country=JP&lang=ja", { headers: { Cookie: u.cookie } })).json()) as any;
    assert.ok(regions.regions.length >= 47);
    const cities = (await (await app.request("/api/geo/cities?country=JP&q=tokyo", { headers: { Cookie: u.cookie } })).json()) as any;
    assert.equal(cities.cities[0].name, "Tokyo");
    assert.equal((await post(app, u.cookie, "/account/delete", { confirm: "yes" })).headers.get("location"), "/account/deleted");
    assert.equal((await sql`select 1 from users where email = 'quitter@example.com'`).length, 0);
  });

  test("career season reports: stored, idempotent, flagged when implausible, owned by one account, exported, cascaded", async () => {
    const { app, mailer } = setup();
    const a = await login(app, mailer, "careers-a@example.com", "203.0.113.60");
    assert.equal((await post(app, a.cookie, "/register", { username: "CareerA", country: "AR", terms: "yes" })).status, 303);
    const b = await login(app, mailer, "careers-b@example.com", "203.0.113.61");
    assert.equal((await post(app, b.cookie, "/register", { username: "CareerB", country: "ES", terms: "yes" })).status, 303);
    const report = (cookie: string, body: Record<string, unknown>) =>
      app.request("/api/career/season", { method: "POST", headers: { ...SAME_ORIGIN, Cookie: cookie, "Content-Type": "application/json" }, body: JSON.stringify(body) });
    const r1 = { career_id: "00112233aabbccdd", season: 1993, reported_on: "1994-07-01", reputation: 1650, club_id: "club_puddlemere_united", club_name: "Puddlemere United", titles: 1, seasons: 1 };
    assert.deepEqual(await (await report(a.cookie, r1)).json(), { ok: true, flagged: false });
    assert.deepEqual(await (await report(a.cookie, r1)).json(), { ok: true, duplicate: true }, "a resend after a reload is harmless");
    assert.equal((await report(a.cookie, { ...r1, reputation: 1700 })).status, 409, "the same season with other numbers");
    assert.equal((await report(b.cookie, { ...r1, season: 1994, reported_on: "1995-07-01" })).status, 409, "another account's career");
    assert.equal((await report(a.cookie, { ...r1, reputation: "lots" })).status, 400);
    assert.equal((await app.request("/api/career/season", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(r1) })).status, 403, "no Origin: refused before the route");
    assert.deepEqual(await (await report(a.cookie, { ...r1, season: 1994, reported_on: "1995-07-01", reputation: 4990, titles: 2, seasons: 2 })).json(), { ok: true, flagged: true });
    assert.deepEqual(await (await report(a.cookie, { ...r1, season: 1995, reported_on: "1996-07-01", reputation: 4995, titles: 2, seasons: 3 })).json(), { ok: true, flagged: false });
    const [c] = await sql`select last_season, last_reputation, flag_reason from careers where career_id = '00112233aabbccdd'`;
    assert.deepEqual({ ...c }, { last_season: 1995, last_reputation: 4995, flag_reason: "reputation_jump" });
    const exp = (await (await app.request("/account/export", { headers: { Cookie: a.cookie } })).json()) as any;
    assert.equal(exp.careers.length, 1);
    assert.equal(exp.careers[0].seasons.length, 3);
    assert.deepEqual(await (await report(b.cookie, { ...r1, career_id: "ffeeddccbbaa0011", club_name: "Wimbourne Wasps", reputation: 1500 })).json(), { ok: true, flagged: false });
    const page = await (await app.request("/ranking")).text();
    assert.match(page, /CareerB/);
    assert.doesNotMatch(page, /CareerA/);
    assert.match(page, /Wimbourne Wasps/);
    assert.doesNotMatch(await (await app.request("/ranking?country=AR")).text(), /CareerB/);
    assert.match(await (await app.request("/ranking?country=es")).text(), /CareerB/);
    const map = await (await app.request("/ranking?view=map")).text();
    assert.match(map, /<svg class="rank-map rank-map-world"/);
    assert.match(map, /<svg class="rank-map rank-map-europe"/);
    assert.match(map, /href="\/ranking\?view=list&amp;country=ES" class="rank-pin"/);
    assert.match(map, /CareerB/, "the best manager per country is in the table");
    assert.equal((await post(app, a.cookie, "/account/delete", { confirm: "CareerA" })).status, 303);
    assert.equal((await sql`select count(*)::int as n from career_seasons where career_id = '00112233aabbccdd'`)[0]!.n, 0);
    assert.equal((await sql`select count(*)::int as n from careers where career_id = '00112233aabbccdd'`)[0]!.n, 0);
  });
});
