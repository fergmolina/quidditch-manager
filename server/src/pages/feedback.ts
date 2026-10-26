import { html, trustedHtml, type SafeHtml } from "../http/html.js";
import type { T } from "../i18n/i18n.js";
import { CONTEXT_MAX, FEEDBACK_KINDS, MESSAGE_MAX, MESSAGE_MIN, type FeedbackErrors, type FeedbackValues } from "../feedback/feedback.js";
import { messageCard } from "./layout.js";

export interface FeedbackState {
  values: FeedbackValues;
  errors: FeedbackErrors;
}

export const HONEYPOT_FIELD = "website";

const ERROR_KEYS: Record<NonNullable<FeedbackErrors["message"] | FeedbackErrors["email"]>, string> = {
  message_short: "web.feedback.error.message_short",
  message_long: "web.feedback.error.message_long",
  email_invalid: "web.login.error.email_invalid",
};

function fieldError(t: T, id: string, code: keyof typeof ERROR_KEYS | undefined): SafeHtml | "" {
  return code ? html`<p class="field-error" id="${id}-error" data-code="${code}">${t(ERROR_KEYS[code], { min: MESSAGE_MIN, max: MESSAGE_MAX })}</p>` : "";
}

function describedBy(id: string, err: string | undefined): SafeHtml {
  return trustedHtml(` aria-describedby="${id}-help${err ? ` ${id}-error` : ""}"${err ? ' aria-invalid="true"' : ""}`);
}

export function feedbackBody(t: T, s: FeedbackState): SafeHtml {
  const { values: v, errors } = s;
  const kinds = FEEDBACK_KINDS.map(
    (k) => html`<label class="check"><input type="radio" name="kind" value="${k}"${v.kind === k ? trustedHtml(" checked") : ""}> <span>${t(`web.feedback.kind_${k}`)}</span></label>`,
  );
  return html`<section class="card">
<h1>${t("web.feedback.title")}</h1>
<p class="lead">${t("web.feedback.intro")}</p>
${errors.message || errors.email ? html`<p class="notice error" role="alert">${t("web.profile.errors_intro")}</p>` : ""}
<form class="stack" method="post" action="/feedback">
<fieldset>
<legend>${t("web.feedback.kind_label")}</legend>
${kinds}
</fieldset>
<div class="field">
<label for="message">${t("web.feedback.message_label")}</label>
<textarea id="message" name="message" required minlength="${MESSAGE_MIN}" maxlength="${MESSAGE_MAX}" rows="8"${describedBy("message", errors.message)}>${v.message}</textarea>
<p class="help" id="message-help">${t("web.feedback.message_help", { min: MESSAGE_MIN, max: MESSAGE_MAX })}</p>
${fieldError(t, "message", errors.message)}
</div>
<div class="field">
<label for="email">${t("web.feedback.email_label")}</label>
<input id="email" name="email" type="email" autocomplete="email" inputmode="email" maxlength="254" value="${v.email}"${describedBy("email", errors.email)}>
<p class="help" id="email-help">${t("web.feedback.email_help")}</p>
${fieldError(t, "email", errors.email)}
</div>
<div class="field">
<label for="context">${t("web.feedback.context_label")}</label>
<input id="context" name="context" type="text" maxlength="${CONTEXT_MAX}" autocomplete="off" value="${v.context}" aria-describedby="context-help">
<p class="help" id="context-help">${t("web.feedback.context_help")}</p>
</div>
<div class="hp" aria-hidden="true"><label for="${HONEYPOT_FIELD}">Website</label><input id="${HONEYPOT_FIELD}" name="${HONEYPOT_FIELD}" type="text" tabindex="-1" autocomplete="off"></div>
<div><button class="btn btn-primary" type="submit">${t("web.feedback.submit")}</button></div>
</form>
</section>`;
}

export function feedbackSentBody(t: T): SafeHtml {
  return messageCard({
    title: t("web.feedback.sent_title"),
    paragraphs: [t("web.feedback.sent_body")],
    actions: html`<a class="btn btn-primary" href="/">${t("web.error.home")}</a>
<a class="btn" href="/feedback">${t("web.feedback.sent_again")}</a>`,
  });
}
