import { createHash } from "node:crypto";
import { readFile, stat } from "node:fs/promises";
import { readFileSync } from "node:fs";
import { extname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

export const STATIC_DIR = fileURLToPath(new URL("../../static/", import.meta.url));

export const MIME: Record<string, string> = {
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".ico": "image/x-icon",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".gz": "application/gzip",
  ".webmanifest": "application/manifest+json",
};

export function safeJoin(root: string, rel: string): string | null {
  let decoded: string;
  try {
    decoded = decodeURIComponent(rel);
  } catch {
    return null;
  }
  if (decoded.includes("\0") || decoded.includes("\\")) return null;
  if (decoded.split("/").some((seg) => seg.startsWith("."))) return null;
  const base = resolve(root);
  const full = resolve(base, "." + (decoded.startsWith("/") ? decoded : "/" + decoded));
  return full === base || full.startsWith(base + sep) ? full : null;
}

export async function readStatic(root: string, rel: string): Promise<{ body: Uint8Array; type: string } | null> {
  const full = safeJoin(root, rel);
  if (!full) return null;
  try {
    const st = await stat(full);
    if (!st.isFile()) return null;
    const body = await readFile(full);
    return { body: new Uint8Array(body), type: MIME[extname(full).toLowerCase()] ?? "application/octet-stream" };
  } catch {
    return null;
  }
}

export function computeAssetVersion(root = STATIC_DIR): string {
  const h = createHash("sha256");
  for (const f of ["site.css", "icon.png", "logo.png", "register.js", "og.jpg", "shot-squad.webp", "shot-match.webp", "shot-hogwarts.webp"]) {
    try {
      h.update(readFileSync(resolve(root, f)));
    } catch {
      h.update(f);
    }
  }
  return h.digest("hex").slice(0, 10);
}
