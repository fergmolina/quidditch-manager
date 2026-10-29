import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { buildStrings, checkKey, DEFAULT_CSV, parseCsv, tableFromCsv, tableFromJson } from "../scripts/gen-i18n.js";
import { bcp47, fill, GENERATED_STRINGS_PATH, LANGS, loadStrings, placeholders, setStrings, translate, translator } from "../src/i18n/i18n.js";
import { fromAcceptLanguage, negotiateLang, normalizeLang } from "../src/i18n/negotiate.js";
import { FAQ_IDS } from "../src/pages/faq.js";
import { FEATURES } from "../src/pages/landing.js";

test("normalizeLang maps any tag onto the 10 game languages", () => {
  const cases: Array<[string, string | null]> = [
    ["es", "es"], ["es-AR", "es"], ["EN", "en"], ["en-GB", "en"], ["pt", "pt_BR"], ["pt-PT", "pt_BR"], ["pt_BR", "pt_BR"], ["pt-br", "pt_BR"],
    ["zh", "zh_CN"], ["zh-Hans-CN", "zh_CN"], ["zh_CN", "zh_CN"], ["ja-JP", "ja"], ["nl-BE", "nl"], ["ru", "ru"], ["de-AT", "de"],
    ["xx", null], ["", null], ["<script>", null], ["e", null],
  ];
  for (const [inp, out] of cases) assert.equal(normalizeLang(inp), out, inp);
  assert.equal(bcp47("pt_BR"), "pt-BR");
  assert.equal(bcp47("zh_CN"), "zh-CN");
});

test("Accept-Language honours q-values and skips unknown languages", () => {
  assert.equal(fromAcceptLanguage("sv-SE,sv;q=0.9,de;q=0.8,en;q=0.7"), "de");
  assert.equal(fromAcceptLanguage("en;q=0.5, ja;q=0.9"), "ja");
  assert.equal(fromAcceptLanguage("*"), null);
  assert.equal(fromAcceptLanguage("fr;q=0"), null);
  assert.equal(fromAcceptLanguage(null), null);
});

test("negotiateLang: ?lang → cookie → Accept-Language → en", () => {
  assert.deepEqual(negotiateLang({ query: "it", cookie: "de", acceptLanguage: "fr" }), { lang: "it", fromQuery: true });
  assert.deepEqual(negotiateLang({ query: "bogus", cookie: "de", acceptLanguage: "fr" }), { lang: "de", fromQuery: false });
  assert.deepEqual(negotiateLang({ query: null, cookie: null, acceptLanguage: "fr-CA,fr;q=0.9" }), { lang: "fr", fromQuery: false });
  assert.deepEqual(negotiateLang({ query: null, cookie: null, acceptLanguage: "sv-SE,sv;q=0.9" }), { lang: "en", fromQuery: false });
  assert.deepEqual(negotiateLang({ query: null, cookie: null, acceptLanguage: null }), { lang: "en", fromQuery: false });
});

test("fill, placeholders, and the language → English → key fallback", () => {
  assert.equal(fill("Hi {name}, {n} left {unknown}", { name: "Ana", n: 3 }), "Hi Ana, 3 left {unknown}");
  assert.deepEqual(placeholders("{b} {a} {b}"), ["a", "b"]);
  setStrings({ en: { "web.x": "Hello {name}", "web.only_en": "EN" }, es: { "web.x": "Hola {name}" } });
  try {
    assert.equal(translate("es", "web.x", { name: "Ana" }), "Hola Ana");
    assert.equal(translate("ja", "web.x", { name: "Ana" }), "Hello Ana");
    assert.equal(translate("es", "web.only_en"), "EN");
    assert.equal(translator("de")("web.missing"), "web.missing");
  } finally {
    setStrings(loadStrings());
  }
});

