import { codePoints } from "../text.js";

export const NAME_MAX = 50;

const ALLOWED_RE = /^[\p{L}\p{M} '’.\-·・]+$/u;
const INVISIBLE_RE = /\p{C}/u;
const LETTER_RE = /\p{L}/u;

export type NameCheck = { ok: true; value: string | null } | { ok: false; error: "name_invalid" | "name_too_long" };

export function checkName(raw: unknown): NameCheck {
  if (raw === undefined || raw === null) return { ok: true, value: null };
  if (typeof raw !== "string") return { ok: false, error: "name_invalid" };
  const nfc = raw.normalize("NFC");
  // \p{C} first: `\s` also matches U+FEFF (a format character) and tabs/newlines, which must not pass as spaces.
  if (INVISIBLE_RE.test(nfc)) return { ok: false, error: "name_invalid" };
  const value = nfc.replace(/\s+/gu, " ").trim();
  if (!value) return { ok: true, value: null };
  if (codePoints(value) > NAME_MAX) return { ok: false, error: "name_too_long" };
  if (!ALLOWED_RE.test(value) || !LETTER_RE.test(value)) return { ok: false, error: "name_invalid" };
  return { ok: true, value };
}
