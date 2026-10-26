---
name: formal-match-day
description: "Model-check the match-day stepper of Quidditch Manager (src/game/game_engine.gd: begin_day, step_day, the resume of an open day, complete_pending_match_begin) with TLA+/TLC: every fixture of a day is played exactly once and the day closes exactly once, whatever the player, a reload or a job change do in between. Use before and after changing those functions, GameSession.load_game, or where the UI calls accept_job, resign or accept_national_job."
---

# Formal check of the match day

**Property, in one sentence.** Every fixture scheduled on a day gets its result exactly once before the calendar
moves to the next day, and the end-of-day work (wages, board, contracts) runs exactly once per day, in every
order in which the player's actions, a reload and a job change can interleave with the engine's steps.

**Harm if it breaks.** A fixture that is never played leaves a hole in a league table and a round that never
completes. A fixture played twice overwrites a result and double-counts points, gate money and injuries. A day
closed twice pays wages twice, and a day never closed skips them. The tests play through seasons on the happy
path and through reload cases (`tests/run_tests.gd`, `test_open_day_survives_reload_and_job_change`,
`test_lineup_day_closes_after_resign_and_reload` and `test_job_change_with_match_pending`). They do not enumerate the
interleavings.

**Tool.** TLA+ with the TLC model checker, over a small model of the stepper (`MatchDay.tla`, instantiated by
`MC.tla`). The question is about the order of events (steps, a reload, a job change), and a model checker
enumerates every order. GDScript has no verifier that runs on the code itself. TLC needs Java 17 or newer
(`brew install openjdk@17`; the runner finds the Homebrew keg by itself). The runner downloads `tla2tools.jar`
1.8.0 once into `.verify/tla/` and checks its SHA-256. A run takes a few seconds.

## Run it

```sh
.claude/skills/formal-match-day/run-tlc                               # no argument: no-job-change-on-open-day, then default
.claude/skills/formal-match-day/run-tlc default                       # the code as it is
.claude/skills/formal-match-day/run-tlc bug-no-resume                 # a broken variant: must FAIL
```

| Config (`cfgs/*.cfg`) | What it models | Expected |
|---|---|---|
| `default` | The code as it is. | PASS (2844 distinct states). Run this one after a change. A FAIL here is new. |
| `no-job-change-on-open-day` | The code, with job changes excluded while a match day is open. A subset of `default`, kept as the base of the first three bug configs. | PASS (1296 distinct states). |
| `bug-drop-half-day` | `begin_day` without its guard that finishes a half-stepped day first. | FAIL `PastDaysClosed`. |
| `bug-no-resume` | `begin_day` without the resume branch for an open day. | FAIL `PastDaysClosed`. |
| `bug-no-second-human-fixture` | `complete_pending_match_begin` queuing the close instead of the resume of the day, so nothing looks for the human's other fixture that day. | FAIL `ClosedMeansPlayed`. |
| `bug-keep-foreign-pending` | `accept_job`, `resign` and `accept_national_job` without `_release_foreign_pending_match`. | FAIL `PendingIsHuman`. |

The four `bug-*` configs show that the check can fail. Each flips one constant that removes one guard of the
code from the model. The first three exclude job changes on an open day, so the removed guard alone causes their
failure. The fourth needs a job change with a match pending, so it starts from `default`. The first three were
proven against the real code on 2026-10-24. With the search for the human's second fixture
deleted from `complete_pending_match_begin` in a scratch copy of the repo, the full test suite still passed
(1313 checks, 19 minutes), while mirroring that deletion as `bug-no-second-human-fixture` made TLC fail
`ClosedMeansPlayed` in seconds. Since 2026-10-25 that search is the resume's `_after_resume`, and the constant
removes the resume. The model catches a change to a covered function only if you mirror the change
in the model.

Exit code 0 means every invariant holds. Otherwise the exit code is TLC's own. The log in `.verify/tla/runs/`
holds the counterexample as the shortest sequence of states. Read every result with the pstack statechart skill
(`/pstack:statechart`; agents read its `SKILL.md` from the installed plugin). It shows each violation as a path
in plain words and, on a pass, draws the state chart.

