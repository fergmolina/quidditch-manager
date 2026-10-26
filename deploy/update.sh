#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Deploy a Quidditch Manager release on the VPS. Run as the deploy user from anywhere; one deploy at a time (flock).

  ./deploy/update.sh v0.12.0                      # release = api + web of that tag (the normal deploy)
  ./deploy/update.sh                              # same, for the latest GitHub Release
  ./deploy/update.sh --target migrate v0.12.0     # FIRST when a release adds migrations (deploy never migrates)
  ./deploy/update.sh --rollback                   # back to the previous api image and web release
  ./deploy/update.sh --target stack v0.12.0       # first rollout / maintenance: db, migrations, caddy, api,
                                                  # web, and cloudflared once CLOUDFLARE_TUNNEL_TOKEN is set

Targets:
  release (default)  api, then web, for VERSION (or the latest release)
  web                download <RELEASE_REPO> release asset WEB_ASSET + SHA256SUMS, verify the checksum, unpack
                     into QM_DATA_DIR/web/releases/<v>/, inject <base href="/play/r/<v>/">, precompress, then
                     switch the `current` symlink (the old one becomes `previous`) and smoke-test through Caddy.
                     A failed smoke test switches back. Old releases beyond KEEP_RELEASES are removed.
  api                pull API_IMAGE:<v> (or, when API_IMAGE is empty or with --build, build server/ of tag <v>),
                     tag it qm-api:current (the old one becomes qm-api:previous), recreate the api, wait for its
                     healthcheck; on failure the previous image comes back.
  migrate            deploy/db/apply.sh in the backup toolbox: the migrations of tag <v> when given, else those of
                     the checkout. Sets the qm_api password. Never runs as part of another target except stack.
  caddy              validate and hot-reload deploy/Caddyfile (after a git pull that changed it)
  edge               (re)start cloudflared (needs CLOUDFLARE_TUNNEL_TOKEN)
  stack              build db + backup images, start db, migrate, caddy, api + web (with VERSION), edge

Options:
  --rollback             release/web/api: swap back to `previous` (no download, no build)
  --no-pull              do not `git pull --ff-only` the checkout first
  --build                build the api image locally even when API_IMAGE is set
  --api-image REF        deploy this exact image reference (testing, emergencies)
  --archive FILE --sums FILE   install the web release from local files instead of downloading (still verified)
  --verify               migrate/stack: list tables, grants and cron jobs afterwards

Reads QM_DATA_DIR, QM_HTTP_PORT, RELEASE_REPO, WEB_ASSET, API_IMAGE, KEEP_RELEASES, CLOUDFLARE_TUNNEL_TOKEN (only
whether it is set) from .env (QM_ENV_FILE overrides the path). Never prints a secret.
EOF
}

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$DEPLOY_DIR")"
ENV_FILE="${QM_ENV_FILE:-$ROOT/.env}"
COMPOSE="$DEPLOY_DIR/compose.sh"
DEFAULT_WEB_ASSET='QuidditchManager-{version}-web.zip'

CLEANUP_PATHS=()
LOCK_DIR=""
# shellcheck disable=SC2329
cleanup() {
  local p
  for p in ${CLEANUP_PATHS[@]+"${CLEANUP_PATHS[@]}"}; do rm -rf -- "$p"; done
  [[ -n "$LOCK_DIR" ]] && rmdir "$LOCK_DIR" 2>/dev/null
  return 0
}
trap cleanup EXIT

