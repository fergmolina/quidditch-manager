import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import type { Hono } from "hono";
import { escapeHtml, html, trustedHtml, type SafeHtml } from "../http/html.js";
import { page, tOf } from "../http/viewer.js";
import { bcp47, fill, LANGS, type Lang, type T } from "../i18n/i18n.js";
import type { AppEnv } from "../types.js";

export const LEGAL_DIR = fileURLToPath(new URL("../../legal/", import.meta.url));

export const LEGAL_DOCS = ["privacy", "terms"] as const;
export type LegalDoc = (typeof LEGAL_DOCS)[number];

export const CONTROLLER_PLACEHOLDER = "[Operator name]";
export const CONTACT_PLACEHOLDER = "[contact email on the game's domain]";

export interface LegalSettings {
  controller: string | null;
  contactEmail: string | null;
  minAge: number;
}


export function isSafeHref(url: string): boolean {
  if (/[\s\u0000-\u001f\u007f\\]/.test(url)) return false;
  if (url.startsWith("https://")) return url.length > "https://".length;
  if (url.startsWith("mailto:")) return /^mailto:[^@]+@[^@]+$/.test(url);
  return url.startsWith("/") && !url.startsWith("//");
}

const INLINE_RE = /\[([^\]\n]+)\]\(([^)\s]+)\)|\*\*([^*\n]+)\*\*|`([^`\n]+)`/g;

export function renderInline(text: string): string {
  let out = "";
  let last = 0;
  for (const m of text.matchAll(INLINE_RE)) {
    out += escapeHtml(text.slice(last, m.index));
    last = m.index + m[0].length;
    if (m[1] !== undefined && m[2] !== undefined) {
      const label = escapeHtml(m[1]);
      const href = m[2];
      if (!isSafeHref(href)) out += label;
      else if (href.startsWith("https://")) out += `<a href="${escapeHtml(href)}" rel="noopener noreferrer">${label}</a>`;
      else out += `<a href="${escapeHtml(href)}">${label}</a>`;
    } else if (m[3] !== undefined) out += `<strong>${escapeHtml(m[3])}</strong>`;
    else if (m[4] !== undefined) out += `<code>${escapeHtml(m[4])}</code>`;
  }
  return out + escapeHtml(text.slice(last));
}

export function stripComments(src: string): string {
  return src.replace(/<!--[\s\S]*?-->/g, "");
}

export interface ParsedDoc {
  title: string | null;
  body: string;
}

export function renderMarkdown(src: string): ParsedDoc {
  const lines = stripComments(src).replace(/\r\n?/g, "\n").split("\n");
  const out: string[] = [];
  let title: string | null = null;
  let para: string[] = [];
  let note: string[] = [];
  let items: string[] | null = null;

  const flushPara = () => {
    if (para.length) out.push(`<p>${renderInline(para.join(" "))}</p>`);
    para = [];
  };
  const flushNote = () => {
    if (note.length) out.push(`<div class="notice"><p>${renderInline(note.join(" "))}</p></div>`);
    note = [];
  };
  const flushList = () => {
    if (items) out.push(`<ul>${items.map((i) => `<li>${renderInline(i)}</li>`).join("")}</ul>`);
    items = null;
  };
  const flushAll = () => {
    flushPara();
    flushNote();
    flushList();
  };

  for (const rawLine of lines) {
    const line = rawLine.trimEnd();
    const trimmed = line.trim();
    if (trimmed === "") {
      flushAll();
      continue;
    }
    const heading = /^(#{1,3}) +(.+)$/.exec(trimmed);
    if (heading && !line.startsWith(" ")) {
      flushAll();
      const level = heading[1]!.length;
      const text = heading[2]!.trim();
      if (level === 1 && title === null && out.length === 0) title = text;
      else out.push(`<h${Math.max(2, level)}>${renderInline(text)}</h${Math.max(2, level)}>`);
      continue;
    }
    if (/^- +/.test(line)) {
      flushPara();
      flushNote();
      items ??= [];
      items.push(line.replace(/^- +/, "").trim());
      continue;
    }
    if (items && /^ {2,}\S/.test(line)) {
      items[items.length - 1] += " " + trimmed;
      continue;
    }
    if (/^> ?/.test(line)) {
      flushPara();
      flushList();
      note.push(line.replace(/^> ?/, "").trim());
      continue;
    }
    flushList();
    flushNote();
    para.push(trimmed);
  }
  flushAll();
  return { title, body: out.join("\n") };
}

export function legalPath(doc: LegalDoc, lang: Lang, dir = LEGAL_DIR): string {
  return `${dir.endsWith("/") ? dir : dir + "/"}${doc}.${lang}.md`;
}

export function loadLegalSources(dir = LEGAL_DIR): Record<LegalDoc, Partial<Record<Lang, string>>> {
  const out = { privacy: {}, terms: {} } as Record<LegalDoc, Partial<Record<Lang, string>>>;
  for (const doc of LEGAL_DOCS) {
    for (const lang of LANGS) {
      const p = legalPath(doc, lang, dir);
      if (existsSync(p)) out[doc][lang] = readFileSync(p, "utf8");
    }
    if (!out[doc].en) throw new Error(`legal text missing: ${legalPath(doc, "en", dir)}`);
  }
  return out;
}

export function legalParams(s: LegalSettings): Record<string, string> {
  return {
    controller: s.controller ?? CONTROLLER_PLACEHOLDER,
    contact: s.contactEmail ? `[${s.contactEmail}](mailto:${s.contactEmail})` : CONTACT_PLACEHOLDER,
    min_age: String(s.minAge),
  };
}

export function formatVersion(version: string, lang: Lang): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(version)) return version;
  const d = new Date(`${version}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) return version;
  return new Intl.DateTimeFormat(bcp47(lang), { dateStyle: "long", timeZone: "UTC" }).format(d);
}

