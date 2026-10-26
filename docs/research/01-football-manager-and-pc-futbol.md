# Research 01: Football Manager / Championship Manager and PC Fútbol

> Genre reference report for designing a "Quidditch Football Manager" (desktop, Windows/Mac, matches simulated and shown in 2D; the manager only makes substitutions and adjusts tactics during the match).
> It does not cover Quidditch (researched by another agent) and does not design the game: it only describes the references and draws lessons from them.
>
> Research date: October 2026.

## How to read the confidence markers

Every relevant claim carries a marker:

- **[F]** = confirmed in a consulted source (listed at the end, numbered). Where needed, the number is given: [F3].
- **[I]** = my own inference from what was confirmed.
- **[R]** = my own recollection, not verified in this session (general genre knowledge; probably correct but **not** checked against a source).
- **[C]** = conflict between sources; both versions are reported.

Several primary sources (Sports Interactive's official manual, the Hattrick wiki, the SI forums, GameSpot) returned 403/402 when I tried to read them; in those cases I relied on community guides and search snippets, and I mark it as such.

---

## 1. Executive summary

**The two series represent two opposite philosophies of the same genre, and both worked.**

> **Update (change of priority):** the main design reference is **Football Manager 2007 (FM 07)**, which now has its own section (§2bis). The modern FM versions (§2) remain as secondary context.

0. **FM 07** (Oct. 2006) is the last generation with the **pure top-down 2D engine** (3D arrives in FM2009 [R]) and with the classic interface of **1-20 tactical sliders and arrows on the pitch** [F77][F78] (the detail of the 1-20 scale and the arrows is confirmed in an FM 08 guide; for FM 07 it is very likely but I did not confirm it). It has **47 visible attributes rated 1-20** (14 technical, 14 mental, 8 physical, 11 goalkeeping) plus **13 hidden ones** [F75][F82]. Training is organized into **9 categories** with per-category intensity (light/medium/intense), and each category maps to a fixed list of attributes [F74][F75][F76]. FM 07 added the **pre-match team talk** and individual half-time talks [F69][F70]. It did **not** yet have touchline shouts, a tactics creator or in-match assistant analysis. Those arrive with FM2010 [F73]. Full detail, including what I could and could not verify, in §2bis.

1. **Football Manager (FM) / Championship Manager (CM)** is maximum depth: a real-world database researched by a worldwide network of scouts [F], ~36 visible attributes on a 1-20 scale plus hidden attributes and a "Current/Potential Ability" (CA/PA) on a 1-200 scale [F], a match engine that decides every player's action every 0.25 s (a "slice") [F], and a game loop organized around the **Continue button** and the **Inbox** [F]. It hooks players through **emergent stories** (your career, the youngster who breaks through, the star who wants to leave) [F]. Its big problem is the **barrier to entry**. According to Miles Jacobson, analytics showed that many new players quit **within the first hour** [F]. FM26 (2025, migrated to Unity after FM25 was cancelled) launched with 27% positive reviews on Steam due to a clunky interface, bugs and removed features [F], a warning about rewriting the interface of a spreadsheet game.

2. **PC Fútbol** (Dinamic Multimedia, 1992-2001) is simplicity, presentation and accessibility. Its creators explicitly say they were inspired by the **simplicity of Kevin Toms's Football Manager (1982), not the complexity of Championship Manager** [F]. A player's overall rating was the simple average of **four** attributes (speed, stamina, aggression, quality) on a 0-99 scale [F]. What made it a mass phenomenon was the **price (roughly half that of other PC software) and distribution through ~30,000 newsstands** versus ~1,000 specialist stores [F], the face of **Michael Robinson** [F], the database with photos and history [F], and the **Promanager** mode: you start at a modest club and climb a **ladder of objectives** (avoid relegation → mid-table safety → promotion) that brings you offers from better clubs [F]. Its chronic weak point was the **3D simulator** (poor, with absurd results) and the **bugs** in the later versions [F].

3. **Engine architecture.** There are three public archetypes. (a) **Tick-based positional agent simulation** (FM: decisions every 0.25 s; the 2D/3D visualization comes "for free" from the positions) [F]; (b) **event/sector-based simulation** (Hattrick: possession = ratio of midfield ratings, up to 15 chances per match, text output) [F]; (c) **possession-based simulation** (Basketball GM) [F]. FM uses **engines with different levels of detail**: the full one for your league and a simpler "quick match engine" for the thousands of matches nobody watches [F]. Standard practice in open projects is to **separate simulation from rendering** and make it **deterministic with a seed** [F].

**The 5 most important lessons for a small team's first release** (detail in §6):

1. **Copy Promanager's career ladder** (board objective per season → better/worse offers) as the backbone of the main mode. [F + I]
2. **Few attributes, readable and with a visible effect in the 2D match** (PC Fútbol style: 4-8 core attributes), with a minimal hidden layer (potential, consistency, injury proneness). [I]
3. **Hybrid engine**: event/phase-based simulation (tunable and testable) + a 2D animation layer that "acts out" the events; deterministic with a seed; a fast mode for unwatched matches. [I]
4. **Match viewing levels** (result only / summary / key highlights / full match) from day one. Both PC Fútbol and FM have them, and players use them according to the importance of the match. [F + I]
5. **Avoid the repetitive tasks that FM turned into "work"**: press conferences, micro-managed training schedules (105 clicks per week in FM26), and an economy with sub-systems that involve no real decision (PC Fútbol's "catering"). [F + I]

---

## 2. Football Manager / Championship Manager (Sports Interactive): general context and modern versions

> This section remains as **secondary context**: the main reference is FM 07 (§2bis). What follows about FM19-FM26 serves to show where the genre evolved and what problems appeared, not as a model to copy.

### 2.1 Historical context

- **1992**: Championship Manager, published by Domark, programmed in BASIC by brothers Paul and Oliver Collyer [F2]. A deliberately graphics-free design focused on "cold, hard statistics" [F2]; it introduced the **average player rating per match** as a way to track performance [F2].
- **CM 93/94**: replaces fictional players with **real players**; according to PCGamesN, this is what set it apart from its rivals [F2].
- **CM2 (1995)**: optional audio commentary by Clive Tyldesley [F2].
- **CM3**: LAN/internet multiplayer [F2].
- **CM 01/02**: considered the classic peak; Bosman free-transfer rule, "fog of war" on attributes, legendary youngsters who became cultural memes [F2]. (This version was released for free by Eidos in 2008 [R].)
- **CM4 (2003)**: introduces the **top-down 2D engine**; before that, the whole match was **radio-style text commentary** [F3][F4]. It was the fastest-selling PC game in the UK at the time [F4]. The 2D leap made matches "tactical". For the first time you saw your fullback getting beaten, instead of inferring it from the half-time rating [F4].
- **2003-2004**: SI and Eidos split; Eidos keeps the "Championship Manager" brand, SI keeps the code and the database and becomes **Football Manager** (Sega) [R].
- **FM2009**: first 3D engine [R].
- **FM25** cancelled in February 2025 for failing to meet quality standards after the migration to Unity [F12]. **FM26** (Nov. 2025): lowest Metacritic score in the series, 27% positive on Steam at launch, criticism of the UI, bugs and removed features [F12][F13].

### 2.2 Game loop

- **Time unit: the day.** The **Continue** button advances the calendar; if there is a message in the Inbox that requires a response, the button changes its label and blocks progress [F5]. [I] This is the game's "metronome". The player decides how long to linger on each day.
- **Inbox as narrator**: injuries, offers, player complaints, scout reports, board messages. The **match preparation** message lets you set one tactical focus and two set-piece focuses before the next opponent [F5].
- **Typical week** [R, except where marked]:
  1. Check the Inbox (injuries, morale, reports) →
  2. Adjust training (or delegate it to the assistant) →
  3. Transfers / scouting if the window is open →
  4. Pre-match press conference (optional, delegable) →
  5. Pick the lineup and tactic, review the opposition report (analyst) →
  6. Pre-match team talk → match → half-time team talk → full-time team talk →
  7. Post-match press conference → back to 1.
- **Season**: pre-season (friendlies, physical workloads) → transfer window → league + cups → winter window → end of season (renewals, retirements, the "youth intake" of new youngsters, board review, new objectives) [R].
- **Most visited screens** [R]: Inbox, Squad, Tactics, Training, Scouting/Transfer Centre, Schedule, League Table, Finances, Board/Club Vision, Match.
- **Session length.** I found no official figures. [R] The community commonly cites between 10 and 30+ hours per season in the PC version, depending on how much is delegated and how many matches are watched in full; FM Touch exists precisely to "fly through the seasons" [F7].

### 2.3 Player model

**Visible attributes, 1-20 scale** [R for the complete list; partially confirmed in F8]. This is the modern list; the FM 07 list (with 11 goalkeeping attributes and names like Creativity and Influence) is in §2bis.2:

| Group | Attributes |
|---|---|
| Technical (14) | Corners, Crossing, Dribbling, Finishing, First Touch, Free Kick Taking, Heading, Long Shots, Long Throws, Marking, Passing, Penalty Taking, Tackling, Technique |
| Mental (14) | Aggression, Anticipation, Bravery, Composure, Concentration, Decisions, Determination, Flair, Leadership, Off the Ball, Positioning, Teamwork, Vision, Work Rate |
| Physical (8) | Acceleration, Agility, Balance, Jumping Reach, Natural Fitness, Pace, Stamina, Strength |
| Goalkeeping (13, replace the technical ones) | Aerial Reach, Command of Area, Communication, Eccentricity, Handling, Kicking, One on Ones, Reflexes, Rushing Out, Punching (Tendency), Throwing, + Passing and First Touch [R] |

- **Current Ability (CA) and Potential Ability (PA)**, both on a **1-200** scale [F6]. CA only grows up to PA [F6]. CA can go up (training, minutes) and down (age, injuries, lack of playing time) [F6].
- [R] Each attribute "costs" CA differently depending on position (e.g., a center back "spends" more CA on Marking than on Finishing). Researchers can assign "negative" PAs (−5 to −95), which mean a random range resolved when the save starts. This creates variety between saves with the same database.
- **Hidden attributes** [F6][F8]: Consistency, Important Matches, Injury Proneness, Versatility, Adaptability; [R] also Dirtiness.
- **Personality**: 7 hidden attributes rated 1-20 (Ambition, Controversy, Loyalty, Pressure, Professionalism, Sportsmanship, Temperament) [F9]. They combine into readable labels: "Model Citizen", "Resolute", "Perfectionist", "Model Professional", etc. [F9]. **[I] This is a key pattern. Hidden numbers become a visible natural-language label.**
- **How hidden attributes are inferred.** They cannot be seen without editors; they are guessed from scout and coaching staff reports (ability/potential stars, "pros and cons") [F6][F10].
- **Evolution with age** (according to community testing, not official data) [F11]:
  - Before 18, training is the dominant factor; from 18 on, **match minutes at the right level** become more important.
  - Outfield players peak at ~24, decline slowly until ~31, then the decline accelerates. Goalkeepers peak at ~26 (lower than what the in-game advice says).
  - Strong development if: PA − CA ≥ 20, Professionalism and Ambition > 10, under 28 and playing regularly.
  - From 30 on, physical attributes drop and mental ones partially rise to compensate.
- **Player status** [F14 unless marked]:
  - **Condition** (immediate tiredness). Stamina determines how much it drops during the match; Natural Fitness, how much it recovers between matches.
  - **Match sharpness**: hidden, 0-10,000.
  - **Accumulated fatigue** ("jaded"): ~50-70 points per match, −20 per full rest day (figure from community testing).
  - **Morale**: drops with defeats, affects performance and training. [R] 7-level scale (Abysmal … Superb).
  - **Injuries**: more likely with low condition; they leave sharpness and condition at rock bottom.
- **Dressing room dynamics** [R]: hierarchy (team leaders, highly influential players), social groups, happiness based on promises (playing time, signings) kept or broken.

### 2.4 Match engine

- **How it simulates.** Every player and the referee makes a decision every **quarter of a second (a "slice")**, choosing the action they consider best according to their attributes [F15]. Since FM21 they can change their decision mid-slice if the situation changes [F15]. Explicit AI areas: marking/defensive positioning, midfield (interceptions, progressive passing), final third (runs, shot selection), goalkeepers, referee/VAR [F15]. More technical players "have a greater variety of shots available" [F15]. The details are **a trade secret** [F16].
- **Relationship between simulation and visualization.** SI says the engine "calculates what happens across the 90 minutes — every pass, tackle, shot and movement — and then FM picks the highlights and plays them back to you in the format you chose" [F15]. **[I] But since mid-match tactical changes alter what follows, the engine necessarily advances in segments and applies changes at the next stoppage**; substitutions, confirmed, take effect at the next break in play [F17]. There was explicit work on passing better information from the decision AI to the animation system [F15]. In other words, **animation is a layer that consumes the simulation state**, not the other way around.
- **Unwatched matches.** FM uses engines with different levels of detail. The full one runs for your league and important stages of major competitions; the rest use the **"quick match engine"**, which is simpler and less random (fewer upsets) [F18]. The player can configure the level of detail of each loaded league to gain speed [F18].
- **Presentation**: 3D, classic top-down 2D, and "commentary only" (text) [F19]. Highlight levels: **Full Match, Comprehensive, Extended, Key, Commentary Only** [F19]. "Key" = goals, clear chances and little else; "Extended" = half-chances, shots on target [F19]. Players choose according to the importance of the match (e.g., Key for friendlies, Extended for important matches) [F19]. There is playback speed control [F19].
- **In-match decisions** [F17 unless marked]:
  - Substitutions (take effect at the next stoppage; you can give an individual talk to the incoming player).
  - Tactical changes: mentality, formation, roles/duties, instructions. The engine reacts to both managers' changes; the opposing AI becomes more aggressive if it is losing late on.
  - **Match Plans**: automatic conditional changes ("if we are winning by 1 at minute 75 → cautious mentality").
  - Touchline shouts [R; removed in FM26 according to F20].
  - Half-time and full-time team talks (with player reactions) [R].
  - Assistant feedback during the match and live stats / data analysis [R].
- **Recurring criticism**: "the engine overreacts to minor tactical tweaks" (forums) [F17]; in FM26, no collision detection, goalkeepers passing through the post, passive defenders on the flanks [F20].

### 2.5 Tactics

- **Team mentality** has 7 levels: Very Defensive, Defensive, Cautious, Balanced, Positive, Attacking, Very Attacking [F21].
- **Formation, role and duty.** Each position has a role (e.g., "Deep-Lying Playmaker", "Wing-Back") and a duty (Defend / Support / Attack). Individual mentality **is not chosen directly**. It is a function of the team mentality and the player's duty [F21].
- **Team instructions**: sliding scales ("do X much more / much less often") grouped into **in possession / in transition / out of possession** [F21][R for the exact grouping].
- **Player instructions** for each player (close down the opponent, mark X, take more risks with passes, etc.) [R].
- **FM24.** The on-screen formation represents the defensive shape; what players do on the ball is defined by the instructions [F21]. **FM26** has separate in-possession and out-of-possession formations (a central midfielder in possession can be a defensive midfielder out of possession), with a visualizer for the transition [F20].
- **Tactical familiarity.** The team takes time to absorb a new tactic [R].
- **Feedback on whether it works** [R]: assistant assessment ("the tactic is…"), analyst reports, heat/pass maps, player ratings and, above all, **seeing it in the 2D engine**. [I] This is the biggest source of frustration. The causal link between tweaks and results is opaque, and the community compensates with "game-breaking tactics" websites (e.g., FM-Arena tests tactics in bulk) [R].

### 2.6 Transfers, contracts, youth academy

- **Scouting** [R]: a scouting network with assigned regions, **knowledge per region** (a percentage that determines which players you see and how accurately), "recruitment focuses" (search criteria), reports with ability and potential stars and a letter-grade recommendation. Reports are filtered through the scout's quality. A scout with poor judgment can be wrong about a player [F22].
- **Transfer negotiation** [R]: fee + installments + clauses (percentage of next sale, appearance fee, goal bonuses, promotion bonus, international cap bonus, buy-back option), loans with or without an option to buy.
- **Contract** [F23]: length, weekly wage, squad status (star player, first team, rotation…), goal and clean-sheet bonuses, release clause (some players demand one). [R] The agent gets involved; the promised squad status creates expectations of playing time.
- **Youth academy** [R]: annual arrival of youngsters (the "youth intake") whose quality depends on facilities, junior recruitment and the Head of Youth Development; loans to give them minutes.

### 2.7 Training and coaching staff

- **Sessions** [F24]: physical (Endurance, Strength, Quickness), tactical (attacking/defensive Shadow Play), match (Match Practice, Match Preview, Match Review), team bonding (Team Cohesion, Community Outreach) and Recovery. Intensity can be set automatically according to each player's condition [F24]. [R] 3 daily slots, weekly planning, individual training focused on an attribute or role.
- **Coaching staff** [R]: assistant manager, coaches by area (with quality stars), fitness coaches, physios, sports scientists, analysts, scouts, director of football, head of youth development. FM Touch reduces this to one member per role and removes several roles [F7].
- **Criticism**: in FM26 "it can take up to 105 clicks to set up the weekly training schedule" [F20].

### 2.8 Club economy and board

- [R] Income: gate receipts, season tickets, TV rights, competition prize money, sponsorships, merchandising, transfers. Expenses: wages (with a **wage budget** set by the board), transfers, facilities, staff.
- [R] **Board.** At the start it communicates the **club vision** (1- and 5-year objectives: league position, playing style, use of homegrown players, financial health) and a **Board Confidence** rating by area (results, matches, transfers, finances, supporters). If it drops below a certain threshold, you get sacked; you can ask for a bigger budget, stadium upgrades or facility improvements.
- Confirmed criticism: board expectations unrealistic for the club's financial state, mid-season wage budget cuts, unexpected sackings even when promises were kept (reported as bugs) [F25].

### 2.9 Competitions

- [R] Dozens of playable countries with their real leagues (including semi-professional divisions), domestic cups, continental competitions, national teams (you can manage one at the same time as a club), promotion/relegation and playoffs with each country's real rules, a real calendar with FIFA windows. The player chooses which leagues to load (more leagues = slower).
- FM26 added women's leagues (14 in 11 countries) and temporarily removed national team management [F20].
- [F26] More than 2,000 professional footballers act as alpha testers; SI considers itself "as much a football business as a video game business". [I] The database and its network of researchers is the franchise's core asset, not replicable by a small team (nor necessary in a fictional sport).

### 2.10 Interface and presentation

- [I] Spreadsheet/data-dashboard aesthetic: tables, filters, configurable columns, player profiles with color-coded attributes. Immersion comes from the narrative (Inbox, press, stories), not from the visual environment.
- FM26 redesigned navigation with three levels (top menu, submenu, bookmarks), "information in smaller chunks for shorter attention spans" and a searchable in-game encyclopedia (**FMPedia/"Fampedia"**) that explains tactics and tells you which screen to go to [F27]. They designed around **six player "personas"** [F27]. However, the change broke years of muscle memory and required more clicks [F12][F20].

### 2.11 What hooks and what frustrates

**Hooks** [F28 unless marked]:
- **Emergent stories** (the most important factor according to the cited analysis): your own career, the club's rise, the youngster who becomes a star.
- **Unpredictability**: unexpected crises (a starter asking to leave for Bayern in the middle of the window).
- **Statistical depth and fog of war.** Learning to read the system is a game in itself.
- **Community**: sharing stories, debating mechanics, challenges ("journeyman", starting unemployed, winning with small teams) [F2][F28].
- [F2] CM classics: taking a team from the lower divisions to the top, exploiting cheap free agents, discovering undervalued youngsters.

**Frustrates**:
- **Barrier to entry.** Many newcomers quit within the first hour [F27].
- Repetitive **press conferences** ("the cancer of the game" according to one veteran; almost identical questions every match) [F29].
- **Tactical opacity**: the feeling that the engine overreacts or is "random" (thread "FM26 match engine is pure random") [F17][F30].
- **Micromanagement**: training (105 clicks in FM26) [F20].
- **Board** with unrealistic expectations [F25].
- **Bugs and regressions** in annual releases, a feeling of "yearly rehash" [F26][F12].

### 2.12 Levels of depth / accessibility

- **FM (PC)**: everything.
- **FM Touch** (PC/tablet/console): much simpler; focus on tactics, transfers and matches; less media interaction, no half-time team talk, very simplified training and staff (one member per role, no sports scientist or analyst) [F7].
- **FM Mobile**: the simplest and fastest; almost all the time is spent signing players and playing matches; 2D engine [F7].
- **Delegation** within the full game. Almost everything can be delegated to the assistant (training, press conferences, friendlies, youth contract renewals) [R].
- [I] The lesson is that SI solved accessibility **with separate products** rather than with modes within the same game; a small team cannot maintain three SKUs, but it can maintain **a single game with aggressive delegation by default**.

---

## 2bis. Football Manager 2007 in detail (main reference)

> Source note: Sports Interactive's official forums (where almost all period documentation lives) block automated reading (403, also with curl), and the FM 07 manual is not online. For this section I used period guides from FMScout and blogs by FM 07/FM 08 players, Wikipedia, 2006 reviews (Vandal, Mundogamers, VideoGamer; GameSpot and IGN only through search engine snippets, because they block reading) and search snippets about SI threads. The FM wiki on Fandom also blocks reading (402); its API returns an FM 07 page that is barely a stub, with no useful content. Where a fact is confirmed for FM 08 or FM 2011 but not for FM 07, I say so.

### 2bis.1 Context and what FM 07 brought

- **Release**: PC/Mac on 18-Oct-2006 (Europe) and early November (Australia/North America); Xbox 360 and PSP in December 2006 [F69].
- **Reception**: 87/100 average on Metacritic, BAFTA Gamers' Award, ELSPA Platinum (more than 300,000 copies in the UK) [F69].
- **New features compared with FM 06** (more than 100 according to SI) [F69][F70]:
  - **Pre-match team talk** (previously there were only half-time and full-time talks) and "more intuitive" half-time and full-time talks, with talks to individual players [F69][F70]. Team talks had existed since FM 06 [F87].
  - **Opposition instructions**: mark a specific opponent, close him down or always tackle him hard [F69][F70].
  - **Match time visible on the tactics screen** and a full-screen scoreboard [F70].
  - Match engine with **more events and better commentary**; substitutes warm up on the touchline; controversial decisions are highlighted more; the manager can comment on the referee to the press [F69][F70].
  - **Player interaction**: telling a player he is going to be rested so he doesn't get upset, commenting on his form to boost his morale, and asking the squad's opinion on match preparation or on signings [F69][F70].
  - **New youth system** (internal name "Fred") that replaces recycled "regens". Only a small fraction of youngsters "make it", and quality depends on facilities [F70].
  - **Affiliate clubs**, scouting reworked with scouts' **report cards**, a board that authorizes a new stadium, club takeovers by investors [F69][F70].
  - "Hints and tips" while the game processes matches [F71].
- **What FM 07 did NOT yet have** (useful to avoid over-copying):
  - **FM 08** added an "advisor system" similar to the assistant's role and a new financial system [F72].
  - **FM 2010** added **touchline shouts**, the **tactics creator**, **in-match assistant analysis**, the **match analysis** tool (pass, shot and tackle maps) and replaced the side menu with tabs [F73].
  - [I] So in FM 07 the manager finds out how the match is going by watching the 2D view, the stats, the player ratings and the commentary, without a live "tactical advisor".
  - The 3D engine arrived with FM2009 [R].

### 2bis.2 Player attributes (1-20 scale)

All visible attributes range from 1 to 20 [R, very likely; the tactical sliders of the era also use 1-20 [F77] and the hidden ones are 1-20 [F81]]. This is the FM 07 list. Most of it is **confirmed for FM 07** because it appears in the FM 07 training-category mapping [F74][F75] or in FM 07 guides [F80].

**Technical (14)**

| Attribute | FM 07 confirmation |
|---|---|
| Corners | [F75] (Set Pieces training) |
| Crossing | [F74][F75] |
| Dribbling | [F75] (Ball Control) |
| Finishing | [F74][F75] |
| First Touch | [F75] |
| Free Kicks | [F74][F75] |
| Heading | [F75] |
| Long Shots | [F74][F75] |
| Long Throws | [F74][F75] |
| Marking | [F74][F75] |
| Passing | [F74][F75] |
| Penalty Taking | [F74][F75] |
| Tackling | [F74][F75] |
| Technique | [F75] |

**Mental (14)**

| Attribute | FM 07 confirmation |
|---|---|
| Aggression | [R] |
| Anticipation | [F74][F75] |
| Bravery | [F80] (center back requirement) |
| Composure | [F74][F75] |
| Concentration | [F74][F75] |
| **Creativity**, later renamed **Vision** | [F74][F75] the FM 07 name is "Creativity"; SI says it "was always called Vision internally" [F79b]. I could not confirm in which version it was renamed [R: approx. FM2010] |
| Decisions | [F74][F75] |
| Determination | [R] visible; guides from the era name it as a development factor [F82] |
| Flair | [F75] |
| **Influence**, later **Leadership** | [F80] (key attribute for choosing a captain); the rename to "Leadership" is [R] |
| Off the Ball ("Movement" in some guides) | [F74][F75] |
| Positioning | [F74][F75] |
| Teamwork | [F74][F75] |
| Work Rate | [F74][F75] (Strength training) |

**Physical (8)**: Acceleration, Agility, Balance, Jumping (later "Jumping Reach" [R]), Natural Fitness, Pace, Stamina, Strength. All 8 are confirmed in FM 07 through the Strength and Aerobic categories [F74][F75].

**Goalkeeping (11)**

| Attribute | FM 07 confirmation |
|---|---|
| Aerial Ability | [F74] |
| Command of Area | [F74] |
| Communication | [F80] (goalkeeper indicator) |
| Eccentricity | [R] for FM 07; the definition is in [F88] |
| Handling | [F74] |
| Kicking | [F74] |
| One on Ones | [F74] |
| Reflexes | [F74] (Aerobic training) |
| Rushing Out | [R] for FM 07; definition in [F88] |
| Tendency to Punch | [R] for FM 07; definition in [F88] |
| Throwing | [F74] |

[R] Goalkeepers also have the mental and physical attributes. In addition, all players have a **left foot and right foot** rated 1-20 and a **familiarity per position**.

**Hidden (13)**, 1-20, confirmed as the FM 07 list in a search snippet [F82]:

- Performance: **Consistency**, **Dirtiness**, **Important Matches**, **Injury Proneness**, **Versatility**.
- Personality: **Adaptability**, **Ambition**, **Controversy**, **Loyalty**, **Pressure**, **Professionalism**, **Sportsmanship**, **Temperament**.
- On top of these are **Current Ability (CA)** and **Potential Ability (PA)**, 1-200 [F6, general series fact; R for FM 07]. [R] The database uses negative PAs (for example −10 or −9) that are resolved randomly within a range when the save starts.

**How hidden attributes are shown.** They do not appear on the profile. They are revealed through **phrases in scout and coaching staff reports** [F81][F82]:

| Hidden attribute | Example phrase |
|---|---|
| Consistency | "Very consistent performer" / "fairly inconsistent performer" |
| Important Matches | "Enjoys big matches" / "Doesn't feel comfortable playing in big matches" |
| Injury Proneness | "Fairly susceptible to injuries" |
| Dirtiness | "Has a competitive streak which can occasionally lead him to bending the rules" |
| Adaptability | "Should have no problems adapting to living in another country" |
| Versatility | "Can play in a couple of positions" |

- [R] Personality is summed up in a label ("Model Professional", "Determined", "Temperamental"…), and a style of dealing with the press is also derived from the hidden attributes.
- **Presentation options**:
  - When starting a save you can enable **attribute masking**: the attributes of little-known players or players in lower leagues stay hidden until you scout them [F82].
  - Since FM 06, attributes can be shown **as numbers or as a graphic** (the "Graphical Attributes" preference), with colors by range (low, normal, good, excellent, special) editable in an XML file [F86].

### 2bis.3 Progression and regression

- **Model.** CA grows toward PA and never exceeds it [F6]. CA is distributed among the attributes according to the player's position [R]. Attributes are stored **with decimals** and the screen shows only the integer part [F83, forum snippet].
- **Factors confirmed in FM 07 guides**:
  - **Training**: categories and intensity, **number and quality of coaches**, each coach's workload and **facilities** [F74][F83].
  - **Match experience.** Loans are "the best way for young players to gain competitive experience" [F80]. After an injury, regain sharpness in the reserves before returning to the first team [F80].
  - **Personality.** Development depends on PA and on traits such as determination, consistency, important matches and versatility, most of them hidden [F82].
  - **Age.** Youngsters tire sooner and need less workload [F74].
  - **Pre-season and holidays.** Attributes **drop naturally during the end-of-season break**; intense physical work belongs in pre-season [F74].
  - **Versatility.** Versatile players retrain to another position more easily [F74].
- **Decline after 30** [R for FM 07; F11 is community testing on modern versions]:
  - Physical attributes drop first (pace and acceleration), more slowly if Natural Fitness is high.
  - Mental attributes can keep rising for a while.
  - Sharp drops arrive around 31-33. Goalkeepers decline later.
- **"Rebalancing".** When CA changes, the game redistributes attributes and some may drop even if the player improves overall [F83, snippet; documented in later versions].
- **How it looks on screen**: **attribute change arrows**.
  - **Green pointing up** = improvement; **red pointing down** = decline [F83].
  - **The angle indicates the magnitude.** A slanted arrow is a fractional change (for example, from 15.0 to 15.2); an arrow pointing **straight up** is a whole point [F83].
  - An **orange arrow** is a fractional drop that hasn't yet reached a full point; if it repeats, the attribute ends up dropping [F83].
  - According to a snippet that links this to an SI thread titled "FM 2007 Training Help", the player sees the arrows on the **training screen** when showing "recent changes" [F83].
  - **Caveat.** I could not read the threads and I don't have an FM 07 screenshot. The "show attribute changes" checkbox on the profile is confirmed for **FM 2011** [F83b].
  - **Another use of arrows.** On the FM 2011 training screen, green/red arrows indicate **how the player is responding to training** ("his attitude and response, not the actual benefit"), which is not the same as the attribute change [F83c]. I could not confirm whether FM 07 had this second meaning. **This needs to be confirmed with an in-game screenshot if the arrows are going to be a central piece of the design.**
- **Progress report**:
  - Confirmed in FM 07: the **assistant's squad report** ("ask your Assistant Manager for a team report") [F80] and scouts' **report cards** [F69].
  - [R] The player's training tab had a **progress graph** (training performance or attribute values over time) and a training performance rating. I could not verify it.
  - [R] The ability and potential **stars** in coaching staff reports are from later versions; I did not confirm them for FM 07.

### 2bis.4 Training by categories and workloads

**9 categories** in FM 07, each with the attributes it improves [F75; matches F74 and FM 08 in F76]:

| Category | Attributes trained |
|---|---|
| Strength | Natural Fitness, Stamina, Strength, Work Rate |
| Aerobic | Acceleration, Agility, Balance, Jumping, Pace, Reflexes |
| Goalkeeping | Aerial Ability, Handling, Kicking, Throwing, One on Ones |
| Tactics | Anticipation, Decisions, Positioning, Off the Ball, Teamwork, Command of Area |
| Ball Control | Dribbling, First Touch, Flair, Heading, Technique |
| Defending | Tackling, Marking, Concentration |
| Attacking | Passing, Creativity |
| Shooting | Finishing, Long Shots, Composure |
| Set Pieces | Crossing, Corners, Free Kicks, Penalty Taking, Long Throws |

- **Workloads.** Each training schedule sets an **intensity slider per category**, on a scale with **light / medium / intense** bands [F76][F85]. Schedules are assigned to groups or to individual players [R].
  - Community schedules (for example the "Viola" ones for FM 07) lowered the physical sliders "to one notch above the start of medium" because intense strength workloads caused injuries; other players reported big improvements with intense strength and aerobic work for two months [F85, snippet].
- **Schedules are files.** They are saved in a `training` folder in the user's documents and shared between players [F77]. For FM 08, community schedules such as "SK" are cited [F85]. [I] A community trading "schedules" as data is a highly reusable pattern.
- **Coaches**:
  - Number and quality matter. If every player has a different schedule, there may not be enough coaches, and **an overloaded coach performs worse** [F74][F83].
  - [R] Each coach has a star rating per category, derived from his attributes (Coaching Attacking/Defending/Fitness/Goalkeepers/Tactics/Technique, Mental, Working with Youngsters); an FM 08 guide talks about "7-Star Coaching" [F77].
  - The goalkeeping coach works with first-team and youth goalkeepers; youth coaches work only with youngsters [F74].
- **Period guidelines** [F74][F80]:
  - Intense physical work belongs in pre-season; during the season it tires players more and raises injury risk.
  - If there are training injuries, lower the strength or aerobic intensity.
  - Training also serves tactical and positional familiarity, morale, cohesion and fatigue.

### 2bis.5 Top-down 2D match engine

- **Representation**: top-down view of the pitch with players as **numbered circles** (the shirt number) moving across a pitch that is normally green but **wears down to brown patches** to show the state of the surface [F89]. Vandal describes it as "a board with counters numbered with the shirt number" [F90]. [R] Text commentary line, scoreboard and clock.
  - **Pitch size changes depending on the stadium** and affects the match (a small team with an attacking tactic suffers more on a big pitch) [F91].
  - GameSpot: "not the most sophisticated way of presenting a match"; other managers of the era (LMA Manager 2007) were flashier [F89].
  - A period review: "its simplicity allows quick loading and good performance, and yet it perfectly captures the ebb and flow of the sport" [F71].
  - It is a direct descendant of the 2D engine introduced in CM4 in 2003 [F3][F4].
- **New in FM 07**: more events, improved commentary, substitutes warming up and highlighted controversial decisions [F69][F70].
- **Viewing levels.** Vandal (FM 07, Xbox 360) confirms you could watch the **full match, only the highlights or only the goals**, with stats and player information accessible during the match [F90]. [R] The in-game names were "Key Highlights", "Extended Highlights", "Full Match" and "Commentary Only", with a speed slider in "notches"; that exact list is confirmed in FM 2011 threads [F92], not FM 07. The "Comprehensive" level came later [R].
- **Side panel** (tree menu): lets you see the **opponent's formation and the changes** it makes during the match, plus stats, ratings and player condition [F80].
  - A **green cross** next to a player indicates a knock; he can recover during the match without it becoming an injury [F80].
- **External factors**: **referee strictness** (with a strict referee it pays to lower tackling to "easy" or "normal") and **weather**, which affects different playing styles differently [F80].
- [R] Matches in other leagues were resolved with a lower level of detail, as in later versions (see §2.4); I did not confirm this for FM 07.

### 2bis.6 Manager options during the match

- **Live tactics screen**:
  - With the **match time visible** [F70], you can change the formation, the team and individual sliders, and the opposition instructions [F69][F80].
  - Period advice: prepare **three tactics** (the main one, an aggressive one to chase a goal and a defensive one to protect the result) and switch between them [F80b]. Changing constantly or making drastic changes prevents players from "settling" and worsens performance [F80].
  - End-of-match tools: **time-wasting** and adjusting the pressing [F80].
- **What can be done and when.** According to GameSpot, once the match starts the manager is "relatively powerless". **Basic tactics can be changed on the fly**, "as if shouting instructions from the touchline", but **big changes and substitutions only take effect when play stops** [F89].
- **Substitutions**: [R] three substitutions from a bench of five, according to each competition's rules; the incoming players can be seen in the 2D view.
- **Period criticism of the match**: "the slowness when making changes mid-match" and the lack of a set-piece editor [F91].
- **Team talks** (three moments) [F69][F70][F80]:
  - **Before the match** (new in FM 07), at **half-time** and at **full-time**.
  - There is a general talk and **individual or per-line** talks; it is recommended to give an individual talk to a player who reacted badly to the general one [F84].
  - Tones documented by community guides: "no pressure" (for nervous players or debutants), "I expect a win" (only if they are clear favorites and morale is good), "pleased" or "well done", and harsh criticism (the "hairdryer") [F84].
  - Harsh criticism with low morale is counterproductive, and some players **complain to the press** afterwards [F80c].
  - Players **react** visibly; the reaction depends on personality and morale [F84][R].
- **Assistant notes**:
  - Confirmed for FM 07: the assistant's **squad report** [F80], the **opposition report** before the match [R] and the option to **ask players' opinion** on match preparation [F70].
  - A team talk guide says a player shows as "nervous" or "under pressure" in the **"Assistant's Feedback"** [F84], but I could not confirm that this text is from FM 07.
  - What FM 07 definitely did **not** have is in-match tactical analysis from the assistant; it arrived with FM 2010 along with shouts [F73].
- **What it did not have**: touchline shouts (FM 2010 [F73]) and "match plans" (later [R]).

### 2bis.7 Tactics screen: pitch with arrows, sliders and player instructions

- **Formation.** Each player icon is dragged to its position on a mini-pitch [F84b].
- **Arrows on the pitch**:
  - A **dotted arrow** indicates the player's **runs into attack** ("Forward Runs") [F84b].
  - There are also **in-possession position arrows**. The arrow points to where the player will be **with the ball**, and without the ball he positions himself in the opposite direction (the "Barrows", backward arrows) [F77, FM 08 guide].
  - [I] The circle is the defensive position and the arrow the attacking movement, almost the same metaphor as PC Fútbol's mini-stadium with range arrows (§3.7).
- **Team instructions** (sliders numbered internally 1-20, all starting at 10 [F77]):

| Instruction | Values |
|---|---|
| Mentality | defensive ↔ attacking |
| Creative Freedom | little ↔ a lot |
| Passing Style | short / mixed / direct |
| Tempo | slow ↔ fast |
| Width | narrow ↔ wide |
| Time Wasting | low ↔ high |
| Closing Down | rarely / mixed / often |
| Defensive Line | deep / normal / pushed up |
| Tackling | easy / normal / hard |
| Marking | zonal / man-to-man, and tight / loose |
| Focus Passing | flanks / middle / mixed |
| Counter Attack | yes / no |
| Offside Trap | yes / no |

  Table sources: [F78][F79][F80]. A guide from the era adds Mentality, Creative Freedom, Passing, Tempo, Width, Time Wasting, Closing Down, Defensive Line and Tackling as the nine main sliders [F79].

- **Player instructions** [F78, a guide covering FM07-FM09; R for the exact FM 07 detail]:
  - Individual mentality, creative freedom, passing, closing down, tackling and marking (tight, or a specific opponent).
  - **Forward runs** (rarely / mixed / often).
  - **Run with ball** and **long shots** (rarely / mixed / often).
  - **Through balls** and **crossing** (rarely / mixed / often); **cross from** (deep / mixed / byline).
  - **Hold up ball** (yes / no).
  - **Free role**, **target man** (with the ball to head or to feet) and **playmaker**.
- **Period advice on combining instructions** [F79][F80]:
  - Tempo and passing go together: short passing with slow tempo, direct play with fast tempo.
  - A lot of creative freedom up front, mixed in midfield and little at the back, and only for players with high creativity, flair, technique and passing.
  - Closing down often tires players more.
  - Fast tempo with a narrow team, slow tempo with a wide team.
- **There were no roles or duties** (Defend/Support/Attack) on the screen. They are introduced with the FM 2010 tactics creator [F73][I]. In FM 07 the "role" is the result of the position plus the sliders.
- **Tactics are files** that are downloaded and shared; there was a whole culture of "downloaded tactics" [F85]. [I] That culture is also a symptom of opacity. Players import tactics because it's hard to know why one works.
- **Feedback on whether the tactic works** in FM 07 [I, based on the above]:
  - Result, player ratings (1-10), match stats, what you see in the 2D view, the opponent's formation in the side panel, and morale.
  - There was no analysis tool or live tactical advice (both arrive in FM 2010 [F73]).

### 2bis.8 FM 07's own new features and surrounding systems

- **Feeder (affiliate) clubs**: a new section on each club's profile [F91].
  - A big club pays the affiliate an **annual fee** (Mundogamers's example is Atlético de Madrid with a Segunda B club, Spain's third tier at the time).
  - In return it can take promising youngsters from the affiliate, send it players on loan to gain experience, and play friendlies against it that earn the affiliate some money [F91].
  - Other sources add easier work permits and merchandise sales in other regions [F93]. There are several types of agreement [F70].
- **Scouts by region**: **knowledge bars per country or region** based on each scout's experience; some specialize.
  - A small club scouts locally; one competing worldwide needs global knowledge [F89][F93].
  - Scouts **learn** about the areas they have already covered [F69][F93].
  - They are assigned to a region for a set period [F90].
  - Scouts and coaches show their experience with **bar charts** [F93].
- **Manager knowledge by region.** The manager profile has **knowledge of countries**, which counts when you apply for a job in another country and widens the players that appear in searches [F91].
  - You can choose **two nationalities** to have more knowledge [F91].
  - When creating the profile you choose the manager's **level of previous experience** [F91].
- **Start modes** [F91]: choose a club; start in a lower division; random club; or **start unemployed** waiting for offers.
  - [I] The latter is the direct equivalent of PC Fútbol's Promanager.
- **Job Centre**: advertises vacancies for physios, coaches, scouts, assistants and managers. You can post an ad and wait for candidates, or apply to a club ("Apply For Job") [F94]. It has existed since FM 2005 according to a snippet [F93]. [R] that it stayed the same in FM 07; the detailed descriptions I found are from modern versions.
- **Press without press conferences**:
  - In FM 07 the press arrives as **journalists' questions** (about the next match or a player's performance), with **degrees of praise or criticism** and the option to **comment on any player** or on the referee [F69][F93].
  - **Press conferences** only appear in **FM 2009** [F95].
  - [I] Good for us, since FM 07 predates the series' most criticized feature (§2.11).
- **Player interaction**: conversations depending on the player's situation, face to face or through the media. You can talk about his form, tell him he is going to be rested, make promises in a negotiation or ask his opinion on signings [F69][F70][F91].
- **Board**: welcome from the chairman with **season objectives** [F91]; the board decides on transfers and wages, authorizes a new stadium, and the club can be taken over by investors [F70].
  - Period guidelines: staying within the wage budget improves your relationship with the board; so does turning down offers from other clubs; ultimatums can end in the sack [F80].
- **"Fred" youngsters**: youngsters generated from scratch instead of recycling retired players, in a distribution where only a few "make it" [F70][F90].
- **Default staff.** The club starts with plenty of assistants already hired, so you don't waste time looking for coaches or scouts [F91].
- **Help features**: a setup wizard when starting the save and **help pop-ups** that appear when pressing Continue [F91]; tips while matches are processed [F71].
- **Pacing.** Mundogamers highlights that FM 07 fixed FM 06's "weekly slowness": "day-to-day happens in a matter of seconds" [F91].
- **Scale**: more than 50 countries and 300,000 players and staff; editor included; downloadable skins; multiplayer and online modes [F91]. Mundogamers scored Gameplay 10, Graphics 6, Sound 6 (no music) and 8 overall [F91]. Vandal (Xbox 360) gave it 8.5, with Fun 9.5 and Sound 2 [F90]. GameSpot gave it 8.5 [F89].

### 2bis.9 Screen structure and navigation

- **Browser-style navigation.** FM 07 introduces **"back" and "forward"** buttons in the style of a web browser, within a new interface redesigned with user input [F96, snippet].
- **Default skin.** The **colors of the club** you manage dominate the top, combined with a **toolbar at the bottom** of the screen; licensed crests and kits in the menus [F91].
- **Side tree menu.** It is the entry point to the club's areas (Squad, Tactics, Training, Scouting, Finances, Schedule, etc.) and is also used during the match to view formations and stats [F80][R for the list of areas]. FM 2010 replaced it with tabs, which confirms that FM 07 used the side menu [F73].
- **Console version (Xbox 360)**: tabs on the triggers, "B" to go back, left trigger for the main menu and right trigger for the **"Actions" menu** [F90][F97]. [I] This mirrors the PC structure: a main menu of areas, tabs inside each screen and a contextual actions menu for the entity you are viewing (player, club, staff member).
- **Screen loop** [R, consistent with §2.2]: Inbox (news) → Continue → club screens as the Inbox requires → match day (lineup and tactic → pre-match talk → 2D match → half-time talk → match → full-time talk) → Continue.
- **Attributes on the profile**: can be shown as numbers or as a graphic, with colors by range [F86].

### 2bis.10 What to take from FM 07 (design summary; detail in §6)

- **Copy** [I]:
  - 1-20 attributes grouped into technical, mental and physical.
  - **Hidden decimals and arrows whose angle indicates the magnitude of the change**.
  - A **fixed table mapping training categories to attributes** with workload sliders.
  - **Hidden attributes revealed through phrases** in reports.
  - **Mini-pitch with circles and arrows** plus team sliders and player instructions.
  - Team talks at **three moments** with reactions.
  - **Three prepared tactics** for quick switching during the match.
- **Simplify** [I]: reduce the 13 team sliders to about 5 with a visible effect; reduce the 9 training categories to those that make sense in the new sport; group the hidden attributes into 4-6.
- **Improve on FM 07** [I]: add the minimal tactical feedback that FM didn't get until 2010 (the assistant saying what's going wrong), because opacity was the central complaint and the reason for the downloaded-tactics culture.

