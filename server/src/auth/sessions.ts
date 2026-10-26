import { toIso, toMs, type Db, type TxDb } from "../db.js";
import { randomToken, sha256Hex, TOKEN_RE } from "./tokens.js";

const DAY_MS = 86_400_000;
export const SESSION_TTL_MS = 30 * DAY_MS;
export const SESSION_ABSOLUTE_MS = 180 * DAY_MS;
export const RENEW_WHEN_LEFT_MS = 15 * DAY_MS;
export const ROTATION_GRACE_MS = 2 * 60_000;
export const LAST_SEEN_EVERY_MS = 10 * 60_000;

export interface UserRow {
  id: string;
  email: string;
  email_verified: boolean;
  google_sub: string | null;
  username: string | null;
  first_name: string | null;
  last_name: string | null;
  country_code: string | null;
  region_code: string | null;
  city_geonameid: number | null;
  city_name: string | null;
  city_lat: number | null;
  city_lon: number | null;
  terms_version: string | null;
  terms_accepted_at: string | Date | null;
  username_changed_at: string | Date | null;
  must_rename: boolean;
  is_admin: boolean;
  blocked_at: string | Date | null;
  approved_at: string | Date | null;
  approved_by: string | null;
  created_at: string | Date;
  last_login_at: string | Date | null;
}

export interface User {
  id: string;
  email: string;
  googleSub: string | null;
  username: string | null;
  firstName: string | null;
  lastName: string | null;
  countryCode: string | null;
  regionCode: string | null;
  city: { geonameid: number; name: string; lat: number; lon: number } | null;
  termsVersion: string | null;
  termsAcceptedAt: string | null;
  usernameChangedAt: string | null;
  mustRename: boolean;
  isAdmin: boolean;
  blockedAt: string | null;
  /** Null while the account waits for the operator (ACCESS_MODE=approval). */
  approvedAt: string | null;
  createdAt: string;
  lastLoginAt: string | null;
}

export function rowToUser(r: UserRow): User {
  return {
    id: r.id,
    email: r.email,
    googleSub: r.google_sub ?? null,
    username: r.username ?? null,
    firstName: r.first_name ?? null,
    lastName: r.last_name ?? null,
    countryCode: r.country_code ?? null,
    regionCode: r.region_code ?? null,
    city:
      r.city_geonameid !== null && r.city_geonameid !== undefined && r.city_name
        ? { geonameid: Number(r.city_geonameid), name: r.city_name, lat: Number(r.city_lat), lon: Number(r.city_lon) }
        : null,
    termsVersion: r.terms_version ?? null,
    termsAcceptedAt: toIso(r.terms_accepted_at),
    usernameChangedAt: toIso(r.username_changed_at),
    mustRename: !!r.must_rename,
    isAdmin: !!r.is_admin,
    blockedAt: toIso(r.blocked_at),
    approvedAt: toIso(r.approved_at),
    createdAt: toIso(r.created_at) ?? new Date(0).toISOString(),
    lastLoginAt: toIso(r.last_login_at),
  };
}

export interface SessionInfo {
  tokenHash: string;
  publicId: string;
  createdAt: string;
  lastSeenAt: string;
  expiresAt: string;
  absoluteExpiresAt: string;
  viaPrevious: boolean;
}

export interface SessionUser {
  session: SessionInfo;
  user: User;
}

interface SessionJoinRow extends UserRow {
  session_id: string;
  session_public_id: string;
  session_created_at: string | Date;
  session_last_seen_at: string | Date;
  session_expires_at: string | Date;
  session_absolute_expires_at: string | Date;
  via_previous: boolean;
}

export async function createSession(
  db: Db,
  userId: string,
  opts: { userAgentFamily?: string | null } = {},
  nowMs = Date.now(),
): Promise<{ token: string; expiresAt: string; publicId: string }> {
  const token = randomToken();
  const now = new Date(nowMs).toISOString();
  const expiresAt = new Date(nowMs + SESSION_TTL_MS).toISOString();
  const absolute = new Date(nowMs + SESSION_ABSOLUTE_MS).toISOString();
  const rows = await db.query<{ public_id: string }>(
    `insert into public.sessions (id, user_id, created_at, last_seen_at, expires_at, absolute_expires_at, user_agent_family)
     values ($1, $2::uuid, $3::timestamptz, $3::timestamptz, $4::timestamptz, $5::timestamptz, $6)
     returning public_id`,
    [sha256Hex(token), userId, now, expiresAt, absolute, opts.userAgentFamily?.slice(0, 64) ?? null],
  );
  return { token, expiresAt, publicId: rows[0]?.public_id ?? "" };
}

function currentOrRotationGraceToken(hashParam: string, nowParam: string): string {
  return `(s.id = ${hashParam} or (s.prev_id = ${hashParam} and s.prev_valid_until > ${nowParam}::timestamptz))`;
}

