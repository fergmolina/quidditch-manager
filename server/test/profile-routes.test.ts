import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp } from "../src/app.js";
import { sha256Hex } from "../src/auth/tokens.js";
import { PAGE_CSP } from "../src/http/security.js";
import { fakeDb, SAME_ORIGIN, testDeps, type Statement } from "./helpers.js";

const FORM = { "Content-Type": "application/x-www-form-urlencoded" };
const form = (o: Record<string, string>) => new URLSearchParams(o).toString();
const TOKEN = "P".repeat(43);
const COOKIE = { Cookie: `qm_session=${TOKEN}` };
const USER_ID = "11111111-1111-4111-8111-111111111111";
const CURRENT_SESSION = "00000000-0000-4000-8000-000000000001";
const OTHER_SESSION = "00000000-0000-4000-8000-000000000002";
const TERMS = "2026-11-01";

function userRow(over: Record<string, unknown> = {}): Record<string, unknown> {
  const now = Date.now();
  return {
    id: USER_ID,
    email: "owner@example.com",
    email_verified: true,
    google_sub: null,
    username: "HarryFan",
    first_name: "Harry",
    last_name: "Fan",
    country_code: "AR",
    region_code: "07",
    city_geonameid: 3435910,
    city_name: "Buenos Aires",
    city_lat: -34.6132,
    city_lon: -58.3772,
    terms_version: TERMS,
    terms_accepted_at: new Date(now - 86_400_000),
    username_changed_at: null,
    must_rename: false,
    is_admin: false,
    blocked_at: null,
    created_at: new Date("2026-01-02T00:00:00Z"),
    last_login_at: new Date(now),
    ...over,
  };
}

const INCOMPLETE = { username: null, first_name: null, last_name: null, country_code: null, region_code: null, city_geonameid: null, city_name: null, city_lat: null, city_lon: null, terms_version: null, terms_accepted_at: null };

interface Scenario {
  user?: Record<string, unknown>;
  taken?: boolean;
  updateError?: unknown;
  rateOk?: boolean;
}

function profileDb(s: Scenario = {}) {
  let row = userRow(s.user);
  const db = fakeDb((st: Statement) => {
    const t = st.text;
    if (t.startsWith("select s.id as session_id")) {
      if (st.values[0] !== sha256Hex(TOKEN)) return [];
      const now = Date.now();
      return [
        {
          session_id: sha256Hex(TOKEN),
          session_public_id: CURRENT_SESSION,
          session_created_at: new Date(now - 86_400_000),
          session_last_seen_at: new Date(now),
          session_expires_at: new Date(now + 20 * 86_400_000),
          session_absolute_expires_at: new Date(now + 170 * 86_400_000),
          via_previous: false,
          ...row,
        },
      ];
    }
    if (t.startsWith("insert into public.auth_rate_events")) return s.rateOk === false ? [] : [{ id: "1" }];
    if (t.startsWith("select 1 as ok from public.users where lower(username)")) return s.taken ? [{ ok: 1 }] : [];
    if (t.startsWith("update public.users")) {
      if (s.updateError) throw s.updateError;
      row = { ...row, ...updatedColumns(t, st.values) };
      return [row];
    }
    if (t.startsWith("select public_id, created_at, last_seen_at, expires_at, user_agent_family")) {
      const now = Date.now();
      return [
        { public_id: CURRENT_SESSION, created_at: new Date(now - 86_400_000), last_seen_at: new Date(now), expires_at: new Date(now + 1e9), user_agent_family: "Firefox · macOS" },
        { public_id: OTHER_SESSION, created_at: new Date(now - 5 * 86_400_000), last_seen_at: new Date(now - 86_400_000), expires_at: new Date(now + 1e9), user_agent_family: "<b>Evil</b>" },
      ];
    }
    if (t.startsWith("delete from public.sessions where user_id = $1::uuid and public_id")) return [{ id: "x" }];
    if (t.startsWith("delete from public.sessions where id = $1 or prev_id = $1")) return [];
    if (t.startsWith("select * from public.users where id")) return [{ ...row, secret_extra: undefined }];
    if (t.startsWith("select public_id, created_at, last_seen_at, expires_at, absolute_expires_at")) {
      return [{ public_id: CURRENT_SESSION, created_at: new Date(), last_seen_at: new Date(), expires_at: new Date(), absolute_expires_at: new Date(), rotated_at: null, user_agent_family: "Firefox · macOS" }];
    }
    if (t.startsWith("select created_at, expires_at, consumed_at, lang, next_path, ip_hash from public.login_tokens")) {
      return [{ created_at: new Date(), expires_at: new Date(), consumed_at: new Date(), lang: "es", next_path: "/play/", ip_hash: "ab".repeat(16) }];
    }
    if (t.startsWith("delete from public.users where id")) return [{ email: row.email }];
    if (t.startsWith("delete from public.login_tokens where email")) return [];
    if (/from public\.careers? where user_id|from public\.career_seasons where user_id|from public\.feedback where user_id/.test(t)) return [];
    return undefined;
  });
  return db;
}

