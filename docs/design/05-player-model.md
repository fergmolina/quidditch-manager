# 05: Player model

> Modeled closely on the Football Manager 2007 model (`docs/research/01-football-manager-and-pc-futbol.md` §2bis.2-2bis.3) and adapted to the four Quidditch positions. Visible 1-20 scale, hidden decimals, current and potential ability 1-200, thirteen hidden attributes revealed through phrases. Canon names for positions and plays are those in QTTA.

## 1. Basic profile

| Field | Detail |
|---|---|
| Name, nationality, date of birth | Canon players have canon or estimated dates (flagged); the rest are generated |
| Main and secondary positions | Keeper (K), Chaser (C), Beater (B), Seeker (S); familiarity 1-20 per position (Ginny played as Chaser and Seeker) |
| Club, contract, value | See `08` |
| Broom | Model and condition (see §6) |
| School of origin | Hogwarts (house), Beauxbatons, Durmstrang… or none |
| Condition, form, morale, injury | Status (see §5) |
| Captain | Yes/no; uses Influence |

## 2. Visible attributes (1-20)

Stored with decimals and shown as integers. Colors by range as in FM (1-5 gray, 6-10 normal, 11-14 good, 15-17 very good, 18-20 excellent).

### Flying (7): what the player does with the broom

| Attribute | What it measures | Canon plays that use it |
|---|---|---|
| Speed | The player's own top speed, combined with the broom | Snitch chases; counterattacks |
| Acceleration | Take-off and changes of pace | Burst after sighting the Snitch; Woollongong Shimmy |
| Agility | Tight turns, dodges | Sloth Grip Roll, dodging Bludgers |
| Broom control | Flight precision, braking, hands-free flying | Reverse Pass, two-handed beating, Starfish and Stick |
| Balance | Staying on the broom through hits and maneuvers | Beaters (let go with both hands), Sloth Grip Roll |
| Altitude | Comfort and performance at great height and in wind | Porskoff Ploy, matches in storms |
| Diving | Vertical descents and pull-outs | Wronski Feint, Spiral Dive |

### Technical (10)