---

## 3. PC Fútbol (Dinamic Multimedia)

### 3.1 Historical context

| Year | Version | Key new feature |
|---|---|---|
| 1992 | Simulador Profesional de Fútbol | First Spanish football manager; foundation of the series [F31] |
| 1993 | PC Fútbol 2.0 | 1993-94 La Liga license (1st and 2nd divisions, 380 matches), 450 real photos, crests; Liga Manager, Liga Pro-Manager, Liga Arcade and friendly modes; Michael Robinson as the face, with videos in a proprietary "TDC" system; it fit on a ~3 MB floppy disk [F31] |
| 1994 | PC Fútbol 3.0 | First version with transfers, cards and suspensions; 70,000+ copies [F31]. First international versions: PC Calcio and PC Fútbol Argentina Clausura [F32] |
| 1995 | PC Fútbol 4.0 | First CD-ROM; **Promanager career mode** (modest club, low budget, world ranking of managers); individual morale per player; 234 teams, 3,980 players; playable Argentine league [F33] |
| 1996/97 | PC Fútbol 5.0 | Primitive 3D simulator (3D stadiums + sprites), manageable Segunda B (122 teams), four management approaches; 305,000 copies; considered the peak [F34][F35][F36] |
| 1997 | PC Fútbol 6.0 | Map for choosing teams from any country, matchday newspaper, voiced staff [F37] |
| 1998 | PC Fútbol 7.0 (+7.5) | Euro PC Fútbol (5 leagues), Desafío Mundial, Pro Quinielas; sales peak [F38] |
| 2000 | PC Fútbol 2000 | New leadership after the founders left [F39] |
| 2001 | PC Fútbol 2001 | 11 licensed countries, 3D environments, EuroManager, online 3D match for up to 4 players; the last by Dinamic, which went bankrupt on 21-Sep-2001 [F40] |

