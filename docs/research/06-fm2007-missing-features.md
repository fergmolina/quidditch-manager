# Research 06: Football Manager 2007 features missing from Quidditch Manager

> Goal: add every FM 2007 feature we don't have yet. This report inventories FM 07 by area, cross-checks it against the current code (October 10, 2026; the version after the 200-season audit and AI sackings), and ends with a prioritized list ready to implement.
>
> **How the status was verified**: grep and reading of `src/game/` (`game_engine.gd`, `economy.gd`, `market_actions.gd`, `press.gd`, `career.gd`, `progression.gd`, `awards.gd`, `team_talk.gd`), `src/world/`, `src/sim/`, the 26 screens in `src/ui/screens/`, design docs `10-screens-and-ui` and `11-scope-and-roadmap` ("Status" entries). Nothing marked "has" was assumed: every row cites the file.

## 0. Conventions

**FM 07 sources**
- `[01 §x]` = `docs/research/01-football-manager-and-pc-futbol.md`, section 2bis (with its sources F69-F97: 2006 reviews, FMScout guides, Wikipedia).
- `[W07]` https://en.wikipedia.org/wiki/Football_Manager_2007 · `[W06]` …/Football_Manager_2006 · `[W05]` …/Football_Manager_2005 · `[W08]` …/Football_Manager_2008 · `[W09]` …/Football_Manager_2009 · `[WS]` …/Football_Manager (series) · `[WDE]` https://de.wikipedia.org/wiki/Football_Manager_2007.
- Confidence: **[C]** confirmed for FM 07 by a source that was read; **[S]** confirmed for the series before FM 07 (almost certainly in FM 07); **[R]** reasonable / recollection from the era with no source read (treat as unconfirmed). The SI forums, the manual, GameSpot, IGN, Fandom, and FMScout blocked automated reading in this session (403/404), as in research 01-football-manager-and-pc-futbol.

**Status**: **has** / **partial** / **missing**, with file or screen.

**Effort**
- **S**: one or two files, no save-schema change; a few text keys.
- **M**: engine + screen + keys in all 10 languages + a test in `tests/run_tests.gd`; may add fields with a default value in `from_dict` without bumping `World.SCHEMA_VERSION`.
- **L**: new system, new persistent fields (bump `SCHEMA_VERSION`, currently 6, which makes older saves stop loading, as there is no migration path), calibration with `tools/life_audit.gd` / `tools/stress_test.gd`.

**Fit**: `[canon]` grounded in the books; `[game]` FM mechanic with no canon basis (mark it in data/docs, never in the UI); `[film]` only in the films; `n/a` does not apply.

## 1. What Quidditch Manager already has that FM 07 didn't

So it isn't filed as missing by mistake:

| QM feature | Arrived in FM in | Where it is in QM |
|---|---|---|
| Post-match press conference with questions and 4 tones | FM 2009 [W09][01 §2bis.8] | `src/game/press.gd`, `press_screen.gd` |
| Agent who negotiates wage and bonus | FM 2011 [WDE] (in FM 07 agents only offered players [W05]) | `Economy.agent_demand`, `MarketActions._contract_stage` |
| Assistant who reads the opponent's tactics and suggests the defense | FM 2010 (assistant analysis) [01 §2bis.1] | `lineup_screen._assistant_text`, `MatchSim._ai_counter_defence` |
| Replays of goals and catches in the 2D view | later [R] | `pitch_2d.gd` (`replay_last_play`) |
| Live "What's at stake" panel | doesn't exist in FM | `match_screen.gd` (`stakes_box`) |
| Promises with verification and consequences | FM 07 already allowed promises in negotiations [01 §2bis.8]; verification with consequences came later [R] | `Press.talk("promise")`, `Press.check_promises` |
| Managing a Hogwarts House (school mode) | doesn't exist | `World.house_club`, `schools.gd` |

## 2. Inventory by area

### 2.1 Screens and navigation

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Tree-style side menu | Access to Squad, Tactics, Training, Finances… [01 §2bis.9][C] | **has**: `main.gd` (grouped menu with icons) | | |
| Browser-style back / forward | New in FM 07 [01 §2bis.9][C] | **has**: `main.gd`, Alt+←/→ | | |
| Continue with contextual text | Advances day by day; blocks if something needs a reply [R] | **has**: "Continue", "Play vs X", "Fix the line-up" (`main.CONTINUE_DAYS`, `GameEngine.lineup_blocked`) | | |
| Top bar in club colors and bottom bar | Default skin [01 §2bis.9][C] | **has**: tinted bar (`main.gd`) | | |
| Contextual "Actions" menu | On player/club/staff member [01 §2bis.9][C] | **has**: `player_screen._actions_menu` | | |
| Every name is a link | [R] | **has**: `UI.player_cell`, `UI.team_cell` | | |
| On-screen help and tips while processing | FM 06/07 [W06][01 §2bis.8][C] | **has**: F1 (`ui.help.*`) and owl tutorial; no tips while processing | | |
| Club home screen (overview) | Home/club overview [R] | **partial**: `club_screen.gd` (basic profile) and `board_screen.gd`; no "desktop" with next match, form, injuries, and finances together | S | [game] |
| Screen bookmarks/favorites | [R, maybe later] | **missing** | S | [game] |
| Global search for people/clubs | Search box [R] | **partial**: player search in `explorer_screen.gd`; doesn't search clubs or staff | S | |
| Swappable skins | Community skins [W07][01 §2bis.8][C] | **missing** (fixed theme `theme_builder.gd`) | L | Low value; can be dropped |
| Currency/units/date preferences | [R] | **partial**: dates by language; fixed Galleons (good: canon) | | [canon] Galleons |

