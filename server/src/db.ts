import postgres from "postgres";

export interface TxDb {
  query<T = Record<string, unknown>>(text: string, values?: unknown[]): Promise<T[]>;
}

export interface Db extends TxDb {
  transaction<T>(fn: (tx: TxDb) => Promise<T>): Promise<T>;
}

export function toMs(v: string | Date | null | undefined): number | null {
  if (v === null || v === undefined) return null;
  const ms = v instanceof Date ? v.getTime() : Date.parse(v);
  return Number.isFinite(ms) ? ms : null;
}

export function toIso(v: string | Date | null | undefined): string | null {
  const ms = toMs(v);
  return ms === null ? null : new Date(ms).toISOString();
}

export function pgError(e: unknown): { code: string | null; constraint: string | null } {
  const err = e as { code?: unknown; constraint_name?: unknown; constraint?: unknown } | null;
  return {
    code: typeof err?.code === "string" ? err.code : null,
    constraint: typeof err?.constraint_name === "string" ? err.constraint_name : typeof err?.constraint === "string" ? err.constraint : null,
  };
}

type Sql = postgres.Sql<Record<string, never>>;
type TxSql = postgres.TransactionSql<Record<string, never>>;

function queryOn(sql: Sql | TxSql): TxDb["query"] {
  return async <T>(text: string, values: unknown[] = []): Promise<T[]> => {
    const rows = await sql.unsafe(text, values as never[]);
    return Array.from(rows as unknown as Iterable<T>);
  };
}

function wrap(sql: Sql): Db {
  return {
    query: queryOn(sql),
    async transaction<T>(fn: (tx: TxDb) => Promise<T>): Promise<T> {
      return (await sql.begin((tx) => fn({ query: queryOn(tx) }))) as T;
    },
  };
}

export interface PgPool {
  db: Db;
  sql: Sql;
  close(): Promise<void>;
}

export function createPool(databaseUrl: string, max = 5): PgPool {
  const sql = postgres(databaseUrl, {
    max,
    idle_timeout: 60,
    connect_timeout: 10,
    onnotice: () => undefined,
    connection: { application_name: "qm-api" },
  }) as unknown as Sql;
  return { db: wrap(sql), sql, close: () => sql.end({ timeout: 5 }) };
}