## Reading a counterexample in the code's words

State variables map to the code like this:

| Model | Code |
|---|---|
| `today`, `played[f]`, `closed[d]` | `w.today`; how many times `apply_result` ran for the fixture (`f["played"]` is a bool); how many times `_queue_end_of_day` ran for the day |
| `steps` | the engine's queue `_steps` from `_step_i` on (`kind`: open, daily, matches, fixture, matches:done, resume, matches:resume, close) |
| `pending`, `humanFx` | `pending_match["fixture"]`, `_human_fixture` (volatile: a reload drops them) |
| `\E f \in FxOn(today) : Unplayed(f)` | the day is open: some competition's `fixtures_on(w.today)` is not empty (read from the world, so it survives a reload) |
| `club`, `nt` | `w.player_club_id`, `w.manager["national_team_id"]` (`None` = none) |
| `result` | `_day_result["reason"]` |

Actions map to code:

| Action | Code |
|---|---|
| `BeginDay` | `game_engine.gd` `begin_day` |
| `Step` (`StepOpen`, `StepDaily`, `StepMatches`, `StepFixture`, `StepFixtureResume`, `StepAfterMatches`, `StepResume`, `StepAfterResume`, `StepClose`) | `step_day` running `_open_day`, `_queue_daily`/`_events_step`/`_market_step`, `_queue_matches`, `_match_step` (resume false / true), `_after_matches` (with `lineup_blocked` as a free choice), `_queue_resume_open_day`, `_after_resume` (and `_open_human_fixture`), `_queue_close_day` + `_queue_end_of_day` + `_close_day_result` |
| `CompleteMatch` | `complete_pending_match_begin` (also `complete_pending_match`, and `complete_pending_match_slice`, which `main.gd finish_match_stepped` calls until the day is done), which queues the resume of the day |
| `Reload` | `game_session.gd load_game` creating a new `GameEngine`, also with a match pending (the save does not keep it) |
| `ChangeClub`, `ChangeNT` | `accept_job`, `resign`, `accept_national_job`, as called from `manager_screen.gd` and from the inbox (`inbox_screen.gd` -> `Inbox.choose` -> `GameEngine.answer_owl`), each ending in `_release_foreign_pending_match` (`PendingAfterJobChange`). `answer_owl` and `manager_screen.gd _confirm_resign` refuse them while `match_awaits_finish` (a pending match past its final whistle), which the model does not tell apart from a pending match before kickoff, so the model allows more job changes than the code |

A modeling error looks like an action doing something the named function does not do. A real bug looks like a
sequence of user actions you can replay in the game. When in doubt, replay it. `probe-known-finding.gd` shows how
to script the engine headlessly for that.

## Fixed finding: a job change on an open day, then a reload

Until 2026-10-25 `default` failed `PastDaysClosed` on this path, in the game's terms:

1. The player presses Continue on a match day of the manager's club. The lineup is invalid (an injured starter),
   so the advance stops with reason `lineup`. The engine has played today's other matches and held back the
   club's fixture, and nothing is pending. The player is free to use the office screens.
2. The player resigns (`manager_screen.gd` calls `resign`) or accepts a job offer from the inbox (`accept_job`).
   The held-back fixture no longer belongs to the human.
3. The player saves (`main.gd _match_locked` only blocks saving while the match screen is live) and later loads
   the save. The new engine had lost the engine-only flag `_day_open`.
4. The player presses Continue. `begin_day` looked for an open human fixture. The old club's fixture was not
   human any more, so `begin_day` opened the next day. The old club's fixture was never played, and the end of
   that day (`_queue_end_of_day`) never ran. In a knockout competition `Competition.advance_bracket` then waits
   forever for that fixture, so the cup never gets a champion.

