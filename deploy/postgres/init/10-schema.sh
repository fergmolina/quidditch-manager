#!/bin/bash
# The official postgres entrypoint runs every file in /docker-entrypoint-initdb.d/ ONCE,
# when the data volume is empty, against a temporary server started with the same flags as the real one (so pg_cron
# is already preloaded).
# Expected noise on the first boot: one `FATAL: database "<POSTGRES_DB>" does not exist` from the pg_cron launcher, which
# starts with the temporary server a moment before POSTGRES_DB is created; it retries on its own.
set -euo pipefail

if [[ "${QM_INIT_SCHEMA:-1}" != "1" ]]; then
  echo "qm: QM_INIT_SCHEMA=${QM_INIT_SCHEMA} → database left empty (restore a dump, then run deploy/db/apply.sh)"
  exit 0
fi

# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../lib/db.sh
. /srv/deploy/lib/db.sh

run() { psql -X -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -q "$@"; }

mapfile -t files < <(migration_files /opt/qm/migrations)
if (( ${#files[@]} == 0 )); then
  echo "qm: no migrations under /opt/qm/migrations (is ../server/migrations mounted?)" >&2
  exit 1
fi

echo "qm: migrations"
for f in "${files[@]}"; do
  echo "   $(basename "$f")"
  run -f "$f" 2>&1 | sed 's/^/     /'
done

if [[ -n "${DB_API_PASSWORD:-}" ]]; then
  set_qm_api_password --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"
  echo "qm: qm_api password set"
else
  echo "qm: DB_API_PASSWORD empty: qm_api has no password yet (deploy/db/apply.sh sets it)"
fi

echo "qm: schema ready ($(run -At -c "select count(*) from pg_tables where schemaname = 'public'") tables, $(run -At -c "select count(*) from cron.job" 2>/dev/null || echo 0) cron jobs)"
