import { createHmac } from "node:crypto";
import { isIP } from "node:net";

export const INTERNAL_IP_BUCKET = "internal";

export function parseIpv6(raw: string): number[] | null {
  let s = raw.trim().toLowerCase();
  if (s.startsWith("[") && s.endsWith("]")) s = s.slice(1, -1);
  const zone = s.indexOf("%");
  if (zone !== -1) s = s.slice(0, zone);
  if (isIP(s) !== 6) return null;
  // Embedded dotted IPv4 at the end (`::ffff:1.2.3.4`, `64:ff9b::8.8.8.8`) → two hex groups.
  const lastColon = s.lastIndexOf(":");
  const tail = s.slice(lastColon + 1);
  if (tail.includes(".")) {
    const parts = tail.split(".").map(Number);
    if (parts.length !== 4 || parts.some((n) => !Number.isInteger(n) || n < 0 || n > 255)) return null;
    const [a, b, c, d] = parts as [number, number, number, number];
    s = `${s.slice(0, lastColon + 1)}${((a << 8) | b).toString(16)}:${((c << 8) | d).toString(16)}`;
  }
  const halves = s.split("::");
  if (halves.length > 2) return null;
  const head = halves[0] ? halves[0].split(":") : [];
  const rest = halves.length === 2 && halves[1] ? halves[1].split(":") : [];
  const missing = 8 - head.length - rest.length;
  if (missing < 0 || (halves.length === 1 && missing !== 0)) return null;
  const groups = [...head, ...Array<string>(halves.length === 2 ? missing : 0).fill("0"), ...rest].map((g) => Number.parseInt(g, 16));
  if (groups.length !== 8 || groups.some((g) => !Number.isInteger(g) || g < 0 || g > 0xffff)) return null;
  return groups;
}

export function ipBucket(ip: string): string {
  const groups = parseIpv6(ip);
  if (!groups) return ip;
  if (groups.slice(0, 5).every((g) => g === 0) && groups[5] === 0xffff) {
    const hi = groups[6] ?? 0;
    const lo = groups[7] ?? 0;
    return `${hi >> 8}.${hi & 0xff}.${lo >> 8}.${lo & 0xff}`;
  }
  return `${groups.slice(0, 4).map((g) => g.toString(16)).join(":")}::/64`;
}

const headerIp = (value: string | null | undefined): string | null => {
  const ip = (value ?? "").split(",")[0]?.trim().slice(0, 64) ?? "";
  return ip && isIP(ip) ? ip : null;
};

export interface HeaderBag {
  get(name: string): string | null | undefined;
}

export function clientIp(headers: HeaderBag, trustedHeaders: readonly string[]): string {
  for (const name of trustedHeaders) {
    const ip = headerIp(headers.get(name));
    if (ip) return ip;
  }
  return INTERNAL_IP_BUCKET;
}

export function ipKey(ip: string, key: Buffer): string {
  return createHmac("sha256", key).update("ip:" + ipBucket(ip)).digest("hex").slice(0, 32);
}
