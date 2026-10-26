import { z } from "zod";
import type { Db } from "../db.js";
import rules from "../../../data/shared/career_rules.json" with { type: "json" };
import schema from "../../../data/shared/season_report.schema.json" with { type: "json" };

export const MAX_NEW_CAREERS_PER_DAY = 20;
export const MAX_REPORTS_PER_DAY = 200;

/** The fields of data/shared/season_report.schema.json after parsing, defaults applied. */
export interface SeasonReport {
  career_id: string;
  season: number;
  reported_on: string;
  reputation: number;
  mode: "club" | "school";
  club_id?: string | null;
  club_name?: string | null;
  titles: number;
  seasons: number;
  game_version?: string | null;
}

/** JSON Schema cannot say "trim", so the name is trimmed before the length limits apply. */
function trimClubName(raw: unknown): unknown {
  if (raw === null || typeof raw !== "object" || !("club_name" in raw) || typeof raw.club_name !== "string") return raw;
  return { ...raw, club_name: raw.club_name.trim() };
}

export const seasonReportSchema = z.preprocess(
  trimClubName,
  z.fromJSONSchema(schema as z.core.JSONSchema.JSONSchema) as z.ZodType<SeasonReport>,
);

export interface CareerState {
  user_id: string;
  last_season: number;
  last_reputation: number;
  last_titles: number;
  last_seasons: number;
}

const SEASON_START_MONTH = 7;
const SEASON_START_DAY = 1;

function seasonStartMs(startYear: number): number {
  return Date.UTC(startYear, SEASON_START_MONTH - 1, SEASON_START_DAY);
}

/** A season is named by its starting year and its report arrives during the next one. */
export function dateFitsSeason(reportedOn: string, season: number): boolean {
  const ms = Date.parse(`${reportedOn}T00:00:00Z`);
  if (!Number.isFinite(ms)) return false;
  return ms >= seasonStartMs(season + 1) && ms < seasonStartMs(season + 2);
}

export function plausibility(r: SeasonReport, prev: CareerState | null): string | null {
  if (!dateFitsSeason(r.reported_on, r.season)) return "date_outside_season";
  if (r.reputation < rules.reputation.min || r.reputation > rules.reputation.max) return "reputation_out_of_range";
  if (prev === null) {
    const seasonsSince = r.season - rules.first_season + 1;
    if (r.reputation > rules.start_reputation.max + rules.max_gain_per_season * seasonsSince) return "reputation_jump";
    if (r.titles > rules.max_titles_per_season * seasonsSince) return "titles_jump";
    return null;
  }
  const gap = r.season - prev.last_season;
  if (gap <= 0) return "season_not_after_last";
  if (r.reputation - prev.last_reputation > rules.max_gain_per_season * gap) return "reputation_jump";
  if (r.titles < prev.last_titles) return "titles_decreased";
  if (r.titles - prev.last_titles > rules.max_titles_per_season * gap) return "titles_jump";
  if (r.seasons < prev.last_seasons) return "seasons_decreased";
  return null;
}

export type ReportOutcome =
  | { status: "stored"; flagged: boolean; reason: string | null }
  | { status: "duplicate" }
  | { status: "conflict"; error: "career_belongs_to_another_account" | "season_already_reported" | "season_before_last" }
  | { status: "limited"; error: "too_many_reports" | "too_many_new_careers" };