step() { printf '\n== %s\n' "$*"; }
note() { printf '   %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
compose() { "$COMPOSE" "$@"; }

env_get() {
  local v
  v="$(grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
  v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
  printf '%s' "$v"
}

sha256_of() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# Atomically repoint a symlink (GNU mv -T on the VPS; BSD mv -h when testing on a Mac).
swap_link() {
  local tmp="$1.new.$$"
  ln -s "$2" "$tmp"
  if mv --help 2>&1 | grep -q -- '--no-target-directory'; then mv -Tf "$tmp" "$1"; else mv -hf "$tmp" "$1"; fi
}

http_code() {
  local m=()
  [[ "${2:-}" == HEAD ]] && m=(-I)
  curl -s ${m[@]+"${m[@]}"} -o /dev/null -m 15 -w '%{http_code}' "$1" || true
}

web_install() {
  local v="$1" dest="$RELEASES/$1" tmp asset archive expected actual src html tag
  if [[ -f "$dest/.complete" ]]; then note "web $v already unpacked"; return 0; fi
  [[ -e "$dest" ]] && rm -rf -- "$dest"
  tmp="$(mktemp -d "$RELEASES/.incoming.XXXXXX")"
  CLEANUP_PATHS+=("$tmp")

  if [[ -n "$ARCHIVE" ]]; then
    [[ -n "$SUMS" ]] || fail "--archive needs --sums (the SHA256SUMS that lists it)"
    asset="$(basename "$ARCHIVE")"
    cp -- "$ARCHIVE" "$tmp/$asset"; cp -- "$SUMS" "$tmp/SHA256SUMS"
  else
    [[ -n "$RELEASE_REPO" ]] || fail "RELEASE_REPO is not set in $ENV_FILE"
    asset="${WEB_ASSET//\{version\}/$v}"
    local base="https://github.com/$RELEASE_REPO/releases/download/$v"
    note "download $asset + SHA256SUMS from github.com/$RELEASE_REPO ($v)"
    curl -fsSL --retry 3 --retry-delay 2 -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" || fail "no SHA256SUMS in release $v"
    curl -fsSL --retry 3 --retry-delay 2 -o "$tmp/$asset" "$base/$asset" || fail "no $asset in release $v"
  fi
  [[ "$asset" =~ ^[A-Za-z0-9._+-]+$ ]] || fail "unexpected asset name: $asset"

  # The checksum must be listed for this exact file name ("<sha256>  <name>" or "<sha256> *<name>").
  expected="$(awk -v f="$asset" '$2 == f || $2 == "*" f { print $1; exit }' "$tmp/SHA256SUMS")"
  [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || fail "SHA256SUMS has no entry for $asset"
  actual="$(sha256_of "$tmp/$asset")"
  [[ "$(tr 'A-F' 'a-f' <<<"$expected")" == "$actual" ]] || fail "checksum mismatch for $asset"
  note "sha256 ok ($actual)"

  archive="$tmp/$asset"; mkdir "$tmp/x"
  case "$asset" in
    *.zip)           unzip -q "$archive" -d "$tmp/x" ;;
    *.tar.gz|*.tgz)  tar -xzf "$archive" -C "$tmp/x" --no-same-owner --no-same-permissions ;;
    *) fail "unsupported archive type: $asset" ;;
  esac
  if [[ -n "$(find "$tmp/x" ! -type f ! -type d -print -quit)" ]]; then fail "the archive contains links or special files"; fi

  src="$tmp/x"
  if [[ ! -f "$src/index.html" ]]; then
    local dirs=("$src"/*/)
    if (( ${#dirs[@]} == 1 )) && [[ -f "${dirs[0]}index.html" ]]; then src="${dirs[0]%/}"; fi
  fi
  for f in index.html index.js index.wasm index.pck; do
    [[ -f "$src/$f" ]] || fail "the archive has no $f (expected a Godot web export)"
  done

  html="$src/index.html"
  if grep -qi '<base[ >]' "$html"; then
    warn "index.html already has a <base> element: left as is (it must point at /play/r/$v/)"
  else
    tag="<base href=\"/play/r/$v/\">"
    awk -v tag="$tag" '
      !done && match(tolower($0), /<head[^>]*>/) {
        print substr($0, 1, RSTART + RLENGTH - 1); print "\t\t" tag
        rest = substr($0, RSTART + RLENGTH); if (rest != "") print rest
        done = 1; next
      }
      { print }
      END { if (!done) exit 3 }' "$html" > "$html.new" || fail "index.html has no <head>"
    mv -f "$html.new" "$html"
    note "injected $tag"
  fi

  local f
  while IFS= read -r f; do
    gzip -9 -n -k -f "$f"
    if command -v brotli >/dev/null; then brotli -q 9 -k -f "$f"; fi
  done < <(find "$src" -type f \( -name '*.wasm' -o -name '*.js' -o -name '*.pck' -o -name '*.html' \))
  command -v brotli >/dev/null || note "brotli not installed: gzip copies only"

  find "$src" -type d -exec chmod 755 {} +
  find "$src" -type f -exec chmod 644 {} +
  touch "$src/.complete"
  mv -- "$src" "$dest"
  rm -rf -- "$tmp"
  note "unpacked into $dest"
}

web_smoke() {
  local v="$1" base="http://127.0.0.1:$HTTP_PORT" code
  code="$(http_code "$base/play/r/$v/index.wasm" HEAD)"
  [[ "$code" == 200 ]] || { warn "/play/r/$v/index.wasm answered $code"; return 1; }
  code="$(http_code "$base/play/")"
  case "$code" in
    302|303) note "gate ok: /play/ without a session → $code" ;;
    502|503|504) warn "/play/ answered $code: is the api up? (./deploy/compose.sh logs --tail 50 api)" ;;
    *) warn "/play/ answered $code without a session (expected a redirect to /login)"; return 1 ;;
  esac
}

web_deploy() {
  local v="$1" cur
  step "web $v"
  web_install "$v"
  cur="$(readlink "$WEB_DIR/current" 2>/dev/null || true)"
  if [[ "$cur" == "releases/$v" ]]; then
    note "already current"
  else
    swap_link "$WEB_DIR/current" "releases/$v"
    [[ -n "$cur" ]] && swap_link "$WEB_DIR/previous" "$cur"
    note "current → releases/$v${cur:+ (previous → $cur)}"
  fi
  if ! web_smoke "$v"; then
    if [[ -n "$cur" && "$cur" != "releases/$v" ]]; then
      swap_link "$WEB_DIR/current" "$cur"
      fail "web smoke test failed: switched back to $cur"
    fi
    fail "web smoke test failed"
  fi
  printf '%s\n' "$v" > "$STATE_DIR/web.current"
  web_prune
}

# Unpacked releases, newest first by mtime. The .incoming.* directories of a running install are dotfiles, so the
# glob leaves them out. `ls -t` is the one mtime sort GNU and BSD share (release names are plain version tags).
# shellcheck disable=SC2012
web_releases_by_age() { ls -1dt "$RELEASES"/*/ 2>/dev/null | sed 's:/$::; s:.*/::' || true; }

