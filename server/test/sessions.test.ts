import assert from "node:assert/strict";
import { test } from "node:test";
import {
  createSession,
  deleteSession,
  LAST_SEEN_EVERY_MS,
  renewalDue,
  RENEW_WHEN_LEFT_MS,
  revokeSession,
  rotateSessionIfDue,
  ROTATION_GRACE_MS,
  SESSION_ABSOLUTE_MS,
  SESSION_TTL_MS,
  touchSession,
  validateSession,
  type SessionInfo,
} from "../src/auth/sessions.js";
import { profileStatus } from "../src/auth/users.js";
import { sha256Hex } from "../src/auth/tokens.js";
import { fakeDb } from "./helpers.js";

const DAY = 86_400_000;
const NOW = Date.UTC(2026, 9, 21, 12);
const iso = (ms: number) => new Date(ms).toISOString();

function session(over: Partial<SessionInfo> = {}): SessionInfo {
  return {
    tokenHash: "a".repeat(64),
    publicId: "00000000-0000-4000-8000-000000000001",
    createdAt: iso(NOW - 20 * DAY),
    lastSeenAt: iso(NOW - DAY),
    expiresAt: iso(NOW + 10 * DAY),
    absoluteExpiresAt: iso(NOW + 160 * DAY),
    viaPrevious: false,
    ...over,
  };
}

test("constants: 30-day sliding, 180-day absolute, renew under 15 days", () => {
  assert.equal(SESSION_TTL_MS, 30 * DAY);
  assert.equal(SESSION_ABSOLUTE_MS, 180 * DAY);
  assert.equal(RENEW_WHEN_LEFT_MS, 15 * DAY);
});

test("renewalDue: sliding renewal below 15 days, capped by the absolute expiry", () => {
  const s = (expires: number, absolute = NOW + 100 * DAY) => ({ expiresAt: iso(expires), absoluteExpiresAt: iso(absolute) });
  assert.equal(renewalDue(s(NOW + 16 * DAY), NOW), null, "16 days left: untouched");
  assert.equal(renewalDue(s(NOW + RENEW_WHEN_LEFT_MS), NOW), null, "exactly 15 days: untouched");
  assert.equal(renewalDue(s(NOW + RENEW_WHEN_LEFT_MS - 1), NOW), iso(NOW + SESSION_TTL_MS), "just under: now + 30 d");
  assert.equal(renewalDue(s(NOW + DAY, NOW + 10 * DAY), NOW), iso(NOW + 10 * DAY), "capped at the absolute expiry");
  assert.equal(renewalDue(s(NOW + DAY, NOW + DAY), NOW), null, "nothing left to extend");
});

