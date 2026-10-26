# 11: Scope and roadmap

## Principle

The final scope is the **whole world**, but it is built outward from a core that works: first the simulator, then a match you can watch, then one season of one league, and only then the world. Every milestone leaves something playable and testable. The engine is calibrated first, because everything else (progression, transfers, league tables) depends on matches producing believable results.

## Milestones

### Milestone 0: Headless simulator (no UI)

- Godot 4 project created; `src/sim/` as a pure module with tests (custom headless runner `tests/run_tests.gd`; gdUnit4 originally planned).
- Full rules from `04`; event log from `03`; parameters in `data/shared/rules/sim_params.json`.
- Console tool: simulate N matches between two squads and dump statistics.
- Calibration against the metrics in `03` §4.
- Test squads: the 13 British clubs with canon players + generated filler.
- **Done when**: 10,000 matches in under a minute, metrics within tolerance, determinism verified.
- **Status: done (2026-10-02)**, except for speed. See the development log.

### Milestone 1: 2D viewer

- Log playback with simple sprites; display levels; speed; HUD.
- Live intervention: tactics (applied at the next stoppage), timeout, team talk.
- Line-up and tactics screen.
- **Done when**: you can watch a full Puddlemere-Harpies match, intervene, and what you see matches the log.
- **Status: base version done (2026-10-03).**

### Milestone 2: One season of the British and Irish League

- World: 13 clubs, squads, brooms, fixtures, table by accumulated points.
- Day-by-day loop with Continue and an inbox.
- Full player model (`05`): attributes, CA/PA, progression and decline, injuries, morale.
- Basic training; basic transfers (moves between league clubs, contracts); basic finances; board with an objective.
- *The Daily Prophet* from templates.
- Save and load; ES/EN localisation.
- **Done when**: five seasons in a row can be played without the world breaking, and you want to play a sixth.
- **Status: base version done (2026-10-02).**

### Milestone 3: The whole world

- The remaining leagues (`07`), procedural club and player generator with a canon layer on top.
- European Cup, World Cup with group stage and final, AI national teams with call-ups.
- Schools as youth academies: Hogwarts (visible: House Cup, youth intake) and the other schools as regional academies.
- Career mode with a ladder of job offers between leagues.
- Scouts by region; partial knowledge.
- **Done when**: 20 seasons simulated without intervention produce plausible leagues, World Cups and careers.
- **Status: done (2026-10-03)**, verified over 6 seasons rather than 20 (later 50-200 seasons; see the log).

### Milestone 4: Release 1.0

- Art direction applied (`docs/research/04-harry-potter-games-aesthetics.md`), polished UI, minimal tutorial, encyclopedia/history.
- Windows (installer) and Mac (.dmg) builds, signed or unsigned as decided.
- Data packs: 1993-94 included; other years (1996-97, 2014-15) as later add-ons.
- **Status: in progress.** See the development log.

## Out of scope for 1.0

- Managing national teams (to be added later; the World Cup already exists with AI). *(Later implemented in 0.6.0.)*
- Managing school teams (decided: not in v1; schools are youth academies). *(Later implemented in 0.8.0.)*
- Multiplayer.
- In-game data editor (the JSON files are hand-editable from day one).
- Voice acting, cutscenes, 3D.

## Main risks

| Risk | Mitigation |
|---|---|
| The engine doesn't produce believable matches, or the Snitch makes everything random | Isolated Milestone 0; calibration against a canon dataset; conditional Seeker instruction and a table by accumulated points spread the weight |
| GDScript is too slow to simulate the world | Simulation module isolated from the start; migration to C# planned |
| Content volume (130 clubs, 1,500 players) | Procedural generator + canon layer; filler marked |
| A dense interface that scares players off (FM loses players in the first hour) | Delegation by default, a minimal four-screen loop, an assistant that explains in plain text |
| Canon drift for convenience | Rule: don't invent rules; filler marked; author review at every milestone |

Markers used below: **[FILLER]** = invented content not found in the books; **[game]** = a game-design mechanic with no canon basis; **[QTTA]** = from *Quidditch Through the Ages*.

## Development log

Newest first.

### 2026-10-26: v0.12.1: closed trial with manual approval, Telegram sign-up alerts, goal sound

- **Goal sound.** The three-note fanfare is now the stands erupting: a crowd swell with twelve synthesized
  "voices" (resonant band-passed noise whose pitch sags like a shouted "yeaah") over a low rumble, 2.6 s, fading
  into the cheer (`tools/make_sounds.gd` `_goal`; still no third-party audio).
- **First deployment** of the browser version on the owner's VPS (v0.12.0; `deploy/README.md`): the API image is
  built on the box because the GHCR push from the release workflow is refused while the package is not linked to
  the repository (`API_IMAGE` empty).
- **Closed trial and sign-up alerts** (server). `ACCESS_MODE=approval` makes every new account wait on `/pending`
  (new profile status between `terms` and `complete`; the gate, `/api/me` and the season report treat it as
  incomplete) until the operator approves it on `/admin/users` (admins only, `is_admin` via
  `deploy/db/make-admin.sh`; approve, revoke, block with session revocation, unblock; `/admin/feedback` lists the
  last 50 reports). Migration `0006_approval.sql` adds `approved_at`/`approved_by` and approves existing accounts
  once; open access approves each registration as it happens, so flipping the switch never locks anyone out. A
  Telegram message (username and country only) goes to the operator per completed registration and per feedback
  submission (`src/notify/telegram.ts`). Privacy policy updated in 10 languages (approval date, Telegram).

### 2026-10-26: v0.12.0: quality pass, owls rebuilt, two engine bugs fixed, no crash on quit

A whole-repo quality pass (comment cleanup, simplification, bug review) and the follow-up program that resolved its
flags. Every unit ended in its own gate and every round in the full one: the test suite, the UI tour, seven real-app
drives, the formal model of the match day, and the server unit and integration tests against a real Postgres. Saves
use schema 6 and a save of any other schema is refused, so older saves do not load.

- **Fixed for players.** Quitting with Cmd+Q, the Dock or the window's close button no longer shows a crash dialog
  on macOS (a lambda held in a static variable aborted Godot at exit). Changing job on a match day that stopped over
  the lineup no longer leaves that match unplayed after a save and reload: the AI plays it and the day closes. On a
  day with both a club and a national-team match, changing national team no longer closes the day twice. The live
  match screen, blank for a short while during this work, renders again, and the verification harness now fails on
  any script error so a blank screen cannot pass.
- **Calendar and squads.** League and cup fixtures skip the national-team windows, so clubs no longer play while
  their internationals are away. Clubs keep at least two Keepers when they sell or loan players, and an emergency
  lineup prefers the player most familiar with the empty position.
- **Owls.** Every stored text goes through one typed module (`say.gd`), so money always shows its unit and names
  link to their pages. Open questions live in world records instead of inside the messages, with one way to answer
  them and one rule for what stops the day. Accepting a job or resigning waits until the watched match is finished.
- **Code.** Constant groups replace magic strings, collections are typed, world generation draws from one random
  stream per purpose, the calendar of yearly events is a table, and the career rules and the season report schema
  live once in `data/shared` for both the game and the server.
- **Server and deploy.** The web page language falls back to the browser's language. The api image builds from the
  repository root, the database name has one source, and the deploy scripts share their helpers.
- **Tooling.** `tools/check_scripts.tscn` compiles every script in seconds, and `tools/run_one_test.gd` runs a
  single test without the 19-minute suite.

### 2026-10-24: v0.11.0: external review applied, saves per career, fitness in matches, market, 2D viewer, pre-publish cleanup

An external agent reviewed the repository before its first public commit (publishability and a gameplay/performance
audit, plus a design proposal for the 2D viewer; reports kept outside the repo). Every finding was verified in the
source; the fixes below came from eight file-owned agents, each followed by a reviewer. Match results change in this
version (fitness), so the version is bumped; existing saves load unchanged and simulate differently from here on.

- **Pre-publish cleanup.** All references to the owner's earlier private project (and the numbered items of its
  security review) are gone from code comments, tests and docs. The server docs now state the security properties
  of this server. The release workflow's web archive is named `QuidditchManager-<tag>-web.zip` and the deploy
  scripts, `env.example` and the deploy README expect that name (they disagreed before, so the first `update.sh web`
  would have failed); `update.sh` accepts a version without the `v`. Every release zip carries `LICENSE` and
  `ATTRIBUTION.md`; the attribution links Godot's licence page. `.gitignore` also excludes private keys, saves,
  database files, logs and editor/agent folders. A personal note in `comp_argentina_league.json` is impersonal.
- **Saves per career (P1).** The slot name came from the club's short name only, so two careers with the same club
  overwrote each other. Each save's `meta.json` now carries the career id; a new career takes a free slot
  (`harpies`, `harpies_2`, …) and keeps it across autosave reloads and job changes (`manager.save_slot`); a typed
  name that belongs to another career is refused ("That name belongs to another career"). Saves from before this
  version adopt their old slot on load.
- **Fitness reaches the match (P1).** `Player.to_sim_player()` never copied the condition and the simulation
  started every player at 100 %, so resting and rotating changed nothing. The starting condition is now the
  player's (`SimPlayer.start_condition`); a drained squad is weaker and recovers in about four days (~10 points a
  day), so only congested weeks (matches 1-4 days apart) kick off at 60-70 %. Book-written results no longer reset
  their participants to 100 % either. Since the condition now matters, the post-match floor rose from 5 to 25
  (`GameEngine.POST_MATCH_CONDITION_FLOOR`). A long match leaves a Chaser exhausted, not out for a week (at 5 he
  needed six days to reach 60 and played the next match at −40 %; at 25 he is there in four). No RNG involved;
  results change, which the version bump already covers.
- **Short line-ups.** With fewer than seven available players the roles shifted (a Beater played as Chaser, the
  Seeker as Beater); line-ups are now built as (player, slot) pairs like the national teams'.
