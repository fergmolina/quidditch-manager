# 03: Key findings and open decisions

> Cross-reference of `01-football-manager-and-pc-futbol.md` and `02-quidditch.md`. For each decision, the evidence on each side and a recommendation. Decisions marked **[PROJECT DECISION]** are settled by the project lead before continuing the GDD; the rest are settled by the design and documented here.

## A. The three critical decisions

### A1. Substitutions during the match: [PROJECT DECISION]

**What the canon says** (02 §3.6, 17 pieces of evidence):
- Rule 5 of 1750: "*In the case of injury, no substitution of players will take place. The team will play on without the injured player*" [QTTA c6]. A sent-off player is not replaced either (New Zealand plays with 6 in 2014).
- But Wood talks about a record three-month match in which "*they had to keep bringing on substitutes so the players could get some sleep*" [PS 10], so there were voluntary changes due to fatigue.
- Clubs have reserve teams (Puddlemere), the Houses have substitutes (Harper, Alicia Spinnet), and managers pick the lineup between matches.
- The Captain can call a **time-out** at any moment (rule 2); it is the only moment with feet on the ground.

**A reading that reconciles everything** [Inference]. Rule 5 forbids replacing the **injured** player, not voluntary changes. That gives a house rule with canonical support:

| Option | Rule | For | Against |
|---|---|---|---|
| **1. Tactical changes at time-outs; injured and sent-off players are not replaced** (recommended) | **Tactics.** The manager can change them at any moment; they take effect at the next stoppage (goal, foul, injury, time-out), as in FM. **Player changes.** Only at time-outs; the manager has N per match (e.g., 2) and at each one can change up to M players (e.g., 2) and talk to the team. If a player is injured or sent off, he leaves and the team plays on with 6: his position **cannot** be covered. | Keeps the core mechanic ("the manager makes changes and tactics") while respecting the letter of rule 5; injury keeps the drama of the books (Gryffindor without a Seeker, CS 7); the time-out as the moment to intervene is canon and is a scarce resource to be managed. | It is an interpretation; a purist could object that the books never show a tactical change. |
| 2. Strict canon | No changes during the match; only tactics at time-outs. Changes only during the overnight breaks of matches lasting more than 12 h. | Total faithfulness. | Half of the core mechanic disappears; the substitutes' bench barely exists. |
| 3. Free substitutions (quadball) | Changes whenever you want, injured players included. | More management gameplay. | Contradicts rule 5 and the spirit of the books. |

**Recommendation.** Option 1. Parameters (time-outs per match, changes per time-out) configurable per competition.

### A2. Snitch value and match length: [PROJECT DECISION]

