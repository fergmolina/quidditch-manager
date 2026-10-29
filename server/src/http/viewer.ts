import type { Context } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import { validateSession, type SessionUser } from "../auth/sessions.js";
import { profileStatus, type ProfileStatus } from "../auth/users.js";
import { translator, type T } from "../i18n/i18n.js";
import { layout } from "../pages/layout.js";
import type { AppEnv } from "../types.js";
import { readSessionToken } from "./cookies.js";
import type { HtmlValue } from "./html.js";
import { htmlPage } from "./respond.js";
import type { SeoMeta } from "./seo.js";

type C = Context<AppEnv>;

export async function getViewer(c: C): Promise<SessionUser | null> {
  const memo = c.get("viewer");
  if (memo.resolved) return memo.viewer;
  const { db, now } = c.get("deps");
  const token = readSessionToken(c);
  const viewer = token ? await validateSession(db, token, now()) : null;
  c.set("viewer", { resolved: true, viewer });
  return viewer;
}

export function tOf(c: C): T {
  return translator(c.get("lang"));
}

export function viewerStatus(c: C, v: SessionUser): ProfileStatus {
  const { config } = c.get("deps");
  return profileStatus(v.user, config.termsVersion, config.accessMode);
}

export function pathForStatus(status: ProfileStatus, next: string): string {
  switch (status) {
    case "complete":
      return next;
    case "pending":
      return "/pending";
    case "blocked":
      return "/login?error=blocked";
    default:
      return `/register?${new URLSearchParams({ next }).toString()}`;
  }
}

export function currentUrl(c: C): string {
  const u = new URL(c.req.url);
  return `${u.pathname}${u.search}`;
}

export interface PageOptions {
  title: string;
  body: HtmlValue;
  status?: ContentfulStatusCode;
  head?: HtmlValue;
  noindex?: boolean;
  bare?: boolean;
  /** An indexable page (one of seo.ts INDEXABLE_PATHS): implies noindex false. */
  seo?: SeoMeta;
  titleAbsolute?: boolean;
}

export async function page(c: C, o: PageOptions): Promise<Response> {
  const v = await getViewer(c).catch(() => null);
  const noindex = o.seo ? false : (o.noindex ?? true);
  // security.ts marks every other path noindex; an indexable page says so itself.
  if (!noindex) c.header("X-Robots-Tag", "index, follow");
  const html = layout({
    lang: c.get("lang"),
    t: tOf(c),
    title: o.title,
    body: o.body,
    currentUrl: currentUrl(c),
    viewer: v ? { username: v.user.username } : null,
    head: o.head,
    noindex,
    bare: o.bare ?? false,
    seo: o.seo,
    siteUrl: c.get("deps").config.siteUrl,
    titleAbsolute: o.titleAbsolute,
  });
  return htmlPage(c, html, o.status ?? 200);
}
