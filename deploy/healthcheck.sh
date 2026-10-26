#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${QM_ENV_FILE:-$ROOT/.env}"
STATE_DIR="${STATE_DIR:-/var/tmp/quidditch-manager-health}"
DISK_ALERT_PCT="${DISK_ALERT_PCT:-80}"
mkdir -p "$STATE_DIR"

env_get() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"'"'"; }
PORT="$(env_get QM_HTTP_PORT)"; PORT="${PORT:-8080}"
TELEGRAM_BOT_TOKEN="$(env_get TELEGRAM_BOT_TOKEN)"
TELEGRAM_CHAT_ID="$(env_get TELEGRAM_CHAT_ID)"

# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/telegram.sh
. "$ROOT/deploy/lib/telegram.sh"

now="$(date -u +%FT%TZ)"
telegram() {
  telegram_configured || { echo "$now (no Telegram configured) $1"; return 0; }
  telegram_send "$1" || echo "$now telegram send failed"
}

disk_pct="$(df -P / 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"
if [[ "$disk_pct" =~ ^[0-9]+$ ]]; then
  if (( disk_pct >= DISK_ALERT_PCT )) && [[ ! -f "$STATE_DIR/disk_alerted" ]]; then
    telegram "Quidditch Manager: disk / at ${disk_pct}% ($now). docker system df; du -sh the data dir."
    touch "$STATE_DIR/disk_alerted"
  elif (( disk_pct < DISK_ALERT_PCT )) && [[ -f "$STATE_DIR/disk_alerted" ]]; then
    telegram "Quidditch Manager: disk / back to ${disk_pct}% ($now)"
    rm -f "$STATE_DIR/disk_alerted"
  fi
fi

health="$(curl -s -m 15 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/healthz" 2>/dev/null)"
play="$(curl -s -m 15 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/play/" 2>/dev/null)"
problems=""
[[ "$health" == 200 ]] || problems+="/healthz → ${health:-000}; "
[[ "$play" == 302 || "$play" == 303 ]] || problems+="/play/ → ${play:-000}; "

if [[ -z "$problems" ]]; then
  if [[ -f "$STATE_DIR/alerted" ]]; then
    echo "$now recovered"
    telegram "Quidditch Manager OK again ($now)"
    rm -f "$STATE_DIR/alerted"
  fi
  rm -f "$STATE_DIR/fails"
  exit 0
fi

n=$(( $(cat "$STATE_DIR/fails" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$STATE_DIR/fails"
echo "$now FAIL #$n $problems"
if (( n >= 2 )) && [[ ! -f "$STATE_DIR/alerted" ]]; then
  telegram "Quidditch Manager DOWN ($n checks in a row, $now): $problems
ssh in: ./deploy/compose.sh ps && ./deploy/compose.sh logs --tail 50 api caddy"
  touch "$STATE_DIR/alerted"
fi
exit 1
