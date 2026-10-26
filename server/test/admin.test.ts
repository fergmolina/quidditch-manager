import assert from "node:assert/strict";
import { test } from "node:test";
import { accountState, applyAdminAction, listUsers, parseView } from "../src/admin/admin.js";
import { createApp } from "../src/app.js";
import { sha256Hex } from "../src/auth/tokens.js";
import { ADMIN_WRITE_LIMIT } from "../src/routes/admin.js";
import { fakeDb, SAME_ORIGIN, testDeps, type Statement } from "./helpers.js";

const FORM = { "Content-Type": "application/x-www-form-urlencoded" };
const form = (o: Record<string, string>) => new URLSearchParams(o).toString();
const TOKEN = "A".repeat(43);
const COOKIE = { Cookie: `qm_session=${TOKEN}` };
const ADMIN_ID = "11111111-1111-4111-8111-111111111111";
const OTHER_ID = "22222222-2222-4222-8222-222222222222";

function userRow(over: Record<string, unknown> = {}): Record<string, unknown> {
  const now = Date.now();
  return {
    id: ADMIN_ID,
    email: "operator@example.com",
    email_verified: true,
    google_sub: null,
    username: "Operator",
    first_name: null,
    last_name: null,
    country_code: "AR",
    region_code: null,
    city_geonameid: null,
    city_name: null,
    city_lat: null,
    city_lon: null,
    terms_version: "2026-11-01",
    terms_accepted_at: new Date(now - 86_400_000),
    username_changed_at: null,
    must_rename: false,
    is_admin: true,
    blocked_at: null,
    approved_at: new Date(now - 86_400_000),
    approved_by: null,
    created_at: new Date("2026-01-02T00:00:00Z"),
    last_login_at: new Date(now),
    ...over,
  };
}

interface Scenario {
  viewer?: Record<string, unknown> | null;
  rateOk?: boolean;
  changed?: boolean;
}

function adminDb(s: Scenario = {}) {
  const viewer = s.viewer === null ? null : userRow(s.viewer);
  return fakeDb((st: Statement) => {
    const t = st.text;
    if (t.startsWith("select s.id as session_id")) {
      if (!viewer || st.values[0] !== sha256Hex(TOKEN)) return [];
      const now = Date.now();
      return [
        {
          session_id: sha256Hex(TOKEN),
          session_public_id: "00000000-0000-4000-8000-000000000001",
          session_created_at: new Date(now - 86_400_000),
          session_last_seen_at: new Date(now),
          session_expires_at: new Date(now + 20 * 86_400_000),
          session_absolute_expires_at: new Date(now + 170 * 86_400_000),
          via_previous: false,
          ...viewer,
        },
      ];
    }
    if (t.startsWith("select id, username, country_code, email, created_at, approved_at, blocked_at, is_admin from public.users")) {
      return [
        { id: OTHER_ID, username: "Newbie<b>", country_code: "FR", email: "new@example.com", created_at: new Date("2026-10-25T10:00:00Z"), approved_at: null, blocked_at: null, is_admin: false },
        { id: "33333333-3333-4333-8333-333333333333", username: null, country_code: null, email: "half@example.com", created_at: new Date("2026-10-25T11:00:00Z"), approved_at: null, blocked_at: null, is_admin: false },
        userRow(),
      ];
    }
    if (t.startsWith("select f.id, f.kind, f.created_at")) {
      return [{ id: "44444444-4444-4444-8444-444444444444", kind: "bug", created_at: new Date("2026-10-25T12:00:00Z"), lang: "es", context: "v0.12.0", message: "<script>alert(1)</script> broken", reply_email: "r@example.com", mailed_at: null, username: null }];
    }
    if (t.startsWith("insert into public.auth_rate_events")) return s.rateOk === false ? [] : [{ id: "1" }];
    if (t.startsWith("update public.users set")) return s.changed === false ? [] : [{ id: OTHER_ID }];
    if (t.startsWith("delete from public.sessions where user_id = $1::uuid returning id")) return [{ id: "s1" }, { id: "s2" }];
    return undefined;
  });
}

