# 09: Data model

> Describes the data as it actually ships (`data/`) and the runtime classes that hold it (`src/world/`). `data/README.md` has the field-by-field schemas with examples.

## 1. Principles

- All content lives in **JSON** under `data/`, editable without touching code. A data pack (1993-94 today; 1996-97, 2014-15… planned) is a folder under `data/packs/` with the same structure; what does not depend on the start year lives in `data/shared/`. Internal keys are English `snake_case`.
- Two layers:
  - **Authored data** loaded by `SimLoader` (`src/sim/sim_loader.gd`): every club and league, canon players, canon school students, national teams, book events. The 159 filler clubs are also authored files (`source: filler_authored`, produced once by `tools/author_clubs.py`), so every save has the same clubs.
  - **Procedural generation** at the start of a game (`WorldGenerator`, `src/world/world_generator.gd`): fills squads with filler players, creates staff, school students, national-team pools and fixtures. A competition can still ask for generated clubs with `filler_clubs > 0` (none does in the 1993-94 pack).
- Every record carries `source`: `canon_book`, `canon_qtta`, `canon_pottermore`, `canon_dp`, `canon_cards`, `prop` (film props, not used unless decided), `videogame` (not used unless decided), `inferred`, `filler`, `filler_authored`. Canon school students carry the book citation itself as `source` (e.g. `"PoA 15"`, `"OotP 19"`). Free-text `notes` explain what is canon and what is `[inferred]`/`[filler]`.
- UI text and news templates live in `locale/strings.csv` (10 languages). Data carries keys (`trait.*`, `award_*`) and proper names; a few files carry display names directly (`name_es`/`name_en` in `regions.json`, `name`/`name_en` in competitions and national teams). `shared/city_names.json` maps the Spanish names of club towns to their names in each of the other nine languages. Neutral venues are `venue.*` keys and broomstick tooltips are `broom.notes.<id>` keys.
- Determinism: the **initial world** (clubs, squads, students, national teams, calendar) always uses the fixed seed `WorldGenerator.WORLD_SEED` (19930801), so it is identical in every game. The **game seed** (`World.seed_value`) only drives what happens afterward: matches, weather, market, youth intake and new students.

## 2. Structure

```
data/
  README.md                  # field-by-field schemas
  packs/
    1993-94/
      clubs/                 # one file per club (194: 35 canon + 159 filler_authored)
      competitions/          # one file per league (20)
      players/               # canon club players, one per file (17)
      schools/               # one per school (11): house colors/info, venue, canon students
      national_teams.json    # 50 national teams: tier, mascot, colors, canon 1994 rosters
      events.json            # canon book events (toggle "Book events")
      world_cup_history.json # past canon World Cups (history) and future canon ones (for book events)
  shared/
    rules/
      match_rules.json       # sport rules (docs/design/04-match-rules.md)
      fouls.json             # the canon foul catalogue
      sim_params.json        # simulator calibration
    brooms.json              # 27 brooms
    regions.json             # 23 regions with their countries
    schools.json             # the 11 schools and their houses
    names/<region>.json      # name tables (23)
    grounds.json             # club grounds: landscape kinds per region, capacities [game/FILLER]
    climate.json             # weather per region [game/FILLER]
    city_names.json          # club town names in the other 9 languages
    crest_templates.json     # procedural crest shapes and emblem templates
    map.json                 # world/Europe map projections and league pins
    career_rules.json        # career limits the accounts server also enforces (shared with server/)
    season_report.schema.json # JSON Schema of the season summary the game sends to the ranking (shared with server/)
    generator/               # empty (distributions live in code, see §5)
```

## 3. Entities

### Region (`shared/regions.json`)

`id`, `name_es`, `name_en`, `school_id` (regional school), `names_file` (name table), `league_id` (absent when the region has no league, e.g. `middle_east`), `countries[]: {id, name_es, name_en, demonym_es, demonym_en}`. Every canon national team has its country in some region.

### Competition

Pack file (`packs/<pack>/competitions/comp_<league>.json`), leagues only:

