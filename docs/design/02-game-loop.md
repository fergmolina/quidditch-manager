# 02: Game loop

## 1. Time structure (FM 07)

- The unit is the **day**. The **Continue** button advances the calendar; it stops on days with one of your own matches, on messages that require a reply and on season milestones.
- The **inbox** is the narrator: injuries, offers, scout reports, board messages, *The Daily Prophet*, national team call-ups.
- Everything that is not central can be **delegated to the assistant** (training, friendlies, routine replies), and delegation is the default for a new player. The minimal loop is lineup, then match, then inbox, then continue.

## 2. Game modes

| Mode | Description |
|---|---|
| **Career** (main mode, Promanager style) | You start without a club and receive offers from modest clubs. The board sets a season objective; meeting it brings offers from better clubs and raises your reputation; failing lowers it or gets you sacked. You can move between leagues and continents. |
| **Free club** | You pick any club in the world and manage it indefinitely. |
| Open world | In both modes seasons are endless: the world goes on, players age and retire, youth players arrive from the schools, there is a World Cup every 4 years and a European Cup every 3. |

## 3. The season

Calendar of the starting year (1993-94). Sources in `07-competitions-and-world.md`.

| Month | Clubs | Hogwarts and schools | National teams |
|---|---|---|---|
| August | Preseason: friendlies, trials, broom purchases, signings **[FILLER: the August start; the canon has league tables in July and October]** | Holidays; Hogwarts letters arrive | World Cup group stage (two preceding years) continues |
| September | The League starts (double round-robin, ~24 matchdays through June, one every 1-2 weeks) | Term starts; house team trials (September-October) | |
| October-November | League | First match of the Hogwarts Cup (typical schedule: Gryffindor-Slytherin in early November; in 1993-94 it was Gryffindor-Hufflepuff because Slytherin managed to reschedule over Malfoy's "injury" [PoA 8-9]; if "Book events" is enabled the PoA fixture list is used) | |
| December-January | League; the market is open all year (the canon shows mid-season signings: Griffiths, Campbell [DP]) | Christmas | Group stage |
| February-March | League; European Cup when it is due (knockout rounds) **[FILLER: dates]** | 3rd and 4th Hogwarts Cup matches | |
| April-May | League | 5th and 6th matches; Hogwarts Cup final (late May) | Call-ups for the finals |
| June | Last matchday; League Cup presentation; Dangerous Dai Medal; renewals, retirements | Exams; 7th-years graduate | |
| July | Holidays; board review; new objectives; graduated youth players arrive on the market | | **World Cup finals** in the years it is held (1994: Dartmoor; final on August 22-25 per the GoF chronology) |

The World Cup finals overlap with the clubs' preseason, as in 1994: called-up players return late and tired.

## 4. The week

Typical sequence with a league match:

1. **Inbox.** Injuries, reports, press, offers.
2. **Squad.** Condition, morale and brooms; see who improved or declined (arrows).
3. **Training.** Review or delegate (one team focus, individual focuses).
4. **Transfers / scouts.** If there is anything to do.
5. **Opposition report** (assistant/observer). Their style, their Seeker, their Beaters.
6. **Lineup and tactics.** Pick the 7 and the captain; Chaser formation, Beater instructions, Seeker instruction, mentality, hard play.
7. **Match.** Watch at the chosen level; intervene with tactics and time-outs.
8. **Post-match.** Result, stats, injuries, the next day's *Daily Prophet*, the board's reaction.
9. **Continue**.

Estimated length of a season (original design estimate, made for the planned highlight modes): 6-10 hours watching matches with 2D; 3-4 with text commentary only; 2-3 hours with the result only **[I]**. The viewing modes as built are "2D + commentary", "Commentary" and "Score only" (see `03-match-engine.md` §8).

## 5. Main screens

Details in `10-screens-and-ui.md`. List in order of importance:

1. Inbox
2. Squad (table with summarized attributes, condition, morale, broom, value)
3. Player profile (1-20 attributes by group, progress arrows, history, contract, broom, scout report)
4. Lineup and tactics (oval pitch with the 7, instructions)
5. Match (2D viewer)
6. Fixtures and results
7. League table (accumulated points; visible explanation of the system)
8. Training
9. Transfers and scouting (search, shortlist, offers, negotiation)
10. Finances (balance, wages, sponsorships, brooms)
11. Board (objective, confidence, requests)
12. *The Daily Prophet* (generated news)
13. Competitions (European Cup, World Cup, Hogwarts Cup)
14. Schools (academy: house teams, standout youth players, scouting)
15. History (honors, records of the game world; an "encyclopedia" as in PC Fútbol)

## 6. Season milestones that stop the calendar

- Job offer received (career).
- Board objective set / reviewed.
- A player asks to leave or for a new contract.
- One of your players is called up to their national team.
- Long-term injury to a starter.
- End of season: summary, awards, school graduations, retirements.
- World Cup: group draw, finals.

## 7. What is not in the game

- Transfer windows. The canon shows signings in mid-season, so the market is always open.
- Catering, parking and other subsystems without real decisions (PC Fútbol).

Originally planned, and now in the game:
- No press conferences, only the occasional *Daily Prophet* question at milestones (three or four per season). The game now has a short press conference after every official club match the manager plays and one the day before it (not for friendlies, national teams or school mode; can be turned off in Settings; `src/game/press.gd`; see `08`).
- No club stadiums, with matches on Ministry moors as in the books [QTTA c5]. Each club now has a home ground **[game, FILLER]** (`src/world/grounds.gd`, `data/shared/grounds.json`). Club matches are played at the home side's ground and finals at the competition's neutral venue, and attendance scales the gate receipts.