function updatedColumns(text: string, values: unknown[]): Record<string, unknown> {
  const set = /set (.*?) where/.exec(text)?.[1] ?? "";
  const out: Record<string, unknown> = {};
  for (const m of set.matchAll(/(\w+) = (\$(\d+)|false)/g)) out[m[1]!] = m[2] === "false" ? false : values[Number(m[3]) - 1];
  return out;
}

const post = (app: ReturnType<typeof createApp>, path: string, body: Record<string, string>, extra: Record<string, string> = {}) =>
  app.request(path, { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, ...COOKIE, ...extra }, body: form(body) });

const userUpdates = (db: ReturnType<typeof profileDb>) => db.log.filter((s) => s.text.startsWith("update public.users"));

test("GET /register: login first; complete users go on; blocked users are refused", async () => {
  const anon = createApp(testDeps({ db: profileDb() }));
  const r = await anon.request("/register?next=/play/");
  assert.equal(r.status, 303);
  assert.equal(r.headers.get("location"), "/login?next=%2Fplay%2F");
  const done = createApp(testDeps({ db: profileDb() }));
  const r2 = await done.request("/register?next=/account", { headers: COOKIE });
  assert.equal(r2.headers.get("location"), "/account");
  const loop = await done.request("/register?next=/register", { headers: COOKIE });
  assert.equal(loop.headers.get("location"), "/play/", "never back into /register");
  const blocked = createApp(testDeps({ db: profileDb({ user: { blocked_at: new Date() } }) }));
  assert.equal((await blocked.request("/register", { headers: COOKIE })).headers.get("location"), "/login?error=blocked");
});

test("GET /register (new account): full form, works without JS, script from /static only, CF-IPCountry preselects", async () => {
  const app = createApp(testDeps({ db: profileDb({ user: INCOMPLETE }) }));
  const res = await app.request("/register?next=/play/", { headers: { ...COOKIE, "CF-IPCountry": "AR" } });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("content-security-policy"), PAGE_CSP);
  assert.equal(res.headers.get("cache-control"), "private, no-store");
  const body = await res.text();
  assert.match(body, /<form class="stack" method="post" action="\/register" data-profile-form>/);
  for (const name of ["username", "first_name", "last_name", "country", "region", "city", "terms", "next"]) assert.match(body, new RegExp(`name="${name}"`), name);
  assert.match(body, /<select id="country" name="country" required/);
  assert.match(body, /<option value="AR" selected>/);
  assert.match(body, /<option value="07"[^>]*>Buenos Aires F\.D\.<\/option>/, "regions of the preselected country");
  assert.match(body, /<option value="other">/, "Other / not listed");
  assert.match(body, /name="action" value="refresh" formnovalidate/, "no-JS refresh button");
  const firstSubmit = /<form class="stack" method="post" action="\/register"[\s\S]*?<button\b[^>]*>/.exec(body)?.[0] ?? "";
  assert.match(firstSubmit, /<button type="submit" class="default-submit"[^>]*>$/, "Enter submits the form, not the refresh");
  assert.match(body, /href="\/terms"/);
  assert.match(body, /href="\/privacy"/);
  assert.match(body, /geonames\.org/);
  assert.match(body, /href="\/account\/delete"/, "an unfinished account can still be deleted");
  assert.match(body, /owner@example\.com/);
  const scripts = [...body.matchAll(/<script\b[^>]*>/g)].map((m) => m[0]);
  assert.equal(scripts.length, 1);
  assert.match(scripts[0]!, /^<script src="\/static\/register\.js\?v=[0-9a-f]+" defer>$/);
  assert.doesNotMatch(body, /<script>|\sstyle=|\son[a-z]+=/i, "no inline script, style or handler");
  const js = await app.request("/static/register.js");
  assert.equal(js.status, 200);
  assert.equal(js.headers.get("content-type"), "text/javascript; charset=utf-8");
});

