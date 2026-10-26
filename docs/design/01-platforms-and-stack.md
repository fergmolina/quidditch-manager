# 01: Platforms and stack

## Platforms

- **Windows** (10/11, x64) and **macOS** (Apple Silicon and Intel, universal binary).
- Installable desktop game, fully offline, no account.
- **Browser.** A web export of the same project (`12-web-version.md`), to be served as static files. Saves stay in the browser (IndexedDB) or are downloaded and uploaded as files; the server keeps none.
- Mouse and keyboard. Minimum design resolution: 1280×720; scalable interface.

Originally planned: desktop only, no web build.

## Engine: Godot 4

- **Version.** The latest stable Godot 4.x at the start of development.
- **Language.** GDScript for the whole game. If mass simulation (simulating every match in the world on a matchday) turns out to be slow in GDScript, the simulation layer is migrated to **C#** (Godot .NET) or to a GDExtension. That is why the simulation is written from the start as an isolated module with no dependencies on nodes or the scene.
- **Why Godot.** It is free and open source (no licenses or royalties, consistent with a fan project) and 2D-oriented, it exports natively to Windows and Mac with one click, and it has a UI system (Control nodes, themes) suited to dense table-heavy screens and built-in internationalization support.

## Project structure

The repository root is the Godot project:

```
project.godot
export_presets.cfg
src/
  sim/          # Match engine: pure, deterministic, no Godot nodes (match_sim.gd, sim_*.gd)
  world/        # World model: clubs, players, competitions, schools, national teams, generators
  game/         # Game flow: game engine and session, career, economy, contracts, scouting,
                #   progression, press, news, team talks, saving
  ui/           # Screens (screens/), widgets (widgets/, including the 2D pitch viewer
                #   pitch_2d.gd), theme (theme/)
data/
  packs/1993-94/  # Starting-season database (JSON): clubs, players, competitions, schools,
                  #   national teams, book events
  shared/         # Data shared by all packs: brooms, grounds, climate, regions, schools, name tables,
                  #   map, crest templates, match rules and simulator parameters (rules/)
assets/         # Art (crests, portraits, brooms, flags, icons), fonts, sounds
locale/         # Translations: strings.csv (es, en, de, fr, it, pt_BR, nl, ru, ja, zh_CN) plus tr/
tests/          # run_tests.gd: custom headless test runner (simulator and world tests)
tools/          # Calibration and audit scripts (sim_batch.gd, sim_world.gd, stress_test.gd…),
                #   asset generators, translation tools (merge_translations.py), DMG packaging
docs/
  design/       # These design documents
  research/     # Background research
  art/          # Art prompt docs (crests/, portraits/, brooms/)
  calibration/  # Calibration charts and examples
```

Originally planned: a separate `src/match_view/` module for the 2D viewer (the viewer ended up as a UI widget, `src/ui/widgets/pitch_2d.gd`), locales es and en only, and tests in GUT or gdUnit4.

## Data

- The whole database (teams, players, brooms, leagues, calendar) lives in **JSON** in `data/`, readable and editable without touching code. This allows fixing names, adding teams or replacing the filler.
- Every record carries a `source` field (`canon_book`, `canon_qtta`, `canon_pottermore`, `canon_dp`, `canon_cards`, `prop`, `videogame`, `inferred`, `filler`; full list in `data/README.md`) so that filler is identifiable in the data too, not only in the documents.
- Schema details in `09-data-model.md`.

## Saved games

- Serialization of the complete world state to one file per game in `user://saves/` (Godot maps it to `%APPDATA%` on Windows and `~/Library/Application Support` on Mac).
- The format is compressed JSON (gzip) with a schema number (`World.SCHEMA_VERSION`). A save of another schema is refused. There is no migration path.
- Autosave once per game month (can be turned off in Settings), on the first day advanced into a new month, and after every match the manager plays, alternating between two slots (`autosave_1` and `autosave_2`), plus manual slots.

## Internationalization

- Spanish and English from the start; the game now ships in 10 languages (es, en, de, fr, it, pt_BR, nl, ru, ja, zh_CN). All interface text goes through `tr()` and lives in `locale/`.
- Canon proper names (teams, players, brooms, plays) are stored in the original English in the data and have the official Spanish translation where one exists (quaffle, bludger, snitch dorada, guardián, cazador, golpeador, buscador).
- Generated text (match commentary, news, board messages) is built from translatable templates with parameters, never by concatenating strings.

## Export and installers

- **Windows.** Godot `.exe` export packaged in an installer (Inno Setup or NSIS). No code signing at first, so Windows SmartScreen will show an "unknown publisher" warning. A signing certificate costs money and is to be evaluated later.
- **macOS.** Universal `.app` export inside a `.dmg`. Without Apple signing and notarization, Gatekeeper blocks the app and the user has to open it with right-click, then Open, or from the Security settings. Signing and notarizing requires an Apple Developer account (99 USD/year). To be decided at the first distribution; the design does not depend on it.
- Reproducible builds from the command line (`godot --headless --export-release`), so they can be automated later.

## Performance targets

- Simulate a full world matchday (all leagues) in under 2 seconds on an ordinary machine; this is what decides whether GDScript is enough or C# is needed.
- 2D viewer at 60 fps with 14 players, 4 balls and the crowd.
- Load a saved game in under 3 seconds.
