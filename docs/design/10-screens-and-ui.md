# 10: Screens and UI

> Art direction: option A from the aesthetics research (`docs/research/04-harry-potter-games-aesthetics.md` §6), "the manager's office": dark wood frame, parchment panels, bronze rules, a wax seal to confirm, the *Daily Prophet* as the news front page. Navigation structure from FM 07 (`docs/research/01-football-manager-and-pc-futbol.md` §2bis.9): tree-style side menu, back/forward buttons, top bar tinted with the club's two colors, contextual Actions menu. Density and tables stay untouched; only the frame gets a costume.

## 1. Visual system

- **Palette** and **typefaces** from `04-harry-potter-games-aesthetics.md` §6.4-6.5: wood `#2B1D14`, parchment `#EFE4C8`, ink `#2A1E14`, dark bronze `#6E4E1E`, brass `#C9A14A` (only on wood), sealing wax `#8E1F1C`, green ink `#2F5A2A`, blue ink `#2E4A6B`. IM Fell English for titles; Alegreya Sans with tabular figures for tables and UI; Alegreya for prose; UnifrakturMaguntia only for the *Daily Prophet* masthead. All OFL.
- **Attributes 1-20**: 1-5 sealing wax, 6-10 soft ink, 11-15 green ink, 16-20 dark bronze in bold. The number is always readable; color is support.
- **Icons.** Line icons, 24 px (16 in tables), with our own set for Quidditch things (hoop, Quaffle, bat, Snitch, broom per manufacturer, owl, Galleon, wax seal).
- **Crests.** Drawn by us from the QTTA text, a single crest style with two colors and a line emblem. Never logos or crests from the films.
- **Portraits.** Layered generator in flat vector; plan B, a silhouette in robes with initials. Never actors' faces.
- **Club colors.** A 4 px vertical stripe with the two colors before every club name in tables; the top bar is tinted with the colors of the manager's club.
- Minimum design resolution 1280×720, scalable; tables readable at 13-14 px.

## 2. Common frame

```
╔══ top bar (wood tinted with the club colors) ═══════════════════════════════════╗
║ ◀ ▶   [crest] Puddlemere United        Mon 6 Sep 1993   1,240 G   [Continue ▶]  ║
╠═══════════╦═════════════════════════════════════════════════════════════════════╣
║ tree-style║  parchment panel with the title in IM Fell and a bronze rule         ║
║ side menu ║                                                                      ║
║           ║  ...content...                                                       ║
║           ║                                                                      ║
║ Inbox     ║                                                                      ║
║ Club ▸    ║                                                                      ║
║  Squad    ║                                                                      ║
║  Tactics  ║                                                                      ║
║  Training ║                                                                      ║
║  Reserves ║                                                                      ║
║  Finances ║                                                                      ║
║  Board    ║                                                                      ║
║ Transfers▸║                                                                      ║
║ Competit.▸║                                                                      ║
║ Schools   ║                                                                      ║
║ Prophet   ║                                                                      ║
║ History   ║                                                                      ║
╠═══════════╩═════════════════════════════════════════════════════════════════════╣
║ bottom bar: [Actions ▾]  tooltips/help   ·   save   ·   options                  ║
╚═════════════════════════════════════════════════════════════════════════════════╝
```

- **Continue** changes its label when something needs an answer ("Reply to the board", "Lineup pending").
- **Actions** offers what can be done with whatever is on screen (player: offer contract, transfer-list, talk; club: view squad, make an offer).
- Back/forward like a browser. Every player or club name is a link (blue ink).

## 3. Screens

### 3.1 Inbox (owls)

List on the left (sender, subject, date, unread in bold), message on the right on parchment with the sender's signature. Types: board, players, scouts (with the report attached), Department (sanctions, venues), national teams (call-ups), *Daily Prophet* (link to the edition). Those that require an answer show buttons; irreversible ones (signing) require the **wax seal**.

### 3.2 Squad