- **Market.** A swap could close without the swapped player (sold meanwhile) and still count as signed; the inbox
  "Accept" skipped the transfer embargo; a male player could be handed to a women-only club in a swap. One
  validator now runs before any money or player moves on both close paths (dialog and inbox). Stale or ineligible
  swaps void the deal, and an embargo refuses it without voiding (the owl stays open to retry when it is lifted; new owl
  `msg.embargo_blocks`). The market lists every candidate with "Show more" instead of the first 120, and sorting
  precomputes ability (441 → 26 ms on 2,700 players).
- **Advancing days without freezing.** `GameEngine.advance_day()` is now a thin wrapper over a resumable stepper
  (`begin_day` / `step_day(budget_ms)` / `day_result`, and `begin_close_day` after the manager's own match); the UI
  runs 12 ms of world per frame, so the loading overlay keeps animating through the monthly processing that used
  to block for a second (the web build has no threads). The monthly AI market runs club by club
  (`Economy.ai_transfer_begin` / `ai_transfer_club`). Same work in the same order. The stepped and the one-shot
  paths give identical worlds over 68 days against the pre-change engine.
- **2D viewer.** Rebuilt around explicit ball states and an action queue on one visual clock (see `03` §8): the
  Quaffle sits in the carrier's hand, passes fly to a fixed reception point and land in the receiver's hand, saves
  end in the Keeper's hands and restart to the named Chaser, goals rest at the hoop through the replay; flights are
  never cut by later events. The log carries the play context (passer/receiver, Keeper, restart target) as data
  only. The simulation of a given seed is unchanged. "Next moment" in 2D keeps playing afterwards; replays include
  the goal arc and the Snitch dive. Bludger hits named the Beater instead of the victim; fixed.
- **UI.** The Explorer is split into *Players* and *National teams* (the Leagues tab was redundant with
  Competitions). Back/Forward restore what a screen had selected (the competition, the school, the profile tab).
  On the line-up screen a bench player dragged onto a starter in the list replaces him (starter on starter swaps);
  the injury-days column fits "✚ 57". The house rosters on the Schools screen no longer need a horizontal scrollbar.
- **International duty.** National teams call up their seven three days before each match (the whole fortnight
  ahead in the World Cup final stage); the players are away until the day after the match: unavailable to their
  club or house (`Player.is_available()`), still fit for the national team (`Player.is_fit()`), shown as "✈ n" on
  the squad and line-up lists and "On duty with …" on the profile; the club gets a call-up owl. Before, the seven
  was picked on the match day and the club found out afterwards.
- **Tests.** Nine new regression tests (slots per career, condition reaching the match, short line-ups, stepper
  equivalence, the three market cases, play context in the log, international duty).
- **Feedback form on the website.** `/feedback` (footer link and a line on the landing page) takes bug reports and
  ideas from anyone, signed in or not: kind, message (10-4000 characters), an optional reply address and an optional
  version/platform line (`?kind=` and `?context=` prefill it, so the game can link to it). Rows go to a new `feedback`
  table (migration `0005`, pruned after 12 months, in the account export; the account link is cleared when the
  account is deleted) and a copy is mailed to `FEEDBACK_TO` when set; a failed mail keeps the row. Honeypot field,
  5 per address per hour and 60 per day in all (`auth_rate_events`), 303 to a thanks page so a refresh does not
  resend. 19 new strings (`web.feedback.*`, the footer and landing links) in 10 languages; the privacy policy lists
  what is kept and for how long. The game's About box links to the form with the version and platform prefilled
  (`UI.feedback_url`: the page's own origin in the browser build, `application/config/site_url` on desktop; no link
  while that setting is empty).
- **README screenshots** recaptured from this version (English, Players/National teams menu, 30 played days).
- Left for later from the audit: in-game display of the engine's licence notices; a single AI club's monthly
  market turn can still take ~0.2 s (one step of the stepper).

### 2026-10-22 (5): Career reports for the ranking; saving explained on the landing page

- **Career reports.** On the web the game sends one summary per finished season of a career (reputation, club,
  titles, seasons managed) to `POST /api/career/season`; migration `0004_careers.sql` stores them per account
  (`careers`, `career_seasons`), included in the data export and deleted with the account. Plausibility checks
  (reputation range and per-season gain, dates inside the season, seasons in order, titles never decreasing, one
  owner per career, daily limits) flag a career for good and keep it out of rankings. `GET /ranking` shows the top
  100 overall or by country (best unflagged career per player), and a map view with a seal per country on the
  game's world and Europe atlas maps. Tested end to end in the browser: sign-in by
  email link, registration, a season on holiday, the report stored and the player listed. Privacy policy updated in 10 languages. Two national-team reputation bonuses were not clamped to
  the 200-5000 scale; now they are.
- **Landing page.** A "Your saved games" box explains that games are saved in the browser, never on the server,
  what makes them disappear, and how to export and import them.

### 2026-10-22 (4): Bug hunt round 3: 47 bugs and the text and canon fixes

Eight agents played the web build for about 12 seasons each, hunting bugs in the new features (reports kept outside
the repo); all 47 reported bugs were confirmed in the source and fixed by six file-owned packages, each reviewed.

- **Saves.** Every change marks the game unsaved (`Game.mark_dirty()`: training, line-up, team talks, inbox answers,
  contract and market actions), so the leave-page warning covers them; Load in the in-game Save/Load dialog asks
  first; save names that would hide a save or overwrite an autosave slot are refused; two quick saves in a row no
  longer give a false "not finished" warning.
- **Contracts and money.** Contract owls shrink as players are renewed and close when nobody is left; AI clubs can
  poach the manager's expiring players only from 1 February, after the January owl; players out on loan are in the
  owls, the renewals, the Squad screen (a "Loaned out" group) and fully known; the debt embargo also stops free
  signings; the ultimatum stops a holiday; holiday renewals keep the best players first within the budget; offers
  (transfer bids, the national-team job) expire after 14 days.
- **Career.** League fixtures change every season (shuffled with a private seed); a mid-season hire gets an
  objective that fits the current position and can't be sacked by that season's verdict; cups count towards the
  verdict; seasons cut short by a sacking count in the career; meeting the objective brings at least a same-level
  offer; friendlies no longer count in season stats.
- **Matches and press.** Time-outs have a cooldown and the button disables; the post-match key moments always keep
  the catch and the final whistle; press conferences never shrink to one repeated question and the memory expires;
  "best player on the pitch" only for the real man of the match; former-club questions survive derbies; "your first
  matches in charge" only once; the 2D view no longer goes stale after "Next moment" or "Simulate to the end", keeps
  players inside the oval and fades the goal flash.
- **Hogwarts.** "Decide later" on tryouts no longer blocks Continue; no fill and no tryouts owl in years without a
  Cup; places are counted on the day the tryouts open (after Ginny's move to Chaser); Ron is the Keeper candidate in
  1995; the missing canon players were added (Kirke, Sloper, Robins, Peakes, Coote, McLaggen, Dean, Harper, Vaisey,
  Urquhart, Bradley, Chambers…); Ginny joins the Harpies' first team and canon players are never culled; the Whomping
  Willow item fits any result.
- **Canon and text.** The 1994 World Cup's nine qualifiers win their groups and Ireland meets Peru in a semi-final;
  "like Krum in 1994" only after the final; Bagman no longer "now heads" the Department in 1996; the 1932 Appleby-
  Vratsa match retold as in QTTA; school and sponsor names in each language's official form; Spanish ordinals 8.º;
  localized durations, list separators, short dates and colons; singular forms; capitalised Quaffle, Snitch and
  Bludger; translated position letters in every table; many press, owl and award strings reworded.

### 2026-10-22 (3): Owner's UI requests

- **Navigation.** The mouse side buttons go back and forward like the top-bar arrows; New Game lost its own "Back"
  button (the top-bar arrow does it).
- **New Game.** A legend explains the map's seals (red: a league of clubs; blue: a school and its houses) and a
  filter shows all, clubs only or schools only, on the maps and in the list; the club list has a fixed width (it
  used to grow or shrink with the profile shown next to it).
- **Right-click menu on players** (tables, names, links in owls and news): "View profile" plus the profile's own
  actions; an action opens the profile and runs there.
- **Player history.** A match-by-match table (date, competition, opponent, score, goals, saves, Snitch, Bludger
  hits, rating) above the season totals. Every player keeps his last 20 matches, the manager's own players their
  last 60 (`Player.match_log`, compact arrays to keep saves small).
- **Post-match.** The board's reaction and the team talk sit under the ratings in the left column, and the ratings
  table is only as tall as its seven rows.
- **2D match.** The Quaffle stays in the carrier's hand (it used to trail behind a flying carrier and looked always in
  the air) and a loose Quaffle is picked up by the nearest attacking Chaser; rain and snow fall over the whole view
  again, stands included; fog is a soft haze instead of hard-edged discs; the Snitch-catch commentary line is no
  longer oversized.

### 2026-10-22 (2): Text variety, rivalries, Hogwarts tryouts, canon data

- **Newspaper.** Fillers come from dated pools in `data/shared/news_fillers/` (Daily Prophet column, The Quibbler,
  Witch Weekly, Which Broomstick?: about 100 items in 10 languages, from QTTA lore to Snorkacks), gated by the books'
  chronology (nothing about Voldemort's return before mid-1996, Fudge only while he is Minister, the Firebolt "price
  on request" only until 1995) and not repeated within 20 editions. Before, five items repeated for 30 seasons.
- **Press.** Context-triggered pools (19 pre-match, 32 post-match questions: streaks, derbies, the manager's former
  club, a former player now with the rival, injured stars, cup ties, weather, long matches), no repeat within the
  last 5 conferences, and "let your assistant answer".
- **Commentary.** Every frequent event has 5-8 variants (224 new lines in 10 languages).
- **Rivalries** (`src/game/rivalries.gd`). The canon derbies stay in the British and Irish League; the other leagues
  get 1-3 invented derbies each, marked [FILLER] (table in `07`). A derby gets a Prophet preview, +25 % gate money,
  stronger morale and fan swings, and the board may ask to finish above the rival. The Prophet also notes a return
  to the manager's former club and a former player starring against it.
- **Hogwarts mode.** At the September tryouts the manager picks the house's new players among 3-5 candidates per open
  place (owl and dialog; the captain decides if the manager doesn't). School matches are calibrated toward the
  books' scores (canon average 256-72; before, 270-350 and Keepers with 72 saves). Club academy players are 18 when
  they leave school (there were 16-year-old graduates).
- **Canon data.** Ron and Ginny join the Gryffindor team in 1995-96, not 1993; Ginny becomes a Chaser in 1996 and
  stays one at the Harpies; Bulgaria and Ireland field the books' sevens until the 1994 final; feminine Slavic and
  Icelandic surnames for women (players, staff, scouts, managers); Tokyo and Kyoto clubs spelt in English; Chudley
  Cannons show their last title (1892) and no invented founding year; Plumpton's 3.5-second catch was against the
  Caerphilly Catapults.

### 2026-10-22: Second 30-season playtest: saves, squad protection, titles, legibility

Ten agents played the web build for 30 seasons each (1993-94 to 2022-23; reports kept outside the repo). No crash
and no memory growth (JS heap 100-200 MB; saves plateau at about 9.5 MB). Fixed by six file-owned packages, each
checked by a reviewer against a pre-change snapshot:

- **Web saves were not durable when the toast said so.** On the web `user://` is memory first; Godot copies it to
  IndexedDB seconds later, and a reload in between lost the save (the owner's "saved after 4 matches, lost 2").
  The game now shows "Saving…", keeps the leave-page warning armed and says "Game saved." only once IndexedDB holds
  the new `meta.json` (`Platform`, polled through `JavaScriptBridge`). Cmd+S saves on a Mac; closing or reloading a
  tab with unsaved progress asks first; the save dialog's "Main menu" asks too; an autosave follows every match the
  manager plays; the title screen has "Continue"; load lists show name, in-game date and "saved N min ago". The
  web loading card (flying Snitch) never appeared because of a `%` in its CSS template; fixed.
- **Players no longer walk away unnoticed.** Academy players enter the January contract review and are extended to
  19 like AI academies do; a new urgent 1 March "Contracts expiring" owl lists names and wages and stops a holiday
  ("Go to the squad" keeps it open, "Let them go" closes it); AI pre-contracts for your players are urgent; holiday
  renewals respect the wage budget; a loan never outlasts the contract; after-school offers exclude students the
  books send elsewhere (Wood, Ginny); a loanee's contract can't be changed by the borrowing club.
- **Career and board.** Job offers capped at 1-3 a summer, quoted after the summer cash drift, with a cooldown after
  a refusal; objectives and wage budgets are re-set every July from reputation rank, and "Win the league" means 1st;
  debts bring a board warning, a transfer embargo, an ultimatum and finally the sack; Manager of the Month needs
  matches and keeps a lifetime count.
- **Seasons have a moment.** A Prophet item for every league champion, a trophy owl, and a 1 July season review owl
  (position, objective, trophies, awards, departures and arrivals). No more "table after round 0".
- **World Cup canon.** The two book finalists are seeded into opposite halves; the 2014 final is in the Patagonian
  Desert; call-up owls are one per national team.
- **Text and links.** Owls carry entity ids, so names shared by two players, list entries and key moments link
  correctly, and names inside competition names no longer become false links; money in owls is formatted at display
  time ("12,000 G") and translated text no longer freezes in the language active when the owl arrived; award owls
  read naturally; `[i]`/`[b]` render in owls; filler news carry their own mastheads (The Quibbler, Witch Weekly,
  Which Broomstick?).
- **Legibility.** Hovered and selected table rows keep dark ink (they were white on pale yellow); the UI font no
  longer swallows spaces next to digits; Board and Training scroll; stray empty rows under table headers removed;
  action owls record the answer given; "Accept the job" asks first; the inbox keeps the owl you were reading.
- **Matches.** Commentary view paced at about one line every 2 s at normal speed with holds on goals, sightings and
  the catch; optional auto-pause on a Snitch sighting (on by default); Bludger lines throttled on screen; Pause no
  longer sits where "Finish" appears; a side with no Chasers and no Seeker that is behind ends the match by mutual
  agreement instead of conceding for hours.
- **Development.** Growth tapers above 16 so walls of 20s are rare; individual training no longer drains a player at
  potential; a mentor who left or retired is cleared; academy intakes favour the positions a squad lacks.

### 2026-10-21 (2): Full code review, UI links, web accounts service

- **Full review.** An 11-dimension review plus a gap pass found 254 candidate defects; adversarial verification
  confirmed 200 (8 high, 59 medium, 133 low). They were fixed by file-owned packages, each checked by a verifier
  against a pre-change snapshot. Highlights: red cards are served (they used to ban a player for life); the
  Umbridge ban no longer soft-locks Gryffindor in 1995-96 (tryouts count only eligible students); a human fixture
  can no longer be skipped when a national-team match shares the day or after a reload; pre-contract signing fees
  are charged; accepted transfers are revalidated; the market no longer crashes for an unemployed manager; the hidden
  2D pitch no longer pauses Commentary/Score-only matches; World Cup canon finalists keep the stats of the run that
  counts; catch bonuses are paid; minutes are the real minutes on the pitch; June awards are computed before the
  rollover; clubless and abroad players develop; brooms are serviced every summer and the workshop slows wear;
  stored messages keep keys (`@comp:`, `@t:`, ranks, positions) so they follow the language; saves keep full float
  precision; every pre-1970 date was one day late (`WDate.from_ymd`). 55 regression tests were added.
- **Links everywhere.** Player, club and country names in tables, labels and lists open the player profile, the club
  page (now with the squad at the top) or the new national-team page (`national_screen.gd`: squad, pool, World Cup
  record; "Tactics and line-up" only for the team the manager runs, route `national_tactics`). Links are underlined
  under the mouse with a pointing hand. Prose in owls and the Prophet is not linked (messages store names, not ids).
- **Line-up drag and drop.** A player can be dragged from the squad table onto a pitch token (same assignment path
  as click-then-slot).
- **Interface.** Visible scroll bars; the side menu always fits the window (compact style, text shrinks if needed);
  option buttons are as wide as their longest option; hovering no longer shifts text in tables and option buttons.
- **Web accounts service** (`server/`, `deploy/`, `.github/`; design in `12-web-version.md`): Google sign-in and
  email magic links (Resend); registration with username,
  optional first and last name, required country and optional region and city picklists (GeoNames, CC BY 4.0, for
  a future players' map); minimum age 13; account page with data export, session list and deletion; privacy and
  terms in 10 languages; Caddy gate on `/play/`; CI for the server and the Godot suite. Not deployed. In the game:
  Settings shows the signed-in account on the web (`Platform.fetch_viewer`) and every career has a `career_id` for
  the future ranking.
- **Incident.** A read-only review agent ran `tools/author_clubs.py` and deleted 159 generated club files; they were
  restored byte-identical from an exported `.pck`. Workflow agents now get an explicit list of tools they must not run.

### 2026-10-21: Fixes from the 30-season browser playtest

Ten agents played the web build for 17 to 30 seasons each (reports kept outside the repo). No crash, freeze or memory runaway (120-410 MB). Fixed:

- **Careers that could not restart.** After two or three sackings the manager's reputation fell below every club's requirement and no offer could ever arrive; now an unemployed manager always hears from the least demanding clubs, Holiday keeps running while unemployed, and one open offer per club.
- **Contracts.** At 1 January an urgent owl lists the contracts ending on 30 June (on Holiday the assistant renews whoever an AI club would keep and reports it). A player with a pre-contract can no longer be "renewed" and still leave. Contract years signed from June count from the next season (`Contracts.end_day_for`). Renewals with no signing fee work with the club in the red.
- **Board.** Objectives scale with the size of the league (`Economy.objective_pos`: "avoid last" is 8th in a 9-club league). The monthly review and owl wait for the first league match (the table reset on 1 July is alphabetical). The finances score uses cash against a year of wages plus the monthly trend. Facility requests only when the club can pay; a warning owl when the club goes into the red; the transfer budget is enforced, capped at the cash, and gets half of sale fees.
- **Changing clubs.** Pending owls, bids and negotiations of the old club lapse; career spells count seasons correctly when the move is on 30 June or 1 July.
- **School mode.** No pre-contracts for students; graduation uses the same 31 August cut-off as the school year (Spinnet, Pucey, Montague and Warrington left a year early); tryouts always fill the positions needed to field a team, also mid-season after a book event; book events (Nimbus, Firebolt, Umbridge ban, captains, the twins' and Harry and Ron's departures, Cedric's death in June 1995) appear in the Prophet and as owls; no Hogwarts Cup in 1997-98; no duplicate student names.
- **Canon.** Bagman calls matches until June 1995 and Lee Jordan until June 1996, then the neutral voice. The book finalists of a World Cup reach the written final through the bracket (in 1994 Ireland had been knocked out and was then credited with the title).
- **Matches and press.** The pre-match press conference is offered before kick-off from the match button, old ones expire, and an ended conference says so instead of an empty page. Key moments always include the catch; a team's Snitch sightings count the Seeker who joins the chase.
- **Screens.** History lists every season's awards per competition; retired players keep their names in awards and records (`World.former_names`); the club page scrolls; the league table in Competitions shows every club; cups in the selector show their season; the training focus and mentor columns open their dialog; facility upgrades ask for confirmation; Explorer search finds national-team players abroad; one "new captain" owl per day.
- **Text.** The Prophet masthead is translated; stored message, news and record values (competitions, awards, objectives, houses, facilities) are shown in the current language (`Game.resolve`) when they are stored as keys (not yet everywhere: the league in award news and the rank in the end-of-season career owl still store translated text); ordinals, thousands separators and inbox dates per language; singular forms for owl counts; English possessives and pronouns; five canon player traits translated; a sponsor name in Spanish replaced by Honeydukes.
- **Balance.** League prize money scales with the final position; AI clubs buy newer brooms over the years; the best keeper award goes by rating, not by saves (it rewarded keepers of weak teams).

### 2026-10-20: Web playtest fixes

- **Fonts in the browser.** The web build has no system fonts, so missing characters showed as boxes: the "◂ Back" caret, ★ ● ✚ ⊘ ⏸ and every Japanese and Chinese character. The game now bundles Noto subsets (`assets/fonts/fallback/`, built by `tools/make_fallback_fonts.py`: symbols plus the characters the game uses, JIS level 1 kanji and GB2312 level 1 hanzi, about 2.5 MB). Fallback chain (`ThemeBuilder._fallbacks`): titles in IM Fell or UnifrakturMaguntia fall back to Alegreya (Cyrillic), then symbols, then CJK (system fonts on desktop, the bundled subsets on the web, Japanese or Chinese first by language). New test `test_fonts_cover_translations`.
- **Manager name required.** The start button on New Game stays disabled, with a hint, until a name is typed (no more "Anonymous manager").
- **Defaults.** English on first launch (it used to follow the system language) and "Match Day" as the default music.
- **Loading screen.** The boot splash is the game logo on the wood colour instead of Godot's (it is also what the browser shows while loading).
- **Side menu on the web.** 15 % smaller text, icons and rows (`ThemeBuilder.MENU_K`), since the browser leaves less height than the desktop window.

### 2026-10-19: Web version planned

Plan for a browser build in [12-web-version.md](12-web-version.md): same project and code as the desktop builds (one more export preset plus a small `platform.gd`), static files served from a Hetzner VPS behind a Cloudflare Tunnel, saves downloaded and uploaded by the player (nothing stored on the server), CI and releases on GitHub with no secrets. Done the same day: the `Web` export preset (single-threaded; `run_blocking()` runs on the main thread there) plays in Chrome; crests and portraits imported as lossy WebP (web data 115 → 47.5 MB, desktop builds smaller too); saves export to and import from `.qmsave` files on every platform (`SaveManager.export_file/import_file`, `Platform.offer_file/pick_file`). Pending: CI, releases, the server and the domain.

### 2026-10-19: Release polish

The official Gravett patches and Pottermore house crests were moved out of the repository (only the AI versions remain). The art import tools (`import_crest_sheets.gd`, `clean_prompts.py`, `add_ai_prompts.py`) are in English and read the sheets from `../Quidditch Manager - work/sheets/`; broom batches renamed `brooms_N`. The Windows `.exe` now carries the Snitch icon (`assets/icon.ico`, built by `tools/make_ico.py`; `application/modify_resources` on). Firebolt handle corrected to ash `[PoA 4]` (Pottermore says ebony; the book takes precedence). The seven brooms without a description got one, and the README title screenshot shows the title background.

### 2026-10-18: Localized data names

Player-facing names that came straight from the data are now translated into all 10 languages: the 101 neutral league venues are `venue.*` keys, the broomstick tooltips in the encyclopedia are `broom.notes.<id>` keys (internal source markers removed), `data/shared/city_names.json` holds every club town in the nine non-Spanish languages, and the Chaser formations (Hawkshead, Porskoff Ploy, Woollongong Shimmy, Reverse Pass, formation looping) use `formation.*` keys in the lineup and match screens.

### 2026-10-18: Public release preparation

Repository translated to English (docs, code comments, tool output), MIT license, third-party Harry Potter artwork (Emily Gravett patches and uniforms and their AI redraws, Pottermore Hogwarts crests, film still on the title screen, World Cup image) reviewed: the film still on the title screen, the World Cup image and the AI crests/portraits based on the Gravett patches and Hogwarts crests stay in the repository, credited in `ATTRIBUTION.md` as not covered by the MIT license; the official Gravett patches and Pottermore house crests were moved out of the repository and are listed in `.gitignore`; AI art source sheets and references moved out of the repo; the default manager name is no longer hardcoded.

Also: documentation-only text in `data/` (`notes`, `_comment`, house inspirations) translated, with markers `[FILLER]`, `[inferred]`, `[game]`; theme colour constants and Label type variations renamed to English (`INK`, `PARCHMENT`, `BRASS`…, `Body`, `Caption`, `TableText`, `Prose`); `tools/patch_crests.gd` now also embroiders the 13 British club and 4 Hogwarts SVG crests so the public build has a patch for every club; the UI tour writes `report.txt` with English categories; new README, CONTRIBUTING, LICENSE and English ATTRIBUTION; README screenshots in `docs/screenshots/` taken without third-party art. Tests: 899 passed.

### 2026-10-17: All AI art complete

- With East Asia batch 4 (Busan and Daegu), all 194 clubs and 44 houses have a character portrait, and the 13 British ones are clean (no leftover lettering).
- All 27 brooms are redrawn in the game's style (no Warner images left in `assets/brooms/`).
- Crests for the four Durmstrang houses arrived. All AI batches (crests, portraits, brooms) are complete: 238 crests (194 clubs + 44 houses). If clubs or houses are added, `python3 tools/add_ai_prompts.py` generates their batches.

### 2026-10-16: House portraits and clean British portraits

- Imported the 16 house sheets for Castelobruxo, Durmstrang, Kapadokya, Koldovstoretz, Mahoutokoro, Nilgiri, Uagadou and Wollemi (32 characters: all 44 houses of the eleven schools now have a figure) and 8 clean copies of British portraits (Appleby, Ballycastle, Caerphilly, Chudley, Falmouth, Holyhead, Kenmare, Montrose).
- "Project info" renamed "About"; attribute abbreviations in English (Spd, Acc…); school venues translated (`venue.school`, `school:<id>`); Apps/Goals columns translated; New Game figures no longer truncated in other languages.

### 2026-10-12: Eleven schools, Koldovstoretz, own brooms

- **Koldovstoretz.** Youth players of Russian clubs come from Koldovstoretz (in Russia per JKR's writings), not Durmstrang.
- **Eleven schools with houses and a House World Cup.** The 3 schools JKR doesn't name are [FILLER] (Wollemi in Australia, Kapadokya in Turkey, Nilgiri in India) and cover regions without a school. The 9 schools without canon houses get 4 invented houses each, based on local folklore (36 houses; `data/packs/1993-94/schools/*.json` with colours, emblem and inspiration). All 11 play their own Cup (44 houses, ~400 students) and are manageable from New Game, with a seal on the map. In June the **House World Cup** [FILLER] pits the champions against each other in a knockout with a rotating host (`GameEngine._create_house_world_cup`); it counts in the school table ("WC" column) and history. Temporary crests drawn by `tools/make_crests.py` until the AI ones arrived: 9 new crest batches and 18 portrait batches (`tools/add_ai_prompts.py` now also generates house batches). 31 new portrait sheets imported (37 batches left).
- **Own brooms.** `docs/art/brooms/prompts.md` with 9 batches of 3 brooms (all 27, in pencil and watercolour like the portraits) to replace the Warner/HP Wiki images. Imported with `godot --headless --path . -s tools/import_crest_sheets.gd -- brooms` (strip cropping, `crop_badges.gd --rows`).

### 2026-10-11: Per-player brooms, playtest fixes, 2D redesign, grounds, weather, FM 2007 features

- **Per-player brooms.** When buying a broom you choose which player gets it (dialog listing the squad: position, current broom, speed and condition; starters in bold; the assistant pre-selects the starter with the worst broom). Previously the assistant assigned it.
- **Playtest fixes.** New Game: the expectation sits in a fixed-width box with two lines of text (the card no longer resizes per club). Schools: the graduates table grows with its rows (they were hidden). Player profile: the Actions menu for another club's player has three entries (Negotiate…, Request report, Shortlist) and "Negotiate…" opens a dialog with every way to sign him (bid, haggle, instalments, swap, loan, loan with option, pre-contract). 2D: during a goal/catch animation the other tokens keep flying (`Pitch2D._move_players`); nobody moves after the final whistle. Finances: long KPI labels (sponsor, ground) widened the page beyond the screen; KPI labels now wrap (`UI.kpi`). Top bar: "Play vs X" appears as soon as the next match falls within the 3 days Continue advances. Match controls: a single Resume/Pause button, "Next moment", view and speed; commentary detail moved to Settings. Portraits: 42 more sheets imported (110 of 202 clubs).
- **2D viewer redesign.** Playtesting feedback: players were giant and the crowd were dots. New consistent scale, in the style of Football Manager's 2D: small tokens (17 px circle in the club colour with a secondary-colour ring, position letter, the broom as a tail showing direction, pulsing gold ring on the ball carrier, red cross on injured/sent-off players), shadows offset by altitude (Seekers further and fainter; all shadows drawn before tokens), grass in twelve soft stripes, thin translucent lines, hoops seen from above (gold ring with pole and shadow), Quaffle, Bludgers and Snitch to scale (`Pitch2D._s()`, `_draw_token`). The crowd is now in proportion (one person ≈ a fifth of a token, as in FM).
- **Club grounds and stands.** [game/FILLER: in the books professional Quidditch is played on remote moors, and the only stadium described is the 1994 World Cup one, for 100,000 people, on Dartmoor.] Each club has a named ground (landscape type of its region + town, translatable: `ground.kind.*`; `data/shared/grounds.json`, `src/world/grounds.gd`) with capacity by tier (tier 1: 22,000-32,000; tier 2: 8,000-15,000; tier 3: 2,750-5,500; computed once per club, old saves included). League, national cup, continental and friendly matches are played at the home ground (`venue = "ground:<club>"`; finals stay at the competition's neutral venue). Attendance per match (`Grounds.attendance`: capacity × occupancy from fan mood, opponent and cup status) is stored in the fixture and shown after the match; gate receipts scale with occupancy. In 2D, stands (`src/ui/widgets/stands.gd`, a layer drawn once behind the pitch): sectors split by radial aisles, rows of seated spectators (head and shoulders) in home colours plus an away sector, a middle aisle on large stands, fence, roof with shadow and both clubs' pennants; width grows with log capacity (2,500 → 14 px, 30,000 → 36, 100,000 → 50) and empty seats show according to occupancy. Rain, snow and weather darkening are now clipped to the oval (they used to stain the corners). Ground and capacity on the club page and in Finances.
- **Weather.** Each match's weather comes from the home region's climate and the hemisphere's season (`data/shared/climate.json` [game/FILLER]: N/S/tropical hemisphere, chance of rain and of snow in midwinter; Argentine or Australian winter is June-August; no snow in the tropics). New **snow** in the simulator (sightings ×0.6, passes ×0.9, injuries ×1.25, tempo ×0.85), and bad weather slows play (`MatchSim._w_tempo`: rain 0.95, storm 0.88, fog 0.97). Over 200 matches: snow matches last 133 min on average (105 in clear weather) with 1.1 injuries per match (0.6). In 2D: white pitch with swaying snowflakes (snow), diagonal drops and dark grass (rain), heavy rain with lightning (storm), white veil (fog) and gusts (wind). Forced-weather capture: `--weather snow`.
- **2D viewer review.** Playtesting feedback: balls and players flew around with no relation to each other. Causes: (1) at normal speed the 2D advanced 20 ticks/s (100 s of match per real second), and each tick changes the carrier 21% of the time, possession 12% and zone 18%, several passes and turnovers per second, impossible to follow; (2) Bludgers chased anyone on the pitch, switched victim every 1-2 s and teleported on each hit, and Beaters copied them; (3) defending Chasers parked on the opponent's side; (4) Seekers circled the whole pitch and the Snitch appeared anywhere; (5) the Quaffle was drawn stuck to the carrier (passes were jumps), and saves and missed shots were overwritten by the next frame (saves also went to the wrong hoops); (6) uncapped exponential interpolation made distant targets cross the pitch instantly. Now: 2.5 / 5 / 12 ticks/s (≈ one pass per second at normal speed; a 2-hour match takes ~5 min, with "Simulate to the end" to shorten it), max speed per role (`Pitch2D.SPEED`), smoothed play anchor with a side lane per Quaffle-carrying Chaser, attackers spread and defenders between the Quaffle and their hoops, each Beater fights for his Bludger, Bludgers chase players near the play and bounce away (no jumps) after a hit, Seekers patrol above and below the play, the Snitch appears near whoever spotted it and flies continuously, the Quaffle travels on passes, goes to the Keeper on saves and wide on misses. Multi-frame capture: `--film N --gap F`.
- **Football Manager 2007 features.** Research in `docs/research/06-fm2007-missing-features.md` (23 prioritised gaps). Done, with tests in `test_contract_negotiation`, `test_happiness` and `test_fm_features`:
  - **P1 contract negotiation** (`src/game/contracts.gd`, `ContractDialog`): wage, years, squad role, signing bonus, goal/catch/title bonuses, yearly rise and release clause; demands based on deserved role, ambition, loyalty and age; counter-offers, talks break down at the third round with a 30-day lock; bonuses are paid, rises applied each season, and an AI club can pay the release clause. Used for renewals, free agents, transfers closed via the agent's owl, and pre-contracts.
  - **P10 pre-contracts** (January-June with expiring players, both ways: the AI takes them too).
  - **P2 happiness and complaints** (`src/game/happiness.gd`: playing time vs contract role, expiring contract, transfer-listed without asking; owl with four replies and a transfer request if ignored twice).
  - **P3 saved tactics and familiarity** (three plans per club, switchable live; an unrehearsed formation costs Chasers up to 8%).
  - **P6 finance ledger** (`Economy.book`: every cash movement with its concept, 6-month table in Finances), monthly merchandising, sponsorship offers on expiry (it never expired before).
  - **P12 fans** (`src/game/fans.gd`: mood that moves gate and merchandising ±15% and feeds into the board).
  - **P13 expanded board** (confidence by area: results/finances/fans; ultimatum of 3 wins in 5 before sacking; requests for more wages or a facility; club takeover by an investor [game]).
  - **P7 monthly awards** (player, young player and manager of the month per league in `World.monthly_awards`, shown in Competitions and the Prophet).
  - **P8 My career** (`manager` screen: history with from/to/reason/titles/best finish, vacancies and applications, resign).
  - **P9 advanced search and compare** (filters for age, value, wage, contract, nationality, status, stars and attribute, paginated; `compare` screen).
  - **P11** live ratings for both sevens and a post-match team talk (`TeamTalk.post_match`).
  - **P14** youth intake day with an assistant report, and Academy (facility adding 4 average PA per level).
  - **P15 scout assignments** (`src/game/scouting.gd`: player report with error depending on scout quality, next-opponent report).
  - **P5 named staff** (`staff` screen: candidates, hire with a bonus, fire paying out the contract).
  - **P16** pre-match press conference (two questions the day before, affecting own and opponent morale).
  - **P17** Contracts view in Squad and injury history.
  - **P18** monthly autosave (two slots) and holiday (the assistant manages until a date and hands back on urgent matters).
  - **P19** transfers in 3 instalments (`World.pending_payments`).
  - **P20** inbox filters, mark all read, delete read.
  - **P21 records** (`src/game/records.gd`, with the canon QTTA records: Plumpton 3.5 s and Appleby-Vratsa 16 days).
  - **P4** training plan by category (intensity 0-3 per category; the week is drawn in those proportions so total improvement stays calibrated).
  - Then added: **national-team friendlies** [game] (in the two seasons after each World Cup, with no group fixtures, the manager's national team plays three friendlies against similar-strength opponents; `GameEngine._create_nt_friendlies`), **loan with option to buy** (request or offer it at the asking price; on 1 June an owl arrives to exercise it, and the AI exercises it if the player is useful; `MarketActions.loan_options_tick`, `exercise_option`) and **sell-on percentage** (sell with 20% of the next sale in exchange for 10% less now; `Player.sell_on`, collected in `Economy.execute_transfer`). Test `test_loans_options_friendlies`.
  - Not done (reasons in the report): referees with strictness, night relief in very long matches, affiliated clubs, previous experience in New Game.
  - Also: AI line-ups kept players who had already left (~750 cases per career; `World._refresh_ai_lineup`); `stress_test` competitions threshold updated (81-83 at steady state with continental cups); `audit_world` compares scores as a set; `tools/compat_save.gd` checked that a save from before these changes still loads and advances (deleted on 2026-10-25, when saves of another schema became refused).
- **New canon tactics.** Starfish and Stick and Double Eight Loop for the Keeper, Bludger Backbeat for Beaters [QTTA ch. 10]; switchable live. No formations with more Chasers, because the rules forbid it (anti-*stooging*, 1884).
- **Automated UI tour.** `godot --path . -- --tour <folder> [--lang xx]` walks the 24 screens at four points of the season, takes screenshots and checks for untranslated text, unreplaced placeholders, overflow, tables hiding rows, clipped headers and screens that fail to open. It found the History screen broken, offer buttons overflowing in German and the Transfers screen empty mid-season.

### 2026-10-10: Sackings and terminations, world-life audit, playtest requests

- **Sackings and terminations.** (1) **AI sackings** [game, as in FM]. AI clubs fire their manager at season end if the board decides so (same verdict as for the human: far from the objective with low confidence, three seasons failing, or bottom twice) and also between November and April if confidence drops below 22 and the manager has been there over 4 months (30% per month). A replacement with a regional name comes in; the old one goes to `club.history.managers` (the club screen shows the last 3) and to the Prophet (`news.manager_sacked`). If the human manager fits the profile (enough reputation and unemployed, or the job is a step up), the vacancy can arrive as an offer (60%; `GameEngine._ai_sack`, `_post_job_offer`). (2) **Terminating a contract** now actually charges the remaining wages (before, it said a payout was due but deducted nothing; `MarketActions.remaining_wages`, `terminate_contract`). (3) **Mutual termination.** The player agrees to leave for part of what he is owed (50%; 30% if a substitute or transfer-listed; less with low morale or aged 32+). A happy starter under 32 won't leave (`MarketActions.mutual_terms`). Button on the player profile (Contract tab and Actions menu). "Cancel" buttons translated in confirmation dialogs. Test `test_contracts_and_sackings`.
- **World-life audit: 200 seasons simulated.** New tool `tools/life_audit.gd` (`godot --headless --path . -s tools/life_audit.gd -- --seasons 50 --seed 1 --human club_id`) simulates with a human club that plays everything, answers owls at random and does the press conference, and measures everything that isn't matches (transfers, loans, regens, retirements, contracts, long-term progression, press, the Prophet, inbox, awards, career, reputations), plus checks every text used in all 10 languages. Ran 2 × 50 seasons (Puddlemere United and La Plata Lobizones) before and after the fixes. Fixed:
  1. **Youth players didn't replace anyone.** They were born with median PA 74 (max ~140), and the elite (CA 150+) fell from 140 to ~40 in 15 years and never recovered. Youth PA now depends on club tier (118/105/92 ± 24, 3% wonderkids +35), and reserves and youth get reserve-match minutes (`GameEngine.RESERVE_MINUTES_WEEK`). Over 50 years the elite stays at ~80 and the median at ~104 (calibrated with `tools/youth_curve.gd`).
  2. **30-year-old stars erased.** A 30+ free agent vanished the night his contract expired; now he gets a season to find a club (except 34+), and the AI renews its 3 best at 95%.
  3. **Frozen club reputations.** Now they change each season by finish vs expectation, title and bottom place, plus cups, with an 8% pull back to the original reputation (`_update_reputations`, `base_reputation`).
  4. **The Prophet with up to 195 items per issue** (every cup and World Cup match on the planet, every injury and signing). Now only what concerns the manager's league and national team, plus the world's 4 most expensive transfers (`_relevant_news`; ~1,400 → ~400 items per season), without duplicates.
  5. **Men at the Holyhead Harpies.** Hogwarts graduates were distributed ignoring that the club is witches-only.
  6. **Players moving through 3-4 clubs in one season** (~100 cases per career). The AI won't move anyone already moved that season (`Economy.moved_this_season`; ~10 cases remain, from re-signed free agents).
  7. **Single-question press conference** at season end, now filled in with the man of the match.

  Verified unchanged: texts (195 keys × 10 languages, nothing missing or unreplaced), foreigners stable at ~30%, unattached free agents stable at ~510, record transfer ~3,000-4,000 G, median wage 5-6 G, average retirement age 34. Note: the auditor's manager reputation drops because it answers everything at random (not a game bug). AI sackings were added in the next batch.
- **Playtest requests.** (1) **FM-style line-up and tactics**: squad on the left (table with position, name, natural position, age, condition, morale, rating and injury/suspension; starters in bold), a vertical pitch in the middle with own hoops at the bottom and the 7 positions as tokens (empty = dotted circle, unavailable = red ring), and team instructions in a right-hand panel **hidden by default** ("Instructions" button above the pitch). Tokens spread over the whole pitch as in FM: Keeper at own hoops, Beaters in the middle, Chasers in the opponent's half, Seeker on top. Click a player then a slot, double-click to bring in/out, drag to swap (`PitchView` rewritten, `slot_pressed`). (2) **No automatic changes.** On match day, if the human line-up has injured, suspended or empty slots, the engine doesn't build the match (`GameEngine.lineup_blocked`, reason `lineup`), sends an urgent owl from the assistant and the bar button reads "Review line-up"; tools and tests keep `auto_fix_lineup = true`. (3) **Continue advances 3 days** (`main.CONTINUE_DAYS`): training, injuries, offers, reports and the Prophet happen between matches; the button just says "Continue", and on match day "Play vs X". (4) **Press conference** (`src/game/press.gd`, `press_screen.gd`): after the match summary, 2-3 Prophet questions (result; standout player, scorer, poor performer or injured; context: streak, table, board, cup or next opponent) with 4 answers (modest, confident, critical, evasive) that move squad and individual morale, board confidence and reputation. 16 questions × 4 answers in all 10 languages; replaces the old press owl. Also: snitch loading overlay (`LoadingOverlay`; creating and loading a game run on a thread), short club names on the button and unique 3-letter abbreviations (`World.team_short/team_abbr`), side menu hidden on the title and New Game screens.

### 2026-10-08: Playtest requests

1. **Small crests without jaggies**: mipmaps on crests, portraits, flags and brooms (and by default on new imports), linear mipmap filtering project-wide.
2. **Save at top right** (icon next to the owl; disabled during matches), removed from the side menu.
3. **Trophies appropriate to each club** (`Club.trophy_counts`): European Cup only for European clubs, continental cup only if its league plays one.
4. **Links.** In every table a club, national team or player name opens its page (`UI.player_cell`, `UI.team_cell`, `UI.router`); crests and names in the post-match screen too.
5. **Match**: "2D + commentary" by default; pause and timeout freeze the pitch (tokens and Bludgers kept moving before); "Simulate to the end" button (plays the rest without animation; you can't leave the match, but you can finish it).
6. **Map in New Game.** An antique atlas with a wax seal per league (blue for schools) and an enlarged Europe inset; a click on a seal lists its teams (`src/ui/widgets/league_map.gd`, `tools/make_map.py` + `tools/make_map.gd` with Natural Earth outlines, public domain). Two-row layout: map on top; below, teams · club card · profile and sign. "List" tab with the full tree.
7. **Career** [game] (`src/game/career.gd`). Starting reputation depends on the club (Puddlemere 1,638, La Plata Lobizones 460); each season adds or subtracts by finish vs the club's expected finish (weighted more in tier 1), verdict and titles; cups add when won. A club offers the job if your reputation reaches what it requires (20% of its own), and after a good season only bigger clubs call. National teams require reputation (weak 1,500, mid 1,900, strong 2,400, elite 3,000) and 2-3 seasons. The Board screen shows reputation, rank (Unknown, Prospect, Respected, Prestigious, Legend) and the gap; an owl at each season end explains the change. Before, everyone started at 1,000 and a weak national team needed 500, so a La Plata manager was offered England in his first August.

### 2026-10-07: Official names, Google Trends and Central Europe

1. **Fouls with their official names** in each edition, taken from each language's Harry Potter wiki (Fandom API): German Zockeln, Keilen, Kollern, Pfeffern, Rempeln, Flacken, Nachtarocken, Quaffelpicken, Schnatzeln, Stutschen; French Hochequeue, Boutenchoc, Croc-en-manche, Tranchefoule, Coudoyage, Rembarrage, Pognensac, Pique-Souafle, Pincevif, Tassebut; Portuguese Mutretar, Trombar, Guidonar, Catimbar, Acotovelar, Bloquear, Conduzir, Furar a goles, Roubar o pomo, Escada; Dutch Blemmeren, Schrepelen, Bokken, Kleuten, Knoerten, Lappedoezen, Tengelen, Slurkplurken, Snaaigraaien, Schoffelen; Russian Прихват, Стычка, Подсечка, Обманка, Отмашка, Выталкивание квоффла, Пропихивание квоффла, Подтасовка квоффла, Перехват снитча, Давиловка; Japanese in katakana (ブラッギング…); Chinese 拉扯, 冲撞, 急刹扫帚, 击球出场, 肘击, 环后击球, 握球入环, 破坏鬼飞球, 触摸飞贼, 夹杀. Spanish and Italian keep the English names, as their editions do.
2. **Ilvermorny houses** with official names (Spanish: Serpiente Cornuda, Ave del Trueno; French Womatou; Portuguese Pumaruna; Russian Пакваджи; Japanese パクワジ; Chinese 长角水蛇); the North American cup is renamed the **Thunderbird Cup**.
3. **Google Trends** (relative interest by country, all time, queried directly): Czechia 100, UK 85-98, Hungary 77-89, Australia, France, Ireland, Thailand (topic only), New Zealand, Norway, Spain, Mexico, Germany, Denmark, Poland, Chile, Italy, Slovakia, Belgium, Canada, Sweden, USA. Czechia, Hungary, Slovakia and Thailand were missing, so there is a new **Central European League** (Praha Golemové, Brno Draci, Plzeň Plivníci, Olomouc Orli, Bratislava Bludičky, Košice Kuvici, Budapest Boszorkányok, Debrecen Délibábok, Szeged Sárkányok), and Thailand joins the Asian league, which becomes East and Southeast Asia (Bangkok Garudas, Chiang Mai Chang Phueak) [FILLER]; Czech and Slovak female surnames (Nováková). Central Europe plays the European Cup and has a Bowman Wright slot (like the Netherlands and Flanders).
4. **The national cup winner enters the next season's continental cup**; if it didn't finish high in the table, it takes its league's last slot.

### 2026-10-06: Continental cups

Requested: Libertadores/Champions-style inter-league cups with Harry Potter-world names [FILLER: the books only name the European Cup, every three years, which stays as is]. Annual; groups of four, home and away (Wednesdays September-November, table by points scored as in the leagues, avoiding two clubs of one league in a group where possible); knockout for the top two (March, April, final in late May; replay on Sunday). **Bowman Wright Cup** (named after the inventor of the Golden Snitch; Europe: champion and runner-up of the 8 leagues, 16 clubs), **Castelobruxo Cup** (South America: 3 from Argentina, 3 from Brazil, 2 from the Andean league), **Thunderbird Cup** (North America and Caribbean: 4 USA, 2 Canada, 2 Mexico), **Mahoutokoro Cup** (Asia: 3 Japan, 3 East Asia, 2 India). `GameEngine.CONTINENTAL`; types `cont_groups`/`cont_knockout`. Also: 44 more crests imported (Japan, Mexico and the Caribbean, Nordic, Oceania, USA), and `tools/clean_prompts.py` removes completed batches from the prompt files.

### 2026-10-05: v0.10.0: fixed world, 22 countries with leagues, 10 languages, national cups

1. **Fixed clubs.** The starting world is the same in every game (`WorldGenerator.WORLD_SEED`); filler clubs were hand-designed in `tools/author_clubs.py` (alliterative name in the region's language, a local folklore creature, colours and crest charge) [FILLER]; only academy and school youth are random. 177 clubs in 19 leagues.
2. **Countries with the most fans** (a top 20 built from box office, book sales, theme parks and Hogwarts Legacy; no published ranking exists): added the Italian League, the East Asian League (China and South Korea), the Netherlands and Flanders League, and Russia in Eastern Europe; Argentina with Argentine clubs only (Mar del Plata Mareas, Posadas Pomberos) and four new US clubs (New York, Los Angeles, San Francisco, Miami). Italy and the Netherlands play the European Cup. Female surname forms where applicable (Russian).
3. **10 languages** (es, en, de, fr, it, pt_BR, nl, ru, ja, zh_CN) with each edition's official terminology; country, region, league, cup and house names translated (`Loc`); dates in each locale's format; kanji/hanzi with system-font fallbacks (bundled Noto subsets in the browser); system language on first launch (English since 2026-10-20); international city names outside Spanish. Pending confirmation: official QTTA foul names per language (done 2026-10-07).
4. **National cups** [FILLER: the books name none]. One per league, single-match knockout with replay, Thursdays October-April, top clubs given first-round byes when needed.
5. **AI crests and portraits**: batch prompts for ChatGPT (`docs/art/crests/`, `docs/art/portraits/`), an importer that crops and removes the background (`tools/import_crest_sheets.gd`); generated crests take priority over code-drawn ones.
6. **Monthly calendar** grid and seamless **paper textures** on the desk and cards (`tools/make_paper.gd`).
7. **Economy.** Average club cash grew without limit (7,200 → 55,000 G in 24 seasons) because gate receipts had a fixed base that was too much in low-wage leagues; now proportional to reputation, and AI club cash reverts 25% per season towards ~30 weeks of wages [game]. Fix: a loanee who retired kept the loan open.
8. **50-season test** (1993-2043, `tools/stress_test.gd --seasons 50 --human club_puddlemere_united`): 80 minutes, no hangs, save/load correct, average cash stable at ~11,000 G. Found two bugs, fixed: loans with no parent club (a player offered for loan who became a free agent kept the flag) and AI squads of 20-21 (one signing per position added in the same tick); the "competition leak" threshold was raised because national cups bring the steady state to 61-64. Follow-up: 15 seasons, 0 anomalies.
9. **Blowouts** (playtesting feedback: too many). `tools/blowouts.gd` simulates every league; with "match settled" [game] (with a lead over 40 points the winner attacks less and shoots less sharply, down to ×0.2 at 200; `sim_params.quaffle.comfort_*`) and `contest_sharpness` 0.5 → 0.4, margins of 300+ fell from 10.3% to 5.6%, 500+ from 1.9% to 0.1%, and the maximum from 1,390 to 550; a team 3 points stronger across the board still wins 66%.

### 2026-10-04: v0.8.0 to v0.9.0

- **v0.9.0.** Title screen, 2D viewer, explorer, music and embroidered crests (playtest requests):
  1. "Play vs…" led to the Inbox. Progress stopped at every owl with actions; now only urgent ones stop it (`urgent`, e.g. job offers while unemployed), the rest wait with a counter and notice.
  2. Title screen (`title_screen.gd`) with the logo over the illustration and four buttons (New Game, Load Game, Settings, Project info); New Game stands alone with "Back".
  3. 2D viewer: goal animation (Quaffle arcing into the hoop, gold rings, sparks in team colours, "GOAL!" banner) and catch animation (Seeker dive, flash, Snitch in hand); the match waits during the animation and the replay follows; big red Quaffle also in the carrier's hand, two black Bludgers chasing players; capture mode `--until goal|catch`.
  4. Parchment-style popups (the team talk was unreadable).
  5. Own Daily Prophet badge, crisp and transparent (`tools/make_prophet.gd`).
  6. New synthesised music (`tools/make_music.gd`: "The Office", a waltz with harp and celesta; "Match Day", a march (default since 2026-10-20); "The Common Room", a jig), selectable in Settings, with the old theme as "Classic".
  7. Explorer (`explorer_screen.gd`): every league with its table, worldwide player search and national-team ranking; in school mode the public rating of professionals is known.
  8. Save/Load as a popup.
  9. Indian League (8 clubs [FILLER]): India appears on the 422nd World Cup poster (a film prop) and was the only country on it without a league; club nicknames unique within a league.
  10. Own crests with the embroidered-patch look: muted colours, charge embroidered in two thread tones, twill weave and a corded border with loose threads (`tools/patch_crests.gd` → `assets/crests/fx/` and `assets/crests/patched/`; generated clubs are embroidered at runtime with the same layers).
  11. Small windows: the UI is designed for 1366×900 logical with `canvas_items`/`expand` stretch, so a shorter window scales down instead of clipping (initial window 1366×820).
  12. Match: no side menu, a much bigger pitch (tokens and balls scaled with it), and no skipping once started: navigation, inbox and "Finish" locked until the end; "instant" speed and the "score only" skip removed.
- **v0.8.2.** Commentators, what's at stake, and defences with counters (from the reviews report, `docs/research/07-quidditch-game-reviews.md`):
  1. **Commentators** (`src/game/commentary.gd`). Lee Jordan calls every school match (pro-Gryffindor, cut off by McGonagall with "JORDAN!") and Ludo Bagman every professional one [game: in the books they only commentate some]. They replace the neutral voice on 60% of key events (throw-off, goals, catches, final whistle always; saves and missed shots 30%) and comment after the neutral text on fouls, injuries, feints and Bludger hits (35%/8%), with 3-6 variants per event in ES/EN; header "commentary by …".
  2. **What's at stake** (match panel): in leagues and the House Cup (accumulated points scored), position with the current score, position if the Snitch is caught now and points needed for first place; in World Cup groups, margin and group points with and without the Snitch.
  3. **Chaser defence** separate from attack (`SimTactics.chaser_defence`: zone, Parkin's Pincer [QTTA], man-marking [game]). The pincer stops dribbling (Hawkshead) and leaves passing lanes; marking cuts passes (Porskoff, reverse pass, sloth grip roll) and suffers against dribbling; getting it right is worth ~1.7 goals/hour (~30 points over a 2-hour match). The AI reads the opponent's style at its timeouts and after conceding three goals (`_ai_counter_defence`), and each AI club has its own style by identity (`GameEngine._ai_style`); the assistant suggests the counter in Line-up and during the match. Also fixed: the Porskoff performed far below "free play" (decoy pass +15%, gains ground). Brand mark (the Snitch alone) as app icon; logo A as the full logo.
- **v0.8.1.** Fixes from the 0.8.0 QA, and logos. A QA agent tested the new features. Fixed: Table and Club broke in school mode and in the year without a Cup ("no competition" notice; `World.team_club`, `Game.team_as_club`); student profiles offered transfers (now only talk and captaincy in your own house, no Contract tab, header with house and year); the bar's "Finish match" button did nothing (`match_screen.finish_match`); Competitions empty with the school Cup (`school_cup` branch); the "Save by …" banner showed the shooter; replays (button also on the final bar, pause/advance respected during replay, history at 30 real fps and cleared after skips); World Cup group cut off in National Team; school year changed on birthdays (`Schools.school_year`: age on 31 August); club messages in school mode (monthly review, European Cup draw, "Retired: .", "The board" in post-match, mediwizard → matron); "Pottermore canon" in a note; History with season/competition/champion columns and World Cups with their year. Engine: **the school Cup no longer has a 90' cap** (the books have none): catches 32% → 98%, median ~2 h. Inconsistencies: the assistant's report no longer repeats identically week to week; a single call-up owl per match (none if the manager is the national coach); notice of house arrivals/departures and captain handover on graduation; texts saying "first-years arrive in September" (they enter via trials, from any year); job offers from the manager's region; tutorial tips adapted to school mode; Cup home advantage split; venues and *The Quibbler* byline translatable; informal-register fix in the federation sacking text. **Crests for every club.** In-game generated clubs use SVG templates in the same style with their colours (`data/shared/crest_templates.json`, exported by `tools/make_crests.py`; `Crest._from_template`), and "Club figures" was removed from New Game (it only listed book players). Three logo proposals (`tools/make_logo.gd`).
- **v0.8.0.** Requested items 1, 2, 4, 5, 6, 7, 9 (lightly), 10 and 12 from the pending list:
  - **Manage a Hogwarts (or Ilvermorny) house** (item 2). New Game has a "School" group with the houses. The human team is a view of the house (`World.house_club`, persistent state in `houses[hid]`: `human`, `lineup`, `tactics`, `board`); `squad_of`/`club_players` return the house's students, `league_of` the school Cup of that year. It plays its three matches (`Schools.sim_team` honours the human line-up and tactics; `Schools.human_lineup_valid`/`best_lineup`); book events are skipped when the player's house is involved, and the canon champion isn't forced in that school. Symmetric weekly training for all houses (`GameEngine._train_club` with `SCHOOL_TRAINING_SCALE` 0.35; no yearly `_grow` jump in schools with houses); no wages, transfers, scouts, board or friendlies (reduced menu, `main.gd SCHOOL_HIDDEN`). End of year: the Head of House reviews the Cup (`_house_season_review`); winning it brings offers from tier-3 professional clubs; 1994-95 has no Cup (Triwizard Tournament), with an inbox notice. Screens: squad with a "Year" column and full knowledge of your own students, line-up with the pitch, 2D, post-match ("Head of House"). Test `test_house_manager` and `stress_test --human hs_hogwarts_gryffindor`. Note: a school year is **3 matches** (6 fixtures among 4 houses); the books show no inter-house friendlies, so none were invented.
  - **Replays** (item 1) already existed for goals; now also for the Snitch catch, with 6 s of context, a "Replay/Skip" button on the 2D viewer bar (`Pitch2D.replay_last_play/skip_replay`) and the setting renamed.
  - **Fixed looks** (item 4): `look` for the Ireland and Bulgaria internationals and Gwenog Jones, marked `look_source: [FILLER]` in the JSON (not described in the books).
  - **Fewer free agents** (item 5). The AI renews its 14 best (85%) and sometimes good ones from the rest; releases veterans 34+ and the bottom of the squad (`_ai_wants_renewal`). Free agents per summer: ~400 → ~300.
  - **Fatigue** (item 6). Low condition reduces attack frequency (`match_sim.gd`, `action_p *= lerp(0.55, 1, condition)`): 17.7 goals/hour in short matches, 15 at 2-4 h, 11 beyond 8 h; average duration 107 → 114 min (within the 90-120 target).
  - **Difficulty** (item 7). `tools/difficulty.gd` compares the same club run by the AI and by a "neutral human" doing the minimum (renew its 14 best, fill gaps with free agents): Wigtown AI [13, 11, 11, 12] vs human [12, 11, 11, 13]; Puddlemere [2, 6, 4, 2] vs [1, 4, 3, 1]; a Mexican club [2, 2, 2, 7] vs [5, 3, 2, 5]. Conclusion: the AI isn't weak; the autopilot's wins came from transfer-market luck. Without a human renewing and signing, the club declines (that's how you lose).
  - **Faces** (item 9, lightly): two more hairstyles (bowl and wavy), variable nose width and chin, hair colour weighted by region (no blondes in Japan/East Asia).
  - **Tutorial** (item 10): five owls on day one (line-up, squad, training, season, transfers; in school mode, school) with a "Go to…" button; "Starting tips" setting in `user://settings.cfg`.
  - **National team** (item 12). The screen shows the next national-team match, the World Cup group with its table and the pool of eligible players (club, age, rating, condition; called-up in bold, injured in red), on a scrolling page. Capture mode: `--scroll N`.

### 2026-10-03: Milestones 1 and 3, v0.4.0 to v0.7.2

- **v0.7.2.** No canon/invented distinction for the player, and procedural portraits. Requested: remove everything that says "canon"; for the player it should make no difference whether something was invented or is real. Removed from the UI: the "Canon player" badge, bold canon students, "Source" columns for fouls and World Cups, notes mentioning filler (brooms, clubs, World Cups, fouls), citation brackets in the encyclopedia rules and the "(canon)" on the Harpies; the clubs encyclopedia now lists every club (those without book notes get a generated note with their style and honours). The data (`source`), design docs and `ATTRIBUTION.md` keep the [FILLER]/canon marking. **Procedural portraits** (`src/ui/widgets/face.gd`, class `Face`). Every player without a picture, including future regens, gets a deterministic code-drawn face (seed = id): skin tone weighted by region of origin [game], hairstyle and colour (grey from 33), sex (long hair, lips, earrings), glasses, beard, freckles or scar, smile and brows, robes and background in club colours. To keep a single style (all realistic or all caricature), the wiki photos were removed and **every** player uses the procedural face; characters described in the books have fixed traits in `look` in the pack (Harry: messy black hair, glasses, green eyes and lightning scar; the red-haired, freckled Weasleys; Angelina; Cho; Malfoy, platinum and slicked back; Flint and Krum with thick brows…). Developer screen `faces_debug` for tuning.
- **v0.7.1.** 50-season stress test. `tools/stress_test.gd --seasons N --seed S [--human club] [--save-every K]` runs N seasons with an "autopilot" human club (plays matches with random tactical changes and timeouts, answers owls at random) and checks invariants at each season end: champion and full table in every league, valid bounded squads, consistent player↔club indices, ages and CA in range, students per school, World Cup every 4 years and European Cup every 3, bounded inbox/news/competitions, save and load every K seasons. Result 1993-2043 (seed 11, Puddlemere): 0 script errors, 0 leaks (~7,000 objects constant; save file 4.0 → 4.2 MB), median CA plateauing at 106-109, 2,650-2,700 players, average cash rising 7,900 → 24,000 G (slow, tolerable inflation). Bugs fixed: (1) a sacked manager never got job offers again → monthly offers by reputation (`_monthly`); (2) board confidence saturated at 100 → monthly review trending to the level the position deserves (`Economy.board_review`) and smaller per-match/press deltas; (3) 21-player squads from a double youth intake in summer (`_fill_squad(…, with_youth=false)` in the turnover) and pruning of surplus youth; (4) AI clubs deep in the red (down to -16,500 G) → they list their best player and freeze signings until they recover; (5) a perpetual bottom club with an "avoid last place" objective was never sacked → three failed objectives in a row or two last places in a row = sacking (`Economy.season_verdict`). ~400 free agents each summer (one cohort per year, pruned after two years): a busy market, candidate for calibration.
- **Semantic audit.** Requested: look for inconsistencies, not just errors. `tools/audit_world.gd --seasons N --seed S [--human club]` simulates N seasons and checks coherence, not crashes: tables matching results, no club with two matches on one day, scores consistent with the Snitch (multiples of 10, +150 to the catcher), one captain per club, no duplicate names in a club, only women at the Harpies, CA ≤ PA, attributes 1-20, valid contracts, consistent loans, per-position stats (saves only for Keepers, catches only for Seekers), no foreigners in national teams, champion = top of the table, club position = history, awards recorded on the profile and real top scorer, young players progressing and veterans declining, complete school cups, canon World Cups, ES/EN translations with the same placeholders, and messages/news with all their data; it also prints the result distribution (points and duration, % Snitch, % wins for the catcher, draws, home advantage, blowouts). Fixed: (1) 21 AI clubs with no captain (retirements/transfers didn't replace him) → `WorldGenerator.ensure_captain` on turnover, sales, loans and departures, with a notice to the human; (2) namesakes within a club → name retry in `_make_filler`; (3) **zero paid transfers** worldwide (the AI only signed free agents) → reinforcement purchases between AI clubs (`Economy._ai_upgrade_purchase`, ~50-65 per season, average ~1,400 G; the buyer releases the replaced player so the wage bill doesn't grow); (4) season stats mixed all competitions, so the league "top scorer" included World Cup goals → per-competition `Player.comp_stats`, used by awards and league leaders (old saves fall back to totals); (5) a new board inherited the previous manager's confidence when changing clubs → starts at 60; (6) in 1996-97 Slytherin played two cup matches on one day (a canon date clashed with a generic one) → free-date allocation in `Schools.create_cup`. Observations, not bugs: the goal rate is flat (~17.5 goals/hour at every duration, as calibrated in Milestone 0), so a 12-hour mismatch can end 5,000+ points; 11-15% of league matches end with a 300+ margin; the Snitch catcher wins 94% (canon 2014: 14 of 15). The market also exposed a money leak. When a starter was sold, `_fill_squad` created a new filler instead of promoting the reserve, so each sale grew the world's player pool and wage bill (average cash 7,900 → 2,500 G in 8 seasons); now reserves are promoted before generating anyone and average cash is stable (7,900 → 8,000 G in 8 seasons, worst club -3,700 G). 0.7.1 installers re-exported with all of the above.
- **v0.7.0.** General pass: post-match summary (`post_match_screen.gd`); images for the personal copy (official patches from the illustrated edition, house crests, canon portraits from the HP Wiki, per-club uniform illustrations, flags from flagcdn, brooms, the Prophet badge, World Cup art, title background; all in `assets/` and listed in `ATTRIBUTION.md`); preseason with two friendlies; weekly assistant report; league leaders and records; staff with levels (assistant, mediwizard, chief scout, broom master); individual training focus and mentors; board requests and an objective negotiable in August; hall of fame; shortlist + scout recommendations + rumours; moor weather in the engine (`MatchSim.weather`: sightings, passes, injuries); ratings with diminishing returns; canon World Cup history 1473-2014 (`world_cup_history.json`, 1998-2014 finals as events); European Cup notices.
- **v0.6.0.** Book events (`data/packs/1993-94/events.json`, 23 events 1993-1999 with sources; `GameEngine._book_events`, results written in, not simulated); Hogwarts and Ilvermorny visible (`src/world/schools.gd`: students with houses, canon from `data/packs/1993-94/schools/`, House Cup run by the engine with a 90-min cap [game], graduates to the academy pool); end-of-season awards (`src/game/awards.gd`: Wronski Award [film], Dangerous Dai [QTTA], top scorer, catches, Keeper, team of the season); transfers with counter-offers, agents (wage + fee) and swaps; national-team management (federation offer by reputation, own seven and tactics, review after the World Cup); heraldic crests drawn from canon `emblem_key` (`src/ui/widgets/crest.gd`; Warner's are not copied); 2D viewer with riders, goal replays and drag-and-drop in Line-up; press conference and individual talks with promises (`src/game/press.gd`); text variants by stable seed (`Game.t_variant`); own synthesised sound (`tools/make_sounds.gd`, `src/ui/sfx.gd`). Save schema 3. 356 checks.
- **v0.5.0 exported**: 2D viewer, loans, team talks, reserves, three-column Prophet, pitch in Line-up, redesigned New Game, Settings (language, text size, density; `user://settings.cfg`) and Encyclopedia (rules, fouls, brooms and QTTA club notes).
- **v0.4.0 exported.** `export_presets.cfg` (macOS universal, ad-hoc signed, not notarised → `export/QuidditchManager.dmg`, 70 MB; Windows x86_64 with embedded pck → `export/QuidditchManager-windows.zip`, 40 MB). Verified the Mac build launches and loads data (`data/*` in `include_filter`; `tests/`, `tools/` and `docs/` excluded). Procedural icon (`tools/make_icon.gd` → `assets/icon.png`); the Windows `.exe` has no icon (needs `rcedit`). Minimal tutorial: per-screen help card (ⓘ button / F1, 16 texts in `ui.help.*`) and a tip in the welcome owl. `ATTRIBUTION.md` with licences (Godot MIT, OFL fonts, Phosphor MIT). Pending for 1.0: real notarisation/signing if distributed, encyclopedia/history, UI polish items 11/14/15, DLC packs.
- **Milestone 3 done.** 142 clubs in 15 leagues (`data/packs/1993-94/competitions/`, incl. Argentina and an Andean league), 62 national teams, World Cup 1994/1998 and European Cup 1995/1998 (`game_engine.gd`: `_calendar_events`, `_create_european_cup`, `_create_world_cup_final`), career ladder (`_career_ladder`, `_job_offers`, `accept_job`), regional scouts with partial knowledge (`Club.knowledge`, `Club.scouts`, `scouting` screen), schools as academies (`schools_screen.gd`). `tools/sim_world.gd --seasons 6` runs stable (~48 s/season); 313 checks in `tests/run_tests.gd`. UI redesigned per `docs/research/05-ui-ux-managers.md` §3-§4 (priorities 1-10, 12 and 13 applied: desk + cards, heat map, sortable tables, grouped menu with Phosphor icons, bar in club colours, buttons by hierarchy, drawn glyphs, shortcuts and toasts, window scaling). Pending from the report: 11 (nine-patch/textures), 14 (visual monthly calendar), 15 (sounds). Verified over 6 seasons, not 20.
- **Milestone 2 update.** Done: loans (`Economy.execute_loan/return_loan`, `MarketActions.request_loan/toggle_loan_list`, AI loans, return on 30 June, save schema 2), team talks and reserve matches (`GameEngine._reserve_matches`: a simulated weekly friendly for the human club, abstract match fitness for the AI). Remaining: own crests and textures (ruled out by the UI report), replays.
- **Milestone 1 done (base version).** `src/ui/widgets/pitch_2d.gd`: replay of the simulator's abstract state (possession, zone, carrier, Snitch state, events) with interpolated tokens, Bludgers, Quaffle, a Snitch visible only during the chase, and event banners. The simulator is unchanged (still zone-based and deterministic). Match views: "Commentary", "2D + commentary" (slower clock) or "Score only"; remembered in `world.settings.match_view`. Team talks (`src/game/team_talk.gd`) before the match and at each timeout, with reactions by hidden personality. Pending: dragging tokens, replays, sprites.

### 2026-10-02: Milestones 0 and 2

- **Milestone 0 done.** `src/sim/` (deterministic RNG, player, team, tactics, event, result, `MatchSim`), `src/world/filler_generator.gd`, `src/sim/sim_loader.gd`, 1993-94 pack data (13 clubs, 17 canon players, 27 brooms, British and Argentine names), `tools/sim_batch.gd`, `tests/run_tests.gd` (198 checks passing). Metrics in `03` §4. The only target missed is speed: 50 matches/s (10,000 in ~200 s), enough for the game (a worldwide matchday in 1.6 s).
- **Milestone 2 done (base version), without the 2D viewer.** Milestone 1 was skipped at first and matches played as text highlights. Delivered: persistent world (`src/world/`: player, club, competition, calendar, generator with canon layer + filler), season engine (`src/game/game_engine.gd`: day by day, AI matches and step-by-step human match, training week and wages, monthly board and AI transfers, season end with retirements, contracts, youth and squad cap), progression and decline (`progression.gd`), economy, board and human transfers (`economy.gd`, `market_actions.gd`), the Prophet (`news_generator.gd`), compressed saves with schema version (`save_manager.gd`), full Godot UI with 16 screens (`src/ui/`), "manager's office" theme with OFL fonts, ES/EN (479 keys in `locale/strings.csv`). `tools/sim_world.gd` runs 10 seasons in ~100 s with a stable world (median CA steady at 110, positive cash, full squads, varied champions). 227-230 checks in `tests/run_tests.gd`, including a full season with a human club and save/load.
