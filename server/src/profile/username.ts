export const USERNAME_RE = /^[A-Za-z][A-Za-z0-9_]{2,19}$/;
export const USERNAME_MIN = 3;
export const USERNAME_MAX = 20;
export const USERNAME_COOLDOWN_MS = 30 * 86_400_000;

// prettier-ignore
export const RESERVED_USERNAMES: ReadonlySet<string> = new Set([
  "admin", "administrator", "root", "system", "support", "help", "staff", "mod", "moderator", "official", "owner",
  "qm", "quidditch", "quidditchmanager", "api", "auth", "www", "mail", "login", "register", "account", "ranking",
  "play", "null", "undefined", "anonymous", "deleted", "unknown", "me",
  "administrador", "soporte", "sysadmin", "webmaster", "postmaster", "hostmaster", "security", "privacy", "terms",
  "logout", "signin", "signup", "settings", "static", "healthz", "everyone", "nobody", "guest", "test", "bot",
]);

// prettier-ignore
export const BLOCKED_SUBSTRINGS: readonly string[] = [
  "nigger", "nigga", "faggot", "retard", "tranny", "kike", "wetback", "hitler", "pedophile", "paedophile",
  "maricon", "sudaca", "negrata", "pedofilo",
  "bougnoule", "youpin",
  "kanake", "untermensch",
  "frocio", "ricchione",
  "kankerlijer", "kankerhoer",
  "pidoras", "pidaras", "pidor",
];

export function foldForBlocklist(name: string): string {
  const map: Record<string, string> = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "9": "g" };
  return name
    .toLowerCase()
    .replace(/_/g, "")
    .replace(/[0-9]/g, (d) => map[d] ?? "");
}

export type UsernameError = "username_required" | "username_format" | "username_reserved" | "username_blocked";

export type UsernameCheck = { ok: true; value: string } | { ok: false; error: UsernameError };

export function checkUsername(raw: unknown): UsernameCheck {
  const value = typeof raw === "string" ? raw.trim() : "";
  if (!value) return { ok: false, error: "username_required" };
  if (!USERNAME_RE.test(value)) return { ok: false, error: "username_format" };
  const lower = value.toLowerCase();
  if (RESERVED_USERNAMES.has(lower) || RESERVED_USERNAMES.has(lower.replace(/_/g, ""))) return { ok: false, error: "username_reserved" };
  const folded = foldForBlocklist(value);
  const plain = lower.replace(/_/g, "");
  if (BLOCKED_SUBSTRINGS.some((w) => folded.includes(w) || plain.includes(w))) return { ok: false, error: "username_blocked" };
  return { ok: true, value };
}

export function usernameCooldownUntilMs(changedAt: string | null, nowMs: number): number | null {
  if (!changedAt) return null;
  const t = Date.parse(changedAt);
  if (!Number.isFinite(t)) return null;
  const until = t + USERNAME_COOLDOWN_MS;
  return until > nowMs ? until : null;
}
