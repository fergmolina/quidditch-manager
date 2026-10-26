import { html, type SafeHtml } from "../http/html.js";
import type { T } from "../i18n/i18n.js";
import { messageCard } from "./layout.js";

/** GET /pending: the account is complete but waits for the operator's approval (closed trial). */
export function pendingBody(t: T): SafeHtml {
  return messageCard({
    title: t("web.pending.title"),
    paragraphs: [t("web.pending.intro"), t("web.pending.later")],
    actions: html`<a class="btn" href="/account">${t("web.nav.account")}</a>
<form method="post" action="/auth/logout"><button class="btn" type="submit">${t("web.nav.sign_out")}</button></form>`,
  });
}