| Attribute | What it measures | Positions |
|---|---|---|
| Passing | Accuracy and power of Quaffle passes | C, K |
| Catching | Catching the Quaffle in flight (Gorgovitch: record for "Quaffle drops") | C, K |
| Shooting | Accuracy and power toward the hoops, including long-range shots (Vratsa) | C |
| Dodging | Evading opposing Chasers while carrying the Quaffle | C |
| Stealing | Taking the Quaffle from an opponent's hands without a foul (rule 4) | C |
| Interception | Cutting out passes | C, K |
| Keeping | Keeper technique: Double Eight Loop, Starfish and Stick | K |
| Beating | Power and technique with the bat; Bludger Backbeat | B |
| Beat accuracy | Sending the Bludger to the target | B |
| Snitch catching | Technique for catching the Snitch (Plumpton Pass; Lamont's "short fingers") | S |

### Mental (14): FM 07's, under the names of that era

| Attribute | Use in Quidditch |
|---|---|
| Aggression | Toughness; combined with hidden Dirtiness, fouls |
| Anticipation | Reading passes and Bludgers |
| Bravery | Holding the line against Bludgers and the Wronski Feint; playing through injury |
| Composure | Shots and penalties under pressure |
| Concentration | Seeker: not losing sight of the Snitch; Keeper in long matches (Miskine did not see the Snitch above his eyebrow) |
| Creativity | Seeing non-obvious passes and plays |
| Decisions | When to shoot, pass, catch, beat |
| Determination | Comebacks; development |
| Flair | Spectacular plays, feints |
| Influence | Captaincy, team morale |
| Off the ball | Chaser without the Quaffle: getting open |
| Positioning | Defensive position: Keeper in front of the hoops, Beater covering |
| Teamwork | Formations (Hawkshead, Parkin's Pincer) |
| Work rate | Sustained effort in long matches |

### Physical (5)

| Attribute | Use |
|---|---|
| Stamina | Condition loss per tick; matches lasting hours |
| Strength | Beating, steals, withstanding collisions |
| Natural fitness | Recovery between matches; slower decline |
| Reflexes | Keeper; dodging Bludgers |
| Eyesight | Sighting the Snitch; seeing long passes |

### Keeper-specific

The Keeper uses Keeping, Reflexes, Positioning, Anticipation, Agility, Bravery, Concentration, Altitude, Passing (restarting play) and Influence (command). The other technical attributes are not shown on their profile, just as outfield attributes are not shown for a goalkeeper in FM.

### Key attributes by position (for CA and for reports)

| Position | Key | Important |
|---|---|---|
| Keeper | Keeping, Reflexes, Positioning, Anticipation | Agility, Bravery, Concentration, Altitude, Influence |
| Chaser | Passing, Catching, Shooting, Dodging, Speed | Off the ball, Creativity, Decisions, Teamwork, Stealing, Agility |
| Beater | Beating, Beat accuracy, Strength, Balance | Anticipation, Aggression, Bravery, Positioning, Decisions, Broom control |
| Seeker | Eyesight, Snitch catching, Speed, Acceleration, Agility | Concentration, Bravery, Diving, Composure, Decisions, Balance |

## 3. Hidden attributes (13, 1-20): FM 07's

| Hidden | Effect | Report phrase (example) |
|---|---|---|
| Consistency | Match-to-match performance variance | "Performs consistently" / "Brilliant one day, invisible the next" |
| Important matches | Bonus/penalty in finals, the World Cup, derbies | "Likes the big matches" |
| Injury proneness | Probability of injury on impact | "Gets injured easily" |
| Dirtiness | Fouls; Cobbing, Blatching | "Has a competitive streak that leads them to bend the rules" |
| Versatility | Switching positions (Ginny) | "Can play in more than one position" |
| Adaptability | Signing in another country / league | "Would have no trouble living in another country" |
| Ambition | Asks to move to bigger clubs; development | "Wants to reach the very top" |
| Controversy | Statements to *The Daily Prophet*, rows (Gwenog Jones) | "Tends to get into controversies" |
| Loyalty | Renewals, turning down offers | "Loves the club" |
| Pressure | Performance with a hostile crowd, jinxes from the stands | "Handles pressure well" |
| Professionalism | Training, slower decline, life off the pitch (Maddock and golf) | "Exemplary professional" |
| Sportsmanship | Diving, protesting, fouls after the whistle | "Plays fair" |
| Temperament | Reaction to team talks and criticism; fights | "Quick to flare up" |

Hidden attributes are never shown as numbers. They are summarized in a **personality label** ("Model professional", "Ambitious", "Temperamental", "Loyal", "Controversial"…) and in phrases in scout and assistant reports.

## 4. Current and potential ability (CA / PA, 1-200)

- **CA** is the weighted sum of the attributes according to position (key attributes weigh more). It never exceeds PA.
- **PA** is fixed when the player is created; generated youth players have a PA within a random range that is resolved at the start of the game (like FM's negative PAs).
- Scale references **[calibrated FILLER]**: starter at a small British league club ~90-110; starter at Puddlemere or the Magpies ~130-150; world star (Krum 1994, O'Hare, Plumpton) 170-190; average Hogwarts youth player 40-70; Harry at 13 ~75 with PA ~165.
- The scout does not see CA/PA. They see ability and potential stars (0-5, with uncertainty depending on their quality and knowledge of the region). Stars in reports probably came after FM 07 [R in the research]. In FM 07, reports were profiles with phrases. They are adopted anyway for readability, alongside the phrases.

## 5. Status

| Variable | Range | How it changes |
|---|---|---|
| Condition | 0-100 | Drops during the match according to intensity and Stamina; recovers daily according to Natural fitness and rest; the mediwizard speeds it up. The value the player brings to the match is his starting condition there (`SimPlayer.start_condition`, since 0.11.0; before, every match started at 100), so a squad playing every 1-4 days kicks off at 60-70 % and performs accordingly. A player leaves a match with at least 25 (`GameEngine.POST_MATCH_CONDITION_FLOOR`): exhausted, back above 60 in four days; the floor was 5 before 0.11.0 |
| Match sharpness | hidden 0-100 | Rises with minutes played; drops with inactivity; affects performance |
| Accumulated fatigue | hidden | Rises with consecutive matches and long matches; only drops with several days' rest |
| Morale | 7 levels (Awful … Superb) | Results, playing time, team talks, promises, press, team morale |
| Form | average rating over the last 5 matches (1-10) | Performance |
| Injury | type, days remaining | See `03` §11; the club mediwizard reduces the days |
| Suspension | matches | Department sanctions (Broadmoor: 14 suspensions) |

## 6. The broom as equipment

The broom **modifies** the Flying attributes: effective speed = f(player's Speed, broom speed), and likewise for acceleration, agility (turning), control (braking), altitude and stability in bad weather. Each model also has durability (the Shooting Star loses speed as it ages; the Thunderbolt VII breaks when hit by a Bludger) and a price. Table in `09-data-model.md`, based on `02-quidditch.md` §6.3. A Firebolt in the hands of a weak Seeker is still weak in Eyesight and Snitch catching. The broom does not replace the player (Slytherin with Nimbus 2001s lost anyway).

## 7. Progression and decline

FM 07 model with canon ages (long careers: Krum champion at 38, Watkins captain of the Magpies for 35 years, Plumpton for decades).

| Age | What happens |
|---|---|
| 11-17 (school) | Fast growth driven by training and school matches; PA is "revealed" (the scout's stars sharpen). First-years do not play. |
| 17-21 | Graduation; the jump to professional play requires playing time: the reserves (Wood at Puddlemere) and matches are the main driver. Without playing time, they stagnate. |
| 22-29 | Peak. Mental attributes keep rising with experience. |
| 30-33 | First physical declines (Speed, Acceleration, Stamina); Flying and mental attributes hold; Natural fitness and Professionalism delay it. |
| 34-40 | Marked decline; typical retirement at 35-38; Seekers and Chasers earlier, Keepers and Beaters later. Exceptions with high Professionalism and Determination (Krum). |

Factors, as in FM 07: **training** (category, workload, coach quality, facilities), **playing time** at the right level, **personality** (Professionalism, Ambition, Determination), **injuries** (long ones take away), **summer break** (slight drop), **rebalancing** (when CA changes the attributes are redistributed and one can drop even if the player improves).

**Top of the scale** [FILLER, calibrated after the 2026-10-22 playtest, where many players reached 20 in every key attribute by 21-23]. Growth is full up to 16 and then tapers (×0.78 at 17 down to ×0.11 at 20, `Progression.top_taper`). Individual training fades over the last 4 points of headroom below potential and does nothing at potential. When the PA cap is hit, only what just rose is taken back, so a player at their potential no longer loses unrelated attributes.

**How it is shown.** On the profile, each attribute has an **arrow** since the last review: green pointing up (improvement), red pointing down (decline). The angle shows the magnitude (tilted for a fraction, vertical for a whole point), and orange marks a fractional drop that has not yet lowered the integer. A "Recent changes" view in Training with the squad summary. A CA evolution chart over time in the progress tab. (The research could not confirm the arrows with an FM 07 screenshot; they are adopted anyway because they were an explicit design requirement.)

## 8. Generating filler players

For the ~1,500 non-canon players: name by region (first-name and surname tables per country, with JKR's humor for the British ones), age following the squad distribution, position, PA by league level, CA by age and PA, attributes distributed according to the position profile with noise, random hidden attributes, broom according to club budget. All with `source: "filler"`. Canon players are loaded from hand-written files and override the generator.

## 9. What the canon provides for canon players

Traits converted into attributes (examples; the full table lives in the data):

| Player | Canon trait | Attributes |
|---|---|---|
| Viktor Krum (18, 1994) | Wronski Feint; clumsy on the ground, graceful in the air; catches with a broken nose | Diving 19, Eyesight 18, Snitch catching 18, Bravery 19, Flair 18, Agility 17; Important matches high |
| Oliver Wood (18, 1994) | Obsessive, tactics board, speeches | Influence 16, Determination 18, Professionalism high, Keeping 14, PA medium-high |
| Gwenog Jones (25, 1993) | "Brilliant but dangerous" | Beating 18, Beat accuracy 17, Aggression 19, Dirtiness high, Controversy high, Influence 17 |
| Tony Silva (Brazil 2014) | Fast and accurate, but struggles to locate the Snitch | Speed 18, Snitch catching 17, Eyesight 9, Concentration 10 |
| Georgi Zdravko (K Bulgaria 2014) | 46 goals conceded vs Japan | Keeping 11 on an elite team |
| Dragomir Gorgovitch | Record for Quaffle drops | Catching 6 |
