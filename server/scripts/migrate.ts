/**
 * Applies every server/migrations/*.sql file in name order (they are idempotent; there is no ledger table). For
 * local development and the integration tests; the deploy uses psql (deploy/db/apply.sh) the same way.
 *
 *   npm run migrate                 # uses DATABASE_URL (or the dev default)
 */
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import postgres from "postgres";

export const MIGRATIONS_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "../migrations");

/** Same pattern as MIGRATION_FILE_PATTERN in deploy/lib/db.sh (POSIX ERE, hence `[0-9]`); test/migrate.test.ts compares them. */
export const MIGRATION_FILE = /^[0-9]{4}_[a-z0-9_]+\.sql$/;

export function migrationFiles(dir = MIGRATIONS_DIR): string[] {
  return readdirSync(dir)
    .filter((f) => MIGRATION_FILE.test(f))
    .sort();
}

/** Runs each file as one simple-protocol batch (files carry their own begin/commit). */
export async function applyMigrations(databaseUrl: string, dir = MIGRATIONS_DIR, log: (s: string) => void = () => undefined): Promise<string[]> {
  const sql = postgres(databaseUrl, { max: 1, onnotice: () => undefined });
  const applied: string[] = [];
  try {
    for (const f of migrationFiles(dir)) {
      await sql.unsafe(readFileSync(join(dir, f), "utf8")).simple();
      applied.push(f);
      log(`[migrate] ${f}`);
    }
  } finally {
    await sql.end({ timeout: 5 });
  }
  return applied;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const url = process.env.DATABASE_URL ?? "postgres://postgres:postgres@127.0.0.1:5432/qm";
  applyMigrations(url, MIGRATIONS_DIR, (s) => console.log(s)).catch((e) => {
    console.error(`[migrate] failed: ${e instanceof Error ? e.message : String(e)}`);
    process.exitCode = 1;
  });
}
