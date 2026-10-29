import type { Hono } from "hono";
import { html, trustedHtml, type SafeHtml } from "./html.js";
import { bcp47, DEFAULT_LANG, LANGS, type Lang } from "../i18n/i18n.js";
import type { AppEnv } from "../types.js";

/**
 * Search-engine plumbing for the public pages. One URL per language: the default language (English) lives at the bare
 * path, the others at `?lang=xx` (the query that also sets the language cookie). A page links its canonical (the URL
 * of the language it was rendered in, whatever picked that language) and every language as an hreflang alternate,
 * with the bare path as x-default.
 */

/** The pages search engines may index, in sitemap order. Everything else sends `noindex` (page() and security.ts). */
export const INDEXABLE_PATHS = ["/", "/faq", "/ranking", "/privacy", "/terms"] as const;

/** Paths kept out of crawlers' way; /admin is left out on purpose: listing it would advertise it (it 404s). */
const ROBOTS_DISALLOW = ["/account", "/api/", "/auth/", "/login", "/register", "/pending", "/play/"];

export const OG_IMAGE = { path: "og.jpg", width: 1200, height: 630 } as const;

const OG_LOCALE: Record<Lang, string> = {
  es: "es_ES",
  en: "en_US",
  de: "de_DE",
  fr: "fr_FR",
  it: "it_IT",
  pt_BR: "pt_BR",
  nl: "nl_NL",
  ru: "ru_RU",
  ja: "ja_JP",
  zh_CN: "zh_CN",
};

/** The URL of `path` in `lang` (absolute when `siteUrl` is given). */
export function langUrl(path: string, lang: Lang, siteUrl = ""): string {
  return lang === DEFAULT_LANG ? `${siteUrl}${path}` : `${siteUrl}${path}?lang=${lang}`;
}

export interface SeoMeta {
  /** One of INDEXABLE_PATHS. */
  path: string;
  /** ≤ 160 characters: results pages and link previews cut the rest. None: the engines pick a snippet. */
  description?: string;
  /** schema.org objects, written as JSON-LD. */
  jsonLd?: Record<string, unknown>[];
}

/** JSON for a `<script type="application/ld+json">`: `<` is escaped so data can never close the tag. */
export function jsonLdText(data: unknown): string {
  return JSON.stringify(data).replace(/</g, "\\u003c");
}

export interface SeoHeadInput {
  siteUrl: string;
  lang: Lang;
  title: string;
  siteName: string;
  imageUrl: string;
  imageAlt: string;
  meta: SeoMeta;
}

export function seoHead(o: SeoHeadInput): SafeHtml {
  const { siteUrl, lang, meta } = o;
  const canonical = langUrl(meta.path, lang, siteUrl);
  const alternates = LANGS.map((l) => html`<link rel="alternate" hreflang="${bcp47(l)}" href="${langUrl(meta.path, l, siteUrl)}">\n`);
  const ld = meta.jsonLd?.length ? trustedHtml(`<script type="application/ld+json">${jsonLdText(meta.jsonLd.length === 1 ? meta.jsonLd[0] : meta.jsonLd)}</script>\n`) : "";
  const description = meta.description ? html`<meta name="description" content="${meta.description}">\n` : "";
  const ogDescription = meta.description ? html`<meta property="og:description" content="${meta.description}">\n` : "";
  const twDescription = meta.description ? html`<meta name="twitter:description" content="${meta.description}">\n` : "";
  return html`${description}<link rel="canonical" href="${canonical}">
${alternates}<link rel="alternate" hreflang="x-default" href="${siteUrl}${meta.path}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="${o.siteName}">
<meta property="og:title" content="${o.title}">
${ogDescription}<meta property="og:url" content="${canonical}">
<meta property="og:locale" content="${OG_LOCALE[lang]}">
<meta property="og:image" content="${o.imageUrl}">
<meta property="og:image:width" content="${OG_IMAGE.width}">
<meta property="og:image:height" content="${OG_IMAGE.height}">
<meta property="og:image:alt" content="${o.imageAlt}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${o.title}">
${twDescription}<meta name="twitter:image" content="${o.imageUrl}">
${ld}`;
}

export function robotsTxt(siteUrl: string): string {
  return ["User-agent: *", "Allow: /", ...ROBOTS_DISALLOW.map((p) => `Disallow: ${p}`), "", `Sitemap: ${siteUrl}/sitemap.xml`, ""].join("\n");
}

/** Every indexable page in every language, each entry listing all its alternates (what Google asks of a sitemap). */
export function sitemapXml(siteUrl: string): string {
  const esc = (s: string) => s.replace(/&/g, "&amp;");
  const alternates = (path: string) =>
    [...LANGS.map((l) => `    <xhtml:link rel="alternate" hreflang="${bcp47(l)}" href="${esc(langUrl(path, l, siteUrl))}"/>`), `    <xhtml:link rel="alternate" hreflang="x-default" href="${esc(siteUrl + path)}"/>`].join("\n");
  const urls = INDEXABLE_PATHS.flatMap((path) => LANGS.map((l) => `  <url>\n    <loc>${esc(langUrl(path, l, siteUrl))}</loc>\n${alternates(path)}\n  </url>`));
  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${urls.join("\n")}
</urlset>
`;
}

const PUBLIC_HOUR = "public, max-age=3600";

export function registerSeoRoutes(app: Hono<AppEnv>): void {
  app.get("/robots.txt", (c) => {
    c.header("Cache-Control", PUBLIC_HOUR);
    return c.text(robotsTxt(c.get("deps").config.siteUrl));
  });
  app.get("/sitemap.xml", (c) => {
    c.header("Cache-Control", PUBLIC_HOUR);
    c.header("Content-Type", "application/xml; charset=utf-8");
    return c.body(sitemapXml(c.get("deps").config.siteUrl));
  });
  // IndexNow (Bing, Yandex, Seznam, Naver; Bing feeds ChatGPT search, Copilot and DuckDuckGo): the engines check that
  // /<key>.txt holds the key before taking a submission (deploy/indexnow.sh). The key is public by design.
  app.get("/:file{[^/]+\\.txt}", (c) => {
    const key = c.get("deps").config.indexNowKey;
    if (!key || c.req.param("file") !== `${key}.txt`) return c.notFound();
    c.header("Cache-Control", PUBLIC_HOUR);
    return c.text(key);
  });
}
