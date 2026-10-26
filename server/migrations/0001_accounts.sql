-- Accounts for the browser build: users, sessions, magic-link tokens, rate-limit events.
--
-- Rules for every migration in this folder:
--   * idempotent and additive: `create ... if not exists`, `add column if not exists`, guarded `do` blocks;
--   * no ledger table: deploy/db/apply.sh re-applies every file in name order, and a fresh volume runs them from
--     /docker-entrypoint-initdb.d;
--   * migrate first, then deploy (the deploy never migrates on its own);
--   * every per-user table references users(id) ON DELETE CASCADE, so deleting a user can never forget a table
--     (no hand-written list of tables to clean up).
--
-- Personal data kept here: email (login only, never shown), username, optional first/last name, country, optional
-- region and city (for the players' map), terms acceptance. Sessions keep no IP and no raw User-Agent; login tokens
-- keep a keyed hash of the IP /64 bucket and are pruned about one day after they expire.

begin;
set local lock_timeout = '3s';

create table if not exists public.users (
  id                  uuid primary key default gen_random_uuid(),
  email               text not null,
  email_verified      boolean not null default true,      -- every login method proves the address
  google_sub          text,                                -- Google account id, when linked
  username            text,                                -- display case; null until /register
  first_name          text,                                -- optional, never public
  last_name           text,                                -- optional, never public
  country_code        text,                                -- ISO 3166-1 alpha-2 (+ XK); required by /register
  region_code         text,                                -- optional: GeoNames admin1 code within country_code
  city_geonameid      integer,                             -- optional: GeoNames cities5000 id
  city_name           text,
  city_lat            double precision,
  city_lon            double precision,
  terms_version       text,
  terms_accepted_at   timestamptz,
  username_changed_at timestamptz,
  must_rename         boolean not null default false,      -- set by the operator (moderation)
  is_admin            boolean not null default false,      -- SQL only; no admin UI
  blocked_at          timestamptz,
  created_at          timestamptz not null default now(),
  last_login_at       timestamptz,
  constraint users_email_lower   check (email = lower(email) and char_length(email) between 3 and 254),
  constraint users_google_sub_fmt check (google_sub is null or char_length(google_sub) between 1 and 255),
  constraint users_username_fmt  check (username is null or username ~ '^[A-Za-z][A-Za-z0-9_]{2,19}$'),
  constraint users_first_len     check (first_name is null or char_length(first_name) between 1 and 50),
  constraint users_last_len      check (last_name  is null or char_length(last_name)  between 1 and 50),
  constraint users_country_fmt   check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  constraint users_region_fmt    check (region_code is null
                                        or (country_code is not null and region_code ~ '^[A-Za-z0-9]{1,20}$')),
  constraint users_city_all      check ((city_geonameid is null and city_name is null and city_lat is null and city_lon is null)
                                        or (city_geonameid is not null and city_name is not null
                                            and city_lat is not null and city_lon is not null)),
  constraint users_city_ok       check (city_geonameid is null
                                        or (city_geonameid > 0 and country_code is not null
                                            and char_length(city_name) between 1 and 200
                                            and city_lat between -90 and 90 and city_lon between -180 and 180)),
  constraint users_terms_pair    check ((terms_version is null) = (terms_accepted_at is null))
);

-- Columns added after the first release go here as `alter table ... add column if not exists`.

create unique index if not exists users_email_key      on public.users (email);
create unique index if not exists users_username_key   on public.users (lower(username));
create unique index if not exists users_google_sub_key on public.users (google_sub) where google_sub is not null;
create index if not exists users_country_idx           on public.users (country_code) where country_code is not null;

comment on column public.users.email is 'Login identifier only. Never shown in the game, the ranking or the logs.';
comment on column public.users.is_admin is 'Set only by SQL, never from the app.';
comment on column public.users.must_rename is 'Set by the operator; the user must pick a new username before playing.';

create table if not exists public.sessions (
  id                  text primary key,                    -- sha256 hex of the cookie token
  public_id           uuid not null default gen_random_uuid(), -- shown on /account to revoke one session
  user_id             uuid not null references public.users(id) on delete cascade,
  created_at          timestamptz not null default now(),
  last_seen_at        timestamptz not null default now(),
  expires_at          timestamptz not null,                -- sliding (30 days)
  absolute_expires_at timestamptz not null,                -- hard cap (180 days), never extended
  rotated_at          timestamptz,
  prev_id             text,                                -- hash of the token replaced by the last rotation
  prev_valid_until    timestamptz,                         -- the replaced token works until then (parallel tabs)
  user_agent_family   text,                                -- coarse "Browser · OS", never the raw User-Agent
  constraint sessions_id_fmt      check (id ~ '^[0-9a-f]{64}$'),
  constraint sessions_prev_fmt    check (prev_id is null or prev_id ~ '^[0-9a-f]{64}$'),
  constraint sessions_expiry_cap  check (expires_at <= absolute_expires_at),
  constraint sessions_ua_len      check (user_agent_family is null or char_length(user_agent_family) <= 64)
);
create unique index if not exists sessions_public_id_key on public.sessions (public_id);
create index if not exists sessions_user_idx    on public.sessions (user_id);
create index if not exists sessions_expires_idx on public.sessions (expires_at);
create index if not exists sessions_prev_idx    on public.sessions (prev_id) where prev_id is not null;

create table if not exists public.login_tokens (          -- magic links
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  token_hash  text not null unique,                       -- sha256 hex
  next_path   text,
  lang        text not null default 'en',                 -- language of the page that asked: the email uses it
  ip_hash     text,                                       -- keyed HMAC of the IP /64 bucket, never the raw IP
  expires_at  timestamptz not null,
  consumed_at timestamptz,
  created_at  timestamptz not null default now(),
  constraint login_tokens_lang_ok check (lang in ('es','en','de','fr','it','pt_BR','nl','ru','ja','zh_CN')),
  constraint login_tokens_next_len check (next_path is null or char_length(next_path) <= 512)
);
create index if not exists login_tokens_email_created_idx on public.login_tokens (email, created_at desc);
create index if not exists login_tokens_ip_created_idx    on public.login_tokens (ip_hash, created_at desc);
create index if not exists login_tokens_created_idx       on public.login_tokens (created_at);  -- global mail cap

-- Generic database-backed rate limits (several routes; survives restarts; correct with several replicas).
create table if not exists public.auth_rate_events (
  id         bigint generated always as identity primary key,
  bucket     text not null,                               -- e.g. 'magic_verify', 'register'
  subject    text not null,                               -- a keyed hash (IP bucket) or 'user:<uuid>'
  created_at timestamptz not null default now(),
  constraint auth_rate_events_bucket_len check (char_length(bucket) between 1 and 40),
  constraint auth_rate_events_subject_len check (char_length(subject) between 1 and 80)
);
create index if not exists auth_rate_events_lookup_idx on public.auth_rate_events (bucket, subject, created_at desc);
create index if not exists auth_rate_events_created_idx on public.auth_rate_events (created_at);

-- Room for the ranking (design §8.2), not built in v1: a later migration adds public.career_seasons with
-- user_id uuid not null references public.users(id) on delete cascade, primary key (user_id, career_id, season).

commit;