test("POST /register: every field error re-renders the form (400) with the values kept and escaped; nothing written", async () => {
  const db = profileDb({ user: INCOMPLETE });
  const app = createApp(testDeps({ db }));
  const res = await post(app, "/register", { next: "/play/", username: "1bad", first_name: `<img src=x onerror=alert(1)>`, last_name: "Ok", country: "AR", region: "nope", city: "999999999" });
  assert.equal(res.status, 400);
  const body = await res.text();
  for (const code of ["username_format", "name_invalid", "region_invalid", "city_invalid", "terms_required"]) assert.match(body, new RegExp(`data-code="${code}"`), code);
  assert.doesNotMatch(body, /<img src=x/);
  assert.match(body, /value="&lt;img src=x onerror=alert\(1\)&gt;"/);
  assert.match(body, /aria-invalid="true"/);
  assert.equal(userUpdates(db).length, 0);

  const r2 = await post(app, "/register", { username: "GoodName", country: "", terms: "yes" });
  assert.match(await r2.text(), /data-code="country_required"/);
  const r3 = await post(app, "/register", { username: "admin", country: "AR", terms: "yes" });
  assert.match(await r3.text(), /data-code="username_reserved"/);
  assert.equal(userUpdates(db).length, 0);
});

test("POST /register: success stores the profile with city data from GeoNames (not the form) and redirects to next", async () => {
  const db = profileDb({ user: INCOMPLETE });
  const app = createApp(testDeps({ db }));
  const res = await post(app, "/register", { next: "/play/?x=1", username: "NewPlayer", first_name: " José  María ", last_name: "", country: "ar", region: "01", city: "3435910", terms: "yes", city_name: "Hacked", city_lat: "0" });
  assert.equal(res.status, 303, await res.clone().text());
  assert.equal(res.headers.get("location"), "/play/?x=1");
  const [upd] = userUpdates(db);
  assert.ok(upd);
  assert.match(upd.text, /where id = \$1::uuid and username is null and blocked_at is null/);
  const v = upd.values;
  assert.deepEqual(v.slice(0, 10), [USER_ID, "José María", null, "AR", "07", 3435910, "Buenos Aires", -34.6131, -58.3772, TERMS]);
  assert.equal(v[11], "NewPlayer");
  assert.ok(db.log.some((s) => s.text.startsWith("insert into public.auth_rate_events") && s.values[0] === "profile_write" && s.values[1] === `user:${USER_ID}`));
});

test("POST /register: the unique index decides (23505 → username_taken, 409); the pre-check catches the common case", async () => {
  const unique = Object.assign(new Error("dup"), { code: "23505", constraint_name: "users_username_key" });
  const raced = createApp(testDeps({ db: profileDb({ user: INCOMPLETE, updateError: unique }) }));
  const r1 = await post(raced, "/register", { username: "Racer", country: "FR", terms: "yes" });
  assert.equal(r1.status, 409);
  assert.match(await r1.text(), /data-code="username_taken"/);
  const db = profileDb({ user: INCOMPLETE, taken: true });
  const taken = createApp(testDeps({ db }));
  const r2 = await post(taken, "/register", { username: "harryfan", country: "FR", terms: "yes" });
  assert.equal(r2.status, 409);
  assert.equal(userUpdates(db).length, 0);
});

test("POST /register action=refresh: re-renders with the new country's lists, no validation, no write", async () => {
  const db = profileDb({ user: INCOMPLETE });
  const app = createApp(testDeps({ db }));
  const res = await post(app, "/register", { action: "refresh", username: "", country: "US", region: "CA", city: "" });
  assert.equal(res.status, 200);
  const body = await res.text();
  assert.match(body, /<option value="CA" selected>California<\/option>/);
  assert.match(body, /<option value="5368361" data-region="CA">Los Angeles<\/option>/);
  assert.doesNotMatch(body, /data-code=/);
  assert.equal(userUpdates(db).length, 0);
  const big = await post(app, "/register", { action: "refresh", country: "US", region: "", city: "" });
  assert.match(await big.text(), /data-geo="city-hint"/, "too many cities without a region: ask for one");
});