export async function storeSeasonReport(db: Db, userId: string, r: SeasonReport, nowMs: number): Promise<ReportOutcome> {
  return db.transaction(async (tx) => {
    const since = new Date(nowMs - 86_400_000).toISOString();
    const counts = await tx.query<{ reports: string; careers: string }>(
      `select (select count(*) from public.career_seasons where user_id = $1::uuid and received_at > $2::timestamptz) as reports,
              (select count(*) from public.careers where user_id = $1::uuid and created_at > $2::timestamptz) as careers`,
      [userId, since],
    );
    if (Number(counts[0]?.reports ?? 0) >= MAX_REPORTS_PER_DAY) return { status: "limited", error: "too_many_reports" };
    const rows = await tx.query<CareerState & { flagged_at: string | Date | null }>(
      `select user_id, last_season, last_reputation, last_titles, last_seasons, flagged_at
         from public.careers where career_id = $1 for update`,
      [r.career_id],
    );
    const prev = rows[0] ?? null;
    if (prev && prev.user_id !== userId) return { status: "conflict", error: "career_belongs_to_another_account" };
    if (prev) {
      const same = await tx.query<{ reputation: number; titles: number; seasons: number }>(
        "select reputation, titles, seasons from public.career_seasons where career_id = $1 and season = $2",
        [r.career_id, r.season],
      );
      if (same[0]) {
        const s = same[0];
        if (s.reputation === r.reputation && s.titles === r.titles && s.seasons === r.seasons) return { status: "duplicate" };
        return { status: "conflict", error: "season_already_reported" };
      }
      if (r.season < prev.last_season) return { status: "conflict", error: "season_before_last" };
    } else if (Number(counts[0]?.careers ?? 0) >= MAX_NEW_CAREERS_PER_DAY) {
      return { status: "limited", error: "too_many_new_careers" };
    }
    const reason = plausibility(r, prev);
    const flagged = reason !== null;
    const now = new Date(nowMs).toISOString();
    if (!prev) {
      await tx.query(
        `insert into public.careers (career_id, user_id, mode, first_season, last_season, last_reputation, last_titles,
                                     last_seasons, flagged_at, flag_reason, created_at, updated_at)
         values ($1, $2::uuid, $3, $4, $4, $5, $6, $7, $8::timestamptz, $9, $10::timestamptz, $10::timestamptz)`,
        [r.career_id, userId, r.mode, r.season, r.reputation, r.titles, r.seasons, flagged ? now : null, reason, now],
      );
    } else {
      await tx.query(
        `update public.careers
            set last_season = $2, last_reputation = $3, last_titles = $4, last_seasons = $5, mode = $6,
                flagged_at = coalesce(flagged_at, $7::timestamptz), flag_reason = coalesce(flag_reason, $8),
                updated_at = $9::timestamptz
          where career_id = $1`,
        [r.career_id, r.season, r.reputation, r.titles, r.seasons, r.mode, flagged ? now : null, reason, now],
      );
    }
    await tx.query(
      `insert into public.career_seasons (career_id, user_id, season, reported_on, reputation, club_id, club_name, titles,
                                          seasons, game_version, flagged, flag_reason, received_at)
       values ($1, $2::uuid, $3, $4::date, $5, $6, $7, $8, $9, $10, $11, $12, $13::timestamptz)`,
      [r.career_id, userId, r.season, r.reported_on, r.reputation, r.club_id ?? null, r.club_name ?? null, r.titles,
        r.seasons, r.game_version ?? null, flagged, reason, now],
    );
    return { status: "stored", flagged, reason };
  });
}

export async function exportCareers(db: Db, userId: string): Promise<Record<string, unknown>[]> {
  const careers = await db.query<Record<string, unknown>>(
    `select career_id, mode, first_season, last_season, last_reputation, last_titles, last_seasons, flagged_at,
            flag_reason, created_at, updated_at
       from public.careers where user_id = $1::uuid order by created_at`,
    [userId],
  );
  const seasons = await db.query<Record<string, unknown>>(
    `select career_id, season, reported_on, reputation, club_id, club_name, titles, seasons, game_version, flagged,
            flag_reason, received_at
       from public.career_seasons where user_id = $1::uuid order by career_id, season`,
    [userId],
  );
  const iso = (row: Record<string, unknown>) =>
    Object.fromEntries(Object.entries(row).map(([k, v]) => [k, v instanceof Date ? v.toISOString() : v]));
  return careers.map((c) => ({ ...iso(c), seasons: seasons.filter((s) => s.career_id === c.career_id).map(iso) }));
}
