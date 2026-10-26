/**
 * The operator's queries behind /admin/*: the list of accounts (waiting or all), approve / revoke / block / unblock,
 * and the last feedback rows. Who may call them is decided by the route (`is_admin`, set by SQL only); nothing here
 * logs an email or a message body.
 */
import { toIso, type Db, type TxDb } from "../db.js";
import type { FeedbackKind } from "../feedback/feedback.js";

export const ADMIN_VIEWS = ["pending", "all"] as const;
export type AdminView = (typeof ADMIN_VIEWS)[number];

export function parseView(raw: string | null | undefined): AdminView {
  return raw === "all" ? "all" : "pending";
}

export const ADMIN_LIST_MAX = 500;
export const ADMIN_FEEDBACK_MAX = 50;

export type AccountState = "blocked" | "pending" | "approved" | "unfinished";

export interface AdminUser {
  id: string;
  username: string | null;
  countryCode: string | null;
  email: string;
  createdAt: string;
  approvedAt: string | null;
  blockedAt: string | null;
  isAdmin: boolean;
  /** `unfinished`: still on /register (no username yet); approving it early is harmless and remembered. */
  state: AccountState;
}

interface AdminUserRow {
  id: string;
  username: string | null;
  country_code: string | null;
  email: string;
  created_at: string | Date;
  approved_at: string | Date | null;
  blocked_at: string | Date | null;
  is_admin: boolean;
}

export function accountState(u: { username: string | null; approvedAt: string | null; blockedAt: string | null }): AccountState {
  if (u.blockedAt) return "blocked";
  if (!u.username) return "unfinished";
  return u.approvedAt ? "approved" : "pending";
}

function toAdminUser(r: AdminUserRow): AdminUser {
  const base = {
    id: r.id,
    username: r.username ?? null,
    countryCode: r.country_code ?? null,
    email: r.email,
    createdAt: toIso(r.created_at) ?? "",
    approvedAt: toIso(r.approved_at),
    blockedAt: toIso(r.blocked_at),
    isAdmin: !!r.is_admin,
  };
  return { ...base, state: accountState(base) };
}

/** `pending`: not approved and not blocked, oldest first (the queue). `all`: newest first. */
export async function listUsers(db: Db, view: AdminView): Promise<AdminUser[]> {
  const where = view === "pending" ? "where approved_at is null and blocked_at is null" : "";
  const order = view === "pending" ? "created_at asc" : "created_at desc";
  const rows = await db.query<AdminUserRow>(
    `select id, username, country_code, email, created_at, approved_at, blocked_at, is_admin
       from public.users ${where} order by ${order} limit $1`,
    [ADMIN_LIST_MAX],
  );
  return rows.map(toAdminUser);
}

export const ADMIN_ACTIONS = ["approve", "revoke", "block", "unblock"] as const;
export type AdminAction = (typeof ADMIN_ACTIONS)[number];

export function isAdminAction(v: unknown): v is AdminAction {
  return typeof v === "string" && (ADMIN_ACTIONS as readonly string[]).includes(v);
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(v: unknown): v is string {
  return typeof v === "string" && UUID_RE.test(v);
}

/**
 * One moderation write. Revoking an approval or blocking never applies to the admin's own account (that is the
 * fastest way to lock the only operator out). Returns false when no row changed.
 */
export async function applyAdminAction(db: TxDb, action: AdminAction, userId: string, adminId: string, nowMs: number): Promise<boolean> {
  const now = new Date(nowMs).toISOString();
  const rows = await (() => {
    switch (action) {
      case "approve":
        return db.query<{ id: string }>(
          "update public.users set approved_at = $2::timestamptz, approved_by = $3::uuid where id = $1::uuid and approved_at is null returning id",
          [userId, now, adminId],
        );
      case "revoke":
        return db.query<{ id: string }>("update public.users set approved_at = null, approved_by = null where id = $1::uuid and id <> $2::uuid and approved_at is not null returning id", [userId, adminId]);
      case "block":
        return db.query<{ id: string }>("update public.users set blocked_at = $3::timestamptz where id = $1::uuid and id <> $2::uuid and blocked_at is null returning id", [userId, adminId, now]);
      case "unblock":
        return db.query<{ id: string }>("update public.users set blocked_at = null where id = $1::uuid and blocked_at is not null returning id", [userId]);
    }
  })();
  return rows.length > 0;
}

export interface AdminFeedback {
  id: string;
  kind: FeedbackKind;
  createdAt: string;
  lang: string;
  context: string | null;
  message: string;
  replyEmail: string | null;
  username: string | null;
  mailed: boolean;
}

export async function listFeedback(db: Db): Promise<AdminFeedback[]> {
  const rows = await db.query<{
    id: string;
    kind: FeedbackKind;
    created_at: string | Date;
    lang: string;
    context: string | null;
    message: string;
    reply_email: string | null;
    username: string | null;
    mailed_at: string | Date | null;
  }>(
    `select f.id, f.kind, f.created_at, f.lang, f.context, f.message, f.reply_email, f.mailed_at, u.username
       from public.feedback f left join public.users u on u.id = f.user_id
      order by f.created_at desc limit $1`,
    [ADMIN_FEEDBACK_MAX],
  );
  return rows.map((r) => ({
    id: r.id,
    kind: r.kind,
    createdAt: toIso(r.created_at) ?? "",
    lang: r.lang,
    context: r.context,
    message: r.message,
    replyEmail: r.reply_email,
    username: r.username ?? null,
    mailed: r.mailed_at !== null,
  }));
}
