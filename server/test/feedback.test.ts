import assert from "node:assert/strict";
import { test } from "node:test";
import { createApp } from "../src/app.js";
import { sha256Hex } from "../src/auth/tokens.js";
import { resendMailer } from "../src/mail/send.js";
import { feedbackEmail } from "../src/mail/templates.js";
import { formValues, parseFeedback } from "../src/feedback/feedback.js";
import { PAGE_CSP } from "../src/http/security.js";
import { captureMailer, fakeDb, SAME_ORIGIN, testDeps, type Statement } from "./helpers.js";

const FORM = { "Content-Type": "application/x-www-form-urlencoded" };
const form = (o: Record<string, string>) => new URLSearchParams(o).toString();
const TOKEN = "F".repeat(43);
const COOKIE = { Cookie: `qm_session=${TOKEN}` };
const USER_ID = "11111111-1111-4111-8111-111111111111";
const ROW_ID = "22222222-2222-4222-8222-222222222222";
const TO = "owner@example.org";
const GOOD = { kind: "bug", message: "The Snitch never appears after the 40th minute in the 2D viewer.", email: "", context: "v0.11.0, browser" };

interface Scenario {
  signedIn?: boolean;
  limited?: string[];
}

function feedbackDb(s: Scenario = {}) {
  return fakeDb((st: Statement) => {
    const t = st.text;
    if (t.startsWith("select s.id as session_id")) {
      if (!s.signedIn || st.values[0] !== sha256Hex(TOKEN)) return [];
      const now = Date.now();
      return [
        {
          session_id: sha256Hex(TOKEN),
          session_public_id: "00000000-0000-4000-8000-000000000001",
          session_created_at: new Date(now - 86_400_000),
          session_last_seen_at: new Date(now),
          session_expires_at: new Date(now + 20 * 86_400_000),
          session_absolute_expires_at: new Date(now + 170 * 86_400_000),
          via_previous: false,
          id: USER_ID,
          email: "owner@example.com",
          email_verified: true,
          google_sub: null,
          username: "HarryFan",
          first_name: null,
          last_name: null,
          country_code: "AR",
          region_code: null,
          city_geonameid: null,
          city_name: null,
          city_lat: null,
          city_lon: null,
          terms_version: "2026-11-01",
          terms_accepted_at: new Date(now - 86_400_000),
          username_changed_at: null,
          must_rename: false,
          is_admin: false,
          blocked_at: null,
          created_at: new Date("2026-01-02T00:00:00Z"),
          last_login_at: new Date(now),
        },
      ];
    }
    if (t.startsWith("insert into public.auth_rate_events")) return (s.limited ?? []).includes(String(st.values[0])) ? [] : [{ id: "1" }];
    if (t.startsWith("insert into public.feedback")) return [{ id: ROW_ID }];
    if (t.startsWith("update public.feedback set mailed_at")) return [];
    return undefined;
  });
}

const post = (app: ReturnType<typeof createApp>, body: Record<string, string>, extra: Record<string, string> = {}) =>
  app.request("/feedback", { method: "POST", headers: { ...FORM, ...SAME_ORIGIN, ...extra }, body: form(body) });

const inserts = (db: ReturnType<typeof feedbackDb>) => db.log.filter((s) => s.text.startsWith("insert into public.feedback"));
const limits = (db: ReturnType<typeof feedbackDb>) => db.log.filter((s) => s.text.startsWith("insert into public.auth_rate_events"));

