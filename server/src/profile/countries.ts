import { bcp47, type Lang } from "../i18n/i18n.js";

// prettier-ignore
export const ISO_3166_1_ALPHA2 = [
  "AD", "AE", "AF", "AG", "AI", "AL", "AM", "AO", "AQ", "AR", "AS", "AT", "AU", "AW", "AX", "AZ",
  "BA", "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BJ", "BL", "BM", "BN", "BO", "BQ", "BR", "BS", "BT", "BV", "BW", "BY", "BZ",
  "CA", "CC", "CD", "CF", "CG", "CH", "CI", "CK", "CL", "CM", "CN", "CO", "CR", "CU", "CV", "CW", "CX", "CY", "CZ",
  "DE", "DJ", "DK", "DM", "DO", "DZ",
  "EC", "EE", "EG", "EH", "ER", "ES", "ET",
  "FI", "FJ", "FK", "FM", "FO", "FR",
  "GA", "GB", "GD", "GE", "GF", "GG", "GH", "GI", "GL", "GM", "GN", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY",
  "HK", "HM", "HN", "HR", "HT", "HU",
  "ID", "IE", "IL", "IM", "IN", "IO", "IQ", "IR", "IS", "IT",
  "JE", "JM", "JO", "JP",
  "KE", "KG", "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ",
  "LA", "LB", "LC", "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY",
  "MA", "MC", "MD", "ME", "MF", "MG", "MH", "MK", "ML", "MM", "MN", "MO", "MP", "MQ", "MR", "MS", "MT", "MU", "MV", "MW", "MX", "MY", "MZ",
  "NA", "NC", "NE", "NF", "NG", "NI", "NL", "NO", "NP", "NR", "NU", "NZ",
  "OM",
  "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM", "PN", "PR", "PS", "PT", "PW", "PY",
  "QA",
  "RE", "RO", "RS", "RU", "RW",
  "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK", "SL", "SM", "SN", "SO", "SR", "SS", "ST", "SV", "SX", "SY", "SZ",
  "TC", "TD", "TF", "TG", "TH", "TJ", "TK", "TL", "TM", "TN", "TO", "TR", "TT", "TV", "TW", "TZ",
  "UA", "UG", "UM", "US", "UY", "UZ",
  "VA", "VC", "VE", "VG", "VI", "VN", "VU",
  "WF", "WS",
  "YE", "YT",
  "ZA", "ZM", "ZW",
] as const;

/** An ISO 3166-1 alpha-2 code from COUNTRY_CODES. The game's nationality codes (src/game) are a different alphabet. */
export type CountryCode = string & { readonly __brand: "CountryCode" };

/** The 249 ISO codes plus `XK` (Kosovo: a user-assigned code that CLDR, GeoNames and most registries use). */
export const COUNTRY_CODES: readonly CountryCode[] = ([...ISO_3166_1_ALPHA2, "XK"] as CountryCode[]).sort();
const COUNTRY_SET: ReadonlySet<string> = new Set(COUNTRY_CODES);

export function isCountryCode(v: unknown): v is CountryCode {
  return typeof v === "string" && COUNTRY_SET.has(v);
}

export function normalizeCountry(v: unknown): CountryCode | null {
  if (typeof v !== "string") return null;
  const c = v.trim().toUpperCase();
  return isCountryCode(c) ? c : null;
}

const displayCache = new Map<string, Intl.DisplayNames>();

export function countryName(code: string, lang: Lang): string {
  let dn = displayCache.get(lang);
  if (!dn) {
    dn = new Intl.DisplayNames([bcp47(lang)], { type: "region", fallback: "code" });
    displayCache.set(lang, dn);
  }
  try {
    return dn.of(code) ?? code;
  } catch {
    return code;
  }
}

export interface CountryOption {
  code: CountryCode;
  name: string;
}

const optionsCache = new Map<Lang, CountryOption[]>();

export function countryOptions(lang: Lang): CountryOption[] {
  let list = optionsCache.get(lang);
  if (!list) {
    const collator = new Intl.Collator(bcp47(lang));
    list = COUNTRY_CODES.map((code) => ({ code, name: countryName(code, lang) })).sort((a, b) => collator.compare(a.name, b.name));
    optionsCache.set(lang, list);
  }
  return list;
}

/**
 * Cloudflare's `CF-IPCountry` header as a preselection hint (read, never stored). `XX` (unknown) and `T1` (Tor) are
 * not countries, so they and anything else outside the list give null.
 */
export function countryFromHeader(v: string | null | undefined): CountryCode | null {
  return normalizeCountry(v ?? "");
}
