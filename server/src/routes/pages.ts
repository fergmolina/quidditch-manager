import type { Context, Hono } from "hono";
import type { SessionUser } from "../auth/sessions.js";
import { ranking, rankedCountries, rankingByCountry } from "../career/ranking.js";
import { rankingBody, rankingMapBody } from "../pages/ranking.js";
import { readStatic, STATIC_DIR } from "../http/static.js";
import { getViewer, page, pathForStatus, tOf, viewerStatus } from "../http/viewer.js";
import { landingBody, landingJsonLd } from "../pages/landing.js";
import { faqBody, faqJsonLd } from "../pages/faq.js";
import { OG_IMAGE } from "../http/seo.js";
import { staticUrl } from "../pages/layout.js";
import type { AppEnv } from "../types.js";

/** Where "Play" leads: the game for a complete profile, else the next step (sign in, register, pending). */
function playHrefFor(c: Context<AppEnv>, v: SessionUser | null): string {
  return v ? pathForStatus(viewerStatus(c, v), "/play/") : "/login?next=%2Fplay%2F";
}

export function registerPageRoutes(app: Hono<AppEnv>, opts: { assetVersion: string; downloadsUrl: string | null }): void {
  app.get("/", async (c) => {
    const t = tOf(c);
    const v = await getViewer(c);
    const { siteUrl } = c.get("deps").config;
    return page(c, {
      title: t("web.seo.home_title"),
      titleAbsolute: true,
      body: landingBody(t, { playHref: playHrefFor(c, v), downloadsUrl: opts.downloadsUrl }),
      seo: {
        path: "/",
        description: t("web.seo.home_description"),
        jsonLd: landingJsonLd(t, { siteUrl, downloadsUrl: opts.downloadsUrl, imageUrl: `${siteUrl}${staticUrl(OG_IMAGE.path)}` }),
      },
    });
  });

  app.get("/faq", async (c) => {
    const t = tOf(c);
    const v = await getViewer(c);
    return page(c, {
      title: t("web.faq.title"),
      body: faqBody(t, { playHref: playHrefFor(c, v) }),
      seo: { path: "/faq", description: t("web.seo.faq_description"), jsonLd: faqJsonLd(t) },
    });
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
    const rankingSeo = { path: "/ranking", description: t("web.seo.ranking_description") };
    if (view === "map") {
      const countryRows = await rankingByCountry(db);
      return page(c, { title: t("web.ranking.title"), body: rankingMapBody(t, { rows: [], countries: [], country: null, viewerId, lang, view, countryRows }), seo: rankingSeo });
    }
    const [rows, countries] = await Promise.all([ranking(db, country), rankedCountries(db)]);
    return page(c, {
      title: t("web.ranking.title"),
      body: rankingBody(t, { rows, countries, country, viewerId, lang, view, countryRows: [] }),
      seo: rankingSeo,
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
