import shared from "../../../data/shared/map.json" with { type: "json" };
import { html, type SafeHtml } from "../http/html.js";
import { bcp47, type Lang, type T } from "../i18n/i18n.js";
import type { CountryRow, RankingRow } from "../career/ranking.js";
import { countryName } from "../profile/countries.js";
import { countryCentroid } from "../profile/geo.js";
import { staticUrl } from "./layout.js";

export interface RankingState {
  rows: RankingRow[];
  countries: string[];
  country: string | null;
  viewerId: string | null;
  lang: Lang;
  view: "list" | "map";
  countryRows: CountryRow[];
}

type Frame = (typeof shared.maps)[keyof typeof shared.maps];
// The images are the frame rasterised at a whole pixel height (tools/make_map.py), so pins use the rounded height.
const frame = ({ lon0, lon1, lat0, lat1, w, h }: Frame, img: string) => ({ lon0, lon1, lat0, lat1, w, h: Math.round(h), img });

export const MAPS = {
  world: frame(shared.maps.world, "map_world.jpg"),
  europe: frame(shared.maps.europe, "map_europe.jpg"),
};
export type MapName = keyof typeof MAPS;
export const MAP_W = MAPS.world.w;
export const MAP_H = MAPS.world.h;

export function mapXY(lat: number, lon: number, map: MapName = "world"): { x: number; y: number } {
  const m = MAPS[map];
  const l = map === "world" && lon < m.lon0 ? lon + 360 : lon;
  const x = ((l - m.lon0) / (m.lon1 - m.lon0)) * m.w;
  const y = ((m.lat1 - Math.max(m.lat0, Math.min(m.lat1, lat))) / (m.lat1 - m.lat0)) * m.h;
  return { x: Math.round(x * 10) / 10, y: Math.round(y * 10) / 10 };
}

export function onMap(lat: number, lon: number, map: MapName): boolean {
  const m = MAPS[map];
  return lat >= m.lat0 && lat <= m.lat1 && lon >= m.lon0 && lon <= m.lon1;
}

function tabs(t: T, s: RankingState): SafeHtml {
  const q = s.country ? `&country=${s.country}` : "";
  return html`<nav class="rank-tabs" aria-label="${t("web.ranking.title")}">
<a href="/ranking?view=list${q}"${s.view === "list" ? html` aria-current="page"` : ""}>${t("web.ranking.view_list")}</a>
<a href="/ranking?view=map"${s.view === "map" ? html` aria-current="page"` : ""}>${t("web.ranking.view_map")}</a>
</nav>`;
}

export function rankingMapBody(t: T, s: RankingState): SafeHtml {
  const nf = new Intl.NumberFormat(bcp47(s.lang));
  const placed = s.countryRows
    .map((r) => ({ r, at: countryCentroid(r.country_code) }))
    .filter((p) => p.at !== null)
    // Biggest first, so smaller seals are drawn on top and stay clickable.
    .sort((a, b) => b.r.managers - a.r.managers);
  const svg = (map: MapName, label: string) => {
    const m = MAPS[map];
    const scale = m.h / MAPS.world.h;
    const pins = placed
      .filter((p) => (map === "europe") === onMap(p.at!.lat, p.at!.lon, "europe"))
      .map(({ r, at }) => {
        const { x, y } = mapXY(at!.lat, at!.lon, map);
        const rad = Math.round((15 + 10 * Math.sqrt(r.managers)) * scale * 10) / 10;
        const title = t(r.managers === 1 ? "web.ranking.pin_one" : "web.ranking.pin_many", {
          country: countryName(r.country_code, s.lang), n: r.managers, user: r.best_username, rep: nf.format(r.best_reputation),
        });
        return html`<a href="/ranking?view=list&amp;country=${r.country_code}" class="rank-pin"><title>${title}</title><circle cx="${x}" cy="${y}" r="${rad}"></circle><text x="${x}" y="${y}" dy="0.35em" font-size="${Math.round(24 * scale)}">${r.managers}</text></a>`;
      });
    return html`<svg class="rank-map rank-map-${map}" viewBox="0 0 ${m.w} ${m.h}" role="img" aria-label="${label}">
<image href="${staticUrl(m.img)}" x="0" y="0" width="${m.w}" height="${m.h}"></image>
${pins}
</svg>`;
  };
  const table = s.countryRows.map(
    (r, i) => html`<tr>
<td class="num">${i + 1}</td>
<td><a href="/ranking?view=list&amp;country=${r.country_code}">${flag(r.country_code)} ${countryName(r.country_code, s.lang)}</a></td>
<td class="num">${r.managers}</td>
<td>${r.best_username}</td>
<td class="num">${nf.format(r.best_reputation)}</td>
<td class="num">${nf.format(r.avg_reputation)}</td>
</tr>`,
  );
  return html`<section class="card ranking ranking-wide">
<h1>${t("web.ranking.title")}</h1>
${tabs(t, s)}
<p class="muted">${t("web.ranking.map_hint")}</p>
<div class="rank-maps">
${svg("world", t("web.ranking.view_map"))}
${svg("europe", t("web.ranking.view_map") + " · Europe")}
</div>
${
  s.countryRows.length === 0
    ? html`<p>${t("web.ranking.empty")}</p>`
    : html`<table>
<thead><tr><th class="num">#</th><th>${t("web.ranking.col_country")}</th><th class="num">${t("web.ranking.col_managers")}</th><th>${t("web.ranking.col_best")}</th><th class="num">${t("web.ranking.col_reputation")}</th><th class="num">${t("web.ranking.col_average")}</th></tr></thead>
<tbody>
${table}
</tbody>
</table>`
}
<p class="muted">${t("web.ranking.note")}</p>
</section>`;
}

