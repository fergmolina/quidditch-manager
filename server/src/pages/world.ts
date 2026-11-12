import { html, type SafeHtml } from "../http/html.js";
import type { Lang, T } from "../i18n/i18n.js";
import { clubNotes, displayCity, type Source, type World, type WorldClub, type WorldLeague, type WorldPlayer, type WorldSchool } from "../world/world.js";

/** The public pages of the game's world: /world, /leagues/<slug>, /clubs/<slug>, /schools/<slug>. */

export const leagueName = (t: T, l: WorldLeague): string => t(`comp.${l.id}`);
export const schoolName = (t: T, s: WorldSchool): string => t(`school.${s.id}.name`);
const country = (t: T, id: string): string => t(`country.${id}`);

/** Two colour stripes. An SVG with fill attributes: the page CSP allows no inline styles. */
function swatch(colors: [string, string] | null, label: string): SafeHtml | string {
  if (!colors) return "";
  return html`<svg class="swatch" width="28" height="18" viewBox="0 0 28 18" role="img" aria-label="${label}"><rect width="14" height="18" fill="${colors[0]}"/><rect x="14" width="14" height="18" fill="${colors[1]}"/></svg>`;
}

function sourceTag(t: T, s: Source): SafeHtml {
  return s === "canon" ? html`<span class="tag tag-canon">${t("web.world.source_canon")}</span>` : html`<span class="tag">${t("web.world.source_filler")}</span>`;
}

/** One step of the path from the home page to a world page: shown above the page and sent as a BreadcrumbList. */
export interface Crumb {
  label: string;
  path: string;
}

/** The trail starts at the home page with the words people search for, not the site's name. */
export const worldCrumbs = (t: T): Crumb[] => [
  { label: t("web.nav.home"), path: "/" },
  { label: t("web.world.title"), path: "/world" },
];
export const leagueCrumbs = (t: T, l: WorldLeague): Crumb[] => [...worldCrumbs(t), { label: leagueName(t, l), path: `/leagues/${l.slug}` }];
export const schoolCrumbs = (t: T, s: WorldSchool): Crumb[] => [...worldCrumbs(t), { label: schoolName(t, s), path: `/schools/${s.slug}` }];
export function clubCrumbs(t: T, w: World, c: WorldClub): Crumb[] {
  const league = w.leagues.find((l) => l.id === c.leagueId);
  return [...(league ? leagueCrumbs(t, league) : worldCrumbs(t)), { label: c.name, path: `/clubs/${c.slug}` }];
}

function crumbsNav(t: T, crumbs: Crumb[]): SafeHtml {
  return html`<nav class="crumbs" aria-label="${t("web.nav.breadcrumb")}"><ol>${crumbs.map((c, i) => (i < crumbs.length - 1 ? html`<li><a href="${c.path}">${c.label}</a></li>` : html`<li aria-current="page">${c.label}</li>`))}</ol></nav>`;
}

function cta(t: T, text: string, playHref: string): SafeHtml {
  return html`<section class="card center">
<p>${text}</p>
<div class="actions center"><a class="btn btn-primary" href="${playHref}">${t("web.landing.play")}</a></div>
</section>`;
}

function playersTable(t: T, players: WorldPlayer[]): SafeHtml {
  return html`<table class="world-table players">
<tbody>
${players.map((p) => html`<tr><td>${p.name}</td><td>${t(`pos.${p.position}`)}</td><td class="muted">${p.nationality ? country(t, p.nationality) : ""}</td></tr>
`)}</tbody>
</table>`;
}

export function worldIndexBody(t: T, w: World): SafeHtml {
  const leagues = [...w.leagues].sort((a, b) => leagueName(t, a).localeCompare(leagueName(t, b)));
  const schools = [...w.schools].sort((a, b) => (a.source === b.source ? 0 : a.source === "canon" ? -1 : 1));
  return html`${crumbsNav(t, worldCrumbs(t))}
<section class="card world">
<h1>${t("web.world.title")}</h1>
<p>${t("web.world.intro")}</p>
<h2>${t("web.world.leagues")}</h2>
<ul class="world-list">
${leagues.map((l) => html`<li><a href="/leagues/${l.slug}">${leagueName(t, l)}</a> <span class="muted">${l.countryIds.map((c) => country(t, c)).join(", ")} · ${t("web.world.n_clubs", { n: l.clubIds.length })}</span></li>
`)}</ul>
<h2>${t("web.world.schools")}</h2>
<ul class="world-list">
${schools.map((s) => html`<li><a href="/schools/${s.slug}">${schoolName(t, s)}</a> <span class="muted">${country(t, s.countryId)}</span>${s.source === "filler" ? html` ${sourceTag(t, s.source)}` : ""}</li>
`)}</ul>
</section>`;
}

