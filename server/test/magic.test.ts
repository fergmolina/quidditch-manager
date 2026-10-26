import assert from "node:assert/strict";
import { test } from "node:test";
import { consumeMagicLink, discardMagicLink, MAGIC_LIMITS, MAGIC_TTL_MS, magicLinkUrl, peekMagicLink, requestMagicLink } from "../src/auth/magic.js";
import { BurstLimiter, hitRateLimit } from "../src/auth/rate-limit.js";
import { sha256Hex, TOKEN_RE } from "../src/auth/tokens.js";
import { fakeDb, type Statement } from "./helpers.js";

const NOW = Date.UTC(2026, 9, 21, 12);
const iso = (ms: number) => new Date(ms).toISOString();

function tokensDb(opts: { dailyTotal?: number } = {}) {
  const rows = new Map<string, { id: string; email: string; next_path: string | null; lang: string; ip_hash: string | null; expires_at: string; created_at: string; consumed: boolean }>();
  let n = 0;
  const db = fakeDb((s: Statement) => {
    const v = s.values;
    if (s.text.startsWith("with usage as")) {
      const [email, hash, next, lang, ip, expires, since, perEmail, sinceDay, perEmailDay, now, perIp, cap] = v as [string, string, string | null, string, string | null, string, string, number, string, number, string, number, number | null];
      const all = [...rows.values()];
      const c = (f: (r: (typeof all)[number]) => boolean) => all.filter(f).length;
      const mailCapped = cap !== null && c((r) => r.created_at > sinceDay) + (opts.dailyTotal ?? 0) >= cap;
      const ok =
        c((r) => r.email === email && r.created_at > since) < perEmail &&
        c((r) => r.email === email && r.created_at > sinceDay) < perEmailDay &&
        (ip === null || c((r) => r.ip_hash === ip && r.created_at > since) < perIp) &&
        !mailCapped;
      if (!ok) return [{ id: null, mail_capped: mailCapped }];
      const id = `id-${++n}`;
      rows.set(hash, { id, email, next_path: next, lang, ip_hash: ip, expires_at: expires, created_at: now, consumed: false });
      return [{ id, mail_capped: false }];
    }
    if (s.text.startsWith("delete from public.login_tokens where id = $1::uuid")) {
      for (const [h, r] of rows) if (r.id === v[0] && !r.consumed) rows.delete(h);
      return [];
    }
    const [hash, nowIso] = v as [string, string];
    const r = rows.get(hash);
    const live = !!r && !r.consumed && r.expires_at > nowIso;
    if (s.text.startsWith("select 1 as ok from public.login_tokens")) return live ? [{ ok: 1 }] : [];
    if (s.text.startsWith("update public.login_tokens set consumed_at")) {
      if (!live || !r) return [];
      r.consumed = true;
      return [{ email: r.email, next_path: r.next_path, lang: r.lang, expires_at: r.expires_at }];
    }
    return undefined;
  });
  return { db, rows };
}

const req = (over: Partial<Parameters<typeof requestMagicLink>[1]> = {}) => ({ email: "a@example.com", ipHash: "ip-1", nextPath: "/play/", lang: "es" as const, dailyCap: 90, ...over });

test("requestMagicLink: ONE statement counts every limit, inserts, and reports the cap; stores only the hash", async () => {
  const { db } = tokensDb();
  const r = await requestMagicLink(db, req(), NOW);
  assert.ok(r.ok);
  assert.match(r.token, TOKEN_RE);
  assert.equal(r.expiresAt, iso(NOW + MAGIC_TTL_MS));
  assert.equal(db.log.length, 1);
  const s = db.log[0]!;
  assert.match(s.text, /^with usage as \( select .* \), inserted as \( insert into public\.login_tokens .* returning id \) select inserted\.id, .* from usage left join inserted on true$/);
  assert.equal((s.text.match(/select count\(\*\)/g) ?? []).length, 4, "per-email 15 min, per-email 24 h, per-IP, global");
  assert.equal(s.values[1], sha256Hex(r.token));
  assert.ok(!JSON.stringify(s.values).includes(r.token));
  assert.equal(s.values[4], "ip-1", "the keyed IP hash, never a raw IP");
  assert.equal(s.values[3], "es");
});

test("per-email: 3 per 15 minutes, 6 per 24 hours", async () => {
  const { db } = tokensDb();
  for (let i = 0; i < MAGIC_LIMITS.perEmail; i++) assert.ok((await requestMagicLink(db, req({ ipHash: `ip-${i}` }), NOW + i)).ok);
  const fourth = await requestMagicLink(db, req({ ipHash: "ip-x" }), NOW + 10);
  assert.deepEqual(fourth, { ok: false, error: "rate_limited" });
  const later = NOW + MAGIC_LIMITS.windowMs + 1000;
  for (let i = 0; i < 3; i++) assert.ok((await requestMagicLink(db, req({ ipHash: `ip-l${i}` }), later + i)).ok);
  const seventh = await requestMagicLink(db, req({ ipHash: "ip-y" }), later + MAGIC_LIMITS.windowMs + 1000);
  assert.deepEqual(seventh, { ok: false, error: "rate_limited" }, "6 per address per day caps email bombing");
});

