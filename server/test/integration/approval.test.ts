import assert from "node:assert/strict";
import { copyFileSync, mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import postgres from "postgres";
import { applyMigrations, MIGRATIONS_DIR } from "../../scripts/migrate.js";
import { createApp } from "../../src/app.js";
import { createPool, type PgPool } from "../../src/db.js";
import { captureNotifier, SAME_ORIGIN, testDeps } from "../helpers.js";

const ADMIN_URL = process.env.TEST_DATABASE_URL;
const DB_NAME = `qm_ita_${process.pid}_${Date.now().toString(36)}`;
const FORM = { "Content-Type": "application/x-www-form-urlencoded" };
const form = (o: Record<string, string>) => new URLSearchParams(o).toString();

function dbUrl(name: string): string {
  const u = new URL(ADMIN_URL!);
  u.pathname = `/${name}`;
  return u.toString();
}

describe("approval (closed trial) against a real Postgres", { skip: !ADMIN_URL && "TEST_DATABASE_URL is not set" }, () => {
  let pool: PgPool;
  let sql: PgPool["sql"];
  let legacyId: string;

  before(async () => {
    const admin = postgres(ADMIN_URL!, { max: 1, onnotice: () => undefined });
    await admin.unsafe(`create database ${DB_NAME}`);
    await admin.end();
    // A database as it was before 0006, with one account already in it: the backfill must approve that account.
    const older = mkdtempSync(join(tmpdir(), "qm-mig-"));
    for (const f of readdirSync(MIGRATIONS_DIR)) if (f < "0006") copyFileSync(join(MIGRATIONS_DIR, f), join(older, f));
    await applyMigrations(dbUrl(DB_NAME), older);
    rmSync(older, { recursive: true, force: true });
    const legacy = postgres(dbUrl(DB_NAME), { max: 1, onnotice: () => undefined });
    const inserted = await legacy`insert into users (email, username, country_code, terms_version, terms_accepted_at, created_at)
                                  values ('legacy@example.com', 'OldHand', 'DE', '2026-11-01', now(), now() - interval '10 days') returning id`;
    legacyId = inserted[0]!.id as string;
    await legacy.end();
    for (let i = 0; i < 2; i++) await applyMigrations(dbUrl(DB_NAME));
    pool = createPool(dbUrl(DB_NAME), 4);
    sql = pool.sql;
  });

  after(async () => {
    await pool?.close();
    const admin = postgres(ADMIN_URL!, { max: 1, onnotice: () => undefined });
    await admin.unsafe(`drop database if exists ${DB_NAME} with (force)`);
    await admin.end();
  });

  function setup(accessMode: "open" | "approval") {
    const notifier = captureNotifier();
    const deps = testDeps({ db: pool.db, notifier, config: { accessMode } });
    return { app: createApp(deps), notifier, mailer: deps.mailer as ReturnType<typeof import("../helpers.js").captureMailer> };
  }

  async function login(app: ReturnType<typeof createApp>, mailer: { sent: Array<{ text: string }> }, email: string, ip: string): Promise<string> {
    const r1 = await app.request("/auth/magic", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, "CF-Connecting-IP": ip }, body: form({ email, next: "/play/" }) });
    assert.equal(r1.status, 200, await r1.clone().text());
    const token = /token=([A-Za-z0-9_-]{43})/.exec(mailer.sent.at(-1)!.text)![1]!;
    const r2 = await app.request("/auth/magic/verify", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, "CF-Connecting-IP": ip }, body: form({ token }) });
    assert.equal(r2.status, 303);
    return r2.headers.getSetCookie().find((c) => c.startsWith("qm_session="))!.split(";")[0]!;
  }

  const gate = (app: ReturnType<typeof createApp>, cookie: string, method = "GET") =>
    app.request("/api/gate", { headers: { Cookie: cookie, "X-Forwarded-Uri": "/play/", "X-Forwarded-Method": method } });

  test("migration 0006: the backfill approves existing accounts once; re-applying never approves a waiting account", async () => {
    const [legacy] = await sql`select approved_at, created_at, approved_by from users where id = ${legacyId}`;
    assert.ok(legacy!.approved_at, "backfilled");
    assert.equal(+legacy!.approved_at, +legacy!.created_at, "approved_at = created_at for accounts older than the column");
    assert.equal(legacy!.approved_by, null);
    const [w] = await sql`insert into users (email, username, country_code, terms_version, terms_accepted_at) values ('waiting@example.com', 'Waiting', 'FR', '2026-11-01', now()) returning id`;
    await applyMigrations(dbUrl(DB_NAME));
    const [still] = await sql`select approved_at from users where id = ${w!.id}`;
    assert.equal(still!.approved_at, null, "the backfill is one-shot");
    const [idx] = await sql`select 1 from pg_indexes where indexname = 'users_pending_idx'`;
    assert.ok(idx);
  });

  test("approval round trip: register → pending (alert sent) → admin approves → gate 200; block → 401 and sessions gone; revoke → pending again", async () => {
    const { app, notifier, mailer } = setup("approval");
    const player = await login(app, mailer, "trial@example.com", "203.0.113.70");
    const reg = await app.request("/register", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, Cookie: player }, body: form({ next: "/play/", username: "TrialOne", country: "AR", terms: "yes" }) });
    assert.equal(reg.status, 303, await reg.clone().text());
    assert.equal(reg.headers.get("location"), "/pending");
    assert.deepEqual(notifier.sent, ["New sign-up: @TrialOne (AR) — pending approval: http://localhost:8080/admin/users?view=pending"]);
    assert.equal((await gate(app, player)).headers.get("location"), "/pending");
    assert.equal((await gate(app, player, "POST")).status, 401);
    assert.deepEqual(await (await app.request("/api/me", { headers: { Cookie: player } })).json(), { logged_in: true, username: "TrialOne", country: "AR", locale: "en", profile_complete: false, pending: true });
    assert.equal((await app.request("/pending", { headers: { Cookie: player } })).status, 200);
    assert.equal((await app.request("/admin/users", { headers: { Cookie: player } })).status, 404, "a player never sees the admin page");

    const admin = await login(app, mailer, "boss@example.com", "203.0.113.71");
    await sql`update users set username = 'TheBoss', country_code = 'AR', terms_version = '2026-11-01', terms_accepted_at = now(), approved_at = now(), is_admin = true where email = 'boss@example.com'`;
    const list = await app.request("/admin/users?view=pending", { headers: { Cookie: admin } });
    assert.equal(list.status, 200);
    const page = await list.text();
    assert.match(page, /@TrialOne/);
    assert.match(page, /trial@example\.com/);
    const trialId = (await sql`select id from users where email = 'trial@example.com'`)[0]!.id as string;
    const approve = await app.request("/admin/users/approve", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, Cookie: admin }, body: form({ id: trialId, view: "pending" }) });
    assert.equal(approve.status, 303);
    assert.equal(approve.headers.get("location"), "/admin/users?view=pending&done=approve");
    const [row] = await sql`select approved_at, approved_by, (select id from users where email = 'boss@example.com') as boss from users where id = ${trialId}`;
    assert.ok(row!.approved_at);
    assert.equal(row!.approved_by, row!.boss);
    assert.equal((await gate(app, player)).status, 200);
    assert.equal((await app.request("/pending", { headers: { Cookie: player } })).headers.get("location"), "/play/");
    assert.doesNotMatch(await (await app.request("/admin/users?view=pending", { headers: { Cookie: admin } })).text(), /@TrialOne/, "out of the queue");

    const block = await app.request("/admin/users/block", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, Cookie: admin }, body: form({ id: trialId, view: "all" }) });
    assert.equal(block.headers.get("location"), "/admin/users?view=all&done=block");
    assert.equal((await gate(app, player, "POST")).status, 401);
    assert.equal((await app.request("/api/me", { headers: { Cookie: player } })).status, 401, "the session is gone, not just refused");
    assert.equal((await sql`select 1 from sessions where user_id = ${trialId}`).length, 0);
    const unblock = await app.request("/admin/users/unblock", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, Cookie: admin }, body: form({ id: trialId }) });
    assert.equal(unblock.headers.get("location"), "/admin/users?view=pending&done=unblock");
    const revoke = await app.request("/admin/users/revoke", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, Cookie: admin }, body: form({ id: trialId }) });
    assert.equal(revoke.headers.get("location"), "/admin/users?view=pending&done=revoke");
    const [revoked] = await sql`select approved_at, approved_by, blocked_at from users where id = ${trialId}`;
    assert.deepEqual({ ...revoked }, { approved_at: null, approved_by: null, blocked_at: null });
    const again = await login(app, mailer, "trial@example.com", "203.0.113.72");
    assert.equal((await gate(app, again)).headers.get("location"), "/pending");

    const bossId = (await sql`select id from users where email = 'boss@example.com'`)[0]!.id as string;
    const selfBlock = await app.request("/admin/users/block", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, Cookie: admin }, body: form({ id: bossId }) });
    assert.equal(selfBlock.headers.get("location"), "/admin/users?view=pending&done=none", "an admin cannot block their own account");
    assert.equal((await sql`select count(*)::int as n from auth_rate_events where bucket = 'admin_write' and subject = ${"user:" + bossId}`)[0]!.n, 5);
    assert.equal(notifier.sent.length, 1, "approval, block and revoke send no alerts");
  });

  test("open access: a completed registration is approved on the spot, so a later switch to approval mode keeps it playing", async () => {
    const { app, notifier, mailer } = setup("open");
    const cookie = await login(app, mailer, "open@example.com", "203.0.113.73");
    const reg = await app.request("/register", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, Cookie: cookie }, body: form({ next: "/play/", username: "OpenDoor", country: "BR", terms: "yes" }) });
    assert.equal(reg.headers.get("location"), "/play/");
    assert.deepEqual(notifier.sent, ["New sign-up: @OpenDoor (BR) — approved (open access)"]);
    const [u] = await sql`select approved_at, approved_by from users where email = 'open@example.com'`;
    assert.ok(u!.approved_at);
    assert.equal(u!.approved_by, null);
    const strict = setup("approval").app;
    assert.equal((await gate(strict, cookie)).status, 200);
    const [legacy] = await sql`select 1 from users where id = ${legacyId} and approved_at is not null`;
    assert.ok(legacy, "the backfilled account plays too");
  });
});