const post = (app: ReturnType<typeof createApp>, path: string, body: Record<string, string>, extra: Record<string, string> = {}) =>
  app.request(path, { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, ...COOKIE, ...extra }, body: form(body) });

test("/admin/* is a 404 for anonymous visitors, ordinary users and blocked admins (never a 403)", async () => {
  for (const viewer of [null, { is_admin: false }, { is_admin: true, blocked_at: new Date() }]) {
    const db = adminDb({ viewer });
    const app = createApp(testDeps({ db }));
    for (const path of ["/admin/users", "/admin/users?view=all", "/admin/feedback"]) {
      const r = await app.request(path, { headers: COOKIE });
      assert.equal(r.status, 404, `${path} ${JSON.stringify(viewer)}`);
      assert.match(await r.text(), /href="\/"/, "the ordinary 404 page");
    }
    const w = await post(app, "/admin/users/approve", { id: OTHER_ID });
    assert.equal(w.status, 404);
    assert.equal(db.writes().length, 0);
  }
});

test("GET /admin/users: the queue with per-row forms, everything escaped, English only, no self-block or self-revoke", async () => {
  const app = createApp(testDeps({ db: adminDb(), config: { accessMode: "approval" } }));
  const res = await app.request("/admin/users?view=pending&done=approve", { headers: COOKIE });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("cache-control"), "private, no-store");
  const body = await res.text();
  assert.match(body, /<h1>Accounts<\/h1>/);
  assert.match(body, /ACCESS_MODE=approval/);
  assert.match(body, /data-done="approve"/);
  assert.match(body, /@Newbie&lt;b&gt;/);
  assert.doesNotMatch(body, /Newbie<b>/);
  assert.match(body, /new@example\.com/, "the operator sees the email");
  assert.match(body, new RegExp(`<form method="post" action="/admin/users/approve"><input type="hidden" name="id" value="${OTHER_ID}"><input type="hidden" name="view" value="pending">`));
  assert.match(body, new RegExp(`action="/admin/users/block"><input type="hidden" name="id" value="${OTHER_ID}"`));
  assert.match(body, /\(no username yet\)/, "an unfinished registration is listed and can be approved early");
  const self = new RegExp(`<tr class="state-approved" data-user="${ADMIN_ID}">[\\s\\S]*?</tr>`).exec(body)![0];
  assert.doesNotMatch(self, /action="\/admin\/users\/(block|revoke)"/, "no button to lock yourself out");
  assert.match(self, /<span class="badge">admin<\/span>/);
  assert.doesNotMatch(body, /<script|\sstyle=|\son[a-z]+=/i);
  const all = await app.request("/admin/users?view=all", { headers: COOKIE });
  assert.match(await all.text(), /href="\/admin\/users\?view=all" aria-current="page"/);
});

