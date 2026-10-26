/**
 * The data-* hooks that static/register.js reads from the profile form. The script cannot import this module
 * (it is served as-is under CSP script-src 'self'), so test/register-js.test.ts checks that both sides use these names.
 */
export const REGISTER_JS = {
  geoForm: "data-geo-form",
  geoRole: "data-geo",
  geoRoles: ["country", "region", "city", "refresh-row", "city-hint"],
  geoWrap: "data-geo-wrap",
  geoWraps: ["region", "city"],
  cityTexts: { other: "data-other", none: "data-none", placeholder: "data-placeholder" },
  cityOptionRegion: "data-region",
  usernameCheck: "data-username-check",
  usernameStatusSuffix: "-status",
  usernameStatus: { ok: "data-ok", taken: "data-taken", reserved: "data-reserved", blocked: "data-blocked" },
} as const;

export type GeoRole = (typeof REGISTER_JS.geoRoles)[number];
export type GeoWrap = (typeof REGISTER_JS.geoWraps)[number];
