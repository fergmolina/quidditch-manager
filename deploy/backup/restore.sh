#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Restore a backup (pg_dump -Fc, from deploy/backup/backup.sh) into the compose `db`. Two uses:
  - the quarterly RESTORE TEST:   deploy/backup/restore.sh <dump> --scratch
    restores into a throwaway database qm_restore_test, prints row counts, drops it. Production is untouched.
  - a real recovery:              deploy/backup/restore.sh <dump> --wipe
    stops the api, replaces schema public of the production database (POSTGRES_DB, default `qm`), re-applies the migrations (deploy/db/apply.sh: roles, grants,
    qm_api password, pg_cron jobs, all lost or absent in a --no-owner --no-privileges dump), starts the api.

  deploy/backup/restore.sh <dump> [--scratch [--keep]] [--wipe] [--no-apply] [--jobs N]

  <dump>       a .dump file: under ${QM_DATA_DIR}/backups (seen by the toolbox as /backups/…) or any other path
               (mounted read-only for the run). Offsite copies: `backup.sh --fetch` first (see backup.sh).
  --scratch    restore into qm_restore_test, count, drop (--keep leaves it for inspection)
  --wipe       required when the production database already has tables
  --no-apply   skip deploy/db/apply.sh after a real restore (the api then cannot log in until you run it)
  --jobs N     pg_restore parallel workers (default 2)

Runs on the VPS from anywhere (uses ./deploy/compose.sh). Never touches cloudflared or caddy.
EOF
}
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE=("$DEPLOY_DIR/compose.sh")

DUMP=""; WIPE=0; APPLY=1; SCRATCH=0; KEEP=0; JOBS=2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wipe) WIPE=1 ;; --no-apply) APPLY=0 ;; --scratch) SCRATCH=1 ;; --keep) KEEP=1 ;;
    --jobs) JOBS="${2:?--jobs needs a number}"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) DUMP="$1" ;;
  esac
  shift
done
[[ -n "$DUMP" && -f "$DUMP" ]] || { echo "usage: deploy/backup/restore.sh <file.dump> [--scratch [--keep]] [--wipe] [--no-apply] [--jobs N]" >&2; exit 2; }
[[ "$JOBS" =~ ^[0-9]+$ ]] || { echo "--jobs must be a number" >&2; exit 2; }

ENV_FILE="${QM_ENV_FILE:-$(dirname "$DEPLOY_DIR")/.env}"
DATA_DIR="$(grep -E '^QM_DATA_DIR=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"'"'" || true)"
DATA_DIR="${DATA_DIR:-/srv/quidditch-manager-data}"
ABS="$(cd "$(dirname "$DUMP")" && pwd)/$(basename "$DUMP")"
case "$ABS" in
  "$DATA_DIR/backups/"*) IN_CT="/backups/${ABS#"$DATA_DIR"/backups/}"; MOUNT=() ;;
  *) IN_CT="/restore/$(basename "$ABS")"; MOUNT=(-v "$ABS:$IN_CT:ro") ;;
esac

TARGET=qm_restore_test
if [[ "$SCRATCH" != 1 ]]; then
  # The toolbox's PGDATABASE is compose's POSTGRES_DB, resolved from the same shell and env file as the db service.
  TARGET="$("${COMPOSE[@]}" run --rm --no-deps -T backup printenv PGDATABASE)" \
    || { echo "could not read PGDATABASE from the backup service" >&2; exit 1; }
fi
step(){ printf '\n== %s\n' "$*"; }
tb()   { "${COMPOSE[@]}" run --rm --no-deps -T ${MOUNT[@]+"${MOUNT[@]}"} -e TARGET="$TARGET" "$@"; }
# shellcheck disable=SC2016
sqla() { tb -e SQL="$1" backup bash -c 'psql -X -d postgres -v ON_ERROR_STOP=1 -qAt -c "$SQL"'; }
# shellcheck disable=SC2016
sqlt() { tb -e SQL="$1" backup bash -c 'psql -X -d "$TARGET" -v ON_ERROR_STOP=1 -qAt -c "$SQL"'; }

step "target: $TARGET ← $DUMP ($(du -hL "$ABS" | cut -f1))"
"${COMPOSE[@]}" up -d --wait db >/dev/null
tb backup pg_restore --list "$IN_CT" >/dev/null \
  || { echo "not a pg_dump custom-format file (or written by a pg_dump newer than 16)" >&2; exit 1; }

