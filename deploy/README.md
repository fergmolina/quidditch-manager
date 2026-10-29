# Deploy runbook: the web build with accounts

How the browser version of Quidditch Manager runs on one small VPS:
- a Godot web export behind a login gate;
- a small accounts API (`server/`);
- Postgres;
- nightly offsite backups.

Everything here runs on free tiers. The only costs are the VPS and the domain.

- **This directory is public.** It holds no secrets, IPs, hostnames or personal emails.
- Values live in one place only: `/srv/quidditch-manager/.env` on the server (mode 600). `env.example` lists the names.
- Examples use placeholders: `<domain>`, `<owner>/<repo>` and `<host>`. `<host>` is your own `~/.ssh/config` alias for the box over Tailscale.

> **The one rule: migrate first, then deploy.** `update.sh` never runs migrations as part of a deploy. When a release adds a migration:
> 1. Run `./deploy/update.sh --target migrate vX.Y.Z`.
> 2. Then run `./deploy/update.sh vX.Y.Z`.
>
> Migrations are idempotent and additive (see `server/migrations/0001_accounts.sql`), so the running API keeps working while they apply.

## 1. What runs

```
Internet ─ Cloudflare (DNS, TLS, cache, WAF) ─ Tunnel (outbound only) ─┐
Hetzner Cloud Firewall: no inbound rules; ufw: only SSH on tailscale0   │
┌─ VPS ─────────────────────────────────────────────────────────────────┴───┐
│ /srv/quidditch-manager        git checkout (main) + .env                  │
│ /srv/quidditch-manager-data   web/releases/<v>/, web/current, web/previous│
│                               backups/daily|weekly, state/                │
│                                                                           │
│  cloudflared ─front─► caddy :8080 ─back─► api :8080 ─data(internal)─► db  │
│                        │ /play/ HTML: forward_auth → api /api/gate        │
│                        │ /play/r/<v>/*: static, immutable                 │
│                        └ everything else: reverse_proxy → api             │
│  backup (profile ops, host cron) ─data─► db ;  ─ops─► Backblaze B2        │
└───────────────────────────────────────────────────────────────────────────┘
```

| Service | Image | Notes |
|---|---|---|
| `cloudflared` | `cloudflare/cloudflared:2026.10.3` (pinned) | Profile `edge`. Starts only once `CLOUDFLARE_TUNNEL_TOKEN` is set. |
| `caddy` | `caddy:2.11.7-alpine` | Runs as uid 65534. Read-only. Its only capability is `NET_BIND_SERVICE`, because the binary carries that file capability and the kernel refuses to exec it otherwise. Bound to `127.0.0.1:${QM_HTTP_PORT}` only. |
| `api` | `qm-api:current` | Tagged by `update.sh`. Built from `server/Dockerfile`. Runs as `node`, read-only, with no capabilities. No published port. |
| `db` | `qm-db:local` (`deploy/postgres`) | Postgres 16.15 + pg_cron. Runs as `postgres`, read-only, with no capabilities. Lives on an internal network, so it has no route to the internet and no host port. |
| `backup` | `qm-backup:local` (`deploy/backup`) | psql/pg_dump 16 and rclone. Profile `ops`, so it runs only when called: by the cron or by `update.sh --target migrate`. |

Every container sets `no-new-privileges` and has memory and pid limits. Each one gets only its own environment variables (no shared `env_file`).

- **Client IPs.** The API trusts `CF-Connecting-IP` because nothing but the tunnel reaches Caddy, apart from `127.0.0.1` on the host itself.
- **No access logs.** Caddy keeps none, so no visitor IPs are written anywhere.

Always drive compose through the wrapper, which adds the project name and the env file:

```sh
./deploy/compose.sh ps
./deploy/compose.sh logs -f --tail 100 api
./deploy/compose.sh exec db sh -c 'exec psql -U postgres "$POSTGRES_DB"'
```

## 2. Create the server (Hetzner)

1. In Hetzner Cloud, create a project and add your SSH public key.
2. Create a server:
   - Location: Falkenstein (`fsn1`), in the EU.
   - Image: Ubuntu 24.04.
   - Type: the smallest **x86 "CX"** type with **2 vCPU and 4 GB** (CX22, now CX23; Hetzner renames them) is plenty. **CAX11** (ARM) also works, but only if the release builds the API image for `linux/arm64` too. All the other images are multi-arch.
   - Keep the public IPv4. GitHub, where the release downloads come from, has no IPv6.
   - Leave Hetzner's paid backups off (B2 is used instead).