Dense sortable table: color stripe, name, position(s), age, nationality, broom (icon), condition (bar), morale (icon), form (●○●●●), key attributes for the position (4-5 columns), CA as the assistant's stars, value, contract (end), status (injury/suspension/called up). Filters: starters / reserves / youngsters / all. Configurable views (General, Flying, Technical, Mental, Physical, Contracts, Statistics).

### 3.3 Player profile

Following `04-harry-potter-games-aesthetics.md` §6.8: on the left the "card" (portrait, name, position, age, nationality, school, broom with 5 segments, caption with a press quote); in the center the attributes in four columns (Flying / Technical / Mental / Physical) with **progress arrows** (`05` §7); on the right status, contract, history and the scout's or assistant's report (phrases describing hidden attributes). Tabs: Profile, Progress (CA chart and recent changes), History, Contract, Reports.

### 3.4 Lineup and tactics

```
┌─ Lineup ────────────────────┐ ┌─ Tactics (main ▾ · attacking · defensive) ──────┐
│ K  Wood          cond 92 ●● │ │        ╭────────────────────────╮               │
│ C  Johnson       cond 88 ●● │ │   ⊙⊙⊙  │  C↑   C↑      C↑       │  ⊙⊙⊙          │
│ C  Spinnet       ...        │ │        │     B      B           │               │
│ C  Bell                     │ │        │  K          S (high)   │               │
│ B  Weasley F.               │ │        ╰────────────────────────╯               │
│ B  Weasley G.               │ │ Mentality  ───────●────   Tempo ────●─────      │
│ S  Potter        captain ⭑  │ │ Passing ──●──  Shooting ──●──  Pressing ───●──  │
│ ─ reserves ─                │ │ Hard play ──●──  Time wasting ──●──             │
│ K  Reserve · C  Reserve ... │ │ Chasers: [Hawkshead ▾]  Beaters: [▾][▾]         │
└─────────────────────────────┘ │ Seeker: catch [only if we're +50 ▾]             │
                                │ Keeper: [in the area ▾]   Vs opponent: [▾]      │
                                └─────────────────────────────────────────────────┘
```

Drag players between the list and the pitch; the Chasers' forward-run arrows can be stretched with the mouse. The assistant comments at the bottom: "The squad has mastered the Hawkshead to 60%".

### 3.5 Match day

1. **Match program** (borrowed from QWC / MinaLima programs): two crests, assigned moor, time (midnight on the Yorkshire Moors), referee and their severity, weather, the observer's report on the opponent, lineups. Pre-match talk.
2. **2D viewer** (`03` §8 and `04-harry-potter-games-aesthetics.md` §6.9):

