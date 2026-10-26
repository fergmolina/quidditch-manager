import { createLocalJWKSet, type JSONWebKeySet } from "jose";
import { testConfig, type Config } from "../src/config.js";
import type { Db, TxDb } from "../src/db.js";
import type { Mailer, MailMessage } from "../src/mail/send.js";
import type { Notifier } from "../src/notify/telegram.js";
import type { AppDeps, Logger } from "../src/types.js";

export interface Statement {
  text: string;
  values: unknown[];
}

export function fakeDb(handler: (s: Statement) => unknown[] | undefined): Db & { log: Statement[]; writes(): Statement[] } {
  const log: Statement[] = [];
  const db = {
    log,
    async query<T>(text: string, values: unknown[] = []): Promise<T[]> {
      const s = { text: text.replace(/\s+/g, " ").trim(), values };
      log.push(s);
      const rows = handler(s);
      if (rows === undefined) throw new Error("unexpected statement: " + s.text);
      return rows as T[];
    },
    async transaction<T>(fn: (tx: TxDb) => Promise<T>): Promise<T> {
      return fn(db);
    },
    writes() {
      return log.filter((s) => /^(update|delete|insert)/i.test(s.text));
    },
  };
  return db;
}

export function headers(h: Record<string, string>): { get(name: string): string | null } {
  const m = new Map(Object.entries(h).map(([k, v]) => [k.toLowerCase(), v]));
  return { get: (n: string) => m.get(n.toLowerCase()) ?? null };
}

export const silentLog: Logger = { info: () => undefined, warn: () => undefined, error: () => undefined };

export function captureMailer(): Mailer & { sent: MailMessage[]; fail: boolean } {
  const m = {
    sent: [] as MailMessage[],
    fail: false,
    canSend: true,
    async send(msg: MailMessage) {
      if (m.fail) throw new Error("send failed");
      m.sent.push(msg);
    },
  };
  return m;
}

/** Records every alert. The push happens before any await, so a test can assert right after `app.request`. */
export function captureNotifier(): Notifier & { sent: string[] } {
  const n = {
    enabled: true,
    sent: [] as string[],
    async send(text: string) {
      n.sent.push(text);
    },
  };
  return n;
}

export function testDeps(over: Partial<Omit<AppDeps, "config">> & { config?: Partial<Config> } = {}): AppDeps {
  const { config, ...rest } = over;
  return {
    config: testConfig(config),
    db: fakeDb(() => undefined),
    mailer: captureMailer(),
    notifier: captureNotifier(),
    fetch: (async () => new Response("{}", { status: 500 })) as typeof fetch,
    googleKeys: createLocalJWKSet({ keys: [] } as JSONWebKeySet),
    now: Date.now,
    log: silentLog,
    ...rest,
  };
}

export const SITE = "http://localhost:8080";
export const SAME_ORIGIN = { Origin: SITE, "Sec-Fetch-Site": "same-origin" };
