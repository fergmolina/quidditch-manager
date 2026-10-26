---
name: verify-quidditch-manager
description: "Drive the Quidditch Manager desktop game (Godot 4.7, GDScript) the way a player does and capture proof: launch into a career, open a screen, play a match, save, or run the UI tour, with every run in its own isolated user data directory. Use when a change to src/ (screens, match engine, saves, world) must be shown working in the real app, not only in tests/run_tests.gd."
---

# Verify Quidditch Manager

The game is a Godot 4.7 desktop app. Its UI is built in code (`src/ui/main.gd` and `src/ui/screens/*.gd`), and
`src/ui/main.tscn` is the only scene. The game ships its own command-line driver in `main.gd:_handle_cmdline`.
User args after `--` start a career, advance the calendar, open a screen, finish a match and save a screenshot.
The UI tour (`src/ui/ui_tour.gd`) walks every screen and audits it. This skill wraps both with `qm-verify`, the
script next to this file, so that every run is isolated and leaves evidence. Read `features/README.md`, then the
feature file that matches what you are proving.

This skill does not cover the browser build (the same GDScript exported for the web, whose accounts API in
`server/` has its own Node test suite) or the headless tools in `tools/` (`sim_world.gd`, `stress_test.gd`,
`audit_world.gd`). Those tools prove engine behaviour without the UI, and `CONTRIBUTING.md` documents them.

## Launch

You need Godot 4.7.x on `PATH` as `godot` (Homebrew installs it at `/opt/homebrew/bin/godot`; `QM_GODOT` points
at another binary) and a logged-in desktop session, because the screenshots come from the window's framebuffer
and a headless run renders a blank image. From a fresh clone, import once. The import also compiles
`locale/strings.csv` into the `.translation` files.

```sh
godot --headless --path . --import
```

There is no server to keep alive. Each `drive` is one short launch, about 10 s for a screen and 30 to 90 s for a
match day, and it quits on its own after writing the screenshot. Start a run first. Every launch in the run shares
one empty, isolated HOME, so the next launch sees the saves that an earlier one wrote.

```sh
.claude/skills/verify-quidditch-manager/qm-verify start      # prints the run id, also kept in .verify/current
```

A launch is ready when it has printed `screenshot saved to <path>` and the PNG is larger than 50 KB.
`qm-verify drive` checks both and writes the verdict. For isolation, the script sets `HOME` to
`.verify/runs/<run>/home`, which moves Godot's `user://` (on macOS `Library/Application Support/Godot/app_userdata/Quidditch Manager`,
on Linux `.local/share/godot/...`), so the game never reads or writes the developer's own saves and settings.
With a fresh HOME the game falls back to Spanish, so pass `--lang en` for English evidence.

## Doctor

```sh
.claude/skills/verify-quidditch-manager/qm-verify doctor
```

The doctor is read-only. It checks that `godot` resolves and reports 4.7.x (project.godot requires feature
`4.7`), that `project.godot` is found, that the project is imported (`.godot/imported/` and
`locale/strings.en.translation` exist), that a display is available (`WindowServer` on macOS, `DISPLAY` on
Linux), and, for the current run, that its HOME exists and no godot process started by the run is still alive.
Run it first whenever anything looks off, and before cleanup.

## Drive

```sh
qm-verify drive <feature> <label> -- <game args...>
```

