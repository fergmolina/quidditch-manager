#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Make an account an administrator (users.is_admin = true), which opens /admin/users and /admin/feedback to it.
The account must exist already: sign in once on the site first.

  ./deploy/db/make-admin.sh <email>        # on the host, from the checkout (/srv/quidditch-manager)

Runs psql inside the db container as postgres (like the SQL recipes in deploy/README.md §11). The address travels
through an environment variable and psql's \getenv, never as a psql argument: an argv shows up in `ps` and in the
audit log. Prints how many rows changed (1 = done, 0 = no account with that email); the address itself is not
echoed. To take the role away again: update users set is_admin = false where lower(email) = lower('<email>');
EOF
}

case "${1:-}" in
  -h|--help|"") usage; exit 2 ;;
esac
(( $# == 1 )) || { usage; exit 2; }

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC2016  # $POSTGRES_DB expands inside the container, not here
changed="$("$DEPLOY_DIR/compose.sh" exec -T -e QM_ADMIN_EMAIL="$1" db \
  sh -c 'exec psql -X -q -A -t -v ON_ERROR_STOP=1 -U postgres "$POSTGRES_DB"' <<'SQL'
\getenv admin_email QM_ADMIN_EMAIL
begin;
set local log_min_error_statement = 'panic';
with changed as (
  update public.users set is_admin = true
   where lower(email) = lower(:'admin_email') and not is_admin
  returning id
)
select count(*) from changed;
commit;
SQL
)"

echo "make-admin: ${changed:-0} account(s) changed"
case "$changed" in
  1) echo "make-admin: done; sign in and open /admin/users" ;;
  0) echo "make-admin: no account with that email that was not already an admin" >&2; exit 1 ;;
esac
