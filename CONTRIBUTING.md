# Contributing

Thanks for your interest in Quidditch Manager. Bug reports, translations, canon corrections and code are all welcome.

## Ground rules

- **Canon first.** The books and *Quidditch Through the Ages* are the source of truth. Don't invent rules. When
  something has to be invented (clubs outside Britain, squads, wages, stadiums), mark it: `source: "filler"` in data,
  `[FILLER]` in docs and comments. A gameplay rule chosen for balance is marked `[game]`. Book references use short
  citations such as `[QTTA c7]` or `[HP3 c8]`.
- **No new third-party artwork.** Don't add images from the films, the illustrated editions, Pottermore, wikis or
  redraws of them. The few that are already in the repository are listed in [ATTRIBUTION.md](ATTRIBUTION.md).
- **Every UI string goes through the translation system in all 10 languages** (see below). No hardcoded text in
  screens.
- GDScript only, with static types where practical. Match the style of the surrounding code: tabs, `##` doc comments
  at the top of each file and above non-obvious functions.
- Run the tests before opening a pull request.

## Architecture in one minute

- `src/sim/` is the match engine. It is pure and deterministic. Given the same teams, tactics and seed it produces
  the same event log. It knows nothing about scenes or UI. Tuning values live in `data/shared/rules/sim_params.json`.
- `src/world/` holds the world state (clubs, players, competitions, schools) and builds the initial world from the
  data pack. The starting world is fixed (`WorldGenerator.WORLD_SEED`); only youth players are random.
- `src/game/` advances time. `GameEngine.advance_day()` runs fixtures, transfers, training, finances, news and
  messages. `GameSession` (autoload `Game`) holds the current game, translation helpers and saving.
- `src/ui/` is the interface. `main.gd` is the shell (navigation, top bar, sidebar); each screen in
  `src/ui/screens/` extends `UIScreen` and rebuilds itself in `build()`. `UI` (`src/ui/ui.gd`) has the widget
  helpers and `ThemeBuilder` the theme.

The design documents in [docs/design/](docs/design/) explain the reasoning behind each system.

## Translations

UI strings live in `locale/strings.csv` (one row per key, one column per language:
`es,en,de,fr,it,pt_BR,nl,ru,ja,zh_CN`). Godot imports it into `.translation` files.

- **Add keys.** Write a JSON file `{"ui.my.key": ["es", "en", "de", "fr", "it", "pt_BR", "nl", "ru", "ja", "zh_CN"]}`
  (a list of 10 strings in that order), run `python3 tools/add_keys.py keys.json`, then
  `godot --headless --path . --import`.
- **Improve a language.** Edit `locale/tr/<lang>.csv` and run `python3 tools/merge_translations.py`.
- Check a language: `python3 tools/check_translation.py <lang>` (missing keys, placeholders).
- Use each language's official terminology from its edition of the books (Quaffle = Quaffel / Souafle / Pluffa…).
- Placeholders such as `{player}` or `%s` must be kept.

## Data

The data pack is plain JSON in `data/packs/1993-94/` (clubs, players, competitions, schools, events) plus shared
tables in `data/shared/`. The format is described in [data/README.md](data/README.md). Invented clubs are authored in
`tools/author_clubs.py`, which writes their JSON files. Edit the script rather than the generated files.

## Tests and developer tools

All commands run from the project root.

```sh
godot --headless --path . tools/check_scripts.tscn     # compiles every script under src, tools and tests, in seconds
godot --headless --path . -s tests/run_tests.gd        # engine and world tests (about 20 minutes)
QM_TEST=test_determinism QM_HELPERS=_sim godot --headless --path . -s tools/run_one_test.gd   # one test function

# Match engine
godot --headless --path . -s tools/sim_batch.gd -- --mode equal --n 1000
godot --headless --path . -s tools/sim_batch.gd -- --mode league --n 2
godot --headless --path . -s tools/sim_batch.gd -- --mode one --home club_puddlemere_united --away club_holyhead_harpies --seed 7
godot --headless --path . -s tools/blowouts.gd           # score margins across every league

# Whole-world simulations and audits
godot --headless --path . -s tools/sim_world.gd -- --seasons 5 --save-test
godot --headless --path . -s tools/stress_test.gd -- --seasons 50 --seed 1 --human club_puddlemere_united --save-every 10
godot --headless --path . -s tools/audit_world.gd -- --seasons 4 --seed 3 --human club_puddlemere_united
godot --headless --path . -s tools/life_audit.gd -- --seasons 50 --seed 1 --human club_puddlemere_united
godot --headless --path . -s tools/difficulty.gd -- --club club_wigtown_wanderers --seasons 4
godot --headless --path . -s tools/youth_curve.gd        # youth development calibration
```

- `check_scripts.tscn` runs as a scene, not with `-s`, so the `Game` autoload exists and the `src/ui` scripts
  compile too. It exits 1 when any script fails. Run it between edits, and the suite before a pull request.
- `run_one_test.gd` compiles one function of `tests/run_tests.gd` out of the file and calls it. Name in `QM_HELPERS`
  the private helpers the function calls (`_sim`, `_rm_tree`, ...), comma separated. Exit 0 when every check
  passed, 1 on a failed check, 2 when the function is missing or its body does not compile.
- `stress_test.gd` checks world invariants every season. `audit_world.gd` checks semantic consistency: tables,
  statistics, awards, texts and result distributions. `life_audit.gd` covers life outside matches: transfers,
  regens, retirements, press, owls, reputations and texts in all 10 languages.
- A save of another schema than `World.SCHEMA_VERSION` is refused, with no migration path. A new field with a
  default in `from_dict` needs no bump. A renamed, removed or reinterpreted field bumps the version, and the old
  saves stop loading.

