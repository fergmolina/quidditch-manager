import assert from "node:assert/strict";
import { after, before, describe, test } from "node:test";
import postgres from "postgres";
import { applyMigrations } from "../../scripts/migrate.js";
import { createApp } from "../../src/app.js";
import { deleteUserAccount } from "../../src/auth/users.js";
import { createPool, type PgPool } from "../../src/db.js";
import { FEEDBACK_LIMIT } from "../../src/routes/feedback.js";
import { captureMailer, SAME_ORIGIN, testDeps } from "../helpers.js";

const ADMIN_URL = process.env.TEST_DATABASE_URL;
const DB_NAME = `qm_itf_${process.pid}_${Date.now().toString(36)}`;
const FORM = { "Content-Type": "application/x-www-form-urlencoded" };
const form = (o: Record<string, string>) => new URLSearchParams(o).toString();
const TO = "owner@example.org";
const MESSAGE = "The Snitch never appears after the 40th minute in the 2D viewer.";

function dbUrl(name: string): string {
  const u = new URL(ADMIN_URL!);
  u.pathname = `/${name}`;
  return u.toString();
}

describe("feedback against a real Postgres", { skip: !ADMIN_URL && "TEST_DATABASE_URL is not set" }, () => {
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

  function setup() {
    const mailer = captureMailer();
    const deps = testDeps({ db: pool.db, mailer, config: { feedbackTo: TO } });
    return { app: createApp(deps), mailer };
  }

  const post = (app: ReturnType<typeof createApp>, body: Record<string, string>, extra: Record<string, string> = {}) =>
    app.request("/feedback", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, ...extra }, body: form(body) });

  async function login(app: ReturnType<typeof createApp>, mailer: ReturnType<typeof captureMailer>, email: string, ip: string): Promise<string> {
    const r1 = await app.request("/auth/magic", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, "CF-Connecting-IP": ip }, body: form({ email, next: "/play/" }) });
    assert.equal(r1.status, 200, await r1.clone().text());
    const token = /token=([A-Za-z0-9_-]{43})/.exec(mailer.sent.at(-1)!.text)![1]!;
    const r2 = await app.request("/auth/magic/verify", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, "CF-Connecting-IP": ip }, body: form({ token }) });
    assert.equal(r2.status, 303);
    return r2.headers.getSetCookie().find((c) => c.startsWith("qm_session="))!.split(";")[0]!;
  }

  test("anonymous submission: stored with the page language and no account, copy mailed, mailed_at set", async () => {
    const { app, mailer } = setup();
    const res = await post(app, { kind: "idea", message: MESSAGE, email: "Player@Example.com", context: "v0.11.0, browser" }, { "CF-Connecting-IP": "203.0.113.50", Cookie: "qm_lang=fr" });
    assert.equal(res.status, 303, await res.clone().text());
    assert.equal(res.headers.get("location"), "/feedback?sent=1");
    const rows = await sql`select user_id, kind, message, reply_email, context, lang, mailed_at from feedback where context = 'v0.11.0, browser'`;
    assert.equal(rows.length, 1);
    assert.deepEqual({ ...rows[0], mailed_at: !!rows[0]!.mailed_at }, { user_id: null, kind: "idea", message: MESSAGE, reply_email: "player@example.com", context: "v0.11.0, browser", lang: "fr", mailed_at: true });
    assert.equal(mailer.sent.length, 1);
    assert.equal(mailer.sent[0]!.to, TO);
    assert.match(mailer.sent[0]!.subject, /^\[Quidditch Manager\] Idea: /);
    assert.equal((await app.request("/feedback?sent=1")).status, 200);
  });

  test("signed-in submission links the account; deleting the account keeps the row and clears the link", async () => {
    const { app, mailer } = setup();
    const cookie = await login(app, mailer, "reporter@example.com", "203.0.113.51");
    const res = await post(app, { kind: "bug", message: MESSAGE, context: "linked" }, { Cookie: cookie, "CF-Connecting-IP": "203.0.113.51" });
    assert.equal(res.status, 303);
    const [u] = await sql`select id from users where email = 'reporter@example.com'`;
    const [row] = await sql`select user_id from feedback where context = 'linked'`;
    assert.equal(row!.user_id, u!.id);
    const exported = (await (await app.request("/account/export", { headers: { Cookie: cookie } })).json()) as { feedback: Array<{ context: string }> };
    assert.deepEqual(exported.feedback.map((f) => f.context), ["linked"]);
    assert.equal(await deleteUserAccount(pool.db, u!.id), true);
    const [after] = await sql`select user_id, message from feedback where context = 'linked'`;
    assert.deepEqual({ ...after }, { user_id: null, message: MESSAGE });
  });

  test("mail failure keeps the row with mailed_at null; the honeypot stores nothing", async () => {
    const { app, mailer } = setup();
    mailer.fail = true;
    const res = await post(app, { kind: "bug", message: MESSAGE, context: "unmailed" }, { "CF-Connecting-IP": "203.0.113.52" });
    assert.equal(res.status, 303);
    const [row] = await sql`select mailed_at from feedback where context = 'unmailed'`;
    assert.equal(row!.mailed_at, null);
    const bot = await post(app, { kind: "bug", message: MESSAGE, context: "bot", website: "x" }, { "CF-Connecting-IP": "203.0.113.52" });
    assert.equal(bot.status, 303);
    assert.equal((await sql`select 1 from feedback where context = 'bot'`).length, 0);
  });

  test("per-address limit: the sixth submission in an hour is refused and not stored", async () => {
    const { app } = setup();
    const ip = "203.0.113.60";
    for (let i = 0; i < FEEDBACK_LIMIT.limit; i++) {
      assert.equal((await post(app, { kind: "bug", message: MESSAGE, context: `burst ${i}` }, { "CF-Connecting-IP": ip })).status, 303, `submission ${i}`);
    }
    const over = await post(app, { kind: "bug", message: MESSAGE, context: "burst over" }, { "CF-Connecting-IP": ip });
    assert.equal(over.status, 429);
    assert.equal((await sql`select count(*)::int as n from feedback where context like 'burst%'`)[0]!.n, FEEDBACK_LIMIT.limit);
    assert.equal((await post(app, { kind: "bug", message: MESSAGE, context: "other address" }, { "CF-Connecting-IP": "203.0.113.61" })).status, 303);
  });

  test("CHECK constraints: kind, message length, email length and context length are enforced by the table", async () => {
    const bad: Array<[string, string]> = [
      ["kind", `insert into feedback (kind, message, lang) values ('rant', '${MESSAGE}', 'en')`],
      ["short message", `insert into feedback (kind, message, lang) values ('bug', 'too short', 'en')`],
      ["long message", `insert into feedback (kind, message, lang) values ('bug', repeat('x', 4001), 'en')`],
      ["long context", `insert into feedback (kind, message, lang, context) values ('bug', '${MESSAGE}', 'en', repeat('c', 201))`],
      ["empty email", `insert into feedback (kind, message, lang, reply_email) values ('bug', '${MESSAGE}', 'en', '')`],
    ];
    for (const [what, stmt] of bad) {
      await assert.rejects(sql.unsafe(stmt), (e: { code?: string }) => e.code === "23514", what);
    }
  });

  test("prune_auth deletes feedback older than 12 months and reports it; qm_api may read, insert and update but not delete", async () => {
    await sql`insert into feedback (kind, message, lang, context, created_at) values
      ('bug', ${MESSAGE}, 'en', 'ancient', now() - interval '13 months'),
      ('bug', ${MESSAGE}, 'en', 'recent', now() - interval '11 months')`;
    const result = await sql`select * from public.prune_auth()`;
    const by = Object.fromEntries(result.map((r) => [r.what, Number(r.deleted)]));
    assert.ok(by.feedback! >= 1);
    assert.equal((await sql`select 1 from feedback where context = 'ancient'`).length, 0);
    assert.equal((await sql`select 1 from feedback where context = 'recent'`).length, 1);
    const [priv] = await sql`select has_table_privilege('qm_api', 'public.feedback', 'select') as s,
                                    has_table_privilege('qm_api', 'public.feedback', 'insert') as i,
                                    has_table_privilege('qm_api', 'public.feedback', 'update') as u,
                                    has_table_privilege('qm_api', 'public.feedback', 'delete') as d,
                                    has_function_privilege('qm_api', 'public.prune_auth()', 'execute') as prune`;
    assert.deepEqual({ ...priv }, { s: true, i: true, u: true, d: false, prune: false });
  });
});
