import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { bcp47, type Lang } from "../i18n/i18n.js";

export const GEO_DIR = fileURLToPath(new URL("../../data/geo/", import.meta.url));

export interface Region {
  code: string;
  name: string;
}

export interface City {
  id: number;
  name: string;
  /** First-level division code, or null where the country has none for this place. */
  admin1: string | null;
  lat: number;
  lon: number;
  population: number;
  keys: string[];
}

export interface CityHit {
  id: number;
  name: string;
  region: string;
  region_name: string | null;
}

const SPECIAL_LETTERS: Record<string, string> = { ł: "l", ø: "o", đ: "d", ß: "ss", æ: "ae", œ: "oe", ı: "i", þ: "th", ð: "d", ħ: "h" };

export function foldText(s: string): string {
  return s
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/[łøđßæœıþðħ]/g, (ch) => SPECIAL_LETTERS[ch] ?? ch)
    .replace(/[\s\-'’.,()/]+/g, " ")
    .trim();
}

let geoDir = GEO_DIR;
let admin1Cache: Map<string, Region[]> | null = null;
const cityCache = new Map<string, { list: City[]; byId: Map<number, City> }>();

export function setGeoDir(dir: string): void {
  geoDir = dir;
  admin1Cache = null;
  cityCache.clear();
}

function admin1(): Map<string, Region[]> {
  if (admin1Cache) return admin1Cache;
  const path = join(geoDir, "admin1.json");
  const raw = existsSync(path) ? (JSON.parse(readFileSync(path, "utf8")) as Record<string, Region[]>) : {};
  admin1Cache = new Map(Object.entries(raw));
  return admin1Cache;
}

type RawCityRow = [number, string, string, number, number, number, string?];

function cities(cc: string): { list: City[]; byId: Map<number, City> } {
  const hit = cityCache.get(cc);
  if (hit) return hit;
  let rows: RawCityRow[] = [];
  if (/^[A-Z]{2}$/.test(cc)) {
    const path = join(geoDir, "cities", `${cc}.json`);
    if (existsSync(path)) rows = JSON.parse(readFileSync(path, "utf8")) as RawCityRow[];
  }
  const list: City[] = rows.map(([id, name, a1, lat, lon, population, ascii]) => {
    const keys = [foldText(name)];
    if (ascii) keys.push(foldText(ascii));
    return { id, name, admin1: a1 || null, lat, lon, population, keys };
  });
  const entry = { list, byId: new Map(list.map((c) => [c.id, c])) };
  cityCache.set(cc, entry);
  return entry;
}

const centroidCache = new Map<string, { lat: number; lon: number } | null>();

/** Weighted mean of angles in degrees. Averaging on the circle keeps Fiji near 180°, where a plain mean gives 0°. */
export function circularMeanDeg(angles: ReadonlyArray<{ deg: number; weight: number }>): number {
  let x = 0, y = 0;
  for (const a of angles) {
    x += Math.cos((a.deg * Math.PI) / 180) * a.weight;
    y += Math.sin((a.deg * Math.PI) / 180) * a.weight;
  }
  return (Math.atan2(y, x) * 180) / Math.PI;
}

export function countryCentroid(cc: string): { lat: number; lon: number } | null {
  if (centroidCache.has(cc)) return centroidCache.get(cc)!;
  const list = cities(cc).list;
  const weight = (c: City) => Math.max(1, c.population);
  const total = list.reduce((n, c) => n + weight(c), 0);
  const out =
    total > 0
      ? {
          lat: list.reduce((n, c) => n + c.lat * weight(c), 0) / total,
          lon: circularMeanDeg(list.map((c) => ({ deg: c.lon, weight: weight(c) }))),
        }
      : null;
  centroidCache.set(cc, out);
  return out;
}

export function regionsFor(cc: string, lang: Lang = "en"): Region[] {
  const list = admin1().get(cc) ?? [];
  const collator = new Intl.Collator(bcp47(lang));
  return [...list].sort((a, b) => collator.compare(a.name, b.name));
}

export function findRegion(cc: string, code: string): Region | null {
  return admin1().get(cc)?.find((r) => r.code === code) ?? null;
}

export function findCity(cc: string, id: number): City | null {
  return cities(cc).byId.get(id) ?? null;
}

export function cityCount(cc: string, region?: string | null): number {
  const list = cities(cc).list;
  return region ? list.filter((c) => c.admin1 === region).length : list.length;
}

export function toHit(cc: string, c: City): CityHit {
  return { id: c.id, name: c.name, region: c.admin1 ?? "", region_name: c.admin1 ? (findRegion(cc, c.admin1)?.name ?? null) : null };
}

export const SEARCH_LIMIT = 20;

export function searchCities(cc: string, opts: { region?: string | null; q?: string; limit?: number } = {}): City[] {
  const limit = Math.min(Math.max(opts.limit ?? SEARCH_LIMIT, 1), 50);
  const q = foldText(opts.q ?? "").slice(0, 60);
  const scored: Array<{ c: City; rank: number }> = [];
  for (const c of cities(cc).list) {
    if (opts.region && c.admin1 !== opts.region) continue;
    let rank = 3;
    if (!q) rank = 0;
    else
      for (const k of c.keys) {
        if (k.startsWith(q)) rank = Math.min(rank, 0);
        else if (k.includes(" " + q)) rank = Math.min(rank, 1);
        else if (k.includes(q)) rank = Math.min(rank, 2);
      }
    if (rank < 3) scored.push({ c, rank });
  }
  scored.sort((a, b) => a.rank - b.rank || b.c.population - a.c.population || a.c.name.localeCompare(b.c.name) || a.c.id - b.c.id);
  return scored.slice(0, limit).map((s) => s.c);
}

export const NO_JS_CITY_LIMIT = 600;

/** `needs_region`: the country has too many places to list at once, so the no-JS form asks for a region first. */
export type CitySelect = { kind: "cities"; list: City[] } | { kind: "needs_region" };

export function citiesForSelect(cc: string, region: string | null, lang: Lang = "en"): CitySelect {
  const all = cities(cc).list;
  let list: City[];
  if (region) list = all.filter((c) => c.admin1 === region);
  else if (all.length <= NO_JS_CITY_LIMIT || !(admin1().get(cc)?.length)) list = all;
  else return { kind: "needs_region" };
  if (list.length > NO_JS_CITY_LIMIT) list = [...list].sort((a, b) => b.population - a.population).slice(0, NO_JS_CITY_LIMIT);
  const collator = new Intl.Collator(bcp47(lang));
  return { kind: "cities", list: [...list].sort((a, b) => collator.compare(a.name, b.name) || a.id - b.id) };
}

export function geoCountries(): { regions: string[] } {
  return { regions: [...admin1().keys()] };
}
