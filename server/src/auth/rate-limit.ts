import type { Db } from "../db.js";

export interface RateLimitInput {
  bucket: string;
  subject: string;
  limit: number;
  windowMs: number;
}

export async function hitRateLimit(db: Db, { bucket, subject, limit, windowMs }: RateLimitInput, nowMs = Date.now()): Promise<boolean> {
  if (limit < 1) throw new RangeError("hitRateLimit: limit must be at least 1");
  if (windowMs > 86_400_000) throw new RangeError("hitRateLimit: window longer than the 24 h retention");
  const rows = await db.query<{ id: string }>(
    `insert into public.auth_rate_events (bucket, subject, created_at)
     select $1, $2, $3::timestamptz
      where (select count(*) from public.auth_rate_events
              where bucket = $1 and subject = $2 and created_at > $4::timestamptz) < $5
     returning id`,
    [bucket.slice(0, 40), subject.slice(0, 80), new Date(nowMs).toISOString(), new Date(nowMs - windowMs).toISOString(), limit],
  );
  return rows.length > 0;
}

export interface BurstDecision {
  allowed: boolean;
  limit: number;
  remaining: number;
  retryAfter: number;
}

export interface BurstLimiterOptions {
  limit: number;
  windowMs?: number;
  maxSubjects?: number;
  now?: () => number;
}

class LruMap<K, V> {
  private readonly map = new Map<K, V>();

  get(key: K): V | undefined {
    return this.map.get(key);
  }

  setMostRecent(key: K, value: V): void {
    this.map.delete(key);
    this.map.set(key, value);
  }

  evictLeastRecentOver(max: number): void {
    for (const key of this.map.keys()) {
      if (this.map.size <= max) break;
      this.map.delete(key);
    }
  }

  get size(): number {
    return this.map.size;
  }
}

/** Per-process state: the deployment runs a single api replica (docs/design/12-web-version.md, "One api container"). */
export class BurstLimiter {
  readonly limit: number;
  private readonly windowMs: number;
  private readonly maxSubjects: number;
  private readonly now: () => number;
  private readonly hits = new LruMap<string, number[]>();

  constructor({ limit, windowMs = 60_000, maxSubjects = 10_000, now = Date.now }: BurstLimiterOptions) {
    if (!Number.isInteger(limit) || limit < 1) throw new RangeError("BurstLimiter: limit must be a positive integer");
    this.limit = limit;
    this.windowMs = windowMs;
    this.maxSubjects = Math.max(1, maxSubjects);
    this.now = now;
  }

  take(subject: string): BurstDecision {
    const t = this.now();
    const cutoff = t - this.windowMs;
    const list = (this.hits.get(subject) ?? []).filter((x) => x > cutoff);
    if (list.length >= this.limit) {
      this.hits.setMostRecent(subject, list);
      const oldest = list[0] ?? t;
      return { allowed: false, limit: this.limit, remaining: 0, retryAfter: Math.max(1, Math.ceil((oldest + this.windowMs - t) / 1000)) };
    }
    list.push(t);
    this.hits.setMostRecent(subject, list);
    this.hits.evictLeastRecentOver(this.maxSubjects);
    return { allowed: true, limit: this.limit, remaining: this.limit - list.length, retryAfter: 0 };
  }

  get size(): number {
    return this.hits.size;
  }
}