The fix reads the open day from the world. `begin_day` resumes while any competition's `fixtures_on(w.today)` is
not empty, and `_day_open` is gone. This is sound because a day closes only once every fixture dated on it has a
result. Every path that creates or moves a fixture runs before the matches step or dates it after today
(`_calendar_events`, `_book_events`, `_create_friendlies`, `advance_bracket`, replays), and every `_finish_day`
runs after the day's fixture steps. A run of 760 days from seed 7 as a club manager, a club and national team
manager, and a Hogwarts house found no closed day with an unplayed fixture of that day or earlier.

`probe-known-finding.gd` replays the path on the real engine with seed 7, Puddlemere United and the keeper injured
so that the 12 August 1993 friendly blocks the lineup. It runs a resignation and a job change, each with a save
and reload, plus a no-reload control. It exits with code 0 while the fix holds and 1 if a reload scenario skips
the fixture again. `test_lineup_day_closes_after_resign_and_reload` covers the resignation through
`GameSession.load_game`.

```sh
HOME=/tmp/qm-probe godot --headless --path . -s .claude/skills/formal-match-day/probe-known-finding.gd
```

## Fixed finding: a job change with a match pending

Until 2026-10-25 the model allowed a reload and a job change only with no match pending, but the UI allows both.
`main.gd _match_locked` blocks saving and leaving the match screen only while it runs a live match. A match is
pending without that lock before kickoff (the pre-match press screen, or any screen the player goes to from it),
after the final whistle until the player presses Finish, and in the autosave of `Game.after_advance` when the
advance stops for a match. With `Reload`, `ChangeClub` and `ChangeNT` enabled there, `default` failed
`ClosedMeansPlayed` on this path, in the game's terms:

1. The manager coaches a club and a national team, and both play on the same day. The player presses Continue.
   The engine plays the day's AI matches, holds back both of the manager's fixtures and leaves the club match
   pending (reason `match`).
2. Before kickoff, the player accepts an offer from another national team that does not play that day
   (`accept_national_job`). The old national team's fixture is now an AI fixture, still unplayed.
3. The player plays the club match. `complete_pending_match_begin` looked only for another human fixture of the
   day, found none, and closed the day with the national fixture unplayed.
4. The next Continue found that fixture unplayed, resumed the day, let the AI play it and closed the day a second
   time, so the weekly and monthly work ran twice.

The fix makes `complete_pending_match_begin` queue the resume of an open day (`_queue_resume_open_day`) instead of
its own search and the close. That resume plays any fixture of today that has become an AI one, then leaves the
manager's next fixture of the day pending or queues the close. `begin_close_day` and the uncalled `_end_of_day`
are gone.

On the same widened model a club change or a resignation with a match pending lost nothing, but the player then
played the old club's match. That follows the decision taken for the lineup-blocked case, where the AI plays the
held-back fixture after a job change. `_release_foreign_pending_match` now drops a pending match when neither team
is the manager's, and the resume lets the AI play it. The invariant `PendingIsHuman` checks this, and
`bug-keep-foreign-pending` shows it can fail.

A save and reload with a match pending was already sound. The save does not keep `pending_match`, and the resume
of the open day rebuilds the same match from the world, with the same seed (`match_seed`). A match watched to the
final whistle and saved before Finish is played again from kickoff after the reload. A job change in that window
is refused since 2026-10-26: accepting a club or national job from the inbox and resigning from the manager screen
show the toast `ui.match.finish_first` while `GameEngine.match_awaits_finish()` holds, so the watched result is
recorded at Finish.

`probe-pending-match.gd` replays seven scenarios on the real engine with seed 7 and Puddlemere United. They cover
a reload before kickoff and after the final whistle, a club change, a resignation, and on a club and national-team
day a reload, a national-team change and a club change. A World Cup fixture is moved onto the club's match day.
Since 2026-10-26 club competitions schedule no match while called-up squads are away
(`WorldGenerator.national_window`), so the generated calendars have no such day. The engine does not forbid one,
so the model and the probe keep the case. Before the fix, four scenarios failed. In
three of them the human played a match of a team they had left, and in one the day closed twice. After the fix none
fail. `test_job_change_with_match_pending` covers the national-team change and the club change.

