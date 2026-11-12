import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp } from "../src/app.js";
import { sitemapPaths } from "../src/http/seo.js";
import { translator } from "../src/i18n/i18n.js";
import { clubNotes, displayCity, slugOf, world } from "../src/world/world.js";
import { SITE, testDeps } from "./helpers.js";

test("world: every league, club and school from the data pack, with slugs and canon marks", () => {
  const w = world();
  assert.equal(w.leagues.length, 20);
  assert.equal(w.clubs.size, 194);
  assert.equal(w.schools.length, 11);
  assert.equal(slugOf("club_chudley_cannons"), "chudley-cannons");
  const cannons = w.clubBySlug.get("chudley-cannons")!;
  assert.equal(cannons.source, "canon");
  assert.equal(cannons.leagueId, "comp_british_irish_league");
  assert.equal(w.clubBySlug.get("buenos-aires-buhos")!.source, "filler");
  assert.ok(w.clubBySlug.get("holyhead-harpies")!.players.some((p) => p.name === "Gwenog Jones" && p.position === "B"));
  const hogwarts = w.schoolBySlug.get("hogwarts")!;
  assert.deepEqual(hogwarts.houses.map((h) => h.name), ["Gryffindor", "Hufflepuff", "Ravenclaw", "Slytherin"]);
  assert.ok(hogwarts.houses[0]!.students.some((s) => s.name === "Harry Potter" && s.position === "S"));
  for (const l of w.leagues) for (const id of l.clubIds) assert.ok(w.clubs.has(id), id);
});

test("world: the game's city names and encyclopedia texts", () => {
  const w = world();
  const club = w.clubBySlug.get("buenos-aires-buhos")!;
  assert.equal(displayCity(w, club, "es", translator("es")), "Buenos Aires, Argentina");
  const ja = displayCity(w, club, "ja", translator("ja"));
  assert.notEqual(ja, club.city);
  assert.ok(clubNotes(club, translator("en")).every((n) => !n.startsWith("club.")));
  assert.ok(clubNotes(w.clubBySlug.get("chudley-cannons")!, translator("de")).every((n) => !n.startsWith("club.")));
});

test("/world, league, club and school pages: indexable with canonical; invented clubs noindex, follow; 404 otherwise", async () => {
  const app = createApp(testDeps());
  for (const [path, robots] of [
    ["/world", "index, follow"],
    ["/leagues/british-irish-league", "index, follow"],
    ["/clubs/chudley-cannons", "index, follow"],
    ["/schools/hogwarts", "index, follow"],
    ["/clubs/buenos-aires-buhos", "noindex, follow"],
  ] as const) {
    const res = await app.request(`${path}?lang=fr`);
    assert.equal(res.status, 200, path);
    assert.equal(res.headers.get("x-robots-tag"), robots, path);
    const body = await res.text();
    assert.match(body, new RegExp(`<link rel="canonical" href="${SITE}${path}\\?lang=fr">`), path);
    assert.doesNotMatch(body, /\sstyle=/i, path);
    assert.doesNotMatch(body, /\{[a-z]+\}|>(web|club|comp|country|house|pos|school)\.[a-z_]+/, `${path}: no raw key or placeholder`);
  }
  for (const p of ["/leagues/nope", "/clubs/nope", "/schools/nope"]) assert.equal((await app.request(p)).status, 404, p);
  const league = await (await app.request("/leagues/british-irish-league")).text();
  assert.match(league, /href="\/clubs\/chudley-cannons"/);
  const school = await (await app.request("/schools/hogwarts")).text();
  assert.match(school, /Harry Potter/);
});

test("world pages: a trail from the home page, the same steps as BreadcrumbList JSON-LD in the page's language", async () => {
  const app = createApp(testDeps());
  const body = await (await app.request("/clubs/chudley-cannons?lang=es")).text();
  assert.match(body, /<nav class="crumbs"[^>]*><ol><li><a href="\/">Juego de mánager de Quidditch<\/a><\/li><li><a href="\/world">[^<]+<\/a><\/li><li><a href="\/leagues\/british-irish-league">[^<]+<\/a><\/li><li aria-current="page">Chudley Cannons<\/li><\/ol><\/nav>/);
  const ld = JSON.parse(/<script type="application\/ld\+json">(.*?)<\/script>/.exec(body)![1]!) as { "@type": string; itemListElement: { position: number; name: string; item: string }[] };
  assert.equal(ld["@type"], "BreadcrumbList");
  assert.deepEqual(ld.itemListElement.map((e) => e.item), [`${SITE}/?lang=es`, `${SITE}/world?lang=es`, `${SITE}/leagues/british-irish-league?lang=es`, `${SITE}/clubs/chudley-cannons?lang=es`]);
  assert.deepEqual(ld.itemListElement.map((e) => e.position), [1, 2, 3, 4]);
  for (const p of ["/world", "/leagues/british-irish-league", "/schools/hogwarts"]) assert.match(await (await app.request(p)).text(), /<li><a href="\/">Quidditch management game<\/a><\/li>/, p);
});

test("sitemap: world index, every league and school, only the canon clubs", () => {
  const w = world();
  const paths = sitemapPaths(w);
  assert.ok(paths.includes("/world"));
  assert.ok(paths.includes("/leagues/argentina-league"));
  assert.ok(paths.includes("/schools/wollemi"));
  assert.ok(paths.includes("/clubs/chudley-cannons"));
  assert.ok(!paths.includes("/clubs/buenos-aires-buhos"));
  assert.equal(paths.filter((p) => p.startsWith("/clubs/")).length, [...w.clubs.values()].filter((c) => c.source === "canon").length);
});