test("GET /feedback: public form, prefilled kind and context, CSP-safe markup, honeypot hidden by class, no email prefill", async () => {
  const app = createApp(testDeps({ db: feedbackDb({ signedIn: true }) }));
  const res = await app.request("/feedback?kind=idea&context=v0.11.0%2C%20Windows", { headers: COOKIE });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("content-security-policy"), PAGE_CSP);
  const body = await res.text();
  assert.match(body, /<form class="stack" method="post" action="\/feedback">/);
  assert.match(body, /<input type="radio" name="kind" value="bug">/);
  assert.match(body, /<input type="radio" name="kind" value="idea" checked>/);
  assert.match(body, /<textarea id="message" name="message" required minlength="10" maxlength="4000"/);
  assert.match(body, /<input id="email" name="email" type="email"[^>]* value="" aria-describedby="email-help">/);
  assert.match(body, /name="context" type="text" maxlength="200" autocomplete="off" value="v0.11.0, Windows"/);
  assert.match(body, /<div class="hp" aria-hidden="true"><label for="website">[^<]*<\/label><input id="website" name="website" type="text" tabindex="-1" autocomplete="off"><\/div>/);
  assert.doesNotMatch(body, /owner@example\.com/, "the viewer's email is never shown");
  assert.doesNotMatch(body, /<script|\sstyle=|\son[a-z]+=/i, "no script, inline style or handler");
  assert.match(body, /href="\/feedback"/, "footer link");
  const anon = await createApp(testDeps({ db: feedbackDb() })).request("/feedback");
  assert.equal(anon.status, 200);
  assert.match(await anon.text(), /<input type="radio" name="kind" value="bug" checked>/, "bug is the default");
  const thanks = await app.request("/feedback?sent=1");
  assert.equal(thanks.status, 200);
  assert.match(await thanks.text(), /href="\/"/);
});

test("the landing page and every page footer link to /feedback", async () => {
  const app = createApp(testDeps({ db: feedbackDb() }));
  const home = await (await app.request("/")).text();
  assert.match(home, /<p class="muted"><a href="\/feedback">/);
  const login = await (await app.request("/login")).text();
  assert.match(login, /<a href="\/privacy">[^<]*<\/a> · <a href="\/terms">[^<]*<\/a> · <a href="\/feedback">[^<]*<\/a>/);
});

test("POST /feedback without a same-origin request is refused before anything runs", async () => {
  const db = feedbackDb();
  const app = createApp(testDeps({ db }));
  const r = await app.request("/feedback", { method: "POST", headers: { ...FORM, Origin: "https://evil.example" }, body: form(GOOD) });
  assert.equal(r.status, 403);
  assert.equal(db.writes().length, 0);
});

test("POST /feedback (anonymous): row inserted, copy mailed to FEEDBACK_TO, mailed_at set, 303 to the thanks page", async () => {
  const db = feedbackDb();
  const mailer = captureMailer();
  const app = createApp(testDeps({ db, mailer, config: { feedbackTo: TO } }));
  const res = await post(app, { ...GOOD, email: " Player@Example.COM ", website: "" }, { "CF-Connecting-IP": "203.0.113.9", Cookie: "qm_lang=es" });
  assert.equal(res.status, 303, await res.clone().text());
  assert.equal(res.headers.get("location"), "/feedback?sent=1");
  assert.equal(res.headers.get("cache-control"), "no-store");
  const [ins] = inserts(db);
  assert.ok(ins);
  assert.deepEqual(ins.values.slice(0, 6), [null, "bug", GOOD.message, "player@example.com", "v0.11.0, browser", "es"]);
  assert.ok(!JSON.stringify(ins.values).includes("203.0.113"), "no address with the row");
  const buckets = limits(db).map((s) => [s.values[0], s.values[1]]);
  assert.equal(buckets.length, 2);
  assert.equal(buckets[0]![0], "feedback");
  assert.match(String(buckets[0]![1]), /^[0-9a-f]{32}$/, "keyed hash of the address");
  assert.deepEqual(buckets[1], ["feedback_all", "all"]);
  assert.equal(mailer.sent.length, 1);
  const mail = mailer.sent[0]!;
  assert.equal(mail.to, TO);
  assert.equal(mail.subject, "[Quidditch Manager] Bug: The Snitch never appears after the 40th minute in the 2D vi…");
  assert.equal(mail.replyTo, "player@example.com", "the sender's address is the Reply-To, not body text");
  assert.doesNotMatch(mail.text, /player@example\.com/);
  assert.match(mail.text, /Account: anonymous/);
  assert.match(mail.text, /Context: v0\.11\.0, browser/);
  assert.ok(mail.text.includes(GOOD.message));
  const marked = db.log.find((s) => s.text.startsWith("update public.feedback set mailed_at"));
  assert.deepEqual(marked?.values[0], ROW_ID);
});

