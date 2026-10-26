import type { Hono } from "hono";
import { ranking, rankedCountries, rankingByCountry } from "../career/ranking.js";
import { rankingBody, rankingMapBody } from "../pages/ranking.js";
import { readStatic, STATIC_DIR } from "../http/static.js";
import { getViewer, page, pathForStatus, tOf, viewerStatus } from "../http/viewer.js";
import { landingBody } from "../pages/landing.js";
import type { AppEnv } from "../types.js";

export function registerPageRoutes(app: Hono<AppEnv>, opts: { assetVersion: string; downloadsUrl: string | null }): void {
  app.get("/", async (c) => {
    const t = tOf(c);
    const v = await getViewer(c);
    const playHref = v ? pathForStatus(viewerStatus(c, v), "/play/") : "/login?next=%2Fplay%2F";
    return page(c, { title: t("ui.app_title"), body: landingBody(t, { playHref, downloadsUrl: opts.downloadsUrl }), noindex: false });
  });

  app.get("/ranking", async (c) => {
    const t = tOf(c);
    const { db } = c.get("deps");
    const raw = (c.req.query("country") ?? "").toUpperCase();
    const country = /^[A-Z]{2}$/.test(raw) ? raw : null;
    const view = c.req.query("view") === "map" ? "map" : "list";
    const v = await getViewer(c).catch(() => null);
    const viewerId = v ? v.user.id : null;
    const lang = c.get("lang");
    if (view === "map") {
      const countryRows = await rankingByCountry(db);
      return page(c, { title: t("web.ranking.title"), body: rankingMapBody(t, { rows: [], countries: [], country: null, viewerId, lang, view, countryRows }), noindex: false });
    }
    const [rows, countries] = await Promise.all([ranking(db, country), rankedCountries(db)]);
    return page(c, {
      title: t("web.ranking.title"),
      body: rankingBody(t, { rows, countries, country, viewerId, lang, view, countryRows: [] }),
      noindex: false,
    });
  });

  app.get("/static/*", async (c) => {
    const rel = c.req.path.slice("/static/".length);
    const file = await readStatic(STATIC_DIR, rel);
    if (!file) return c.notFound();
    const versioned = c.req.query("v") === opts.assetVersion;
    c.header("Content-Type", file.type);
    c.header("Cache-Control", versioned ? "public, max-age=31536000, immutable" : "public, max-age=300");
    return c.body(file.body as Uint8Array<ArrayBuffer>);
  });
}
