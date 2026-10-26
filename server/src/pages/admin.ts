/**
 * The operator's pages (/admin/users, /admin/feedback). English only and hardcoded on purpose: the only reader is
 * the person running the site, so these strings are not `web.*` keys. Everything from the database goes through
 * `html`, which escapes it.
 */
import { html, trustedHtml, type SafeHtml } from "../http/html.js";
import { ADMIN_FEEDBACK_MAX, ADMIN_LIST_MAX, type AdminFeedback, type AdminUser, type AdminView } from "../admin/admin.js";
import type { AccessMode } from "../config.js";

export interface AdminUsersState {
  view: AdminView;
  accessMode: AccessMode;
  users: AdminUser[];
  viewerId: string;
  /** From `?done=`: what the last POST did, or "none" when no row changed. */
  done: string | null;
}

function when(iso: string | null): string {
  return iso ? iso.slice(0, 16).replace("T", " ") : "";
}

function actionForm(view: AdminView, action: string, id: string, label: string, danger = false): SafeHtml {
  return html`<form method="post" action="/admin/users/${action}"><input type="hidden" name="id" value="${id}"><input type="hidden" name="view" value="${view}"><button class="btn btn-small${danger ? " btn-danger" : ""}" type="submit">${label}</button></form>`;
}

function userRow(s: AdminUsersState, u: AdminUser): SafeHtml {
  const self = u.id === s.viewerId;
  const actions: SafeHtml[] = [];
  if (u.state === "pending" || u.state === "unfinished") actions.push(actionForm(s.view, "approve", u.id, "Approve"));
  if (u.state === "approved" && !self) actions.push(actionForm(s.view, "revoke", u.id, "Revoke"));
  if (u.state === "blocked") actions.push(actionForm(s.view, "unblock", u.id, "Unblock"));
  else if (!self) actions.push(actionForm(s.view, "block", u.id, "Block", true));
  return html`<tr class="state-${u.state}" data-user="${u.id}">
<td>${u.username ? "@" + u.username : html`<span class="muted">(no username yet)</span>`}${u.isAdmin ? html` <span class="badge">admin</span>` : ""}</td>
<td>${u.countryCode ?? ""}</td>
<td class="email">${u.email}</td>
<td class="num">${when(u.createdAt)}</td>
<td>${u.state}${u.approvedAt ? html`<br><span class="muted">${when(u.approvedAt)}</span>` : ""}</td>
<td class="row-actions">${actions}</td>
</tr>`;
}

export function adminUsersBody(s: AdminUsersState): SafeHtml {
  const tab = (view: AdminView, label: string) =>
    html`<a href="/admin/users?view=${view}"${view === s.view ? trustedHtml(' aria-current="page"') : ""}>${label}</a>`;
  const mode =
    s.accessMode === "approval"
      ? "ACCESS_MODE=approval: a new account waits here until you approve it."
      : "ACCESS_MODE=open: new accounts are approved on the spot; the list below is for moderation.";
  const pending = s.users.filter((u) => u.state === "pending").length;
  const done = s.done ? html`<p class="notice ok" role="status" data-done="${s.done}">${s.done === "none" ? "Nothing changed (already in that state, or your own account)." : `Done: ${s.done}.`}</p>` : "";
  return html`<section class="card admin ranking-wide">
<h1>Accounts</h1>
<p class="muted">${mode} <a href="/admin/feedback">Feedback</a></p>
${done}
<nav class="rank-tabs">${tab("pending", `Waiting (${pending})`)} ${tab("all", "All")}</nav>
${
  s.users.length === 0
    ? html`<p>Nobody is waiting.</p>`
    : html`<table>
<thead><tr><th>Username</th><th>Country</th><th>Email</th><th>Created (UTC)</th><th>State</th><th></th></tr></thead>
<tbody>${s.users.map((u) => userRow(s, u))}</tbody>
</table>
${s.users.length >= ADMIN_LIST_MAX ? html`<p class="muted">Only the first ${ADMIN_LIST_MAX} rows are shown.</p>` : ""}`
}
</section>`;
}

export function adminFeedbackBody(rows: AdminFeedback[]): SafeHtml {
  return html`<section class="card admin ranking-wide">
<h1>Feedback</h1>
<p class="muted">The last ${ADMIN_FEEDBACK_MAX} submissions, newest first. <a href="/admin/users">Accounts</a></p>
${
  rows.length === 0
    ? html`<p>No feedback yet.</p>`
    : html`<table>
<thead><tr><th>When (UTC)</th><th>Kind</th><th>From</th><th>Context</th><th>Message</th></tr></thead>
<tbody>${rows.map(
  (r) => html`<tr data-feedback="${r.id}">
<td class="num">${when(r.createdAt)}<br><span class="muted">${r.lang}${r.mailed ? "" : " · not mailed"}</span></td>
<td>${r.kind}</td>
<td>${r.username ? "@" + r.username : html`<span class="muted">anonymous</span>`}${r.replyEmail ? html`<br><a href="mailto:${r.replyEmail}">${r.replyEmail}</a>` : ""}</td>
<td>${r.context ?? ""}</td>
<td class="message">${r.message}</td>
</tr>`,
)}</tbody>
</table>`
}
</section>`;
}
