/**
 * Builds `generated/strings.json` (`{lang: {key: text}}`) from the game's `locale/strings.csv`.
 *
 * Usage:
 *   npm run gen:i18n                         # reads ../locale/strings.csv
 *   npm run gen:i18n -- --csv path/to.csv    # another CSV
 *   npm run gen:i18n -- --extra keys.json    # also merge pending keys ({"key": [es, en, …, zh_CN]}) not yet in the CSV
 *   npm run gen:i18n -- --lenient            # report problems but still write the file (local dev only)
 *
 * Kept: every `web.*` key plus a few shared ones (SHARED_KEYS). The build FAILS when a `web.*` key is empty in one
 * of the 10 languages or its `{placeholders}` differ from the English text. Note: tools/merge_translations.py fills
 * missing translations with English silently, so run tools/check_translation.py for each language before merging.
 */
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { GENERATED_STRINGS_PATH, LANGS, placeholders, type Lang, type Strings } from "../src/i18n/i18n.js";

export const SHARED_KEYS = ["ui.app_title", "ui.app_subtitle"];
const here = dirname(fileURLToPath(import.meta.url));
export const DEFAULT_CSV = resolve(here, "../../locale/strings.csv");

/** RFC 4180 CSV (quoted fields, doubled quotes, newlines inside quotes). */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let quoted = false;
  const src = text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
  for (let i = 0; i < src.length; i++) {
    const ch = src[i];
    if (quoted) {
      if (ch === '"') {
        if (src[i + 1] === '"') {
          field += '"';
          i++;
        } else quoted = false;
      } else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ",") {
      row.push(field);
      field = "";
    } else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && src[i + 1] === "\n") i++;
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
    } else field += ch;
  }
  if (field !== "" || row.length) {
    row.push(field);
    rows.push(row);
  }
  return rows.filter((r) => r.length > 1 || (r[0] ?? "") !== "");
}

export type KeyTable = Map<string, string[]>;

/** CSV rows → key → [10 texts in LANGS order]. */
export function tableFromCsv(rows: string[][]): KeyTable {
  const header = rows[0] ?? [];
  const cols = LANGS.map((l) => header.indexOf(l));
  if (header[0] !== "keys" || cols.some((c) => c < 0)) throw new Error(`unexpected CSV header: ${header.join(",")}`);
  const out: KeyTable = new Map();
  for (const r of rows.slice(1)) {
    const key = r[0] ?? "";
    if (key) out.set(key, cols.map((c) => r[c] ?? ""));
  }
  return out;
}

/** A pending-keys JSON (`{"key": [es, en, de, fr, it, pt_BR, nl, ru, ja, zh_CN]}`) → key table. */
export function tableFromJson(obj: unknown): KeyTable {
  const out: KeyTable = new Map();
  if (!obj || typeof obj !== "object") return out;
  for (const [k, v] of Object.entries(obj as Record<string, unknown>)) {
    if (Array.isArray(v) && v.length === LANGS.length && v.every((x) => typeof x === "string")) out.set(k, v as string[]);
  }
  return out;
}

export function wanted(key: string): boolean {
  return key.startsWith("web.") || SHARED_KEYS.includes(key);
}

/** Problems with a key's 10 texts: empty columns and placeholder mismatches against English. */
export function checkKey(key: string, texts: string[]): string[] {
  const problems: string[] = [];
  const enIdx = LANGS.indexOf("en");
  const en = texts[enIdx] ?? "";
  const want = placeholders(en).join(",");
  LANGS.forEach((lang, i) => {
    const t = texts[i] ?? "";
    if (!t.trim()) problems.push(`${key}: empty in ${lang}`);
    else if (placeholders(t).join(",") !== want) problems.push(`${key}: placeholders in ${lang} {${placeholders(t).join(",")}} differ from en {${want}}`);
  });
  return problems;
}

/** Merges the tables (earlier tables win), keeps wanted keys, validates `web.*` keys. */
export function buildStrings(tables: KeyTable[]): { strings: Strings; problems: string[]; count: number } {
  const merged: KeyTable = new Map();
  for (const t of tables) for (const [k, v] of t) if (wanted(k) && !merged.has(k)) merged.set(k, v);
  const strings: Strings = {};
  for (const l of LANGS) strings[l] = {};
  const problems: string[] = [];
  for (const [key, texts] of [...merged].sort(([a], [b]) => a.localeCompare(b))) {
    if (key.startsWith("web.")) problems.push(...checkKey(key, texts));
    LANGS.forEach((l: Lang, i) => {
      const t = texts[i] ?? "";
      if (t) (strings[l] as Record<string, string>)[key] = t;
    });
  }
  return { strings, problems, count: merged.size };
}

function main(argv: string[]): number {
  let csv = DEFAULT_CSV;
  const extras: string[] = [];
  let lenient = false;
  let out = GENERATED_STRINGS_PATH;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--csv") csv = resolve(argv[++i] ?? "");
    else if (a === "--extra") extras.push(resolve(argv[++i] ?? ""));
    else if (a === "--out") out = resolve(argv[++i] ?? "");
    else if (a === "--lenient") lenient = true;
    else {
      console.error(`unknown argument: ${a}`);
      return 2;
    }
  }
  const tables = [tableFromCsv(parseCsv(readFileSync(csv, "utf8")))];
  for (const e of extras) tables.push(tableFromJson(JSON.parse(readFileSync(e, "utf8"))));
  const { strings, problems, count } = buildStrings(tables);
  for (const p of problems) console.error(`[gen-i18n] ${p}`);
  if (problems.length && !lenient) {
    console.error(`[gen-i18n] ${problems.length} problem(s); nothing written`);
    return 1;
  }
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify(strings, null, 1) + "\n");
  console.log(`[gen-i18n] ${count} keys × ${LANGS.length} languages → ${out}`);
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = main(process.argv.slice(2));
}
