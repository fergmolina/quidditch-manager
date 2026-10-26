import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export const LANGS = ["es", "en", "de", "fr", "it", "pt_BR", "nl", "ru", "ja", "zh_CN"] as const;
export type Lang = (typeof LANGS)[number];
export const DEFAULT_LANG: Lang = "en";

export function isLang(v: unknown): v is Lang {
  return typeof v === "string" && (LANGS as readonly string[]).includes(v);
}

export function bcp47(lang: Lang): string {
  return lang.replace("_", "-");
}

export const LANG_NATIVE_NAMES: Record<Lang, string> = {
  es: "Español",
  en: "English",
  de: "Deutsch",
  fr: "Français",
  it: "Italiano",
  pt_BR: "Português (Brasil)",
  nl: "Nederlands",
  ru: "Русский",
  ja: "日本語",
  zh_CN: "简体中文",
};

export type Strings = Partial<Record<Lang, Record<string, string>>>;

export const GENERATED_STRINGS_PATH = fileURLToPath(new URL("../../generated/strings.json", import.meta.url));

let loaded: Strings | null = null;

export function loadStrings(path = GENERATED_STRINGS_PATH): Strings {
  if (!existsSync(path)) return {};
  return JSON.parse(readFileSync(path, "utf8")) as Strings;
}

function strings(): Strings {
  return (loaded ??= loadStrings());
}

export function setStrings(s: Strings): void {
  loaded = s;
}

export function fill(text: string, params?: Record<string, string | number>): string {
  if (!params) return text;
  return text.replace(/\{([A-Za-z0-9_]+)\}/g, (m, k: string) => (Object.hasOwn(params, k) ? String(params[k]) : m));
}

export function translate(lang: Lang, key: string, params?: Record<string, string | number>): string {
  const s = strings();
  const text = s[lang]?.[key] || s.en?.[key] || key;
  return fill(text, params);
}

export type T = (key: string, params?: Record<string, string | number>) => string;

export function translator(lang: Lang): T {
  return (key, params) => translate(lang, key, params);
}

export function placeholders(text: string): string[] {
  return [...new Set([...text.matchAll(/\{([A-Za-z0-9_]+)\}/g)].map((m) => m[1] ?? ""))].sort();
}