3. Create the **Cloud Firewall** and give it, for now, **one inbound rule: TCP 22 from your own IP only** (`/32`), and attach it right away, so the fresh box is not open to the whole internet while you bootstrap it. After SSH over Tailscale works (step 3), **delete that rule**. The firewall then has no inbound rules at all, and the box answers nothing from the internet (the site arrives through the Cloudflare Tunnel, SSH through Tailscale; both connect outbound). With the CLI:
   `hcloud firewall add-rule <fw> --direction in --protocol tcp --port 22 --source-ips <your-ip>/32` and later `hcloud firewall delete-rule <fw> --direction in --protocol tcp --port 22 --source-ips <your-ip>/32`.

## 3. Bootstrap the box

From your machine, as root on the new server (the key Hetzner installed is reused for the deploy user):

```sh
ssh root@<server> 'REPO_URL=https://github.com/<owner>/<repo>.git bash -s' < deploy/bootstrap.sh
```

`bootstrap.sh` is idempotent. Run it again whenever something failed. It does the following:
- Creates the deploy user `qm` (sudo and docker).
- Sets sshd to keys only.
- Installs Docker CE with compose, Tailscale, fail2ban, unattended upgrades (reboot window 05:30 UTC), and unzip, brotli and jq.
- Clones the repo to `/srv/quidditch-manager` and creates `/srv/quidditch-manager-data`.
- Copies `.env` from `env.example` with mode 600, and fills `POSTGRES_PASSWORD`, `DB_API_PASSWORD` and `AUTH_SECRET` with random hex. It never overwrites a value that is already there.
- Installs the crontab and logrotate.
- Stages ufw to allow only 22/tcp on `tailscale0`.

Then:

1. Open the Tailscale login URL it prints.
2. Check `ssh qm@<tailscale name>` from another terminal.
3. Enable the firewall: `FIREWALL_LOCK=yes bash bootstrap.sh` (re-run), or answer `yes` at the prompt.
4. Delete the temporary SSH rule from the Hetzner Cloud Firewall (step 2), so it has no inbound rules left.
5. Put an alias in your `~/.ssh/config` (`Host <host>`). From now on, only `ssh <host>` works.

## 4. External services (all free tiers)

### 4.1 Resend (magic-link emails)

Hetzner blocks outbound port 25, so the box cannot send mail itself.

1. In Resend, go to **Domains → Add domain** and enter `<domain>`. Choose the region **eu-west-1 (Ireland)**.
2. Copy the records Resend shows into Cloudflare DNS. They must be **DNS only**; MX and TXT records cannot be proxied anyway.
   - DKIM: TXT `resend._domainkey`
   - SPF on the `send` subdomain: MX `send` → `feedback-smtp.eu-west-1.amazonses.com` (priority 10), and TXT `send` → `v=spf1 include:amazonses.com ~all`
   - Recommended: TXT `_dmarc` → `v=DMARC1; p=none;` (DMARC passes through DKIM alignment)
3. Wait for **Verified**.
4. Go to **API Keys → Create** with *Sending access* limited to that domain, then set:
   - `RESEND_API_KEY=` the new key
   - `MAIL_FROM=Quidditch Manager <login@<domain>>`
5. Free tier: 100 emails per day and 3,000 per month. `MAIL_DAILY_CAP=90` keeps the site under that.

### 4.2 Google OAuth

1. In the Google Cloud console, create a new project, then open **APIs & Services → OAuth consent screen**:
   - User type: **External**.
   - App name: plain, for example "Quidditch Manager (fan game)". Add no logo, so no brand verification is needed.
   - Support email: the site's contact address.
   - App home page: `https://<domain>/`. Privacy policy: `https://<domain>/privacy`. Terms: `https://<domain>/terms`.
   - Authorized domain: `<domain>`.
   - Scopes: `openid`, `email` and `profile`. They are non-sensitive, so Google needs no review.
   - Publish the app ("In production"). In testing mode only listed test users can sign in.
2. Go to **Credentials → Create credentials → OAuth client ID** and pick **Web application**:
   - Authorized redirect URI: `https://<domain>/auth/google/callback` (exactly; `SITE_URL` must match).
   - No JavaScript origins are needed.
   - For local development, create a **separate** client with `http://localhost:8080/auth/google/callback`.
