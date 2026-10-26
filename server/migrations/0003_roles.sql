-- Least-privilege login role for the API (design §8.1). Migrations run as `postgres`; the API connects as `qm_api`.
--
-- The role is created WITHOUT a password. The deploy sets it from the environment (DB_API_PASSWORD), e.g.
--   psql -v pw="$DB_API_PASSWORD" -c "alter role qm_api password :'pw'"
-- Until then the API keeps connecting as `postgres` (DATABASE_URL).
--
-- qm_api gets row access to the app tables only: no DDL, no EXECUTE on prune_auth(), a statement timeout, and no
-- superuser/replication/RLS bypass.

do $roles$
begin
  if not exists (select 1 from pg_roles where rolname = 'qm_api') then
    create role qm_api login nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
  alter role qm_api nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  alter role qm_api set statement_timeout = '10s';
  alter role qm_api set idle_in_transaction_session_timeout = '60s';
  execute format('grant connect on database %I to qm_api', current_database());
end
$roles$;

revoke create on schema public from public;
grant usage on schema public to qm_api;

grant select, insert, update, delete on public.users, public.sessions, public.login_tokens to qm_api;
grant select, insert, delete on public.auth_rate_events to qm_api;
grant usage, select on all sequences in schema public to qm_api;

-- Tables created later by `postgres` (ranking, …) get row access by default; functions do not.
alter default privileges for role postgres in schema public grant select, insert, update, delete on tables to qm_api;
alter default privileges for role postgres in schema public grant usage, select on sequences to qm_api;
alter default privileges for role postgres in schema public revoke execute on routines from public;