```
╔═ wood ════════════════════════════════════════════════════════════════════════╗
║ [PUD] Puddlemere United   130  ·  1h 42m  ·   40  Holyhead Harpies [HOL]        ║
║        snitch: ○ not sighted   |  ⏸ timeout  |  ×1 ×2 ×4 ×8  |  tactics ▸       ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                      oval with heather, stands with banners                    ║
║      ⊚     ⊙          ●quaffle          ⊙                                       ║
║   hoops        ⊙ ◦shadow                          ⊙        hoops                ║
║             ⊗bludger            ⊙        ⊙  ⊗                                   ║
║                         ✦ (snitch, only if sighted: indicator at the edge)      ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║ Lee Jordan: "Johnson's clean through on her own and... GOAL! 130-40 Puddlemere."║
║ [condition of the 7: bars]   [fouls]   [statistics]   [live tactics]            ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

   - Height shown by token-shadow separation + scale; tokens shaped by position; the Quaffle always outlined; Snitch indicator with three states (not sighted / sighted by X / in pursuit), **never a probability**. The manager knows what they would know from the bench.
   - Collapsible live tactics panel (the same controls as 3.4; changes apply at the next stoppage and show as "pending" until then); the timeout button opens the team talk.
   - Modes (`03` §8): result only / text highlights without 2D / 2D with highlights / full 2D; speed. In "text highlights" the oval is replaced by the full-screen match report on parchment, one event per line with the game clock and the score, and the same tactics and timeout controls.
   - Long match: banner "Day 2 · hour 17 · night pause", option of sleep relays where applicable.
   - Proposal to end by mutual agreement: dialog with a seal.
3. **Post-match**: score, duration, statistics (shots, saves, Bludger hits, fouls, catches), player ratings 1-10, injuries, final talk, the next day's *Daily Prophet* headline.

### 3.6 Fixtures and results

Month by month: league matchdays (with moor and time), European Cup, Hogwarts Cup (if followed), World Cup, call-ups. Results of the matchday with duration and who caught the Snitch.

### 3.7 League table

Following `04-harry-potter-games-aesthetics.md` §6.7: POS, club (color stripe), P, W, D, L, **POINTS** (scored, in bold), points conceded, catches (8/12), form. A help banner the first time: "The league is ranked by points scored, like the *Daily Prophet* tables". A "as published in the *Daily Prophet*" variant (points only).

### 3.8 Training

Load sliders per category (`08` §1) for each group; coach assignment with their workload; a "recent changes" view with the arrows for the whole squad; the assistant's report on the squad.

### 3.9 Transfers and scouts

Search with filters (position, age, league, value, broom); shortlist; offers sent and received; transfer and contract negotiation on a sheet with a wax seal; region map with each scout's knowledge bars and assignment.

### 3.10 Finances

Gringotts ledger: balance, income and expenses per month, wage budget vs. spending, sponsors (contracts and offers), brooms (inventory and purchase), facilities (level and upgrade cost).

### 3.11 Board

Season objective, confidence by area (results, signings, finances, fans), requests, history of evaluations, manager reputation and job center.

### 3.12 Competitions

League (table, fixtures, statistics, awards), European Cup (bracket), World Cup (groups in progress, bracket, history), Hogwarts Cup and other schools' cups (table by total points, results).

### 3.13 Schools (youth academy)

Per school: houses, house squads with students aged 12-17, standouts according to scouting, next graduation; a "send scout" button. Hogwarts shows the 6-match canon calendar and Lee Jordan's commentary.

### 3.14 *The Daily Prophet*

Front page on newsprint (`04-harry-potter-games-aesthetics.md` §6.10): Gothic masthead, date, headline in IM Fell, three columns, "moving photos" of 2-4 frames, a "points only" table, opinion column, rumors. Editions by date; *Witch Weekly* and *The Quibbler* as secondary tabs for gossip and nonsense.

### 3.15 History

Encyclopedia of the game world (like the PC Fútbol database): honours of every competition, records (longest match, most goals, fastest catches: Plumpton 3.5 s), biographies of retired players, foundings. Fed by the canon data before 1993 and by what the game simulates.

### 3.16 New game

Data pack (1993-94), mode (career: start without a club / free choice of club), language, leagues to load (all by default; fewer = faster), "Book events" toggle (on by default; see `07` §1.2), manager's name and nationalities, previous experience.

### 3.17 Players

Worldwide player search (menu *Players*, formerly a tab of the Explorer): name, position and region, plus the collapsed FM 07-style advanced filters (age, value, wage, contract end, nationality, status, stars, one attribute). Sorted by ability among the players the scouts know, then the unknown by name; 200 rows at a time with "Show more". What is shown of each player follows the scouting knowledge level, as everywhere else.

### 3.18 National teams

The ranking of every national team (menu *National teams*, formerly a tab of the Explorer): flag, strength of its best seven, World Cups won; a row opens the team's page (§`07`). The former *Leagues* tab is gone, since *Competitions* already shows every league.

### 3.19 Returning to a screen

Back and Forward (toolbar arrows, mouse side buttons) restore what a screen had selected when it was left: the competition on *Competitions*, the school on *Schools*, the tab on the player profile and the encyclopedia, the open owl on the inbox (`UIScreen.nav_state`).

## 4. Accessibility and sessions

- Everything that took multiple clicks in FM 07 can be delegated: "Delegate to the assistant" in Training, Reserves, Friendlies, Press answers.
- Tooltips on every attribute and every slider, with the canon play that uses it.
- Help banners when pressing Continue during the first weeks (FM 07).
- No mandatory sound; discreet UI effects (quill, owl, seal, goal horn, crowd at three levels).
