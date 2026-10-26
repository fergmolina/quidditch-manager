import assert from "node:assert/strict";
import { test } from "node:test";
import { testConfig } from "../src/config.js";
import { createNotifier, feedbackAlert, signupAlert, TELEGRAM_API, telegramNotifier } from "../src/notify/telegram.js";
import type { Logger } from "../src/types.js";

const TOKEN = "123456:ABC-secret-token";

function logs(): Logger & { lines: string[] } {
  const lines: string[] = [];
  return { lines, info: (m) => lines.push(m), warn: (m) => lines.push(m), error: (m) => lines.push(m) };
}

test("telegramNotifier posts chat_id, text and no link preview to the bot's sendMessage, with a timeout", async () => {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const fetchImpl = (async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    return new Response('{"ok":true}', { status: 200 });
  }) as typeof fetch;
  const log = logs();
  const n = telegramNotifier(TOKEN, "-100777", log, fetchImpl);
  assert.equal(n.enabled, true);
  await n.send("New sign-up: @HarryFan (AR)");
  assert.equal(calls.length, 1);
  assert.equal(calls[0]!.url, `${TELEGRAM_API}/bot${TOKEN}/sendMessage`);
  assert.equal(calls[0]!.init.method, "POST");
  assert.deepEqual(JSON.parse(String(calls[0]!.init.body)), { chat_id: "-100777", text: "New sign-up: @HarryFan (AR)", disable_web_page_preview: true });
  assert.ok(calls[0]!.init.signal instanceof AbortSignal);
  assert.deepEqual(log.lines, []);
});

test("failures never throw and never log the token (HTTP error, network error with the URL in its message)", async () => {
  const log = logs();
  const bad = telegramNotifier(TOKEN, "1", log, (async () => new Response("nope", { status: 401 })) as typeof fetch);
  await bad.send("x");
  const thrower = telegramNotifier(TOKEN, "1", log, (async (url: string | URL | Request) => {
    throw new TypeError(`fetch failed: ${String(url)}`);
  }) as typeof fetch);
  await thrower.send("x");
  assert.equal(log.lines.length, 2);
  assert.match(log.lines[0]!, /responded 401/);
  assert.match(log.lines[1]!, /failed \(TypeError\)/);
  for (const line of log.lines) assert.ok(!line.includes(TOKEN) && !line.includes("secret"), line);
});

test("createNotifier: off (and says so once) without TELEGRAM_*; both variables go together", async () => {
  const log = logs();
  const off = createNotifier(testConfig(), log);
  assert.equal(off.enabled, false);
  await off.send("dropped");
  assert.deepEqual(log.lines, ["[telegram] notifications off (TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are not set)"]);
  const on = createNotifier(testConfig({ telegram: { botToken: TOKEN, chatId: "1" } }), logs(), (async () => new Response("{}")) as typeof fetch);
  assert.equal(on.enabled, true);
});

test("alert texts carry the username and country only, and point at the admin pages", () => {
  const cfg = { siteUrl: "https://qm.example.org", accessMode: "approval" as const };
  assert.equal(signupAlert(cfg, { username: "HarryFan", countryCode: "AR" }), "New sign-up: @HarryFan (AR) — pending approval: https://qm.example.org/admin/users?view=pending");
  assert.equal(signupAlert({ ...cfg, accessMode: "open" }, { username: "HarryFan", countryCode: "AR" }), "New sign-up: @HarryFan (AR) — approved (open access)");
  assert.equal(feedbackAlert(cfg, "bug", null), "Feedback (bug) from anonymous — https://qm.example.org/admin/feedback");
  assert.equal(feedbackAlert(cfg, "idea", "HarryFan"), "Feedback (idea) from @HarryFan — https://qm.example.org/admin/feedback");
});