### Screenshots and the UI tour

```sh
# One screen
godot --path . -- [--lang en] [--autostart club_puddlemere_united] [--advance N] --screen squad [--player <id>] --shot /tmp/x.png

# Visit every screen at four points of a season and report untranslated keys, unreplaced placeholders,
# clipped table headers, hidden rows and overflowing layouts
godot --path . -- --tour /tmp/tour --lang de --autostart club_puddlemere_united
TOUR_ONLY=market,squad godot --path . -- --tour /tmp/tour     # only some screens
```

The capture occasionally produces a blank image on the first frames. Run it again if the PNG is tiny.

### Generated assets

| Asset | Tool |
|---|---|
| Vector crests | `python3 tools/make_crests.py` |
| Embroidered crests | `godot --headless --path . -s tools/patch_crests.gd` |
| Maps | `python3 tools/make_map.py` |
| Paper textures | `godot --headless --path . -s tools/make_paper.gd` |
| Sounds and music | `godot --headless --path . -s tools/make_sounds.gd`, `tools/make_music.gd` |
| Website images (captures, link preview) | `bash tools/make_site_images.sh` (cwebp + Godot) |
| Logo, icon, Daily Prophet badge | `tools/make_logo.gd`, `tools/make_icon.gd`, `tools/make_prophet.gd` |
| Windows icon (`assets/icon.ico`) | `python3 tools/make_ico.py` (macOS, uses `sips`) |
| Fallback fonts (symbols, Japanese, Chinese; `assets/fonts/fallback/`) | `python3 tools/make_fallback_fonts.py` (needs `pip install fonttools`); rerun when a translation adds characters the test `test_fonts_cover_translations` reports as missing |
| macOS installer | `bash tools/make_dmg.sh` |
| Browser build | `godot --headless --path . --export-release "Web" export/web/index.html` (needs the `web_nothreads_*.zip` export templates), then serve `export/web/` with any static server, e.g. `python3 -m http.server -d export/web` |

AI artwork (crests, character portraits, broomsticks) is generated from the prompts in [docs/art/](docs/art/).
Source sheets are kept outside the repository and cut out with
`godot --headless --path . -s tools/import_crest_sheets.gd [-- portraits|brooms]`. When clubs or houses are added,
`python3 tools/add_ai_prompts.py` writes their prompt batches.

## The web accounts service (`server/`)

The browser version has a small accounts service: sign-in, profiles, the gate in front of the game, and the privacy
and terms pages. It is Node 24 + TypeScript ([Hono](https://hono.dev), postgres.js, zod, jose). The desktop game never
uses it, and Godot ignores the folder. Design: [docs/design/12-web-version.md](docs/design/12-web-version.md); details:
[server/README.md](server/README.md).

### Run it locally

You need Node 24 or newer and Docker (or any Postgres 16). No Google or Resend account is needed:

```sh
docker compose -f deploy/compose.dev.yml up -d db   # Postgres on 127.0.0.1:5432, migrations applied on first boot
cd server
npm ci
npm run gen:i18n     # locale/strings.csv → generated/strings.json (the web.* keys)
npm run dev          # http://localhost:8080
```

- **Signing in without email.** With no `RESEND_API_KEY`, the sign-in link (and the whole email) is printed to the
  terminal running `npm run dev`. Open it and press the button.
- **Google** stays hidden until `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set; a test OAuth client needs the
  redirect URI `http://localhost:8080/auth/google/callback`.
- **The game behind the gate.** Export the Web preset to `export/web/`, then set `DEV_PLAY_DIR=../export/web`
  (development only) and open `http://localhost:8080/play/`.
- Local settings go in `server/.env.local`, which is git-ignored. Never commit a real key, password or address.

### Tests

```sh
cd server
npm run typecheck
npm test                       # unit tests: fake database, no network
# integration tests against a throwaway Postgres (pick any free local port)
docker run --rm -d --name qm-test-pg -p 127.0.0.1:55432:5432 -e POSTGRES_PASSWORD=test postgres:16
TEST_DATABASE_URL=postgres://postgres:test@127.0.0.1:55432/postgres npm run test:integration
docker rm -f qm-test-pg
```

CI runs the same commands, plus a Docker build of the api image from the repository root
(`docker build -f server/Dockerfile .`). Without `TEST_DATABASE_URL` the integration tests are skipped.

### Strings and legal text

- **Every string a player can see needs all 10 languages**, on the server too. Pages and emails use `web.*` keys in
  `locale/strings.csv`, added with `tools/add_keys.py` like any other key (see [Translations](#translations)). Never
  hardcode text in a page. `npm run gen:i18n` fails when a `web.*` key is empty in a language or its `{placeholders}`
  differ from English; the unit tests fail when the server uses a key that is missing.
- To try keys before they are merged: `npm run gen:i18n -- --extra my-keys.json` (same JSON format as `add_keys.py`).
- The privacy policy and terms of use are `server/legal/<privacy|terms>.<lang>.md`. **English is authoritative.** Change
  `*.en.md` first, then the nine translations, which must keep the same headings, list items, links and
  `{placeholders}` (a test checks it). A change that matters to players also bumps `TERMS_VERSION`, which asks every
  player to accept again. Never put a real name or address in these files. The operator's details come from the
  server's environment.

### Protected paths

`.github/CODEOWNERS` requires the owner's review for changes to:

- `server/src/auth/` (sign-in, sessions, tokens, rate limits),
- `server/migrations/` (the database schema and roles),
- `deploy/` (the server, Caddy, backups),
- `.github/` (CI and release workflows).

Pull requests there are welcome, but expect a closer review. Please report vulnerabilities privately, as described in
[SECURITY.md](SECURITY.md), not in an issue or a pull request.