# KEEP_RELEASES counts the releases besides current and previous (env.example).
web_keep_set() {
  local keep="${KEEP_RELEASES:-3}" cur prev n=0 name
  [[ "$keep" =~ ^[0-9]+$ ]] || keep=3
  cur="$(readlink "$WEB_DIR/current" 2>/dev/null || true)"; prev="$(readlink "$WEB_DIR/previous" 2>/dev/null || true)"
  while IFS= read -r name; do
    if [[ "releases/$name" == "$cur" || "releases/$name" == "$prev" ]]; then printf '%s\n' "$name"
    elif (( n < keep )); then printf '%s\n' "$name"; n=$((n + 1))
    fi
  done < <(web_releases_by_age)
}

web_prune() {
  local keep name
  keep="$(web_keep_set)"
  while IFS= read -r name; do
    grep -qxF -- "$name" <<<"$keep" && continue
    rm -rf -- "${RELEASES:?}/$name"; note "removed old release $name"
  done < <(web_releases_by_age)
}

web_rollback() {
  local cur prev
  step "web rollback"
  prev="$(readlink "$WEB_DIR/previous" 2>/dev/null || true)"; cur="$(readlink "$WEB_DIR/current" 2>/dev/null || true)"
  [[ -n "$prev" && -f "$WEB_DIR/$prev/.complete" ]] || fail "no previous web release to roll back to"
  swap_link "$WEB_DIR/current" "$prev"
  [[ -n "$cur" ]] && swap_link "$WEB_DIR/previous" "$cur"
  note "current → $prev"
  web_smoke "$(basename "$prev")" || warn "smoke test failed after the rollback"
  basename "$prev" > "$STATE_DIR/web.current"
}

