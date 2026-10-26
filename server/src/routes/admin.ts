import type { Context, Hono } from "hono";
import { hitRateLimit } from "../auth/rate-limit.js";
import { deleteUserSessions, type SessionUser } from "../auth/sessions.js";
import { applyAdminAction, isAdminAction, isUuid, listFeedback, listUsers, parseView, type AdminView } from "../admin/admin.js";
import { getViewer, page } from "../http/viewer.js";
import { adminFeedbackBody, adminUsersBody } from "../pages/admin.js";
import type { AppEnv } from "../types.js";
import { tooMany } from "./auth.js";

type C = Context<AppEnv>;

export const ADMIN_WRITE_LIMIT = { bucket: "admin_write", limit: 60, windowMs: 15 * 60_000 } as const;

/**
 * The operator's pages. Only a signed-in, unblocked `is_admin` account gets in; everyone else sees the ordinary 404,
 * not a 403, so the path stays unadvertised. `is_admin` is set by SQL only (deploy/db/make-admin.sh).
 */
async function adminViewer(c: C): Promise<SessionUser | null> {
  const v = await getViewer(c);
  return v && v.user.isAdmin && !v.user.blockedAt ? v : null;
}

async function formOf(c: C): Promise<Record<string, string>> {
  const body = await c.req.parseBody().catch(() => ({}) as Record<string, unknown>);
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(body)) if (typeof v === "string") out[k] = v;
  return out;
}

/** /admin is not in the `next` allowlist (on purpose), so these redirects bypass redirect303's check with fixed paths. */
function backToUsers(c: C, view: AdminView, done: string | null): Response {
  const q = new URLSearchParams({ view });
  if (done) q.set("done", done);
  c.header("Cache-Control", "no-store");
  return c.redirect(`/admin/users?${q.toString()}`, 303);
}

export function registerAdminRoutes(app: Hono<AppEnv>): void {
  app.get("/admin/users", async (c) => {
    const v = await adminViewer(c);
    if (!v) return c.notFound();
    const { db, config } = c.get("deps");
    const view = parseView(c.req.query("view"));
    const done = (c.req.query("done") ?? "").slice(0, 20);
    const users = await listUsers(db, view);
    return page(c, { title: "Accounts", body: adminUsersBody({ view, accessMode: config.accessMode, users, viewerId: v.user.id, done: /^[a-z]+$/.test(done) ? done : null }) });
  });

  app.post("/admin/users/:action", async (c) => {
    const v = await adminViewer(c);
    if (!v) return c.notFound();
    const action = c.req.param("action");
    if (!isAdminAction(action)) return c.notFound();
    const { db, now, log } = c.get("deps");
    const form = await formOf(c);
    const view = parseView(form.view);
    if (!isUuid(form.id)) return backToUsers(c, view, "none");
    if (!(await hitRateLimit(db, { ...ADMIN_WRITE_LIMIT, subject: `user:${v.user.id}` }, now()))) return tooMany(c);
    const changed = await db.transaction(async (tx) => {
      const ok = await applyAdminAction(tx, action, form.id!, v.user.id, now());
      // A blocked account must not keep playing on an open session: its sessions go with the block.
      if (ok && action === "block") await deleteUserSessions(tx, form.id!);
      return ok;
    });
    if (changed) log.info(`[admin] ${action} applied to an account by an admin`);
    return backToUsers(c, view, changed ? action : "none");
  });

  app.get("/admin/feedback", async (c) => {
    const v = await adminViewer(c);
    if (!v) return c.notFound();
    const { db } = c.get("deps");
    return page(c, { title: "Feedback", body: adminFeedbackBody(await listFeedback(db)) });
  });
}
