import { escapeHtml } from "../http/html.js";
import type { T } from "../i18n/i18n.js";
import { codePoints } from "../text.js";
import type { MailMessage } from "./send.js";

export function magicLinkEmail(t: T, url: string, minutes: number): { subject: string; text: string; html: string } {
  const title = t("ui.app_title");
  const subject = t("web.mail.magic_subject", { app: title });
  const text = [
    t("web.mail.magic_body_text", { minutes }),
    "",
    url,
    "",
    t("web.mail.ignore_if_not_you"),
  ].join("\n");
  const u = escapeHtml(url);
  const html = `<!doctype html>
<html>
<body style="margin:0;padding:24px;background:#E2D3AE;font-family:Georgia,'Times New Roman',serif;color:#2A1E14">
<div style="max-width:480px;margin:0 auto;background:#F7F1E1;border:1px solid #CBB88C;border-radius:6px;padding:24px">
<h1 style="margin:0 0 16px;font-size:22px;color:#2B1D14">${escapeHtml(title)}</h1>
<p style="margin:0 0 20px;font-size:16px;line-height:1.5">${escapeHtml(t("web.mail.magic_body_html_intro"))}</p>
<p style="margin:0 0 20px"><a href="${u}" style="display:inline-block;background:#E2C25A;color:#2A1E14;text-decoration:none;font-weight:bold;padding:12px 20px;border-radius:4px;border-bottom:2px solid #8A6428">${escapeHtml(t("web.mail.magic_button"))}</a></p>
<p style="margin:0 0 12px;font-size:14px;color:#5C4A36">${escapeHtml(t("web.mail.expires", { minutes }))}</p>
<p style="margin:0 0 12px;font-size:12px;color:#7C6A52;word-break:break-all">${u}</p>
<p style="margin:16px 0 0;font-size:13px;color:#7C6A52">${escapeHtml(t("web.mail.ignore_if_not_you"))}</p>
</div>
</body>
</html>
`;
  return { subject, text, html };
}

export interface FeedbackMailInput {
  kind: "bug" | "idea";
  message: string;
  replyEmail: string | null;
  context: string | null;
  lang: string;
  signedIn: boolean;
}

export function feedbackEmail(f: FeedbackMailInput): Omit<MailMessage, "to"> {
  const firstLine = f.message.replace(/\s+/g, " ").trim();
  const excerpt = codePoints(firstLine) > 60 ? [...firstLine].slice(0, 59).join("") + "…" : firstLine;
  const label = f.kind === "bug" ? "Bug" : "Idea";
  const subject = `[Quidditch Manager] ${label}: ${excerpt}`;
  const meta: Array<[string, string]> = [
    ["Kind", label],
    ["Language", f.lang],
    ["Account", f.signedIn ? "signed in" : "anonymous"],
    ["Context", f.context ?? "(none)"],
  ];
  const text = [...meta.map(([k, v]) => `${k}: ${v}`), "", f.message, ""].join("\n");
  const html = `<!doctype html>
<html>
<body style="margin:0;padding:24px;background:#E2D3AE;font-family:Georgia,'Times New Roman',serif;color:#2A1E14">
<div style="max-width:640px;margin:0 auto;background:#F7F1E1;border:1px solid #CBB88C;border-radius:6px;padding:24px">
<h1 style="margin:0 0 16px;font-size:20px;color:#2B1D14">${escapeHtml(subject)}</h1>
<table style="margin:0 0 16px;font-size:14px;color:#5C4A36">
${meta.map(([k, v]) => `<tr><td style="padding:2px 12px 2px 0"><b>${escapeHtml(k)}</b></td><td style="padding:2px 0">${escapeHtml(v)}</td></tr>`).join("\n")}
</table>
<pre style="margin:0;white-space:pre-wrap;word-break:break-word;font:15px/1.5 Georgia,'Times New Roman',serif">${escapeHtml(f.message)}</pre>
</div>
</body>
</html>
`;
  return f.replyEmail ? { subject, text, html, replyTo: f.replyEmail } : { subject, text, html };
}
