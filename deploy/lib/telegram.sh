# shellcheck shell=bash
# Sourced by deploy/healthcheck.sh (host) and deploy/backup/backup.sh (toolbox, where compose mounts this directory at
# /srv/deploy/lib). Reads TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID from the shell.

telegram_configured() { [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; }

# curl with the URL fed through its stdin config file. An argv shows in `ps` and in the audit log, and a Telegram URL
# carries the bot token.
curl_with_url_on_stdin() {
  local url="$1"; shift
  curl --config - "$@" <<< "url = \"$url\""
}

telegram_send() {
  curl_with_url_on_stdin "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -sS -m 15 -o /dev/null -X POST -d chat_id="${TELEGRAM_CHAT_ID}" --data-urlencode text="$1"
}
