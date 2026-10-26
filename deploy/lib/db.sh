# shellcheck shell=bash
# Sourced by deploy/db/apply.sh (backup toolbox) and deploy/postgres/init/10-schema.sh (db container); compose mounts
# this directory at /srv/deploy/lib in both.

# server/scripts/migrate.ts applies the same pattern; server/test/migrate.test.ts checks that the two strings match.
MIGRATION_FILE_PATTERN='^[0-9]{4}_[a-z0-9_]+\.sql$'

# The migration files of a directory, one per line in name order.
migration_files() {
  local f
  for f in "$1"/*.sql; do
    [[ -f "$f" && "$(basename "$f")" =~ $MIGRATION_FILE_PATTERN ]] && printf '%s\n' "$f"
  done
  return 0
}

# Sets the qm_api password from DB_API_PASSWORD. The value travels through \getenv, never in an argv, and
# log_min_error_statement is raised for the one transaction so a failing ALTER cannot print the statement (with the
# password) to the log. Arguments are passed on to psql (connection flags; apply.sh passes none, the PG* variables
# carry its connection).
# shellcheck disable=SC2120
set_qm_api_password() {
  psql -X -v ON_ERROR_STOP=1 -q "$@" <<'SQL'
\getenv qm_api_pw DB_API_PASSWORD
begin;
set local log_min_error_statement = 'panic';
alter role qm_api password :'qm_api_pw';
commit;
SQL
}
