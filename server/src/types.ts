import type { JWTVerifyGetKey } from "jose";
import type { SessionUser } from "./auth/sessions.js";
import type { Config } from "./config.js";
import type { Db } from "./db.js";
import type { Lang } from "./i18n/i18n.js";
import type { Mailer } from "./mail/send.js";
import type { Notifier } from "./notify/telegram.js";

export interface Logger {
  info(msg: string): void;
  warn(msg: string): void;
  error(msg: string): void;
}

export interface AppDeps {
  config: Config;
  db: Db;
  mailer: Mailer;
  /** Operator alerts (Telegram). Fire-and-forget: `send` never throws and never blocks a request. */
  notifier: Notifier;
  fetch: typeof fetch;
  googleKeys: JWTVerifyGetKey;
  now: () => number;
  log: Logger;
}

export type ViewerMemo = { resolved: false } | { resolved: true; viewer: SessionUser | null };

export interface AppVariables {
  deps: AppDeps;
  lang: Lang;
  viewer: ViewerMemo;
}

export type AppEnv = { Variables: AppVariables };
