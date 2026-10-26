import { html, trustedHtml, type SafeHtml } from "../http/html.js";
import type { Lang, T } from "../i18n/i18n.js";
import type { FieldErrors, ProfileFormValues } from "../profile/profile.js";
import { defaultSubmit, errorSummary, locationFieldset, namesFieldset, termsCheckbox, usernameField } from "./profile-form.js";

export type RegisterMode = "register" | "rename" | "terms";

export interface RegisterState {
  lang: Lang;
  mode: RegisterMode;
  next: string;
  values: ProfileFormValues;
  errors: FieldErrors;
  hasUsername: boolean;
  currentUsername: string | null;
  termsDue: boolean;
  termsChecked: boolean;
  minAge: number;
  email: string;
}

function accountFooter(t: T, s: RegisterState): SafeHtml {
  return html`<div class="aside">
<p class="muted">${t("web.register.signed_in_email", { email: s.email })}</p>
<div class="actions">
<form method="post" action="/auth/logout"><button class="btn btn-small" type="submit">${t("web.nav.sign_out")}</button></form>
${s.mode === "register" ? html`<a class="btn btn-small" href="/account/delete">${t("web.register.delete_link")}</a>` : ""}
</div>
</div>`;
}

export function registerBody(t: T, s: RegisterState): SafeHtml {
  const hidden = html`<input type="hidden" name="next" value="${s.next}">`;
  const terms = termsCheckbox(t, { minAge: s.minAge, checked: s.termsChecked, ...(s.errors.terms ? { error: s.errors.terms } : {}) });

  if (s.mode === "terms") {
    return html`<section class="card">
<h1>${t("web.register.terms_title")}</h1>
<p class="lead">${t("web.register.terms_body")}</p>
${errorSummary(t, s.errors)}
<form class="stack" method="post" action="/register">
${hidden}
${terms}
<button class="btn btn-primary" type="submit">${t("web.register.terms_submit")}</button>
</form>
${accountFooter(t, s)}
</section>`;
  }

  if (s.mode === "rename") {
    return html`<section class="card">
<h1>${t("web.register.rename_title")}</h1>
<p class="lead">${t("web.register.rename_body", { name: "@" + (s.currentUsername ?? "") })}</p>
${errorSummary(t, s.errors)}
<form class="stack" method="post" action="/register">
${hidden}
${usernameField(t, { value: s.values.username, ...(s.errors.username ? { error: s.errors.username } : {}), label: t("web.account.username_new"), autofocus: true })}
${s.termsDue ? terms : ""}
<button class="btn btn-primary" type="submit">${t("web.register.rename_submit")}</button>
</form>
${accountFooter(t, s)}
</section>`;
  }

  return html`<section class="card">
<h1>${t("web.register.title")}</h1>
<p class="lead">${t("web.register.intro")}</p>
${errorSummary(t, s.errors)}
<form class="stack" method="post" action="/register" data-profile-form>
${defaultSubmit()}
${hidden}
${s.hasUsername ? trustedHtml("") : usernameField(t, { value: s.values.username, ...(s.errors.username ? { error: s.errors.username } : {}) })}
${namesFieldset(t, s.values, s.errors)}
${locationFieldset(t, s.lang, s.values, s.errors)}
${terms}
<button class="btn btn-primary" type="submit">${t("web.register.submit")}</button>
</form>
${accountFooter(t, s)}
</section>`;
}
