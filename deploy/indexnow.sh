#!/usr/bin/env bash
# Tells the IndexNow engines (Bing, Yandex, Seznam, Naver) about every URL in the live sitemap. Needs SITE_URL and
# INDEXNOW_KEY in .env and the api serving https://<SITE_URL>/<key>.txt (it does once INDEXNOW_KEY is set).
# Usage: ./deploy/indexnow.sh      (on the server, after a deploy that changes public pages)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${QM_ENV_FILE:-$ROOT/.env}"
env_get() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"'"'"; }
SITE_URL="$(env_get SITE_URL)"; SITE_URL="${SITE_URL%/}"
KEY="$(env_get INDEXNOW_KEY)"
[[ -n "$SITE_URL" && -n "$KEY" ]] || { echo "SITE_URL and INDEXNOW_KEY must be set in $ENV_FILE" >&2; exit 1; }
[[ "$(curl -fsS "$SITE_URL/$KEY.txt")" == "$KEY" ]] || { echo "$SITE_URL/$KEY.txt does not serve the key yet" >&2; exit 1; }
urls="$(curl -fsS "$SITE_URL/sitemap.xml" | grep -o '<loc>[^<]*</loc>' | sed -e 's#<loc>##' -e 's#</loc>##' -e 's#&amp;#\&#g')"
[[ -n "$urls" ]] || { echo "the sitemap lists no URLs" >&2; exit 1; }
host="${SITE_URL#https://}"
body="$(printf '%s\n' "$urls" | jq -R . | jq -s --arg host "$host" --arg key "$KEY" --arg loc "$SITE_URL/$KEY.txt" \
  '{host: $host, key: $key, keyLocation: $loc, urlList: .}')"
code="$(curl -sS -o /dev/null -w '%{http_code}' -X POST https://api.indexnow.org/indexnow \
  -H 'Content-Type: application/json; charset=utf-8' --data "$body")"
echo "IndexNow: $(printf '%s\n' "$urls" | wc -l | tr -d ' ') URLs → HTTP $code (200/202 = accepted)"
[[ "$code" == 200 || "$code" == 202 ]]
