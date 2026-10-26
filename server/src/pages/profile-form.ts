import { html, trustedHtml, escapeHtml, type HtmlValue, type SafeHtml } from "../http/html.js";
import { bcp47, type Lang, type T } from "../i18n/i18n.js";
import { countryOptions, normalizeCountry } from "../profile/countries.js";
import { citiesForSelect, findCity, regionsFor, type City, type CitySelect } from "../profile/geo.js";
import type { FieldErrors, ProfileField, ProfileFormValues } from "../profile/profile.js";
import { USERNAME_MAX, USERNAME_MIN } from "../profile/username.js";
import { REGISTER_JS, type GeoRole, type GeoWrap } from "./register-js.js";

const JS = REGISTER_JS;

function hook(attr: string, value?: string): SafeHtml {
  return trustedHtml(value === undefined ? ` ${attr}` : ` ${attr}="${escapeHtml(value)}"`);
}
const geoRole = (role: GeoRole) => hook(JS.geoRole, role);
const geoWrap = (wrap: GeoWrap) => hook(JS.geoWrap, wrap);

export function tRich(t: T, key: string, params: Record<string, HtmlValue>): SafeHtml {
  const template = t(key);
  let out = "";
  let last = 0;
  for (const m of template.matchAll(/\{([A-Za-z0-9_]+)\}/g)) {
    out += escapeHtml(template.slice(last, m.index));
    const name = m[1] ?? "";
    out += Object.hasOwn(params, name) ? html`${params[name]}`.value : escapeHtml(m[0]);
    last = (m.index ?? 0) + m[0].length;
  }
  out += escapeHtml(template.slice(last));
  return trustedHtml(out);
}

export function formatDate(lang: Lang, iso: string | number | null): string {
  if (iso === null) return "";
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) return "";
  return new Intl.DateTimeFormat(bcp47(lang), { dateStyle: "long", timeZone: "UTC" }).format(d);
}

function describedBy(id: string, hasHelp: boolean, err: string | undefined): SafeHtml {
  const ids = [hasHelp ? `${id}-help` : "", err ? `${id}-error` : ""].filter(Boolean).join(" ");
  return trustedHtml(`${ids ? ` aria-describedby="${ids}"` : ""}${err ? ' aria-invalid="true"' : ""}`);
}

export function fieldError(t: T, id: string, err: string | undefined): SafeHtml | "" {
  return err ? html`<p class="field-error" id="${id}-error" data-code="${err}">${t(`web.profile.error.${err}`)}</p>` : "";
}

export function errorSummary(t: T, errors: FieldErrors): SafeHtml | "" {
  if (!Object.keys(errors).length) return "";
  const form = errors.form;
  return html`<p class="notice error" role="alert"${form ? trustedHtml(` data-code="${form}"`) : ""}>${form ? t(`web.profile.error.${form}`) : t("web.profile.errors_intro")}</p>`;
}

export function usernameField(t: T, o: { value: string; error?: string; id?: string; label?: string; autofocus?: boolean }): SafeHtml {
  const id = o.id ?? "username";
  return html`<div class="field">
<label for="${id}">${o.label ?? t("web.profile.username_label")}</label>
<input id="${id}" name="username" type="text" required minlength="${USERNAME_MIN}" maxlength="${USERNAME_MAX}" pattern="[A-Za-z][A-Za-z0-9_]{2,19}" autocomplete="username" autocapitalize="none" spellcheck="false" value="${o.value}"${o.autofocus ? trustedHtml(" autofocus") : ""}${describedBy(id, true, o.error)}${hook(JS.usernameCheck)}>
<p class="help" id="${id}-help">${t("web.profile.username_help")}</p>
<p class="help" id="${id}${JS.usernameStatusSuffix}" aria-live="polite"${hook(JS.usernameStatus.ok, t("web.profile.username_available"))}${hook(JS.usernameStatus.taken, t("web.profile.error.username_taken"))}${hook(JS.usernameStatus.reserved, t("web.profile.error.username_reserved"))}${hook(JS.usernameStatus.blocked, t("web.profile.error.username_blocked"))}></p>
${fieldError(t, id, o.error)}
</div>`;
}

export function namesFieldset(t: T, v: Pick<ProfileFormValues, "first_name" | "last_name">, errors: FieldErrors): SafeHtml {
  const one = (id: "first_name" | "last_name", label: string, ac: string) => html`<div class="field">
<label for="${id}">${label}</label>
<input id="${id}" name="${id}" type="text" maxlength="50" autocomplete="${ac}" value="${v[id]}"${describedBy(id, false, errors[id])}>
${fieldError(t, id, errors[id])}
</div>`;
  return html`<fieldset>
<legend>${t("web.profile.names_legend")}</legend>
<p class="help">${t("web.profile.names_help")}</p>
${one("first_name", t("web.profile.first_name_label"), "given-name")}
${one("last_name", t("web.profile.last_name_label"), "family-name")}
</fieldset>`;
}

const GEONAMES = html`<a href="https://www.geonames.org/" rel="noopener">GeoNames</a> (<a href="https://creativecommons.org/licenses/by/4.0/" rel="noopener license">CC BY 4.0</a>)`;

