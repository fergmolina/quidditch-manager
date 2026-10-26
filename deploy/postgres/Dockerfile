# =====================================================================================================================
# Quidditch Manager database: Postgres 16 + pg_cron.
#
# - postgresql.conf = the image's sample + `include_dir conf.d`; our settings live in qm.conf (baked into the image:
#   rebuild with `./deploy/update.sh --target stack` and restart `db` to apply a change).
# - The migrations are NOT baked in: compose mounts ../server/migrations at /opt/qm/migrations (read-only), and
#   init/10-schema.sh applies them on a FRESH volume only. Ongoing migrations: deploy/db/apply.sh.
# Build context: deploy/postgres (compose `build: ./postgres`).
# =====================================================================================================================
FROM postgres:16.15-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-16-cron \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/postgresql/conf.d /opt/qm/migrations \
 && cp /usr/share/postgresql/postgresql.conf.sample /etc/postgresql/postgresql.conf \
 && printf "\n# --- Quidditch Manager: every file in conf.d overrides the defaults above ---\ninclude_dir = '/etc/postgresql/conf.d'\n" >> /etc/postgresql/postgresql.conf \
 && chown -R postgres:postgres /etc/postgresql
COPY --chown=postgres:postgres qm.conf /etc/postgresql/conf.d/qm.conf
COPY --chmod=0755 init/ /docker-entrypoint-initdb.d/

# cron.database_name is a postmaster setting, so it is passed on the command line, derived from POSTGRES_DB (set once,
# in deploy/compose.yml) instead of being repeated in qm.conf. The official entrypoint runs its first-boot init only
# when its first argument is `postgres`, hence the re-exec through the shell that expands the variable. The temporary
# init server gets these same flags, so the init script runs with pg_cron preloaded and 0002_prune.sql can create the
# extension and schedule the jobs.
CMD ["sh", "-c", "exec docker-entrypoint.sh postgres -c config_file=/etc/postgresql/postgresql.conf -c cron.database_name=\"${POSTGRES_DB:-${POSTGRES_USER:-postgres}}\""]
