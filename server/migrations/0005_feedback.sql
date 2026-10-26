-- Player feedback from the website's /feedback form: bug reports and ideas, from anyone (signed in or not).
--
-- Every submission is stored first; the notification mail (FEEDBACK_TO) is a copy, and `mailed_at` says whether it
-- went out, so nothing is lost when the mailer is down or off. The reply address is optional and is used only to
-- answer. No network address is stored with the message: the per-IP limit lives in auth_rate_events (keyed hashes,
-- pruned after a day). `user_id` is a plain reference with `on delete set null`, so deleting the account unlinks
-- its feedback instead of deleting what was already reported. The privacy policy promises 12 months of retention,
-- enforced by prune_auth() below.

begin;
set local lock_timeout = '3s';

create table if not exists public.feedback (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references public.users (id) on delete set null,
  kind         text not null,                                 -- 'bug' or 'idea'
  message      text not null,
  reply_email  text,                                          -- optional, only to answer
  context      text,                                         -- e.g. game version and platform, filled by the page or the game
  lang         text not null,                                 -- the page language, to answer in it
  created_at   timestamptz not null default now(),
  mailed_at    timestamptz,                                   -- when the copy reached FEEDBACK_TO; null = not sent
  constraint feedback_kind      check (kind in ('bug', 'idea')),
  constraint feedback_msg_len   check (char_length(message) between 10 and 4000),
  constraint feedback_email_len check (reply_email is null or char_length(reply_email) between 3 and 254),
  constraint feedback_ctx_len   check (context is null or char_length(context) between 1 and 200),
  constraint feedback_lang_len  check (char_length(lang) between 2 and 10)
);

create index if not exists feedback_created_idx on public.feedback (created_at);
create index if not exists feedback_user_idx on public.feedback (user_id) where user_id is not null;

-- Explicit, besides 0003's default privileges (which also hand out delete; taken back here). No delete for the api:
-- it only writes rows and marks them mailed, and pruning runs as postgres through prune_auth().
grant select, insert, update on public.feedback to qm_api;
revoke delete on public.feedback from qm_api;

-- Replaces the body from 0002_prune.sql: the same four steps, plus feedback older than 12 months (privacy policy
-- §"How long we keep it"). Files are applied in name order, so this definition is the one that stays.
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

  delete from feedback where created_at < now() - interval '12 months';
  get diagnostics n = row_count; what := 'feedback'; deleted := n; return next;
end
$$;
revoke execute on function public.prune_auth() from public;

commit;
