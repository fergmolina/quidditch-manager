/**
 * Builds the location picklists from GeoNames (https://www.geonames.org, CC BY 4.0) into server/data/geo/:
 *
 *   admin1.json          { "<CC>": [{ "code": "<admin1>", "name": "<name>" }, …] }   (sorted by code)
 *   cities/<CC>.json     [[geonameid, name, admin1, lat, lon, population, asciiname?], …]   (sorted by geonameid)
 *   meta.json            source URLs, Last-Modified of each download, row counts
 *
 * Sources: admin1CodesASCII.txt (first-level divisions: states, provinces, regions…) and cities5000.zip (every
 * populated place with at least 5,000 inhabitants or that is a seat of a first-level division). Only what the
 * picklists and the future players' map need is kept. `asciiname` is stored only when folding `name` (NFD, marks
 * removed, lowercase) does not already give it, so "Łódź" can be found by typing "lodz".
 *
 * Usage (network required; the output is committed, the server never downloads anything):
 *   npm run build:geo                       # download and write server/data/geo
 *   npm run build:geo -- --from <dir>       # use admin1CodesASCII.txt + cities5000.zip already in <dir>
 *
 * Output is deterministic for a given input, so re-runs give clean diffs.
 */
import { mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { inflateRawSync } from "node:zlib";
import { COUNTRY_CODES } from "../src/profile/countries.js";
import { foldText } from "../src/profile/geo.js";

const here = dirname(fileURLToPath(import.meta.url));
export const GEO_OUT_DIR = resolve(here, "../data/geo");
export const ADMIN1_URL = "https://download.geonames.org/export/dump/admin1CodesASCII.txt";
export const CITIES_URL = "https://download.geonames.org/export/dump/cities5000.zip";
const REGION_CODE_RE = /^[A-Za-z0-9]{1,20}$/;

/** Extracts one file from a zip archive (stored or deflated), reading the central directory. */
export function unzipEntry(zip: Buffer, name: string): Buffer {
  const eocdSig = 0x06054b50;
  let eocd = -1;
  for (let i = zip.length - 22; i >= Math.max(0, zip.length - 65_557); i--) {
    if (zip.readUInt32LE(i) === eocdSig) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw new Error("zip: end of central directory not found");
  const entries = zip.readUInt16LE(eocd + 10);
  let p = zip.readUInt32LE(eocd + 16);
  for (let n = 0; n < entries; n++) {
    if (zip.readUInt32LE(p) !== 0x02014b50) throw new Error("zip: bad central directory entry");
    const method = zip.readUInt16LE(p + 10);
    const compSize = zip.readUInt32LE(p + 20);
    const nameLen = zip.readUInt16LE(p + 28);
    const extraLen = zip.readUInt16LE(p + 30);
    const commentLen = zip.readUInt16LE(p + 32);
    const localOffset = zip.readUInt32LE(p + 42);
    const entryName = zip.subarray(p + 46, p + 46 + nameLen).toString("utf8");
    if (entryName === name) {
      if (zip.readUInt32LE(localOffset) !== 0x04034b50) throw new Error("zip: bad local header");
      const start = localOffset + 30 + zip.readUInt16LE(localOffset + 26) + zip.readUInt16LE(localOffset + 28);
      const data = zip.subarray(start, start + compSize);
      if (method === 0) return Buffer.from(data);
      if (method === 8) return inflateRawSync(data);
      throw new Error(`zip: unsupported compression method ${method}`);
    }
    p += 46 + nameLen + extraLen + commentLen;
  }
  throw new Error(`zip: ${name} not found`);
}

export interface Admin1Entry {
  code: string;
  name: string;
}

/** admin1CodesASCII.txt: `CC.code<TAB>name<TAB>asciiname<TAB>geonameid`. */
export function parseAdmin1(text: string, countries: ReadonlySet<string>): Record<string, Admin1Entry[]> {
  const out: Record<string, Admin1Entry[]> = {};
  for (const line of text.split("\n")) {
    if (!line.trim()) continue;
    const [key = "", name = "", ascii = ""] = line.split("\t");
    const dot = key.indexOf(".");
    const cc = key.slice(0, dot);
    const code = key.slice(dot + 1);
    if (dot !== 2 || !countries.has(cc) || !REGION_CODE_RE.test(code)) continue;
    (out[cc] ??= []).push({ code, name: (name || ascii).trim() });
  }
  const sorted: Record<string, Admin1Entry[]> = {};
  for (const cc of Object.keys(out).sort()) sorted[cc] = out[cc]!.sort((a, b) => (a.code < b.code ? -1 : a.code > b.code ? 1 : 0));
  return sorted;
}

/** One city row: [geonameid, name, admin1 ("" when none), lat, lon, population, asciiname?]. */
export type CityRow = [number, string, string, number, number, number] | [number, string, string, number, number, number, string];

const round4 = (x: number) => Math.round(x * 10_000) / 10_000;

/**
 * cities5000.txt (the GeoNames "geoname" table): 0 geonameid, 1 name, 2 asciiname, 3 alternatenames, 4 latitude,
 * 5 longitude, 6 feature class, 7 feature code, 8 country code, 9 cc2, 10 admin1 code, …, 14 population.
 * An admin1 code that is not listed for the country (e.g. "00") is dropped, so every stored admin1 is a real region.
 */
export function parseCities(text: string, countries: ReadonlySet<string>, admin1: Record<string, Admin1Entry[]>): Record<string, CityRow[]> {
  const known = new Map(Object.entries(admin1).map(([cc, list]) => [cc, new Set(list.map((r) => r.code))]));
  const out: Record<string, CityRow[]> = {};
  for (const line of text.split("\n")) {
    if (!line.trim()) continue;
    const f = line.split("\t");
    const id = Number(f[0]);
    const name = (f[1] ?? "").trim();
    const ascii = (f[2] ?? "").trim();
    const lat = Number(f[4]);
    const lon = Number(f[5]);
    const cc = f[8] ?? "";
    let a1 = f[10] ?? "";
    const pop = Number(f[14] ?? 0) || 0;
    if (!Number.isInteger(id) || id <= 0 || !name || !countries.has(cc)) continue;
    if (!Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) continue;
    if (!known.get(cc)?.has(a1)) a1 = "";
    const row: CityRow = [id, name.slice(0, 200), a1, round4(lat), round4(lon), pop];
    if (ascii && foldText(name) !== foldText(ascii)) row.push(ascii.slice(0, 200));
    (out[cc] ??= []).push(row);
  }
  const sorted: Record<string, CityRow[]> = {};
  for (const cc of Object.keys(out).sort()) sorted[cc] = out[cc]!.sort((a, b) => a[0] - b[0]);
  return sorted;
}

async function download(url: string): Promise<{ body: Buffer; lastModified: string | null }> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return { body: Buffer.from(await res.arrayBuffer()), lastModified: res.headers.get("last-modified") };
}

async function main(argv: string[]): Promise<number> {
  let from: string | null = null;
  let out = GEO_OUT_DIR;
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--from") from = resolve(argv[++i] ?? "");
    else if (argv[i] === "--out") out = resolve(argv[++i] ?? "");
    else {
      console.error(`unknown argument: ${argv[i]}`);
      return 2;
    }
  }
  let admin1Text: string;
  let zip: Buffer;
  let admin1Modified: string | null = null;
  let citiesModified: string | null = null;
  if (from) {
    admin1Text = readFileSync(join(from, "admin1CodesASCII.txt"), "utf8");
    zip = readFileSync(join(from, "cities5000.zip"));
  } else {
    const a = await download(ADMIN1_URL);
    const c = await download(CITIES_URL);
    admin1Text = a.body.toString("utf8");
    zip = c.body;
    admin1Modified = a.lastModified;
    citiesModified = c.lastModified;
  }
  const countries = new Set<string>(COUNTRY_CODES);
  const admin1 = parseAdmin1(admin1Text, countries);
  const cities = parseCities(unzipEntry(zip, "cities5000.txt").toString("utf8"), countries, admin1);

  mkdirSync(join(out, "cities"), { recursive: true });
  for (const f of readdirSync(join(out, "cities"))) if (f.endsWith(".json")) rmSync(join(out, "cities", f));
  writeFileSync(join(out, "admin1.json"), JSON.stringify(admin1) + "\n");
  let cityCount = 0;
  for (const [cc, rows] of Object.entries(cities)) {
    cityCount += rows.length;
    writeFileSync(join(out, "cities", `${cc}.json`), "[\n" + rows.map((r) => JSON.stringify(r)).join(",\n") + "\n]\n");
  }
  const meta = {
    source: "GeoNames (https://www.geonames.org)",
    license: "CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)",
    files: {
      admin1: { url: ADMIN1_URL, lastModified: admin1Modified },
      cities: { url: CITIES_URL, lastModified: citiesModified },
    },
    counts: {
      countriesWithRegions: Object.keys(admin1).length,
      regions: Object.values(admin1).reduce((n, l) => n + l.length, 0),
      countriesWithCities: Object.keys(cities).length,
      cities: cityCount,
    },
    cityRow: ["geonameid", "name", "admin1", "lat", "lon", "population", "asciiname (only when it differs from the folded name)"],
  };
  writeFileSync(join(out, "meta.json"), JSON.stringify(meta, null, 2) + "\n");
  console.log(`[build-geo] ${meta.counts.regions} regions in ${meta.counts.countriesWithRegions} countries, ${cityCount} cities in ${meta.counts.countriesWithCities} countries → ${out}`);
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).then(
    (code) => (process.exitCode = code),
    (e) => {
      console.error(`[build-geo] ${e instanceof Error ? e.message : String(e)}`);
      process.exitCode = 1;
    },
  );
}