test("forced rename (must_rename): explains, refuses the same name in any case, clears the flag, no cooldown", async () => {
  const db = profileDb({ user: { must_rename: true, username_changed_at: new Date() } });
  const app = createApp(testDeps({ db }));
  const g = await app.request("/register", { headers: COOKIE });
  const page = await g.text();
  assert.match(page, /@HarryFan/);
  assert.doesNotMatch(page, /name="country"/, "only the username is asked");
  assert.doesNotMatch(page, /name="terms"/, "terms are current");
  const same = await post(app, "/register", { username: "HARRYFAN" });
  assert.equal(same.status, 400);
  assert.match(await same.text(), /data-code="username_same"/);
  const ok = await post(app, "/register", { username: "CleanName", next: "/play/" });
  assert.equal(ok.status, 303);
  assert.equal(ok.headers.get("location"), "/play/");
  const [upd] = userUpdates(db);
  assert.match(upd!.text, /set username = \$2, username_changed_at = \$3::timestamptz, must_rename = false where id = \$1::uuid and must_rename/);
});

test("new terms version: a re-accept page; the checkbox is required; acceptance stores the current version", async () => {
  const db = profileDb({ user: { terms_version: "2020-01-01" } });
  const app = createApp(testDeps({ db }));
  const g = await app.request("/register?next=/play/", { headers: COOKIE });
  const page = await g.text();
  assert.match(page, /web\.register\.terms_title|We updated our terms/);
  assert.match(page, /name="terms"/);
  assert.doesNotMatch(page, /name="username"/);
  const no = await post(app, "/register", { next: "/play/" });
  assert.equal(no.status, 400);
  assert.equal(userUpdates(db).length, 0);
  const yes = await post(app, "/register", { next: "/play/", terms: "yes" });
  assert.equal(yes.status, 303);
  assert.equal(yes.headers.get("location"), "/play/");
  assert.deepEqual(userUpdates(db)[0]!.values.slice(0, 2), [USER_ID, TERMS]);
});

test("GET /account: owner-only data, escaped; sessions with revoke; export and delete links; incomplete → /register", async () => {
  const app = createApp(testDeps({ db: profileDb({ user: { first_name: "<i>Harry</i>" } }) }));
  const res = await app.request("/account?saved=profile", { headers: COOKIE });
  assert.equal(res.status, 200);
  const body = await res.text();
  assert.match(body, /owner@example\.com/);
  assert.match(body, /value="&lt;i&gt;Harry&lt;\/i&gt;"/);
  assert.doesNotMatch(body, /<i>Harry/);
  assert.match(body, /data-saved="profile"/);
  assert.match(body, /<option value="3435910" data-region="07" selected>Buenos Aires<\/option>/);
  assert.match(body, new RegExp(`name="id" value="${OTHER_SESSION}"`));
  assert.doesNotMatch(body, new RegExp(`name="id" value="${CURRENT_SESSION}"`), "the current session signs out instead");
  assert.match(body, /&lt;b&gt;Evil&lt;\/b&gt;/);
  assert.match(body, /href="\/account\/export"/);
  assert.match(body, /href="\/account\/delete"/);
  assert.match(body, /action="\/auth\/logout-all"/);
  assert.match(body, /action="\/account\/username"/);
  const bad = await app.request("/account?saved=<x>", { headers: COOKIE });
  assert.doesNotMatch(await bad.text(), /data-saved=/);

  const inc = createApp(testDeps({ db: profileDb({ user: INCOMPLETE }) }));
  assert.equal((await inc.request("/account", { headers: COOKIE })).headers.get("location"), "/register?next=%2Faccount");
  const anon = createApp(testDeps({ db: profileDb() }));
  assert.equal((await anon.request("/account")).headers.get("location"), "/login?next=%2Faccount");
});