image_id() { docker image inspect -f '{{.Id}}' "$1" 2>/dev/null || true; }

# Builds the api image of tag $1 as $2. The Dockerfile's context is the repository root (it reads locale/strings.csv
# and data/shared/).
api_build() {
  local v="$1" tag="$2" tmp
  if ! command -v git >/dev/null || ! git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    fail "building needs the git checkout"
  fi
  git -C "$ROOT" fetch --tags --quiet 2>/dev/null || warn "git fetch --tags failed: using the tags already here"
  git -C "$ROOT" rev-parse --verify --quiet "$v^{commit}" >/dev/null || fail "no git tag/commit $v"
  tmp="$(mktemp -d)"
  CLEANUP_PATHS+=("$tmp")
  git -C "$ROOT" archive "$v" server locale/strings.csv data/shared | tar -x -C "$tmp"
  docker build --pull -t "$tag" -f "$tmp/server/Dockerfile" "$tmp"
  rm -rf -- "$tmp"
}

# Image ids behind qm-api:current and qm-api:previous, one per line (empty when the tag does not exist), for
# api_tags_restore after a failed deploy.
api_tags_snapshot() { printf '%s\n' "$(image_id qm-api:current)" "$(image_id qm-api:previous)"; }

api_tags_restore() {
  local cur="$1" prev="$2"
  docker tag "$cur" qm-api:current
  if [[ -n "$prev" ]]; then docker tag "$prev" qm-api:previous; else docker rmi qm-api:previous >/dev/null; fi
}

api_deploy() {
  local v="$1" ref new cur old_prev
  step "api $v"
  if [[ -n "$API_REF" ]]; then
    ref="$API_REF"
    [[ -n "$(image_id "$ref")" ]] || docker pull "$ref"
  elif [[ -n "$API_IMAGE" && "$BUILD" == 0 ]]; then
    ref="$API_IMAGE:$v"
    docker pull "$ref"
  else
    note "building server/ of $v on this host (API_IMAGE empty or --build)"
    ref="qm-api:$v"; api_build "$v" "$ref"
  fi
  new="$(image_id "$ref")"; [[ -n "$new" ]] || fail "image $ref not available"
  { read -r cur; read -r old_prev; } < <(api_tags_snapshot)
  if [[ "$new" == "$cur" ]]; then
    note "qm-api:current is already $ref"
    compose up -d --no-deps --wait --wait-timeout 120 api
    return 0
  fi
  [[ -n "$cur" ]] && docker tag qm-api:current qm-api:previous
  docker tag "$ref" qm-api:current
  if compose up -d --no-deps --wait --wait-timeout 120 api; then
    note "api healthy on $ref"
    printf '%s %s\n' "$ref" "$new" > "$STATE_DIR/api.current"
  else
    if [[ -n "$cur" ]]; then
      api_tags_restore "$cur" "$old_prev"
      compose up -d --no-deps --wait --wait-timeout 120 api || true
      fail "the new api did not become healthy: rolled back to the previous image (logs: ./deploy/compose.sh logs api)"
    fi
    fail "the api did not become healthy (./deploy/compose.sh logs api)"
  fi
  local code; code="$(http_code "http://127.0.0.1:$HTTP_PORT/healthz")"
  [[ "$code" == 200 ]] || warn "/healthz through Caddy answered $code (is caddy up?)"
}

api_rollback() {
  step "api rollback"
  [[ -n "$(image_id qm-api:previous)" ]] || fail "no qm-api:previous image to roll back to"
  docker tag qm-api:current qm-api:rollback-swap
  docker tag qm-api:previous qm-api:current
  docker tag qm-api:rollback-swap qm-api:previous
  docker rmi qm-api:rollback-swap >/dev/null
  compose up -d --no-deps --wait --wait-timeout 120 api
  note "api back on the previous image"
}

db_running() { [[ -n "$(compose ps -q --status running db 2>/dev/null)" ]]; }

