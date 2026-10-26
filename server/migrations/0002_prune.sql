-- Housekeeping: delete expired sessions, old login tokens and old rate-limit events every night (pg_cron).
-- Works without pg_cron (local dev with the plain postgres image): the function is created, the schedule is skipped
-- with a notice, and `select * from public.prune_auth()` can be run by hand.

begin;
set local lock_timeout = '3s';

create or replace function public.prune_auth()
returns table (what text, deleted bigint)
language plpgsql volatile security invoker set search_path = public
as $$
declare
  n bigint;
begin
  delete from sessions where expires_at < now() or absolute_expires_at < now();
  get diagnostics n = row_count; what := 'sessions'; deleted := n; return next;

  update sessions set prev_id = null, prev_valid_until = null
   where prev_id is not null and prev_valid_until < now();
  get diagnostics n = row_count; what := 'sessions_prev'; deleted := n; return next;

  -- Kept one day past expiry: the per-email 24 h cap and the global daily mail cap count these rows.
  delete from login_tokens where expires_at < now() - interval '1 day';
  get diagnostics n = row_count; what := 'login_tokens'; deleted := n; return next;

  delete from auth_rate_events where created_at < now() - interval '1 day';
  get diagnostics n = row_count; what := 'auth_rate_events'; deleted := n; return next;
end
$$;
revoke execute on function public.prune_auth() from public;

do $cron$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron')
     and current_setting('shared_preload_libraries', true) like '%pg_cron%' then
    create extension if not exists pg_cron;
  end if;
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname in ('qm_prune_auth', 'qm_prune_cron_log');
    perform cron.schedule('qm_prune_cron_log', '45 4 * * *',
      $q$delete from cron.job_run_details where coalesce(end_time, start_time) < now() - interval '30 days'$q$);
    perform cron.schedule('qm_prune_auth', '50 4 * * *', $q$select public.prune_auth()$q$);
  else
    raise notice 'pg_cron not installed: qm_prune_auth not scheduled';
  end if;
end
$cron$;

commit;
