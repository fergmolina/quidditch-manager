# Quidditch Manager verification map

This directory is the maintained source for verifying the user-facing behaviour of Quidditch Manager (the Godot
desktop build). Read this index before driving the app, then use the matching feature file as the recipe.

## Baseline preconditions

- `qm-verify doctor` passes (Godot 4.7.x, project imported, a display, no stale godot from the run).
- A run exists (`qm-verify start`) and its HOME is empty, so the game starts with no saves and default settings.
- Every launch passes `--lang en` (a fresh HOME falls back to Spanish).
- The reference career is `--autostart club_puddlemere_united` (seed 7, manager "Manager"). It plays in the
  British and Irish League with 14 players, has a pre-season friendly on 12 August 1993 and its first league
  match on 11 September 1993.
- Never drive the developer's real installation (no `godot --path .` without `qm-verify`). Their saves live in
  the real HOME.

## Driving conventions

- One launch per screenshot, because `--finish`, `--press` and `--main-call` navigate after `--screen`.
- Use entity ids (`club_*`, `comp_*`, player ids from `data/`). The driver cannot click by position.
- Treat every command as literal. Keep ids, flags and quoted names unchanged.
- Chain launches in one run when a step needs the state of a previous one (a save, then the screen that lists it).
- Run `qm-verify cleanup` after the feature, failed attempts included. Never delete `.verify/runs/<run>/<feature>/`.

## Proof and skip reporting

- Capture the action and the resulting state, which means the screenshot after the action and the side effect on
  disk or on a second screen. The final screen alone is not proof.
- Every screenshot shows the app's identity (club name, date and balance in the top bar).
- `qm-verify saves <feature>` proves a save (folder, `meta.json` and `world.json.gz` read from the isolated HOME),
  and a later launch proves it again by showing it on the saves screen.
- Record the feature file, the label and the exact args with every artifact. `<label>.result` does this.
- Report an unreachable path with the attempted command and the unmet precondition. The Gotchas of each feature
  list what the driver cannot reach. Do not report a skipped entry point as verified through a different path.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behaviour, then exactly
four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`, `Driving it with qm-verify` and
`Gotchas`. The driving section starts with `Preconditions:` and continues with labeled bullets that pair each user
action with an exact command and the observable result.

## Features

- [Start a career](./start-a-career.md) covers the title and New game screens, a club or a Hogwarts house, and the welcome owls.
- [Squad, lineup and player](./squad-lineup-player.md) covers the squad table, the lineup and tactics, and a player's profile.
- [Play a match](./play-a-match.md) covers Continue to match day, the match, the post-match report and the press.
- [Save and load](./save-and-load.md) covers the quick save, the saves screen, the files on disk and the title screen's Continue.
- [UI tour](./ui-tour.md) covers every screen at four points of a season, audited for text, layout and errors.
