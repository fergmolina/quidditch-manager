import { html, trustedHtml, type HtmlValue, type SafeHtml } from "../http/html.js";
import { computeAssetVersion } from "../http/static.js";
import { seoHead, OG_IMAGE, type SeoMeta } from "../http/seo.js";
import { bcp47, LANG_NATIVE_NAMES, LANGS, type Lang, type T } from "../i18n/i18n.js";

/** Cache-busting hash of the static files; fixed for the life of the process, like the files it covers. */
export const ASSET_VERSION = computeAssetVersion();

export function staticUrl(path: string): string {
  return `/static/${path}?v=${ASSET_VERSION}`;
}

export interface LayoutViewer {
  username: string | null;
}

export interface LayoutOptions {
  lang: Lang;
  t: T;
  title: string;
  body: HtmlValue;
  currentUrl: string;
  viewer: LayoutViewer | null;
  head?: HtmlValue;
  noindex?: boolean;
  bare?: boolean;
  /** Indexable page: description, canonical, hreflang alternates, Open Graph and JSON-LD. */
  seo?: SeoMeta;
  /** Absolute origin for the canonical and Open Graph URLs (config.siteUrl). */
  siteUrl?: string;
  /** The title already names the game: no " · Quidditch Manager" suffix. */
  titleAbsolute?: boolean;
}

export function withLang(currentUrl: string, lang: Lang): string {
  const u = new URL(currentUrl, "http://x");
  u.searchParams.set("lang", lang);
  return `${u.pathname}${u.search}`;
}

export function layout(o: LayoutOptions): SafeHtml {
  const { t, lang } = o;
  const app = t("ui.app_title");
  const title = o.titleAbsolute || o.title === app ? o.title : `${o.title} · ${app}`;
  const seo = o.seo
    ? seoHead({ siteUrl: o.siteUrl ?? "", lang, title, siteName: app, imageUrl: `${o.siteUrl ?? ""}${staticUrl(OG_IMAGE.path)}`, imageAlt: t("web.og.image_alt"), meta: o.seo })
    : "";
  const nav = o.bare
    ? null
    : o.viewer
      ? html`<a href="/ranking">${t("web.nav.ranking")}</a>
          <a href="/play/">${t("web.nav.play")}</a>
          <a href="/account">${o.viewer.username ? "@" + o.viewer.username : t("web.nav.account")}</a>
          <form method="post" action="/auth/logout"><button type="submit" class="linklike">${t("web.nav.sign_out")}</button></form>`
      : html`<a href="/ranking">${t("web.nav.ranking")}</a>
          <a href="/login">${t("web.nav.sign_in")}</a>`;
  const langs = LANGS.map(
    (l) => html`<li><a href="${withLang(o.currentUrl, l)}" hreflang="${bcp47(l)}" lang="${bcp47(l)}"${l === lang ? trustedHtml(' aria-current="true"') : ""}>${LANG_NATIVE_NAMES[l]}</a></li>`,
  );
  return html`<!doctype html>
<html lang="${bcp47(lang)}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
${o.noindex ? trustedHtml('<meta name="robots" content="noindex, nofollow">\n') : ""}<title>${title}</title>
<link rel="stylesheet" href="${staticUrl("site.css")}">
<link rel="icon" type="image/png" href="${staticUrl("icon.png")}">
${seo}${o.head ?? ""}
</head>
<body>
<header class="bar">
<a class="brand" href="/">${app}</a>
<nav>${nav}</nav>
</header>
<main>
${o.body}
</main>
<footer>
<nav aria-label="${t("web.lang.switch")}"><ul class="langs">${langs}</ul></nav>
<p><a href="/faq">${t("web.nav.faq")}</a> · <a href="/privacy">${t("web.footer.privacy")}</a> · <a href="/terms">${t("web.footer.terms")}</a> · <a href="/feedback">${t("web.footer.feedback")}</a></p>
<p>${t("web.footer.fan_project")}</p>
</footer>
</body>
</html>
`;
}

export function messageCard(o: { title: string; paragraphs: HtmlValue[]; actions?: HtmlValue; tone?: "error" | "ok" }): SafeHtml {
  return html`<section class="card">
<h1>${o.title}</h1>
${o.paragraphs.map((p) => html`<p>${p}</p>`)}
${o.actions ? html`<div class="actions">${o.actions}</div>` : ""}
</section>`;
}
