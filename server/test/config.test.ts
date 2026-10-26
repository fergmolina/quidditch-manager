import assert from "node:assert/strict";
import { test } from "node:test";
import { ConfigError, DEFAULT_TRUSTED_PROXY_HEADER, loadConfig } from "../src/config.js";

const SECRET = "test-secret-test-secret-test-secret!!";
const DEV = { NODE_ENV: "test", SITE_URL: "http://localhost:8080", AUTH_SECRET: SECRET };
const PROD = { NODE_ENV: "production", SITE_URL: "https://qm.example.org", DATABASE_URL: "postgres://qm_api:x@db/qm", RESEND_API_KEY: "re_x", MAIL_FROM: "QM <login@qm.example.org>", AUTH_SECRET: SECRET };

test("MAIL_DAILY_CAP=0 and SESSION_RATE_PER_MINUTE=0 become null (no limit) at the boundary", () => {
  const def = loadConfig(DEV);
  assert.equal(def.mail.dailyCap, 90);
  assert.equal(def.sessionRatePerMinute, 60);
  const off = loadConfig({ ...DEV, MAIL_DAILY_CAP: "0", SESSION_RATE_PER_MINUTE: "0" });
  assert.equal(off.mail.dailyCap, null);
  assert.equal(off.sessionRatePerMinute, null);
});

test("LEGAL_CONTROLLER / LEGAL_CONTACT_EMAIL: trimmed and collapsed; an invalid address counts as unset, never a config error", () => {
  assert.deepEqual(loadConfig(DEV).legal, { controller: null, contactEmail: null });
  assert.deepEqual(loadConfig({ ...DEV, LEGAL_CONTROLLER: "   ", LEGAL_CONTACT_EMAIL: "  " }).legal, { controller: null, contactEmail: null });
  assert.deepEqual(loadConfig({ ...DEV, LEGAL_CONTROLLER: "  Example   Org ", LEGAL_CONTACT_EMAIL: " privacy@game.example " }).legal, {
    controller: "Example Org",
    contactEmail: "privacy@game.example",
  });
  assert.equal(loadConfig({ ...DEV, LEGAL_CONTROLLER: "x".repeat(300) }).legal.controller, "x".repeat(200));
  assert.equal(loadConfig({ ...PROD, LEGAL_CONTACT_EMAIL: "not an email" }).legal.contactEmail, null);
  assert.equal(loadConfig({ ...DEV, LEGAL_CONTACT_EMAIL: "a@b.example)(javascript:x" }).legal.contactEmail, null);
});

test("BACKUP_RETENTION_DAYS: 45 by default, at least 1", () => {
  assert.equal(loadConfig(DEV).backupRetentionDays, 45);
  assert.equal(loadConfig({ ...DEV, BACKUP_RETENTION_DAYS: "60" }).backupRetentionDays, 60);
  assert.throws(() => loadConfig({ ...DEV, BACKUP_RETENTION_DAYS: "0" }), ConfigError);
});

test("trusted client-IP headers: Cloudflare's by default, XFF only outside production, TRUSTED_PROXY_HEADER overrides", () => {
  assert.deepEqual(loadConfig(DEV).trustedClientIpHeaders, [DEFAULT_TRUSTED_PROXY_HEADER, "x-forwarded-for"]);
  assert.deepEqual(loadConfig(PROD).trustedClientIpHeaders, ["cf-connecting-ip"]);
  assert.deepEqual(loadConfig({ ...PROD, TRUSTED_PROXY_HEADER: "X-Real-IP" }).trustedClientIpHeaders, ["x-real-ip"]);
  assert.throws(() => loadConfig({ ...DEV, TRUSTED_PROXY_HEADER: "not a header" }), ConfigError);
});

test("ACCESS_MODE: open by default, approval accepted, anything else refused; TELEGRAM_* go together", () => {
  assert.equal(loadConfig(DEV).accessMode, "open");
  assert.equal(loadConfig(DEV).telegram, null);
  assert.equal(loadConfig({ ...DEV, ACCESS_MODE: "approval" }).accessMode, "approval");
  assert.throws(() => loadConfig({ ...DEV, ACCESS_MODE: "bogus" }), ConfigError);
  assert.throws(() => loadConfig({ ...PROD, TELEGRAM_BOT_TOKEN: "123:abc" }), /go together/);
  assert.throws(() => loadConfig({ ...PROD, TELEGRAM_CHAT_ID: "-100" }), /go together/);
  assert.deepEqual(loadConfig({ ...PROD, TELEGRAM_BOT_TOKEN: "123:abc", TELEGRAM_CHAT_ID: "-100" }).telegram, { botToken: "123:abc", chatId: "-100" });
});
