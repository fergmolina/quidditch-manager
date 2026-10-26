import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { randomToken, safeEqual, sha256Hex, signPayload, verifySigned } from "../src/auth/tokens.js";

test("sha256Hex matches node:crypto; randomToken is base64url of the right length", () => {
  assert.equal(sha256Hex("abc"), createHash("sha256").update("abc").digest("hex"));
  assert.notEqual(sha256Hex("abc"), sha256Hex("abd"));
  assert.match(randomToken(), /^[A-Za-z0-9_-]{43}$/);
  assert.match(randomToken(16), /^[A-Za-z0-9_-]{22}$/);
  const seen = new Set(Array.from({ length: 100 }, () => randomToken()));
  assert.equal(seen.size, 100);
});

test("safeEqual: constant-time equality, false on different lengths", () => {
  assert.equal(safeEqual("abc", "abc"), true);
  assert.equal(safeEqual("abc", "abd"), false);
  assert.equal(safeEqual("abc", "abcd"), false);
  assert.equal(safeEqual("", ""), true);
});

test("signPayload / verifySigned: round trip, tamper, wrong key, malformed", () => {
  const key = Buffer.from("k".repeat(32));
  const v = signPayload(key, { a: 1, s: "x" });
  assert.deepEqual(verifySigned(key, v), { a: 1, s: "x" });
  const [body, mac] = v.split(".") as [string, string];
  const forged = Buffer.from(JSON.stringify({ a: 2, s: "x" })).toString("base64url");
  assert.equal(verifySigned(key, `${forged}.${mac}`), null, "edited body");
  assert.equal(verifySigned(key, `${body}.${mac.slice(0, -2)}AA`), null, "edited mac");
  assert.equal(verifySigned(Buffer.from("x".repeat(32)), v), null, "other key");
  for (const bad of [null, undefined, "", "nodot", "a.b.c", ".x", "x".repeat(5000)]) assert.equal(verifySigned(key, bad), null, String(bad));
});