3. Put the client ID and secret into `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`.

### 4.3 Backblaze B2 (offsite backups)

1. When you sign up, choose the **EU Central** region (Amsterdam). The region belongs to the account and cannot change later.
2. Create a bucket:
   - **Private**.
   - **Default encryption on** (SSE-B2).
   - Object Lock off.
   - Lifecycle: **Keep only the last version of the file**, so pruned dumps really disappear.
3. Create an **application key** limited to that bucket (read and write), and set `B2_KEY_ID`, `B2_APP_KEY`, `B2_BUCKET` and optionally `B2_PATH`.
4. Optional but recommended: set `BACKUP_CRYPT_PASSWORD` (`openssl rand -hex 32`). The copies are then encrypted before they leave the box (rclone crypt).
   - Keep this password in your password manager too.
   - Without it, the offsite copies cannot be read.

The free tier is 10 GB. The dumps are kilobytes to a few MB.

### 4.4 Cloudflare

1. Add `<domain>` to Cloudflare (Free plan) and point the registrar's nameservers at it.
2. **Tunnel.** Go to Zero Trust → Networks → Tunnels → Create a tunnel (type *Cloudflared*), and copy the token into `CLOUDFLARE_TUNNEL_TOKEN`. In the tunnel's **Public hostnames**, add:
   - `<domain>` → Service `HTTP`, URL `caddy:8080`.
   - Optionally `www.<domain>` → the same. Then add a Redirect Rule `www.<domain>/*` → `https://<domain>/${1}` (301), because `SITE_URL` must be a single origin.
3. **SSL/TLS:**
   - Always Use HTTPS: on.
   - Minimum TLS version: 1.2.
   - HSTS: optional (Caddy and the API send it anyway).
4. **Turn off anything that rewrites pages:**
   - Rocket Loader, Email Address Obfuscation, Cloudflare Fonts, and Zaraz/analytics injection: **off**. They inject scripts that the CSP blocks.
   - Bot Fight Mode: off. It can challenge the login POSTs.
5. **Cache Rules** (Caching → Cache Rules). Order matters, so create them in this order:
   1. **"bypass accounts and the game page"**, action **Bypass cache**. Expression:
      ```
      (http.request.uri.path eq "/") or (http.request.uri.path in {"/play" "/play/" "/play/index.html" "/healthz"})
      or starts_with(http.request.uri.path, "/login") or starts_with(http.request.uri.path, "/register")
      or starts_with(http.request.uri.path, "/account") or starts_with(http.request.uri.path, "/auth/")
      or starts_with(http.request.uri.path, "/api/") or starts_with(http.request.uri.path, "/privacy")
      or starts_with(http.request.uri.path, "/terms") or http.request.uri.path in {"/faq" "/ranking" "/feedback"}
      ```
      The routes also answer `private, no-store`. This rule just makes sure a page carrying a session is never cached.
   2. **"game releases"**: `starts_with(http.request.uri.path, "/play/r/")`. Settings:
      - **Eligible for cache**.
      - Edge TTL: *Use cache-control header if present*.
      - Browser TTL: *Respect origin*.

      Without this rule Cloudflare does not cache `.pck` and `.wasm`.

   `/static/*` (CSS, fonts, logo) is cached by default by file extension and respects the API's headers.
6. **WAF rate limiting.** The Free plan allows **one** rule. Spend it on the login endpoints (Security → WAF → Rate limiting rules):
   - Expression: `(http.request.method eq "POST" and starts_with(http.request.uri.path, "/auth/"))`. If the Free editor does not offer the method field, use the path alone.
   - Characteristic: IP. Rate: 20 requests per 10 seconds. Action: Block for 10 seconds.
   - The finer limits live in the API and the database (per address, per IPv6 /64, and a global mail cap).
7. **robots.txt.** Security → Bots (or Settings → Bots): turn **off** "Instruct AI bot traffic with robots.txt"
   (managed robots.txt). The API serves its own `/robots.txt` with the sitemap; the managed one is prepended to it.

### 4.5 Search engines

The API serves `/robots.txt`, `/sitemap.xml` (the public pages in all 10 languages, with hreflang alternates), a
canonical URL, hreflang alternates, Open Graph tags and schema.org JSON-LD on every public page. To get them read:

1. **Google Search Console** → Add property → *Domain* `<domain>` → copy the `google-site-verification=…` TXT
   record into Cloudflare DNS (name `@`) → Verify → Sitemaps → submit `https://<domain>/sitemap.xml`.
2. **Bing Webmaster Tools** → Import from Search Console (or verify with its own TXT/CNAME) → submit the same sitemap.
3. **IndexNow** (Bing, Yandex, Seznam, Naver): set `INDEXNOW_KEY` (§5), deploy, then `./deploy/indexnow.sh`
   submits every URL of the sitemap. Run it again after a deploy that changes public pages.

## 5. Fill `.env`

```sh
ssh <host>
cd /srv/quidditch-manager && nano .env      # stays mode 600
```

Variables to fill:
- Required:
  - `SITE_URL=https://<domain>`
  - `RELEASE_REPO=<owner>/<repo>`
- At least one login method:
  - Resend: `RESEND_API_KEY` and `MAIL_FROM`
  - and/or Google: `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`
- Legal pages: `LEGAL_CONTROLLER` and `LEGAL_CONTACT_EMAIL`.
- Recommended: `API_IMAGE` (when the release publishes the API image to GHCR) and the `B2_*` keys.
- Optional: `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` for failure alerts and the api's sign-up and feedback alerts.
- Optional: `INDEXNOW_KEY` (`openssl rand -hex 16`) so Bing and the other IndexNow engines hear about page changes
  (`./deploy/indexnow.sh` after a deploy that changes public pages; see §4.5).
- Optional: `ACCESS_MODE=approval` for a closed trial (every new account waits for your approval; see §11).
- **Already set by bootstrap.** Do not change them after the first start:
  - `POSTGRES_PASSWORD`
  - `DB_API_PASSWORD`
  - `AUTH_SECRET`
  - `QM_UID`, `QM_GID` and `QM_DATA_DIR`

The API refuses to start in production when a required value is missing, and its log lists them.

## 6. First rollout (in this order)

```sh
ssh <host>
cd /srv/quidditch-manager
./deploy/update.sh --target stack vX.Y.Z --verify
```

This command:
1. Builds the db and backup images.
2. Starts Postgres. On a fresh volume, `deploy/postgres/init/10-schema.sh` applies every migration and sets the `qm_api` password.
3. Runs the migrations again. They are idempotent, and `--verify` prints the tables, the grants and the cron jobs.
4. Starts Caddy.
5. Deploys the API and the web release of `vX.Y.Z`.

The tunnel stays down, so nothing is public yet. Check on the box (§10, "On the box"). Then:

```sh
./deploy/update.sh --target edge      # CLOUDFLARE_TUNNEL_TOKEN must be set
```

Then run the browser checklist (§10), take a first backup (§9), and restore it once with `--scratch`. The crontab that bootstrap installed already runs the health probe every 5 minutes and the backup at 05:15 UTC.

## 7. Routine deploys

```sh
ssh <host> 'cd /srv/quidditch-manager && ./deploy/update.sh vX.Y.Z'          # api + web of the tag
ssh <host> 'cd /srv/quidditch-manager && ./deploy/update.sh'                 # the latest GitHub Release
ssh <host> 'cd /srv/quidditch-manager && ./deploy/update.sh --target migrate vX.Y.Z'   # FIRST, when the release has migrations
```

Before deploying, `update.sh` takes a lock, so only one deploy runs at a time. It also runs `git pull --ff-only`, which updates the deploy tooling itself on `main` (`--no-pull` skips it).

**api step:**
1. Pulls `API_IMAGE:vX.Y.Z`. When `API_IMAGE` is empty, or with `--build`, it builds the image from the tag's `server/` and `locale/strings.csv` on the box instead.
2. Tags the image `qm-api:current`. The old one becomes `qm-api:previous`.
3. Recreates the API and waits for its healthcheck. If the check fails, the previous image comes back automatically.

**web step:**
1. Downloads `WEB_ASSET` and `SHA256SUMS` from the GitHub Release and verifies the checksum.
2. Unpacks into `releases/vX.Y.Z/` and refuses archives that contain links or special files.
3. Injects `<base href="/play/r/vX.Y.Z/">` and precompresses the files (gzip and brotli).
4. Switches the `current` symlink atomically. The old target becomes `previous`.
5. Smoke-tests through Caddy. If the test fails, it switches back.
6. Keeps `KEEP_RELEASES` older releases besides those two.

