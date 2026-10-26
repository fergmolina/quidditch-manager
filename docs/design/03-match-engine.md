# 03: Match engine

## 1. Architectural pillar

The match is **simulated** in a pure, deterministic module, with no Godot nodes and no dependencies on the interface:

```
simulate(initial_state, tactics_A, tactics_B, seed, interventions) → event log
```

- **Deterministic.** The same seed, the same inputs and the same manager interventions (with their tick) give the same match. This allows replays without storing video, regression tests and debugging.
- **Headless.** It runs in the console, in tests and for the hundreds of matches each world matchday that nobody watches. **A single engine for everything** (FM uses two and the community notices balance differences). The simulator state is **abstract** (possession, zone, ball carrier, each player's condition, Snitch state). The viewer synthesizes the on-screen positions from the events and zones, so the engine runs just as fast with or without the viewer.
- **The 2D viewer is a replay of the log.** Nothing that is shown happens outside the simulation (the lesson of PC Fútbol 6.0, whose replays contradicted the result).
- The rules it applies are those of `04-match-rules.md`, with no exceptions.

## 2. Time model

- The unit is the **tick of 5 seconds of game time**. A typical 90-minute match is ~1,080 ticks; a 10-hour one, ~7,200.
- The match clock only runs while play is live; time-outs and stoppages (mediwizards, Bumphing, night) stop it and are logged as events.
- **Normal regime.** Up to 12 hours of play.
- **Long-match regime** (over 12 hours, rule 2). Time-outs of up to 2 hours, night breaks every ~16 hours of play **[minimal FILLER]** (each one restores 35 condition to every active player and interrupts any Snitch chase), and condition drain changes (×0.6 multiplier, `long_match_drain_multiplier`). Originally planned: sleep relays (see `04` §4) and 1-minute ticks for these stretches. Neither is built, and ticks stay at 5 seconds throughout.
- **Hard cap** of 48 hours of play as a safety valve for the simulator **[technical FILLER: not a rule of the sport; no calibrated match comes close]**.
- **End by mutual agreement** (rule 7). After 12 hours of play, the match ends when both teams' average condition is below 15 and the lead exceeds the Snitch's 150 points by more than another 150 (`mutual_end` in `sim_params.json`) **[FILLER: the threshold]**. The engine applies it automatically. Originally planned: the human manager would receive the proposal and accept or reject it.

## 3. Match state

For each of the 14 players: **zone** (own area / midfield / opponent's area; high / low), condition (0-100), in-match morale, injury, fouls committed, broom and its state, current tactical instructions. There are no coordinates. Proximity between players is modeled with probabilities weighted by zone, role and tactics (Hattrick style).
For the balls: Quaffle (who has it or where it is flying), two Bludgers (position, current target), Snitch (position, visibility, "evasiveness").
Score, clock, time-outs called, referee (strictness, attention), conditions (weather, light, wind) and crowd (mood, hostility).

## 4. What happens in a tick

The engine resolves **events** with probabilities derived from attributes, broom, tactics, zone and fatigue. Each event carries the zones of those involved; the viewer (Milestone 1) synthesizes plausible positions by interpolating between events, so that what is drawn is still exactly what the log says.

Per tick, in this order:

1. **Bludgers.** Each Bludger picks a target (the nearest player, unless a Beater has directed it) and moves. If it reaches a player, that player makes a **dodge** roll (Agility, Reflexes, broom) against power. On failure the impact costs condition and may cause an injury or a Quaffle drop. Beaters in range make a **beating** roll (Beating, Strength, Timing) to deflect it toward a target according to their instruction (opposing Seeker, Quaffle carrier, protect a teammate).
2. **Quaffle phase** (one possession is a sequence of ticks). The team in possession advances with passes (Passing, Vision, Teamwork vs. the opponents' Marking and Interception), according to the chosen Chaser formation (Hawkshead, Porskoff, Woollongong Shimmy, Reverse Pass as "styles"). On entering the scoring area with a single Chaser, the Chaser takes a **shot** (Shooting, Composure, Power) against the Keeper's **save** (the Keeper's Reflexes, Positioning, Agility; Starfish and Stick / Double Eight Loop as styles). A goal is worth 10 points, and the Keeper restarts play. Steals, interceptions and turnovers change possession.
3. **Fouls.** On every contact, an **aggression** roll for the player, scaled by the team instruction ("hard play") and the pressure of the moment, decides whether there is a foul, and a **referee** roll (strictness, attention, distance) decides whether it is seen. Penalties from `04` §5. A penalty is a direct shot, Chaser against Keeper.
4. **Snitch.** The Snitch moves erratically within the boundaries and has a varying **visibility**. Every tick, each Seeker makes a **sighting** roll (Eyesight, Concentration, altitude, weather). On a sighting, the Seeker enters a **chase**, a speed race (broom, Speed and Acceleration) plus maneuvering (Agility, Bravery), with the opposing Seeker marking or chasing and the opposing Beaters trying to knock the Seeker off. The catch also requires the Seeker's **conditional instruction** to be satisfied (see §6). If it is not, the Seeker deliberately lets it go or "obstructs" it (Krum 2014). The **Wronski Feint** is a Seeker action using Bravery and Deception vs. the opponent's Decisions.
5. **Condition and morale.** Everyone loses condition each tick according to intensity and Stamina. In-match morale rises with your own goals and falls with the opponent's goals and with hits.
6. **Logging.** The engine emits an event for every relevant occurrence, with its tick, its importance (goal > catch > injury > penalty > saved shot > steal > pass) and the zones of those involved.

### The Snitch curve (what decides match length)

The per-tick **sighting** probability starts low and **rises with game time** (the Snitch "tires"; in the canon the crowd feels cheated if it is caught within 5 minutes [QTTA c10], and Eunice Murray asked for a faster Snitch because it was "too easy"). Calibration targets (from the dataset in `02-quidditch.md` §3.9-3.10):

| Metric | Target | Milestone 0 result (10,000 matches, equal teams) |
|---|---|---|
| Median length, elite match | 90-120 minutes | **95 min** (p10 39, p25 60, p75 141, p90 196) |
| Matches < 40 minutes | ~10% | **10.5%** |
| Matches > 4 hours | ~5% | **4.6%** |
| Matches > 8 hours | ~0.5% (epics) | **~0.3%**; the longest 12.6 h. No multi-day matches occur (see §4.1) |
| Goals per hour | 5-35 depending on quality and fatigue (mean ~15) | **17.6** |
| Typical score | 150-350 per team | **winner 313, loser 149** on average |
| The side that catches the Snitch wins | ~85-93% (canon 2014: 14 of 15) | **97%** between equals, **83-85%** between mismatched teams |
| Fouls / penalties per match | few (2-4 penalties in the 1994 final) | **1.6 / 1.2** |
| Injuries that take a player off | ~0.3-0.6 per match | **0.58** |
| Sensitivity to strength | the better team wins more, without it being automatic | **+3 in all attributes → 77%; +5 → 87%; +10 → 92%** |
| Speed | world matchday (~80 matches) < 2 s | **50 matches/s in GDScript: ~1.6 s per matchday**; 10,000 matches in ~200 s (the 60 s criterion is not met; see §9) |

### 4.1 Calibration decisions

- The probability of sighting the Snitch grows with the square of game time (`sight_ramp_power = 2`), so short matches are rare, long ones are rare, and the median is at 95 minutes.
- Each Snitch has its own **evasiveness** per match (lognormal, `match_evasiveness_sd`), because the canon says they vary. On top of that, 1.5% are "wild Snitches" (Bodmin Moor 1884), up to 12 times more evasive, and these produce the 6-12 hour matches.
- Multi-day matches (Liechtenstein-Chad) do not occur in practice. The quadratic ramp eventually beats any Snitch, even a wild one, and the longest of 10,000 test matches lasted 12.6 h. The engine still supports them (long-match regime from 12 h, night breaks every 16 h of play, mutual agreement after 12 h, 48 h hard cap), but no further tuning toward multi-day matches has been done.
- The attribute contest raises the ratio of the two skills to `contest_sharpness = 0.4` (advances, passes and shots). A 15 player against a 10 player multiplies the base chance by 1.5^0.4 ≈ 1.18, a small edge in one duel that adds up over 30 goals. It was 0.5 (square root) until v0.10.0, when it was lowered together with the "match settled" rule (`quaffle.comfort_*`) to curb blowouts (`11`, 2026-10-05, item 9). Quaffle control uses its own, sharper `control_contest_sharpness = 1.4`.
- With no active Seekers on either team, the captains agree to end the match at 20 minutes (rule 7), the only canon way to end it. A side that is behind and left with no Chasers and no Seeker also ends the match by the captains' agreement, instead of conceding for hours (playtest 2026-10-22: scores of 1,100-1,330).
- **School matches** [game] (both sides houses, `SimTeam.is_school`). `sim_params.school` scales the Quaffle tempo (`quaffle_tempo_mult` 0.6) and the Snitch sighting chance (`snitch_sight_mult` 2.5). Canon school results average 256-72 (eight full scores in the books). The target is about 245-85, some 17 goals and Keepers with saves in the teens, against 270-350 and 72 saves before. These figures are estimated from the formulas and not yet measured with `tools/sim_batch.gd` (it has no school mode). Hogwarts results written in `events.json` bypass the simulator.

These parameters live in a data file, not in the code, and are tuned with thousands of simulated matches in tests.

## 5. Manager interventions during the match

The only things the manager can do, in line with `04` §4:

| Action | When | How it applies |
|---|---|---|
| Change tactics (mentality, Chaser formation, Beater instructions, Seeker instruction, marking, hard play) | At any time | It is queued and takes effect at the **next stoppage** (goal, foul, injury, time-out); players take a few ticks to adapt depending on Decisions and Teamwork |
| Call a **time-out** | At any time, **with no limit** (the canon sets no number) | The captain asks the referee for it; the clock stops; it allows a team talk (morale) and an immediate tactical change. A natural consequence, not a rule: **both teams** recover condition and the opponent also reorganizes its tactics, so calling one while dominating has a cost |
| Time-out talk | During the time-out | One of four tones (Calm down / I have faith in you / I expect more / This is unacceptable) that changes each player's attributes for the rest of the match depending on personality and score (FM07 style; see §10) |

The manager cannot: substitute players, talk to the referee, appeal decisions.

Originally planned: sleep relays during night breaks of long matches, and accepting, rejecting or proposing an end by mutual agreement. Neither is built, and the engine applies the mutual-agreement end automatically (§2).

**Match plans** are conditional rules ("if we are +100 → Seeker always catches"; "if we lose our Seeker → Beaters protect the Chasers") that the engine evaluates on its own. **They were not in FM 07** (they came later). They are included because they are the same mechanism the AI opponent uses to make decisions, and because the conditional Seeker instruction is already a rule of this kind. Optional for the human player.

## 6. Tactics the engine consumes

Defined in `06-tactics.md`: team sliders (mentality, tempo, passing, shooting, pressing, hard play, time wasting), Chaser style (canon formations), Beater instructions, conditional Seeker instruction, Keeper instructions, per-player instructions and opposition instructions. The engine receives them as one dictionary per team and re-evaluates them at every stoppage.

## 7. Event log

Each event: `{tick, type, importance, players, ball, zones, score, text_key, params}`. The `text_key` is a translatable key ("match.goal.long_shot") with parameters. The viewer builds its commentary from it in the player's language.

Types: kickoff, pass, intercept, steal, shot, save, goal, foul, penalty, bludger_hit, bludger_dodge, bludger_deflect, injury, send_off, snitch_sighted, snitch_chase, snitch_lost, wronski_feint, snitch_caught, timeout, team_talk, night_pause, relay, mutual_end, match_end, plus conditions (weather_change, crowd_event).

A 2-hour match produces a few hundred events (≈ 50-100 KB uncompressed). The full log is stored only for the player's own match (replay available). For the rest only the summary is stored (score, events of importance ≥ goal, stats).

Play context for the viewer (0.11.0): passes name passer and receiver, saves and misses name the Keeper, turnovers name the player who lost the ball (`other_player_id`), and every play that ends with a restart carries `params.restart` ("keeper" | "no_chasers" | "attack") and `params.restart_to`, the Chaser who gets the ball. These are data only. No RNG draw depends on them, so the log of a given seed is unchanged.

## 8. 2D viewer

- **Top-down** view of the oval, with the three hoops at each end drawn as circles in perspective and height indicated by sprite size/shadow (Quidditch is 3D; a top-down view with shadows and scale handles the vertical axis without building a 3D engine).
- Simple sprites: players as a broom and robes in the club's color, balls with distinctive marks (red Quaffle, black Bludgers, golden Snitch with a trail).
- **Viewing modes** (a design decision, since it must be possible to watch a match without 2D). The mode is set from the **View** dropdown on the match screen, can be changed at any time during the match, and is remembered for the next match (default: 2D + commentary):

| Mode | What you see | What it is for |
|---|---|---|
| **Commentary** | Text commentary in the classic Championship Manager style, event by event, with score, clock, live tactics and time-outs; no 2D | Watching the match without animation, quickly, like a Lee Jordan commentary |
| **2D + commentary** | The 2D pitch with the players' tokens, plus a strip of commentary below; the clock runs slower so the eye can follow the play; automatic (optional setting) and on-demand **Replay** of the last goal or Snitch catch | The default mode |
| **Score only** | No pitch and no commentary: the match runs at the fastest speed straight to the end, and the final score and stats are shown | Unimportant matches; going fast |

The mode changes what you see, not the simulation. Tactics and time-outs work the same in all three. Controls common to every mode: **Play**/pause, **Next moment** (skip to the next key moment), a **Speed** selector (step / slow / normal / fast) and **Simulate to the end** (plays the rest of the match at once, without animations). The **Match commentary detail** setting (minimum event importance, default 3) decides which events appear in the commentary. Originally planned: four modes (result only, text highlights, 2D highlights that skip to key moments, full 2D at ×1 to ×16).
- **Ball states (0.11.0).** The viewer does not chase the simulator's current carrier. It plays the log as a queue of actions on one visual clock, and the Quaffle is always in one of five states: *held* (glued to the carrier's hand, placed after the tokens move), *pass* (from the passer to a reception point fixed when the ball leaves the hand; the receiver flies to it), *shot* (to the hoop, the Keeper's contact point or wide), *loose* (steal, drop, rebound, the Keeper gathering) or *restart* (from the Keeper to the Chaser the log names). A flight is never cut short by a later event. When the simulator gets more than about a second ahead, the oldest actions resolve instantly instead. The possession ring follows the player who visibly holds the ball; the intended receiver gets a pale ring while a pass flies. Replays include the goal arc or the Snitch dive. "Next moment" in 2D jumps and keeps playing (text mode still pauses).
- **Time compression.** The viewer skips stretches without important events according to the level. The game clock is always shown.
- HUD: score, game clock, condition of your 7, Snitch indicator (sighted / being chased), time-out button, collapsible tactics panel and text commentary (Lee Jordan / *Daily Prophet* live).
- In long matches the viewer shows "Day 2, hour 17" and automatically summarizes the slow stretches.

## 9. Unwatched matches

The same `simulate` function, with no difference at all. Since the state is abstract, there is nothing to skip, and the result is identical to the one you would have watched. Measured in Milestone 0: 50 matches/s in GDScript with static typing and list caches, i.e. ~1.6 s per world matchday of 80 matches. Enough to play. For the mass calibration tools (10,000 matches in 200 s), migrating `src/sim/` to C# remains the option if needed.

## 10. Team talks and 2D viewer (added October 3, 2026)

- **Team talks** (`src/game/team_talk.gd`). A mechanic taken from FM 07, **not a Quidditch rule**. Given before the match and at every time-out (there is no half-time). Four tones (Calm down, I have faith in you, I expect more, This is unacceptable; effects in `06-tactics.md` §9). Each player reacts according to professionalism, temperament, pressure and determination, and to the score. The effect is ±4% on attributes for that match. Deterministic (its own RNG seeded with the tick and tone).
- **2D viewer** (`src/ui/widgets/pitch_2d.gd`). A *replay* of the simulator's abstract state (possession, zone, ball carrier, Snitch state, events). The engine has no physics and no coordinates. The tokens are interpolated toward targets derived from that state, which is why what you see matches the log without affecting determinism.

## 11. Injuries

- Causes: Bludger impact, collision (Blatching), fall (failed Wronski Feint, broken broom), extreme fatigue.
- Severity: minor (keeps playing with a penalty), off for the match (the team continues with 6), long (weeks) and serious (months; Pfeffer 2014).
- Mediwizards on the pitch treat the player, who does not return after going off [GoF 8, PM-2014].
- Injury proneness as a hidden attribute (FM07).

## 12. Engine tests

- Determinism: the same seed gives an identical log (byte for byte).
- Distributions: 10,000 matches between equivalent teams give the §4 metrics within tolerance.
- Strength: a team with +5 in all attributes wins ~75-80%; +10, ~95%.
- Rules: never a player substitution outside a night break; never two Chasers in the scoring area without the goal being disallowed; Snitchnip means forfeit; a sent-off player never returns.
- Long matches: 1,000 matches forced past 12 h all end (catch or mutual agreement) before 30 days of play.
