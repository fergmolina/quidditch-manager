import type { SessionListItem } from "../auth/sessions.js";
import { html, trustedHtml, type SafeHtml } from "../http/html.js";
import type { Lang, T } from "../i18n/i18n.js";
import { countryName } from "../profile/countries.js";
import type { FieldErrors, ProfileFormValues } from "../profile/profile.js";
import { USERNAME_COOLDOWN_MS } from "../profile/username.js";
import { messageCard } from "./layout.js";
import { defaultSubmit, errorSummary, fieldError, formatDate, locationFieldset, namesFieldset, usernameField } from "./profile-form.js";

export const ACCOUNT_SAVED = ["profile", "username", "session"] as const;
export type AccountSaved = (typeof ACCOUNT_SAVED)[number];

export interface AccountState {
  lang: Lang;
  email: string;
  username: string;
  countryCode: string | null;
  createdAt: string;
  usernameLockedUntilMs: number | null;
  profile: ProfileFormValues;
  profileErrors: FieldErrors;
  usernameValue: string;
  usernameErrors: FieldErrors;
  sessions: SessionListItem[];
  saved: AccountSaved | null;
}

function sessionRow(t: T, lang: Lang, s: SessionListItem): SafeHtml {
  const device = s.userAgentFamily || t("web.account.session_unknown_device");
  const dates = t("web.account.session_dates", { created: formatDate(lang, s.createdAt), seen: formatDate(lang, s.lastSeenAt) });
  const action = s.current
    ? html`<form method="post" action="/auth/logout"><button class="btn btn-small" type="submit">${t("web.account.session_revoke")}</button></form>`
    : html`<form method="post" action="/account/sessions/revoke"><input type="hidden" name="id" value="${s.publicId}"><button class="btn btn-small" type="submit">${t("web.account.session_revoke")}</button></form>`;
  return html`<li class="session${s.current ? " current" : ""}">
<div><strong>${device}</strong>${s.current ? html` <span class="badge">${t("web.account.session_current")}</span>` : ""}<br><span class="muted">${dates}</span></div>
${action}
</li>`;
}

export function accountBody(t: T, s: AccountState): SafeHtml {
  const days = Math.round(USERNAME_COOLDOWN_MS / 86_400_000);
  const saved = s.saved ? html`<p class="notice ok" role="status" data-saved="${s.saved}">${t(`web.account.saved.${s.saved}`)}</p>` : "";
  const usernameSection = s.usernameLockedUntilMs
    ? html`<p>${t("web.account.username_cooldown", { date: formatDate(s.lang, s.usernameLockedUntilMs) })}</p>`
    : html`${errorSummary(t, s.usernameErrors)}<form class="stack" method="post" action="/account/username">
${usernameField(t, { id: "new_username", value: s.usernameValue, ...(s.usernameErrors.username ? { error: s.usernameErrors.username } : {}), label: t("web.account.username_new") })}
<p class="help">${t("web.account.username_help", { days })}</p>
<div><button class="btn" type="submit">${t("web.account.username_submit")}</button></div>
</form>`;

  return html`<section class="card">
<h1>${t("web.account.title")}</h1>
${saved}
<p class="lead">@${s.username}${s.countryCode ? ` · ${countryName(s.countryCode, s.lang)}` : ""}</p>
<p class="muted">${t("web.account.email_line", { email: s.email })}<br>${t("web.account.member_since", { date: formatDate(s.lang, s.createdAt) })}</p>
</section>

<section class="card" id="username-section">
<h2>${t("web.account.username_title")}</h2>
<p>${t("web.account.username_current", { name: "@" + s.username })}</p>
${usernameSection}
</section>

<section class="card" id="profile-section">
<h2>${t("web.account.profile_title")}</h2>
${errorSummary(t, s.profileErrors)}
<form class="stack" method="post" action="/account/profile" data-profile-form>
${defaultSubmit()}
${namesFieldset(t, s.profile, s.profileErrors)}
${locationFieldset(t, s.lang, s.profile, s.profileErrors)}
<div><button class="btn btn-primary" type="submit">${t("web.account.profile_submit")}</button></div>
</form>
</section>

<section class="card" id="sessions-section">
<h2>${t("web.account.sessions_title")}</h2>
<p class="muted">${t("web.account.sessions_intro")}</p>
<ul class="sessions">${s.sessions.map((x) => sessionRow(t, s.lang, x))}</ul>
<div class="actions">
<form method="post" action="/auth/logout"><button class="btn" type="submit">${t("web.nav.sign_out")}</button></form>
<form method="post" action="/auth/logout-all"><button class="btn" type="submit">${t("web.account.logout_all")}</button></form>
</div>
</section>

<section class="card" id="data-section">
<h2>${t("web.account.data_title")}</h2>
<p>${t("web.account.data_intro")}</p>
<div class="actions">
<a class="btn" href="/account/export" download>${t("web.account.export")}</a>
<a class="btn btn-danger" href="/account/delete">${t("web.account.delete")}</a>
</div>
</section>`;
}

export interface DeleteState {
  username: string | null;
  /** The deletion page's promise: deploy/compose.yml's BACKUP_KEEP_* bound how long a backup can still hold the row. */
  backupRetentionDays: number;
  error?: string | undefined;
}

export function deleteBody(t: T, s: DeleteState): SafeHtml {
  const confirm = s.username
    ? html`<div class="field">
<label for="confirm">${t("web.account.delete_confirm_label", { name: s.username })}</label>
<input id="confirm" name="confirm" type="text" required autocomplete="off" autocapitalize="none" spellcheck="false"${s.error ? trustedHtml(' aria-invalid="true" aria-describedby="confirm-error"') : ""}>
${fieldError(t, "confirm", s.error)}
</div>`
    : html`<div class="field">
<label class="check"><input type="checkbox" name="confirm" value="yes" required> <span>${t("web.account.delete_confirm_check")}</span></label>
${fieldError(t, "confirm", s.error)}
</div>`;
  return html`<section class="card">
<h1>${t("web.account.delete_title")}</h1>
<p>${t("web.account.delete_body", { days: s.backupRetentionDays })}</p>
<form class="stack" method="post" action="/account/delete">
${confirm}
<div class="actions">
<button class="btn btn-danger" type="submit">${t("web.account.delete_submit")}</button>
<a class="btn" href="/account">${t("web.account.cancel")}</a>
</div>
</form>
</section>`;
}

export function deletedBody(t: T): SafeHtml {
  return messageCard({
    title: t("web.account.deleted_title"),
    paragraphs: [t("web.account.deleted_body")],
    actions: html`<a class="btn" href="/">${t("web.error.home")}</a>`,
  });
}
