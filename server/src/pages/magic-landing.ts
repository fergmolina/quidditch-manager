/**
 * The page a magic link opens (GET /auth/magic/verify?token=…). It does NOT log anyone in: mail scanners and link
 * previews follow GETs. The login happens in the POST this page's form sends, and only when the person presses the
 * button: there is no auto-submit script, so even a scanner that runs JavaScript cannot burn the link.
 */
import { html, type SafeHtml } from "../http/html.js";
import type { T } from "../i18n/i18n.js";

export function magicLandingBody(t: T, token: string): SafeHtml {
  return html`<section class="card center">
<h1>${t("web.magic.title")}</h1>
<p>${t("web.magic.body")}</p>
<form method="post" action="/auth/magic/verify">
<input type="hidden" name="token" value="${token}">
<div class="actions center"><button class="btn btn-primary" type="submit">${t("web.magic.button")}</button></div>
</form>
</section>`;
}
