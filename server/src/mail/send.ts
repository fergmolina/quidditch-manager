/** Transactional email through Resend's HTTPS API (Hetzner blocks outbound port 25). */
import type { Config } from "../config.js";
import type { Logger } from "../types.js";

export interface MailMessage {
  to: string;
  subject: string;
  html: string;
  text: string;
  replyTo?: string;
}

export interface Mailer {
  /** false when every send() throws, as in production without a Resend key. */
  readonly canSend: boolean;
  send(msg: MailMessage): Promise<void>;
}

export class MailError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
    this.name = "MailError";
  }
}

export const RESEND_ENDPOINT = "https://api.resend.com/emails";

export function resendMailer(apiKey: string, from: string, fetchImpl: typeof fetch = fetch): Mailer {
  return {
    canSend: true,
    async send(msg) {
      const res = await fetchImpl(RESEND_ENDPOINT, {
        method: "POST",
        headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from, to: [msg.to], subject: msg.subject, html: msg.html, text: msg.text, ...(msg.replyTo ? { reply_to: msg.replyTo } : {}) }),
        signal: AbortSignal.timeout(10_000),
      });
      if (!res.ok) {
        throw new MailError(`resend responded ${res.status}`, res.status);
      }
    },
  };
}

export function consoleMailer(print: (s: string) => void = (s) => console.log(s)): Mailer {
  return {
    canSend: true,
    async send(msg) {
      print(`[mail] (dev, not sent) to=${msg.to}${msg.replyTo ? ` reply-to=${msg.replyTo}` : ""} subject=${msg.subject}\n${msg.text}`);
    },
  };
}

export function createMailer(config: Config, log: Logger, fetchImpl: typeof fetch = fetch): Mailer {
  if (config.mail.resendApiKey) return resendMailer(config.mail.resendApiKey, config.mail.from, fetchImpl);
  if (config.isProd) {
    return {
      canSend: false,
      async send() {
        throw new MailError("email login is off");
      },
    };
  }
  log.warn("RESEND_API_KEY is not set: magic links are printed to this console");
  return consoleMailer();
}
