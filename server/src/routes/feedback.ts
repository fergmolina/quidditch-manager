import type { Context, Hono } from "hono";
import { hitRateLimit } from "../auth/rate-limit.js";
import { CONTEXT_MAX, formValues, insertFeedback, markFeedbackMailed, parseFeedback, parseKind, type FeedbackErrors, type FeedbackValues } from "../feedback/feedback.js";
import { redirect303 } from "../http/redirect.js";
import { getViewer, page, tOf } from "../http/viewer.js";
import { feedbackEmail } from "../mail/templates.js";
import { feedbackBody, feedbackSentBody, HONEYPOT_FIELD } from "../pages/feedback.js";
import type { AppEnv } from "../types.js";
import { ipSubject, tooMany } from "./auth.js";

type C = Context<AppEnv>;

export const FEEDBACK_LIMIT = { bucket: "feedback", limit: 5, windowMs: 60 * 60_000 } as const;
export const FEEDBACK_ALL_LIMIT = { bucket: "feedback_all", subject: "all", limit: 60, windowMs: 24 * 60 * 60_000 } as const;

export const FEEDBACK_SENT_PATH = "/feedback?sent=1";

async function formOf(c: C): Promise<Record<string, string>> {
  const body = await c.req.parseBody().catch(() => ({}) as Record<string, unknown>);
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(body)) if (typeof v === "string") out[k] = v;
  return out;
}

async function renderForm(c: C, values: FeedbackValues, errors: FeedbackErrors, status: 200 | 400 = 200): Promise<Response> {
  const t = tOf(c);
  return page(c, { title: t("web.feedback.title"), status, body: feedbackBody(t, { values, errors }) });
}

export function registerFeedbackRoutes(app: Hono<AppEnv>): void {
  app.get("/feedback", async (c) => {
    if (c.req.query("sent") === "1") {
      const t = tOf(c);
      return page(c, { title: t("web.feedback.sent_title"), body: feedbackSentBody(t) });
    }
    const values = formValues({ kind: parseKind(c.req.query("kind")), context: (c.req.query("context") ?? "").slice(0, CONTEXT_MAX) });
    return renderForm(c, values, {});
  });

  app.post("/feedback", async (c) => {
    const { db, config, mailer, now, log } = c.get("deps");
    const form = await formOf(c);
    if ((form[HONEYPOT_FIELD] ?? "") !== "") return redirect303(c, FEEDBACK_SENT_PATH, "/");
    const values = formValues(form);
    const v = await getViewer(c);
    const parsed = parseFeedback(values, c.get("lang"), v ? v.user.id : null);
    if (!parsed.ok) return renderForm(c, values, parsed.errors, 400);
    const feedback = parsed.value;
    if (!(await hitRateLimit(db, { ...FEEDBACK_LIMIT, subject: ipSubject(c) }, now()))) return tooMany(c);
    if (!(await hitRateLimit(db, FEEDBACK_ALL_LIMIT, now()))) return tooMany(c);

    const id = await insertFeedback(db, feedback, now());
    if (config.feedbackTo !== null && mailer.canSend) {
      try {
        await mailer.send({ to: config.feedbackTo!, ...feedbackEmail({ ...feedback, signedIn: feedback.userId !== null }) });
        await markFeedbackMailed(db, id, now());
      } catch (e) {
        log.error(`[feedback] copy to FEEDBACK_TO failed (row kept): ${e instanceof Error ? e.message : String(e)}`);
      }
    }
    return redirect303(c, FEEDBACK_SENT_PATH, "/");
  });
}
