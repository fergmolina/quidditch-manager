#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Apply every migration (server/migrations/NNNN_name.sql, in name order) with psql, then set the qm_api password.
Idempotent: there is no ledger table, every file is written to be re-run (server/migrations/0001_accounts.sql).

Runs inside the backup toolbox (psql 16), which gets the superuser connection as PG* variables from compose:
  ./deploy/update.sh --target migrate [vX.Y.Z]          # the normal way (migrations of that tag, or the checkout)
  ./deploy/compose.sh run --rm --no-deps -T backup /srv/deploy/db/apply.sh [--dry-run] [--verify]

  --dry-run   list the files that would run
  --verify    afterwards, list the tables, the qm_api grants and the pg_cron jobs

Env: PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE (superuser: 0003_roles.sql creates roles and default privileges),
     MIGRATIONS_DIR (default /srv/migrations), DB_API_USER (default qm_api), DB_API_PASSWORD.

RULE: migrate first, then deploy. update.sh never migrates on its own.
EOF
}

DRY=0; VERIFY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --verify)  VERIFY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "apply.sh: unknown option: $a" >&2; exit 2 ;;
  esac
done

# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/db.sh
. "${BASH_SOURCE[0]%/*}/../lib/db.sh"

DIR="${MIGRATIONS_DIR:-/srv/migrations}"
: "${PGDATABASE:?PGDATABASE is not set (run through the backup service)}"
command -v psql >/dev/null || { echo "apply.sh: psql not found" >&2; exit 1; }

run() { psql -X -v ON_ERROR_STOP=1 -q "$@"; }

mapfile -t files < <(migration_files "$DIR")
(( ${#files[@]} > 0 )) || { echo "apply.sh: no migrations in $DIR" >&2; exit 1; }

echo "== target: $(run -At -c "select current_database() || ' (' || split_part(version(), ' on ', 1) || ')'")"
echo "== migrations from $DIR"
for f in "${files[@]}"; do
  echo "   $(basename "$f")"
  if [[ "$DRY" == 0 ]]; then
    run -f "$f" 2>&1 | sed 's/^/     /'
  fi
done
[[ "$DRY" == 1 ]] && exit 0

API_USER="${DB_API_USER:-qm_api}"
if [[ "$API_USER" == qm_api ]]; then
  if [[ -n "${DB_API_PASSWORD:-}" ]]; then
    set_qm_api_password
    echo "== qm_api password set from DB_API_PASSWORD"
  else
    echo "== WARNING: DB_API_PASSWORD is empty: the api cannot log in as qm_api" >&2
  fi
else
  echo "== DB_API_USER=$API_USER (not qm_api): password left alone"
fi

if [[ "$VERIFY" == 1 ]]; then
  echo "== tables"
  run -c "select tablename from pg_tables where schemaname = 'public' order by 1"
  echo "== qm_api grants"
  run -c "select table_name, string_agg(privilege_type, ', ' order by privilege_type) as privileges
            from information_schema.role_table_grants where grantee = 'qm_api' group by 1 order by 1"
  echo "== pg_cron jobs"
  run -c "select jobname, schedule, command from cron.job order by jobname" 2>/dev/null \
    || echo "   (pg_cron not loaded in this database)"
fi
echo "== done"