**What the canon says.** 150 points and the end of the match [QTTA c4, c6]. Indefinite length, from 3.5 seconds to 16 days; at the 2014 World Cup most catches came between 40 min and 2.5 h (02 §3.9). The catching team won 14 of 15 clean matches in 2014. JKR already wrote a canonical "patch" for the World Cup group stage: a 4-hour cap, decided on goals if there is no catch, 2 points per win + 1/3/5 for margins of 50/100/150 [PM-WC]. The timing of the catch is canonical tactics (Wood: don't catch until +50; Krum in 2014 refuses to catch it until his team has come back).

**What others did.** *Quidditch Champions* lowered the Snitch to 30 and made matches timed; *Quidditch World Cup* (2003) only makes it appear once the Chasers fill a meter; quadball: 30/35 points and 20 minutes without Seekers.

| Option | Rule | For | Against |
|---|---|---|---|
| **1. Canon (150, ends the match) + Seeker tactics as the lever + leagues on accumulated points** (recommended) | The Snitch is worth 150 and ends the match. The manager gives **Seeker instructions**, all conditional as in canon: "always catch" (Krum 1994: ends the match even though he loses), "only if catching wins us the match" (Krum 2014), and "only if we are +X ahead" (Wood). There is no "never catch". The Seeker always tries as soon as his condition is met, and if the Snitch appears right in front of him with the opponent on top of him, he catches it anyway. Because the league adds up points scored (canon, see A3), winning big matters and the Chasers are not decorative. The probability of a catch grows with playing time; fatigue degrades everyone and, after X hours, the Captains can agree to end the match (rule 7), so the match always ends. Most matches last between 40 minutes and 3 hours of playing time; multi-day matches exist but are rare and epic. | It is exactly the sport of the books, with the tactics the books show. The "unfairness" of the Snitch becomes the most tense decision in the game. | The catch curve has to be calibrated carefully so the variance is not absurd; in a management game the player may feel that "the match decides itself." |
| 2. Time cap + goals (World Cup rule) in every competition | If there is no catch within X hours, decided on goals. | Partial canon; bounds the length. | Changes the essence of the league; the Snitch loses weight. |
| 3. Snitch at 30-50 points | Like *Quidditch Champions* / quadball. | Easy balance. | It is not the Quidditch of the books; contradicts "same essence." |

**Recommendation.** Option 1 as the default rule for leagues and cups; option 2 as the rule for the World Cup group stage (because it is canon); and the Snitch value, the time cap, and the catch curve as parameters of each competition. The simulator has an explicit time model in minutes of play; the 2D viewer compresses it (summary / key moments / full).

### A3. League format: [PROJECT DECISION]

**What the canon says.** The *Daily Prophet* tables rank by **accumulated points**, multiples of 10, with no wins column (02 §7.2); the Hogwarts Cup is decided by total points [PoA 15] and the margin matters [HBP 24]; there are recorded draws. The League has 13 teams and an annual League Cup [QTTA c7]. It is not known how many matches there are per season; the Cannons' 16-defeat streak suggests a double round-robin or a streak spanning seasons. There are no club-owned stadiums. Matches are played on Ministry moors, sometimes at midnight.

| Option | Rule | For | Against |
|---|---|---|---|
| **1. Table by accumulated points scored** (recommended) | Each team adds up the points it scores in each match (goals + Snitch). Double round-robin (24 matches). Tiebreaker: fewest points conceded, then most Snitch catches. **Scale.** The *Daily Prophet* tables show season totals of 230-820, but canon results of individual matches range from 170 to 610 per team; 24 matches at ~250 points give totals of ~6,000. Calibrated with the match dataset (02 §3.10), treating the scale of the *Prophet* tables as a loose approximation by JKR. | Canon (*Daily Prophet* tables, Hogwarts). Makes every goal matter even when you lose, and keeps the Snitch from being everything. It is unlike any football manager, which gives it an identity of its own. | A team can win the league while losing matches; this needs to be explained well in the interface. "Dead" matches make less sense (they always count). |
| 2. Points per win + margin bonus (JKR's World Cup format) | 2 per win, +1/+3/+5 for margins of 50/100/150. | Canon for the World Cup; more familiar. | It is the World Cup group-stage format, not the league's. |
| 3. Win = 3 points, football style | | Familiar. | No canonical basis; makes the Snitch decisive again. |

**Recommendation.** Option 1 for the British and Irish League and Hogwarts (canon); option 2 for the World Cup group stage (canon); the format is a per-competition parameter, so leagues in other countries can vary (and we mark that as filler).

## A4. Decisions made (October 2, 2026)

| Decision | Outcome |
|---|---|
| A1 Substitutions | **As in the books.** No player changes during the match. If a player is injured or sent off, the team plays on with 6. Changes only during sleep breaks in matches lasting more than 12 hours (rule 2 + Wood). The manager handles tactics live (applied at the next stoppage) and calls time-outs; the lineup is set between matches using the reserves. The proposed "changes at time-outs" option was discarded for not being canon. |
| A2 Snitch | **Canon: 150 points and the match ends**, with conditional Seeker instructions. 4-hour cap **only** in the World Cup group stage (JKR canon). Competitions with a devalued Snitch are **not** invented: they do not exist in canon. "The real thing." |
| A3 League | **Accumulated points scored**, double round-robin. |
| Start year | **1993-94** by default. Other years (1996-97, 2014-15…) as **DLC / data packs**. **Open world.** Endless seasons with no ending. **World Cups every 4 years** (1994 at Dartmoor, 1998, 2002…), with the group stage over the two preceding years. |

Second round (same day):

| Decision | Outcome |
|---|---|
| Book events | **Yes.** A "Book events" toggle, on by default (Hogwarts without Quidditch in 1994-95; PoA fixture list in 1993-94). |
| Managing school teams | **Not in v1.** Schools are youth academies; they can be viewed and scouted. |
| Market | **Purchases, sales, and loans.** Purchases and sales are canon [DP]; loans neither appear in canon nor contradict it, so they are **[FILLER]**. |
| Josef Wronski Award | **Yes**, as a secondary award marked **[Prop]** (Cannons crest from the films). |

## B. Other design decisions (settled by the GDD)

| # | Decision | Evidence | Decision taken |
|---|---|---|---|
| B1 | Match engine archetype | FM: agent-based ticks (free visualization, hard calibration). Hattrick: events by sector (easy calibration, scripted animation). PC Fútbol 6.0: result and animation separated, which gives replays that contradict the result (to be avoided). | **Phase-based hybrid.** The simulator advances in ticks of playing time (e.g., 5 seconds) and in each tick resolves **events** (Quaffle possession, attack, shot, save, Bludger, Snitch sighting, chase, catch) with probabilities derived from attributes, brooms, tactics, and fatigue. Each event carries approximate positions of the 14 players and the 4 balls, enough for the 2D viewer to interpolate. What you see is exactly the log. |
| B2 | Attribute model | FM07: ~36 visible 1-20 + hidden + CA/PA 1-200. PC Fútbol: 4 attributes, "it was solved by stacking the average." Lesson from 01 §6.2: few and readable. The brief asks for skills that improve and decline FM07-style. | **1-20 scale, 36 visible attributes** (7 Flying, 10 Technical, 14 Mental, 5 Physical) with key attributes per position, 13 hidden as in FM 07, and CA/PA 1-200. Same size as FM 07 (36 for outfield players), carried over to Quidditch. Details in `docs/design/05-player-model`. Progress arrows on the player profile. |
| B3 | Progression curve | FM (community testing): training dominates until 18, minutes from 18 on, peak ~24, slow decline until ~31, then fast; physical attributes drop first. Canon: Krum comes back at 38 and wins the World Cup; Plumpton captain for decades; Wood in the reserves at 18-19. | Peak 24-29; physical decline from 31, mental holds up; Seekers and Chasers depend more on physical attributes (earlier peak), Keepers and Beaters later. Careers until ~38-40 with exceptions. |
| B4 | Career ladders | PC Fútbol's Promanager is the biggest generator of "one more season" (01 §6.1). | Main mode: start at a small club (or a school, see B6) with a board objective; offers when you meet it; manager reputation. Free mode: choose any club. |
| B5 | World: which leagues exist | Canon: British and Irish League (13 clubs); ~22 named clubs in the rest of the world spread across 15 countries; national teams (~40). Chosen scope: the whole world. **This implies ~130 clubs and ~1,500 players, almost all filler: they are not written by hand.** The data model (09) has to define a **procedural generator** (name tables by region, attribute distributions by league level) with a layer of canon files on top that override it. | Leagues playable in v1: **Great Britain and Ireland (13, canon)**, **France**, **Germany**, **Eastern Europe** (Bulgaria, Poland, Lithuania, Romania, Moldova), **Iberian Peninsula + Luxembourg** (Portugal, Spain), **Nordic** (Norway, Sweden), **United States**, **Canada**, **Argentina** (a must-have), **Brazil**, **Andean** (Peru, Chile…), **Mexico and the Caribbean**, **Africa** (All-Africa League: Uganda, Togo, Ethiopia, Tanzania, Nigeria, Malawi…), **Japan**, **Oceania** (Australia, New Zealand). Each league with 8-13 clubs; canon clubs are used and the rest are **[FILLER]**. European Cup every 3 years (canon), World Cup every 4 (canon). |
| B6 | Schools as youth academies | Hogwarts has 4 House teams with substitutes; other schools have teams (Beauxbatons, Durmstrang, Ilvermorny, Mahoutokoro, Castelobruxo); first-years do not play; graduates move to reserve teams (Wood to the Puddlemere reserve). | The 8-11 known magic schools are **regional youth academies**: they generate players aged 12-17, play their House cup visibly in the game, and at 17-18 graduate onto the market. Clubs scout them. **Open question.** Can the player manage a House team as the first rung of a career? |
| B7 | Venues | There are no club-owned stadiums in the British league (Ministry moors). | The club has a **training ground** (upgradable facilities) but matches are played on moors assigned by the Department; "home advantage" exists through proximity and fans, not through a stadium. Removes the stadium subsystem (which in PC Fútbol was filler without decisions). Other leagues may have their own stadiums [FILLER]. |
| B8 | Economy | A single canon data point: a 1,000-Galleon transfer (1999). Brooms 600-5,000 G (1890), Omnioculars 10 G. FM: wage and transfer budget; PC Fútbol: subsystems without decisions (catering) to be avoided. | Currency: Galleons. Income: gate receipts (via the Department), sponsorship (Nimbus, Butterbeer…), simple merchandising, prize money. Expenses: wages, brooms, staff, Healers. Scale: star signing ≈ 1,000-5,000 G; weekly wage 5-100 G [FILLER calibrated from the only canon data point]. |
| B9 | Brooms as equipment | Table of ~40 models with speed, acceleration, braking, endurance, altitude, wear. Firebolt "price on request," limited production. | The club buys brooms per player or in bulk; each model has attributes that modify the player's; they wear out (Shooting Star) and are broken by Bludgers (Thunderbolt VII). Limited availability of the top models. |
| B10 | Fouls and referee | 10 named fouls, penalties: penalty shot, disallowed goal, sending-off, forfeit of the match (Snitchnip). Named referees with canon biases (Mostafa distracted by Veela). | The simulator models **the 10 fouls from QTTA** with their canon penalties (penalty; goal disallowed for stooging/haversacking; sending-off for serious blatching; forfeit for snitchnip), plus the conduct penalized in the books (grabbing the body, hitting a player with the bat, attacking the Keeper without the Quaffle in the scoring area, play after the whistle). The player's aggression attribute and the "hard play" instruction (Falmouth style) trigger them; referees have strictness and distraction (Mostafa and the Veela). |
| B11 | Match display | Both series offer only result / summary / key moments / full. | The same, from the first prototype; adjustable speed. Playing time is compressed: a 2-hour match is watched in ~8-10 min in "key moments." |
| B12 | Press and board | FM press conferences: "the cancer of the game." PC Fútbol 6.0's matchday newspaper: cheap and effective. Canon: the *Daily Prophet* with tables and match reports (Ginny Potter, Rita Skeeter), managers who talk to the press. | **No press conferences.** A weekly *Daily Prophet* generated from templates (results, signings, controversies, Rita Skeeter). Board with a season objective and confidence by area, without a complex "club vision." |
| B13 | National teams | World Cup every 4 years with canon format (16 groups, 2 years, 4 h cap, 2 pts + bonus); European club Cup every 3 years. | In v1 the player manages clubs; national teams are managed by the AI and call up the club's players (absences, injuries). Managing a national team is left for later. |

## C. Inventory of canon gaps and their filler

Everything in this table is invented and marked **[FILLER]** in documents and with `source: "filler"` in the data.

| Gap | What the canon has | How it is filled | Style criterion |
|---|---|---|---|
| Full squads for the 13 British clubs | 1-5 named players per club, from different eras (1920s-1999) | Squad of **7 starters + 5-7 reserves** per club. Canon players from the 1994-2000 era are used; the rest are invented. | British and Irish names with JKR's humor (alliteration, surnames that sound like a trade or a place: Gudgeon, Wadcock, Plumpton). Ages and positions consistent with the canon anecdotes. |
| Leagues and clubs outside Great Britain | ~22 named clubs in 15 countries, 1-2 per country; no tables or formats | 8-13 clubs per league; canon clubs are included with their traits (Vratsa: long-range shooting; Toyohashi: burn their brooms). | Name = city + alliterative animal/object ("Quiberon Quafflepunchers," "Gorodok Gargoyles"); one identity trait per club. |
| National team squads | Nearly complete 2014 rosters for ~10 national teams; 1994 for Ireland and Bulgaria | National teams call up the best players of each nationality in the game world; canon names are assigned to plausible clubs. | The 2014 names are canon and are respected; the game's start year determines which players are active. |
| Start year and chronology | Canon milestones 1991-2014. **Note.** In 1994-95 Hogwarts had no Quidditch (Triwizard Tournament) and in 1995-96 Harry was banned mid-season. | **[PROJECT DECISION]** Candidates with a full Hogwarts season: **1993-94** (PoA: Wood's last season, the Firebolt arrives, the Dartmoor World Cup falls the following summer), **1996-97** (HBP: Harry as Captain, Ginny as Chaser), or **2014-15** (after the Patagonia World Cup: most complete canon rosters, Krum retires). Recommended: 1993-94. | Canon players with known dates appear at the correct age; those from later eras appear as youth players or not yet born. |
| Season length and calendar | Tables in Jul/Feb/Jun/Oct; matches on Friday/Saturday/Monday at varied times | Season from **August to June**, double round-robin (24 matchdays), fixtures every 1-2 weeks, with gaps for the European Cup and call-ups. | Odd kickoff times (midnight) as flavor in the match reports. |
| National cup | No mention for Great Britain | No national cup in v1 (one league + European Cup + World Cup is already a full calendar). | |
| European Cup format | "Every three years"; known champions; unknown format | Straight knockout of 16 clubs (champions and runners-up of the European leagues), single matches at neutral venues. | |
| Tiebreak in matches | There are recorded draws (Cannons-Catapults; Proudsticks-Magpies 1986), with no tiebreak rule in any source | Draws exist and stand (the league adds points either way, so no rule is needed). In knockouts, where a winner is needed, **the match is replayed** (the canon knows the idea of a replay: Diggory offers one in PoA 9). No "golden score" or extra time is invented. | Minimal option compatible with the lore. |
| Contracts, wages, budget | One 1,000 G transfer | Calibrated Galleon scale (see B8). Contracts of 1-5 years with a weekly wage. | Small, readable numbers, like the prices in the books. |
| Training facilities | Nothing | 3-5 facility levels per club (training pitch, infirmary with a Healer, broom workshop). | |
| Staff | Named managers, a "coach and manager," scattered trainers, Healers | Roles: assistant, flying coach, Beater/Chaser coach, Healer, scout(s), club secretary. Invented names. | |
| Broom attributes | Qualitative traits and some speeds (0-150 mph in 10 s) | Numerical table (speed, acceleration, turning, braking, stability, durability, price) derived from the canon traits. | Canon hierarchy: Firebolt > Nimbus 2001 > 2000 > Cleansweep 11 ≈ Comet 290 > … > Shooting Star. |
| Referees | ~10 named | Pool of ~20 referees per region with strictness and a tendency to get distracted. | JKR-style names. |
| Official Spanish translations | Only quaffle, bludger, snitch dorada verified | Use the Salamandra terms from memory (Amago de Wronski, Saeta de Fuego, Barredora, Cometa, Estrella Fugaz) marked "unverified"; check against a physical copy before release. | |

## D. What the research leaves as warnings

1. **What you see has to be what happened** (PC Fútbol 6.0). The 2D viewer consumes the simulator log and nothing else.
2. **Barrier to entry.** FM loses players in the first hour. The weekly loop has to be playable with 3-4 screens; everything else can be delegated to the assistant.
3. **Tactical opacity.** FM's central complaint. The assistant has to say in plain text what is happening ("their Beaters are punishing our Seeker"; "our Chasers aren't getting into the scoring area").
4. **10-20-season hands-off tests** from the first prototype to detect worlds that break (empty squads, eternal players, Galleon inflation).
5. **Exploitable market.** Player value and willingness to sign from the first release, even if simple.
6. **Variance.** FM's "quick engine" is less random than the full one; here there is a single engine for all matches, so calibration is done once with thousands of simulated matches (dataset from 02 §3.10 as reference: 3-35 goals/hour, 40 min-3 h typical).
