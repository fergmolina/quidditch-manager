# Quidditch Manager accounts service (`server/`)

A small Node service for the **browser build** only. It handles login (Google, or an email magic link, with no passwords), sessions, the profile gate in front of `/play/`, the ranking and the feedback form. The desktop builds never use it. Design: `docs/design/12-web-version.md` and the web accounts design.

Stack: Node 24, TypeScript, [Hono](https://hono.dev), postgres.js, zod and jose. Tests use `node:test` through `tsx`. Godot ignores this folder (`.gdignore`).

## Run it locally

```sh
docker compose -f deploy/compose.dev.yml up -d db   # Postgres 16 on 127.0.0.1:5432, migrations applied on first boot
cd server
npm ci
npm run gen:i18n          # locale/strings.csv → generated/strings.json (web.* keys)
npm run dev               # http://localhost:8080 (reads server/.env.local if present)
```

- **No `RESEND_API_KEY`.** The magic link and the whole email are printed to the console. Open the link and press the button.
- **No `GOOGLE_CLIENT_ID`.** The Google button is hidden. To try Google, create a Web OAuth client with the redirect URI `http://localhost:8080/auth/google/callback`.
- **To run the game behind the gate.** Set `DEV_PLAY_DIR=../export/web`. `/play/` is then served by this server with the same gate Caddy applies in production. This is refused in production.
- **To try the game without logging in.** Add `DEV_PLAY_OPEN=1` (with `DEV_PLAY_DIR`). `/play/` then skips the gate. Development only; refused in production.
- Migrations by hand: `npm run migrate` applies `migrations/*.sql` in name order. Every file is idempotent, and there is no ledger table. **Migrate first, then deploy.** The deploy never migrates on its own.
- Port 5432 already in use: `QM_DEV_DB_PORT=55433 docker compose -f deploy/compose.dev.yml up -d db`, then set `DATABASE_URL=postgres://postgres:postgres@127.0.0.1:55433/qm`.

`.env.local` example (development only, never committed):

```
SITE_URL=http://localhost:8080
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/qm
```

## Tests

```sh
npm run typecheck
npm test                                   # unit tests, fake Db, no network
docker run --rm -d --name qm-test-pg -p 127.0.0.1:55432:5432 -e POSTGRES_PASSWORD=test postgres:16
TEST_DATABASE_URL=postgres://postgres:test@127.0.0.1:55432/postgres npm run test:integration
docker rm -f qm-test-pg
```

- The integration tests create a throwaway database, apply the migrations three times, run the full magic-link and Google flows, the gate, session rotation and pruning, and then drop the database.
- Without `TEST_DATABASE_URL` they are skipped.

## Strings (10 languages)

- Every user-visible string is a `web.*` key in `locale/strings.csv`, with all 10 languages filled in.
- `npm run gen:i18n` fails if a `web.*` key is empty in any language, or if its `{placeholders}` differ from the English ones.
- Keys not yet merged into the CSV can be tried with `npm run gen:i18n -- --extra pending.json` (format `{"key": [es, en, de, fr, it, pt_BR, nl, ru, ja, zh_CN]}`).
- At runtime a missing key falls back to English, then to the key name.

## Profile and location data

- `src/profile/` holds the profile rules:
  - `username.ts`: ASCII format, reserved names, a small blocklist and the 30-day cooldown;
  - `names.ts`: optional names (NFC, 1-50 code points, no invisible characters);
  - `countries.ts`: the 249 ISO 3166-1 codes plus XK, named with `Intl.DisplayNames`;
  - `geo.ts`: region and city lookups;
  - `profile.ts`: guarded UPDATEs, with `23505` on `users_username_key` reported as `username_taken`.
- `data/geo/` holds the committed GeoNames picklists (CC BY 4.0; see `data/geo/README.md`). `npm run build:geo` rebuilds them.
- When a city is chosen, its own admin1 code is stored as `region_code`, so the region always matches the city.

## Docker image

```sh
docker build -f server/Dockerfile -t qm-api .     # from the repository root
```

- The build context is the repository root, because the image generates `generated/strings.json` itself from `locale/strings.csv`, which sits next to `server/`, and copies `data/shared/career_rules.json` and `data/shared/season_report.schema.json`, which `src/career/report.ts` shares with the game, and `data/shared/map.json`, the map frames `src/pages/ranking.ts` shares with it. `server/Dockerfile.dockerignore` keeps the context down to the files the Dockerfile copies.
- Build with BuildKit, the default builder since Docker 23: the classic builder ignores `server/Dockerfile.dockerignore` and sends the whole repository as the context.
- The image runs as the unprivileged `node` user and writes no files. Run it with `read_only: true`, a tmpfs on `/tmp`, `cap_drop: [ALL]` and `no-new-privileges`.

## Environment

Names only. The values live in the server's `.env` (see `deploy/env.example`). Production refuses to start when a required value is missing.

| Variable | Required | Notes |
|---|---|---|
| `NODE_ENV` | | `production` on the server. This switches on `__Host-` cookies, Secure, HSTS and the strict checks. |
| `SITE_URL` | prod | `https://<domain>`. The only origin accepted on POSTs; also used for the magic links and the Google redirect URI. |
| `DATABASE_URL` | prod | `postgres://…`. In production, the `qm_api` role. |
| `DB_POOL_MAX` | | Default 5. |
| `HOST`, `PORT` | | Default `0.0.0.0:8080`. |
| `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | one login method | Both or neither. The secret is secret. |
| `RESEND_API_KEY` | prod, unless `LOGIN_EMAIL=off` | Secret. |
| `MAIL_FROM` | prod with email login | For example `Quidditch Manager <login@<domain>>`. |
| `LOGIN_EMAIL` | | `on` (default) or `off`. |
| `MAIL_DAILY_CAP` | | Default 90 magic-link emails per rolling 24 h; 0 means no cap. |
| `AUTH_SECRET` | recommended | Secret, at least 32 characters. Keys the HMACs of the OAuth state cookie and of the IP buckets. Without it, a random key is generated per process. |
| `TERMS_VERSION` | | Default `2026-11-01`. Bumping it sends every user back to accept the terms again. |
| `LEGAL_CONTROLLER`, `LEGAL_CONTACT_EMAIL` | recommended | Data controller and contact address shown on `/privacy` and `/terms`. Until both are set the pages show a bracketed placeholder, and production logs a warning. |
| `SESSION_RATE_PER_MINUTE` | | Default 60 requests per minute on `/api/*`. |
| `TRUSTED_PROXY_HEADER` | | Default `cf-connecting-ip`. The request header the api reads the visitor's IP from (rate limits, IP hashes). Change it only with another edge in front. The server refuses to start with a value that is not a header name. |
| `BACKUP_RETENTION_DAYS` | | Default 45, at least 1. The number of days the account deletion page promises deleted data can still sit in a backup. Must cover the backup service's `BACKUP_KEEP_*` and match the privacy policy's prose. |
| `DOWNLOADS_URL` | | Optional https link to the desktop downloads. |
| `FEEDBACK_TO` | | Optional. Address that receives a copy of each `/feedback` submission; rows are stored regardless. Needs email on (Resend). |
| `ACCESS_MODE` | | `open` (default) or `approval`. With `approval` a completed profile still waits (`/pending`, gate 302, `/api/me` `pending: true`) until an admin approves it on `/admin/users`. Accounts that exist when migration `0006` runs, and every registration made while access is open, are approved on the spot. |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | | Optional, both or neither. The token is secret. A Telegram message per completed registration (username and country only) and per feedback submission (kind and username only). Off, with one log line, when unset. |
| `INDEXNOW_KEY` | | Optional, 8–128 letters, digits or dashes (`openssl rand -hex 16`). Public by design: served at `/<key>.txt` so the IndexNow engines accept `deploy/indexnow.sh` submissions. |
| `DEV_PLAY_DIR` | dev only | Serves a Godot web export at `/play/`. |

## Routes

| Route | Method | What |
|---|---|---|
| `/` | GET | Landing page (features, captures, saves). "Play in the browser" leads to `/play/`, `/register?next=/play/` or `/login?next=/play/`. |
| `/faq` | GET | Frequently asked questions, with FAQPage JSON-LD. |
| `/robots.txt`, `/sitemap.xml` | GET | For crawlers (`src/http/seo.ts`): the sitemap lists every indexable page (`INDEXABLE_PATHS`) in all 10 languages with hreflang alternates. `public, max-age=3600`. |
| `/<INDEXNOW_KEY>.txt` | GET | The IndexNow key, when configured; any other root `.txt` is a 404. |
| `/login` | GET | Google button, email form and `?error=` messages. Shows a notice when already signed in. |
| `/auth/magic` | POST (form) | Requests a link. Always answers "check your inbox"; answers 429 when limited and 502 when the email fails. |
| `/auth/magic/verify?token=` | GET | Read-only check of the link. Shows a page with a button and no auto-submit. |
| `/auth/magic/verify` | POST (form) | Uses the link once (tier-2 origin check), opens a session, then 303 to `next` or to `/register?next=…`. |
| `/auth/google` | GET | Signed `__Host-qm_oauth` state cookie with PKCE and nonce, then 302 to Google. |
| `/auth/google/callback` | GET | Exchanges the code, verifies the id_token against Google's JWKS, links accounts by verified email. |
| `/auth/logout`, `/auth/logout-all` | POST | 303 to `/`. |
| `/api/me` | GET | `{logged_in, username, country, locale, profile_complete, pending}`, with 401 when logged out. Renews and rotates the session. `private, no-store`. |
| `/api/gate` | GET/HEAD | For Caddy `forward_auth` on `/play/`: 200 when the profile is complete (and approved, with `ACCESS_MODE=approval`), otherwise 302 to `/login?next=`, `/register?next=` or `/pending`. A forwarded non-GET method gets 401. |
| `/pending` | GET | `ACCESS_MODE=approval`: the waiting room of a complete but unapproved account (sign-out button, link to `/account`). Approved or open access: 303 to `/play/`. |
| `/admin/users?view=pending\|all` | GET | Admins only (`is_admin`; anyone else gets the ordinary 404). Accounts with username, country, email, created, state, and per-row forms. |
| `/admin/users/approve\|revoke\|block\|unblock` | POST (form `id`, `view`) | The moderation writes; Block also ends the user's sessions. An admin cannot block or revoke their own account. 60 per admin per 15 min (`admin_write`). 303 back to the list. |
| `/admin/feedback` | GET | Admins only. The last 50 feedback rows (kind, when, language, context, message, reply address). |
| `/privacy`, `/terms` | GET | Privacy policy and terms of use from `legal/<doc>.<lang>.md` (English authoritative; missing translations fall back to English). `?original=1` shows the English text. |
| `/register` | GET/POST | Profile step after the first login: username, optional first and last name, country (required), optional region and city, and the age (13+) and terms checkbox. The same page handles a forced rename (`must_rename`) and re-accepting a new `TERMS_VERSION`. Works without JS; `static/register.js` adds the region reload, city search and username check. |
| `/account` | GET | Profile, email (owner only), username change (once every 30 days), sessions with revoke, data export, account deletion, sign-out. |
| `/account/profile`, `/account/username`, `/account/sessions/revoke` | POST (form) | Edit names and location, change the username, revoke one session. Limited to 30 writes per user per 15 min. |
| `/account/export` | GET | Every column of the user row, sessions and sign-in links (token hashes left out), as a JSON download. |
| `/account/delete` | GET/POST | Confirmation (type the username), then hard delete (cascade), sign-out, 303 to `/account/deleted`. Also reachable from an unfinished `/register`. |
| `/api/geo/regions?country=XX` | GET | Logged-in only. GeoNames admin1 regions of a country. |
| `/api/geo/cities?country=XX&region=YY&q=…` | GET | Logged-in only. Up to 20 cities (prefix, then word-start, then substring; most populous first). |
| `/api/username-available?u=…` | GET | Logged-in only. `{available, error}`: rules first, then the database. 30 per minute per user. |
| `/feedback` | GET/POST (form) | Bug reports and ideas, signed in or not (`?kind=bug\|idea`, `?context=` prefill; `?sent=1` is the thanks page). Stores the row (`feedback`, 12 months), mails a copy to `FEEDBACK_TO`, 303 to `/feedback?sent=1`. 400 re-renders the form; 429 over 5 per address per hour or 60 in all per day. A hidden honeypot field drops bots silently. |
| `/healthz` | GET | Runs `select 1`. |
| `/static/*` | GET | `site.css`, `register.js`, fonts (SIL OFL, licence files next to them), logo, icon, the landing captures and the link-preview image (`tools/make_site_images.sh`). |

Indexable pages (`/`, `/faq`, `/ranking`, `/privacy`, `/terms`) pass `seo` to `page()`: `X-Robots-Tag: index, follow`,
a meta description, a canonical URL for the language the page was rendered in (English at the bare path, the others
at `?lang=xx`), the 10 hreflang alternates plus x-default, Open Graph and Twitter tags, and optional JSON-LD. Every
other page is `noindex, nofollow`.

Every non-GET request must pass the same-origin check (Origin plus Fetch Metadata) before any route runs. Every response carries a strict CSP (`script-src 'self'`, no inline scripts or styles).

## Adding routes (other areas)

- Export a `RouteModule` (`(app) => void`, from `src/modules.ts`) and add one line to `MODULES`.
- Helpers to use:
  - `getViewer(c)`, `viewerStatus(c, v)`, `pathForStatus(status, next)`, `page(c, {title, body})` and `tOf(c)` in `src/http/viewer.ts`;
  - `html` in `src/http/html.ts`, which escapes everything;
  - `redirect303` and `safeNext` in `src/http/redirect.ts`;
  - `privateJson` in `src/http/respond.ts`;
  - `hitRateLimit` in `src/auth/rate-limit.ts`;
  - `listSessions`, `revokeSession` and `deleteUserSessions` in `src/auth/sessions.ts`;
  - `deleteUserAccount` and `profileStatus` in `src/auth/users.ts` (statuses: `blocked`, `register`, `rename`, `terms`, `pending`, `complete`);
  - `notifier.send(text)` from the deps for an operator alert through Telegram (`src/notify/telegram.ts`); fire-and-forget with `void`, username and country at most;
  - `pgError` in `src/db.ts`, to map `23505` on `users_username_key`.
- Page scripts go in `static/*.js` and are loaded with `<script src="/static/…" defer>` through the `head` option of `page()`. Never use inline scripts or `style=""`.

## Legal pages

- `legal/privacy.<lang>.md` and `legal/terms.<lang>.md`, one per game language, rendered by `src/pages/legal.ts` with a
  small Markdown subset: `#`/`##`/`###` headings, paragraphs, `- ` lists, `> ` notes, `**bold**`, `` `code` ``,
  links to `https:`, `mailto:` or same-site paths, and `<!-- comments -->` (dropped). Every text run is escaped.
- English is authoritative. `test/legal.test.ts` checks that each translation has the same headings, list items,
  links, code spans and `{placeholders}` as the English file.
- Placeholders: `{controller}` and `{contact}` (from `LEGAL_CONTROLLER` / `LEGAL_CONTACT_EMAIL`), `{min_age}`. The
  version line under the title is `TERMS_VERSION`, the same value `/register` records.
- The Docker image copies `legal/`.
