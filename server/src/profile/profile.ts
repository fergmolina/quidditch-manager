import { exportCareers } from "../career/report.js";
import { pgError, toIso, type Db, type TxDb } from "../db.js";
import { exportFeedback } from "../feedback/feedback.js";
import { rowToUser, type User, type UserRow } from "../auth/sessions.js";
import { normalizeCountry, type CountryCode } from "./countries.js";
import { findCity, findRegion, type City } from "./geo.js";
import { checkName } from "./names.js";
import { checkUsername, USERNAME_COOLDOWN_MS } from "./username.js";

export const PROFILE_ERRORS = [
  "username_required",
  "username_format",
  "username_reserved",
  "username_blocked",
  "username_taken",
  "username_same",
  "username_cooldown",
  "name_invalid",
  "name_too_long",
  "country_required",
  "country_invalid",
  "region_invalid",
  "city_invalid",
  "terms_required",
  "confirm_mismatch",
  "conflict",
] as const;
export type ProfileError = (typeof PROFILE_ERRORS)[number];

export type ProfileField = "username" | "first_name" | "last_name" | "country" | "region" | "city" | "terms" | "confirm" | "form";
export type FieldErrors = Partial<Record<ProfileField, ProfileError>>;

export class ProfileWriteError extends Error {
  constructor(readonly code: ProfileError) {
    super(code);
    this.name = "ProfileWriteError";
  }
}

export interface Location {
  country: CountryCode | null;
  region: string | null;
  city: City | null;
}

/** What the city field posts: nothing, "other" (a place not in the list) or a GeoNames id. Anything else is `invalid`. */
export type CityChoice = { kind: "none" } | { kind: "other" } | { kind: "id"; id: number } | { kind: "invalid" };

export function cityChoice(raw: string): CityChoice {
  const s = raw.trim();
  if (!s) return { kind: "none" };
  if (s === "other") return { kind: "other" };
  return /^[1-9][0-9]{0,9}$/.test(s) ? { kind: "id", id: Number(s) } : { kind: "invalid" };
}

export interface ProfileFormValues {
  username: string;
  first_name: string;
  last_name: string;
  country: string;
  region: string;
  city: CityChoice;
}

export function formValues(form: Record<string, string>): ProfileFormValues {
  const s = (k: string, max: number) => (form[k] ?? "").slice(0, max);
  return {
    username: s("username", 64),
    first_name: s("first_name", 200),
    last_name: s("last_name", 200),
    country: s("country", 8),
    region: s("region", 32),
    city: cityChoice(s("city", 16)),
  };
}

export function valuesFromUser(u: User): ProfileFormValues {
  return {
    username: u.username ?? "",
    first_name: u.firstName ?? "",
    last_name: u.lastName ?? "",
    country: u.countryCode ?? "",
    region: u.regionCode ?? "",
    city: u.city ? { kind: "id", id: u.city.geonameid } : { kind: "none" },
  };
}

export type Parsed<T> = { ok: true; value: T } | { ok: false; errors: FieldErrors };

/** The errors of every failed parse, merged for one re-render of the form. */
export function collectErrors(...results: Array<Parsed<unknown> | null>): FieldErrors {
  return Object.assign({}, ...results.map((r) => (r && !r.ok ? r.errors : {})));
}

export function parseLocation(v: Pick<ProfileFormValues, "country" | "region" | "city">): Parsed<Location> {
  if (!v.country.trim()) return { ok: false, errors: { country: "country_required" } };
  const country = normalizeCountry(v.country);
  if (!country) return { ok: false, errors: { country: "country_invalid" } };
  const errors: FieldErrors = {};
  let city: City | null = null;
  if (v.city.kind === "id" || v.city.kind === "invalid") {
    city = v.city.kind === "id" ? findCity(country, v.city.id) : null;
    if (!city) errors.city = "city_invalid";
  }
  // The region select only narrows the city list, so a chosen city's own region wins and the pick is not checked.
  let region = city?.admin1 ?? null;
  if (region === null) {
    const picked = v.region.trim();
    if (picked) {
      if (findRegion(country, picked)) region = picked;
      else errors.region = "region_invalid";
    }
  }
  if (errors.city || errors.region) return { ok: false, errors };
  return { ok: true, value: { country, region, city } };
}

