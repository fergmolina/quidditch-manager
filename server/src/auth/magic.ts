import { toMs, type Db } from "../db.js";
import type { Lang } from "../i18n/i18n.js";
import { randomToken, sha256Hex, TOKEN_RE } from "./tokens.js";

export const MAGIC_TTL_MS = 15 * 60_000;
export const MAGIC_LIMITS = {
  perEmail: 3,
  perIp: 10,
  windowMs: 15 * 60_000,
  perEmailDay: 6,
  dayMs: 24 * 3_600_000,
} as const;

export interface MagicRequest {
  email: string;
  ipHash: string | null;
  nextPath: string | null;
  lang: Lang;
  dailyCap: number | null;
}

export type MagicRequestResult =
  | { ok: true; id: string; token: string; expiresAt: string }
  | { ok: false; error: "rate_limited" | "mail_cap" };

export async function requestMagicLink(db: Db, req: MagicRequest, nowMs = Date.now()): Promise<MagicRequestResult> {
  const since = new Date(nowMs - MAGIC_LIMITS.windowMs).toISOString();
  const sinceDay = new Date(nowMs - MAGIC_LIMITS.dayMs).toISOString();
  const token = randomToken();
  const expiresAt = new Date(nowMs + MAGIC_TTL_MS).toISOString();
  const rows = await db.query<{ id: string | null; mail_capped: boolean }>(
    `with usage as (
       select (select count(*) from public.login_tokens where email = $1 and created_at > $7::timestamptz) as per_email,
              (select count(*) from public.login_tokens where email = $1 and created_at > $9::timestamptz) as per_email_day,
              (select count(*) from public.login_tokens where ip_hash = $5 and created_at > $7::timestamptz) as per_ip,
              (select count(*) from public.login_tokens where created_at > $9::timestamptz) as total
     ), inserted as (
       insert into public.login_tokens (email, token_hash, next_path, lang, ip_hash, expires_at, created_at)
       select $1, $2, $3, $4, $5, $6::timestamptz, $11::timestamptz from usage
        where per_email < $8 and per_email_day < $10 and ($5::text is null or per_ip < $12) and ($13::int is null or total < $13::int)
       returning id
     )
     select inserted.id, ($13::int is not null and usage.total >= $13::int) as mail_capped
       from usage left join inserted on true`,
    [
      req.email,
      sha256Hex(token),
      req.nextPath,
      req.lang,
      req.ipHash,
      expiresAt,
      since,
      MAGIC_LIMITS.perEmail,
      sinceDay,
      MAGIC_LIMITS.perEmailDay,
      new Date(nowMs).toISOString(),
      MAGIC_LIMITS.perIp,
      req.dailyCap,
    ],
  );
  const r = rows[0];
  if (r?.id) return { ok: true, id: r.id, token, expiresAt };
  return { ok: false, error: r?.mail_capped ? "mail_cap" : "rate_limited" };
}

export async function discardMagicLink(db: Db, id: string): Promise<void> {
  await db.query("delete from public.login_tokens where id = $1::uuid and consumed_at is null", [id]);
}

export function magicLinkUrl(siteUrl: string, token: string): string {
  return `${siteUrl}/auth/magic/verify?token=${encodeURIComponent(token)}`;
}

export async function peekMagicLink(db: Db, token: string, nowMs = Date.now()): Promise<boolean> {
  if (!TOKEN_RE.test(token)) return false;
  const rows = await db.query<{ ok: number }>(
    "select 1 as ok from public.login_tokens where token_hash = $1 and consumed_at is null and expires_at > $2::timestamptz",
    [sha256Hex(token), new Date(nowMs).toISOString()],
  );
  return rows.length > 0;
}

export interface ConsumedLink {
  email: string;
  nextPath: string | null;
  lang: string;
}

export async function consumeMagicLink(db: Db, token: string, nowMs = Date.now()): Promise<ConsumedLink | null> {
  if (!TOKEN_RE.test(token)) return null;
  const rows = await db.query<{ email: string; next_path: string | null; lang: string; expires_at: string | Date }>(
    `update public.login_tokens set consumed_at = $2::timestamptz
      where token_hash = $1 and consumed_at is null and expires_at > $2::timestamptz
      returning email, next_path, lang, expires_at`,
    [sha256Hex(token), new Date(nowMs).toISOString()],
  );
  const r = rows[0];
  if (!r || (toMs(r.expires_at) ?? 0) <= nowMs) return null;
  return { email: r.email, nextPath: r.next_path, lang: r.lang };
}