export function locationFieldset(t: T, lang: Lang, v: Pick<ProfileFormValues, "country" | "region" | "city">, errors: FieldErrors): SafeHtml {
  const country = normalizeCountry(v.country);
  const countries = countryOptions(lang);
  const regions = country ? regionsFor(country, lang) : [];
  const region = regions.some((r) => r.code === v.region) ? v.region : "";
  const selectedCity: City | null = country && v.city.kind === "id" ? findCity(country, v.city.id) : null;
  const select: CitySelect = country ? citiesForSelect(country, region || null, lang) : { kind: "cities", list: [] };
  const needsRegion = select.kind === "needs_region";
  let cities = select.kind === "cities" ? select.list : [];
  if (selectedCity && !needsRegion && !cities.some((c) => c.id === selectedCity.id)) cities = [selectedCity, ...cities];
  const sel = (on: boolean) => (on ? trustedHtml(" selected") : "");
  const regionName = (code: string) => regions.find((r) => r.code === code)?.name ?? "";

  const countrySelect = html`<div class="field">
<label for="country">${t("web.profile.country_label")}</label>
<select id="country" name="country" required${geoRole("country")}${describedBy("country", true, errors.country)}>
<option value=""${sel(!country)}>${t("web.profile.country_choose")}</option>
${countries.map((c) => html`<option value="${c.code}"${sel(c.code === country)}>${c.name}</option>`)}
</select>
<p class="help" id="country-help">${t("web.profile.country_help")}</p>
${fieldError(t, "country", errors.country)}
</div>`;

  const regionSelect = html`<div class="field"${geoWrap("region")}${regions.length || !country ? "" : trustedHtml(" hidden")}>
<label for="region">${t("web.profile.region_label")}</label>
<select id="region" name="region"${geoRole("region")}${describedBy("region", false, errors.region)}>
<option value="">${t("web.profile.region_none")}</option>
${regions.map((r) => html`<option value="${r.code}"${sel(r.code === region)}>${r.name}</option>`)}
</select>
${fieldError(t, "region", errors.region)}
</div>`;

  const cityOther = v.city.kind === "other";
  const citySelect = html`<div class="field"${geoWrap("city")}
${hook(JS.cityTexts.other, t("web.profile.city_other"))}${hook(JS.cityTexts.none, t("web.profile.city_no_results"))}${hook(JS.cityTexts.placeholder, t("web.profile.city_search_placeholder"))}>
<label for="city">${t("web.profile.city_label")}</label>
<select id="city" name="city"${geoRole("city")}${describedBy("city", needsRegion, errors.city)}>
<option value=""${sel(!selectedCity && !cityOther)}>${t("web.profile.city_none")}</option>
${cities.map(
  (c) => html`<option value="${c.id}"${hook(JS.cityOptionRegion, c.admin1 ?? "")}${sel(selectedCity?.id === c.id)}>${c.name}${!region && c.admin1 && regions.length ? `, ${regionName(c.admin1)}` : ""}</option>`,
)}
<option value="other"${sel(cityOther)}>${t("web.profile.city_other")}</option>
</select>
${needsRegion ? html`<p class="help" id="city-help"${geoRole("city-hint")}>${t("web.profile.city_pick_region")}</p>` : ""}
${fieldError(t, "city", errors.city)}
</div>`;

  return html`<fieldset${hook(JS.geoForm)}>
<legend>${t("web.profile.location_legend")}</legend>
${countrySelect}
${regionSelect}
${citySelect}
<div class="actions"${geoRole("refresh-row")}><button class="btn btn-small" type="submit" name="action" value="refresh" formnovalidate>${t("web.profile.refresh_lists")}</button></div>
<p class="help">${t("web.profile.location_help")}</p>
<p class="help credit">${tRich(t, "web.profile.geo_credit", { source: GEONAMES })}</p>
</fieldset>`;
}

export function termsCheckbox(t: T, o: { minAge: number; checked: boolean; error?: string }): SafeHtml {
  const sentence = tRich(t, "web.profile.terms_check", {
    age: o.minAge,
    terms: html`<a href="/terms" target="_blank" rel="noopener">${t("web.profile.terms_link")}</a>`,
    privacy: html`<a href="/privacy" target="_blank" rel="noopener">${t("web.profile.privacy_link")}</a>`,
  });
  return html`<div class="field">
<label class="check"><input type="checkbox" name="terms" value="yes" required${o.checked ? trustedHtml(" checked") : ""}${describedBy("terms", false, o.error)}> <span>${sentence}</span></label>
${fieldError(t, "terms", o.error)}
</div>`;
}

/**
 * The first submit button of a form that also has the no-JS "update the lists" button: pressing Enter in a text
 * field uses the form's first submit button, which must be the real "save" and not the refresh.
 */
export function defaultSubmit(): SafeHtml {
  return trustedHtml('<button type="submit" class="default-submit" tabindex="-1" aria-hidden="true"></button>');
}

export function profileScript(src: string): SafeHtml {
  return html`<script src="${src}" defer></script>`;
}

export function hasError(errors: FieldErrors, f: ProfileField): boolean {
  return errors[f] !== undefined;
}
