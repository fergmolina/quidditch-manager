import { html, type SafeHtml } from "../http/html.js";
import type { T } from "../i18n/i18n.js";

/** Question ids, in page order: web.faq.q_<id> / web.faq.a_<id>. */
export const FAQ_IDS = ["free", "official", "play", "fm", "hogwarts", "era", "saves", "langs", "code"] as const;

export function faqBody(t: T, o: { playHref: string }): SafeHtml {
  return html`<section class="card faq">
<h1>${t("web.faq.title")}</h1>
${FAQ_IDS.map((id) => html`<h2>${t(`web.faq.q_${id}`)}</h2>
<p>${t(`web.faq.a_${id}`)}</p>
`)}
<div class="actions center"><a class="btn btn-primary" href="${o.playHref}">${t("web.landing.play")}</a></div>
</section>`;
}

/** FAQPage structured data: the same questions and answers as the page. */
export function faqJsonLd(t: T): Record<string, unknown>[] {
  return [
    {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      mainEntity: FAQ_IDS.map((id) => ({
        "@type": "Question",
        name: t(`web.faq.q_${id}`),
        acceptedAnswer: { "@type": "Answer", text: t(`web.faq.a_${id}`) },
      })),
    },
  ];
}