**Rollback:**
- `./deploy/update.sh --rollback` goes back to the previous API image and web release. `--target web` or `--target api` limits it to one of the two.
- To go to any older version: `./deploy/update.sh vA.B.C`.
- A migration is never rolled back. They are additive, so an older API runs fine on a newer schema.

**Changes to the infrastructure (they arrive with `git pull`):**
- Caddyfile changed: `./deploy/update.sh --target caddy` validates it and reloads it without downtime.
- A service changed in `compose.yml`: `./deploy/compose.sh up -d --no-deps <service>`.
- Postgres image or `qm.conf` changed: `./deploy/update.sh --target stack` (restarts db; brief API errors).
- An `.env` value the API reads changed: `./deploy/compose.sh up -d --no-deps api` (recreates it with the new environment).

### Release contract (what `release.yml` must publish)

`update.sh` expects each GitHub Release with tag `vX.Y.Z` to have:
- **`QuidditchManager-vX.Y.Z-web.zip`** (the `WEB_ASSET` pattern). It holds the Godot **Web** export: `index.html`, `index.js`, `index.wasm`, `index.pck`, the audio worklets and the icons. They sit at the archive root or in one top-level folder. `.tar.gz` also works.
- **`SHA256SUMS`** in `sha256sum` format, listing that archive.
- Optionally, the API image **`ghcr.io/<owner>/<image>:vX.Y.Z`** (a public package; `API_IMAGE` without the tag).
  - Build it from the repository root: `docker build -f server/Dockerfile .` (the image generates its web strings from `locale/strings.csv` itself and copies the `data/shared/` files the ranking validator and the ranking map read).
  - Build with BuildKit, the default builder since Docker 23: the classic builder ignores `server/Dockerfile.dockerignore` and sends the whole repository as the context.
  - Build `linux/amd64`, plus `linux/arm64` for an ARM box.

The checksum file comes from the same release, so it catches corrupted or truncated downloads. It cannot catch a compromised GitHub account. A stronger check, GitHub artifact attestations verified on the box, can be added later without changing this layout.

## 8. How `/play/` is served, and why

**The gate.**
- Only the HTML entry page (`/play/` and `/play/index.html`) goes through Caddy's `forward_auth` to `/api/gate`.
- With no session, or an incomplete profile, the gate's 302 to `/login?next=/play/` or `/register?next=/play/` reaches the browser unchanged.
- With a complete profile, Caddy serves `web/current/index.html` with `Cache-Control: private, no-store`.
- The engine and data files are not gated. They are public in the GitHub Release archives anyway. Registration gives players an identity; it is not DRM.

**Asset versioning (fixes design finding 2).** Godot exports fixed file names (`index.wasm`, `index.pck`), so a long cache on `/play/index.wasm` would mix releases. Instead:
- `update.sh` writes `<base href="/play/r/<v>/">` into the release's `index.html`, so every relative URL the loader uses lands under `/play/r/<v>/`. That covers the engine script, `.wasm`, `.pck`, the audio worklets and the icons.
- Those files never change for a given `<v>`. Caddy and Cloudflare cache them as `public, max-age=31536000, immutable`.
- A returning player downloads nothing until the next release.
- A player whose tab still runs an old release keeps loading that release's own files, as long as it is on disk (`KEEP_RELEASES`).
- `/play/<file>` (no version) still works as a fallback. It is served from `current` with `no-cache` (revalidated by ETag).
- `/play/r/<v>/index.html` redirects to the gated `/play/`.

**Content-Security-Policy on `/play/` (a temporary compromise).**
- **Why it is loose.** Godot 4.7's default HTML shell starts the engine from an inline `<script>` and has an inline `<style>`. The game also calls `JavaScriptBridge.eval()`, which is JavaScript `eval()`, for the save-file picker (`Platform.pick_file`).
- **The enforced policy** therefore allows `'unsafe-inline'` and `'unsafe-eval'`, **only on `/play/*`**. Every account page, form and login keeps the API's strict CSP: no inline code, no eval.
- **Why that is acceptable for now.** The game page shows no user-supplied content and loads nothing from other origins, so the XSS surface stays small.
- **The target policy** (`script-src 'self' 'wasm-unsafe-eval'`, no inline) is sent at the same time as `Content-Security-Policy-Report-Only`. The browser console lists every remaining violation, and nothing is collected anywhere.
- TODO (Godot step, WP4):
  1. Use the custom shell `web_shell/qm_shell.html`, with the engine started from an external `shell.js` and no inline style.
  2. Use `JavaScriptBridge.get_interface()` instead of `eval`.
  3. When the Report-Only policy is clean in Chrome, Firefox and Safari, move it to the enforced header in the `(play_headers)` snippet of the `Caddyfile` and drop the two `unsafe-` keywords.
