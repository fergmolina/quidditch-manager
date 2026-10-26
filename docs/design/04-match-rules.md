# 04: Match rules

> Project rule: the game uses the rules of Quidditch **exactly as they appear in the books and in *Quidditch Through the Ages***. No rules are invented. Where the canon is silent and the simulator needs an answer, the minimal option compatible with the lore is chosen and marked **[FILLER]**. Detailed source: `docs/research/02-quidditch.md` §3-4.

## 1. Pitch, balls and players

| Element | Game rule | Source |
|---|---|---|
| Pitch | Oval of 500 × 180 feet; 2-foot center circle; no height limit; crossing the boundary is forbidden (if a player goes out, their team surrenders the Quaffle) | [QTTA c6] |
| Hoops | Three at each end, on posts of different heights; scoring area around them | [QTTA c6] |
| Quaffle | One; 12 inches, scarlet leather; falls slowly (Pennifold); can be held in one hand (Gripping Charm) | [QTTA c6] |
| Bludgers | Two; iron, 10 inches; attack the nearest player if nobody deflects them | [QTTA c6] |
| Golden Snitch | One; walnut-sized; evades capture and does not leave the boundaries; flesh memory to settle disputed catches | [QTTA c4, c6], [DH 7] |
| Team | 7 players: 1 Keeper, 3 Chasers, 2 Beaters, 1 Seeker. One of them is captain | [PS 10], [QTTA c6] |
| Keeper | Defends the hoops; must block from in front (Flacking if they put their body through the hoop); may leave the scoring area; restarts play after conceding a goal. **Cannot be attacked with Bludgers unless the Quaffle is in the scoring area** | [QTTA c6], [PoA 15], [PM-2014] |
| Chasers | Pass and score; only the one carrying the Quaffle may enter the scoring area (Stooging if more enter); the Quaffle must be thrown, not carried, through the hoop (Haversacking) | [QTTA c6] |
| Beaters | Reinforced bats; deflect Bludgers toward opponents and away from teammates; never score or touch the Quaffle; may not hit Bludgers into the crowd (Bumphing) | [QTTA c6] |
| Seeker | The only one who may touch the Snitch; historically the most fouled player and the one who suffers the worst injuries ("Take out the Seeker") | [QTTA c6] |
| Wands | May be taken onto the pitch, but never used against opponents, brooms, the referee, the balls or the crowd | [QTTA c6] |

## 2. Scoring and end of match

| Rule | Detail | Source |
|---|---|---|
| Goal | 10 points for the Quaffle through any hoop | [PS 10] |
| Snitch | 150 points to the team whose Seeker catches it | [QTTA c4] |
| End of match | Only when the Snitch is caught **or by mutual agreement of both captains** | [QTTA c6, rule 7] |
| Winner | The side with more points at the end; you can catch the Snitch and lose (Bulgaria 1994, Gryffindor 1996) | [GoF 8], [OotP 26] |
| Draw | Exists and is valid (Cannons-Catapults; Proudsticks-Magpies 1986). There is no tiebreak rule in the canon | [DP], [QTTA c8] |
| No clock | No periods and no clock: the length is indefinite | [PS 10] |
| Start | The referee releases the Bludgers and the Snitch, throws up the Quaffle and blows the whistle; all 14 take off | [QTTA c6], [PS 11] |
| Restart after a goal | The Keeper of the team that conceded puts the Quaffle back in play | [Wiki, video games; **not explicit in the books or QTTA**: it is the minimal option to resume play] |
| Ends | Teams do not switch ends | [Wiki, not contradicted by the books] |

## 3. Time-outs, stoppages and duration

| Rule | Detail | Source |
|---|---|---|
| Time-out | The captain may call one at any time by notifying the referee; the only moment players may touch the ground. If the match goes beyond 12 hours, a time-out may last up to 2 hours; failing to return = disqualification | [QTTA c6, rule 2] |
| Stoppages for medical attention | Play stops so mediwizards can treat a fallen player (Lynch 1994) | [GoF 8], [PM-2014] |
| Stoppage for Bumphing | Hitting a Bludger into the crowd forces play to stop | [QTTA c6] |
| Night breaks | In multi-day matches play stops so players can sleep | [PM-2014] |
| Long matches | The canon records matches from 3.5 seconds to 16 days, a 3-month record (Wood) and a Snitch that evaded capture for 6 months until both teams gave up | [QTTA c6-7], [PS 10] |

**How the simulator handles it** (details in `03-match-engine.md`). Game time is counted in minutes. Most matches end between 40 minutes and 3 hours of play, as in the 2014 World Cup. Matches that exceed 12 hours enter the "long match" regime (time-outs of up to 2 h, night breaks, severe fatigue). The end by mutual agreement of the captains (rule 7) exists as the canon way out of endless matches. The captains' AI proposes it when both teams are exhausted and the lead is unreachable **[FILLER: the exact criterion for when a captain agrees to give up is not in the canon]**.

## 4. Substitutions and lineup

