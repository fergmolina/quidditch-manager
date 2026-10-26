# Play a match

Continue advances the calendar until the manager's next match. The match plays as text commentary or on the 2D
pitch. The post-match screen shows the score, ratings, key moments and the team talk. The press conference follows.

## Sub-features

- `match-advance` Continue advances day by day and stops on the manager's match day with the match pending.
- `match-screen` the match screen shows the two teams, the clock, the score and the commentary or the 2D pitch.
- `match-finish` the match ends by Snitch catch (or the competition's time cap) and the result is recorded.
- `match-post` the post-match screen shows the score, ratings, key moments, board reaction and the team talk.
- `match-press` the press conference after the match.
- `match-table` the league table reflects the result.

## How to get to it (user POV)

- `Continue` (Space) from any screen until the match day. The match screen opens by itself.
- On the match screen, the play, speed and live-tactics controls, and `Finish` when it is over, which opens the post-match screen.
- `Back to the office` from the post-match screen. The press conference is offered after league matches.

## Driving it with qm-verify

Preconditions:

- A run with an empty HOME, `qm-verify doctor` passes.
- The reference career: its first fixture is the pre-season friendly against Falmouth Falcons on 12 August 1993
  (seed 7), then the league starts on 11 September 1993.

- **Advance to match day.** Run `qm-verify drive play-a-match match-day -- --lang en --autostart club_puddlemere_united --advance 60 --screen match`. The advance stops on the first match (`Thu 12 August 1993` in the top bar, the Continue button reads `Match in progress`) and the match screen shows Puddlemere United against Falmouth Falcons at `0 - 0`, `00m 00s`, the 2D pitch with the crowd, the pre-match talk buttons, both sevens with condition, and the `Play`, `Next moment`, `Call a time-out` and `Simulate to the end` controls.
- **Finish the match.** Run `qm-verify drive play-a-match post-match -- --lang en --autostart club_puddlemere_united --advance 60 --finish`. The post-match screen shows the final score (250 to 160 for seed 7), the ratings table, key moments and the four team-talk buttons. The top bar date is the match day.
- **Press conference.** Run `qm-verify drive play-a-match press -- --lang en --autostart club_puddlemere_united --advance 60 --finish --press`. The press screen shows `Question 1 of 3` naming the score and Falmouth Falcons, four answers and `Let your assistant manager answer`.
- **League matches and the table.** Let the assistant play through two months. Run `qm-verify drive play-a-match league-table -- --lang en --autostart club_puddlemere_united --advance 60 --play-match --screen table`. The top bar reads `Thu 30 September 1993`, the Continue button reads `Play vs Magpies` (next fixture 2 October) and the British and Irish Quidditch League table shows Puddlemere United with `P 2`, two league rounds played and points accumulated. The friendly is not counted.
- **Proof.** `post-match.png` (score, ratings, key moments) plus `match-day.png` (0 to 0 before) prove the action and the result. `press.png` the follow-up. `league-table.png` the side effect on the standings. Then `qm-verify cleanup`.

## Gotchas

- `--advance` stops at the manager's first match (reason "match"). `--finish` then plays it to the end with the
  engine (`complete_pending_match`), the same code the Finish button runs after the viewer, so the viewer's
  animation itself is not exercised. The 2D viewer can be filmed with `--view pitch2d --film N --gap F` (see
  `main.gd:_handle_cmdline`). Its output is a series of PNGs, not a verdict.
- Each launch replays from day one: seed 7 makes every launch deterministic, so `match-day` and `post-match` show
  the same fixture. A different seed (`--seed`) changes the fixture list and the scores.
- Flag order inside a launch is fixed: `--advance`, then `--screen`, then `--finish`, `--press`, `--main-call`,
  `--advance2`, `--call`, `--shot`. So `--screen table --finish` ends on the post-match screen, not the table. To
  show a screen after matches were played, use `--advance N --play-match --screen <id>` (the AI plays the
  manager's matches too) in its own launch.
- An urgent owl (job offer, ultimatum) stops the advance before a match. `--advance` marks urgent owls resolved, so
  it does not happen in the reference career's first weeks.
- `--press` opens the press conference of the last match (`Question 1 of 3`, the score in the question). It works
  after the pre-season friendly too. Answering a question is a click: not driveable, the screenshot proves the
  conference opens with the right match.
