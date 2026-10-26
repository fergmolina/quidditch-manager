import type { AccessMode } from "../config.js";
import type { Db, TxDb } from "../db.js";
import { rowToUser, type User, type UserRow } from "./sessions.js";

export type { User, UserRow };

/** `created`: this call inserted the row (a fresh row has `xmax = 0`). */
export async function upsertUserByEmail(db: Db, input: { email: string }, nowMs = Date.now()): Promise<User & { created: boolean }> {
  const email = input.email.trim().toLowerCase();
  const now = new Date(nowMs).toISOString();
  const rows = await db.query<UserRow & { inserted?: boolean }>(
    `insert into public.users (email, email_verified, created_at, last_login_at)
     values ($1, true, $2::timestamptz, $2::timestamptz)
     on conflict (email) do update
       set last_login_at = excluded.last_login_at, email_verified = true
     returning *, (xmax = 0) as inserted`,
    [email, now],
  );
  const r = rows[0];
  if (!r) throw new Error("upsertUserByEmail: no row returned");
  return { ...rowToUser(r), created: r.inserted === true };
}

export async function getUserById(db: Db, id: string): Promise<User | null> {
  const rows = await db.query<UserRow>("select * from public.users where id = $1::uuid", [id]);
  return rows[0] ? rowToUser(rows[0]) : null;
}

export async function findUserByGoogleSub(db: Db, sub: string): Promise<User | null> {
  const rows = await db.query<UserRow>("select * from public.users where google_sub = $1", [sub]);
  return rows[0] ? rowToUser(rows[0]) : null;
}

export async function linkGoogle(db: Db, { sub, userId }: { sub: string; userId: string }): Promise<void> {
  await db.transaction(async (tx) => {
    await unlinkGoogleSubElsewhere(tx, sub, userId);
    await tx.query("update public.users set google_sub = $1 where id = $2::uuid", [sub, userId]);
  });
}

async function unlinkGoogleSubElsewhere(tx: TxDb, sub: string, keepUserId: string): Promise<void> {
  await tx.query("update public.users set google_sub = null where google_sub = $1 and id <> $2::uuid", [sub, keepUserId]);
}

export async function recordLogin(db: Db, userId: string, nowMs = Date.now()): Promise<User | null> {
  const rows = await db.query<UserRow>("update public.users set last_login_at = $2::timestamptz where id = $1::uuid returning *", [userId, new Date(nowMs).toISOString()]);
  return rows[0] ? rowToUser(rows[0]) : null;
}

export async function deleteUserAccount(db: Db, userId: string): Promise<boolean> {
  return db.transaction(async (tx) => {
    const rows = await tx.query<{ email: string }>("delete from public.users where id = $1::uuid returning email", [userId]);
    const email = rows[0]?.email;
    if (!email) return false;
    await tx.query("delete from public.login_tokens where email = $1", [email]);
    return true;
  });
}

/** `pending`: the profile is done but the operator has not approved the account yet (ACCESS_MODE=approval only). */
export type ProfileStatus = "complete" | "register" | "rename" | "terms" | "pending" | "blocked";

export function profileStatus(
  user: Pick<User, "username" | "countryCode" | "termsVersion" | "termsAcceptedAt" | "mustRename" | "blockedAt" | "approvedAt">,
  termsVersion: string,
  accessMode: AccessMode = "open",
): ProfileStatus {
  if (user.blockedAt) return "blocked";
  if (!user.username || !user.countryCode || !user.termsAcceptedAt) return "register";
  if (user.mustRename) return "rename";
  if (user.termsVersion !== termsVersion) return "terms";
  if (accessMode === "approval" && !user.approvedAt) return "pending";
  return "complete";
}

export function isProfileComplete(user: Parameters<typeof profileStatus>[0], termsVersion: string, accessMode: AccessMode = "open"): boolean {
  return profileStatus(user, termsVersion, accessMode) === "complete";
}