### 2.2 Inbox and news

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Inbox with typed messages and actions | Offers, board, scouts; they block if a reply is required [S][R] | **has**: `World.post_message`, `inbox_screen.gd`, only `urgent` ones stop progress | | owls [canon] |
| World news (newspaper) | League, cup, international news [W05][S] | **has**: weekly three-column Daily Prophet (`news_generator.gd`, `news_screen.gd`, `_relevant_news`) | | [canon] |
| News filters / preferences for what to receive | [R] | **missing**: `_relevant_news` decides on its own | S | |
| Delete, archive, filter the inbox by sender/unread | [R] | **missing**: `inbox_screen.gd` only lists and marks unread | S | |
| Opposition report | Assistant's report on the next opponent [R] | **partial**: `lineup_screen._assistant_text` gives style and suggested defense; no form, key players, or probable seven | S | |
| Transfer rumors | Basic rumors in the news [R]; rumor module in FM 2009 [W09] | **has**: `GameEngine._rumours` | | |

### 2.3 Squad and player profile

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Sortable squad table with views | Configurable views and columns [R] | **partial**: `squad_screen.gd`: First team/Reserve/Youth filters and General/Flying/Technical/Mental/Physical views; **Contracts** and **Stats** views are missing (planned in `10-screens-and-ui` §3.2), as are user-chosen columns | S | |
| First team / reserves / youth | Separate squads [R] | **has**: `Player.squad` (first/reserve/youth), reserve matches (`_reserve_matches`) | | reserves [canon GoF 7] |
| Move players between squads | Promote/demote [R] | **partial**: youth players move to the reserves at 19 at rollover; no manual "promote to first team / demote to reserves" action | S | |
| Squad numbers | Per season [R] | **missing** | S | [film]: the books put the surname on the robes |
| Captain and vice-captain | [R] | **partial**: captain yes (`_make_captain`, `ensure_captain`); no vice | S | captain [canon] |
| Designated takers (set pieces) | Penalties, corners, free kicks [R] | **partial**: `MatchSim._penalty` picks the Chaser with the best shooting; can't be designated | S | penalty [canon QTTA] |
| 1-20 attributes in groups, hidden ones shown as phrases | [01 §2bis.2][C] | **has**: `player_screen._profile`, `_reports` | | |
| Progress arrows | [01 §2bis.3][C/R] | **has**: `Player.prev_attrs`, `training_screen.gd`, Progress tab | | |
| Season-by-season history | [R] | **has**: `player_screen._history` (apps, goals, catches, saves, rating, awards) | | |
| Injury history | [R] | **missing**: only the current injury (`injury_days`, `injury_kind`) | S | |
| Contract tab with clauses | [R] | **partial**: wage, expiry, role, and value; no clauses | see 2.8 | |
| Compare two players | [R, maybe FM 2008+] | **missing** | M | |
| CA/PA stars | Later (FM 07 used text) [01 §2bis.3] | **has** (more than FM 07): `_stars` in market and explorer | | |