test("POST /admin/users/<action>: validates id and action, spends the admin_write bucket, blocks also revoke sessions, 303 back", async () => {
  const db = adminDb();
  const app = createApp(testDeps({ db }));
  const ok = await post(app, "/admin/users/approve", { id: OTHER_ID, view: "pending" });
  assert.equal(ok.status, 303);
  assert.equal(ok.headers.get("location"), "/admin/users?view=pending&done=approve");
  assert.equal(ok.headers.get("cache-control"), "no-store");
  const upd = db.log.find((s) => s.text.startsWith("update public.users set approved_at = $2"));
  assert.ok(upd);
  assert.equal(upd.values[0], OTHER_ID);
  assert.equal(upd.values[2], ADMIN_ID, "approved_by is the admin");
  const limit = db.log.find((s) => s.text.startsWith("insert into public.auth_rate_events"));
  assert.deepEqual([limit?.values[0], limit?.values[1]], [ADMIN_WRITE_LIMIT.bucket, `user:${ADMIN_ID}`]);

  const block = await post(app, "/admin/users/block", { id: OTHER_ID, view: "all" });
  assert.equal(block.headers.get("location"), "/admin/users?view=all&done=block");
  assert.ok(db.log.some((s) => s.text.startsWith("update public.users set blocked_at = $3") && s.values[0] === OTHER_ID && s.values[1] === ADMIN_ID));
  assert.ok(db.log.some((s) => s.text.startsWith("delete from public.sessions where user_id = $1::uuid") && s.values[0] === OTHER_ID), "sessions revoked with the block");

  const before = db.writes().length;
  assert.equal((await post(app, "/admin/users/approve", { id: "not-a-uuid" })).headers.get("location"), "/admin/users?view=pending&done=none");
  assert.equal((await post(app, "/admin/users/promote", { id: OTHER_ID })).status, 404, "unknown action");
  assert.equal(db.writes().length, before, "nothing written");
  assert.equal((await app.request("/admin/users/approve", { method: "POST", headers: { ...FORM, ...COOKIE, Origin: "https://evil.example" }, body: form({ id: OTHER_ID }) })).status, 403);

  const unchanged = createApp(testDeps({ db: adminDb({ changed: false }) }));
  assert.equal((await post(unchanged, "/admin/users/revoke", { id: OTHER_ID })).headers.get("location"), "/admin/users?view=pending&done=none");
  const limited = createApp(testDeps({ db: adminDb({ rateOk: false }) }));
  assert.equal((await post(limited, "/admin/users/approve", { id: OTHER_ID })).status, 429);
});

test("GET /admin/feedback: the last rows, escaped, with the reply address as a mailto link", async () => {
  const app = createApp(testDeps({ db: adminDb() }));
  const res = await app.request("/admin/feedback", { headers: COOKIE });
  assert.equal(res.status, 200);
  const body = await res.text();
  assert.match(body, /<h1>Feedback<\/h1>/);
  assert.match(body, /&lt;script&gt;alert\(1\)&lt;\/script&gt; broken/);
  assert.doesNotMatch(body, /<script>alert/);
  assert.match(body, /<a href="mailto:r@example\.com">r@example\.com<\/a>/);
  assert.match(body, /not mailed/);
  assert.match(body, /anonymous/);
});

test("admin queries: list shape, state derivation, the self-protection in revoke and block", async () => {
  const db = adminDb();
  const users = await listUsers(db, "pending");
  assert.match(db.log[0]!.text, /where approved_at is null and blocked_at is null order by created_at asc limit \$1/);
  assert.deepEqual(users.map((u) => u.state), ["pending", "unfinished", "approved"]);
  assert.equal(users[0]!.approvedAt, null);
  await listUsers(db, "all");
  assert.match(db.log[1]!.text, /from public\.users order by created_at desc limit \$1/);
  assert.equal(parseView("all"), "all");
  assert.equal(parseView("<x>"), "pending");
  assert.equal(accountState({ username: "x", approvedAt: "2026-01-01T00:00:00.000Z", blockedAt: "2026-02-01T00:00:00.000Z" }), "blocked");

  const self = fakeDb(() => []);
  assert.equal(await applyAdminAction(self, "block", ADMIN_ID, ADMIN_ID, Date.now()), false);
  assert.match(self.log[0]!.text, /where id = \$1::uuid and id <> \$2::uuid and blocked_at is null/);
  assert.equal(await applyAdminAction(self, "revoke", ADMIN_ID, ADMIN_ID, Date.now()), false);
  assert.match(self.log[1]!.text, /id <> \$2::uuid and approved_at is not null/);
  await applyAdminAction(self, "unblock", OTHER_ID, ADMIN_ID, Date.now());
  assert.match(self.log[2]!.text, /set blocked_at = null where id = \$1::uuid and blocked_at is not null/);
});
