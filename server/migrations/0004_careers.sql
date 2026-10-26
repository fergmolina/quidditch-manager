-- Manager careers for a future ranking (global and by country). The game reports one row per finished season of a
-- career (`POST /api/career/season`): reputation, club and titles. Saved games themselves never reach the server.
--
-- A career is the game's `career_id` (16 hex characters, random per new game). It belongs to the first account that
-- reports it. Rows that fail the plausibility checks are kept but flagged, and a flagged career is left out of any
-- ranking (src/career/report.ts). Both tables cascade from users, so deleting an account deletes its careers.

begin;
set local lock_timeout = '3s';

create table if not exists public.careers (
  career_id        text primary key,
  user_id          uuid not null references public.users (id) on delete cascade,
  mode             text not null default 'club',              -- 'club' or 'school' (a Hogwarts house)
  first_season     integer not null,
  last_season      integer not null,
  last_reputation  integer not null,
  last_titles      integer not null default 0,
  last_seasons     integer not null default 0,
  flagged_at       timestamptz,                               -- set by the first implausible report
  flag_reason      text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint careers_id_fmt    check (career_id ~ '^[0-9a-f]{16}$'),
  constraint careers_mode      check (mode in ('club', 'school')),
  constraint careers_seasons   check (first_season between 1993 and 2300 and last_season between first_season and 2300),
  constraint careers_rep       check (last_reputation between 0 and 100000),
  constraint careers_flag_pair check ((flagged_at is null) = (flag_reason is null))
);

create index if not exists careers_user_idx on public.careers (user_id);
-- The ranking reads unflagged careers by reputation.
create index if not exists careers_rank_idx on public.careers (last_reputation desc) where flagged_at is null;

create table if not exists public.career_seasons (
  career_id    text not null references public.careers (career_id) on delete cascade,
  user_id      uuid not null references public.users (id) on delete cascade,
  season       integer not null,                              -- the season that ended (1993 = 1993-94)
  reported_on  date not null,                                 -- in-game date of the report
  reputation   integer not null,
  club_id      text,
  club_name    text,
  titles       integer not null default 0,                    -- career titles so far
  seasons      integer not null default 0,                    -- seasons managed so far
  game_version text,
  flagged      boolean not null default false,
  flag_reason  text,
  received_at  timestamptz not null default now(),
  primary key (career_id, season),
  constraint career_seasons_season   check (season between 1993 and 2300),
  constraint career_seasons_club_len check (club_id is null or char_length(club_id) between 1 and 80),
  constraint career_seasons_name_len check (club_name is null or char_length(club_name) between 1 and 120),
  constraint career_seasons_ver_len  check (game_version is null or char_length(game_version) between 1 and 40)
);

create index if not exists career_seasons_user_idx on public.career_seasons (user_id, received_at desc);

-- Explicit, besides 0003's default privileges (which only cover tables created by postgres after it ran).
grant select, insert, update, delete on public.careers, public.career_seasons to qm_api;

commit;