- **`base-uri 'self'`** (not `'none'`), because of the injected `<base>`.
- **No COOP/COEP isolation headers.** The export is single-threaded and needs no `SharedArrayBuffer`.

## 9. Backups and restore

- **Nightly, from the host cron at 05:15 UTC.** `./deploy/compose.sh run --rm -T backup` does the following.
  - Runs `pg_dump -Fc` of schema `public` into `QM_DATA_DIR/backups/daily/`, and checks the dump with `pg_restore --list`.
  - On Sundays, keeps a hard-linked copy in `weekly/`.
  - Retention is **7 daily and 4 weekly**, the defaults in `compose.yml` (`BACKUP_KEEP_DAILY` and `BACKUP_KEEP_WEEKLY`, which `.env` can override).
  - Then `rclone sync` to B2, encrypted when `BACKUP_CRYPT_PASSWORD` is set.
  - A failure sends a Telegram alert, if one is configured.
- **Privacy.** The privacy policy promises that deleted accounts leave the backups **within 45 days**, and the account deletion page shows the same number from `BACKUP_RETENTION_DAYS` (`.env`, default 45). 7 daily and 4 weekly dumps last about 5 weeks. Change the three together, or not at all.
- Restore test, once a quarter (and once after the first rollout):
  ```sh
  ./deploy/backup/restore.sh /srv/quidditch-manager-data/backups/daily/latest.dump --scratch
  ```
  It restores into a throwaway `qm_restore_test`, prints the row counts and drops it. Production is not touched.
- Real recovery:
  ```sh
  ./deploy/compose.sh run --rm -T backup backup.sh --list-remote            # offsite copies
  ./deploy/compose.sh run --rm -T backup backup.sh --fetch daily/qm_<stamp>.dump
  ./deploy/backup/restore.sh /srv/quidditch-manager-data/backups/restored/qm_<stamp>.dump --wipe
  ```
  `--wipe` does the following:
  - Stops the API.
  - Replaces schema `public`.
  - Runs `deploy/db/apply.sh`. The dump has no owners or grants, so this re-creates the `qm_api` grants, its password and the pg_cron jobs.
  - Starts the API again.
- **New server from scratch.** Set `QM_INIT_SCHEMA=0` in `.env` before the first `--target stack`, then restore with `--wipe` (or without it, on an empty schema).

## 10. How to verify

**On the box** (`ssh <host>`):

```sh
./deploy/compose.sh ps                                            # caddy, api, db healthy (cloudflared up)
curl -sI 127.0.0.1:8080/play/ | grep -iE '^(HTTP|location)'       # 302 → /login?next=%2Fplay%2F
curl -s  127.0.0.1:8080/healthz                                   # ok
curl -sI 127.0.0.1:8080/play/r/vX.Y.Z/index.wasm | grep -iE 'HTTP|cache-control|content-type'
                                                                  # 200, immutable, application/wasm
curl -sI 127.0.0.1:8080/login | grep -i '^content-security-policy'   # the strict API policy
./deploy/compose.sh run --rm --no-deps -T backup /srv/deploy/db/apply.sh --dry-run   # migrations visible
```

**From outside:**

```sh
curl -sI https://<domain>/play/r/vX.Y.Z/index.wasm | grep -i cf-cache-status   # HIT from the 2nd request on
curl -sI https://<domain>/login | grep -i cf-cache-status                      # DYNAMIC or BYPASS
curl -sI https://<domain>/play/ | grep -iE '^(HTTP|location|cf-cache-status)' # 302, never HIT
```

**Browser checklist** (desktop Chrome, Firefox and Safari, then Safari on iOS):
- [ ] Log in with an email link: the email arrives in the page's language, the link works once, and the button on the link page must be pressed.
- [ ] Log in with Google.
- [ ] Register: a taken name and a reserved name are refused; country, region and city pickers work.
- [ ] `/play/` loads the game. Play, export a save, sign out.
- [ ] `/account`: sessions are listed and one can be revoked; data export works; delete the account.
- [ ] DevTools console on `/play/`: no **enforced** CSP errors. Report-Only messages are expected until WP4.
- [ ] Network tab: `.wasm` and `.pck` come from `/play/r/<version>/` and return 304 or disk cache on a reload.

