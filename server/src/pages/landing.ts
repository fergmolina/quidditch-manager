import { html, type SafeHtml } from "../http/html.js";
import { bcp47, LANGS, type T } from "../i18n/i18n.js";
import { staticUrl } from "./layout.js";

export interface LandingState {
  playHref: string;
  downloadsUrl: string | null;
}

export const FEATURES = ["world", "schools", "players", "matches", "manager", "langs"] as const;

/** Captures of the game (docs/screenshots, resized to WebP by tools/make_site_images.sh). */
const SHOTS = [
  { file: "shot-match.webp", key: "web.landing.shot_match" },
  { file: "shot-squad.webp", key: "web.landing.shot_squad" },
  { file: "shot-hogwarts.webp", key: "web.landing.shot_hogwarts" },
] as const;
const SHOT_SIZE = { width: 960, height: 576 };

export function landingBody(t: T, s: LandingState): SafeHtml {
  return html`<section class="card center">
<div class="hero"><img class="logo" src="${staticUrl("logo.png")}" alt="${t("ui.app_title")}" width="420" height="210"></div>
<h1 class="lead">${t("ui.app_subtitle")}</h1>
<p>${t("web.landing.pitch")}</p>
<div class="actions center"><a class="btn btn-primary" href="${s.playHref}">${t("web.landing.play")}</a></div>
<p class="muted">${t("web.landing.account_note")}</p>
${s.downloadsUrl ? html`<p class="muted"><a href="${s.downloadsUrl}" rel="noopener">${t("web.landing.desktop")}</a></p>` : ""}
<p class="muted"><a href="/feedback">${t("web.landing.feedback")}</a></p>
</section>
<section class="card features">
<h2>${t("web.landing.features_title")}</h2>
${FEATURES.map((f) => html`<h3>${t(`web.landing.f_${f}_title`)}</h3>
<p>${t(`web.landing.f_${f}_text`)}</p>
`)}
</section>
<section class="card shots">
${SHOTS.map(
  (shot, i) => html`<figure><img src="${staticUrl(shot.file)}" alt="${t(shot.key)}" width="${SHOT_SIZE.width}" height="${SHOT_SIZE.height}"${i ? html` loading="lazy"` : ""}><figcaption>${t(shot.key)}</figcaption></figure>
`,
)}
</section>
<section class="card saves">
<h2>${t("web.landing.saves_title")}</h2>
<ul>
<li>${t("web.landing.saves_where")}</li>
<li>${t("web.landing.saves_lost")}</li>
<li>${t("web.landing.saves_export")}</li>
</ul>
<p><a href="/faq">${t("web.landing.faq_link")}</a></p>
</section>`;
}

/** schema.org for the home page: the site and the game it is about. */
export function landingJsonLd(t: T, o: { siteUrl: string; downloadsUrl: string | null; imageUrl: string }): Record<string, unknown>[] {
  const name = t("ui.app_title");
  return [
    { "@context": "https://schema.org", "@type": "WebSite", name, url: `${o.siteUrl}/`, inLanguage: LANGS.map(bcp47) },
    {
      "@context": "https://schema.org",
      "@type": "VideoGame",
      name,
      url: `${o.siteUrl}/`,
      description: t("web.seo.home_description"),
      image: o.imageUrl,
      genre: ["Sports management", "Simulation"],
      gamePlatform: ["Web browser", "Windows", "macOS"],
      applicationCategory: "GameApplication",
      operatingSystem: "Web browser, Windows, macOS",
      inLanguage: LANGS.map(bcp47),
      isAccessibleForFree: true,
      offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
      ...(o.downloadsUrl ? { downloadUrl: o.downloadsUrl } : {}),
    },
  ];
}