(Segunda B was Spain's third tier; Pro Quinielas refers to the Spanish football pools.)

- **[C] PC Fútbol 5.0 date.** pcfutbol.com labels it "(1996)" [F34]; English Wikipedia says it was released in January 1997 [F35]. It probably refers to the 96-97 season with a commercial release in early '97 [I].
- **[C] PC Fútbol 7 sales**: 360,000 according to Wikipedia [F32]; 370,000 according to the creators in Xataka [F39]. Wikipedia says ~1 million for the whole main series [F32]; [I] that figure seems low if 5.0 and 7.0 alone add up to ~675,000.
- **[C] The "Pro-Manager" name.** The PC Fútbol 2.0 (1993) entry already lists a "Liga Pro-Manager" mode (described as a coach role) [F31], but all sources credit **4.0 (1995)** with introducing Promanager as a **career mode** with progression between clubs [F33][F41]. [I] The label existed earlier with a different meaning.
- **Decline**: after the success of 7.0, conflicts between the Ruiz brothers (the founders) and the publisher; the founders and Carlos Abril left in March 1999 and founded FX Interactive [F39]. The 2000/2001 versions bet on 3D and higher resolution; 2001 arrived late (March) and more expensive (4,000 pesetas) [F39]. Persistent bugs even after 12-16 patches (version 3.6) [F42]. Competition from EA and SI [F32]. Gaelco's revivals (2005-2007) were "riddled with bugs, almost unplayable" [F43]; PC Fútbol 8 was announced for 2023 and abandoned in 2025 [F32].

### 3.2 Why it was loved in Spain and Argentina

- **Price and distribution.** It cost roughly **half** as much as typical PC software; it was sold at **newsstands** (some 30,000 in Spain, versus ~1,000 video game stores). "For many people it was their first video game" (Pablo Ruiz) [F39]. In Argentina it sold for **16 pesos** at newsstands, bookstores and computer shops [F44], with a VAT discount because it was a newsstand sale [F45].
- **Deliberate simplicity**: inspired by **Kevin Toms's Football Manager**, not Championship Manager [F39]. In Argentina it is remembered as the opposite of CM's complexity [F45].
- **Annual ritual.** The release of each version became part of the Spanish football calendar for eight years; kids went to the newsstand to see if it was out [F31][F43]. Data updates via modem/server and via floppy disk sent by mail or included with magazines (in Argentina, the Clausura 97 update) [F32][F44].
- **Michael Robinson** (former Liverpool player, Canal+ presenter): face and voice of the series; he wrote the team analyses, appeared in season-tracking videos and had catchphrases in the commentary that "although excessively repeated, were entertaining" [F32][F36][F39][F46]. According to Pablo Ruiz, at first he didn't even ask for money [F39].
- **Argentine localization**: PC Fútbol Argentina Clausura 95 (March 1995, the first), Apertura 95, 4.0 Apertura 96, 5.0 Apertura 97, 6 Apertura 98 (released in July 1999, almost a year late), 2000 Clausura [F47][F48][F44]. Commentary by **Marcelo Araujo** [F33][F47]; according to a single source, **Víctor Hugo Morales** did the commentary for the Argentine 6.0 [F45, single source, unconfirmed]. According to pcfutbol.com, **Diego Maradona** appeared on the box of the Argentine version of 5.0 [F34, single source]. Argentine modes: Torneo Arcade, Torneo D.T., Torneo Manager and Pro-Manager (in 4.0 Apertura 96), and "Desafío América-Europa" (friendlies between European and Primera A clubs) [F44]. (Apertura and Clausura are Argentina's two short half-season tournaments; "D.T." stands for *director técnico*, i.e., head coach.)
- **Football context.** Version 5.0 coincided with La Liga's 96-97 season of star signings (Ronaldo, Romário, Rivaldo) [F36].

### 3.3 Game loop

- [F49] In 5.0: choose mode and difficulty → pre-season with friendlies → league. Each matchday generates administrative notifications: injuries, automatic renewals based on number of matches played, TV income. Long sessions are spent more on reviewing stats, renewing contracts and balancing the budget than on watching matches [F49].
- **Main screens (PC Fútbol 2001, EuroManager mode)** [F50]:
  - **Coach**: Lineup (11 starters, 5 substitutes, the rest not selected), Tactics, Advanced Tactics, Takers (set pieces), Stats, Training.
  - **Finances**: Cash, Insurance, **Confidence** (three meters: in the manager, from the fans, from the board), TV Offers, Sponsors, Merchandising, Catering.
  - **Stadium**: Overview, Advertising Boards, Attendance Graph, Remodel (stands, parking, services), Match Day (ticket prices).
  - **Tracking**: Results, Standings, Averages (relegation), League Progress, Top Scorers and Goalkeepers, Calendar, Watch Matches.
  - **Market**: Sign, Portfolio (shortlist, requires a technical secretary), Offer Status, Technical Secretary (search tool), Offers Received, Latest Signings.
  - **Staff**: Assistant, Board, Technical Secretary (the Spanish *secretario técnico*, roughly a director of football/chief scout), Groundskeeper, Assistant Coaches, Youth Coach, Scout, Head of Medical, **Psychologist** (morale), **Observer** (opponent's tactics).
- **Main menu** (2001): History, Database, Online Tracking, Team Editor, FutbolQuiz, Virtual Competition, Online 3D Match, EuroManager [F50][F51]. [I] The "manager" is just one of several products on the CD: database/encyclopedia, editor, arcade simulator and trivia. The game was also a **football encyclopedia**.
- **Session length**: no data. [I] Given the simplicity (few attributes, no Inbox forcing you to respond) and the "Result" mode, a season must have played much faster than in FM.

### 3.4 Game modes

- **Liga Manager.** You pick any team (1st, 2nd, 2nd B divisions) and manage it indefinitely [F38]. In 5.0, four approaches: **Coach, Manager, Chairman, or all three at once** [F35]. [I] It is a selector of "which subsystems you want to touch". The game automates the rest. In 2001: Chairman mode (finances, advertising, kits, tickets) vs. Coach mode (youngsters, signings, player complaints) [F51]. In Manager, if you get sacked the game is over [F37].
- **Liga Promanager** [F41][F52]:
  - You start "from scratch" and receive offers from lesser teams (Segunda B in Spain; in Argentina, modest Primera A clubs chosen at random [F44]).
  - Each club has a **season objective** set by the board. If you meet or exceed it, at the end of the season you receive offers from better clubs (or you stay). If not, the board may sack you and **your standing as a manager drops**.
  - Ladder observed by players: getting promoted with a 2nd B club whose objective was "avoid relegation" → you are offered teams with a "mid-table safety" objective; getting promoted with a "mid-table safety" one → you are offered 2nd B clubs with a "promotion" objective [F52].
  - World ranking of managers [F33].
  - In 6.0, one reviewer describes it as "a carbon copy" of Manager with offers from amateur clubs; the saves were interchangeable [F37].
- **Arcade / Interactive**: play the match controlling the footballers (keyboard/joystick). 2001 was the last version that allowed it [F40].
- **Others**: Euro PC Fútbol / EuroManager (several European leagues), Desafío Mundial, Desafío América-Europa, Pro Quinielas (football pools), FutbolQuiz [F38][F44][F50].

### 3.5 Player model

- **0-99 scale** [F50]. Reading bands: 60-69 average, 70-79 good, 80-89 very good, 90+ excellent [F50].
- **Four general attributes**: **Speed (VE), Stamina (RE), Aggression (AG), Quality (CA)** (abbreviations from the Spanish *Velocidad, Resistencia, Agresividad, Calidad*). The **overall (ME, *media*)** is the simple arithmetic average of the four, 25% each [F53][F54]. Original definition: "they scored goals according to their quality, ran according to their speed, kept up the pace according to their stamina and kicked people according to their aggression" [F55].
- **Specific skills** (later versions): Finishing, Dribbling, Passing, Shooting; set pieces: Free Kicks, Corners (left/right), Penalties; **Goalkeeper (PO)** [F50][F54]. They don't count toward the overall but affect performance [F53].
- **Status**: **Energy** (shown in red when low), **Form (EF)**, **Morale (MO)** [F50][F54]. Individual morale was born in 4.0 and fluctuates with playing time, results, transfers and how the manager treats the player [F33]. Bonuses/incentives for important matches raise morale [F50].
- **Age**: optional aging; retirement around 31 [F50]. Players under 29 handle more training load; older ones get injured more [F56].
- **Injuries**: with recovery times and purchasable **medical insurance** [F50].
- **Nationality**: max. 3 foreigners; naturalization after 3+ years [F50].
- **What it didn't have** [I]: hidden CA/PA-style potential, complex personality, consistency. Players in 2.0 "were immortal" (no injuries, suspensions or transfers) and behaved "exactly according to their parameters" [F55].
- **Community perception**: "what matters is having the starting eleven with the highest possible overall"; one moderator believes energy barely matters [F53]. [I] Readability came at a cost. The game was "solved" by stacking overall rating.

### 3.6 Match engine

- **Viewing** (7.0): **Result** (score only), **Summary** (text + stats), **Interactive** (play it, configurable duration of 2-20 minutes), **Simulation** (watch it without control) [F38]. In 2001: Interactive, Viewing, Summary, Result [F50].
- **Graphics**: primitive 3D since 5.0 (3D stadiums + sprites, moving camera) [F35][F36]; 2001, "fully 3D" [F46].
- **Simulator quality** (constant criticism): in 2001 "to win the ball from the opponent you have to chase him all over the pitch", goalkeepers who come out absurdly, "out of every 4 shots you score 5 goals" [F51]. In 6.0, replays "weren't accurate": goals that looked like misses in the replay [F37]. Vandal 2001: fun 9/10 but the simulator "is still poor after nine years" [F51].
- **[I] Critical lesson.** In 6.0 the result was calculated separately from the animation, and when the two didn't match the player noticed and lost trust. **If a match is shown, the animation has to be the truth (or be derived 1:1 from the simulation).**
- **Attribute influence.** The overall dominated; forums report that players with a lower overall sometimes perform better and that the result depends heavily on match events [F53].

### 3.7 Tactics

- **Mini-stadium.** Each player is a circle at his base position, with an **arrow marking how far forward he can go**; his lateral range can be widened [F57][F50].
- **Advanced tactics**: General / Attack / Defense sections [F50][F57]; parameters: style of play (attacking/mixed/defensive), **tackling intensity**, **pressing** (and the height of the defensive and midfield pressing lines), passing/touch style, **% counterattack**, **individual marking** [F57][F49].
- Interactions known to the community: high aggression + hard tackling = cards; high pressing + >75% counterattack = fatigue and injuries [F57]. Popular formations 4-3-3, 4-4-2, 3-5-2 [F58].
- During the match (in non-interactive modes), [R] you could make substitutions and modify tactics during pauses; the **Observer** reports on the opponent's tactics [F50][F38].
- [I] Feedback on whether the tactic works: almost nonexistent apart from the result and the stats; the community resorted to trial and error and save-scumming (one user admits saving before the match and replaying it until winning) [F58].

### 3.8 Transfers, contracts and youth academy

- **Contract**: annual wage, years (1-7), immediate arrival or at the end of the season, **release clause** [F50]. Automatic renewals based on matches played in 5.0 [F49]. Options: let him go, offer incentives to stay, sell and reinvest [F50].
- **Loans**, club staff, medical insurance [F36].
- **Youth scout** since 5.0 [F36]; hiring youngsters to build an academy (7.0) [F38]. Historic bug: youngsters who didn't progress (6.0) [F37].
- **Balance problems**: from 5.0 on, "any team could sign any player without its checkbook trembling" [F55]; the AI made absurd offers ("59 million") for players with high release clauses even if they were worth little [F37]; AI teams that kept over-age players or ended up with insufficient squads [F37].

### 3.9 Training and coaching staff

- 5-day plan (Monday-Friday) with sessions: stretching, ball recovery, passes into the box, gym, continuous running, speed sprints, small-sided games, masseur; goalkeepers: one-on-one rushes, high balls [F56]. Each position requires a specific type of training [F54].
- Hirable staff (see §3.3), each with its own function; the psychologist works on morale [F50].

### 3.10 Club economy

- Cash with a weekly/monthly breakdown of income and expenses [F49]; advertising income per match, stadium occupancy [F49]; TV, sponsors, merchandising, catering (bars, cafés, restaurants), advertising boards, ticket prices, modular stadium expansion, parking [F50].
- **Confidence** on three axes (manager, fans, board) [F50].
- Criticism: in the later versions, "bloated features" (catering, merchandising) with little gameplay value [F55].

### 3.11 Competitions

- Spain: 1st, 2nd, 2nd B (since 5.0), Copa del Rey, Supercopa; Europe: European Cup/Champions League, UEFA Cup, Cup Winners' Cup, European Super Cup, Intercontinental/Toyota Cup [F33][F36][F51]. Relegation averages in the tracking screens [F50]. Optional international call-ups [F50].
- Argentina: Apertura and Clausura (short tournaments) with Primera, Nacional B and Metropolitana depending on the version [F45][F44].

### 3.12 Interface and presentation (what made it different from FM)

- **Database/encyclopedia with photos**, honors, history of clubs and players with descriptive texts [F31][F44][F51]. It was a reference product as well as a game.
- **Michael Robinson** as presenter: written analyses of each team, season-tracking videos, commentary in the simulator alongside Chus del Río (5.0) [F36][F39].
- **Matchday newspaper**, **voiced staff** who tell you what's happening at the club ("listen to the events") and **team selection by clicking on a map** (6.0) [F37].
- **The "office".** I could not confirm in any source an interface with a desk/office metaphor. What is verified is: menus by area (Coach, Finances, Stadium, Tracking, Market, Staff) and, in 2001, a "completely revamped" interface [F46][F50]. **[Not verified]**
- A "for adults, not for kids" approach to management, according to a modern retrospective [F49].
- [I] Compared with FM: **fewer numbers, more "television"**. The identity came from the presentation (real people talking to you, photos, press), not from the depth of the model.

### 3.13 What hooks and what frustrates

**Hooks**:
- The **Promanager** arc: taking a modest team to glory, with real career promotions [F41][F43][F55].
- **Readable rationality**: in 2.0, "good management directly influenced results"; in 4.0, the balance between rational management and surprise (injuries, suspensions, aging) [F55].
- Price, newsstand, annual ritual, Robinson [F39].
- "Fun 9/10" despite everything else [F51].

**Frustrates**:
- Poor 3D simulator and absurd results [F51]; replays that don't match the result [F37].
- **Bugs**: corrupted saves, youngsters who don't develop, broken AI squads [F37]; 2001 with 12-16 patches [F42].
- **Too much freedom and too many features** that break the balance (signing anyone; catering) [F55].
- A transfer market the AI could exploit [F37].

### 3.14 Levels of depth

- **Role selector** (Coach / Manager / Chairman / All) within the same game [F35].
- Match **viewing selector** (Result / Summary / Simulation / Interactive) [F38].
- **Manager vs. Promanager**: sandbox with a team of your choice vs. career with objectives [F38].
- Complexity setup options at the start (EuroManager 2001): European competitions, aging, international call-ups, modular stadium, player stats, monthly awards [F50]. [I] **Systems that add workload are opt-in.**

---

## 4. Other sports managers: one or two lessons per game

| Game | What it is | Applicable lesson |
|---|---|---|
| **Hattrick** (browser, 1997-) | Online manager; weekly matches, text report | (1) **The engine can be abstract and still have depth**: midfield determines possession (possession = M_A / (M_A + M_B)), and up to 15 chances per match are split 5/5/5 (exclusive to each team + open ones weighted by midfield, P ∝ M³) [F59]. (2) All events are random rolls **weighted** by ratings, specialties and tactics: randomness exists but is readable [F59]. |
| **Out of the Park Baseball** | Baseball manager/GM of enormous depth | (1) **Real scouts' 20-80 scale**, with color coding (red → blue) and an option to show 0-5 stars: the scale adapts to what the player understands [F60]. (2) **The values you see pass through your scouting director's filter**: a bad one doesn't lie but is less reliable; scouting accuracy is configurable [F60]. |
| **Motorsport Manager** (Playsport Games) | Started as a mobile app (2014) and expanded to PC | (1) **First find the core that works at small scale, then grow** (mobile → PC) [F61]. (2) During the race the player makes real-time decisions from the pit wall; race day is "where your focus is" [F61]. [I] A direct equivalent of "during the match, only substitutions and tactics": live decisions must be few, clear and with visible consequences. |
| **Football Chairman Pro** (Underground Creative) | You are the chairman, not the manager; you start in the English 7th tier | (1) **A change of role opens up a new game with the same world**. (2) Squad summed up in **4 values** (goalkeeper, defense, midfield, attack); **~20 minutes per season** [F62]. [I] Proof that aggressive abstraction doesn't kill engagement if the decisions are relevant. |
| **New Star Manager** (Simon Read) | Casual manager with interactive matches | (1) **Minigames for repetitive decisions** (contract negotiation as "higher/lower"; team talk as a memory game) [F63]. (2) Matches that are "light on simulation, focused on scoring goals" [F63]. It started as a one-person project [F63]. [I] Useful as a reference for turning spreadsheet tasks into brief interaction, though with the risk of trivializing them. |
| **Blood Bowl** (league mode) | Fantasy sport with persistent teams | (1) **Progression via Star Player Points** earned through specific actions (completion 1, casualty inflicted 2, interception 2, touchdown 3, MVP 5) → level-up with skills [F64]. (2) **Permanent loss** (serious injuries, death) as a source of drama, offset by balancing mechanisms (mercenaries, bribes, temporary staff for the team with the lower value) [F64]. [I] Highly applicable to a fictional, violent sport like Quidditch. |
| **Basketball GM / ZenGM** | Basketball GM in JavaScript, open source, generated players | (1) **Procedurally generated fictional world** instead of a licensed database [F65]. (2) **Possession-by-possession simulation**: each possession ends in a shot or a turnover [F65]. [I] An example that a solo developer can sustain a very deep manager if the world is generated. |
| **Kevin Toms' Football Manager (1982)** [F1] | The original; explicit inspiration for PC Fútbol [F39] | [I] If the simplicity of 1982 could inspire Spain's best-selling series, a first release can start well below FM. |

---

## 5. Technical architecture of match engines

### 5.1 Three archetypes

| Archetype | Example | How it works | Visualization | Advantages | Disadvantages |
|---|---|---|---|---|---|
| **Tick-based positional with agents** | FM (0.25 s slices) [F15]; footballSimulationEngine (Node.js, iterations with player and ball positions) [F66] | Each tick, each agent evaluates the state and chooses an action based on attributes + instructions; simple ball physics | Comes "for free": the positions at each tick are drawn (top-down 2D = the cheapest) | What you see **is** what happened; tactics have a real spatial effect | **The hardest to calibrate** (realistic emergent stats, goals per match, absurd behaviors); CPU-expensive for thousands of matches |
| **Event / sector-based** | Hattrick [F59] | Ratings are compared per sector; chances and their outcomes are rolled | Text/events; to animate, each event must be **scripted** | Easy to calibrate and test (known distributions); cheap; ideal for unwatched matches | Without an extra layer it looks "dead"; tactics act as abstract modifiers |
| **Possession-based** | Basketball GM [F65] | Sequence of possessions; each one ends in an event (shot, turnover) with probabilities derived from attributes | Same as events | Very good balance between statistical realism and cost | Less natural in sports with continuous, simultaneous play |

### 5.2 Confirmed and recommended patterns

- **Separate simulation from rendering/interface.** Open-source football manager projects separate the engine (deterministic TypeScript) from the UI and persistence, with a competition layer that generates fixtures from a seed and runs deterministic seasons [F67]. FM explicitly works on "passing the best information from the AI to the animation system" [F15]. Animation consumes the simulation.
- **Seeded determinism.** The same seed and the same inputs (manager changes with a tick number) give the same match. It allows replaying matches, debugging, testing balance and making "replays" without storing video [F68]. Projects like openfootmanager are working on making the seed reproduce fixtures and squads too [F68].
- **Multiple levels of detail.** FM uses the full engine only for what is relevant and the "quick match engine" for the rest, which is also less random [F18]. [I] This implies that **the two engines must be calibrated to produce the same distributions** (goals, chances, injuries); otherwise balance differences appear depending on which matches the player watches. A community player warns that results change depending on whether you play the matches or go "on holiday" [F18].
- **Precompute vs. advance in segments.** SI describes the engine as calculating the 90 minutes and then picking highlights [F15], but live changes alter what follows and substitutions are applied at the next stoppage [F17]. [I] The likely model is that the engine simulates ahead up to the next decision point (or in a short buffer) and re-simulates from there if the manager intervenes; highlights are selected from the event log.
- **Highlights as a filter over an event log** [F15][F19][I]. The engine emits events with an importance level (goal > clear chance > shot on target > half-chance); the chosen highlight level defines the threshold.
- **Match Plans** [F17]: conditional rules set by the manager that the engine evaluates without interaction. [I] Useful for those who don't want to intervene and for the opposing AI (which uses the same mechanism).
- **Consistency between result and animation.** The PC Fútbol 6.0 case (replays that contradict the result) [F37] shows the cost of calculating the result separately and animating it afterwards without respecting it.

### 5.3 What is not publicly known

- Details of the FM engine (attribute weights, physics model, how it is calibrated) are a trade secret [F16]. What circulates are the community's empirical tests (FM-Arena) [F11].
- I found no technical documentation of the PC Fútbol simulator beyond the programmers' names (Pedro Sudón, Pablo Ariza, Ricardo Puerto) and the fact that Carlos Abril wrote his own graphics libraries in assembly [F35][F39].

---

## 6. Lessons for a Quidditch manager

Intended for a **first release made by a very small team**. Ordered by priority within each block. This entire block is **[I]** (inference), supported by the confirmed facts cited.

### 6.1 Copy (high priority)

1. **Promanager-style career ladder** as the main mode. You start at a modest club, the board sets a **readable season objective** (avoid relegation / mid-table safety / promotion / title), and meeting it generates **offers** from better clubs; failure lowers your standing or gets you sacked [F41][F52]. It is the biggest "one more season" generator in both series (in CM, "taking a team from the bottom to the top" [F2]).
2. **Match viewing selector** from the start: result only / summary / key highlights / full match, with speed control [F19][F38]. The player regulates the pace of his own session.
3. **Inbox + Continue button** as the time structure [F5], but with **few things that block** progress.
4. **Hidden personality summed up in a readable label** ("Model Professional", "Temperamental") [F9]. Depth without spreadsheets.
5. **Hidden potential + reports with uncertainty** (CA/PA [F6]; filtered by scout quality as in OOTP [F60]). Discovering the young prospect is one of the most cited pleasures [F2].
6. **Engine with a simulation layer separate from rendering, deterministic with a seed** [F67][F68], with a **calibrated fast mode** for unwatched matches [F18].
7. **Match Plans / conditional instructions** [F17] (they did not exist in FM 07; they came later [R]). They fit perfectly with "during the match, only substitutions and tactics", and also serve the opposing AI.
8. **Emergent stories** (short press items, milestones, rivalries) as what really hooks players [F28]. A matchday newspaper like PC Fútbol 6.0's [F37] is cheap and effective.
9. **(FM 07) Visible progression with decimals and arrows.** Store attributes with decimals, display integers, and show the trend with green/red arrows whose **angle** indicates the magnitude; the straight arrow is a whole point gained or lost [F83]. This way the player sees the effect of training and age without needing a report. Before settling the visual detail, confirm with an FM 07 screenshot exactly what the arrows showed (see §2bis.3).
10. **(FM 07) Fixed "training category → attributes" table** with workload sliders (light/medium/intense) and coaches with limited capacity [F74][F75][F76]. It is readable, configurable as data, and creates real decisions: workload vs. injuries, pre-season vs. season.
11. **(FM 07) Hidden attributes revealed through phrases** in reports ("enjoys big matches", "injury-prone") [F81][F82]. Depth without showing numbers.
12. **(FM 07 + PC Fútbol) Mini-pitch with circles and arrows** as the tactics screen (base position plus an attacking-movement arrow), plus a few team and player instructions [F77][F84b][F57].
13. **(FM 07) Team talks at three moments** (before, half-time and full-time; general and individual), with visible player reactions [F69][F84], and **three prepared tactics** to switch between during the match [F80b]. It fits with "during the match, only substitutions and tactics".

### 6.2 Simplify

1. **Attributes**: from FM 07's ~47 visible + 13 hidden [§2bis.2] to a core of **4-8 per role**, with a **visible** effect in the 2D animation. PC Fútbol's simple average (4 attributes at 25% each) [F53] is too flat (everything was solved by stacking overall rating), but it shows that readability sells.
2. **Tactics**: a few levers with a clear effect (mentality in 3-5 levels, 2-3 team instructions, a role per player), instead of FM 07's 13 team sliders and dozen or so player instructions [F78][F79]. PC Fútbol's mini-pitch with range arrows [F57] is an excellent and cheap visual metaphor.
3. **Explicit tactical feedback.** The assistant says in natural language what's going wrong ("they're winning the midfield battle"), with simple per-sector stats in the Hattrick style [F59]. It tackles opacity, which is FM's central complaint [F17][F30].
4. **An economy with few relevant decisions**: tickets, wages, one stadium upgrade, one sponsor. Avoid sub-systems with no decision (PC Fútbol's catering, parking, merchandising [F55]).
5. **Training**: start from the FM 07 scheme (categories with workload) [F75], but with fewer categories, predefined schedules and the option to delegate; none of FM26's 105-click schedules [F20].
6. **A manageable database.** A world with hand-defined teams and players (like FM's researched database) is expensive to maintain. It's better to combine a hand-written database for the main clubs and figures with generated players for the rest, like Basketball GM [F65] or FM 07's youth system [F70]. PC Fútbol's value as an "encyclopedia" can be recreated with a league history (honors, records) that builds up over time.
7. **Delegation by default** of everything non-core (friendlies, youth contract renewals, press) and opt-in systems when creating the save, like the EuroManager options [F50].

### 6.3 Avoid

1. **Result and animation that don't match** (PC Fútbol 6.0 [F37]). What you see must be what happened.
2. **An "arcade"/playable match mode.** It was PC Fútbol's chronic weak point [F51] and is beyond the reach of a small team. It is already ruled out by the brief; it's best to keep it that way.
3. **Repetitive press conferences** [F29]. If there is press, it should be sporadic, tied to milestones, and have consequences.
4. **An exploitable market** (AI that pays anything, signing anyone without limit) [F37][F55]. A model of player value and willingness is needed from the first release, even if simple.
5. **Board expectations inconsistent with resources** [F25].
6. **Persistence bugs** (corrupted saves) and AI bugs that break the world in the long run (empty squads, eternal players) [F37]. Prioritize simulation tests of 10-20 seasons without intervention.
7. **Rewriting the interface and breaking habits** unnecessarily (FM26 [F12][F20]): less relevant for a first release, but it applies to updates.
8. **Crunch.** The PC Fútbol team worked "4-5 days non-stop" during the final pushes of 5.0 and 7.0 [F39]. It is a production warning.

### 6.4 Open questions for the design (not resolved by this research)

- How much randomness to tolerate. FM's quick match engine is "less random" [F18], and the FM26 community complains that the engine "is pure luck" [F30]. What variance should a Quidditch match have so that tactics matter and there are still upsets?
- Which engine archetype? Tick-based positional (free visualization, hard calibration) vs. events + scripted animation (easy calibration, expensive animation). See §5.1.
- A role selector (manager/chairman/both) as in PC Fútbol 5.0 [F35] and Football Chairman [F62]?

---

## 7. Sources

Numbered according to the citations in the text. "(snippet)" indicates that I could not read the full page and used the search engine excerpt.

1. Wikipedia, Football Manager (1982 video game), by Kevin Toms: https://en.wikipedia.org/wiki/Football_Manager_(1982_video_game) (snippet)
2. PCGamesN, The history of Championship Manager, part one: https://www.pcgamesn.com/championship-manager-series/championship-manager-football-manager-history-making-of
3. Wikipedia, Championship Manager (series): https://en.wikipedia.org/wiki/Championship_Manager (snippet)
4. Wikipedia, Championship Manager 4: https://en.wikipedia.org/wiki/Championship_Manager_4 (snippet)
5. SI Manual FM24, The User Interface (Continue/Inbox/Match Preparation): https://community.sports-interactive.com/sigames-manual/football-manager-2024/the-user-interface-r4951/ (snippet; 403 when reading)
6. Football Manager Wiki, Current Ability: https://footballmanager.fandom.com/wiki/Current_Ability (snippet; 402 when reading) and Football Gaming Zone, Hidden attributes FM26: https://footballgamingzone.com/football-manager/how-to-view-hidden-attributes-in-football-manager-26-explained/ (snippet)
7. Footy.com, FM21 Mobile vs Touch vs PC: https://www.footy.com/blog/culture/fm21-mobile-vs-touch-vs-pc/ and FMShot, FM Touch vs Mobile: https://www.fmshot.com/football-manager-touch-vs-mobile/ (snippets)
8. FootballGPT, FM Player Attributes Guide: https://footballgpt.co/fm/fm-attributes
9. FMScout / sortitoutsi, personality guides: https://www.fmscout.com/a-guide-to-player-personalities-football-manager.html , https://sortitoutsi.net/content/67996/fm24-guide-player-personalities (snippets)
10. FMNatics, FM26 Coach Reports Explained: https://fmnatics.com/article-coach-reports/1764390008913x870439155255892100 (snippet)
11. sortitoutsi, When do players peak in FM: https://sortitoutsi.net/content/67377/when-do-players-peak-in-football-manager-the-advise-from-si-is-a-lie ; Passion4FM, 11 reasons players won't develop: https://www.passion4fm.com/11-reasons-why-your-players-wont-develop-in-football-manager/ ; FM-Arena, Player Development and Training: https://fm-arena.com/thread/2671-player-development-and-training/ (snippets)
12. Wikipedia, Football Manager 26: https://en.wikipedia.org/wiki/Football_Manager_26 ; Goal, FM25 scrapped: https://www.goal.com/en-om/news/football-manager-2025-why-there-will-be-no-new-management-sim-game-this-year/blt599614fe05d508b7 ; SoccerGaming, From Cancelled to Playable: https://soccergaming.com/from-cancelled-to-playable-what-two-years-did-to-football-manager/ (snippets)
13. Scorpiolikeyou, FM26 Steam's 7th worst-rated: https://scorpiolikeyou.com/news/two-years-for-this-football-manager-26-lands-as-steams-7th-worst-rated-game-amid-bugs-clunky-ui-and-missing-features_a133 (snippet)
14. FM-Arena, Conditions management FM26: https://fm-arena.com/thread/16275-part-1-conditions-management-one-of-the-core-fm26-mechanics/ ; Higher Tempo Press: https://www.thehighertempopress.com/2026/07/how-football-manager-stats-mirror-real-life-sports-training-morale-fitness-and-peak-performance (snippets)
15. footballmanager.com, Match Engine AI in FM21: https://www.footballmanager.com/news/match-engine-ai-fm21
16. SI Community, "Does anyone actually know how the Match Engine works?": https://community.sports-interactive.com/forums/topic/301766-does-anyone-acyually-know-how-the-match-engine-works-under-the-hood-so-to-speak/ (snippet)
17. Guide to FM, Making Tactical Changes: https://www.guidetofm.com/match-day/tactical-changes/3/ ; footballmanager.com, FM2019 Match Engine Improvements: https://www.footballmanager.com/news/football-manager-2019-match-engine-improvements ; SI Community, "Does the ME over-react to tactical tweaks?": https://community.sports-interactive.com/forums/topic/575154-does-the-match-engine-over-react-to-tactical-tweaks/ (snippets)
18. SI Community, Speed to process other teams' matches: https://community.sports-interactive.com/forums/topic/550864-what-does-the-setting-speed-to-process-other-teams-matches-do/ ; VideoGamer, How to speed up FM: https://www.videogamer.com/features/how-to-speed-up-football-manager/ ; tweet by @WorkTheSpace: https://x.com/WorkTheSpace/status/1755937575775195156 (snippets)
19. SI Community, Highlight level threads: https://community.sports-interactive.com/forums/topic/593035-do-you-watch-the-entire-game-comprehensive-or-extended-highlights-or-key-moments/ ; GGRecon, change highlights FM24: https://www.ggrecon.com/guides/football-manager-2024-change-highlights/ (snippets)
20. FullerFM, My thoughts on Football Manager 26: https://fullerfm.com/2025/11/14/my-thoughts-on-football-manager-26/
21. FMScout, Mentality Analysis and the FM Tactics Creator: https://www.fmscout.com/a-mentality-analysis.html ; SI Manual FM24, Tactics: https://community.sports-interactive.com/sigames-manual/football-manager-2024/tactics-r4960/ (snippets; manual 403)
22. Stratpack, Why FM is the most addictive spreadsheet: https://stratpack.blog/2019/01/25/football-manager-addictive-spreadsheet/
23. Search snippet on FM contract negotiation (contract elements); SI Community, Player demanding a release clause: https://community.sports-interactive.com/forums/topic/560307-player-demanding-a-release-clause-what-are-my-options/
24. Passion4FM, Pre-season training guide: https://www.passion4fm.com/football-manager-pre-season-training-guide/
25. FMM Vibe, Board expectations unrealistic: https://fmmvibe.com/forums/topic/48839-do-you-find-board-expectations-totally-unrealistic/ ; SI bug tracker, Promise not recognised, got sacked: https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2024-early-access-bugs-tracker/club-vision-supporter-confidence-manager-staff-appointments/promise-not-recognised-got-sacked-as-a-result-r18187/ (snippets)
26. Gfinity, Miles Jacobson interview: https://www.gfinityesports.com/article/football-manager-miles-jacobson-interview ; PC Gamer, Miles Jacobson on FM's real world influence: https://www.pcgamer.com/miles-jacobson-on-football-managers-real-world-influence-huge-scouting-network-and-farting-players/ (snippets)
27. One More Game, FM26 interview with Miles Jacobson: https://onemoregame.ph/2025/10/football-manager-26-interview-milesjacobson/
28. Stratpack (see 22)
29. FMScout, Opinions on press conferences: https://www.fmscout.com/q-18007-Opinions-on-press-conferences-wanted.html ; Steam FM2017 discussion: https://steamcommunity.com/app/482730/discussions/0/135512931347683702 (snippets)
30. Steam, "FM26 match engine is pure random": https://steamcommunity.com/app/3551340/discussions/0/844005093415131352/ (snippet, title only)
31. pcfutbol.com, PC Fútbol 2.0 history (1993) and version table: https://www.pcfutbol.com/spain/historia/1993-pcfutbol-2?locale=es
32. Wikipedia, PC Fútbol: https://en.wikipedia.org/wiki/PC_F%C3%BAtbol
33. pcfutbol.com, PC Fútbol 4.0 (1995): https://www.pcfutbol.com/spain/historia/1995-pcfutbol-4?locale=es
34. pcfutbol.com, PC Fútbol 5.0 (1996): https://www.pcfutbol.com/spain/historia/1996-pcfutbol-5?locale=es
35. Wikipedia, PC Fútbol 5.0: https://en.wikipedia.org/wiki/PC_F%C3%BAtbol_5.0 (snippet)
36. Kódro Magazine, PC Fútbol 5.0: https://www.kodromagazine.com/pc-futbol-5-0/
37. El General Failure, PC Fútbol 6.0 review (Spanish): https://www.elgeneralfailure.com/2007/07/anlisis-pc-ftbol-60.html
38. Spanish Wikipedia, PC Fútbol 7.0: https://es.wikipedia.org/wiki/PC_F%C3%BAtbol_7.0
39. Xataka, PC Fútbol turns 25 (interview with its creators): https://www.xataka.com/entrevistas/pc-futbol-cumple-25-anos-sus-creadores-nos-cuentan-como-nacio-como-llego-a-ser-juego-espanol-vendido-que-ha-sido
40. pcfutbol.com, PC Fútbol 2001: https://www.pcfutbol.com/spain/historia/2001-pcfutbol-2001?locale=es
41. Vida Extra, PC Fútbol, the game that defined a decade: https://www.vidaextra.com/deportes/pc-futbol-el-juego-que-marco-una-decada-resucito-y-volvio-a-morir
42. PCFútbolManía, Patch 3.6: https://www.pcfutbolmania.com/thread-4766.html (snippet)
43. Vida Extra (see 41)
44. Kódro Magazine, PC Fútbol Argentina 4.0 Apertura 96: https://www.kodromagazine.com/pc-futbol-argentina-4-0-apertura-96/
45. Multimedia Plus (Substack), PC Fútbol 6 Argentina: https://multimediaplus.substack.com/p/pc-futbol-6-argentina
46. Vandal, Michael Robinson dies: https://vandal.elespanol.com/noticia/1350733863/fallece-michael-robinson-el-exfutbolista-y-presentador-que-puso-voz-a-los-pc-futbol/ (snippet)
47. Kódro Magazine, PC Fútbol Argentina Clausura 95: https://www.kodromagazine.com/pc-futbol-argentina-clausura-95/ ; Computer Emuzone, PC Fútbol Argentina series: https://computeremuzone.com/saga/pc-futbol-argentina (snippets)
48. Computer Emuzone, PC Fútbol 6 Apertura 98: https://computeremuzone.com/ficha/1201/pc-futbol-6-apertura-98 ; Internet Archive: https://archive.org/details/pc-futbol-6-apertura-98_202306 (snippets)
49. Xataka, I went back to playing PC Fútbol 5.0: https://www.xataka.com/videojuegos/he-vuelto-a-jugar-al-pc-futbol-5-0-anos-despues-nostalgia-adelantado-a-su-tiempo
50. PCFútbolManía, First time playing PCF 2001? In-depth tutorial: https://www.pcfutbolmania.com/Thread-Primera-vez-jugando-a-PCF-2001-Tutorial-a-fondo
51. Vandal, PC Fútbol 2001 review: https://vandal.elespanol.com/analisis/pc/pc-futbol-2001/433
52. PCFútbolManía, Promanager mode: it always offers me 2ªB teams: https://www.pcfutbolmania.com/Thread-Modo-Promanager-Siempre-me-ofrece-equipos-de-2%C2%AAB (snippet)
53. PCFútbolManía, Player energy: https://www.pcfutbolmania.com/thread-8319.html
54. PCFútbolManía search snippets on the 25% average and key attributes by position (threads: https://www.pcfutbolmania.com/thread-5026.html , https://www.pcfutbolmania.com/Thread-Editor-PC-F%C3%BAtbol-2001?pid=231834)
55. La Página Definitiva, PcFútbol: https://www.lapaginadefinitiva.com/2006/08/31/pcfutbol/
56. PCFútbolManía, Super training guide for PC Fútbol 2001: https://www.pcfutbolmania.com/Thread-La-super-guia-tutorial-de-entrenamientos-pc-futbol-2001
57. PCFútbolManía, tactics threads: https://www.pcfutbolmania.com/thread-5486.html , https://www.pcfutbolmania.com/thread-9663.html (snippets)
58. PCFútbolManía, Which is the best tactic: https://www.pcfutbolmania.com/Thread-La-mejor-tactica-cual-es
59. Hattrick Wiki, Match engine / Regular chances / Midfield: https://wiki.hattrick.org/wiki/Match_engine , https://wiki.hattrick.org/wiki/Regular_chances , https://wiki.hattrick.org/wiki/Midfield ; Hattrick devblog, Chance Distribution: https://devblog.hattrick.org/2016/02/and-on-the-seventh-day-bob-sunesson-created-the-chance-distribution/ (snippets; 403 when reading)
60. Baseball Prospectus, Staff Review OOTP 16: https://www.baseballprospectus.com/news/article/26292/staff-review-out-of-the-park-baseball-ootp-16/ ; OOTP Forums, 20-80 ratings: https://forums.ootpdevelopments.com/showthread.php?t=284505 (snippets)
61. RaceFans, Meeting the brains behind Motorsport Manager: https://www.racefans.net/2016/08/10/meeting-man-behind-motorsport-manager/
62. Gaming Matters, Football Chairman Pro Review: https://siboyle.wixsite.com/sismatters/single-post/2016/09/25/gaming-matters-football-chairman-pro-review (snippet)
63. Miketendo64, New Star Manager review: https://miketendo64.com/2019/04/11/switch-review-new-star-manager/ ; Interview with Simon Read: https://invisioncommunity.co.uk/interview-with-simon-read-creator-of-new-star-soccer/ (snippets)
64. Blood Bowl Leagues (UB): https://www.eng.buffalo.edu/~chz/bloodbowl/mp/league.shtml ; Alternate Blood Bowl League Rules: http://www.friedgold.co.uk/altbbligp.htm (snippets)
65. GitHub, ZenGM: https://github.com/sync0516/zengm ; GitHub, basketball-gm-simulation-game: https://github.com/willforman/basketball-gm-simulation-game (snippets)
66. GitHub, footballSimulationEngine: https://github.com/GallagherAiden/footballSimulationEngine (snippet)
67. GitHub, football-manager-simulation (deterministic TS engine separated from the UI): https://github.com/TheTrustLeader/football-manager-simulation (snippet)
68. GitHub, openfootmanager PR #704 (seed reproduces squads and fixtures): https://github.com/openfootmanager/openfootmanager/pull/704 ; Medium, Deterministic Match-3 engine: https://medium.com/my-games-company/divide-and-conquer-a-deterministic-and-scripted-match-3-engine-7b6e1ee16ec (snippets)

**Sources for the FM 07 section (§2bis)**

69. Wikipedia, Football Manager 2007: https://en.wikipedia.org/wiki/Football_Manager_2007
70. VideoGamer, Football Manager 2007 Fact Sheet: https://www.videogamer.com/previews/football-manager-2007-fact-sheet/
71. DarkZero, Football Manager 2007 PC Review: https://darkzero.co.uk/game-reviews/football-manager-2007-pc/
72. Wikipedia, Football Manager 2008: https://en.wikipedia.org/wiki/Football_Manager_2008
73. Football Manager 2010 (new features: shouts, tactics creator, live assistant analysis, Match Analysis, tabs): https://football.fandom.com/wiki/Football_Manager_2010 ; GameSpot review: https://www.gamespot.com/reviews/football-manager-2010-review/1900-6240556/ (snippets)
74. FMScout, FM2007 Beginner Level: Training: https://www.fmscout.com/a-fm2007_beginner_training.html
75. Blog "Football Manager by Yutthana", FM2007 (9 training categories and their attributes): http://fm2007-yutthana.blogspot.com/2009/12/football-manager-2007-return-play-style.html
76. FM 2008 VN, How to create your own training schedule (FM 08): http://fm2008vietnam.blogspot.com/2011/10/how-to-create-your-own-training.html
77. Football Manager 2008 FAQ (1-20 sliders starting at 10, with/without-ball arrows, training schedules folder, "7-star coaching"): https://realfootballmanager2008.blogspot.com/2008/06/football-manager-2008-faq-includes.html
78. FM Tactical Bible (team and player instructions, FM07-FM09 era): https://superam.wordpress.com/2009/01/19/fm-tactical-bible/
79. FMScout, How to make tactic (Guide): https://www.fmscout.com/q-172-How-to-make-tactic-Guide.html
79b. SI Community, "Where the attribute Creativity has gone?": https://community.sports-interactive.com/forums/topic/333805-where-the-attribute-quot-creativity-quot-has-gone/ ; FM-Base, Vision = Creativity?: http://www.fm-base.co.uk/forum/football-manager-2015-discussion/179249-vision-=-creativity.html (snippets)
80. FMScout, FM2007 Beginner Level: Match: https://www.fmscout.com/a-fm2007_beginner_match.html and General: https://www.fmscout.com/a-fm2007_beginner_general.html
80b. Search snippet from FMScout's FM2007 beginner guides ("set up 3 tactics…", tempo and passing related)
80c. FMScout, FM2007 Beginner Level: Team Talk: https://www.fmscout.com/a-fm2007_beginner_teamtalk.html
81. Passion4FM, Football Manager Guide to Hidden Attributes: https://www.passion4fm.com/football-manager-guide-to-hidden-attributes/
82. Search snippets on hidden attributes and attribute masking in FM 07/08 (SI Community: https://community.sports-interactive.com/forums/topic/88281-hidden-attributes-and-ability/ , https://community.sports-interactive.com/forums/topic/157434-hidden-attributes/ ; Neoseeker FM2007: https://www.neoseeker.com/forums/33098/t1196086-hidden-players/)
83. Search snippets on attribute change arrows (SI Community: "FM 2007 Training Help" https://community.sports-interactive.com/forums/topic/386236-fm-2007-training-help/ ; "training and the green arrows" https://community.sports-interactive.com/forums/topic/280253-training-and-the-green-arrows/ ; "Arrows on attribute change" https://community.sports-interactive.com/forums/topic/235638-arrows-on-attribute-change/). **I could not read them (403)**.
83b. FM-Base, How do you get attribute arrows? (FM 2011, "show attribute changes" checkbox): https://fm-base.co.uk/threads/how-do-you-get-attribute-arrows.58550/
83c. FM-Base, Training Schedule. What's with the red arrows? (FM 2011, arrows as response to training): https://fm-base.co.uk/threads/training-schedule-whats-with-the-red-arrows.61114/
84. Snippets from team talk guides (FMScout Q&A: https://www.fmscout.com/q-3050-Team-Talk-Help.html ; FM-Base: https://fm-base.co.uk/threads/teams-talks-what-to-say.84382/ , https://fm-base.co.uk/threads/woifsongs-teamtalk-guide.25988/)
84b. FMScout, Tactics (dragging icons, dotted forward-run arrow): https://www.fmscout.com/tactics.htm
85. Snippets from FM 07/08 forums on training schedules and downloaded tactics (Neoseeker FM2007: https://www.neoseeker.com/forums/33098/t2216514-fm2007-training-improving-players/ , https://www.neoseeker.com/forums/33098/t972611-downloaded-tactics-team-instructions/ ; FM-Base SK schedules: https://fm-base.co.uk/threads/sk-senior-youth-training-schedules-regular-injury-pre-season.48829/)
86. FM-Base, Question about player attributes (FM 2006, graphical or numerical attributes, colors in XML): https://fm-base.co.uk/threads/question-about-player-attributes.196/
87. Wikipedia, Football Manager 2006: https://en.wikipedia.org/wiki/Football_Manager_2006
88. FMScout, Player Attributes and Roles Explained (goalkeeper attribute definitions): https://www.fmscout.com/a-player-attributes-roles-and-duties-explained.html (snippet)
89. GameSpot, Football Manager 2007 Review (8.5): https://www.gamespot.com/reviews/football-manager-2007-review/1900-6160571/ (search engine excerpts; the page returns 403)
90. Vandal, Football Manager 2007 review (Xbox 360): https://vandal.elespanol.com/analisis/x360/football-manager-2007/5894
91. Mundogamers, Football Manager 2007 PC review (30-Oct-2006): https://www.mundogamers.com/analisis/football-manager-2007/1848
92. FM-Base, How do you view your matches (extended, full, only commentary)? (FM 2011): https://fm-base.co.uk/threads/how-do-you-view-your-matches-extended-full-only-commentary.64365/
93. Football Wiki (Fandom), Football Manager 2007 and series articles: https://football.fandom.com/wiki/Football_Manager_2007 (search engine excerpts; 402 when reading)
94. FMScout, Job Centre: https://www.fmscout.com/job_centre.htm (describes modern versions)
95. FMScout, FM 2009 New Features (press conferences for the first time, 3D engine): https://www.fmscout.com/a-fm09_3d_game_engine.html (excerpt)
96. Search engine excerpt on the FM 2007 interface (browser-style back/forward buttons, new GUI built with user input), attributable to Wikipedia FM 2007 (see 69)
97. VideoGamer, Football Manager 2007 Review (Xbox 360): https://www.videogamer.com/reviews/20070111003826-football-manager-2007-review/