test("POST /feedback (signed in): the account id goes on the row, the email does not; the mail says only 'signed in'", async () => {
  const db = feedbackDb({ signedIn: true });
  const mailer = captureMailer();
  const app = createApp(testDeps({ db, mailer, config: { feedbackTo: TO } }));
  const res = await post(app, { ...GOOD, kind: "idea" }, COOKIE);
  assert.equal(res.status, 303);
  const [ins] = inserts(db);
  assert.equal(ins!.values[0], USER_ID);
  assert.equal(ins!.values[1], "idea");
  assert.equal(ins!.values[3], null);
  assert.match(mailer.sent[0]!.subject, /^\[Quidditch Manager\] Idea: /);
  assert.match(mailer.sent[0]!.text, /Account: signed in/);
  assert.equal(mailer.sent[0]!.replyTo, undefined, "no reply address given: none set");
  assert.ok(!mailer.sent[0]!.text.includes("owner@example.com") && !mailer.sent[0]!.text.includes(USER_ID));
});

test("honeypot filled: the same 303, nothing stored, nothing sent, no limit spent", async () => {
  const db = feedbackDb();
  const mailer = captureMailer();
  const app = createApp(testDeps({ db, mailer, config: { feedbackTo: TO } }));
  const res = await post(app, { ...GOOD, website: "https://spam.example" });
  assert.equal(res.status, 303);
  assert.equal(res.headers.get("location"), "/feedback?sent=1");
  assert.equal(db.writes().length, 0);
  assert.equal(mailer.sent.length, 0);
});

test("validation: too short, too long (code points), bad email → 400 with the values kept and escaped; nothing written", async () => {
  const db = feedbackDb();
  const mailer = captureMailer();
  const app = createApp(testDeps({ db, mailer, config: { feedbackTo: TO } }));
  const short = await post(app, { kind: "idea", message: `<b>hi</b>`, email: "not-an-email", context: `"x"` });
  assert.equal(short.status, 400);
  const body = await short.text();
  assert.match(body, /data-code="message_short"/);
  assert.match(body, /data-code="email_invalid"/);
  assert.match(body, /<p class="notice error" role="alert">/);
  assert.match(body, /aria-invalid="true"/);
  assert.match(body, /&lt;b&gt;hi&lt;\/b&gt;<\/textarea>/);
  assert.doesNotMatch(body, /<b>hi/);
  assert.match(body, /value="not-an-email"/);
  assert.match(body, /value="&quot;x&quot;"/);
  assert.match(body, /value="idea" checked/);
  const long = await post(app, { kind: "bug", message: "x".repeat(4001) });
  assert.equal(long.status, 400);
  assert.match(await long.text(), /data-code="message_long"/);
  // Five emoji are ten UTF-16 units but five characters: too short, as Postgres would count them.
  const emoji = await post(app, { kind: "bug", message: "😀".repeat(5) });
  assert.equal(emoji.status, 400);
  assert.equal(db.writes().length, 0, "no insert, no rate-limit row");
  assert.equal(mailer.sent.length, 0);
});

test("rate limits: the per-address bucket, then the global one; nothing stored when limited", async () => {
  for (const limited of [["feedback"], ["feedback_all"]]) {
    const db = feedbackDb({ limited });
    const app = createApp(testDeps({ db, config: { feedbackTo: TO } }));
    const res = await post(app, GOOD);
    assert.equal(res.status, 429, limited.join());
    assert.equal(inserts(db).length, 0);
  }
});

