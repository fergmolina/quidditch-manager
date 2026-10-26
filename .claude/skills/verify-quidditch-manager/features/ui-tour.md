# UI tour

The UI tour is the game's own robot player: it visits every screen at four points of a season (start, preseason,
mid-season, season end), screenshots each one and reports untranslated keys, unreplaced placeholders, screens
wider than the window, tables hiding rows, clipped headers and screens that fail to open. It is the broadest
single check that a UI change broke nothing elsewhere.

## Sub-features

- `tour-selftest` a planted fake screen yields exactly four findings, so an empty report can be trusted.
- `tour-all` every screen in the side menu plus a player profile, a rival's profile and compare, at four phases.
- `tour-language` the same tour in another language (German is the widest, Japanese and Chinese test CJK fonts).
- `tour-subset` only the screens named in `TOUR_ONLY`.

## How to get to it (user POV)

- Not a user feature: it is the developer's walk through every screen a user can open, in the user's build.

## Driving it with qm-verify

Preconditions:

- A run with an empty HOME, `qm-verify doctor` passes.
- A one-screen subset takes about 2 minutes (the season is simulated in seconds, the screenshots take the time). The full tour, with 21 screens per phase, takes longer in proportion.

- **Subset tour (quick).** Run `TOUR_ONLY=squad,lineup,table qm-verify tour ui-tour --lang en --autostart club_puddlemere_united`. `tour.result` says `PASS`, `tour/report.txt` starts with `UI tour — language en — N findings (M controls checked)` followed by the self-test line `selftest: 4 of 4 planted problems detected`, and `tour/` holds `start_squad.png`, `preseason_squad.png`, `season_squad.png`, `season_end_squad.png`, the same for lineup and table, plus `<phase>_player_own.png`, `<phase>_player_other.png`, `<phase>_compare.png` and, once a match has been played, `<phase>_post_match.png` (19 files for the squad-only run).
- **Full tour.** Run `qm-verify tour ui-tour --lang en --autostart club_puddlemere_united`. About 100 screenshots and the report.
- **German.** Run `qm-verify tour ui-tour-de --lang de --autostart club_puddlemere_united`. The report's findings (if any) name the screen and the control. Overflow in German is the usual finding.
- **Proof.** `tour.result` (`PASS` means the tour completed and wrote the report, it says nothing about findings), `tour/report.txt` (the findings, zero is the goal, every line is a defect to triage), and the screenshots. Then `qm-verify cleanup`.

## Gotchas

- A `PASS` verdict means the tour finished, not that it found nothing: read `report.txt`. The self-test line counts
  as one finding, so a clean run reads `1 findings` with only the `selftest: 4 of 4` line below. Anything else is a
  defect. A folder name ending in `_selftest` runs only the self-test.
- The tour plays a season with the assistant. It does not save, so `qm-verify saves` finds nothing afterwards.
- Screens hidden for the current mode (market, finances for a house coach) are skipped by the menu but still
  visited by the tour: a house career makes those screens report as failing to open or as empty. Tour a club.
- The tour quits by itself and exits 0.