export interface NamesInput {
  firstName: string | null;
  lastName: string | null;
}

export function parseNames(v: Pick<ProfileFormValues, "first_name" | "last_name">): Parsed<NamesInput> {
  const f = checkName(v.first_name);
  const l = checkName(v.last_name);
  if (f.ok && l.ok) return { ok: true, value: { firstName: f.value, lastName: l.value } };
  const errors: FieldErrors = {};
  if (!f.ok) errors.first_name = f.error;
  if (!l.ok) errors.last_name = l.error;
  return { ok: false, errors };
}

export function parseUsername(raw: string): Parsed<string> {
  const r = checkUsername(raw);
  return r.ok ? { ok: true, value: r.value } : { ok: false, errors: { username: r.error } };
}

/** The unique index on lower(username) is the race guard between the availability pre-check and the write. */
function isUsernameConflict(e: unknown): boolean {
  const p = pgError(e);
  return p.code === "23505" && p.constraint === "users_username_key";
}

async function guarded<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    if (isUsernameConflict(e)) throw new ProfileWriteError("username_taken");
    throw e;
  }
}

export interface ProfileInput extends NamesInput {
  location: Location;
}

/** Parameters $1..$9 of every statement that writes the profile columns. */
function profileParams(userId: string, p: ProfileInput): unknown[] {
  const city = p.location.city;
  return [userId, p.firstName, p.lastName, p.location.country, p.location.region, city?.id ?? null, city?.name ?? null, city?.lat ?? null, city?.lon ?? null];
}

/** First registration: the account has no username yet and gets one together with the profile. */
export async function registerProfile(db: Db, userId: string, input: ProfileInput & { username: string; termsVersion: string }, nowMs: number): Promise<User> {
  const rows = await guarded(() =>
    db.query<UserRow>(
      `update public.users
          set first_name = $2, last_name = $3, country_code = $4, region_code = $5,
              city_geonameid = $6, city_name = $7, city_lat = $8, city_lon = $9,
              terms_version = $10, terms_accepted_at = $11::timestamptz, username = $12
        where id = $1::uuid and username is null and blocked_at is null
        returning *`,
      [...profileParams(userId, input), input.termsVersion, new Date(nowMs).toISOString(), input.username],
    ),
  );
  if (!rows[0]) throw new ProfileWriteError("conflict");
  return rowToUser(rows[0]);
}

/** An account that has a username but still lacks the rest of the profile fills it in and accepts the terms. */
export async function completeProfile(db: Db, userId: string, input: ProfileInput & { termsVersion: string }, nowMs: number): Promise<User> {
  const rows = await db.query<UserRow>(
    `update public.users
        set first_name = $2, last_name = $3, country_code = $4, region_code = $5,
            city_geonameid = $6, city_name = $7, city_lat = $8, city_lon = $9,
            terms_version = $10, terms_accepted_at = $11::timestamptz
      where id = $1::uuid and username is not null and blocked_at is null
      returning *`,
    [...profileParams(userId, input), input.termsVersion, new Date(nowMs).toISOString()],
  );
  if (!rows[0]) throw new ProfileWriteError("conflict");
  return rowToUser(rows[0]);
}

export async function updateProfile(db: Db, userId: string, input: ProfileInput): Promise<User | null> {
  const rows = await db.query<UserRow>(
    `update public.users
        set first_name = $2, last_name = $3, country_code = $4, region_code = $5,
            city_geonameid = $6, city_name = $7, city_lat = $8, city_lon = $9
      where id = $1::uuid and blocked_at is null
      returning *`,
    profileParams(userId, input),
  );
  return rows[0] ? rowToUser(rows[0]) : null;
}

