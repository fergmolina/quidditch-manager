import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { test } from "node:test";
import { createApp } from "../src/app.js";
import { escapeHtml } from "../src/http/html.js";
import { LANGS, placeholders, translator, type Lang } from "../src/i18n/i18n.js";
import {
  CONTACT_PLACEHOLDER,
  CONTROLLER_PLACEHOLDER,
  formatVersion,
  isSafeHref,
  LEGAL_DOCS,
  legalPath,
  loadLegalSources,
  renderInline,
  renderLegal,
  renderMarkdown,
  stripComments,
  type LegalSettings,
} from "../src/pages/legal.js";
import { testDeps } from "./helpers.js";

const t = translator("en");
const unset: LegalSettings = { controller: null, contactEmail: null, minAge: 13 };

test("renderInline escapes text and allows only https, mailto and same-site links", () => {
  assert.equal(renderInline("a <script>alert(1)</script> & b"), "a &lt;script&gt;alert(1)&lt;/script&gt; &amp; b");
  assert.equal(renderInline("**bold** and `code`"), "<strong>bold</strong> and <code>code</code>");
  assert.equal(renderInline("[x](https://e.example/a?b=1&c=2)"), '<a href="https://e.example/a?b=1&amp;c=2" rel="noopener noreferrer">x</a>');
  assert.equal(renderInline("[acct](/account)"), '<a href="/account">acct</a>');
  assert.equal(renderInline("[m](mailto:a@b.example)"), '<a href="mailto:a@b.example">m</a>');
  for (const bad of ["javascript:alert(1)", "//evil.example", "http://plain.example", "/\\evil", "data:text/html,x"]) {
    assert.equal(isSafeHref(bad), false, bad);
    const out = renderInline(`[click](${bad})`);
    assert.ok(out.startsWith("click") && !out.includes("<a"), bad);
  }
  assert.equal(renderInline('[<b>"x"</b>](/a)'), '<a href="/a">&lt;b&gt;&quot;x&quot;&lt;/b&gt;</a>');
  assert.equal(renderInline("[Operator name] and [contact email]"), "[Operator name] and [contact email]");
});

test("renderMarkdown: title, headings, lists with continuation lines, notes, paragraphs, comments", () => {
  const md = [
    "<!-- a comment {nope}",
    "spanning lines -->",
    "# The title",
    "",
    "> A note",
    "> continued.",
    "",
    "## Section <one>",
    "",
    "First line",
    "second line.",
    "",
    "- item **one**",
    "  continues here",
    "- item two",
    "### Sub",
    "<img src=x onerror=alert(1)>",
  ].join("\n");
  const r = renderMarkdown(md);
  assert.equal(r.title, "The title");
  assert.equal(
    r.body,
    [
      '<div class="notice"><p>A note continued.</p></div>',
      "<h2>Section &lt;one&gt;</h2>",
      "<p>First line second line.</p>",
      "<ul><li>item <strong>one</strong> continues here</li><li>item two</li></ul>",
      "<h3>Sub</h3>",
      "<p>&lt;img src=x onerror=alert(1)&gt;</p>",
    ].join("\n"),
  );
  assert.equal(stripComments("a<!-- x -->b"), "ab");
});

test("GET /privacy shows the controller and contact from config.legal, placeholders while unset", async () => {
  const set = await (await createApp(testDeps({ config: { legal: { controller: "Example Org", contactEmail: "privacy@game.example" } } })).request("/privacy")).text();
  assert.ok(set.includes("Example Org"));
  assert.ok(set.includes('<a href="mailto:privacy@game.example">privacy@game.example</a>'));
  const placeholder = await (await createApp(testDeps()).request("/privacy")).text();
  assert.ok(placeholder.includes(escapeHtml(CONTROLLER_PLACEHOLDER)) && placeholder.includes(escapeHtml(CONTACT_PLACEHOLDER)));
});

test("formatVersion localizes ISO dates and leaves other version strings alone", () => {
  assert.equal(formatVersion("2026-11-01", "en"), "November 1, 2026");
  assert.equal(formatVersion("2026-11-01", "de"), "1. November 2026");
  assert.equal(formatVersion("2026-11-01", "ja"), "2026年11月1日");
  assert.equal(formatVersion("v2", "en"), "v2");
});