test("POST /account/username: rules, availability, 30-day cooldown (no form, no write)", async () => {
  const db = profileDb();
  const app = createApp(testDeps({ db }));
  const reserved = await post(app, "/account/username", { username: "support" });
  assert.equal(reserved.status, 400);
  assert.match(await reserved.text(), /data-code="username_reserved"/);
  const ok = await post(app, "/account/username", { username: "Harry_2" });
  assert.equal(ok.status, 303);
  assert.equal(ok.headers.get("location"), "/account?saved=username#username-section");
  const [upd] = userUpdates(db);
  assert.match(upd!.text, /username_changed_at is null or username_changed_at <= \$4::timestamptz/);
  assert.equal(upd!.values[1], "Harry_2");

  const lockedDb = profileDb({ user: { username_changed_at: new Date(Date.now() - 5 * 86_400_000) } });
  const locked = createApp(testDeps({ db: lockedDb }));
  const page = await (await locked.request("/account", { headers: COOKIE })).text();
  assert.doesNotMatch(page, /action="\/account\/username"/);
  const r = await post(locked, "/account/username", { username: "Another" });
  assert.equal(r.status, 303);
  assert.equal(userUpdates(lockedDb).length, 0);
});

test("POST /account/profile: names and location; errors re-render; refresh does not write", async () => {
  const db = profileDb();
  const app = createApp(testDeps({ db }));
  const bad = await post(app, "/account/profile", { first_name: "x​y", country: "ZZ" });
  assert.equal(bad.status, 400);
  const body = await bad.text();
  assert.match(body, /data-code="name_invalid"/);
  assert.match(body, /data-code="country_invalid"/);
  assert.equal((await post(app, "/account/profile", { action: "refresh", country: "DE" })).status, 200);
  assert.equal(userUpdates(db).length, 0);
  const ok = await post(app, "/account/profile", { first_name: "", last_name: "Fan", country: "UY", region: "", city: "other" });
  assert.equal(ok.status, 303);
  assert.deepEqual(userUpdates(db)[0]!.values, [USER_ID, null, "Fan", "UY", null, null, null, null, null]);
  const limited = createApp(testDeps({ db: profileDb({ rateOk: false }) }));
  assert.equal((await post(limited, "/account/profile", { country: "UY" })).status, 429);
});

test("sessions: revoke another one; revoking the current one signs out", async () => {
  const db = profileDb();
  const app = createApp(testDeps({ db }));
  const r = await post(app, "/account/sessions/revoke", { id: OTHER_SESSION });
  assert.equal(r.status, 303);
  const del = db.log.find((s) => s.text.startsWith("delete from public.sessions where user_id"));
  assert.deepEqual(del?.values, [USER_ID, OTHER_SESSION]);
  const me = await post(app, "/account/sessions/revoke", { id: CURRENT_SESSION });
  assert.equal(me.headers.get("location"), "/");
  assert.ok(me.headers.getSetCookie().some((c) => c.startsWith("qm_session=;")));
});

test("GET /account/export: a private JSON download with the account, sessions and links, never token hashes", async () => {
  const app = createApp(testDeps({ db: profileDb() }));
  const res = await app.request("/account/export", { headers: COOKIE });
  assert.equal(res.status, 200);
  assert.match(res.headers.get("content-disposition") ?? "", /^attachment; filename="quidditch-manager-account-\d{4}-\d{2}-\d{2}\.json"$/);
  assert.equal(res.headers.get("cache-control"), "private, no-store");
  const data = (await res.json()) as any;
  for (const col of ["id", "email", "username", "first_name", "last_name", "country_code", "region_code", "city_geonameid", "city_name", "city_lat", "city_lon", "terms_version", "terms_accepted_at", "created_at", "last_login_at", "must_rename", "blocked_at"]) {
    assert.ok(col in data.account, col);
  }
  assert.equal(data.sessions.length, 1);
  assert.equal(data.sign_in_links.length, 1);
  assert.deepEqual(data.careers, []);
  assert.deepEqual(data.feedback, []);
  const text = JSON.stringify(data);
  assert.ok(!text.includes(sha256Hex(TOKEN)));
  assert.ok(!/token_hash|prev_id|"id":"[0-9a-f]{64}"/.test(text));
});