## 11. Operations

- Logs: `./deploy/compose.sh logs --tail 200 api` (also `db` and `caddy`). Host jobs log to `/var/log/quidditch-manager/`.
- SQL: `./deploy/compose.sh exec db sh -c 'exec psql -U postgres "$POSTGRES_DB"'`. Moderation by SQL:
  - Block a user: `update users set blocked_at = now() where lower(username) = lower('<name>');` (or the Block
    button on `/admin/users`, which also ends the user's sessions)
  - Force a rename on the next visit: `update users set must_rename = true where …;`
  - Make someone an admin: `./deploy/db/make-admin.sh <email>` (the account must have signed in once; the address
    goes through an environment variable, never a psql argument). Admins see `/admin/users` and `/admin/feedback`;
    everyone else gets the ordinary 404 there. `is_admin` is never set from the app.
  - Delete an account (cascades): `delete from users where …;`, then `delete from login_tokens where email = '<email>';`
- **Closed trial (manual approval).** Set `ACCESS_MODE=approval` in `.env` and restart the api
  (`./deploy/compose.sh up -d --no-deps api`). From then on a new account that completes `/register` lands on
  `/pending` (and `/api/gate` keeps it out of `/play/`) until you press Approve on `/admin/users?view=pending`;
  accounts that existed before the switch keep playing (migration `0006_approval.sql` approved them, and open
  access approves each registration as it happens). With `TELEGRAM_*` set, the api sends a Telegram message per
  completed registration (username and country only) with a link to that page, and one per feedback submission.
  Revoke undoes an approval, Block also ends the user's sessions. Back to `ACCESS_MODE=open` and a restart ends
  the trial: nobody waits any more, and `approved_at` stays as history.
- **New terms.** Bump `TERMS_VERSION` in `.env`, then `./deploy/compose.sh up -d --no-deps api`. Everyone is asked to accept again on their next visit. The privacy policy now also names Telegram (sign-up alerts) and the approval date: bump it when that matters to your users.
- Rotating secrets:
  - `DB_API_PASSWORD`: edit `.env`, run `./deploy/update.sh --target migrate` (which sets the role password), then `./deploy/compose.sh up -d --no-deps api`.
  - `AUTH_SECRET`: edit `.env` and recreate the API. Only Google logins in progress at that moment break.
  - `POSTGRES_PASSWORD`: run `alter role postgres password '…'` in psql first, then edit `.env`.
- **Disk.** The weekly cron prunes dangling images and caps the build cache. It never removes the `qm-api:current` and `qm-api:previous` tags.
- **Image bumps** (cloudflared, caddy, postgres minor, alpine). Change the pinned tag in `compose.yml` or the Dockerfile in a PR. After the merge, `./deploy/compose.sh up -d --no-deps <service>` (or `--target stack` for db and backup).

## 12. Try the production stack locally

Docker only, no Cloudflare. Use a throwaway env file **outside** the repo:

```sh
cat > /tmp/qm-test.env <<'EOF'
NODE_ENV=development
SITE_URL=http://localhost:18080
POSTGRES_PASSWORD=<openssl rand -hex 24>
DB_API_PASSWORD=<openssl rand -hex 24>
AUTH_SECRET=<openssl rand -hex 32>
QM_DATA_DIR=/tmp/qm-data
QM_HTTP_PORT=18080
QM_UID=<id -u>
QM_GID=<id -g>
EOF
export QM_ENV_FILE=/tmp/qm-test.env
./deploy/update.sh --no-pull --target stack                       # db + migrations + caddy
docker build -f server/Dockerfile -t qm-api:dev .
(cd export/web && zip -qr /tmp/QuidditchManager-v0.0.1-web.zip .)
(cd /tmp && shasum -a 256 QuidditchManager-v0.0.1-web.zip > SHA256SUMS)
./deploy/update.sh --no-pull v0.0.1 --api-image qm-api:dev \
  --archive /tmp/QuidditchManager-v0.0.1-web.zip --sums /tmp/SHA256SUMS
# http://localhost:18080/play/ → log in (the magic link is printed in `./deploy/compose.sh logs api`)
./deploy/compose.sh --profile ops --profile edge down -v          # remove everything, including the database
```