`<feature>` names the evidence folder (use the feature file's name) and `<label>` names the step. The game args
are the driver's own flags. One launch applies them in this order:

| Flag | Effect |
|---|---|
| `--lang en` | UI language for this launch (not saved). |
| `--autostart <club_id>` | Starts a career with that club (`club_puddlemere_united`, `club_holyhead_harpies`, any id in `data/`; a Hogwarts house is `hs_<school>_<house>`), manager "Manager", seed 7 (`--seed N` changes it). |
| `--load <slot>` | Loads the save in that slot of the run's HOME on a thread behind the loading overlay, the title screen's path (`main.run_blocking` + `Game.load_game`), then opens the inbox. A missing or unreadable slot prints `--load: no loadable save in slot <slot>` and exits 1. |
| `--advance N` | Advances up to N days with the assistant fixing the lineup; stops at the first match of the manager's. Add `--play-match` to have the AI play through them instead. |
| `--nt <nt_id>` | Accepts a national team job. |
| `--screen <id>` | Opens a screen: `inbox news squad lineup training table calendar competitions players national_teams market scouting schools finances staff board manager club history encyclopedia settings saves new_game title`. Params: `--player <id>`, `--a <id> --b <id>` (compare), `--competition <id>`, `--club <id>`, `--school <id>`, `--tab N` (read by the player, calendar and encyclopedia screens only). |
| `--finish` | Plays the pending match to the end and opens `post_match`. |
| `--press` | Opens the press conference of the last match. |
| `--main-call <method>` | Calls a no-argument method of `main.gd` (for example `_quick_save`, the Ctrl+S handler). |
| `--call <method>` | Calls a no-argument method of the open screen (for example `_save` on the saves screen). |
| `--scroll N` | Scrolls the screen's ScrollContainers. |
| `--shot <path>` | Screenshot after `--wait F` frames (default 4), then quit. `drive` adds it when missing. |

Use screen ids and entity ids. Nothing here clicks by position. Each feature's Gotchas record what the flags
cannot do (type into a field, select a list row, drag a player). Never fake those steps.

The UI tour visits every screen at four points of a season and reports untranslated keys, placeholders, overflow
and screens that fail to open:

```sh
qm-verify tour <feature> --lang en --autostart club_puddlemere_united
TOUR_ONLY=squad,market qm-verify tour <feature> --lang en --autostart club_puddlemere_united   # a few screens
```

## Evidence

Everything goes to `.verify/runs/<run>/<feature>/`, which git ignores:

- `<label>.png` is the screen at 1366x820, with the club name, date and balance in the top bar as the app's identity.
- `<label>.log` is Godot's stdout and stderr for the launch. The verdict counts its `SCRIPT ERROR` lines.
- `<label>.result` holds the verdict (`PASS`, `FAIL` or `TIMEOUT`), the exact args, the exit code, the PNG size and the error count.
- `tour/report.txt` and `tour/<phase>_<screen>.png` come from a tour, and `tour.result` holds its verdict.
- `save-<slot>.meta.json` is the copy that `qm-verify saves <feature>` makes of a save's metadata, read from disk.

Exercise the user path (a screen the player opens, a match the player's club plays, a save through
`main.save_and_confirm`), not test-only hooks. `--autostart` stands in for the New game screen, and the feature
file says so. Capture the action and the resulting state. That means the screenshot after the action plus the
side effect (a save folder with `meta.json` and `world.json.gz`, a changed date in the top bar, a result on the
post-match screen), and a second, read-only view of the side effect (`qm-verify saves`, or a second launch on the
same run that shows the saves screen). There are no mocks. The app runs its real engine on its real data.

## Cleanup

```sh
qm-verify cleanup
```

Cleanup kills only the godot processes whose pids this run recorded, never by name. It deletes the run's HOME
(settings, saves, shader cache) and keeps every file under `.verify/runs/<run>/<feature>/`. Run it after every
attempt, failed ones included. This skill never deletes evidence. Prune `.verify/runs/` by hand when it grows.

## Helpers

`qm-verify` is an executable bash script with the subcommands `start`, `doctor`, `drive`, `tour`, `saves`,
`cleanup`, `runs` and `help`. It finds the project root from its own location, sets HOME per run, launches
`godot --path . --windowed --resolution 1366x820 -- <args>` under a per-launch timeout (`QM_TIMEOUT`, default
300 s, and the kill reaches only that process) and writes the verdict files. Set `QM_RUN=<id>` to address a run
other than `.verify/current`.

## Gotchas for every feature

- Every launch is muted (`--audio-driver Dummy`), so runs make no sound on the developer's machine. Audio code
  still runs; only the output device is a dummy.
- A drive passes only when it printed `screenshot saved to`, the PNG is larger than 50 KB, the log has no
  `SCRIPT ERROR` line and the exit code is 0. The tour passes only on `tour finished`, a report, no `SCRIPT ERROR`
  and exit 0. A screenshot alone is not proof: on 2026-10-25 a blank match screen passed for a whole round because
  the verdict looked only at the PNG.
- `--finish`, `--press` and `--main-call` navigate after `--screen`, so a launch yields one screenshot. Plan one
  launch per state you need to show.
- The first frames can produce a blank image (see CONTRIBUTING.md). `drive` fails a PNG under 50 KB. Rerun the
  step with `--wait 8`.
- Do not edit `qm-verify` while one of its launches is running. Bash reads the script as it goes and fails at the
  dispatch with a syntax error after the launch. The verdict file is already written by then.
- Running the suite `godot --headless --path . -s tests/run_tests.gd` at the same time is safe, since both only
  read the sources, but it slows the launches.

## Maintaining the map

The feature files under `features/` are the maintained verification source. When a screen or flag changes, update
the matching file. Use `/pstack:maintain-verification-skill` to re-walk the map against the app.