test("per-IP bucket: 10 per 15 minutes across addresses", async () => {
  const { db } = tokensDb();
  for (let i = 0; i < MAGIC_LIMITS.perIp; i++) assert.ok((await requestMagicLink(db, req({ email: `u${i}@example.com` }), NOW + i)).ok);
  assert.deepEqual(await requestMagicLink(db, req({ email: "z@example.com" }), NOW + 20), { ok: false, error: "rate_limited" });
});

test("global daily cap answers mail_cap from the same statement; a null cap disables it", async () => {
  const { db } = tokensDb({ dailyTotal: 90 });
  assert.deepEqual(await requestMagicLink(db, req(), NOW), { ok: false, error: "mail_cap" });
  assert.equal(db.log.length, 1, "no second query to tell mail_cap from rate_limited");
  const { db: db2 } = tokensDb({ dailyTotal: 1000 });
  assert.ok((await requestMagicLink(db2, req({ dailyCap: null }), NOW)).ok);
});

test("a failed send is discarded and does not count against the address", async () => {
  const { db, rows } = tokensDb();
  for (let i = 0; i < 5; i++) {
    const r = await requestMagicLink(db, req(), NOW + i);
    assert.ok(r.ok, `attempt ${i}`);
    await discardMagicLink(db, r.id);
  }
  assert.equal(rows.size, 0);
});

test("peek is read-only; consume works once; malformed tokens never hit the database", async () => {
  const { db } = tokensDb();
  const r = await requestMagicLink(db, req({ nextPath: "/account" }), NOW);
  assert.ok(r.ok);
  const before = db.writes().length;
  assert.equal(await peekMagicLink(db, r.token, NOW + 1000), true);
  assert.equal(await peekMagicLink(db, r.token, NOW + 2000), true, "peeking twice is fine: a mail scanner cannot burn the link");
  assert.equal(db.writes().length, before);
  assert.deepEqual(await consumeMagicLink(db, r.token, NOW + 3000), { email: "a@example.com", nextPath: "/account", lang: "es" });
  assert.equal(await consumeMagicLink(db, r.token, NOW + 4000), null, "single use");
  assert.equal(await peekMagicLink(db, r.token, NOW + 5000), false);
  const n = db.log.length;
  for (const bad of ["", "x", "a".repeat(44), "<script>", "a".repeat(42) + "/"]) {
    assert.equal(await peekMagicLink(db, bad, NOW), false);
    assert.equal(await consumeMagicLink(db, bad, NOW), null);
  }
  assert.equal(db.log.length, n);
});

test("expired links are refused", async () => {
  const { db } = tokensDb();
  const r = await requestMagicLink(db, req(), NOW);
  assert.ok(r.ok);
  assert.equal(await peekMagicLink(db, r.token, NOW + MAGIC_TTL_MS + 1), false);
  assert.equal(await consumeMagicLink(db, r.token, NOW + MAGIC_TTL_MS + 1), null);
});

test("magicLinkUrl points at the verify landing page", () => {
  assert.equal(magicLinkUrl("https://qm.example.org", "abc_-"), "https://qm.example.org/auth/magic/verify?token=abc_-");
});

test("hitRateLimit: one insert…select statement; limits below 1 and windows over 24 h refused", async () => {
  let count = 0;
  const db = fakeDb((s) => {
    if (!s.text.startsWith("insert into public.auth_rate_events")) return undefined;
    if (count >= (s.values[4] as number)) return [];
    count++;
    return [{ id: String(count) }];
  });
  const input = { bucket: "magic_verify", subject: "k", limit: 2, windowMs: 60_000 };
  assert.equal(await hitRateLimit(db, input, NOW), true);
  assert.equal(await hitRateLimit(db, input, NOW), true);
  assert.equal(await hitRateLimit(db, input, NOW), false);
  assert.equal(db.log.length, 3);
  assert.equal(db.log[0]!.values[3], iso(NOW - 60_000));
  await assert.rejects(hitRateLimit(db, { ...input, limit: 0 }, NOW), RangeError);
  assert.equal(db.log.length, 3);
  await assert.rejects(hitRateLimit(db, { ...input, windowMs: 2 * 86_400_000 }, NOW), RangeError);
});

test("BurstLimiter: sliding window, retryAfter, LRU eviction, limits below 1 refused", () => {
  let t = 0;
  const l = new BurstLimiter({ limit: 2, windowMs: 1000, maxSubjects: 2, now: () => t });
  assert.equal(l.take("a").allowed, true);
  assert.equal(l.take("a").allowed, true);
  const d = l.take("a");
  assert.equal(d.allowed, false);
  assert.equal(d.retryAfter, 1);
  t = 1001;
  assert.equal(l.take("a").allowed, true);
  l.take("b");
  l.take("c");
  assert.equal(l.size, 2);
  assert.throws(() => new BurstLimiter({ limit: 0 }), RangeError);
});
