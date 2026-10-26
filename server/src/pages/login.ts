import { html, type SafeHtml } from "../http/html.js";
import type { Lang, T } from "../i18n/i18n.js";
import { messageCard } from "./layout.js";

export const LOGIN_ERRORS = [
  "link",
  "blocked",
  "google_unverified",
  "google_failed",
  "rate_limited",
  "mail_failed",
  "mail_cap",
  "email_invalid",
  "session",
] as const;
export type LoginError = (typeof LOGIN_ERRORS)[number];

export function isLoginError(v: unknown): v is LoginError {
  return typeof v === "string" && (LOGIN_ERRORS as readonly string[]).includes(v);
}

export interface LoginState {
  lang: Lang;
  next: string;
  error: LoginError | null;
  googleEnabled: boolean;
  emailEnabled: boolean;
  email?: string;
  signedIn: { username: string | null; continueHref: string } | null;
}

export function loginBody(t: T, s: LoginState): SafeHtml {
  if (s.signedIn) {
    const who = s.signedIn.username ? t("web.login.signed_in_as", { name: "@" + s.signedIn.username }) : t("web.login.signed_in_no_profile");
    return messageCard({
      title: t("web.login.title"),
      paragraphs: [who],
      actions: html`<a class="btn btn-primary" href="${s.signedIn.continueHref}">${t("web.login.continue")}</a>
<form method="post" action="/auth/logout"><button class="btn" type="submit">${t("web.nav.sign_out")}</button></form>`,
    });
  }
  const googleHref = `/auth/google?${new URLSearchParams({ next: s.next, lang: s.lang }).toString()}`;
  return html`<section class="card">
<h1>${t("web.login.title")}</h1>
<p class="lead">${t("web.login.intro")}</p>
${s.error ? html`<p class="notice error" role="alert">${t(`web.login.error.${s.error}`)}</p>` : ""}
${s.googleEnabled ? html`<a class="btn btn-block btn-google" href="${googleHref}">${t("web.login.google")}</a>` : ""}
${s.googleEnabled && s.emailEnabled ? html`<div class="or">${t("web.login.or")}</div>` : ""}
${
  s.emailEnabled
    ? html`<form class="stack" method="post" action="/auth/magic">
<label for="email">${t("web.login.email_label")}</label>
<input id="email" name="email" type="email" autocomplete="email" inputmode="email" required maxlength="254" value="${s.email ?? ""}">
<input type="hidden" name="next" value="${s.next}">
<input type="hidden" name="lang" value="${s.lang}">
<button class="btn btn-primary" type="submit">${t("web.login.email_submit")}</button>
</form>
<p class="muted">${t("web.login.email_note")}</p>`
    : ""
}
</section>`;
}

export function checkInboxBody(t: T, o: { email: string; minutes: number; next: string }): SafeHtml {
  return messageCard({
    title: t("web.check.title"),
    paragraphs: [t("web.check.body", { email: o.email, minutes: o.minutes }), html`<span class="muted">${t("web.check.spam")}</span>`],
    actions: html`<a class="btn" href="/login?${new URLSearchParams({ next: o.next }).toString()}">${t("web.check.back")}</a>`,
  });
}