# pg_dump --schema=public writes CREATE SCHEMA public: the target must not have the schema for a clean restore.
TOC="$(tb backup pg_restore --list "$IN_CT" 2>/dev/null || true)"
DUMP_HAS_SCHEMA=0
grep -qE ' SCHEMA - public ' <<<"$TOC" && DUMP_HAS_SCHEMA=1
prepare_schema() {
  if [[ "$DUMP_HAS_SCHEMA" == 1 ]]; then sqlt "drop schema if exists public cascade" >/dev/null
  else sqlt "drop schema if exists public cascade; create schema public;" >/dev/null; fi
}

API_STOPPED=0
if [[ "$SCRATCH" == 1 ]]; then
  step "create $TARGET"
  sqla "drop database if exists $TARGET with (force)" >/dev/null 2>&1 || true
  sqla "create database $TARGET" >/dev/null
  prepare_schema
else
  TABLES="$(sqlt "select count(*) from pg_tables where schemaname = 'public'")"
  if [[ "$TABLES" != 0 && "$WIPE" != 1 ]]; then
    echo "schema public of $TARGET already has $TABLES tables. Re-run with --wipe to replace it (the api is stopped" >&2
    echo "meanwhile), or use --scratch for a test restore." >&2
    exit 1
  fi
  step "stop api, replace schema public ($TABLES tables now)"
  "${COMPOSE[@]}" stop api >/dev/null 2>&1 || true
  API_STOPPED=1
  prepare_schema 2>&1 | grep -vE '^(NOTICE|DETAIL|drop cascades)' || true
fi

step "pg_restore --jobs $JOBS"
RESTORE_LOG="$(mktemp)"
trap 'rm -f "$RESTORE_LOG"' EXIT
set +e
# shellcheck disable=SC2016
tb -e JOBS="$JOBS" -e IN_CT="$IN_CT" backup bash -c 'pg_restore --no-owner --no-privileges --jobs "$JOBS" -d "$TARGET" "$IN_CT"' >"$RESTORE_LOG" 2>&1
rc=$?
set -e
{ grep -vE '^ Container ' "$RESTORE_LOG" || true; } | tail -n 40
IGNORED="$(grep -oE 'errors ignored on restore: [0-9]+' "$RESTORE_LOG" | grep -oE '[0-9]+$' || echo 0)"
if [[ $rc -eq 0 && "$IGNORED" == 0 ]]; then echo "   pg_restore: no errors"
else echo "   pg_restore exit $rc, $IGNORED error(s) ignored: read them above (anything about tables, COPY or data matters)"; fi

step "analyze + counts"
sqlt "analyze" >/dev/null
for t in users sessions login_tokens auth_rate_events; do
  printf '   %-18s %s\n' "$t" "$(sqlt "select case when to_regclass('public.$t') is null then 'absent' else (select count(*)::text from public.$t) end" 2>/dev/null || echo '?')"
done
printf '   %-18s %s\n' "newest user" "$(sqlt "select coalesce(max(created_at)::text, '-') from public.users" 2>/dev/null || echo '?')"

if [[ "$SCRATCH" == 1 ]]; then
  if [[ "$KEEP" == 1 ]]; then
    echo "kept: ./deploy/compose.sh exec db psql -U postgres $TARGET   (drop database $TARGET; when done)"
  else
    sqla "drop database $TARGET with (force)" >/dev/null
    if [[ $rc -eq 0 && "$IGNORED" == 0 ]]; then echo "scratch database dropped: the dump restores cleanly"
    else echo "scratch database dropped: restored with errors, check them above"; fi
  fi
  exit 0
fi

if [[ "$APPLY" == 1 ]]; then
  step "deploy/db/apply.sh (roles, grants, qm_api password, pg_cron jobs)"
  tb backup /srv/deploy/db/apply.sh --verify
else
  echo "skipped apply.sh: run ./deploy/update.sh --target migrate before starting the api"
fi

if [[ "$API_STOPPED" == 1 && "$APPLY" == 1 ]]; then
  step "start api"
  "${COMPOSE[@]}" up -d --no-deps --wait api
fi
"${COMPOSE[@]}" ps --format 'table {{.Service}}\t{{.Status}}'