export interface RenderedLegal {
  title: string;
  textLang: Lang;
  body: SafeHtml;
}

export function renderLegal(
  sources: Record<LegalDoc, Partial<Record<Lang, string>>>,
  doc: LegalDoc,
  lang: Lang,
  o: { t: T; settings: LegalSettings; termsVersion: string; original?: boolean },
): RenderedLegal {
  const translated = o.original ? undefined : sources[doc][lang];
  const textLang: Lang = translated ? lang : "en";
  const src = translated ?? sources[doc].en ?? "";
  const parsed = renderMarkdown(fill(src, legalParams(o.settings)));
  const title = parsed.title ?? (doc === "privacy" ? o.t("web.footer.privacy") : o.t("web.footer.terms"));
  const path = `/${doc}`;
  const missing = !translated && !o.original && lang !== "en";
  const notes: SafeHtml[] = [];
  if (missing) notes.push(html`<div class="notice"><p>${o.t("web.legal.fallback")}</p></div>`);
  if (textLang !== "en") notes.push(html`<p class="muted"><a href="${path}?original=1" hreflang="en">${o.t("web.legal.read_original")}</a></p>`);
  const body = html`<article class="card legal" lang="${bcp47(textLang)}">
<h1>${title}</h1>
<p class="muted" lang="${bcp47(lang)}">${o.t("web.legal.version", { date: formatVersion(o.termsVersion, lang) })}</p>
${notes}
${trustedHtml(parsed.body)}
</article>`;
  return { title, textLang, body };
}

export function registerLegalRoutes(app: Hono<AppEnv>): void {
  const sources = loadLegalSources();
  let warned = false;
  for (const doc of LEGAL_DOCS) {
    app.get(`/${doc}`, async (c) => {
      const { config, log } = c.get("deps");
      if (!warned && config.isProd && (!config.legal.controller || !config.legal.contactEmail)) {
        log.warn("[legal] LEGAL_CONTROLLER / LEGAL_CONTACT_EMAIL are not set: /privacy and /terms show placeholders");
      }
      warned = true;
      const r = renderLegal(sources, doc, c.get("lang"), {
        t: tOf(c),
        settings: { ...config.legal, minAge: config.minAge },
        termsVersion: config.termsVersion,
        original: c.req.query("original") === "1",
      });
      c.header("X-Robots-Tag", "index, follow");
      return page(c, { title: r.title, body: r.body, noindex: false });
    });
  }
}