### 2.4 Tactics (team and individual instructions)

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Formation by dragging counters | [01 §2bis.7][C] | **has**: `PitchView` in `lineup_screen.gd` | | 7 fixed positions [canon] |
| Team sliders | 13 sliders, 1-20 [01 §2bis.7][C] | **has**: `SimTactics.defaults()`: mentality, tempo, passing, long shots, pressing, hard tackling, time-wasting | | |
| Named styles/plays | Equivalent to formation | **has**: Chaser styles (Hawkshead, Porskoff, Parkin's Pincer…), Beaters, conditional Seeker, Keeper | | [canon QTTA] |
| Individual player instructions | Same sliders per player + forward runs, run with ball, long shots, free role, playmaker [01 §2bis.7][R detail] | **partial**: by position only (all Chasers the same; Seeker and Keeper have their own); no per-player instructions | M | [game] |
| Opposition instructions for a specific opponent | Mark/close down/tackle hard a specific opponent [W07 via 01 §2bis.1][C] | **partial**: `seeker_search: mark_rival`, Beaters `hunt_seeker`/`mark_beaters`, defense `mark`; no picking an opponent by name | M | Wronski against Krum [canon GoF 8] |
| Save/load tactics, three prepared | Main, attacking, and defensive [01 §2bis.6][C] | **missing**: `Club.tactics` is a single dictionary (what was planned in `10-screens-and-ui` §3.4 wasn't done) | M | [game] |
| Tactical familiarity (the team "settles") | Changing too much makes things worse [01 §2bis.6][C] | **missing**: planned in `06-tactics` §113, no code (`grep cohesion/familiarity` empty) | M | [game] |
| Set pieces | Corner and free-kick instructions [R]; criticized for having no editor [01 §2bis.6] | **n/a** except the penalty: see designated taker (2.3) | | Quidditch has no corners or throw-ins |
| Tactics creator / shouts | FM 2010 [01 §2bis.1] | not part of FM 07 | | |

### 2.5 Training

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Schedules with workload per category | 9 categories with a light/medium/intensive slider, schedules per group or player, shareable files [01 §2bis.4][C] | **partial**: one weekly focus + one workload for the whole club (`training_screen.gd`, `Club.tactics.training_focus/load`), individual focus and mentors (`Player.training_focus`, `mentor_id`); no workload per category or per-group schedules | L | [game]; Wood trained the team 3 times a week [canon PS 9] |
| Coaches with ratings and workload | Stars per category; an overloaded coach performs worse [01 §2bis.4][C] | **missing**: no coaches (only `Club.staff` with 4 roles rated 1-5) | L | [game] |
| Training performance report | Training rating, graph [01 §2bis.3][R] | **missing** | M | [game] |
| Physical pre-season and summer break | [01 §2bis.3-4][C] | **has**: `_ai_training_focus` (physical in August), −0.15 at rollover | | |
| Injuries from intensive workload | [01 §2bis.4][C] | **has**: `Progression.training` + owl `msg.training_injury` | | |
| Individual rest | Give a tired player a rest [R] | **missing** | S | |

### 2.6 Match

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Top-down 2D view | Numbered counters, inherited from CM4 (2003) [01 §2bis.5][WS][C] | **has**: `pitch_2d.gd` (richer: animations, replays) | | |
| Display levels and speed | Full / key highlights / goals only [01 §2bis.5][C] | **has**: "Commentary", "2D + commentary", "Score only"; speeds | | |
| Commentary | [W07][C] | **has**: `commentary.gd` (Lee Jordan / Ludo Bagman) | | [canon] |
| Pre-match team talk (new in FM 07), half-time and full-time | [W07][W06][C] | **partial**: pre-match and during time-outs (`team_talk.gd`, `match_screen._show_talk`); **no post-match talk** (`post_match_screen.gd` doesn't offer it) | S | there's no half-time in Quidditch [canon]: the time-out is the equivalent |
| Individual talks | [01 §2bis.6][C] | **missing** during the match (exists outside it: `Press.talk`) | S | |
| Live tactical changes | Applied at the next stoppage [01 §2bis.6][C] | **has**: `sim.queue_tactics` | | |
| Substitutions | 3 subs [R] | **n/a**: QTTA rule 5: no substitution, not even for injury | | see sleep relief |
| Sleep relief in extremely long matches | | **partial**: overnight pause in the engine (`MatchSim.next_night_pause_h`), with no player relief (planned in `04-match-rules` §4) | M | [canon partial PS 10] |
| Live stats | [R] | **has**: `match_screen.stats_box` | | |
| Live player ratings | Rating and condition of each player during the match [R] | **missing**: ratings only appear post-match (`grep rating match_screen.gd` empty) | S | |
| Opponent's formation and changes in the panel | [01 §2bis.5][C] | **partial**: notices of AI tactical changes in the commentary; the opposing seven with their condition isn't shown | S | |
| Referee and their strictness | Affects fouls; you can comment on the referee [W07][01 §2bis.5][C] | **missing**: no referees in `src/` | M | [canon]: Madam Hooch, Hassan Mostafa (GoF 8) |
| Weather | [01 §2bis.5][C] | **has**: `MatchSim.weather` | | |
| Live scores from other matches | [R] | **missing** | S | |
| Post-match with ratings and player of the match | [R] | **has**: `post_match_screen.gd` | | |

### 2.7 Transfers

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Bids with counter-offers | [R] | **has**: `MarketActions.make_offer`, `process_pending`, `resolve_counter` (up to 2 rounds) | | |
| Incoming AI bids | [R] | **has**: on the 15th of each month, accept/counter/reject | | |
| Payment in installments | [R] | **missing**: everything paid up front | M | [FILLER: installments] already planned in `08-transfers-training-economy` §4 |
| Extras: sell-on %, appearance fees | [R] | **missing** | M | [game] |
| Player exchange | [R] | **has**: `make_swap_offer` | | |
| Loans with duration, wage split, option to buy, recall | "Enhanced loan options" [W05][S] | **partial**: free loan until June 30, full wage paid by the receiving club, early return; no fee, no option to buy, no selectable duration (`request_loan`, `execute_loan`) | M | [game] (`08-transfers-training-economy` §loans) |
| Transfer and loan lists | [R] | **has**: `toggle_transfer_list`, `toggle_loan_list` | | |
| Shortlist with alerts | [R] | **has**: `World.shortlist`, alerts in `_scout_recommendations` | | |
| Transfer windows | [R] | **n/a**: market open all year per canon (`08-transfers-training-economy` §4, [DP]) | | |
| Agents offering players | [W05][S] | **missing**: the agent only appears when negotiating | S | [game] |
| Mutual contract termination | [W05][S] | **has**: `mutual_terms`, `terminate_contract` | | |
| Work permits | [R] | **n/a**: no canon basis; foreigners play (Krum didn't play in Britain, but nothing forbids it) | | |
| Scout recommends signings | [R] | **has**: monthly `_scout_recommendations` | | |

### 2.8 Contracts

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Negotiation screen (wage, years, role) | [R] | **partial**: when signing: the agent makes a demand and you accept or haggle a fixed 15% with a fixed 3 years (`_contract_stage`); when renewing: a toast with wage ×1.15 and 2 years (`player_screen._renew`); when signing a free agent, a fixed wage (`_sign_free`). No screen to choose wage, years, or role | M | [game] |
| Squad role that matters | [R] | **partial (dead data)**: `contract.role` is saved and displayed (`player_screen.gd:350`) but the engine never reads it | M | [game] |
| Signing-on fee | [R] | **partial**: the agent's "bonus" (`agent_demand.bonus`) | | |
| Appearance, goal, catch, title bonuses | [R] | **missing**: `contract` = `{wage_weekly, end_day, role}` | M | planned in `08-transfers-training-economy` §4 |
| Yearly wage rise | [R] | **missing** | S | [game] |
| Minimum release fee clause | [R] | **missing** | M | planned in `08-transfers-training-economy` §4 |
| Relegation/promotion clauses | [R] | **n/a**: closed leagues [canon QTTA c7] | | |
| Pre-contracts and "Bosman" free transfers | Final six months: sign for free for the following season [R] | **missing**: you can only sign players who are already free; the shortlist warns about expiring contracts | M | [game] |
| Player-requested renewal | The player asks for a new contract [R] | **missing**: the assistant warns about expiring contracts (`_assistant_weekly`), the player never asks | M | [game] |

### 2.9 Scouts and knowledge

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Regional knowledge that grows | New in FM 07 [W07][01 §2bis.8][C] | **has**: `Club.knowledge`, monthly growth in `_monthly` | | |
| Hire, fire, assign scouts | [01 §2bis.8][C] | **has**: `scouting_screen.gd` (up to 4) | | |
| Scout attributes (judging ability/potential) | [R] | **partial**: a single "quality" rating, 1-4 | S | |
| Assignments: player, competition, next opponent | [R] | **missing**: region only | M | [game] |
| Scout report cards | New in FM 07 [W07][C] | **partial**: recommendations in an owl; the player profile shows what is known by region (`Game.knowledge_level`), with no dated "report" containing a recommendation and rating | M | |
| Mask attributes of unknown players | [01 §2bis.2][C] | **has**: "?" depending on knowledge | | |
| Manager knowledge by country (nationalities) | [01 §2bis.8][C] | **missing**: a single nationality, gives no knowledge | S | [game] |

### 2.10 Youth academy and youth players

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Generated youth players (not recycled) | "Fred", new in FM 07 [W07][C] | **has**: `_make_filler` with PA based on club level, schools that graduate students (`Schools.rollover`) | | schools [canon] |
| Youth intake day with a report | [R] | **partial**: 2 youth players per club on July 1 with no notice; an owl for each school graduate (`msg.graduate`) | S | |
| Youth facility that sets quality | [01 §2bis.1][C] | **missing**: facilities: training ground, infirmary, broom workshop; PA depends on club level | M | [game] |
| Affiliated clubs (feeder clubs) | New in FM 07 [W07][01 §2bis.8][C] | **missing** | M | [game]; canon only gives schools as a youth source |
| Scout schools with priority on graduates | | **partial**: `schools_screen.gd` shows students; the priority from `08-transfers-training-economy` §4 isn't there | M | [FILLER] planned |

### 2.11 Staff

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Roles (assistant, coaches, physio, scouts, youth) | [R] | **partial**: 4 roles (assistant manager, mediwizard, chief scout, broom master) rated 1-5 (`Club.staff`, `Economy.upgrade_staff`) | | mediwizard [canon] |
| Search for, interview, and hire specific people | Job centre [01 §2bis.8][S] | **missing**: "promote" creates a random name of the next level; there are no candidates | M | [game] |
| Fire staff | [R] | **missing** (scouts only) | S | |
| Staff attributes | Coaching attacking/defending/fitness, judging, physiotherapy, discipline [R] | **missing**: level only | L | [game] |
| Staff contracts | [R] | **missing**: fixed wage per level | M | |
| Default staff at the start | [01 §2bis.8][C] | **has**: `WorldGenerator.default_staff` | | |

### 2.12 Board

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Season objective | Welcome message with objectives [01 §2bis.8][C] | **has**: `Club.board.objective`, negotiable in August (`board_screen._negotiate`) | | |
| Confidence and sacking | [01 §2bis.8][C] | **has**: `Economy.board_review`, `season_verdict`, AI sackings | | |
| Confidence by area | Improved in FM 2008 [W08] | **partial**: a single number (by area is planned in `08-transfers-training-economy` §6) | M | |
| Manager requests to the board | Budget, facilities, youth, feeder club [R] | **partial**: only "ask for budget" (`_ask_budget`); facilities are bought directly with club funds | M | [game] |
| Board requests to the manager | | **has** (QM extra): `_board_request` (facility, sell surplus players, wages) | | |
| Ultimatum / warning before the sack | [01 §2bis.8][C] | **missing**: the sack comes with no prior warning | S | [game] |
| New stadium / expansion | New in FM 07 [W07][C] | **n/a**: British clubs play on Ministry moors [canon QTTA c5]; see "training ground" in 2.13 | | |
| Club takeover by investors | New in FM 07 [W07][C] | **missing** | M | [game]; a Gringotts-style patron or a tycoon [FILLER] |

### 2.13 Finances

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Balance, transfer budget, and wage budget | [R] | **has**: `finances_screen.gd` | | Galleons [canon] |
| Split between transfer and wage budget | Adjustable within the limit [R] | **missing** | S | [game] |
| Income and expenditure ledger by month/season | Breakdown of gate receipts, TV, sponsorship, merchandising, prize money, wages, transfers [R] | **missing**: nothing is recorded; only the current balance | M | |
| Sponsors with contracts and renewal | [R] | **partial**: one fixed sponsor from creation; `sponsor.ends_season` is shown on the Finances screen, but the engine never reads it: the contract doesn't expire or renew (it doesn't appear in `src/game/`) | M | brands [canon GoF 8] |
| Merchandising | [R] | **missing** | M | rosettes, figurines, robes [canon GoF 7] |
| TV rights | [R] | **n/a**: no magical TV; a possible equivalent is the "Wizarding Wireless Network" (radio) [canon: WWN exists] as income [game] | S | |
| Prize money | [R] | **has**: league prize (champion and participation) at rollover and cup-winner prize in `_on_cup_finished`; no per-round payments | S | [FILLER: amounts] |
| Season tickets | [R] | **n/a**: gate receipts are allocated by the Department | | |
| Upgradable facilities | [R] | **has**: training ground, infirmary, workshop (`finances_screen._upgrade`) | | [FILLER] |
| Brooms (purchase) | | **has** (QM extra) | | [canon] |

### 2.14 Competitions, history, records, and awards

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Leagues, cups, continental competitions, World Cup | [S] | **has**: `competition.gd`, `GameEngine._create_*` | | [canon] + [FILLER] |
| Competition leaders and stats | [R] | **has**: `competitions_screen._league_stats` | | |
| End-of-season awards | [R] | **has**: `awards.gd` (Wronski, Dangerous Dai, top scorer, team of the season) | | [canon QTTA] |
| Player / manager / young player of the month | [R] | **missing** (`grep of_the_month` empty) | S | [game] |
| Team of the week | [R] | **missing** | S | [game] |
| All-time records (across all seasons) | Club, competition, player [R] | **partial**: current-season records (`competitions_screen.gd:158`); Plumpton's 3.5 s and similar only in the encyclopedia; no historical records are saved | M | [canon] QTTA records |
| Club history and honors | [R] | **has**: `board_screen` (hall of fame, legends, seasons), `history_screen.gd`, `club.history.managers` | | |

### 2.15 National team

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Manage a national team, alone or alongside a club | [R] | **has**: `_national_job_offer`, `accept_national_job`, `_national_review` | | |
| Call-ups, pool of eligible players | [R] | **has**: National team screen (`lineup_screen` in `national` mode) | | |
| International qualifiers and friendlies | [R] | **partial**: World Cup groups and final; no national-team friendlies | M | check with `07-competitions-and-world`: canon doesn't detail qualifiers |

### 2.16 Manager career

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Reputation and job offers | [01 §2bis.8][C] | **has**: `career.gd`, `_job_offers`, `accept_job` | | [game] |
| Start unemployed | [01 §2bis.8][C] | **has**: `new_game_screen` | | |
| Sacking and return to the job market | [R] | **has** | | |
| Profile with club history | [R] | **partial**: `World.manager.career` is saved but not shown on any screen; Board shows reputation, rank, seasons, and titles | S | |
| Resign | [R] | **missing** | S | |
| Apply for a vacancy (job centre) | "Apply for job" [01 §2bis.8][S] | **missing**: offers only come in | M | [game] |
| Past experience and two nationalities when creating the profile | [01 §2bis.8][C] | **missing** | S | [game] |

### 2.17 Interaction: press, talks, morale, happiness, promises, relationships

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Comments to the press about any player | New in FM 07 [W07][C] | **partial**: the press only asks after the match, about your own team (`press.gd`) | M | The Daily Prophet [canon] |
| Pre-match questions / mind games with the opponent | [W05][WS][S] | **missing** | M | trash talk allowed until 2014 [canon PM-2014] |
| Comment on the referee | New in FM 07 [W07][C] | **missing** (no referees) | | depends on 2.6 |
| Talk to a player (praise, demand, promise) | [01 §2bis.8][C] | **has**: `Press.talk` | | |
| Tell a player he'll be rested, ask the squad's opinion | New in FM 07 [W07 via 01 §2bis.1][C] | **missing** | S | [game] |
| Morale affected by playing time, contract, role | [R] | **partial**: morale changes with results, ratings, talks, press, and promises; it doesn't drop from not playing or from being transfer-listed | M | |
| Complaints: asks for a transfer, asks for a contract, complains to the press | [R][01 §2bis.6] | **missing**: a player only becomes transfer-listed if an ambitious player sees a promise broken (`check_promises`) | M | |
| Relationships, favorites, personal rivalries | [R] | **missing** (there are rivalries between clubs in `club.identity`) | L | Gwenog Jones and Griffiths [canon DP] |
| Supporters with a mood | Supporter confidence (FM 2008 [W08]) | **missing**: planned in `08-transfers-training-economy` §7 | M | rivalries and mascots [canon QTTA] |

### 2.18 Database, search, compare, reports, calendar, saving, and options

| Feature | How it is in FM 2007 | Status in QM | Eff. | Fit |
|---|---|---|---|---|
| Search with filters (age, value, contract, attributes, nationality) | [R] | **partial**: name + position + region (`explorer_screen._players`); market: scope + position + region (`market_screen.gd`), max 120-200 rows | M | |
| Compare players | [R] | **missing** | M | |
| Assistant's squad report | [01 §2bis.3][C] | **has**: `_assistant_weekly` | | |
| Calendar | [R] | **has**: `calendar_screen.gd` (list and month) | | |
| Save and load, multiple games | [R] | **has**: `save_manager.gd`, `saves_screen.gd`, Ctrl+S | | |
| Autosave | [R] | **missing** (`grep autosave` empty) | S | |
| Holiday (the assistant takes charge) | [R] | **missing** | M | [game] |
| Add/remove human managers, hotseat, network | [W05][S] | **missing**; multiplayer out of scope for 1.0 (`11-scope-and-roadmap`) | L | |
| Choose playable leagues / database size | [R] | **missing**: all 19 leagues load in full detail | M | |
| Editor | Editable files [W05][S] | **has**, in its own way: editable JSON (`data/`) | | |
| Multiple languages | [R] | **has**: 10 languages | | |

### 2.19 What doesn't apply to Quidditch

- **Substitutions.** QTTA rule 5, "substitution will not be permitted in the event of injury"; only sleep relief in extremely long matches (see 2.6).
- **Offside, corners, throw-ins, free kicks.** They don't exist in the QTTA rules; the only set piece is the penalty.
- **Half-time and half-time team talk.** The match has no halves; the time-out, which already exists, takes their place.
- **Promotion and relegation, relegation clauses.** The British league has been closed since 1674 (QTTA c7) and the rest copy that format.
- **Transfer windows.** Canon shows signings in mid-season; open market (`08-transfers-training-economy` §4).
- **Own stadium, capacity, expansions, season tickets.** Matches are played on Ministry moors (QTTA c5).
- **TV rights.** There is no magical television; at most, radio (WWN) as income [game].
- **Work permits.** Canon has nothing similar.
- **Preferred foot, heading, yellow cards.** The Quidditch player model replaces them (hands, broom, penalties, and sendings-off).

## 3. Prioritized missing and partial features

Ordered by impact on the "FM" feel (what's most noticeable in the first hour and every week). For each: data, screen, rules, and where to hook in. **Common rules**: (a) all new UI text goes into `locale/strings.csv` with `python3 tools/add_keys.py keys.json` in all 10 languages and is validated with `tools/check_translation.py`; (b) every new persistent field is added in `to_dict`/`from_dict` with a default value; if the meaning of something existing changes, bump `World.SCHEMA_VERSION` (currently 6), which makes `SaveManager` refuse the older saves, as there is no migration path; (c) every new system adds a test to `tests/run_tests.gd` and is checked in `tools/life_audit.gd` (which already checks texts in all 10 languages); (d) anything invented is tagged [game]/[FILLER] in `docs/design/08-transfers-training-economy` and in the JSON, never in the UI.

### P1. Real contract negotiation (M, or L if clauses and bonuses are added at the same time)
- **Data**: `Player.contract` becomes `{wage_weekly, end_day, role, signing_fee, bonus_goal, bonus_catch, bonus_title, yearly_rise_pct, release_clause}` (all 0 by default, so old saves load).
- **Screen**: new `ContractDialog` (in `src/ui/widgets/` or as a `contract` screen) used in three places: `_contract_stage` (signing), `player_screen._renew`, and `_sign_free`. Fields: wage (spin box), years 1-5, role (star/starter/rotation/backup/youth), signing-on fee, goal/catch/title bonuses, yearly rise, release clause. "Propose" button with a seal.
- **Rules**: a function `Economy.evaluate_contract(w, p, club, terms) -> {accept, counter_terms, mood}`: the player values a "package" = wage + signing-on fee/52 + expected bonuses (goals/catches from his last season × bonus) + role modifier (`star` +15%, `reserve` −20% if his CA is starter level). Ambition asks for a high role; loyalty gives a discount when renewing at his own club. Up to 3 rounds; after the third with no agreement, talks "close" for 30 days. The release clause lowers what he demands (−5% for each time the clause exceeds 2× the value), and if an AI club offers ≥ the clause, the transfer is automatic (`ai_transfer_tick`). Bonuses are paid in `GameEngine.apply_result` (goal/catch) and in `_on_cup_finished`/rollover (title); the yearly rise in `_season_rollover`.
- **Test**: renewing an ambitious starter with a low role is rejected; the clause triggers the transfer.

### P2. Player happiness and complaints (M)
- **Data**: `Player.happiness: Dictionary` with causes `{playing_time, contract, listed, promise}` (−20..+20) and `Player.last_complaint_day`.
- **Rules** (in `_weekly`, human club only): `contract.role` stops being dead data. If the role is `star`/`starter` and he played < 40% of the matches in the last 6 weeks (`stats_for`), `playing_time` drops; if he's transfer-listed without asking, `listed` −8; if he has < 6 months left and his CA is in the club's top 7, `contract` drops. The sum moves morale (±1/week). When the sum is ≤ −25, an owl "Wants to talk" (`from.player`) arrives with four actions: promise playing time (uses `Press.talk("promise")`), offer a renewal (opens P1), transfer-list him, ignore. If the manager ignores him twice, he asks for a transfer (`transfer_listed = true` and −10 morale to his "friends of the same nationality", see P15) and a story in the Daily Prophet ("X wants to leave Y").
- **Screen**: on the profile, a line "Happy / Unhappy about: playing time, contract…" and a column in the Squad's General view.
- **Calibration**: `life_audit` should show ~1-3 complaints per season at a well-run club.

### P3. Saved tactics and familiarity (M)
- **Data**: `Club.tactic_sets: Array` of 3 `{name, tactics}` and `Club.active_set: int`; `Club.familiarity: Dictionary` (Chaser style → 0-100).
- **Screen**: in `lineup_screen.gd`, a "Main / Attacking / Defensive" selector above the instructions panel (copy from the current one, rename). In `match_screen._build_live_tactics`, three buttons to switch sets live (queued until the next stoppage, as today).
- **Rules**: familiarity rises 4/week with the "tactics" training focus and 2 per match played with that style; it drops 1/week when unused. In `GameEngine.sim_team_for`, scale the style bonus in `MatchSim`, where `chaser_formation`/`beater_instruction` is applied, by `lerp(0.9, 1.0, fam/100)` (pass familiarity in `SimTeam`); each live style change adds a −3% penalty for 10 minutes of play (the FM 07 guidance about not changing things all the time). Recalibrate with `tools/sim_batch.gd` so that a 100%-familiar team doesn't win more than +3 percentage points.

### P4. Training by category and coaches (L)
- **Data**: `Club.training = {groups: {first, reserve, youth}: {category: load 0-3}}` with the categories from `08-transfers-training-economy` §1 (Physical, Flying, Quaffle, Beating, Keeping, Seeking, Tactics); `Club.coaches: Array` of `{name, ratings: {category: 1-20}, wage, contract_end}`.
- **Screen**: `training_screen.gd` with a group × category grid (light/medium/intensive sliders), coach assignment per category with a workload indicator, and the current table of recent changes. Schedules saveable as JSON in `user://training/` (like FM 07's files).
- **Rules**: in `_train_club`, replace the single focus. For each player, each category with load > 0 contributes progress proportional to `load × coach_quality × facilities.training`; quality drops 15% for each extra category the same coach covers. Injury risk ∝ sum of physical loads (Physical + Flying) × age; youth players capped at 2. The AI and "delegate" use default schedules. Weekly training rating (`Player.training_rating`, 1-10) = relative progress + professionalism. It feeds a column in Training and an owl from the assistant about the worst performers.
- **Mandatory calibration**: `tools/youth_curve.gd` and `life_audit --seasons 50` so the elite stays stable (~80 players with CA 150+).

### P5. Staff as people: search, hire, fire (M, or L together with P4)
- **Data**: the `Club.staff` roles become people `{name, role, attrs: {coaching, judging, medicine, broom_craft, motivation}, wage, contract_end, reputation}`; `World.staff_pool: Array` of free agents (regenerated at rollover).
- **Screen**: new `staff` screen (Club group) with the current staff, a "Search" button that lists candidates from the pool by role (filter by level and wage), "Offer contract" (wage and years; accepts based on club reputation), and "Dismiss" (pays what's left, like `MarketActions.remaining_wages`). Remove the staff block from `finances_screen.gd`.
- **Rules**: `staff_level(role)` becomes derived from the attributes (so as not to break `Progression.daily`, `_monthly`, etc.). An assistant with high `judging` improves the accuracy of the stars; the mediwizard, injury days; the broom master, wear.

### P6. Finance ledger, expiring sponsorships, and merchandising (M)
- **Data**: `Club.ledger: Dictionary` `"YYYY-MM" -> {gate, sponsor, merch, prizes, transfers_in, wages, staff, transfers_out, facilities, brooms, scouts}`; helper `Economy.book(club, kind, amount)` called from every place that touches `club.balance` today (`pay_wages`, `match_income`, `monthly_sponsor`, `execute_transfer`, `_upgrade`, `_buy_broom`, scouts in `_monthly`, prize money in `_season_rollover`).
- **Sponsorship**: at rollover, if `sponsor.ends_season < w.season`, 2-3 offers arrive by owl (canon brands from `WorldGenerator.SPONSORS`, amount based on reputation and league position) with "Accept"; today the contract never expires (minor bug).
- **Merchandising** [canon GoF 7: rosettes, figurines, robes]: monthly income = reputation × 0.02 × (1 + titles that year × 0.1) × supporter mood (P12). Add per-round prize money in the cups (today only the winner gets paid, in `_on_cup_finished`; amounts are [FILLER] in the pack).
- **Screen**: `finances_screen.gd` with "Summary" (current), "Month by month" (ledger table), and "Season" (totals and a bar chart of the balance) tabs; split between the transfer and wage budgets with a slider bounded by the board.

### P7. Monthly awards and team of the week (S)
- **Rules**: in `_monthly` (months with matches), for each league: player of the month = best average rating with ≥ 2 matches in the month (requires storing ratings by matchday: `Player.month_ratings`, cleared in `_monthly`, just like `World.minutes_month`); manager of the month = club with the most points scored in the month; young player of the month ≤ 21 years old. Team of the week: in `_weekly`, the 7 best-rated by position (1 K, 3 C, 2 B, 1 S). Reuse `Awards._give` with new `kind`s (`player_month`, `manager_month`, `young_month`); add +15 reputation to `Career` for manager of the month.
- **Screen**: section in `competitions_screen._league_stats` and a story in the Daily Prophet (`news.award`). An owl if the winner is yours.

### P8. Manager career: profile, resigning, and applying (M)
- **Screen**: new `manager` screen (or a tab in Board): details, reputation, rank, a table of `World.manager.career` (club, from, to, titles, best finish; saved today and never shown), manager awards (P7), nationalities.
- **Resign**: button with a seal; reputation −5%, `manager_unemployed = true`, the club picks a replacement à la `_ai_sack`.
- **Job centre**: list of clubs that just sacked their manager (`_ai_sack` already generates them) and of vacant national teams; "Apply" resolves in 3-7 days with the same rule as `Career.club_requirement` (better chance if the region matches the manager's knowledge).
- **New game**: second nationality and "past experience" (None / Former Sunday-league player / Former professional / International) that sets the starting reputation [game].

### P9. Advanced search and player comparison (M)
- **Screen**: in `explorer_screen._players` and `market_screen.gd`, a collapsible filter panel: min/max age, max value, max asking price, max wage, contract until (date), nationality, sex (Harpies), minimum broom, minimum stars, and up to 3 attribute conditions (`attr ≥ n`, only on attributes known according to `Game.knowledge_level`). Sortable columns and no 120/200 cap (paginate).
- **Compare**: "Compare with…" action in the player menu; a `compare` screen with two columns of attributes, color-coded differences, season stats, value, and wage. Respects the "?" for unknowns.

### P10. Pre-contracts (free agents at the end of their contract) (M)
- **Rules**: from January 1, a player with `end_day` ≤ the coming June 30 can receive a contract offer from another club without a transfer fee. New "Offer pre-contract" action (opens P1); if he accepts, `Player.pre_contract = {club_id, terms}` and in `_season_rollover` he moves to the new club instead of becoming a free agent. The AI does the same with the human club's best upcoming free agents (assistant notice: "X has signed with Y for next season"). The AI renews earlier the players it fears losing (`_ai_wants_renewal` brought forward to January).

### P11. Match: live ratings, opposing seven, and post-match talk (S)
- `match_screen.gd`: small table with your 7 and the opponent's 7 (live rating using `Progression.match_rating` on the partial stats from the `MatchResult`, condition, and a cross for knocked-out players).
- Post-match talk in `post_match_screen.gd` with the tones from `TeamTalk.TONES` and an effect on morale based on the result and personality (the function already accepts `pre_match`; add a `post` mode).
- Individual talk: in the team talk, a per-player dropdown (same tones).
- A real "Match programme": before the throw-off, the opponent's probable seven and their form (today the programme is just the header).
- Results of the other matches of the matchday in a bottom strip.

### P12. Supporters (M)
- **Data**: `Club.fans = {mood 0-100, size}` (size ∝ reputation).
- **Rules**: mood rises with wins, titles, and expensive signings; it drops with losses to rivals (`club.identity` already has rivalries), with selling the idol (the player with the most appearances), and with bad runs. It multiplies gate receipts (`match_income`) and merchandising (P6), enters as an area in board confidence (P13), and generates Daily Prophet stories. A match with high mood gives +2% starting morale at home [game].

### P13. Expanded board: confidence by area, requests, and ultimatum (M)
- `Club.board.confidence_areas = {results, finances, transfers, fans}`; overall confidence is the weighted average (compatible with what is read today).
- Manager requests in `board_screen.gd`: upgrade a facility (the board pays if confidence ≥ 60), new brooms for the squad, more scouts, a bigger wage budget; each with a response and a confidence cost.
- Ultimatum: if confidence drops below 25 between November and April, an owl "the board demands X points in the next 5 matches" before the sack.
- Club takeover by an investor [game]: a rare event (1% per season at clubs with a negative balance) that brings a new budget, a higher objective, and a Daily Prophet story.

### P14. Youth academy: intake day, academy, and feeder clubs (M)
- Youth intake day (July 1): an owl from the assistant with the newcomers and a line for each ("could become a star"), instead of them arriving without notice.
- "Youth academy" facility in `Club.facilities` (1-5) that raises the PA of youth players generated in `_make_filler` (+4 per level) and their number (2-4).
- A scout assigned to a school (P15) gives priority to sign graduates (as planned in `08-transfers-training-economy` §4).
- Affiliated clubs [game]: an agreement with a tier-3 club in the same region. It costs an annual fee, the big club can loan players there without the small one refusing, and it has first option on their youth players. Data: `Club.affiliates: Array`.

### P15. Scouts with assignments and reports (M)
- Assignments per scout: region (as today), **specific player** (report in 7-14 days), **next opponent** (report before the match with their probable seven, styles, and key players), **school**.
- Report as an owl with a card: scout rating (CA/PA stars), the hidden-attribute phrases that already exist in `player_screen._reports`, recommendation ("Sign him" / "Keep an eye on him" / "Not worth it"), and estimated price. Save `Club.scout_reports: Dictionary pid → {day, ca_est, pa_est}` and show the date of the latest report on the profile.
- Scout attributes: `judging_ability`, `judging_potential` (replacing the single "quality"), which introduce error into the stars.

### P16. Expanded press: pre-match, comments on players, and referees (M)
- Referees [canon: Madam Hooch, Hassan Mostafa; the rest FILLER]: `data/packs/1993-94/referees.json` with strictness; the engine uses strictness for the probability of fouls being called (`match_sim.gd`, fouls block) and the match programme shows it.
- Pre-match questions (on match day, before the programme): about the opponent, the pressure, an opposing player; answering confident/modest affects your own morale and the opponent's (mind games [game]; legal until 2014 [canon PM-2014]).
- "Comment to the press" action on any player's profile (praise, criticize, show interest). It moves his morale and, if he's at another club, his willingness to sign and the relationship with that club.
- After the match, a question about the referee if there were penalties.

### P17. Squad and profile: details (S)
- "Contracts" and "Stats" views in `squad_screen.gd` (planned in `10-screens-and-ui` §3.2).
- Promote/demote between first team, reserves, and youth from the actions menu.
- Vice-captain; designated penalty taker (`Club.tactics.penalty_taker`, read in `MatchSim._penalty` if on the pitch).
- Injury history (`Player.injury_history: Array` of `{day, kind, days}`), visible on the profile.
- Squad numbers [film], optional: `Player.number`, shown on the 2D counter.
- Rest: "Give a week off" action (+condition, −match sharpness).

### P18. Game options: autosave, holiday, and active leagues (S/M)
- **Autosave (S)**: in `game_session.after_advance`, on the 1st of each month save to `autosave` (rotating 2 slots); setting in `settings_screen.gd`.
- **Holiday (M)**: "Go on holiday until…" dialog; the engine advances with `auto_fix_lineup = true` and a bot like the one in `tools/stress_test.gd`/`life_audit.gd` (answers owls conservatively: reject bids for starters, renew the top 14, matches in "Score only"), stopping on a job offer or a sacking.
- **Active leagues (M)**: in New game, a checkbox per league; inactive ones are simulated with a fast model (result by squad strength, without `MatchSim`), which also speeds up daily advancement.
- Adding human managers/hotseat stays out of 1.0 (`11-scope-and-roadmap`), effort L.

### P19. Advanced transfers: installments, sell-on, and full loans (M)
- Bid with `installments: {count, period_months}` and `sell_on_pct`; installments are collected/paid in `_monthly` (record debt in `World.pending_payments`); the sell-on pays the original club in `execute_transfer` if the player is sold again.
- Loan with `{duration: until January | end of season, wage_share_pct, fee, buy_option}`; `Economy.return_loan` accepts a return in January; the option to buy generates an owl at the end.
- Agents offering players [game]: a monthly owl from an agent with 1-2 free agents or transfer-listed players suited to the budget.

### P20. Inbox, home, and search (S)
- Inbox: filters by sender/unread/pending, delete, and "Mark all as read".
- Daily Prophet preferences: which leagues and cups are included (`_relevant_news` reads `World.settings.news_filter`).
- Club desktop: next match, form, injuries, balance, and confidence on a single screen.
- Global search (clubs and staff) in the top bar.

### P21. All-time records (M)
- `World.records: Dictionary` per competition and global (longest match, most points, biggest margin, fastest catch, top scorer in a season and of all time), updated in `GameEngine.apply_result` and at rollover, seeded with the canon QTTA records (Plumpton 3.5 s; 3-month match). Screen: "Records" tab in `history_screen.gd`.

### P22. Sleep relief in long matches (M)
- During the overnight pause `MatchSim` already has, allow up to 2 reliefs per team for players with condition < 30% (only at that moment) [canon partial PS 10; `04-match-rules` §4]. UI: dialog in `match_screen` on receiving the `night_pause` event.

### P23. National team: international friendlies (M)
- National-team dates (`WorldGenerator.national_dates`) with friendlies in non-World Cup years for the national-team manager; call-ups and morale of those called up. Check with `07-competitions-and-world` before inventing qualifiers. Canon doesn't describe them.

### Discarded for low value or being out of scope
- Swappable skins (L, little value compared with the office theme).
- Full personal relationships between players and staff (L) are only worthwhile after P2, starting with "friends of the same nationality".
- Multiplayer (out of scope for 1.0 per `11-scope-and-roadmap`).