/** A regional-indicator flag for an ISO country code (Kosovo's XK has none, so it shows nothing). */
export function flag(code: string | null): string {
  if (!code || !/^[A-Z]{2}$/.test(code) || code === "XK") return "";
  return String.fromCodePoint(...[...code].map((ch) => 0x1f1e6 + ch.charCodeAt(0) - 65));
}

export function rankingBody(t: T, s: RankingState): SafeHtml {
  const collator = new Intl.Collator(bcp47(s.lang));
  const options = s.countries
    .map((code) => ({ code, name: countryName(code, s.lang) }))
    .sort((a, b) => collator.compare(a.name, b.name));
  const nf = new Intl.NumberFormat(bcp47(s.lang));
  const rows = s.rows.map(
    (r, i) => html`<tr${r.user_id === s.viewerId ? html` class="you"` : ""}>
<td class="num">${i + 1}</td>
<td><strong>${r.username}</strong>${r.club_name ? html`<br><span class="muted">${r.club_name} · ${r.last_season}-${String((r.last_season + 1) % 100).padStart(2, "0")}</span>` : ""}</td>
<td>${flag(r.country_code)} ${r.country_code ? countryName(r.country_code, s.lang) : ""}</td>
<td class="num">${nf.format(r.reputation)}</td>
<td class="num">${r.titles}</td>
<td class="num">${r.seasons}</td>
</tr>`,
  );
  return html`<section class="card ranking">
<h1>${t("web.ranking.title")}</h1>
${tabs(t, s)}
<p class="muted">${t("web.ranking.intro")}</p>
<form method="get" action="/ranking" class="ranking-filter">
<input type="hidden" name="view" value="list">
<label for="country">${t("web.ranking.country")}</label>
<select id="country" name="country">
<option value=""${s.country ? "" : html` selected`}>${t("web.ranking.all_countries")}</option>
${options.map((o) => html`<option value="${o.code}"${o.code === s.country ? html` selected` : ""}>${o.name}</option>`)}
</select>
<button type="submit" class="btn">${t("web.ranking.show")}</button>
</form>
${
  s.rows.length === 0
    ? html`<p>${t("web.ranking.empty")}</p>`
    : html`<table>
<thead><tr><th class="num">#</th><th>${t("web.ranking.col_manager")}</th><th>${t("web.ranking.col_country")}</th><th class="num">${t("web.ranking.col_reputation")}</th><th class="num">${t("web.ranking.col_titles")}</th><th class="num">${t("web.ranking.col_seasons")}</th></tr></thead>
<tbody>
${rows}
</tbody>
</table>`
}
<p class="muted">${t("web.ranking.note")}</p>
</section>`;
}
