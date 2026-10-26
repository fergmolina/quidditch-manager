import assert from "node:assert/strict";
import { test } from "node:test";
import { escapeHtml, html, trustedHtml } from "../src/http/html.js";
import { clientIp, INTERNAL_IP_BUCKET, ipBucket, ipKey, parseIpv6 } from "../src/http/ip.js";
import { isOwnOrigin, loginPostRejection, sameOriginRejection } from "../src/http/origin.js";
import { isAllowedNext, isSafeNextPath, loginErrorPath, safeNext } from "../src/http/redirect.js";
import { safeJoin } from "../src/http/static.js";
import { userAgentFamily } from "../src/http/ua.js";
import { headers } from "./helpers.js";

test("isSafeNextPath: same-site paths only", () => {
  const ok = ["/", "/x", "/play/", "/account?tab=1#top", "/register?next=%2Fplay%2F"];
  const bad = ["//evil", "//evil.com/x", "http://x", "https://x/y", "/\\evil", "\\evil", "/x\\y", "/x\n", "/x\r\n", "/x\t", "/x\0", "/x\u007f", "x", "", "/" + "a".repeat(512)];
  for (const p of ok) assert.equal(isSafeNextPath(p), true, p);
  for (const p of bad) assert.equal(isSafeNextPath(p), false, JSON.stringify(p));
  assert.equal(isSafeNextPath(null), false);
  assert.equal(isSafeNextPath(42), false);
});

test("isAllowedNext / safeNext: prefix allowlist on top of the safe-path rule", () => {
  for (const p of ["/", "/?lang=es", "/play/", "/play/index.html", "/account", "/account/", "/account?x=1", "/register?next=%2Fplay%2F", "/login?error=link", "/feedback?sent=1", "/pending"]) {
    assert.equal(isAllowedNext(p), true, p);
    assert.equal(safeNext(p), p);
  }
  for (const p of ["/play", "/accountx", "/api/me", "/auth/logout", "/static/site.css", "/registerx", "//play/", "/admin", "/admin/users", "/pendingx"]) {
    assert.equal(isAllowedNext(p), false, p);
    assert.equal(safeNext(p), "/play/", p);
  }
  assert.equal(safeNext(null), "/play/");
  assert.equal(safeNext(undefined, "/account"), "/account");
  assert.equal(loginErrorPath("link"), "/login?error=link");
  assert.equal(loginErrorPath("blocked", "/play/"), "/login?error=blocked&next=%2Fplay%2F");
  assert.equal(loginErrorPath("blocked", "//evil"), "/login?error=blocked");
});

test("isOwnOrigin: SITE_URL origin; local dev servers only outside production", () => {
  const site = "https://qm.example.org";
  assert.equal(isOwnOrigin(site, site, true), true);
  assert.equal(isOwnOrigin("https://evil.example.org", site, true), false);
  assert.equal(isOwnOrigin("http://localhost:8080", site, true), false);
  assert.equal(isOwnOrigin("http://localhost:8080", site, false), true);
  assert.equal(isOwnOrigin("http://127.0.0.1:3000", site, false), true);
  assert.equal(isOwnOrigin("http://localhost.evil.com", site, false), false);
  assert.equal(isOwnOrigin(null, site, false), false);
  assert.equal(isOwnOrigin("null", site, false), false);
});

test("tier 1 sameOriginRejection: Origin required and own; Sec-Fetch-Site same-origin or none", () => {
  const site = "https://qm.example.org";
  const ok = (o: string) => o === site;
  assert.equal(sameOriginRejection(headers({ origin: site, "sec-fetch-site": "same-origin" }), ok), null);
  assert.equal(sameOriginRejection(headers({ origin: site, "sec-fetch-site": "none" }), ok), null);
  assert.equal(sameOriginRejection(headers({ origin: site }), ok), null, "old browsers without Fetch Metadata");
  assert.equal(sameOriginRejection(headers({ origin: site, "sec-fetch-site": "same-site" }), ok), "fetch_site");
  assert.equal(sameOriginRejection(headers({ origin: site, "sec-fetch-site": "cross-site" }), ok), "fetch_site");
  assert.equal(sameOriginRejection(headers({ origin: "https://evil.example" }), ok), "origin");
  assert.equal(sameOriginRejection(headers({ origin: "null" }), ok), "origin");
  assert.equal(sameOriginRejection(headers({}), ok), "origin", "no Origin at all");
});

test("tier 2 loginPostRejection: exactly same-origin; Origin, else same-origin Referer", () => {
  const site = "https://qm.example.org";
  const ok = (o: string) => o === site;
  assert.equal(loginPostRejection(headers({ "sec-fetch-site": "same-origin", origin: site }), ok), null);
  assert.equal(loginPostRejection(headers({ "sec-fetch-site": "none", origin: site }), ok), "fetch_site", "typed URL / bookmark");
  assert.equal(loginPostRejection(headers({ "sec-fetch-site": "same-site", origin: site }), ok), "fetch_site");
  assert.equal(loginPostRejection(headers({ "sec-fetch-site": "cross-site" }), ok), "fetch_site");
  assert.equal(loginPostRejection(headers({ origin: site }), ok), null);
  assert.equal(loginPostRejection(headers({ origin: "null" }), ok), "origin", "no-referrer form post");
  assert.equal(loginPostRejection(headers({ referer: `${site}/auth/magic/verify?token=x` }), ok), null);
  assert.equal(loginPostRejection(headers({ referer: "https://evil.example/x" }), ok), "origin");
  assert.equal(loginPostRejection(headers({ referer: "not a url" }), ok), "origin");
  assert.equal(loginPostRejection(headers({}), ok), "origin");
});

