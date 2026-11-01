import type { Context, Hono } from "hono";
import { getViewer, page, tOf } from "../http/viewer.js";
import { clubBody, leagueBody, leagueName, schoolBody, schoolName, worldIndexBody } from "../pages/world.js";
import { playHrefFor } from "./pages.js";
import type { AppEnv } from "../types.js";
import { displayCity, world } from "../world/world.js";

type C = Context<AppEnv>;

async function playHref(c: C): Promise<string> {
  return playHrefFor(c, await getViewer(c).catch(() => null));
}

export function registerWorldRoutes(app: Hono<AppEnv>): void {
  app.get("/world", async (c) => {
    const t = tOf(c);
    const w = world();
    return page(c, {
      title: t("web.world.title"),
      body: worldIndexBody(t, w),
      seo: { path: "/world", description: t("web.seo.world_description", { leagues: w.leagues.length, clubs: w.clubs.size, schools: w.schools.length }) },
    });
  });

  app.get("/leagues/:slug", async (c) => {
    const w = world();
    const l = w.leagueBySlug.get(c.req.param("slug"));
    if (!l) return c.notFound();
    const t = tOf(c);
    const name = leagueName(t, l);
    return page(c, {
      title: name,
      body: leagueBody(t, w, l, c.get("lang"), await playHref(c)),
      seo: { path: `/leagues/${l.slug}`, description: t("web.seo.league_description", { league: name, n: l.clubIds.length }) },
    });
  });

  app.get("/clubs/:slug", async (c) => {
    const w = world();
    const club = w.clubBySlug.get(c.req.param("slug"));
    if (!club) return c.notFound();
    const t = tOf(c);
    const lang = c.get("lang");
    const league = w.leagues.find((l) => l.id === club.leagueId);
    return page(c, {
      title: club.name,
      body: clubBody(t, w, club, lang, await playHref(c)),
      seo: {
        path: `/clubs/${club.slug}`,
        description: t("web.seo.club_description", { club: club.name, city: displayCity(w, club, lang, t), league: league ? leagueName(t, league) : "" }),
        noindex: club.source !== "canon",
      },
    });
  });

  app.get("/schools/:slug", async (c) => {
    const w = world();
    const s = w.schoolBySlug.get(c.req.param("slug"));
    if (!s) return c.notFound();
    const t = tOf(c);
    const name = schoolName(t, s);
    return page(c, {
      title: name,
      body: schoolBody(t, s, await playHref(c)),
      seo: { path: `/schools/${s.slug}`, description: t("web.seo.school_description", { school: name }) },
    });
  });
}
