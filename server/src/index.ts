import { existsSync } from "node:fs";
import { serve } from "@hono/node-server";
import { createApp } from "./app.js";
import { googleRemoteKeys } from "./auth/google.js";
import { ConfigError, loadConfig } from "./config.js";
import { createPool } from "./db.js";
import { GENERATED_STRINGS_PATH } from "./i18n/i18n.js";
import { createMailer } from "./mail/send.js";
import type { Logger } from "./types.js";

const log: Logger = {
  info: (m) => console.log(m),
  warn: (m) => console.warn(m),
  error: (m) => console.error(m),
};

function main(): void {
  let config;
  try {
    config = loadConfig();
  } catch (e) {
    console.error(e instanceof ConfigError ? `[config] ${e.message}` : e);
    process.exit(1);
  }
  if (!existsSync(GENERATED_STRINGS_PATH)) {
    if (config.isProd) {
      console.error(`[i18n] ${GENERATED_STRINGS_PATH} is missing: run \`npm run gen:i18n\` before building the image`);
      process.exit(1);
    }
    log.warn("[i18n] generated/strings.json is missing: pages show key names (run `npm run gen:i18n`)");
  }
  if (!config.authSecretFromEnv) log.warn("[config] AUTH_SECRET is not set: using a random per-process key");
  if (config.feedbackTo && config.isProd && !config.mail.resendApiKey) log.warn("[config] FEEDBACK_TO is set but email is off: feedback is stored, not mailed");

  const pool = createPool(config.databaseUrl, config.dbPoolMax);
  const app = createApp({
    config,
    db: pool.db,
    mailer: createMailer(config, log),
    fetch: globalThis.fetch,
    googleKeys: googleRemoteKeys(),
    now: Date.now,
    log,
  });

  const server = serve({ fetch: app.fetch, hostname: config.host, port: config.port }, (info) => {
    log.info(`[http] listening on ${info.address}:${info.port} (${config.env}), site ${config.siteUrl}`);
  });

  let closing = false;
  const shutdown = (signal: string) => {
    if (closing) return;
    closing = true;
    log.info(`[http] ${signal}: shutting down`);
    server.close(() => {
      void pool.close().finally(() => process.exit(0));
    });
    setTimeout(() => process.exit(0), 10_000).unref();
  };
  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}

main();