test("delete: confirmation page; wrong confirmation deletes nothing; the right one deletes, signs out, says goodbye", async () => {
  const db = profileDb();
  const app = createApp(testDeps({ db }));
  const page = await app.request("/account/delete", { headers: COOKIE });
  assert.equal(page.status, 200);
  assert.match(await page.text(), /name="confirm"/);
  const wrong = await post(app, "/account/delete", { confirm: "someone" });
  assert.equal(wrong.status, 400);
  assert.match(await wrong.text(), /data-code="confirm_mismatch"/);
  assert.ok(!db.log.some((s) => s.text.startsWith("delete from public.users")));
  const ok = await post(app, "/account/delete", { confirm: " harryfan " });
  assert.equal(ok.status, 303);
  assert.equal(ok.headers.get("location"), "/account/deleted");
  assert.ok(ok.headers.getSetCookie().some((c) => c.startsWith("qm_session=;")));
  assert.ok(db.log.some((s) => s.text.startsWith("delete from public.users where id")));
  assert.ok(db.log.some((s) => s.text.startsWith("delete from public.login_tokens where email")));
  assert.equal((await app.request("/account/deleted")).status, 200);

  const incDb = profileDb({ user: INCOMPLETE });
  const inc = createApp(testDeps({ db: incDb }));
  assert.match(await (await inc.request("/account/delete", { headers: COOKIE })).text(), /type="checkbox" name="confirm" value="yes"/);
  assert.equal((await post(inc, "/account/delete", { confirm: "yes" })).headers.get("location"), "/account/deleted");

  const blocked = createApp(testDeps({ db: profileDb({ user: { blocked_at: new Date() } }) }));
  assert.equal((await post(blocked, "/account/delete", { confirm: "harryfan" })).headers.get("location"), "/login?error=blocked");
});

test("every profile POST needs a same-origin request (tier 1) before anything runs", async () => {
  const db = profileDb();
  const app = createApp(testDeps({ db }));
  for (const path of ["/register", "/account/profile", "/account/username", "/account/sessions/revoke", "/account/delete"]) {
    const r = await app.request(path, { method: "POST", headers: { ...FORM, ...COOKIE, Origin: "https://evil.example" }, body: form({ confirm: "harryfan" }) });
    assert.equal(r.status, 403, path);
  }
  assert.equal(db.writes().length, 0, "no write (the 403 page only looks up the viewer for its header)");
  assert.ok(!db.log.some((s) => s.text.startsWith("insert into public.auth_rate_events")));
});

test("GET /api/geo/*: logged-in only, validated input, private JSON", async () => {
  const app = createApp(testDeps({ db: profileDb() }));
  assert.equal((await app.request("/api/geo/regions?country=AR")).status, 401);
  const bad = await app.request("/api/geo/regions?country=XX", { headers: COOKIE });
  assert.equal(bad.status, 400);
  const r = await app.request("/api/geo/regions?country=ar&lang=es", { headers: COOKIE });
  assert.equal(r.headers.get("cache-control"), "private, no-store");
  const regions = ((await r.json()) as any).regions as Array<{ code: string; name: string }>;
  assert.ok(regions.some((x) => x.code === "07"));
  const c = await app.request("/api/geo/cities?country=AR&q=buenos", { headers: COOKIE });
  const cities = ((await c.json()) as any).cities as Array<{ id: number; name: string; region: string; region_name: string | null }>;
  assert.deepEqual(cities[0], { id: 3435910, name: "Buenos Aires", region: "07", region_name: "Buenos Aires F.D." });
  assert.ok(cities.length <= 20);
  assert.equal((await app.request("/api/geo/cities?country=AR&region=zz&q=a", { headers: COOKIE })).status, 400);
  const inRegion = (await (await app.request("/api/geo/cities?country=US&region=CA&q=san", { headers: COOKIE })).json()) as any;
  assert.ok(inRegion.cities.length > 0 && inRegion.cities.every((x: { region: string }) => x.region === "CA"));
});

test("GET /api/username-available: rules first, then the database; your own name counts as free", async () => {
  const free = createApp(testDeps({ db: profileDb() }));
  assert.equal((await free.request("/api/username-available?u=abc")).status, 401);
  assert.deepEqual(await (await free.request("/api/username-available?u=1x", { headers: COOKIE })).json(), { available: false, error: "username_format" });
  assert.deepEqual(await (await free.request("/api/username-available?u=admin", { headers: COOKIE })).json(), { available: false, error: "username_reserved" });
  assert.deepEqual(await (await free.request("/api/username-available?u=Fresh_1", { headers: COOKIE })).json(), { available: true, error: null });
  const db = profileDb({ taken: true });
  const taken = createApp(testDeps({ db }));
  assert.deepEqual(await (await taken.request("/api/username-available?u=Someone", { headers: COOKIE })).json(), { available: false, error: "username_taken" });
  const q = db.log.find((s) => s.text.startsWith("select 1 as ok from public.users"));
  assert.deepEqual(q?.values, ["Someone", USER_ID]);
});