test("parseIpv6 and ipBucket: /64 for IPv6, IPv4 unchanged, mapped IPv4 unwrapped", () => {
  assert.deepEqual(parseIpv6("2001:db8::1"), [0x2001, 0xdb8, 0, 0, 0, 0, 0, 1]);
  assert.deepEqual(parseIpv6("[::1]"), [0, 0, 0, 0, 0, 0, 0, 1]);
  assert.deepEqual(parseIpv6("fe80::1%eth0"), [0xfe80, 0, 0, 0, 0, 0, 0, 1]);
  assert.equal(parseIpv6("1.2.3.4"), null);
  assert.equal(parseIpv6("2001:db8:::1"), null);
  assert.equal(ipBucket("2001:db8:1:2:aaaa:bbbb:cccc:dddd"), "2001:db8:1:2::/64");
  assert.equal(ipBucket("2001:db8:1:2::ffff"), "2001:db8:1:2::/64", "same /64, different host: same bucket");
  assert.notEqual(ipBucket("2001:db8:1:3::1"), ipBucket("2001:db8:1:2::1"));
  assert.equal(ipBucket("203.0.113.9"), "203.0.113.9");
  assert.equal(ipBucket("::ffff:203.0.113.9"), "203.0.113.9");
  assert.equal(ipBucket(INTERNAL_IP_BUCKET), INTERNAL_IP_BUCKET);
});

test("clientIp: the first trusted header carrying an IP wins; anything else is the internal bucket", () => {
  const prod = ["cf-connecting-ip"];
  const dev = ["cf-connecting-ip", "x-forwarded-for"];
  assert.equal(clientIp(headers({ "cf-connecting-ip": "203.0.113.9", "x-forwarded-for": "1.1.1.1" }), prod), "203.0.113.9");
  assert.equal(clientIp(headers({ "x-forwarded-for": "1.1.1.1" }), prod), INTERNAL_IP_BUCKET, "an untrusted header is never read");
  assert.equal(clientIp(headers({ "x-forwarded-for": "1.1.1.1, 10.0.0.1" }), dev), "1.1.1.1");
  assert.equal(clientIp(headers({ "cf-connecting-ip": "not-an-ip" }), prod), INTERNAL_IP_BUCKET);
  assert.equal(clientIp(headers({ "x-real-ip": "198.51.100.4" }), ["x-real-ip"]), "198.51.100.4");
  assert.equal(clientIp(headers({}), dev), INTERNAL_IP_BUCKET);
});

test("ipKey: keyed hash of the bucket (no raw IP), stable per key, differs across keys", () => {
  const k1 = Buffer.from("a".repeat(32));
  const k2 = Buffer.from("b".repeat(32));
  const a = ipKey("2001:db8:1:2::1", k1);
  assert.match(a, /^[0-9a-f]{32}$/);
  assert.equal(a, ipKey("2001:db8:1:2::9999", k1), "same /64");
  assert.notEqual(a, ipKey("2001:db8:1:2::1", k2));
  assert.ok(!a.includes("2001"));
});

test("userAgentFamily: coarse browser · OS only", () => {
  assert.equal(userAgentFamily("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"), "Chrome · Windows");
  assert.equal(userAgentFamily("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"), "Safari · macOS");
  assert.equal(userAgentFamily("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/130.0 Mobile/15E148 Safari/604.1"), "Chrome · iOS");
  assert.equal(userAgentFamily("Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0"), "Firefox · Linux");
  assert.equal(userAgentFamily("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36 Edg/130.0"), "Edge · Windows");
  assert.equal(userAgentFamily("curl/8.0"), null);
  assert.equal(userAgentFamily(null), null);
});

test("html tag escapes every interpolation; trustedHtml and nested html pass through", () => {
  const evil = `<script>alert("x")</script>&'`;
  assert.equal(escapeHtml(evil), "&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;&amp;&#39;");
  const out = html`<p title="${evil}">${evil}${html`<b>${evil}</b>`}${trustedHtml("<i>ok</i>")}${null}${false}${[1, "<", html`<u></u>`]}</p>`.toString();
  assert.ok(!out.includes("<script>"));
  assert.ok(out.includes("<b>&lt;script&gt;"));
  assert.ok(out.includes("<i>ok</i>"));
  assert.ok(out.includes("1&lt;<u></u>"));
});

test("safeJoin: no traversal, no dotfiles, stays under the root", () => {
  const root = "/srv/static";
  assert.equal(safeJoin(root, "site.css"), "/srv/static/site.css");
  assert.equal(safeJoin(root, "fonts/a.ttf"), "/srv/static/fonts/a.ttf");
  for (const bad of ["../etc/passwd", "fonts/../../x", "%2e%2e/x", ".env", "a/.git/config", "a\\b", "a%00b", "%E0%A4%A"]) assert.equal(safeJoin(root, bad), null, bad);
});