migrate() {
  local v="${1:-}" dir args=()
  step "migrations${v:+ of $v}"
  db_running || fail "db is not running (first rollout: --target stack)"
  [[ -n "$(image_id qm-backup:local)" ]] || compose build backup
  [[ -n "$VERIFY" ]] && args+=("$VERIFY")
  if [[ -n "$v" ]] && command -v git >/dev/null && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$ROOT" fetch --tags --quiet 2>/dev/null || true
    git -C "$ROOT" rev-parse --verify --quiet "$v^{commit}" >/dev/null || fail "no git tag/commit $v"
    dir="$STATE_DIR/migrations-$v"
    rm -rf -- "$dir"; mkdir -p "$dir"
    git -C "$ROOT" archive "$v" server/migrations | tar -x -C "$dir" --strip-components=2
    compose run --rm --no-deps -T -v "$dir:/srv/migrations-ref:ro" -e MIGRATIONS_DIR=/srv/migrations-ref \
      backup /srv/deploy/db/apply.sh ${args[@]+"${args[@]}"}
  else
    [[ -n "$v" ]] && warn "no git checkout: applying the migrations of the files on disk, not of $v"
    compose run --rm --no-deps -T backup /srv/deploy/db/apply.sh ${args[@]+"${args[@]}"}
  fi
}

caddy_reload() {
  step "caddy"
  compose up -d --no-deps --wait caddy
  compose exec -T caddy caddy validate --config /etc/qm-deploy/Caddyfile --adapter caddyfile
  compose exec -T caddy caddy reload --config /etc/qm-deploy/Caddyfile --adapter caddyfile
  note "Caddyfile reloaded"
}

edge_up() {
  step "edge (cloudflared)"
  if [[ -z "$(env_get CLOUDFLARE_TUNNEL_TOKEN)" ]]; then
    note "CLOUDFLARE_TUNNEL_TOKEN is empty: cloudflared not started (the site is reachable only on the host)"
    return 0
  fi
  compose --profile edge up -d --no-deps cloudflared
}