export function leagueBody(t: T, w: World, l: WorldLeague, lang: Lang, playHref: string): SafeHtml {
  const clubs = l.clubIds.map((id) => w.clubs.get(id)).filter((c): c is WorldClub => !!c);
  clubs.sort((a, b) => b.leagueTitles - a.leagueTitles || a.name.localeCompare(b.name));
  // A league of book clubs gets one label; in a mixed league each book club carries its own.
  const allCanon = clubs.every((c) => c.source === "canon");
  return html`${crumbsNav(t, leagueCrumbs(t, l))}
<section class="card world">
<h1>${leagueName(t, l)}</h1>
${allCanon ? html`<p>${sourceTag(t, "canon")}</p>` : ""}
<p class="muted">${t("web.world.countries")}: ${l.countryIds.map((c) => country(t, c)).join(", ")}</p>
<table class="world-table">
<thead><tr><th>${t("ui.col.club")}</th><th>${t("web.world.city")}</th><th class="num">${t("ui.founded")}</th><th class="num">${t("ui.league_titles")}</th></tr></thead>
<tbody>
${clubs.map((c) => html`<tr><td>${swatch(c.colors, t("web.world.colors"))} <a href="/clubs/${c.slug}">${c.name}</a>${c.source === "canon" && !allCanon ? html` ${sourceTag(t, c.source)}` : ""}</td><td>${displayCity(w, c, lang, t)}</td><td class="num">${c.founded > 0 ? c.founded : "—"}</td><td class="num">${c.leagueTitles}</td></tr>
`)}</tbody>
</table>
</section>
${cta(t, t("web.landing.pitch"), playHref)}`;
}

export function clubBody(t: T, w: World, c: WorldClub, lang: Lang, playHref: string): SafeHtml {
  const league = w.leagues.find((l) => l.id === c.leagueId);
  const rivals = c.rivalIds.map((id) => w.clubs.get(id)).filter((r): r is WorldClub => !!r);
  const facts: [string, SafeHtml | string][] = [[t("web.world.city"), displayCity(w, c, lang, t)]];
  if (league) facts.push([t("web.world.league"), html`<a href="/leagues/${league.slug}">${leagueName(t, league)}</a>`]);
  if (c.founded > 0) facts.push([t("ui.founded"), String(c.founded)]);
  facts.push([t("ui.league_titles"), String(c.leagueTitles)]);
  if (c.europeanCups > 0) facts.push([t("ui.european_cups"), String(c.europeanCups)]);
  facts.push([t("web.world.colors"), swatch(c.colors, t("web.world.colors"))]);
  if (c.manager) facts.push([t("web.world.manager"), c.manager]);
  if (rivals.length) facts.push([t("web.world.rivals"), html`${rivals.map((r, i) => html`${i ? ", " : ""}<a href="/clubs/${r.slug}">${r.name}</a>`)}`]);
  return html`${crumbsNav(t, clubCrumbs(t, w, c))}
<section class="card world">
<h1>${swatch(c.colors, t("web.world.colors"))} ${c.name}</h1>
<p>${sourceTag(t, c.source)}</p>
<dl class="facts">
${facts.map(([k, v]) => html`<dt>${k}</dt><dd>${v}</dd>
`)}</dl>
${clubNotes(c, t).map((n) => html`<p>${n}</p>
`)}${c.source === "filler" ? html`<p class="muted">${t("web.world.club_filler_note")}</p>` : ""}
${c.players.length ? html`<h2>${t("web.world.canon_players")}</h2>
${playersTable(t, c.players)}` : ""}
</section>
${cta(t, t("web.world.club_cta", { club: c.name }), playHref)}`;
}

export function schoolBody(t: T, s: WorldSchool, playHref: string): SafeHtml {
  return html`${crumbsNav(t, schoolCrumbs(t, s))}
<section class="card world">
<h1>${schoolName(t, s)}</h1>
<p class="muted">${t("web.world.country")}: ${country(t, s.countryId)}</p>
<p>${sourceTag(t, s.source)}</p>
${s.source === "filler" ? html`<p class="muted">${t("web.world.school_filler_note")}</p>` : ""}
<h2>${t("web.world.houses")}</h2>
${s.houses.map((h) => html`<h3>${swatch(h.colors, t("web.world.colors"))} ${t(`house.${h.name}`)}</h3>
${h.students.length ? playersTable(t, h.students) : ""}
`)}
</section>
${cta(t, t("web.world.school_cta", { school: schoolName(t, s) }), playHref)}`;
}