export async function acceptTerms(db: TxDb, userId: string, version: string, nowMs: number): Promise<User | null> {
  const rows = await db.query<UserRow>(
    `update public.users set terms_version = $2, terms_accepted_at = $3::timestamptz
      where id = $1::uuid and blocked_at is null returning *`,
    [userId, version, new Date(nowMs).toISOString()],
  );
  return rows[0] ? rowToUser(rows[0]) : null;
}

export async function changeUsername(db: TxDb, userId: string, username: string, nowMs: number, opts: { forced: boolean }): Promise<User> {
  const now = new Date(nowMs).toISOString();
  const rows = await guarded(() =>
    opts.forced
      ? db.query<UserRow>(
          `update public.users set username = $2, username_changed_at = $3::timestamptz, must_rename = false
            where id = $1::uuid and must_rename and blocked_at is null
              and (username is null or lower(username) <> lower($2))
            returning *`,
          [userId, username, now],
        )
      : db.query<UserRow>(
          `update public.users set username = $2, username_changed_at = $3::timestamptz
            where id = $1::uuid and not must_rename and blocked_at is null and username is not null
              and (username_changed_at is null or username_changed_at <= $4::timestamptz)
            returning *`,
          [userId, username, now, new Date(nowMs - USERNAME_COOLDOWN_MS).toISOString()],
        ),
  );
  if (!rows[0]) throw new ProfileWriteError(opts.forced ? "username_same" : "username_cooldown");
  return rowToUser(rows[0]);
}

export async function usernameAvailable(db: Db, username: string, userId: string): Promise<boolean> {
  const rows = await db.query<{ ok: number }>(
    "select 1 as ok from public.users where lower(username) = lower($1) and id <> $2::uuid limit 1",
    [username, userId],
  );
  return rows.length === 0;
}

export async function exportUserData(db: Db, userId: string, nowMs: number): Promise<Record<string, unknown> | null> {
  const users = await db.query<UserRow & Record<string, unknown>>("select * from public.users where id = $1::uuid", [userId]);
  const u = users[0];
  if (!u) return null;
  const account: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(u)) account[k] = v instanceof Date ? v.toISOString() : v;
  const sessions = await db.query<Record<string, unknown>>(
    `select public_id, created_at, last_seen_at, expires_at, absolute_expires_at, rotated_at, user_agent_family
       from public.sessions where user_id = $1::uuid order by created_at`,
    [userId],
  );
  const links = await db.query<Record<string, unknown>>(
    `select created_at, expires_at, consumed_at, lang, next_path, ip_hash
       from public.login_tokens where email = $1 order by created_at`,
    [u.email],
  );
  const iso = (row: Record<string, unknown>) => Object.fromEntries(Object.entries(row).map(([k, v]) => [k, v instanceof Date ? v.toISOString() : v]));
  return {
    exported_at: toIso(new Date(nowMs)),
    service: "Quidditch Manager (browser version) accounts",
    account,
    sessions: sessions.map(iso),
    sign_in_links: links.map(iso),
    careers: await exportCareers(db, userId),
    feedback: await exportFeedback(db, userId),
    notes: [
      "Session and sign-in link token hashes are not included: they are credentials.",
      "ip_hash is a keyed hash of the network block (IPv4 address or IPv6 /64) a sign-in link was requested from; the address itself is never stored. Sign-in links are deleted about a day after they expire.",
      "Your saved games are not on the server: they stay in your browser.",
      "careers: one summary per finished season of each career you played in the browser (reputation, club, titles), for the ranking. A career marked flagged failed a plausibility check and is left out of rankings.",
      "feedback: the bug reports and ideas you sent from /feedback while signed in. They are kept for 12 months.",
    ],
  };
}
