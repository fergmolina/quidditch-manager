import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp } from "../src/app.js";
import { INDEXABLE_PATHS, jsonLdText, robotsTxt, sitemapXml } from "../src/http/seo.js";
import { LANGS } from "../src/i18n/i18n.js";
import { SITE, testDeps } from "./helpers.js";

function jsonLd(body: string): unknown[] {
  return [...body.matchAll(/<script type="application\/ld\+json">(.*?)<\/script>/gs)].map((m) => JSON.parse(m[1]!));
}

test("robots.txt: public, points at the sitemap, keeps accounts and the game out", async () => {
  const res = await createApp(testDeps()).request("/robots.txt");
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("cache-control"), "public, max-age=3600");
  const body = await res.text();
  assert.equal(body, robotsTxt(SITE));
  assert.match(body, /^User-agent: \*\nAllow: \/\n/);
  for (const p of ["/account", "/api/", "/auth/", "/play/"]) assert.match(body, new RegExp(`^Disallow: ${p}$`, "m"));
  assert.doesNotMatch(body, /admin/, "never advertised");
  assert.match(body, new RegExp(`^Sitemap: ${SITE}/sitemap.xml$`, "m"));
});

test("sitemap.xml: every indexable page in every language, each with all its alternates and x-default", async () => {
  const res = await createApp(testDeps()).request("/sitemap.xml");
  assert.equal(res.status, 200);
  assert.match(res.headers.get("content-type") ?? "", /^application\/xml/);
  const body = await res.text();
  assert.equal(body, sitemapXml(SITE));
  assert.equal(body.match(/<url>/g)?.length, INDEXABLE_PATHS.length * LANGS.length);
  assert.match(body, new RegExp(`<loc>${SITE}/</loc>`));
  assert.match(body, new RegExp(`<loc>${SITE}/faq\\?lang=pt_BR</loc>`));
  assert.equal(body.match(/hreflang="x-default"/g)?.length, INDEXABLE_PATHS.length * LANGS.length);
  assert.doesNotMatch(body, /\/play\/|\/account|\/login/);
});

test("home: indexable, canonical and hreflang alternates, Open Graph, VideoGame JSON-LD", async () => {
  const res = await createApp(testDeps()).request("/");
  assert.equal(res.headers.get("x-robots-tag"), "index, follow");
  const body = await res.text();
  assert.match(body, new RegExp(`<link rel="canonical" href="${SITE}/">`));
  assert.match(body, new RegExp(`<link rel="alternate" hreflang="x-default" href="${SITE}/">`));
  assert.match(body, new RegExp(`<link rel="alternate" hreflang="en" href="${SITE}/">`));
  assert.match(body, new RegExp(`<link rel="alternate" hreflang="zh-CN" href="${SITE}/\\?lang=zh_CN">`));
  assert.match(body, /<meta name="description" content="[^"]+">/);
  assert.match(body, new RegExp(`<meta property="og:image" content="${SITE}/static/og.jpg\\?v=[0-9a-f]{10}">`));
  assert.match(body, /<h1/);
  const types = jsonLd(body).flat().map((d) => (d as { "@type": string })["@type"]);
  assert.deepEqual(types, ["WebSite", "VideoGame"]);
});

test("canonical follows the language the page was rendered in, not how it was chosen", async () => {
  const app = createApp(testDeps());
  const viaQuery = await (await app.request("/?lang=es")).text();
  assert.match(viaQuery, new RegExp(`<link rel="canonical" href="${SITE}/\\?lang=es">`));
  const viaCookie = await (await app.request("/", { headers: { Cookie: "qm_lang=es" } })).text();
  assert.match(viaCookie, new RegExp(`<link rel="canonical" href="${SITE}/\\?lang=es">`));
  assert.match(viaCookie, /<meta property="og:locale" content="es_ES">/);
});

test("/faq: indexable, FAQPage JSON-LD with the same questions as the page", async () => {
  const res = await createApp(testDeps()).request("/faq?lang=de");
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("x-robots-tag"), "index, follow");
  const body = await res.text();
  assert.match(body, new RegExp(`<link rel="canonical" href="${SITE}/faq\\?lang=de">`));
  const [faq] = jsonLd(body) as { "@type": string; mainEntity: { name: string }[] }[];
  assert.equal(faq!["@type"], "FAQPage");
  assert.ok(faq!.mainEntity.length >= 5);
  for (const q of faq!.mainEntity) assert.ok(body.includes(`<h2>${q.name.replace(/&/g, "&amp;").replace(/'/g, "&#39;").replace(/"/g, "&quot;")}</h2>`), q.name);
});

test("legal pages are indexable with alternates; account pages stay noindex", async () => {
  const app = createApp(testDeps());
  const privacy = await app.request("/privacy?lang=fr");
  assert.equal(privacy.headers.get("x-robots-tag"), "index, follow");
  assert.match(await privacy.text(), new RegExp(`<link rel="canonical" href="${SITE}/privacy\\?lang=fr">`));
  for (const p of ["/login", "/feedback"]) {
    const res = await app.request(p);
    assert.equal(res.headers.get("x-robots-tag"), "noindex, nofollow", p);
    assert.doesNotMatch(await res.text(), /rel="canonical"/, p);
  }
});

test("IndexNow key file: served only for the configured key", async () => {
  const key = "0123456789abcdef0123456789abcdef";
  const off = createApp(testDeps());
  assert.equal((await off.request(`/${key}.txt`)).status, 404);
  const app = createApp(testDeps({ config: { indexNowKey: key } }));
  const res = await app.request(`/${key}.txt`);
  assert.equal(res.status, 200);
  assert.equal(await res.text(), key);
  assert.equal((await app.request("/fedcba9876543210fedcba9876543210.txt")).status, 404);
});

test("JSON-LD text can never close its script tag", () => {
  assert.equal(jsonLdText({ a: "</script><script>alert(1)</script>" }).includes("</"), false);
});