export async function validateSession(db: Db, token: string | null | undefined, nowMs = Date.now()): Promise<SessionUser | null> {
  if (!token || !TOKEN_RE.test(token)) return null;
  const rows = await db.query<SessionJoinRow>(
    `select s.id as session_id, s.public_id as session_public_id, s.created_at as session_created_at,
            s.last_seen_at as session_last_seen_at, s.expires_at as session_expires_at,
            s.absolute_expires_at as session_absolute_expires_at, (s.id <> $1) as via_previous, u.*
       from public.sessions s join public.users u on u.id = s.user_id
      where ${currentOrRotationGraceToken("$1", "$2")}
        and s.expires_at > $2::timestamptz and s.absolute_expires_at > $2::timestamptz
      limit 1`,
    [sha256Hex(token), new Date(nowMs).toISOString()],
  );
  const r = rows[0];
  if (!r) return null;
  return {
    session: {
      tokenHash: r.session_id,
      publicId: r.session_public_id,
      createdAt: toIso(r.session_created_at) ?? new Date(nowMs).toISOString(),
      lastSeenAt: toIso(r.session_last_seen_at) ?? new Date(nowMs).toISOString(),
      expiresAt: toIso(r.session_expires_at) ?? new Date(nowMs).toISOString(),
      absoluteExpiresAt: toIso(r.session_absolute_expires_at) ?? new Date(nowMs).toISOString(),
      viaPrevious: !!r.via_previous,
    },
    user: rowToUser(r),
  };
}

export function renewalDue(session: { expiresAt: string; absoluteExpiresAt: string }, nowMs = Date.now()): string | null {
  const expires = toMs(session.expiresAt) ?? 0;
  const absolute = toMs(session.absoluteExpiresAt) ?? 0;
  if (expires - nowMs >= RENEW_WHEN_LEFT_MS) return null;
  const next = Math.min(nowMs + SESSION_TTL_MS, absolute);
  return next > expires ? new Date(next).toISOString() : null;
}

export async function rotateSessionIfDue(db: Db, session: SessionInfo, nowMs = Date.now()): Promise<{ token: string; expiresAt: string } | null> {
  if (session.viaPrevious) return null;
  const next = renewalDue(session, nowMs);
  if (!next) return null;
  const token = randomToken();
  const rotated = await rotateIfStillCurrent(db, session.tokenHash, {
    hash: sha256Hex(token),
    graceUntil: new Date(nowMs + ROTATION_GRACE_MS).toISOString(),
    now: new Date(nowMs).toISOString(),
    expiresAt: next,
  });
  return rotated ? { token, expiresAt: next } : null;
}

async function rotateIfStillCurrent(db: Db, currentHash: string, next: { hash: string; graceUntil: string; now: string; expiresAt: string }): Promise<boolean> {
  const rows = await db.query<{ public_id: string }>(
    `update public.sessions
        set id = $2, prev_id = $1, prev_valid_until = $3::timestamptz, rotated_at = $4::timestamptz,
            expires_at = $5::timestamptz, last_seen_at = $4::timestamptz
      where id = $1
      returning public_id`,
    [currentHash, next.hash, next.graceUntil, next.now, next.expiresAt],
  );
  return rows.length > 0;
}

export async function touchSession(db: Db, session: SessionInfo, nowMs = Date.now()): Promise<void> {
  const last = toMs(session.lastSeenAt) ?? 0;
  if (nowMs - last < LAST_SEEN_EVERY_MS) return;
  await db.query("update public.sessions set last_seen_at = $2::timestamptz where id = $1", [session.tokenHash, new Date(nowMs).toISOString()]);
}

export async function deleteSession(db: Db, token: string | null | undefined): Promise<void> {
  if (!token || !TOKEN_RE.test(token)) return;
  const hash = sha256Hex(token);
  await db.query("delete from public.sessions where id = $1 or prev_id = $1", [hash]);
}

export async function deleteUserSessions(db: TxDb, userId: string): Promise<number> {
  const rows = await db.query<{ id: string }>("delete from public.sessions where user_id = $1::uuid returning id", [userId]);
  return rows.length;
}

export interface SessionListItem {
  publicId: string;
  createdAt: string;
  lastSeenAt: string;
  expiresAt: string;
  userAgentFamily: string | null;
  current: boolean;
}

export async function listSessions(db: Db, userId: string, currentPublicId: string | null, nowMs = Date.now()): Promise<SessionListItem[]> {
  const rows = await db.query<{
    public_id: string;
    created_at: string | Date;
    last_seen_at: string | Date;
    expires_at: string | Date;
    user_agent_family: string | null;
  }>(
    `select public_id, created_at, last_seen_at, expires_at, user_agent_family
       from public.sessions
      where user_id = $1::uuid and expires_at > $2::timestamptz and absolute_expires_at > $2::timestamptz
      order by last_seen_at desc, created_at desc`,
    [userId, new Date(nowMs).toISOString()],
  );
  return rows.map((r) => ({
    publicId: r.public_id,
    createdAt: toIso(r.created_at) ?? "",
    lastSeenAt: toIso(r.last_seen_at) ?? "",
    expiresAt: toIso(r.expires_at) ?? "",
    userAgentFamily: r.user_agent_family,
    current: r.public_id === currentPublicId,
  }));
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function revokeSession(db: Db, userId: string, publicId: string): Promise<boolean> {
  if (!UUID_RE.test(publicId)) return false;
  const rows = await db.query<{ id: string }>("delete from public.sessions where user_id = $1::uuid and public_id = $2::uuid returning id", [userId, publicId]);
  return rows.length > 0;
}
