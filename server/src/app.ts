import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { BurstLimiter } from "./auth/rate-limit.js";
import { setLangCookie, readLangCookie } from "./http/cookies.js";
import { isOwnOrigin, sameOriginRejection } from "./http/origin.js";
import { securityHeaders } from "./http/security.js";
import { page, tOf } from "./http/viewer.js";
import { negotiateLang } from "./i18n/negotiate.js";
import { html } from "./http/html.js";
import { MODULES, type RouteModule } from "./modules.js";
import { ASSET_VERSION, messageCard } from "./pages/layout.js";
import { forbidden, registerAuthRoutes } from "./routes/auth.js";
import { registerApiRoutes, registerHealth } from "./routes/api.js";
import { registerDevPlay } from "./routes/dev-play.js";
import { registerPageRoutes } from "./routes/pages.js";
import type { AppDeps, AppEnv } from "./types.js";

export const MAX_BODY_BYTES = 32 * 1024;

export interface CreateAppOptions {
  modules?: RouteModule[];
}

export function createApp(deps: AppDeps, opts: CreateAppOptions = {}): Hono<AppEnv> {
  const app = new Hono<AppEnv>();
  const { config } = deps;

  app.use("*", async (c, next) => {
    c.set("deps", deps);
    c.set("viewer", { resolved: false });
    const { lang, fromQuery } = negotiateLang({
      query: c.req.query("lang"),
      cookie: readLangCookie(c),
      acceptLanguage: c.req.header("accept-language"),
    });
    c.set("lang", lang);
    if (fromQuery) setLangCookie(c, lang);
    await next();
  });

  app.use("*", securityHeaders());

  app.use("*", async (c, next) => {
    const m = c.req.method;
    if (m === "GET" || m === "HEAD" || m === "OPTIONS") return next();
    const rejection = sameOriginRejection(c.req.raw.headers, (o) => isOwnOrigin(o, config.siteOrigin, config.isProd));
    if (rejection) return forbidden(c);
    return next();
  });

  app.use(
    "*",
    bodyLimit({
      maxSize: MAX_BODY_BYTES,
      onError: (c) => c.text("Payload Too Large", 413),
    }),
  );

  registerHealth(app);
  registerApiRoutes(app, config.sessionRatePerMinute === null ? null : new BurstLimiter({ limit: config.sessionRatePerMinute, now: deps.now }));
  registerPageRoutes(app, { assetVersion: ASSET_VERSION, downloadsUrl: config.downloadsUrl });
  registerAuthRoutes(app);
  for (const m of [...MODULES, ...(opts.modules ?? [])]) m(app);
  if (config.devPlayDir) registerDevPlay(app, config.devPlayDir, config.devPlayOpen);

  app.notFound(async (c) => {
    if (c.req.path.startsWith("/api/")) {
      c.header("Cache-Control", "no-store");
      return c.json({ error: "not_found" }, 404);
    }
    const t = tOf(c);
    return page(c, {
      title: t("web.error.404"),
      status: 404,
      body: messageCard({ title: t("web.error.404"), paragraphs: [], actions: html`<a class="btn" href="/">${t("web.error.home")}</a>` }),
    });
  });

  app.onError(async (err, c) => {
    deps.log.error(`[http] ${c.req.method} ${c.req.path}: ${err instanceof Error ? (err.stack ?? err.message) : String(err)}`);
    if (c.req.path.startsWith("/api/") || c.req.path === "/healthz") {
      c.header("Cache-Control", "no-store");
      return c.json({ error: "internal" }, 500);
    }
    const t = tOf(c);
    try {
      return await page(c, {
        title: t("web.error.title"),
        status: 500,
        body: messageCard({ title: t("web.error.title"), paragraphs: [t("web.error.generic")] }),
      });
    } catch {
      return c.text("Internal Server Error", 500);
    }
  });

  return app;
}