```
id, name, name_en, type: "league", region_id, country_ids[], level (1 = elite … 3)
format: { rounds: 2, table: "points_scored", tiebreak: ["points_conceded_asc", "snitch_catches_desc"],
          time_cap_minutes: null, knockout: null }
calendar: { start_month, end_month, match_weekday_pool[], period_years: 1 }
club_ids[], filler_clubs, venues[]        # empty venues -> the British moors
prizes: { galleons_champion, galleons_per_position_step, awards[] }
founded, trophy                           # British league only
source, notes
```

Every other competition is created in code by `GameEngine` and lives only in the save (`src/world/competition.gd`, `type`): `cup` (European Cup), `national_cup`, `cont_groups`/`cont_knockout` (continental cups), `wc_groups`/`wc_knockout` (World Cup), `school_cup` (each school's house cup), `house_world` (House World Cup), `friendly`. Runtime fields add `season`, `fixtures[]`, `groups`, `champion_id`, `third_id`, `parent_id`, `bracket_done`.

A fixture is a dictionary inside its competition: `id, round, day, home_id, away_id, venue ("ground:<club_id>" for club matches; neutral venue for finals), hour, played`, plus the result once played.

### Club

Pack file (`packs/<pack>/clubs/<club_id>.json`):

```
id, name, short_name, city, country_id, region_id, founded
colors: { primary, secondary }, emblem_key, emblem_desc
identity: { style_tags[], motto, rivalries[], fan_traits[], mascot }
league_id, level (1-3), reputation (1-10000)
finances: { balance, wage_budget_weekly, transfer_budget }
facilities: { training (1-5), medical (1-5), broom_workshop (1-5) }
constraints: { women_only: true }     # Holyhead Harpies
manager_name
history: { league_titles, european_cups, notes_keys[] }
source, notes
```

Runtime (`src/world/club.gd`) adds: `manager_is_human`, `lineup {K, C[3], B[2], S}`, `tactics`, `tactic_sets[3]` + `active_set` (main / attacking / defensive), `familiarity` (per Chaser formation, 0-100), `board {objective, confidence, objective_min_pos}`, `sponsor`, `staff`, `scouts[]`, `knowledge` (region → 0-100), `scout_reports`, `ledger` (month → items), `fans {mood}`, `ground {kind, place, capacity}`, `season_summary`.

### Player

Pack file (`packs/<pack>/players/<player_id>.json`):

```
id, first_name, last_name, gender, nationality_ids[], birth_date, birth_date_estimated
main_position, positions: { K, C, B, S: 1-20 }
attributes: { flying: {7}, technical: {10}, mental: {14}, physical: {5} }   # 1-20, decimals allowed
hidden: { consistency, big_matches, injury_proneness, dirtiness, versatility,
          adaptability, ambition, controversy, loyalty, pressure, professionalism,
          sportsmanship, temperament }
ca, pa
club_id, squad: first | reserve | youth, is_captain
broom: { model_id, condition }
traits_text_keys[]          # canon traits, e.g. "trait.narcolepsy"
look {}                     # optional fixed portrait features (book descriptions)
source, notes
```

The attribute keys are listed in `data/README.md`. Runtime (`src/world/player.gd`) flattens `attributes` into `attrs`, keeps one `nationality` and a `birth_day` (day number) and derives CA from attributes (`ca()`). State and career fields: `condition`, `sharpness`, `morale`, `form[]` (last 5 ratings), `injury_days`/`injury_kind`/`injury_history`, `suspension_matches`, `ban_until`, `contract {wage_weekly, end_day, role}`, `pre_contract`, `loan`/`loan_listed`/`loan_option_fee`, `transfer_listed`, `sell_on`, `free_since`, `school_id`/`house` (while `squad == "school"`), `season_stats`/`comp_stats`, `awards`, `promise`, `happiness`, `training_focus`, `mentor_id`, `prev_attrs` (snapshot for the progress arrows).

### Staff

There is no staff file. Each club has `staff`: role → `{name, level 1-5, wage}` for the four roles in `Club.STAFF_ROLES` (`assistant`, `mediwizard`, `head_scout`, `broom_master`), created by `WorldGenerator.default_staff` with names from the region **[FILLER]**; plus `scouts[]: {name, region_id, quality}`. Unemployed staff available for hire are in `World.staff_pool`.

### Broom (`shared/brooms.json`)

`id, model, manufacturer, year, speed, acceleration, turning, braking, altitude, stability, durability, degradation_per_season, price (Galleons), available_from, available_to, scarcity (common | uncommon | rare | very_rare), source, notes`. Stats on a 1-20 scale. They are the table in `02-quidditch.md` §6.3 converted to numbers **[FILLER, calibrated to the canon hierarchy]**.

### School

- `shared/schools.json`: `id, name, short_name, country_id, region_ids[], houses[4], source, notes`.
- `packs/<pack>/schools/<school_id>.json`: `school_id, house_colors {house: {primary, secondary}}, house_info {house: {emblem_desc, inspiration, source}}` (invented houses), `venue`, `students[]`. Canon students (20 in 1993-94, Hogwarts) carry `id, first_name, last_name, gender, house, position, birth_date, talent, broom, nationality, source, notes, look`.

Students are `Player`s with `squad = "school"`, `school_id`, `house` and no club. `Schools` (`src/world/schools.gd`) fills each house to 9 students aged 13-17 and graduates them at 18 into the youth squad of a club in the region.

### National team (`packs/<pack>/national_teams.json`)

`id (nt_<country>), country_id, name, name_en, tier (elite | strong | mid | weak, see 07 §5.3), mascot, colors, world_cup_titles, canon_roster_1994[] {first_name, last_name, position, birth_date, birth_date_estimated, notes, look}, qualified_1994, source, notes`. Squads are called up from the players of that nationality; the generator also keeps a pool of generated players abroad for countries without a league (`refill_abroad_pool`).

### Book events (`packs/<pack>/events.json`)

Each event: `date, kind, …, source, notes`. Kinds: `fixture_result`, `wc_final`, `broom`, `graduate_to`, `no_school_cup`, `ban`, `retire`, `captain`, `cup_champion`. Applied only when `settings.book_events` is on; if the human manager runs one of the teams involved, the match is played for real.

### Referees

There is no referee entity. Refereeing is a set of simulator parameters (`sim_params.json` → `fouls.referee_sees_base`, etc.).

### World and save-state entities

`World` (`src/world/world.gd`) holds everything that is serialized: `pack`, `seed_value`, `today`, `season`, `player_club_id`, `manager {name, nationality, reputation, career}`, `clubs`, `players`, `competitions`, `national_teams`, `owls` (the inbox, `src/game/inbox.gd`), `news` (*Daily Prophet* editions), `history` (champions and tables per season), `transfers`, `pending_offers`, `pending_payments`, `awards`, `monthly_awards`, `records`, `shortlist`, `staff_pool`, `houses`, `settings {book_events, delegate_training, match_mode, match_view}`, `rng_state`.

## 4. Rules and simulator parameters (`shared/rules/`)

- `match_rules.json`: points per goal (10) and per Snitch (150), the Snitch ends the match, 5-second tick, no substitutions (injured or sent-off players are not replaced), long-match threshold (12 h), timeouts (max 5 min normally, 120 min in a long match), night pause (after 16 h, 8 h long), sleep relays in long matches, mutual end allowed, restart after a goal by the conceding Keeper, Keeper protected from Bludgers outside the area, stooging annuls the goal, Snitchnip and crowd hexes forfeit the match, `time_cap_minutes` (null; decided on goals if capped), replay of drawn knockout matches.
- `fouls.json`: the canon fouls (14 entries: QTTA's ten plus the book behaviors) with `id, who, sanction, source` and an example citation (`04-match-rules.md` §5).
- `sim_params.json`: groups `condition`, `consistency`, `quaffle`, `bludgers`, `fouls`, `snitch` (sighting curve, catch chance), `timeouts`, `mutual_end`, plus `hard_cap_hours` (48). This is the file tuned during calibration with `tools/sim_batch.gd` (`03-match-engine.md` §4).
- There is no `plays.json`. Named plays (Hawkshead, Porskoff, reverse pass, looping, Parkin's Pincer, Wronski Feint…) are tactic options in code (`src/sim/sim_tactics.gd`).

Changing the sport's rules is not intended through the UI. They live in data for architectural cleanliness, not as game options.

## 5. Procedural generator (`WorldGenerator.generate`)

Input: the loaded pack and shared data, plus the seeds described in §1.

1. **Leagues.** Loads the authored clubs and, for each league, builds the club list; if `filler_clubs > 0` it generates clubs (name = town from the region's name table + an unused noun from `club_nouns`, palette colors, founding year 1650-1950, reputation and budgets by level). It then builds the double round-robin fixtures, staggering weekdays between leagues.
2. **Canon players** from `players/` are placed in their clubs.
3. **Squads.** Each club is filled to 7 starters (1 K, 3 C, 2 B, 1 S), reserves per `RESERVE_PLAN` (1 K, 2 C, 1 B, 1 S) and 2 youngsters, using `FillerGenerator` (`src/world/filler_generator.gd`): target CA per club level (`CA_BY_LEVEL`: level 1 = 125-150 … level 4 = 70-95), key attributes per position, brooms per level, no duplicate names within a club, women only for the Harpies. Then the board objective by level, default lineup, sponsor, manager name (if none) and full knowledge of the club's own region.
4. **National teams** and their pools; the **1994 World Cup** group stage already halfway through (1992-94).
5. **Schools** (`Schools.setup`): canon students plus filler students up to 9 per house.
6. Default **staff** for every club; past canon World Cups added to history and to national-team titles.

Each season the engine produces the new youth intake and school students (FM 07 "regens": few make it) and replaces retirements in AI clubs.

## 6. Names (`shared/names/<region>.json`)

Two formats. **Version 1** (`british_isles.json`, `argentina.json`): top-level `first_names_m`, `first_names_f`, `last_names`, `club_nouns`, `cities`. **Version 2**: `region_id`, `club_nouns`, `club_nouns_lang`, and `by_country {country_id: {first_names_m, first_names_f, last_names, cities, [last_names_f]}}`. The loader uses `by_country[country_id]` if present, otherwise the top-level lists (`SimLoader.names_for`).

British and Irish names follow JKR's humor (occupation, place or sound surnames: Gudgeon, Wadcock, Plumpton, Fenwick); the other tables cover French, German, Slavic, Nordic, Iberian, North American, Brazilian/Andean, African (several languages), Japanese, Oceanian names and more. Names of well-known real people are never used. Canon names are reserved and the generator cannot produce them.

## 7. Saves (`src/game/save_manager.gd`)

- `user://saves/<name>/world.json.gz` (full `World.to_dict()`, gzip) + `meta.json` (`name`, `schema`, `pack`, `today`, `season`, `club_id`, `club_name`, `manager`, `saved_at`, `saved_unix`, `save_id`, `career_id`). The slot is per career (`career_id`; `GameSession.manual_slot`), so two careers never share one. Floats are snapped on save and again on load (`World.normalize_floats`), so a loaded game simulates exactly as the running one would have.
- Schema version: `World.SCHEMA_VERSION` (currently 6). `SaveManager` refuses a save or an imported file of any other schema. There is no migration path. A new field with a default in `from_dict` needs no bump. A renamed, removed or reinterpreted field bumps the version, and old saves stop loading.
- The last human match is kept in memory only (`GameEngine.last_match`) for the post-match screen and press conference; there is no replay file.

## 8. Validation and tools

- `tools/sim_batch.gd`: mass simulation to calibrate `sim_params.json`.
- `tools/sim_world.gd`: N seasons with no human input, with a report on world health (champions, ages, inflation, broken squads); `--save-test` round-trips a save.
- `tools/stress_test.gd`: N seasons with per-season invariants and behavior metrics.
- `tools/audit_world.gd`: semantic audit (impossible stats, tables that don't add up, injured players in lineups, expired contracts, untranslated text, results outside the lore).
- `tools/life_audit.gd`: audit of off-pitch life (transfers, loans, regens, retirements, contracts, progression, press, news, inbox, awards) and of the texts used in all 10 languages.
- `tools/author_clubs.py`: produces the hand-designed `filler_authored` clubs.
- `tools/merge_translations.py`, `tools/check_translation.py`: maintenance of `locale/strings.csv`.
- No standalone data-schema validator or filler inventory script exists yet; listing `filler`/`inferred` records for review is done by searching the `source` and `notes` fields.
