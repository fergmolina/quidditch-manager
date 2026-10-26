/**
 * Operator alerts through a Telegram bot (sign-ups, feedback). The same bot the host scripts use for backup and
 * health alerts (deploy/lib/telegram.sh), configured by TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID.
 *
 * The request URL carries the bot token, so no error path may log the URL or an error message that could contain
 * it: failures are logged with a fixed text plus the HTTP status or the error's name only. What goes into a message
 * is the caller's business, but the rule is: username and country at most, never an email, a name, a city or an IP.
 */
import type { Config } from "../config.js";
import type { Logger } from "../types.js";

export interface Notifier {
  /** false when nothing is configured: send() is then a no-op. */
  readonly enabled: boolean;
  /** Resolves once the message was accepted or dropped; never rejects. */
  send(text: string): Promise<void>;
}

export const TELEGRAM_API = "https://api.telegram.org";
export const TELEGRAM_TIMEOUT_MS = 10_000;
const TEXT_MAX = 4000;

export function telegramNotifier(token: string, chatId: string, log: Logger, fetchImpl: typeof fetch = fetch): Notifier {
  return {
    enabled: true,
    async send(text) {
      try {
        const res = await fetchImpl(`${TELEGRAM_API}/bot${token}/sendMessage`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ chat_id: chatId, text: text.slice(0, TEXT_MAX), disable_web_page_preview: true }),
          signal: AbortSignal.timeout(TELEGRAM_TIMEOUT_MS),
        });
        if (!res.ok) log.error(`[telegram] sendMessage responded ${res.status}`);
      } catch (e) {
        log.error(`[telegram] sendMessage failed (${e instanceof Error ? e.name : "error"})`);
      }
    },
  };
}

export const silentNotifier: Notifier = { enabled: false, send: async () => undefined };

export function createNotifier(config: Config, log: Logger, fetchImpl: typeof fetch = fetch): Notifier {
  if (!config.telegram) {
    log.info("[telegram] notifications off (TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are not set)");
    return silentNotifier;
  }
  return telegramNotifier(config.telegram.botToken, config.telegram.chatId, log, fetchImpl);
}

/** The sign-up alert. Only the username and the country code: nothing else about the person goes to Telegram. */
export function signupAlert(config: Pick<Config, "siteUrl" | "accessMode">, user: { username: string | null; countryCode: string | null }): string {
  const who = `@${user.username ?? "?"} (${user.countryCode ?? "??"})`;
  return config.accessMode === "approval"
    ? `New sign-up: ${who} — pending approval: ${config.siteUrl}/admin/users?view=pending`
    : `New sign-up: ${who} — approved (open access)`;
}

/** The feedback alert: kind and who (username or anonymous), never the message, the reply address or the context. */
export function feedbackAlert(config: Pick<Config, "siteUrl">, kind: string, username: string | null): string {
  return `Feedback (${kind}) from ${username ? `@${username}` : "anonymous"} — ${config.siteUrl}/admin/feedback`;
}
