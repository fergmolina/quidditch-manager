import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import type { Lang, T } from "../i18n/i18n.js";

/**
 * The game's world as the public pages show it: leagues, clubs, schools and the canon players and students, read
 * from the game's own data pack (data/packs/1993-94 and data/shared). Nothing here is invented: names come from the
 * data, every other word from translation keys the game already uses (country.*, comp.*, club.*, house.*, pos.*).
 * In the repository the data sits at ../../../data from this file; the Docker image copies the files it needs to
 * /data, which is the same relative path from dist/world/.
 */
export const DATA_DIR = fileURLToPath(new URL("../../../data/", import.meta.url));
const PACK = "packs/1993-94";

export type Source = "canon" | "filler";
export type Position = "K" | "C" | "B" | "S";

export interface WorldPlayer {
  name: string;
  position: Position;
  nationality: string;
}

export interface WorldClub {
  id: string;
  slug: string;
  name: string;
  /** As written in the data: Spanish "City, Country"; see displayCity. */
  city: string;
  countryId: string;
  leagueId: string;
  founded: number;
  colors: [string, string];
  styleTag: string;
  leagueTitles: number;
  europeanCups: number;
  notesKeys: string[];
  rivalIds: string[];
  manager: string;
  source: Source;
  players: WorldPlayer[];
}

export interface WorldLeague {
  id: string;
  slug: string;
  regionId: string;
  countryIds: string[];
  clubIds: string[];
}

export interface WorldHouse {
  name: string;
  colors: [string, string] | null;
  students: WorldPlayer[];
}

export interface WorldSchool {
  id: string;
  slug: string;
  countryId: string;
  houses: WorldHouse[];
  source: Source;
}

export interface World {
  leagues: WorldLeague[];
  clubs: Map<string, WorldClub>;
  schools: WorldSchool[];
  leagueBySlug: Map<string, WorldLeague>;
  clubBySlug: Map<string, WorldClub>;
  schoolBySlug: Map<string, WorldSchool>;
  /** Spanish city name → its name in the other languages (data/shared/city_names.json). */
  cityNames: Record<string, Partial<Record<Lang | "local", string>>>;
}

/** "club_chudley_cannons" → "chudley-cannons". */
export function slugOf(id: string): string {
  return id.replace(/^(club|comp|school)_/, "").replace(/_/g, "-");
}

const sourceOf = (s: unknown): Source => (typeof s === "string" && (s.startsWith("canon") || s === "inferred") ? "canon" : "filler");

function readJson(path: string): Record<string, unknown> {
  return JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
}

function readDir(dir: string): Record<string, unknown>[] {
  return readdirSync(dir)
    .filter((f) => f.endsWith(".json"))
    .sort()
    .map((f) => readJson(join(dir, f)));
}

const str = (v: unknown): string => (typeof v === "string" ? v : "");
const num = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : 0);
const strs = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : []);
const pos = (v: unknown): Position => (v === "K" || v === "C" || v === "B" || v === "S" ? v : "C");

function colorsOf(v: unknown): [string, string] | null {
  const c = v as { primary?: unknown; secondary?: unknown } | undefined;
  const ok = (x: unknown): x is string => typeof x === "string" && /^#[0-9A-Fa-f]{6}$/.test(x);
  return c && ok(c.primary) && ok(c.secondary) ? [c.primary, c.secondary] : null;
}

const fullName = (o: Record<string, unknown>): string => [str(o.first_name), str(o.last_name)].filter(Boolean).join(" ");

