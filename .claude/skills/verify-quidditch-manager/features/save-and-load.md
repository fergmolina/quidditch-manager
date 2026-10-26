# Save and load

The manager saves with Ctrl+S (Cmd+S on a Mac) or from the saves screen, where the current slot is named after the
club. Saves are folders under the game's user data directory with a `meta.json` and a compressed world. The saves
screen and the title screen list them and load one back.

## Sub-features

- `save-quick` Ctrl+S saves to the career's slot and shows the `Game saved.` toast.
- `save-screen` the saves screen saves under the typed name and lists existing saves.
- `save-files` a save is `saves/<slot>/meta.json` plus `saves/<slot>/world.json.gz` in user data.
- `save-list` the saves screen and the title screen list the save with club, date and time.
- `save-load` loading a save restores the career (`--load <slot>`, the title screen's threaded load).
- `save-export` export and import a `.qmsave` file (not driveable from the command line).

## How to get to it (user POV)

- Ctrl+S / Cmd+S anywhere during a career. The floppy icon in the top bar.
- Side menu: the saves screen (`Saves` from the top bar's save icon or the title screen's Load).
- Title screen: `Continue` with the newest save, `Load` to pick one.

## Driving it with qm-verify

Preconditions:

- A run with an empty HOME (`qm-verify start`): no saves exist, so `qm-verify saves` reports none.
- The reference career. Its slot is derived from the club's short name (`puddlemere` for Puddlemere United).

- **Save from the saves screen.** Run `qm-verify drive save-and-load saves-screen -- --lang en --autostart club_puddlemere_united --screen saves --call _save`. The saves screen shows the slot name in the field, the message `Game saved.` and the save listed with `Puddlemere United`, the date and the time.
- **Files on disk.** Run `qm-verify saves save-and-load`. It lists one folder (the slot), `world.json.gz` with a size in the megabytes and `meta.json` with `"club_id":"club_puddlemere_united"`, `"today":"1993-08-01"` and the manager `Manager`. The meta is copied into the evidence folder.
- **Quick save (Ctrl+S handler).** Run `qm-verify drive save-and-load quick-save -- --lang en --autostart club_puddlemere_united --advance 5 --main-call _quick_save --screen saves`. The saves screen lists the save. `qm-verify saves save-and-load` now shows `saved_at` later than before and, because `--autostart` created a second career in the same run, a second slot (`puddlemere_2`) rather than an overwrite.
- **Second, read-only view.** Launch with no career: run `qm-verify drive save-and-load title-after-save -- --lang en --screen title`. The title screen now offers Continue with the newest save and its club, date and saved time.
- **Load a save (threaded).** After the quick save, run `qm-verify drive save-and-load load-threaded -- --lang en --load puddlemere_2 --screen inbox`. The launch loads the slot on a thread behind the loading overlay, as the title screen's Continue and Load do. The inbox shows Puddlemere United with the saved date in the top bar (`today` in `save-puddlemere_2.meta.json`, 6 August 1993 after `--advance 5`) and the career's owls. A slot that does not exist fails the drive with exit code 1 and the line `--load: no loadable save in slot <slot>` in the log.
- **Proof.** `saves-screen.png` (action and confirmation), the `save-<slot>.meta.json` copies and the `qm-verify saves` output (side effect on disk), `title-after-save.png` (independent second view), `load-threaded.png` (the career restored from disk). Then `qm-verify cleanup`.

## Gotchas

- `--call _save` runs the saves screen's Save button handler with the slot name that the screen pre-fills. Typing
  another name is not driveable. `--main-call _quick_save` is the Ctrl+S handler without the key press: say so.
- Loading from the saves screen needs a selected row (`saves_screen._load` returns when nothing is selected), which
  the flags cannot do. `--load <slot>` runs the same threaded load as the title screen's Continue and Load buttons,
  without the click: say so. `--load` runs before `--advance`, `--screen` and the other flags, and replaces
  `--autostart` when both are given.
- Every `--autostart` in the same run is a new career with a new career id. The slot picker never overwrites
  another career's save, so expect `puddlemere`, `puddlemere_2`, ... across launches. An autosave slot is named
  `autosave_1/2` and appears after a match of the manager's.
- Saving during a match is refused (`Save after the match`) by design. `--finish` first.
- On desktop the save is confirmed at once. The browser's `Saving...` then `Game saved.` sequence does not occur here.
