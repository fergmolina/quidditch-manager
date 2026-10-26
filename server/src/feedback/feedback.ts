import { emailSchema } from "../auth/schemas.js";
import type { Db } from "../db.js";
import type { Lang } from "../i18n/i18n.js";
import { codePoints } from "../text.js";

export const FEEDBACK_KINDS = ["bug", "idea"] as const;
export type FeedbackKind = (typeof FEEDBACK_KINDS)[number];
export const MESSAGE_MIN = 10;
export const MESSAGE_MAX = 4000;
export const CONTEXT_MAX = 200;

export interface FeedbackValues {
  kind: FeedbackKind;
  message: string;
  email: string;
  context: string;
}

export interface FeedbackErrors {
  message?: "message_short" | "message_long";
  email?: "email_invalid";
}

export interface Feedback {
  kind: FeedbackKind;
  message: string;
  replyEmail: string | null;
  context: string | null;
  lang: Lang;
  userId: string | null;
}

export function parseKind(raw: string | null | undefined): FeedbackKind {
  return raw === "idea" ? "idea" : "bug";
}

const clean = (s: string | undefined): string => (s ?? "").replace(/\r\n?/g, "\n").replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, "").trim();

export function formValues(form: Record<string, string>): FeedbackValues {
  return {
    kind: parseKind(form.kind),
    message: clean(form.message).slice(0, MESSAGE_MAX * 4),
    email: (form.email ?? "").trim().slice(0, 254),
    context: clean(form.context).replace(/\s+/g, " ").slice(0, CONTEXT_MAX),
  };
}

export type ParsedFeedback = { ok: true; value: Feedback } | { ok: false; errors: FeedbackErrors };

export function parseFeedback(v: FeedbackValues, lang: Lang, userId: string | null): ParsedFeedback {
  const errors: FeedbackErrors = {};
  const n = codePoints(v.message);
  if (n < MESSAGE_MIN) errors.message = "message_short";
  else if (n > MESSAGE_MAX) errors.message = "message_long";
  let replyEmail: string | null = null;
  if (v.email !== "") {
    const parsed = emailSchema.safeParse(v.email);
    if (parsed.success) replyEmail = parsed.data;
    else errors.email = "email_invalid";
  }
  if (errors.message || errors.email) return { ok: false, errors };
  return { ok: true, value: { kind: v.kind, message: v.message, replyEmail, context: v.context || null, lang, userId } };
}

export async function insertFeedback(db: Db, f: Feedback, nowMs: number): Promise<string> {
  const rows = await db.query<{ id: string }>(
    `insert into public.feedback (user_id, kind, message, reply_email, context, lang, created_at)
     values ($1::uuid, $2, $3, $4, $5, $6, $7::timestamptz) returning id`,
    [f.userId, f.kind, f.message, f.replyEmail, f.context, f.lang, new Date(nowMs).toISOString()],
  );
  const id = rows[0]?.id;
  if (!id) throw new Error("feedback insert returned no row");
  return id;
}

export async function markFeedbackMailed(db: Db, id: string, nowMs: number): Promise<void> {
  await db.query("update public.feedback set mailed_at = $2::timestamptz where id = $1::uuid", [id, new Date(nowMs).toISOString()]);
}

export async function exportFeedback(db: Db, userId: string): Promise<Record<string, unknown>[]> {
  const rows = await db.query<Record<string, unknown>>(
    `select kind, message, reply_email, context, lang, created_at
       from public.feedback where user_id = $1::uuid order by created_at`,
    [userId],
  );
  return rows.map((r) => Object.fromEntries(Object.entries(r).map(([k, v]) => [k, v instanceof Date ? v.toISOString() : v])));
}
