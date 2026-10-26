# Quidditch Manager: documentation

Non-commercial fan project. The project rule is maximum fidelity to the books and the lore. No rules are invented, and
anything invented is marked **[FILLER]** (and pure game mechanics **[game]**).

## Design (`docs/design/`)

| File | Contents |
|---|---|
| `00-vision.md` | Pitch, pillars, audience, legal note |
| `01-platforms-and-stack.md` | Godot 4, project structure, data, saves, localisation, Windows/Mac export |
| `02-game-loop.md` | Day / week / season; game modes; screens; what's deliberately left out |
| `03-match-engine.md` | Deterministic headless simulator; time; the Snitch; interventions; event log; viewer; tests |
| `04-match-rules.md` | Canon match rules, fouls and penalties, per-competition rules |
| `05-player-model.md` | 1-20 attributes (FM 07 → Quidditch), hidden attributes, CA/PA, condition, brooms, progression and decline |
| `06-tactics.md` | Mini-pitch, sliders, canon formations, per-position instructions, team talks, feedback |
| `07-competitions-and-world.md` | 1993-94 timeline, British league, European Cup, World Cup, world leagues, schools, the wider world |
| `08-transfers-training-economy.md` | Training, squad, scouts, transfer market, finances, board, fans |
| `09-data-model.md` | JSON, data packs, entities, procedural generator + canon layer, saves |
| `10-screens-and-ui.md` | Visual system, common frame and wireframes for each screen |
| `11-scope-and-roadmap.md` | Milestones 0-4, out of scope, risks, and the development log |
| `12-web-version.md` | Plan for the browser build: same codebase, static files on a Hetzner VPS, saves downloaded and uploaded by the player |

## Research (`docs/research/`)

| File | Contents |
|---|---|
| `01-football-manager-and-pc-futbol.md` | The reference series; §2bis covers Football Manager 2007 in detail (the main reference) |
| `02-quidditch.md` | All Quidditch canon: rules, fouls, plays, brooms, teams, competitions, players, history, balance |
| `03-key-findings.md` | Cross-analysis of both: author decisions (A4), design decisions (B) and filler inventory (C) |
| `04-harry-potter-games-aesthetics.md` | Art direction: every HP game, visual patterns, the "manager's office" proposal, legal |
| `05-ui-ux-managers.md` | UI/UX of management games, a design system for Godot and prioritised UI changes |
| `06-fm2007-missing-features.md` | Football Manager 2007 features the game was missing, inventoried by area and prioritised |
| `07-quidditch-game-reviews.md` | Reviews of existing Quidditch video games: what worked, what didn't, and prioritised recommendations |

## Art pipeline (`docs/art/`)

How the AI-generated artwork was made. Source sheets live in a local work folder outside the repository and are not published.

| File | Contents |
|---|---|
| `crests/prompts.md` | How to generate and import club and house crests (4 per sheet) |
| `crests/batches.json` | Which club/house goes in each position of each crest sheet |
| `portraits/prompts.md` | How to generate and import club and house characters (2 per sheet) |
| `portraits/batches.json` | Which club/house goes on each portrait sheet |
| `brooms/prompts.md` | How to generate and import the 27 brooms (3 per sheet) |
| `brooms/batches.json` | Which broom goes in each row of each broom sheet |

## Calibration (`docs/calibration/`)

| File | Contents |
|---|---|
| `example_puddlemere_harpies.txt` | Sample event log of a simulated Puddlemere United vs Holyhead Harpies match |

To run the simulator, see the root `README.md`.

To list everything invented: `grep -rn "FILLER" docs/design/`.
