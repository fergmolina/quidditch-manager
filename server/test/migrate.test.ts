import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { MIGRATION_FILE, migrationFiles, MIGRATIONS_DIR } from "../scripts/migrate.js";

test("the migration filename filter is the one deploy/lib/db.sh applies with psql", () => {
  const sh = readFileSync(new URL("../../deploy/lib/db.sh", import.meta.url), "utf8");
  const m = /^MIGRATION_FILE_PATTERN='([^']+)'$/m.exec(sh);
  assert.ok(m, "deploy/lib/db.sh defines MIGRATION_FILE_PATTERN='...'");
  assert.equal(m[1], MIGRATION_FILE.source);
});

test("migrationFiles keeps NNNN_name.sql only, in name order", () => {
  for (const ok of ["0001_accounts.sql", "0012_a_b9.sql"]) assert.ok(MIGRATION_FILE.test(ok), ok);
  for (const no of ["001_short.sql", "0001_Caps.sql", "0001-dash.sql", "0001_x.sql.bak", "readme.sql", "0001_.sql"]) assert.ok(!MIGRATION_FILE.test(no), no);
  const files = migrationFiles(MIGRATIONS_DIR);
  assert.ok(files.length >= 5, `found ${files.length} migrations`);
  assert.deepEqual(files, [...files].sort());
});