function shape(src: string) {
  const body = stripComments(src);
  const lines = body.split("\n");
  return {
    h1: lines.filter((l) => /^# /.test(l)).length,
    h2: lines.filter((l) => /^## /.test(l)).length,
    h3: lines.filter((l) => /^### /.test(l)).length,
    items: lines.filter((l) => /^- /.test(l)).length,
    placeholders: placeholders(body),
    links: [...body.matchAll(/\]\(([^)\s]+)\)/g)].map((m) => m[1]).sort(),
    cookies: [...body.matchAll(/`([^`]+)`/g)].map((m) => m[1]).sort(),
  };
}

test("every legal text exists in all 10 languages, with the same structure as the English original", () => {
  for (const doc of LEGAL_DOCS) {
    const en = readFileSync(legalPath(doc, "en"), "utf8");
    const want = shape(en);
    assert.equal(want.h1, 1, `${doc}.en has one title`);
    for (const lang of LANGS) {
      const p = legalPath(doc, lang);
      assert.ok(existsSync(p), `missing ${p}`);
      if (lang === "en") continue;
      const got = shape(readFileSync(p, "utf8"));
      assert.deepEqual(got, want, `${doc}.${lang} differs in structure from ${doc}.en`);
    }
  }
});

test("the privacy policy names every processor, both legal bases and the retention numbers in every language", () => {
  const sources = loadLegalSources();
  for (const lang of LANGS) {
    const src = sources.privacy[lang] ?? "";
    for (const name of ["Hetzner", "Cloudflare", "Resend", "Google", "Backblaze", "Telegram", "GeoNames"]) {
      assert.ok(src.includes(name), `privacy.${lang} does not mention ${name}`);
    }
    assert.ok(src.includes("6(1)(b)") && src.includes("6(1)(f)"), `privacy.${lang}: legal bases`);
    for (const n of ["30", "180", "45", "15", "10"]) assert.ok(src.includes(n), `privacy.${lang}: missing the number ${n}`);
  }
});

test("renderLegal: placeholders filled, version shown, English fallback and the link to the original", () => {
  const sources = loadLegalSources();
  for (const doc of LEGAL_DOCS) {
    for (const lang of LANGS) {
      const r = renderLegal(sources, doc, lang, { t: translator(lang), settings: unset, termsVersion: "2026-11-01" });
      const out = String(r.body);
      assert.equal(r.textLang, lang);
      assert.ok(!/\{[a-z_]+\}/.test(out), `${doc}.${lang}: unfilled placeholder`);
      assert.ok(out.includes(escapeHtml(CONTROLLER_PLACEHOLDER)), `${doc}.${lang}: controller placeholder`);
      assert.ok(out.includes(escapeHtml(CONTACT_PLACEHOLDER)), `${doc}.${lang}: contact placeholder`);
      assert.ok(out.includes("13"), `${doc}.${lang}: minimum age`);
      assert.equal(out.includes(`/${doc}?original=1`), lang !== "en", `${doc}.${lang}: link to the original`);
      assert.ok(!out.includes("<script"), `${doc}.${lang}: no script`);
      assert.ok(r.title.length > 0 && !r.title.includes("#"));
    }
  }
  const set = renderLegal(sources, "privacy", "es", {
    t,
    settings: { controller: "Example Org", contactEmail: "privacy@game.example", minAge: 13 },
    termsVersion: "2026-11-01",
  });
  const out = String(set.body);
  assert.ok(out.includes("Example Org"));
  assert.ok(out.includes('<a href="mailto:privacy@game.example">privacy@game.example</a>'));
  assert.ok(!out.includes(escapeHtml(CONTACT_PLACEHOLDER)));

  const original = renderLegal(sources, "terms", "ja", { t, settings: unset, termsVersion: "v2", original: true });
  assert.equal(original.textLang, "en");
  assert.ok(String(original.body).includes('lang="en"'));
  assert.ok(!String(original.body).includes("?original=1"));

  const partial = { privacy: { en: sources.privacy.en }, terms: { en: sources.terms.en } };
  const fb = renderLegal(partial, "privacy", "de" as Lang, { t: translator("de"), settings: unset, termsVersion: "2026-11-01" });
  assert.equal(fb.textLang, "en");
  assert.ok(String(fb.body).includes(translator("de")("web.legal.fallback")));
});

test("GET /privacy and /terms: 200, strict CSP, page language, indexable, no account lookup without a cookie", async () => {
  const app = createApp(testDeps());
  for (const doc of LEGAL_DOCS) {
    const res = await app.request(`/${doc}?lang=de`);
    assert.equal(res.status, 200);
    assert.match(res.headers.get("content-security-policy") ?? "", /script-src 'self'/);
    assert.equal(res.headers.get("x-robots-tag"), "index, follow");
    assert.equal(res.headers.get("cache-control"), "private, no-store");
    const body = await res.text();
    assert.match(body, /<html lang="de">/);
    assert.match(body, /<article class="card legal" lang="de">/);
    assert.ok(!body.includes('name="robots"'));
    assert.ok(!/<script/i.test(body));
    const orig = await (await app.request(`/${doc}?original=1`, { headers: { Cookie: "qm_lang=fr" } })).text();
    assert.match(orig, /<html lang="fr">/);
    assert.match(orig, /<article class="card legal" lang="en">/);
  }
});
