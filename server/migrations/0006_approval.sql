-- Closed trial: an account must be approved by the operator before it can play (ACCESS_MODE=approval).
--
-- `approved_at` is null for an account still waiting; `approved_by` is the admin who approved it (null when the
-- approval came from the backfill below, from open access or when that admin's account is gone). With
-- ACCESS_MODE=open the api fills approved_at itself when a profile is completed, so flipping the switch later never
-- locks out people who signed up while access was open.
--
-- The backfill approves every account that exists when the column is created: the gate only applies to sign-ups
-- after the trial starts. It sits inside the `do` block on purpose: this file is re-applied on every deploy
-- (deploy/db/apply.sh, no ledger table), and a bare `update … where approved_at is null` would approve every
-- waiting account each time.

begin;
set local lock_timeout = '3s';

do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'users' and column_name = 'approved_at') then
    alter table public.users add column approved_at timestamptz;
    update public.users set approved_at = created_at;
  end if;
end
$$;

alter table public.users add column if not exists approved_by uuid references public.users (id) on delete set null;

comment on column public.users.approved_at is 'Null while the account waits for the operator (ACCESS_MODE=approval). Set from /admin/users, or at registration when access is open.';
comment on column public.users.approved_by is 'The admin who approved the account; null for the backfill, for open access, or once that admin is deleted.';

-- Waiting accounts are what the admin page lists; the rest of the table is small either way.
create index if not exists users_pending_idx on public.users (created_at) where approved_at is null;

-- 0003's grants on public.users cover the new columns (table-level privileges); nothing to add for qm_api.

commit;