```sh
HOME=/tmp/qm-probe godot --headless --path . -s .claude/skills/formal-match-day/probe-pending-match.gd
```

## Scope and bounds

The check verifies the model in `MC.tla`. It has 2 days, 4 clubs, 2 national teams and 5 fixtures. Day 1 holds
the human's club match, another club match and the national teams' match, with the human coaching one of the
national teams, so two human fixtures fall on one day. Day 2 holds two club matches. The human can resign, take
any club or any national team, reload between actions, and have the lineup block or not at each check. TLC
explores every interleaving of these. The invariants are `NoDoublePlay`, `NoFuturePlay`, `ClosedOnce`,
`PastDaysClosed`, `PastFixturesPlayed`, `ClosedMeansPlayed`, `PendingIsToday`, `PendingIsHuman` and `TypeOK`. `MatchDay.tla`
explains each one.

The check does not cover what the daily, weekly and monthly steps do (only that they run once), the match
simulation itself, sackings and hirings that the AI does inside the day (`_sack_human`, `_national_review`), the
autosave's content, the browser build's single-tab and save-confirmation logic, more than two human fixtures on
one day, or the holiday loop (`main.gd _go_on_holiday`, which calls the same engine functions). A pass covers the
model and these bounds, not the whole game.

## When a change touches the verified code

The check covers these functions. If a change touches one of them, mirror the change in the matching action,
run every config, and update this record.

| File | Functions | Model |
|---|---|---|
| `src/game/game_engine.gd` | `begin_day`, `step_day`, `_finish_day`, `_open_day`, `_queue_matches`, `_queue_comp_matches`, `_match_step`, `_after_matches`, `_queue_close_day`, `_queue_end_of_day`, `_close_day_result`, `_queue_resume_open_day`, `_after_resume`, `_open_human_fixture`, `_is_club_fixture`, `_is_human`, `lineup_blocked` (as a free choice), `complete_pending_match_begin`, `complete_pending_match_slice`, `_release_foreign_pending_match`, `accept_job`, `resign`, `accept_national_job`, `match_awaits_finish` and `answer_owl` (their refusal) | `MatchDay.tla` |
| `src/game/game_session.gd` | `load_game` (a new engine; what the save keeps), `after_advance` (the autosave with a match pending) | `Reload` |
| `src/ui/main.gd` | `_continue`, `_advance_day_stepped`, `finish_match_stepped`, `_match_locked`, `save_and_confirm` (when saving and job changes are allowed) | the enabling conditions of `Reload`, `ChangeClub`, `ChangeNT` |
| `src/ui/screens/manager_screen.gd` | `_confirm_resign` (refused while `match_awaits_finish`) | the enabling condition of `ChangeClub` |

Sync record. The verification describes these files as of 2026-10-26, after the slice entry point
`complete_pending_match_slice` and the refusal of job changes after the final whistle, and before the repository's
first commit. The git blob hashes at that point (`git hash-object <file>`) are
`a9a7f5c78c149505220ec905dd22093baa3438dc` for `game_engine.gd`, `2ef3227f160dd05bb016806d421b098447cfc1e6` for
`game_session.gd` and `358cb8ec1315da057345e6c126c590bae6e0a1ab` for `main.gd`. Once the repository has commits, replace this line
with the commit hash. Move the record forward only after confirming that every action still describes the code
at the new state. The bug configs must still fail and `default` and `no-job-change-on-open-day` must still pass.

To change the model, edit `MatchDay.tla` (the code's structure) or `MC.tla` (the concrete instance), keep the
comments pointing at functions, and re-run every config. A new guard in the code deserves a new `BUG_*` constant,
so that its absence can be shown to fail. Use `/pstack:maintain-formal-verification-skill` to bring the
verification back in line after changes that did not re-check it.
