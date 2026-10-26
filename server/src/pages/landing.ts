import { html, type SafeHtml } from "../http/html.js";
import type { T } from "../i18n/i18n.js";
import { staticUrl } from "./layout.js";

export interface LandingState {
  playHref: string;
  downloadsUrl: string | null;
}

export function landingBody(t: T, s: LandingState): SafeHtml {
  return html`<section class="card center">
<div class="hero"><img class="logo" src="${staticUrl("logo.png")}" alt="${t("ui.app_title")}" width="420" height="210"></div>
<p class="lead">${t("ui.app_subtitle")}</p>
<p>${t("web.landing.pitch")}</p>
<div class="actions center"><a class="btn btn-primary" href="${s.playHref}">${t("web.landing.play")}</a></div>
<p class="muted">${t("web.landing.account_note")}</p>
${s.downloadsUrl ? html`<p class="muted"><a href="${s.downloadsUrl}" rel="noopener">${t("web.landing.desktop")}</a></p>` : ""}
<p class="muted"><a href="/feedback">${t("web.landing.feedback")}</a></p>
</section>
<section class="card saves">
<h2>${t("web.landing.saves_title")}</h2>
<ul>
<li>${t("web.landing.saves_where")}</li>
<li>${t("web.landing.saves_lost")}</li>
<li>${t("web.landing.saves_export")}</li>
</ul>
</section>`;
}
