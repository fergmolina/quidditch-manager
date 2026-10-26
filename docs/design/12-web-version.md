# 12. Web version

Plan for a browser version of the game, served from a Hetzner VPS, with the same codebase as the desktop builds.
Playing in the browser needs a free account; the desktop builds stay offline with no account.

Status (2026-10-24): steps 1-4 done (the game runs in the browser; saves export/import as files; the accounts
service in `server/` is written and tested, with the deploy runbook in `deploy/`). The Hetzner server exists but
nothing is deployed on it yet; the first rollout follows the first public release. Steps 5-9 are pending or in
progress (the custom web shell of step 5 is planned, not written, so the game uses Godot's default HTML shell and
`src/game/platform.gd`).

## Goals and constraints

- **One codebase.** The browser build is another Godot export preset of this same project, like Windows and macOS.
  Game logic (`src/sim`, `src/world`, `src/game`) is shared as is; a pull request changes it once and every platform
  gets it. Platform differences live in one small module (see [Platform layer](#platform-layer)).
- **Accounts on the web build only.** Playing in the browser needs a free account: a username and a country, plus an
  email address to sign in with. The account gives each player an identity for a future ranking; it is not copy
  protection (the export archives are public). macOS and Windows never talk to the server.
- **Still no saves on the server.** Players download their save as a file and upload it to continue. The browser
  may also keep a working copy locally (IndexedDB, which is Godot's `user://` on the web); that never leaves the
  player's machine. The server stores accounts and sessions, nothing from the game.
- **Public repository.** No secrets, server addresses, personal names or emails, or tokens in the repository, in CI
  or in the build output. Secrets live only in the server's `.env` and are documented by name (below).
- **Low cost.** Free tiers only: Godot, GitHub Actions and GHCR for public repos, Cloudflare Free, Tailscale personal,
  Resend free (100 emails/day), Google sign-in, Backblaze B2 (10 GB free). The only costs are a small dedicated
  Hetzner VPS and the game's own domain (owner's decision, 2026-10-19).
- **Every user-visible string in 10 languages**, including the account pages and the sign-in email.
- **Accept pull requests.** CI runs the tests on every PR; deploys are never triggered by a PR.

## Owner decisions (2026-10-21, final)

| Topic | Decision |
|---|---|
| Sign-in | Google OAuth and an email magic link sent through Resend. No passwords. The email is required, private and never shown. |
| Auth code | Lives in this public MIT repo; the security properties it guarantees are listed under [Security](#security). |
| Username | ASCII `^[A-Za-z][A-Za-z0-9_]{2,19}$`, unique ignoring case, a reserved list and a small blocklist. Changeable once every 30 days; the old name is released at once. The operator can force a rename (`must_rename`). |
| First and last name | Optional. Never public, never in `/api/me`. |
| Country | Required. ISO 3166-1 alpha-2 plus `XK`; names localized with `Intl.DisplayNames`. |
| Region and city | Optional, for a future map of players. Pick lists from GeoNames: region = admin1 code for the country, city = `cities5000` entry (geonameid, name, admin1, lat, lon); "Other / not listed" leaves the city empty. GeoNames data is CC BY 4.0 and is attributed. |
| Minimum age | 13. A required checkbox "I am at least 13 and accept the terms and privacy policy" stores `terms_version` and `terms_accepted_at`. |
| Legal pages | English is authoritative; the other nine languages are AI-assisted translations and each says English prevails. |
| Data controller | Named on `/privacy` and `/terms` from the server's environment (`LEGAL_CONTROLLER`, `LEGAL_CONTACT_EMAIL`), never committed. |

## Architecture

```
Internet ─ Cloudflare (DNS, TLS, cache, WAF) ─ Tunnel (outbound only) ─┐
Hetzner firewall: no inbound rules                                      │
┌─ VPS (fsn1, Germany) ─────────────────────────────────────────────────┴───┐
│ /srv/quidditch-manager  (Compose project "qm")                            │
│                                                                           │
│  cloudflared ──► caddy :8080 ─┬─ /play/          gated: forward_auth →    │
│                               │                  api /api/gate, then the  │
│                               │                  game's HTML entry page   │
│                               ├─ /play/r/<v>/*   versioned engine + data  │
│                               └─ everything else reverse_proxy → api:8080 │
│                                                                           │
│  api (Node 24, read-only rootfs, cap_drop ALL) ──► db (Postgres 16 +      │
│                                                    pg_cron, internal net) │
│  backup (profile ops; host cron: nightly pg_dump → Backblaze B2, EU)      │
│  SSH only over Tailscale                                                  │
└───────────────────────────────────────────────────────────────────────────┘
```

- **No ports are published to the internet.** Caddy listens on `127.0.0.1` on the host for health probes only;
  the api is reachable only from Caddy, and Caddy only from cloudflared. That is why the api can trust Cloudflare's
  `cf-connecting-ip` header and nothing else.
- **One api container.** The in-process burst limiter on `/api/*` assumes a single replica; every sign-in limit is
  stored in the database anyway.
- **The account pages are server-rendered HTML** (`/login`, `/register`, `/account`, `/privacy`, `/terms`). A player
  goes through them before the 90 MB engine starts loading, IME and password-manager autofill work natively, and
  they work without JavaScript. Godot only reads who is signed in from `/api/me`.
- **The gate is soft.** Only the HTML entry page of `/play/` is gated. The engine files and the release archives are
  public, so the gate gives players an identity; it does not protect the game. The strict rule (a valid, registered
  session) will apply to submitting stats, when there is a ranking.

### Accounts service (`server/`)

A small Node 24 + TypeScript service: [Hono](https://hono.dev), postgres.js, zod and jose; no framework, ORM or
template engine. `server/README.md` covers running it, the environment and the module layout. Godot never scans it
(`server/.gdignore`) and the export presets exclude it.

- `src/auth/`: tokens, sessions, magic links, Google, users, rate limits (security properties below).
- `src/profile/`, `src/pages/`, `src/routes/`: registration, account page, export and deletion, GeoNames pick lists,
  legal pages. Each area is a route module listed in `src/modules.ts`.
- `migrations/`: idempotent SQL files, applied in name order; migrate first, then deploy.
- `legal/`: `privacy.<lang>.md` and `terms.<lang>.md`, rendered by `src/pages/legal.ts`.
- `test/`: unit tests with a fake database, and integration tests against a real Postgres.

### First visit

1. The player opens `https://<domain>/play/`. Caddy asks `/api/gate`; with no session it answers
   `302 /login?next=/play/`.
2. The player signs in with Google, or asks for an email link (15 minutes, works once). The link opens a page with a
   button; pressing it signs in (no automatic submit, so mail scanners cannot use the link).
3. A new account has no profile yet, so the gate sends the player to `/register?next=/play/`: username, country,
   optional names, optional region and city, and the age/terms checkbox.
4. With a complete profile the gate answers 200 and Caddy serves the game. The game calls `/api/me`, which also
   renews the session. Return visits within 30 days go straight to the game.

The gate also sends a player to `/register` when the operator forced a rename or when `TERMS_VERSION` was bumped
(new terms to accept), and to `/login?error=blocked` for a blocked account.

## Routes

| Route | Method | What |
|---|---|---|
| `/` | GET | Landing page: what the game is, "Play in the browser", optional desktop downloads link. |
| `/login` | GET | "Continue with Google" and the email form; `?next=` (allowlisted) and `?error=` messages. |
| `/auth/magic` | POST | Asks for an email link. Answers "check your inbox"; 429 when limited, 502 when the email fails. |
| `/auth/magic/verify` | GET, POST | GET checks the link without using it and shows a button; POST uses it once and opens a session. |
| `/auth/google`, `/auth/google/callback` | GET | Google OAuth: code + PKCE + state + nonce; the id_token is verified against Google's keys. |
| `/auth/logout`, `/auth/logout-all` | POST | Sign out of this browser, or of every device. |
| `/register` | GET, POST | First profile, forced rename, or accepting new terms. |
| `/account` | GET | Profile, sessions, data export and deletion. |
| `/account/profile`, `/account/username`, `/account/sessions/revoke` | POST | Edit the profile, change the username (30-day cooldown), revoke one session. |
| `/account/export` | GET | Everything stored about the user, as JSON (GDPR access and portability). |
| `/account/delete` | GET, POST | Confirmation page; the POST deletes the user at once (cascade) and that email's sign-in links. |
| `/api/me` | GET | `{logged_in, username, country, locale, profile_complete, pending}` or 401. Never the email, names, region or city. Renews and rotates the session. `pending` is true for a complete profile that still waits for approval (`ACCESS_MODE=approval`); `profile_complete` is then false, so the game treats it like an unfinished profile. |
| `/pending` | GET | `ACCESS_MODE=approval` only: "your account is waiting for approval", with sign-out and a link to `/account`. Approved, or open access: 303 to `/play/`. |
| `/admin/users`, `/admin/users/<approve\|revoke\|block\|unblock>`, `/admin/feedback` | GET, POST | The operator's pages (`is_admin`, set by `deploy/db/make-admin.sh`; anyone else gets the ordinary 404). English only, hardcoded. The list of accounts (waiting or all) with approve/revoke/block/unblock buttons (block also ends the sessions; 60 writes per admin per 15 min), and the last 50 feedback rows. |
| `/ranking` | GET | The managers' ranking, overall or `?country=XX`; `?view=map` for the countries on the world map (public). |
| `/api/career/season` | POST | A finished season of a career (JSON, ≤ 4 KB, signed-in and complete profile; same-origin). `{ok, flagged}`, `{ok, duplicate}`, 400, 401, 409 or 429. |
| `/api/gate` | GET, HEAD | For Caddy `forward_auth`: 200, or 302 to `/login` / `/register` / `/pending`. Never sets cookies. |
| `/api/geo/regions`, `/api/geo/cities`, `/api/username-available` | GET | Helpers for the register form (it also works without them). |
| `/privacy`, `/terms` | GET | Legal pages in the page language; `?original=1` shows the English text. |
| `/feedback` | GET, POST | Bug reports and ideas, with or without an account (`?kind=bug\|idea` and `?context=` prefill the form). The POST stores the row, mails a copy to `FEEDBACK_TO` and answers 303 to `/feedback?sent=1`; 400 with the form on invalid input, 429 over 5 per address per hour or 60 in all per day. |
| `/healthz` | GET | `select 1`, for the Compose healthcheck. |
| `/static/*` | GET | CSS, OFL fonts, logo and icon. |

The page language comes from `?lang=` (which also sets the `qm_lang` cookie), then `qm_lang`, then
`Accept-Language`, then English.

## Security

**Cookies.** `__Host-qm_session` (HttpOnly, Secure, SameSite=Lax, Path=/), `__Host-qm_oauth` (10 minutes, signed,
only during Google sign-in) and `qm_lang` (language, not secret). All are strictly necessary, so there is no cookie
banner, as long as there is no analytics.

**Sessions.** Random 32-byte tokens; the database keeps only their SHA-256. 30 days sliding, never more than 180 days.
Renewal on `/api/me` rotates the token (the old one works for 2 more minutes, for parallel tabs). Each session keeps
`created_at`, `last_seen_at` and a coarse browser family such as "Firefox · Windows", so `/account` can list and
revoke them. Every login deletes the session the browser already had (session fixation).

**CSRF.** Every non-GET request must come from the site itself (Origin plus `Sec-Fetch-Site`), checked before any
route runs. The magic-link POST uses the stricter check. No CORS anywhere. Every page and API answer is
`private, no-store` with `Vary: Cookie`. Redirect targets (`next`) must be same-site paths under an allowlist.

**Rate limits.** Email links: 3 per address per 15 minutes, 6 per address per 24 hours, 10 per network per
15 minutes, and a global `MAIL_DAILY_CAP` that protects the Resend quota; a failed send does not count. Per-IP limits
use the IPv6 /64. The database never stores a raw IP. Sign-in links keep an HMAC of the /64 (or IPv4) bucket and are
deleted about a day after they expire. Cloudflare's free WAF rule goes on `POST /auth/*`.

**Security properties of the server.** Per-IP limits on the IPv6 /64; a tight per-address email cap that ignores
failed sends; an absolute session lifetime and rotation on renewal; a session inventory with revoke; a `__Host-`,
signed OAuth state cookie; a magic-link landing page that needs a click and never auto-submits; self-service account
deletion; no raw IPs kept; a strict CSP; the Google id_token signature is verified and a nonce is required.

**Content-Security-Policy.** Every page the api serves:

```
default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self';
connect-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'
```

plus HSTS, `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`
(`same-origin` on the magic-link page), COOP and CORP `same-origin` and a restrictive `Permissions-Policy`. No page
has an inline script or style.

`/play/` (set by Caddy) is a temporary compromise. Godot's default HTML shell starts the engine from an inline
script and `Platform.pick_file()` uses `JavaScriptBridge.eval`, so the **enforced** policy still allows
`'unsafe-inline'` and `'unsafe-eval'` on `/play/` only. The **target** policy is sent at the same time as
`Content-Security-Policy-Report-Only`:

```
default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self'; img-src 'self' data: blob:;
font-src 'self'; media-src 'self' blob:; connect-src 'self'; worker-src 'self' blob:; object-src 'none';
base-uri 'self'; form-action 'self'; frame-ancestors 'none'
```

Step 5 (custom shell with an external `shell.js`, `pick_file` without `eval`) makes the target policy enforceable.
No COOP/COEP isolation headers: the build is single-threaded.

## Data

Tables (`server/migrations/0001_accounts.sql`): `users`, `sessions`, `login_tokens` (email links) and
`auth_rate_events`; later migrations add `careers`, `career_seasons` and `feedback`. Every per-user table references
`users(id) on delete cascade` (feedback: `on delete set null`, see below), so deleting an account cannot forget a
table. The api connects as the least-privilege role `qm_api` (no DDL); pg_cron prunes expired sessions,
links and rate-limit rows every night.

| Kept | Notes |
|---|---|
| Email | Sign-in only; never shown. |
| Google account id | Only with Google sign-in. Only `sub`, `email` and `email_verified` are read from Google. |
| Username, last change | Public. |
| First and last name | Optional, never public. |
| Country; region and city | Country required; region and city optional (city name, GeoNames id and the city's coordinates). |
| Terms version and acceptance time | Bumping `TERMS_VERSION` asks everyone to accept again. |
| Created, last sign-in, moderation flags | `must_rename`, `blocked_at`, `is_admin` (SQL only, `deploy/db/make-admin.sh`). |
| Approval | `approved_at`, `approved_by` (`0006_approval.sql`). Null while a closed trial (`ACCESS_MODE=approval`) keeps the account on `/pending`; set by an admin on `/admin/users`, or at registration when access is open. Accounts older than the column were approved by the migration's one-shot backfill. |
| Sessions | No IP, no raw User-Agent. |

**Feedback** (`0005_feedback.sql`, table `feedback`): bug reports and ideas from `/feedback`, from anyone. One row
per submission: kind (`bug` or `idea`), the message (10-4000 characters), an optional reply address, an optional
context line (game version and platform, ≤ 200 characters, filled by the page or by the game through `?context=`),
the page language, the account id when the sender was signed in (`on delete set null`, so deleting the account unlinks
the feedback but does not delete what was reported), `created_at` and `mailed_at` (when the copy reached
`FEEDBACK_TO`; null when email is off or the send failed, and the row is kept either way). No network address is stored
with the row. The per-address limit is an `auth_rate_events` counter (keyed hash, one day). Rows are deleted after 12
months by `prune_auth()`, and a signed-in player's rows appear in their account export. A honeypot field catches
naive bots (nothing is stored); every POST passes the same-origin check like the rest of the site.

Not kept: saves, raw IP addresses, analytics. Backups: 7 daily + 4 weekly dumps (`BACKUP_KEEP_DAILY`,
`BACKUP_KEEP_WEEKLY`, defaults in `deploy/compose.yml`), so deleted data leaves the backups within 45 days. The
deletion page shows `BACKUP_RETENTION_DAYS` (default 45) and the privacy policy states the same number in prose.
Change the three together.

**Career reports and the ranking.** `GET /ranking` (public, linked from the header) lists one row per player:
their best never-flagged career by reputation (username, flag and country, last club and season, reputation, titles,
seasons), top 100, overall or `?country=XX`; the signed-in player's row is highlighted (`src/career/ranking.ts`,
`src/pages/ranking.ts`). `?view=map` shows the game's atlas maps (world plus the enlarged Europe inset, drawn by
`tools/make_map.py`, served as `static/map_*.jpg`, projected with the game's frames in `data/shared/map.json`) with a wax seal per country, sized by its number of ranked
managers and placed at the population-weighted centre of the country's GeoNames places (`countryCentroid`); a seal
links to that country's list, and a table below gives managers, the best one, best and average reputation. The map
is server-rendered SVG (no script, so the strict CSP stays). Every save carries a random
`career_id`. On the web, the game sends one summary per finished season (`GameSession.report_finished_season` →
`Platform.report_season` → `POST /api/career/season`): career id, season, in-game date, manager reputation, mode
(club or school), club id and name, career titles and seasons managed, game version. The country comes from the
account, so a country ranking needs nothing more. Migration `0004_careers.sql` adds `careers` (one row per career,
owned by the first account that reports it, with the latest values) and `career_seasons` (one row per season, primary
key `(career_id, season)`); both cascade from `users`, and both appear in the account data export.

Results are self-reported (the save lives in the player's browser and can be edited), so the server checks
plausibility, not proof (`src/career/report.ts`): reputation within the game's 200-5000; the date inside the season
after the one reported; seasons strictly increasing; at most +2,500 reputation and +6 titles per season since the
last report (a season can give about +2,100 at most: title, objective, every cup, a World Cup with a national team,
monthly awards); titles and seasons never decreasing; a first report bounded by what could have been earned since
1993. A malformed body is refused (400); a resend of the same season is accepted as a duplicate; the same season
with other numbers, an older season or another account's career is refused (409); 200 reports or 20 new careers
per account a day at most (429). A report that fails a plausibility check is stored with its reason and the career
is flagged for good, which keeps it out of any ranking. About 100 bytes per season: 1,000 players × 30 seasons is
well under 5 MB. The body's schema (`data/shared/season_report.schema.json`) and the numeric limits
(`data/shared/career_rules.json`) are the game's own files: the server builds its validator from them.

## Strings and legal pages

- Server strings are `web.*` keys in `locale/strings.csv`, with all 10 languages, added with the usual tools
  (`tools/add_keys.py`, `check_translation.py`, `merge_translations.py`). `server/scripts/gen-i18n.ts` extracts them
  to `server/generated/strings.json` and fails when a `web.*` key is empty in a language or its `{placeholders}`
  differ from English. The sign-in email goes out in the language of the page that asked for it.
- The privacy policy and terms are too long for the CSV: they live in `server/legal/<doc>.<lang>.md`. English is
  authoritative; each translation says so in its language, and a test checks that every translation has the same
  headings, list items, links and placeholders as the English file. Change the English file first.

## Build

- **Export preset `Web`** in `export_presets.cfg`: Godot 4.7.2, **single-threaded** (thread support off). Without
  threads the build needs no `SharedArrayBuffer`, so no COOP/COEP headers and it works in every browser, iOS Safari
  included. The engine and the season simulation are single-threaded; the only thread is `run_blocking()` in
  `src/ui/main.gd`, which creates/loads a game behind the loading overlay. On the web it runs the work directly
  instead (the overlay freezes for a few seconds, nothing else changes).
- **Who builds.** GitHub Actions, on a version tag (`v*`). The workflow installs Godot and the export templates,
  runs the tests, exports Web, Windows and macOS, and attaches the archives plus a `SHA256SUMS` file to a GitHub
  Release. Because the repository is public, the server downloads the release without any credential. The api image
  is built from `server/` in the same release.
- **Size.** The crest and portrait PNGs are imported as lossy WebP (`compress/mode=1`, quality 0.8; no visible
  difference at game size). The web `.pck` went from 115 MB to 47.5 MB, plus a 40 MB `.wasm` (about 9 MB gzipped).
  The desktop builds shrink the same way.
- **Caching.** The export's file names (`index.js`, `index.wasm`, `index.pck`) do not carry the version, so each
  release is served from its own path, `/play/r/<version>/`, cached for a year as immutable; `update.sh` writes a
  `<base href>` into the gated entry page so the loader fetches from there. The entry page itself is `no-store`.

## Platform layer

`src/game/platform.gd` is the only place that asks `OS.has_feature("web")`. Screens call it instead of branching
themselves:

| Feature | Desktop | Web |
|---|---|---|
| Save | `user://saves/<name>/` | same (IndexedDB) **and** "Download save" → `JavaScriptBridge.download_buffer()` of a single `.qmsave` file |
| Load | list of `user://saves` | same **and** "Upload save" → browser file picker (`<input type=file>` through `JavaScriptBridge`) |
| Background work | `run_blocking()` on a thread | same call, run on the main thread |
| Window / fullscreen | settings | browser fullscreen toggle |
| Account (step 5) | none: `Platform.viewer()` returns `{}` | the custom shell reads `/api/me` before starting the engine; Settings shows "Signed in as @username · Manage account · Sign out" |

**Save file format.** A `.qmsave` is a zip of today's `meta.json` + `world.json.gz` (~3.5 MB), built by
`SaveManager.export_file()` and read by `SaveManager.import_file()`. The buttons are "Export to file" / "Import file"
in the save dialogs and under Load game on the Title screen (an imported file loads at once); in the browser a note
under them says saves live only in that browser until exported. Desktop gets the same "Export / Import save"
buttons, so a save moves between the browser and the installed game. The loader checks the
schema version and refuses files that are not valid saves; nothing from the file is executed.

**Signing in from the game (step 5).** A custom HTML shell (`web_shell/qm_shell.html`, engine start moved to an
external `shell.js`) fetches `/api/me`: on 401 it goes to `/login?next=/play/`; on any other failure the game still
starts with an empty viewer, because an account problem must never stop a local game. It exposes a small `qm`
object (`viewerJson`, `lang`, `setLang`, `openAccount`, `logout`, `pickFile`) that `platform.gd` reads through
`JavaScriptBridge.get_interface("qm")`, null-checked so a build with the default shell behaves as today. Session
expiry during play changes nothing, because the game is local.

## Repository hygiene (public repo)

- `.env` and `.env.*` are git-ignored (as are `server/node_modules/` and `server/dist/`). `deploy/env.example` lists
  variable **names only**.
- No server IPs, Tailscale names, account ids, personal names or emails in the repository. Operators keep them in
  `~/.ssh/config` and in the server's `.env`.
- **GitHub Actions has no stored secrets.** The release is built from public code and published to the public
  release page; the api image goes to GHCR with the automatic `GITHUB_TOKEN`. Workflows use `pull_request` (never
  `pull_request_target`), `permissions: contents: read` by default (write only in the release job, on tags), and
  actions pinned to a commit SHA. Dependabot watches `server/package-lock.json` and the actions.
- GitHub settings: secret scanning and push protection on; private vulnerability reporting on (see `SECURITY.md`);
  branch protection on `main` (PR + passing CI + code owner review); "Require approval for all outside
  collaborators" for workflow runs from forks. `CODEOWNERS` covers `server/src/auth/`, `server/migrations/`,
  `deploy/` and `.github/`.

### Server secrets and settings (names only)

Values live only in `/srv/quidditch-manager/.env` (mode 600). **Bold** = secret.

| Variable | Notes |
|---|---|
| `SITE_URL`, `NODE_ENV` | `https://<domain>`; `production`. |
| **`POSTGRES_PASSWORD`**, `DB_API_USER`, **`DB_API_PASSWORD`** | Hex passwords (they go into a URL). Compose builds `DATABASE_URL` for the `qm_api` role. |
| `GOOGLE_CLIENT_ID`, **`GOOGLE_CLIENT_SECRET`** | Redirect URI `SITE_URL/auth/google/callback`. Both or neither. |
| **`RESEND_API_KEY`**, `MAIL_FROM`, `LOGIN_EMAIL`, `MAIL_DAILY_CAP` | Email links; the sender domain needs Resend's DKIM/SPF records. |
| **`AUTH_SECRET`** | At least 32 characters. Keys the OAuth cookie signature and the IP hashes. |
| `TERMS_VERSION` | Bump to make everyone accept changed terms. |
| `LEGAL_CONTROLLER`, `LEGAL_CONTACT_EMAIL` | Data controller and contact shown on `/privacy` and `/terms`. |
| `SESSION_RATE_PER_MINUTE`, `DOWNLOADS_URL` | Optional. |
| `TRUSTED_PROXY_HEADER` | Optional, default `cf-connecting-ip`: the header the api trusts for the visitor's IP. Change only with another edge in front. |
| `BACKUP_RETENTION_DAYS` | Optional, default 45: the deletion page's promise; must cover the backup service's `BACKUP_KEEP_*`. |
| `FEEDBACK_TO` | Optional. The address that receives a copy of each `/feedback` submission (needs email on). |
| `ACCESS_MODE` | `open` (default) or `approval`: a closed trial where each new account waits on `/pending` until an admin approves it. |
| **`CLOUDFLARE_TUNNEL_TOKEN`** | The tunnel. |
| `RELEASE_REPO`, `WEB_ASSET`, `API_IMAGE`, `KEEP_RELEASES` | What `update.sh` downloads (public: no credentials). |
| `QM_DATA_DIR`, `QM_UID`, `QM_GID`, `QM_HTTP_PORT`, `QM_INIT_SCHEMA` | Host layout; written by `bootstrap.sh`. |
| **`B2_KEY_ID`**, **`B2_APP_KEY`**, `B2_BUCKET`, **`BACKUP_CRYPT_PASSWORD`** | Offsite backups (key limited to the bucket, EU region). |
| **`TELEGRAM_BOT_TOKEN`**, `TELEGRAM_CHAT_ID` | Optional health and backup alerts (host scripts), and the api's alerts: one message per completed registration (username and country only) and per feedback submission (kind and username only). Both or neither. |

## Deploy

- `deploy/compose.yml`: cloudflared, caddy, api, db (Postgres 16 + pg_cron, `deploy/postgres/`) and the backup
  toolbox (profile `ops`). Every container drops all capabilities; all but the toolbox run read-only and as non-root.
- `deploy/bootstrap.sh`: one-off server setup, run as root (idempotent): deploy user with SSH key, key-only sshd,
  Docker CE + Compose, Tailscale, fail2ban, unattended upgrades, ufw (SSH only on `tailscale0`), the project
  directory and `.env` from `deploy/env.example`. The Hetzner firewall ends with no inbound rules.
- `deploy/update.sh [vX.Y.Z]`: downloads the release's web archive and `SHA256SUMS`, verifies the checksum, unpacks
  into `releases/<version>/`, points `current` at it, installs the api image and restarts api and Caddy. Rollback =
  `./deploy/update.sh <previous version>`. `./deploy/update.sh --target migrate` applies the migrations.
  **Migrate first, then deploy.** A deploy never migrates on its own.
- Backups: a host cron runs `pg_dump` nightly and copies it to a private Backblaze B2 bucket in the EU region;
  restore is tested every quarter on a scratch database.
- Cloudflare: cache rules bypass the cache for the account pages, `/auth/*`, `/api/*` and the `/play/` entry page,
  and cache `/play/r/*`; the free WAF rate-limit rule covers `POST /auth/*`.
- Run from the operator's machine: `ssh <host> 'cd /srv/quidditch-manager && ./deploy/update.sh v0.12.0'`.

## Steps

Steps 1-3 needed nothing but the game. Steps 6-8 need the repository on GitHub (first commit and push), because CI,
the release page and `update.sh` depend on it.

1. ~~Web export templates, `Web` preset, play in a browser.~~ Done: a new game, three days, the squad screen, and
   loading an uploaded save all work in Chrome (WebGL 2, single-threaded build).
2. ~~Lossy WebP import for crests and portraits.~~ Done (115 → 47.5 MB).
3. ~~`platform.gd`, `.qmsave` export/import, UI strings in 10 languages.~~ Done; covered by `test_world_human_season`
   (export, import twice without overwriting, load, garbage rejected) and checked in the browser (upload, then
   download an identical file).
4. Accounts service in `server/`: sign-in (email link and Google), sessions, the `/play/` gate, registration,
   account page with export and deletion, GeoNames pick lists, legal pages in 10 languages. Written, with unit and
   integration tests; strings to merge into `locale/strings.csv`.
5. Godot integration (web only): custom shell and `shell.js`, `Platform.viewer()` / `open_account()` / `logout()`,
   `pick_file` without `eval`, the Settings account row with a "save first" warning before signing out,
   `career_id` and `game_version` in saves. Then enforce the strict `/play/` CSP.
6. CI: `ci.yml` (Godot tests, plus a server job with a Postgres service: typecheck, unit and integration tests,
   image build) and `release.yml` (tag → exports + api image → GitHub Release and GHCR). Dependabot and CODEOWNERS.
7. `deploy/` (Compose file, Caddyfile, Postgres image, backup toolbox, `env.example`, `bootstrap.sh`, `update.sh`)
   and the runbook in `deploy/README.md`.
8. External setup and first deploy: Cloudflare tunnel, cache and WAF rules; Resend domain records; Google OAuth
   consent screen (External; scopes `openid email profile`; homepage, `/privacy` and `/terms` URLs); B2 bucket in the
   EU; fill `LEGAL_CONTROLLER` and `LEGAL_CONTACT_EMAIL`; migrate, then deploy; the manual browser checklist on
   desktop and mobile, iOS Safari included.
9. README: "Play in your browser" link; CONTRIBUTING: how PRs reach the web build (merge → tag → release → deploy).

## Open decisions

- Server: a new, dedicated Hetzner VPS (decided 2026-10-19).
- Domain: a new domain for the game (decided 2026-10-19; name to be chosen).
- Lossy WebP for the crests and portraits, also on desktop (decided 2026-10-19, after a before/after comparison).
- Inactive accounts: none are deleted in v1. Deleting accounts after 24 months without a sign-in (with an email
  notice first) can come later.
- UK nations (England, Scotland, Wales, Northern Ireland) as separate countries: not in v1; the column allows it.
- Desktop careers in the future ranking: whether an imported desktop save may submit stats.
- EU representative (GDPR Art. 27): the "occasional, low-risk" exemption probably covers a free fan game with
  minimal data; the owner should confirm. Not legal advice.

## Risks

- **Memory on phones.** The web build loads the whole `.pck` into memory; step 2 is what makes it fit. If mobile
  Safari still struggles, the page can say "best on desktop".
- **Browser storage can be wiped** (private mode, "clear site data", iOS after weeks without visits). The UI
  reminds players to download their save; that file is the real backup.
- **Audio** starts only after the first click (browser autoplay rules); the title screen needs a click anyway.
- **Email quota.** Resend's free tier sends 100 emails a day. `MAIL_DAILY_CAP` stops at 90 and the page suggests
  Google; 30-day sliding sessions keep sign-ins rare.
- **Machine-translated legal text.** Accepted by the owner, with English prevailing.
- **Personal data now lives on the server.** Hence the least-privilege database role, no raw IPs, a private EU
  backup bucket with a fixed retention (encrypted client-side once `BACKUP_CRYPT_PASSWORD` is set), self-service
  export and deletion, and `SECURITY.md`.