test("mail failure: the row is kept with mailed_at untouched, the player still gets the thanks page", async () => {
  const db = feedbackDb();
  const mailer = captureMailer();
  mailer.fail = true;
  const errors: string[] = [];
  const app = createApp(testDeps({ db, mailer, config: { feedbackTo: TO }, log: { info: () => undefined, warn: () => undefined, error: (m) => errors.push(m) } }));
  const res = await post(app, GOOD);
  assert.equal(res.status, 303);
  assert.equal(inserts(db).length, 1);
  assert.ok(!db.log.some((s) => s.text.startsWith("update public.feedback")));
  assert.equal(errors.length, 1);
  assert.ok(!errors[0]!.includes(GOOD.message), "the message is never logged");
});

test("no FEEDBACK_TO, or production without Resend: stored, not mailed, no error logged", async () => {
  const db = feedbackDb();
  const mailer = captureMailer();
  const app = createApp(testDeps({ db, mailer }));
  assert.equal((await post(app, GOOD)).status, 303);
  assert.equal(inserts(db).length, 1);
  assert.equal(mailer.sent.length, 0);

  const prodDb = feedbackDb();
  const errors: string[] = [];
  const prod = createApp(
    testDeps({
      db: prodDb,
      mailer: { canSend: false, send: async () => { throw new Error("email login is off"); } },
      config: { feedbackTo: TO, isProd: true, siteUrl: "https://qm.example.org", siteOrigin: "https://qm.example.org" },
      log: { info: () => undefined, warn: () => undefined, error: (m) => errors.push(m) },
    }),
  );
  const r = await prod.request("https://qm.example.org/feedback", { method: "POST", headers: { ...FORM, Origin: "https://qm.example.org", "Sec-Fetch-Site": "same-origin" }, body: form(GOOD) });
  assert.equal(r.status, 303);
  assert.equal(inserts(prodDb).length, 1);
  assert.deepEqual(errors, []);
});

test("parseFeedback / formValues: CRLF normalised, control characters dropped, context collapsed, unknown kind → bug", () => {
  const v = formValues({ kind: "weird", message: "line one\r\nline two\u0000 here", email: "", context: "  v0.11.0 \n Windows  " });
  assert.deepEqual(v, { kind: "bug", message: "line one\nline two here", email: "", context: "v0.11.0 Windows" });
  assert.deepEqual(parseFeedback(v, "de", null), { ok: true, value: { kind: "bug", message: "line one\nline two here", replyEmail: null, context: "v0.11.0 Windows", lang: "de", userId: null } });
  const bad = parseFeedback({ kind: "bug", message: "short", email: "not-an-email", context: "" }, "en", null);
  assert.deepEqual(bad, { ok: false, errors: { message: "message_short", email: "email_invalid" } }, "both field errors at once, no value");
});

test("feedbackEmail: one-line subject cut at 60 characters, everything escaped in the HTML", () => {
  const m = feedbackEmail({ kind: "bug", message: "a\nb <script>alert(1)</script> " + "x".repeat(100), replyEmail: null, context: null, lang: "ja", signedIn: false });
  assert.doesNotMatch(m.subject, /\n/);
  assert.ok([...m.subject.replace("[Quidditch Manager] Bug: ", "")].length <= 60);
  assert.match(m.subject, /…$/);
  assert.doesNotMatch(m.html, /<script>alert/);
  assert.match(m.html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.equal(m.replyTo, undefined);
  assert.doesNotMatch(m.text, /Reply to/);
});

test("resendMailer: a reply address becomes Resend's reply_to; without one the field is absent", async () => {
  const bodies: Array<Record<string, unknown>> = [];
  const fetchImpl = (async (_url: string | URL | Request, init?: RequestInit) => {
    bodies.push(JSON.parse(String(init?.body)) as Record<string, unknown>);
    return new Response("{}", { status: 200 });
  }) as typeof fetch;
  const mailer = resendMailer("key", "QM <login@example.org>", fetchImpl);
  await mailer.send({ to: TO, subject: "s", text: "t", html: "<p>t</p>", replyTo: "player@example.com" });
  await mailer.send({ to: TO, subject: "s", text: "t", html: "<p>t</p>" });
  assert.equal(bodies[0]!.reply_to, "player@example.com");
  assert.ok(!("reply_to" in bodies[1]!));
});
