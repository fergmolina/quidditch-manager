#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Nightly backup of the accounts database:
  1. pg_dump -Fc of schema public → /backups/daily/<PGDATABASE>_<UTC stamp>.dump, checked with pg_restore --list
  2. on Sundays a hard-linked copy in /backups/weekly/
  3. local retention: BACKUP_KEEP_DAILY daily + BACKUP_KEEP_WEEKLY weekly (set in deploy/compose.yml ONLY)
  4. rclone sync of /backups to Backblaze B2 (a mirror: the remote keeps the same files). Optional client-side
     encryption with BACKUP_CRYPT_PASSWORD (rclone crypt). Skipped with a notice when B2_* are unset.

The dumps hold personal data (emails, usernames, optional names and places): the directory is mode 700, files are
600, the B2 bucket is private and its key is limited to that bucket (deploy/README.md, "Backups").

  ./deploy/compose.sh run --rm -T backup                          # what the host crontab runs
  ./deploy/compose.sh run --rm -T backup backup.sh --list-remote  # list the offsite copies
  ./deploy/compose.sh run --rm -T backup backup.sh --fetch daily/qm_2026-11-02_0515.dump
                                                                  # copy one back into /backups/restored/

Env (deploy/compose.yml ← .env): PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE, BACKUP_KEEP_DAILY,
BACKUP_KEEP_WEEKLY, B2_KEY_ID, B2_APP_KEY, B2_BUCKET, B2_PATH, BACKUP_CRYPT_PASSWORD, TELEGRAM_BOT_TOKEN,
TELEGRAM_CHAT_ID (failure alert, optional).
EOF
}
umask 077

ROOT="${BACKUP_DIR:-/backups}"
MODE=backup; FETCH=""
case "${1:-}" in
  "") ;;
  --list-remote) MODE=list ;;
  --fetch) MODE=fetch; FETCH="${2:?--fetch needs a remote file name, e.g. daily/qm_2026-11-02_0515.dump}" ;;
  -h|--help) usage; exit 0 ;;
  *) echo "backup.sh: unknown option: $1" >&2; exit 2 ;;
esac

log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*"; }

# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/telegram.sh
. /srv/deploy/lib/telegram.sh
telegram() {
  telegram_configured || return 0
  telegram_send "$1" || true
}

REMOTE=""
if [[ -n "${B2_KEY_ID:-}" && -n "${B2_APP_KEY:-}" && -n "${B2_BUCKET:-}" ]]; then
  export RCLONE_CONFIG_B2_TYPE=b2 RCLONE_CONFIG_B2_ACCOUNT="$B2_KEY_ID" RCLONE_CONFIG_B2_KEY="$B2_APP_KEY"
  # Pruned dumps really leave the bucket (no hidden old versions).
  export RCLONE_CONFIG_B2_HARD_DELETE=true
  REMOTE="b2:${B2_BUCKET}/${B2_PATH:-qm}"
  if [[ -n "${BACKUP_CRYPT_PASSWORD:-}" ]]; then
    export RCLONE_CONFIG_B2C_TYPE=crypt RCLONE_CONFIG_B2C_REMOTE="$REMOTE"
    RCLONE_CONFIG_B2C_PASSWORD="$(printf '%s' "$BACKUP_CRYPT_PASSWORD" | rclone obscure -)"
    export RCLONE_CONFIG_B2C_PASSWORD
    REMOTE="b2c:"
  fi
fi

if [[ "$MODE" != backup ]]; then
  [[ -n "$REMOTE" ]] || { echo "B2_KEY_ID / B2_APP_KEY / B2_BUCKET are not set" >&2; exit 1; }
  if [[ "$MODE" == list ]]; then
    rclone lsl "$REMOTE"
  else
    [[ "$FETCH" =~ ^(daily|weekly)/[A-Za-z0-9_.-]+\.dump$ ]] || { echo "unexpected name: $FETCH" >&2; exit 2; }
    mkdir -p "$ROOT/restored"
    rclone copyto "$REMOTE/$FETCH" "$ROOT/restored/$(basename "$FETCH")"
    echo "fetched: backups/restored/$(basename "$FETCH")  →  deploy/backup/restore.sh <that path> --scratch"
  fi
  exit 0
fi

: "${PGDATABASE:?PGDATABASE is not set (run through the backup service)}"
: "${BACKUP_KEEP_DAILY:?BACKUP_KEEP_DAILY is not set (deploy/compose.yml)}"
: "${BACKUP_KEEP_WEEKLY:?BACKUP_KEEP_WEEKLY is not set (deploy/compose.yml)}"
[[ "$BACKUP_KEEP_DAILY" =~ ^[0-9]+$ && "$BACKUP_KEEP_WEEKLY" =~ ^[0-9]+$ ]] || { echo "BACKUP_KEEP_* must be integers" >&2; exit 2; }

fail() {
  log "FAILED: $*"
  telegram "Quidditch Manager backup FAILED: $*"
  exit 1
}
trap 'fail "line $LINENO"' ERR

STAMP="$(date -u +%Y-%m-%d_%H%M)"
DAILY="$ROOT/daily"; WEEKLY="$ROOT/weekly"
FILE="$DAILY/${PGDATABASE}_${STAMP}.dump"
mkdir -p "$DAILY" "$WEEKLY"
chmod 700 "$ROOT" "$DAILY" "$WEEKLY" 2>/dev/null || true

log "pg_dump $PGDATABASE (schema public) → $FILE"
pg_dump -Fc --no-owner --no-privileges --schema=public --compress=zstd:3 -f "$FILE.part" \
  || { log "zstd unavailable, falling back to gzip"; pg_dump -Fc --no-owner --no-privileges --schema=public --compress=6 -f "$FILE.part"; }
mv "$FILE.part" "$FILE"
pg_restore --list "$FILE" >/dev/null
log "ok, $(du -h "$FILE" | cut -f1)"
ln -sfn "$(basename "$FILE")" "$DAILY/latest.dump"

if [[ "$(date -u +%u)" == 7 ]]; then
  ln -f "$FILE" "$WEEKLY/$(basename "$FILE")"
  log "weekly copy kept"
fi

prune() {
  local n=0 f
  while IFS= read -r f; do
    n=$((n + 1))
    if (( n > $2 )); then rm -f -- "$f"; log "pruned $(basename "$f")"; fi
  done < <(find "$1" -maxdepth 1 -type f -name '*.dump' | sort -r)
}
prune "$DAILY" "$BACKUP_KEEP_DAILY"
prune "$WEEKLY" "$BACKUP_KEEP_WEEKLY"

if [[ -n "$REMOTE" ]]; then
  log "rclone sync → B2 (${B2_PATH:-qm}${BACKUP_CRYPT_PASSWORD:+, encrypted})"
  rclone sync "$ROOT" "$REMOTE" --filter '- latest.dump' --filter '+ /daily/*.dump' --filter '+ /weekly/*.dump' \
    --filter '- *' --transfers 2 -q
  log "offsite ok ($(rclone size "$REMOTE" --json | sed -E 's/.*"bytes":([0-9]+).*/\1/') bytes)"
else
  log "B2_KEY_ID / B2_APP_KEY / B2_BUCKET not set: offsite copy skipped"
fi

log "done: $(find "$DAILY" -name '*.dump' -type f | wc -l | tr -d ' ') daily, $(find "$WEEKLY" -name '*.dump' -type f | wc -l | tr -d ' ') weekly"