test("parseCsv: quotes, doubled quotes, commas and newlines inside fields, BOM, CRLF", () => {
  const rows = parseCsv('﻿keys,es\r\na,"x, ""y""\nz"\r\nb,plain\n');
  assert.deepEqual(rows, [["keys", "es"], ["a", 'x, "y"\nz'], ["b", "plain"]]);
});

test("buildStrings: CSV wins over extra JSON; incomplete web.* keys and placeholder drift are reported", () => {
  const header = ["keys", ...LANGS];
  const full = (s: string) => LANGS.map((l) => `${s} ${l} {n}`);
  const csv = tableFromCsv([header, ["web.a", ...full("csv")], ["ui.app_title", ...LANGS.map(() => "QM")], ["ui.other", ...full("o")]]);
  const extra = tableFromJson({ "web.a": full("json"), "web.b": full("b"), "bad": [1, 2] });
  const { strings, problems, count } = buildStrings([csv, extra]);
  assert.equal(count, 3, "web.a, web.b, ui.app_title (ui.other is not exported)");
  assert.equal(strings.de?.["web.a"], "csv de {n}");
  assert.equal(strings.ja?.["web.b"], "b ja {n}");
  assert.deepEqual(problems, []);
  const broken = LANGS.map((l) => (l === "ru" ? "" : l === "ja" ? "no placeholder" : "x {n}"));
  assert.deepEqual(checkKey("web.c", broken), ["web.c: empty in ru", "web.c: placeholders in ja {} differ from en {n}"]);
  assert.throws(() => tableFromCsv([["key", "es"]]));
});

test("the game's strings.csv parses with the expected header", { skip: !existsSync(DEFAULT_CSV) && "no locale/strings.csv" }, () => {
  const table = tableFromCsv(parseCsv(readFileSync(DEFAULT_CSV, "utf8")));
  assert.equal(table.get("ui.app_title")?.length, LANGS.length);
});

function usedKeys(): string[] {
  const root = fileURLToPath(new URL("../src/", import.meta.url));
  const out = new Set<string>();
  const walk = (dir: string) => {
    for (const f of readdirSync(dir)) {
      const p = join(dir, f);
      if (statSync(p).isDirectory()) walk(p);
      else if (p.endsWith(".ts")) for (const m of readFileSync(p, "utf8").matchAll(/\bt\("((?:web|ui)\.[a-z0-9_.]+)"/g)) out.add(m[1]!);
    }
  };
  walk(root);
  for (const f of FEATURES) out.add(`web.landing.f_${f}_title`).add(`web.landing.f_${f}_text`);
  for (const id of FAQ_IDS) out.add(`web.faq.q_${id}`).add(`web.faq.a_${id}`);
  for (const e of ["link", "blocked", "google_unverified", "google_failed", "rate_limited", "mail_failed", "mail_cap", "email_invalid", "session"]) out.add(`web.login.error.${e}`);
  return [...out].sort();
}

test("every key the server uses exists in all 10 languages of generated/strings.json", (t) => {
  const s = existsSync(GENERATED_STRINGS_PATH) ? loadStrings() : {};
  const merged = Object.keys(s.en ?? {}).some((k) => k.startsWith("web."));
  if (!merged) {
    t.skip("generated/strings.json has no web.* keys yet (run `npm run gen:i18n` after the keys are merged into strings.csv)");
    return;
  }
  const missing: string[] = [];
  for (const k of usedKeys()) for (const l of LANGS) if (!s[l]?.[k]) missing.push(`${l}:${k}`);
  assert.deepEqual(missing, []);
});

test("Intl has full ICU (country names in every page language)", () => {
  assert.equal(new Intl.DisplayNames(["ja"], { type: "region" }).of("DE"), "ドイツ");
  assert.equal(new Intl.DisplayNames(["zh-CN"], { type: "region" }).of("AR"), "阿根廷");
  assert.equal(new Intl.DisplayNames(["ru"], { type: "region" }).of("FR"), "Франция");
});