| Rule | Detail | Source |
|---|---|---|
| Injury | "In the event of injury, no substitution of players will take place. The team will play on without the injured player." | [QTTA c6, rule 5] |
| Sending off | A sent-off player is not replaced (New Zealand played with six in 2014) | [PM-2014] |
| Sleep relays | In extremely long matches substitutes have been brought on so players could sleep (the 3-month record) | [PS 10] |
| Lineup | Decided before each match; clubs have reserve teams and the houses have reserves | [GoF 7], [HBP 14], [PS 11] |

**In the game.** The manager picks the 7-player lineup before each match from the whole squad. During the match **there are no player substitutions**. If a player is injured or sent off, the team carries on with six (or fewer). Only in matches that enter the "long match" regime (over 12 hours of play) may the manager, during a night break, relieve exhausted players with reserves **[partial canon: Wood + rule 2; the details of how many and when are minimal FILLER]**. The relays are not built yet. The engine has night breaks but no sleep relays (see `03-match-engine.md` §2).

## 5. Fouls and penalties

The 700 recorded fouls are not published [QTTA c6]. The game models the ten named ones plus the conduct penalized in the books:

| Foul | Who | In-game sanction | Source of the sanction |
|---|---|---|---|
| Blagging (seizing the tail of the broom) | All | Penalty | [PoA 15] (Malfoy) |
| Blatching (flying with intent to collide) | All | Penalty; sending off if serious or repeated | [GoF 8] (Dimitrov), [PM-2014] (Moon sent off) |
| Blurting (locking broom handles) | All | Penalty | [QTTA c6] [Inference about the sanction] |
| Bumphing (Bludger into the crowd) | Beaters | Play stopped; penalty **[FILLER: QTTA only says play is stopped]** | [QTTA c6] |
| Cobbing (use of elbows) | All | Penalty | [GoF 8] (Zograf) |
| Flacking (Keeper blocking from behind the hoop) | Keeper | Goal stands | [Inference] |
| Haversacking (hand on the Quaffle as it goes through the hoop) | Chasers | Goal disallowed | [Inference] |
| Quaffle-pocking (tampering with the Quaffle) | Chasers | Penalty **[FILLER]** | [QTTA c6] |
| Snitchnip (a non-Seeker touching the Snitch) | All except the Seeker | **Match forfeited** | [PM-2014] (Haiti) |
| Stooging (more than one Chaser in the scoring area) | Chasers | Goal disallowed | [QTTA c6] (1884) |
| Grabbing an opponent's body | All | Penalty | [QTTA c6 rule 4], [PoA 15] (Montague) |
| Hitting a player with the bat | Beaters | Penalty if intentional ("no foul" if not, with review) | [PoA 15] (Bole), [PM-2014] (Santos) |
| Attacking the Keeper without the Quaffle in the scoring area | Beaters | Penalty | [PoA 15], [PM-2014] (Rice) |
| Deliberately blocking the opposing Seeker | All | Penalty | [PS 11] (Flint) |
| Play after the whistle | All | Disciplinary sanction outside the match (suspension) | [OotP 19] |
| Using a wand against an opponent | All | Sending off and suspension by the Department **[FILLER on the exact sanction; the canon shows jinxes in 1999 and suspensions by the Department]** | [QTTA c6], [DP3] |
| A spectator jinxing a player | Supporters | That supporters' team **automatically forfeits** (1849) | [PM-2014] |

**Penalty.** The Chaser flies from the center circle toward the scoring area. Only the opposing Keeper may intervene [QTTA c6, rule 3]. The Keeper's Double Eight Loop is the usual defense [QTTA c10].

**Referee.** One per match, appointed by the Department (league) or the ICWQC (World Cup). Boundary officials watch the boundaries. The referee can caution, award penalties, send off, disqualify and review Omnioculars footage [PM-2014]. The referee has a strictness level and can be distracted (Mostafa and the veela) **[FILLER: the referee's numeric attributes]**.

## 6. Rules by competition

| Competition | Specific rules | Source |
|---|---|---|
| British and Irish League | Table by accumulated points scored; no time limit; venues on Ministry moors | [DP], [QTTA c5-7] |
| Hogwarts Cup | Single round-robin among the 4 houses; table by total points (margin decides); first-years do not play | [PoA 15], [HBP 24], [PS 9] |
| World Cup, group stage | Limit of **4 hours**; if there is no catch, decided by goals; win = 2 points, +1/+3/+5 for margins of 50/100/150; tiebreak by number and speed of catches | [PM-WC] |
| World Cup, knockout rounds | No time limit; 1st vs 16th, etc.; third-place match | [PM-WC], [PM-2014] |
| European Cup | Every three years; format not described **[FILLER: see 07]** | [QTTA c8] |
| Draw in knockout rounds | No canon rule. **[minimal FILLER]: the match is replayed** (the replay as a concept exists: Diggory offers one in PoA 9) | |

## 7. What the game does NOT do

- It does not reduce the Snitch's value or put a clock on league matches.
- It does not allow tactical player substitutions during a match.
- It has no extra time, "golden score" or penalty shootouts.
- It does not let more than one Chaser into the scoring area without disallowing the goal.
- It does not use the rules of any video game or of real-world quadball.
