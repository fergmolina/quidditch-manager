#!/usr/bin/env bash
set -euo pipefail
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$DEPLOY_DIR")"
ENV_FILE="${QM_ENV_FILE:-$ROOT/.env}"
[[ -f "$ENV_FILE" ]] || { echo "compose.sh: $ENV_FILE missing (copy deploy/env.example, see deploy/README.md)" >&2; exit 1; }
exec docker compose --project-name qm --file "$DEPLOY_DIR/compose.yml" --env-file "$ENV_FILE" "$@"
