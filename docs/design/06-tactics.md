# 06: Tactics

> Modeled on the FM 07 tactics screen (`docs/research/01-football-manager-and-pc-futbol.md` §2bis.6-2bis.7): a mini-pitch with the players and instructions, team sliders, per-player instructions, opposition instructions, three prepared tactics to switch between, and team talks at three moments. No roles/duties and no tactics creator (those are from FM 2010). The plays and styles are the canon ones (`docs/research/02-quidditch.md` §5); no plays are invented.

## 1. The mini-pitch

A top-down oval with the **7 players** as circles showing their number and position initial. They are dragged to set their **base zone**:

- **Keeper.** Inside the scoring area (default) or pushed up (comes out to intercept; in 1398 it "was a matter for the Keeper's conscience", today Keepers are "advised to stay in the scoring area" [QTTA c6]). Blancheflower came out too far and conceded [PM-2014].
- **Chasers.** Three zones (left, center, right; advanced or withdrawn). An **arrow** per Chaser shows how far they push forward in attack (FM 07's "forward run arrow") and a dotted arrow backward shows how far they drop back to defend.
- **Beaters.** Coverage zone (over the Chasers, over the Seeker, over our own scoring area, free).
- **Seeker.** Search altitude (high, medium, low) and zone (free, own half, tight on the opposing Seeker).

**Three tactics** are saved per match (main, attacking, defensive) to switch between with one click during the match, as the FM 07 guides recommended. Tactics are files (`user://tactics/`) that can be shared.

## 2. Team sliders (1-20, default 10)

Reduced from FM 07's 13 to the ones with a visible effect in Quidditch:

| Slider | Extremes | What it changes in the engine |
|---|---|---|
| **Mentality** | Defensive ↔ Attacking | How high the Chasers play, how far the Keeper comes out, passing risk, how many Chasers drop back to defend |
| **Tempo** | Slow ↔ Fast | Speed of Quaffle circulation; more shots and more turnovers; more fatigue |
| **Passing** | Short ↔ Long | Short, safe passes vs. long passes and Reverse Pass; depends on Passing and Catching |
| **Shooting** | Close only ↔ From range | Shots from outside the scoring area (Vratsa's long shot [QTTA c8]) |
| **Pressing** | Rarely ↔ Often | How much the Chasers chase the opposing carrier; tiring |
| **Hard play** | Soft ↔ Hard | Aggression in steals and collisions; fouls; injuries caused; "Let us win, but if we cannot win, let us break a few heads" (Falmouth) |
| **Time wasting** | Low ↔ High | Long possession without shooting to give the Seeker time (Krum 2014: dragging the match out to come back) |

Sensible combinations (the assistant explains them): fast tempo with long passing makes a counterattack; defensive mentality with time wasting waits for the Snitch; hard play against a strict referee brings penalties.

## 3. Chaser style (canon formation)

A single choice, with requirements; the assistant warns if the squad has not mastered it:

| Style | What it does | Requirements | Risk | Source |
|---|---|---|---|---|
| **Free** | No fixed pattern | | | |
| **Hawkshead Attacking Formation** | All three in an arrowhead; intimidates and forces a way through | Teamwork, Bravery, Speed | If the pass fails, all three are out of position | [QTTA c10], Ireland 1994 |
| **Porskoff Ploy** | The carrier climbs as a decoy and drops the Quaffle to a teammate below | Creativity, Altitude, Catching | Interception if the timing fails | [QTTA c10], Troy 1994 |
| **Parkin's Pincer** | Two close in on the opposing carrier and the third comes head-on: pressure to steal | Stealing, Aggression, Anticipation | Blatching (penalty) with high Dirtiness | [QTTA c10] |
| **Woollongong Shimmy** | High-speed zigzag to shake off markers | Agility, Dodging, Broom control | Turnovers from difficult passes; fatigue | [QTTA c10] |
| **Reverse Pass** (as a passing style) | Unexpected over-the-shoulder passes | Passing, Creativity, Flair | Turnovers | [QTTA c10], Tchamba Charmers |
| **Formation looping** | Loops in formation; spectacle and confusion | Teamwork, Broom control | Slow | [QTTA c8], Sumbawanga Sunrays |

> **Why there are no "four Chasers" or 4-3-3-style formations.** Positions are fixed by the rules: 3 Chasers, 2 Beaters, 1 Keeper and 1 Seeker [QTTA c6]. Since 1884 only the Chaser carrying the Quaffle may enter the scoring area; if more than one enters, the goal is disallowed (*Stooging*) [QTTA c6]. A Beater cannot play the Quaffle, and if anyone other than the Seeker touches the Snitch it is a foul (*Snitchnip*). The way to "attack with more players" is mentality, Chaser style (Hawkshead, Porskoff…), Beaters protecting the Chasers and the Keeper coming out to intercept. Measured over 3,000 matches against an equal opponent, no option exceeds a 52% win rate: they are nuances, because the Snitch decides most matches.

## 4. Beater instructions

Per Beater, or for both:

| Instruction | Effect | Source |
|---|---|---|
| **Hunt the rival seeker** | Priority: Bludgers at the opposing Seeker ("Take out the Seeker", *The Beaters' Bible*) | [QTTA c6] |
| **Protect our seeker** | Escort (Fred and George with Harry; Vulchanov for Krum) | [CS 10], [PM-2014] |
| **Protect the chasers** | Deflect Bludgers away from our own attack | |
| **Punish the carrier** | Bludgers at the opposing Chaser with the Quaffle | |
| **Beater marking** | Braga Broomfleet's marking system: each Beater follows an opponent | [QTTA c8] |
| **Dopplebeater Defence** | Both hit the same Bludger for more power; leaves the other Bludger free | [QTTA c10] |
| **Bludger Backbeat** | Backhand stroke that sends the Bludger backward: 35% of the time it wrong-foots the opponent (×1.5 accuracy), otherwise it is inaccurate (×0.7), and 1 time in 10 it can hit a teammate [effect: game] | [QTTA c10] |

Instruction against a specific opponent (new in FM 07): "mark X", "always tackle X hard".

## 5. Seeker instructions

| Instruction | Options | Source |
|---|---|---|
| **Catch** (conditional) | **Always catch** (Krum 1994: ends the match even if he loses) / **Only if catching wins** (Krum 2014: holds off until the team has come back) / **Only if we are at least +X ahead** (Wood: +50; X selectable 0-200; with X = 0 it means "only if we are ahead") | [GoF 8]; [PM-2014]; [PoA 15] |
| **Search** | Free / Mark the rival seeker (Harry on Malfoy) / Preferred altitude | [PoA 15] |
| **Wronski Feint** | Never / If the chance arises / Actively look for it | [QTTA c10]; Pfeffer's risk [PM-2014] |
| **Plumpton Pass** | Automatic if Snitch catching ≥ 18 and Flair is high | [QTTA c10] |

The catch instruction is the most important decision of the match and the interface always shows it in the HUD.

## 6. Keeper instructions

| Instruction | Options | Source |
|---|---|---|
| Position | Stay in the scoring area / Rush out / **Starfish and Stick** (covers the hoops: +7% against long shots and +8% on penalties, −4% if the Chaser gets in close) / **Double Eight Loop** (swooping around the three hoops: +25% on penalties, −3% in open play) [effects: game] | [QTTA c6], [QTTA c10], [PM-2014] |
| Restart | Short / long pass | |

## 7. Per-player instructions

Individual mentality, creative freedom, passing, pressing, hard play and marking (as in FM 07), plus: **long shots** (rarely / mixed / often), **run with the Quaffle**, **free role**, **playmaker** (passes go through them), **target player** (receives the long passes).

## 8. Captain

Chosen by the manager (Influence, Determination, experience). The captain calls the time-outs and negotiates the end by mutual agreement (rule 7); their Influence weighs on morale and on how the others react to team talks.

## 9. Team talks (FM 07: before, at the time-out, after)

The same four tones are used at every moment (`src/game/team_talk.gd`):

| Tone | Before the match / at a time-out (each player's attributes for the rest of the match, capped at ±4%) | After the match (squad morale) |
|---|---|---|
| **Calm down** | Takes the pressure off: helps players with low Pressure; slightly better when ahead, slightly worse when behind | Small boost, larger after a defeat |
| **I have faith in you** | Encouragement: positive for almost everyone, more for temperamental players, a little less for professionals; extra boost when behind | Good after a win, mild after a narrow defeat, negative after a heavy one (more swing for temperamental players) |
| **I expect more** | Works on professional and determined players; sinks temperamental ones; worse when losing by more than 100 | Works on professionals, upsets temperamental players; slightly negative after a win by more than 100 |
| **This is unacceptable** | Only makes sense when losing (by more than 50 before the match, or at all at a time-out): professionals and determined players react, temperamental and pressure-sensitive ones shut down. Otherwise it backfires on everyone | Backfires after a draw or a win; after a defeat it works on professionals and upsets temperamental players |

Each player's reaction also has a small random component (deterministic, from the talk's own seed). The screen then lists who reacted well and who reacted badly. One post-match talk per match. Individual talks are given outside matches, from the player profile (Praise their form / Demand more / Promise a starting place).

Originally planned: different tone sets per moment (before: No pressure / I expect a win / I have faith in you / This is the match of the year; time-out: Calm / Demanding / Motivating / Harsh criticism, with harsh criticism able to reach *The Daily Prophet*; full time: Congratulations / Disappointment / No comment), individual talks during the match for whoever reacted badly, and one talk per night break in multi-day matches.

## 10. Tactical feedback (what FM 07 lacked and this game has)

During and after the match the assistant (and the "observer" watching the opponent) says in text what is happening, with stats by area:

- "Their Beaters are focused on our Seeker: three Bludger hits so far."
- "We've entered the scoring area 14 times and shot 9 times: their Keeper is saving everything."
- "Our Chasers are losing the Quaffle on long passes (6 interceptions)."
- "We're +120 and the Seeker is instructed to catch only at +150."
- "Three hours in: the team's condition has dropped below 50."

These are translatable templates fed by the match log (`03` §7).

## 11. Tactical familiarity

The team takes weeks to master a new formation (Hawkshead requires tactics training). Changing it constantly during a match lowers performance (FM 07 guide: avoid drastic changes). "Tactics" training (`08`) raises it.
