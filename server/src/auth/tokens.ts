import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";

export const TOKEN_BYTES = 32;
export const TOKEN_RE = new RegExp(`^[A-Za-z0-9_-]{${Math.ceil((TOKEN_BYTES * 4) / 3)}}$`);

export function randomToken(bytes = TOKEN_BYTES): string {
  return randomBytes(bytes).toString("base64url");
}

export function sha256Hex(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

export function hmacBase64url(key: Buffer, value: string): string {
  return createHmac("sha256", key).update(value, "utf8").digest("base64url");
}

export function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(a, "utf8");
  const bb = Buffer.from(b, "utf8");
  return ab.length === bb.length && timingSafeEqual(ab, bb);
}

export function signPayload(key: Buffer, payload: unknown): string {
  const body = Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");
  return `${body}.${hmacBase64url(key, body)}`;
}

export function verifySigned<T>(key: Buffer, value: string | null | undefined): T | null {
  if (!value || value.length > 4096) return null;
  const dot = value.indexOf(".");
  if (dot <= 0 || dot !== value.lastIndexOf(".")) return null;
  const body = value.slice(0, dot);
  const mac = value.slice(dot + 1);
  if (!safeEqual(mac, hmacBase64url(key, body))) return null;
  try {
    return JSON.parse(Buffer.from(body, "base64url").toString("utf8")) as T;
  } catch {
    return null;
  }
}