export function loadWorld(dir = DATA_DIR): World {
  const players = readDir(join(dir, PACK, "players"));
  const clubs = new Map<string, WorldClub>();
  for (const c of readDir(join(dir, PACK, "clubs"))) {
    const id = str(c.id);
    const identity = (c.identity ?? {}) as Record<string, unknown>;
    const history = (c.history ?? {}) as Record<string, unknown>;
    clubs.set(id, {
      id,
      slug: slugOf(id),
      name: str(c.name),
      city: str(c.city),
      countryId: str(c.country_id),
      leagueId: str(c.league_id),
      founded: num(c.founded),
      colors: colorsOf(c.colors) ?? ["#7A5A26", "#F7F1E1"],
      styleTag: strs(identity.style_tags)[0] ?? "balanced",
      leagueTitles: num(history.league_titles),
      europeanCups: num(history.european_cups),
      notesKeys: strs(history.notes_keys),
      rivalIds: strs(identity.rivalries),
      manager: str(c.manager_name),
      source: sourceOf(c.source),
      players: players
        .filter((p) => p.club_id === id)
        .map((p) => ({ name: fullName(p), position: pos(p.main_position), nationality: strs(p.nationality_ids)[0] ?? "" })),
    });
  }
  const leagues: WorldLeague[] = readDir(join(dir, PACK, "competitions"))
    .filter((l) => l.type === "league")
    .map((l) => ({ id: str(l.id), slug: slugOf(str(l.id)), regionId: str(l.region_id), countryIds: strs(l.country_ids), clubIds: strs(l.club_ids).filter((id) => clubs.has(id)) }));
  const packSchools = new Map(readDir(join(dir, PACK, "schools")).map((s) => [str(s.school_id), s]));
  const schools: WorldSchool[] = ((readJson(join(dir, "shared/schools.json")).schools ?? []) as Record<string, unknown>[]).map((s) => {
    const id = str(s.id);
    const pack = packSchools.get(id) ?? {};
    const colors = (pack.house_colors ?? {}) as Record<string, unknown>;
    const students = (Array.isArray(pack.students) ? pack.students : []) as Record<string, unknown>[];
    return {
      id,
      slug: slugOf(id),
      countryId: str(s.country_id),
      source: sourceOf(s.source),
      houses: strs(s.houses).map((h) => ({
        name: h,
        colors: colorsOf(colors[h]),
        students: students.filter((st) => st.house === h).map((st) => ({ name: fullName(st), position: pos(st.position), nationality: str(st.nationality) })),
      })),
    };
  });
  const cityNames = (readJson(join(dir, "shared/city_names.json")).cities ?? {}) as World["cityNames"];
  return {
    leagues,
    clubs,
    schools,
    cityNames,
    leagueBySlug: new Map(leagues.map((l) => [l.slug, l])),
    clubBySlug: new Map([...clubs.values()].map((c) => [c.slug, c])),
    schoolBySlug: new Map(schools.map((s) => [s.slug, s])),
  };
}

let cached: World | null = null;

/** The world, read once per process (the data is part of the image). */
export function world(): World {
  cached ??= loadWorld();
  return cached;
}

/** Club.display_city() of the game: the city in the page language, then the country through country.<id>. */
export function displayCity(w: World, club: WorldClub, lang: Lang, t: T): string {
  if (!club.city || lang === "es") return club.city;
  const parts = club.city.split(",").map((s) => s.trim());
  let first = parts[0] ?? "";
  if (first.includes(" (")) first = first.split(" (")[0] ?? first;
  const names = w.cityNames[first];
  if (names) first = names[lang] ?? names.en ?? first;
  if (parts.length < 2) return first;
  const key = `country.${club.countryId}`;
  const country = t(key);
  return `${first}, ${country === key ? (parts[parts.length - 1] ?? "") : country}`;
}

/** The game's encyclopedia text for a club: its own history keys, or the generic style and titles lines. */
export function clubNotes(club: WorldClub, t: T): string[] {
  if (club.notesKeys.length) return club.notesKeys.map((k) => t(k, { n: club.leagueTitles }));
  const styleKey = `club.generic.style.${club.styleTag}`;
  const style = t(styleKey) === styleKey ? t("club.generic.style.balanced") : t(styleKey);
  const titles = club.leagueTitles === 0 ? t("club.generic.no_titles") : club.leagueTitles === 1 ? t("club.generic.one_title") : t("club.generic.titles", { n: club.leagueTitles });
  return [style, titles];
}