test("createSession: stores only the sha256 of the token, 30 d sliding + 180 d absolute, UA family", async () => {
  const db = fakeDb((s) => (s.text.startsWith("insert into public.sessions") ? [{ public_id: "p-1" }] : undefined));
  const s = await createSession(db, "u-1", { userAgentFamily: "Firefox · Linux" }, NOW);
  assert.match(s.token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(s.expiresAt, iso(NOW + SESSION_TTL_MS));
  assert.equal(s.publicId, "p-1");
  const [id, uid, created, expires, absolute, ua] = db.log[0]!.values as string[];
  assert.equal(id, sha256Hex(s.token));
  assert.ok(!JSON.stringify(db.log).includes(s.token), "the raw token never reaches the database");
  assert.equal(uid, "u-1");
  assert.equal(created, iso(NOW));
  assert.equal(expires, iso(NOW + SESSION_TTL_MS));
  assert.equal(absolute, iso(NOW + SESSION_ABSOLUTE_MS));
  assert.equal(ua, "Firefox · Linux");
});

test("validateSession: malformed tokens never touch the database; one query checks both expiries and the grace token", async () => {
  const db = fakeDb(() => []);
  for (const bad of ["", "short", "x".repeat(44), "a".repeat(42) + "!", null, undefined]) assert.equal(await validateSession(db, bad as string, NOW), null);
  assert.equal(db.log.length, 0);
  const token = "A".repeat(43);
  assert.equal(await validateSession(db, token, NOW), null);
  const q = db.log[0]!;
  assert.match(q.text, /s\.id = \$1 or \(s\.prev_id = \$1 and s\.prev_valid_until > \$2::timestamptz\)/);
  assert.match(q.text, /s\.expires_at > \$2::timestamptz and s\.absolute_expires_at > \$2::timestamptz/);
  assert.deepEqual(q.values, [sha256Hex(token), iso(NOW)]);
});

test("rotateSessionIfDue: new token for the same row, old one valid for the grace period only", async () => {
  const db = fakeDb((s) => (s.text.startsWith("update public.sessions set id = $2") ? [{ public_id: "p" }] : undefined));
  assert.equal(await rotateSessionIfDue(db, session({ expiresAt: iso(NOW + 20 * DAY) }), NOW), null, "not due");
  assert.equal(await rotateSessionIfDue(db, session({ viaPrevious: true }), NOW), null, "request used the replaced token");
  assert.equal(db.log.length, 0);
  const r = await rotateSessionIfDue(db, session(), NOW);
  assert.ok(r);
  assert.match(r.token, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(r.expiresAt, iso(NOW + SESSION_TTL_MS));
  const [oldId, newId, grace, rotatedAt, expires] = db.log[0]!.values as string[];
  assert.equal(oldId, "a".repeat(64));
  assert.equal(newId, sha256Hex(r.token));
  assert.equal(grace, iso(NOW + ROTATION_GRACE_MS));
  assert.equal(rotatedAt, iso(NOW));
  assert.equal(expires, iso(NOW + SESSION_TTL_MS));
  assert.match(db.log[0]!.text, /where id = \$1/, "matches the current id: a concurrent rotation cannot also win");
  assert.doesNotMatch(db.log[0]!.text, /absolute_expires_at|created_at/, "rotation keeps the absolute cap and creation time");
});

test("rotateSessionIfDue: lost race → null (no cookie set)", async () => {
  const db = fakeDb(() => []);
  assert.equal(await rotateSessionIfDue(db, session(), NOW), null);
});

test("touchSession: writes last_seen_at at most every 10 minutes", async () => {
  const db = fakeDb(() => []);
  await touchSession(db, session({ lastSeenAt: iso(NOW - LAST_SEEN_EVERY_MS + 1000) }), NOW);
  assert.equal(db.log.length, 0);
  await touchSession(db, session({ lastSeenAt: iso(NOW - LAST_SEEN_EVERY_MS) }), NOW);
  assert.equal(db.log.length, 1);
  assert.deepEqual(db.log[0]!.values, ["a".repeat(64), iso(NOW)]);
});

test("deleteSession matches current or replaced token; revokeSession is scoped to the user and a UUID", async () => {
  const db = fakeDb(() => [{ id: "x" }]);
  await deleteSession(db, "B".repeat(43));
  assert.match(db.log[0]!.text, /where id = \$1 or prev_id = \$1/);
  await deleteSession(db, "bad token");
  assert.equal(db.log.length, 1);
  assert.equal(await revokeSession(db, "u-1", "not-a-uuid"), false);
  assert.equal(await revokeSession(db, "u-1", "00000000-0000-4000-8000-000000000001"), true);
  assert.match(db.log[1]!.text, /where user_id = \$1::uuid and public_id = \$2::uuid/);
});

test("profileStatus: complete needs username, country and the current terms; names and city never matter", () => {
  const base = { username: "HarryFan", countryCode: "AR", termsVersion: "v1", termsAcceptedAt: iso(NOW), mustRename: false, blockedAt: null };
  assert.equal(profileStatus(base, "v1"), "complete");
  assert.equal(profileStatus({ ...base, username: null }, "v1"), "register");
  assert.equal(profileStatus({ ...base, countryCode: null }, "v1"), "register");
  assert.equal(profileStatus({ ...base, termsAcceptedAt: null, termsVersion: null }, "v1"), "register");
  assert.equal(profileStatus({ ...base, mustRename: true }, "v1"), "rename");
  assert.equal(profileStatus(base, "v2"), "terms");
  assert.equal(profileStatus({ ...base, blockedAt: iso(NOW) }, "v1"), "blocked");
});