latest_version() {
  [[ -n "$RELEASE_REPO" ]] || fail "no VERSION given and RELEASE_REPO is not set"
  curl -fsSL -m 20 -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$RELEASE_REPO/releases/latest" \
    | sed -nE 's/^[[:space:]]*"tag_name":[[:space:]]*"([^"]+)".*/\1/p' | head -1
}

main() {
  TARGET=release; VERSION=""; PULL=1; ROLLBACK=0; BUILD=0; API_REF=""; ARCHIVE=""; SUMS=""; VERIFY=""
  while (( $# )); do
    case "$1" in
      --target) TARGET="${2:?--target needs release|web|api|migrate|caddy|edge|stack}"; shift ;;
      --rollback) ROLLBACK=1 ;;
      --no-pull) PULL=0 ;;
      --build) BUILD=1 ;;
      --api-image) API_REF="${2:?--api-image needs an image reference}"; shift ;;
      --archive) ARCHIVE="${2:?}"; shift ;;
      --sums) SUMS="${2:?}"; shift ;;
      --verify) VERIFY=--verify ;;
      -h|--help) usage; exit 0 ;;
      -*) fail "unknown option: $1 (--help)" ;;
      *) [[ -z "$VERSION" ]] || fail "two versions given: $VERSION and $1"; VERSION="$1" ;;
    esac
    shift
  done
  case "$TARGET" in release|web|api|migrate|caddy|edge|stack) ;; *) fail "unknown target: $TARGET" ;; esac
  if [[ "$ROLLBACK" == 1 ]]; then
    case "$TARGET" in release|web|api) ;; *) fail "--rollback works with --target release, web or api" ;; esac
    [[ -z "$VERSION" ]] || fail "--rollback takes no version (to go to a specific one: ./deploy/update.sh <version>)"
  fi
  if [[ -n "$VERSION" ]]; then
    [[ "$VERSION" =~ ^v?[0-9]+(\.[0-9]+){1,3}([-.][0-9A-Za-z]+)*$ ]] || fail "not a release version: $VERSION"
    [[ "$VERSION" == v* ]] || VERSION="v$VERSION"
  fi
  [[ -f "$ENV_FILE" ]] || fail "$ENV_FILE missing (copy deploy/env.example; see deploy/README.md)"
  if [[ "$(uname -s)" == Linux ]] && [[ "$(stat -c '%a' "$ENV_FILE")" != 600 ]]; then
    warn "$ENV_FILE should be mode 600 (chmod 600 $ENV_FILE)"
  fi
  command -v docker >/dev/null || fail "docker is not installed"
  command -v curl >/dev/null || fail "curl is not installed"

  DATA_DIR="$(env_get QM_DATA_DIR)"; DATA_DIR="${DATA_DIR:-/srv/quidditch-manager-data}"
  WEB_DIR="$DATA_DIR/web"; RELEASES="$WEB_DIR/releases"; STATE_DIR="$DATA_DIR/state"
  HTTP_PORT="$(env_get QM_HTTP_PORT)"; HTTP_PORT="${HTTP_PORT:-8080}"
  RELEASE_REPO="$(env_get RELEASE_REPO)"
  WEB_ASSET="$(env_get WEB_ASSET)"; WEB_ASSET="${WEB_ASSET:-$DEFAULT_WEB_ASSET}"
  API_IMAGE="$(env_get API_IMAGE)"
  KEEP_RELEASES="$(env_get KEEP_RELEASES)"
  mkdir -p "$RELEASES" "$STATE_DIR" "$DATA_DIR/backups"

  if command -v flock >/dev/null; then
    exec 9>"$STATE_DIR/.deploy.lock"
    flock -n 9 || fail "another deploy is running"
  else
    mkdir "$STATE_DIR/.deploy.lockdir" 2>/dev/null || fail "another deploy is running (or remove $STATE_DIR/.deploy.lockdir)"
    LOCK_DIR="$STATE_DIR/.deploy.lockdir"
  fi

  if [[ "$PULL" == 1 ]] && command -v git >/dev/null && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    step "git pull"
    git -C "$ROOT" pull --ff-only
  fi

  local needs_version=0
  case "$TARGET" in release|web|api) [[ "$ROLLBACK" == 0 ]] && needs_version=1 ;; esac
  if [[ "$needs_version" == 1 && -z "$VERSION" ]]; then
    VERSION="$(latest_version)"; [[ -n "$VERSION" ]] || fail "could not find the latest release of $RELEASE_REPO"
    note "latest release: $VERSION"
  fi
  local commit; commit="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '-')"
  echo "target=$TARGET version=${VERSION:-'-'} rollback=$ROLLBACK checkout=$commit"

  case "$TARGET" in
    release)
      if [[ "$ROLLBACK" == 1 ]]; then api_rollback; web_rollback
      else api_deploy "$VERSION"; web_deploy "$VERSION"; fi ;;
    web)
      if [[ "$ROLLBACK" == 1 ]]; then web_rollback; else web_deploy "$VERSION"; fi ;;
    api)
      if [[ "$ROLLBACK" == 1 ]]; then api_rollback; else api_deploy "$VERSION"; fi ;;
    migrate) migrate "$VERSION" ;;
    caddy) caddy_reload ;;
    edge) edge_up ;;
    stack)
      step "images: db, backup"
      compose build --pull db backup
      step "db"
      compose up -d --no-deps --wait --wait-timeout 180 db
      migrate "$VERSION"
      caddy_reload
      if [[ -n "$VERSION" ]]; then
        api_deploy "$VERSION"; web_deploy "$VERSION"
      elif [[ -n "$(image_id qm-api:current)" ]]; then
        compose up -d --no-deps --wait --wait-timeout 120 api
      else
        warn "no api image yet and no VERSION given: run ./deploy/update.sh <version>"
      fi
      edge_up ;;
  esac

  printf '%s target=%s version=%s rollback=%s checkout=%s\n' "$(date -u +%FT%TZ)" "$TARGET" "${VERSION:--}" "$ROLLBACK" "$commit" \
    >> "$STATE_DIR/deploy.log"
  step "status"
  compose ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}'
}

# Everything runs from main(): bash has read the whole function before `git pull` can rewrite this file.
main "$@"
exit $?
