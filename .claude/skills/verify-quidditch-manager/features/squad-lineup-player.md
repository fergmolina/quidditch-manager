# Squad, lineup and player

The manager reads the squad as a table of attributes from 1 to 20 grouped by position, sets the seven who play and the
tactics on the lineup screen, and opens a player's profile with attributes, contract and actions.

## Sub-features

- `squad-table` the squad screen groups players by position (Keeper, Chaser, Beater, Seeker) with attribute columns and a side card for the selected player.
- `squad-views` the view buttons switch the columns (General, Flying, Technical, Mental, Physical, Contracts).
- `lineup-pitch` the lineup screen shows the seven starters on a pitch and the tactics options.
- `player-profile` the player screen shows the full attribute set, contract and value.
- `player-compare` two players side by side.

## How to get to it (user POV)

- Side menu: `Squad`, `Lineup & tactics`.
- Click a player's name in any table to open the profile. Right-click for actions. `Compare` from the profile.

## Driving it with qm-verify

Preconditions:

- A run with an empty HOME, `qm-verify doctor` passes.
- Each launch starts the reference career (`--autostart club_puddlemere_united`), so player ids are stable for seed 7.

- **Squad.** Run `qm-verify drive squad-lineup-player squad -- --lang en --autostart club_puddlemere_united --screen squad`. The screenshot shows `Squad`, `14 players`, four position groups and the card of the first keeper (Edwin Gammage for seed 7).
- **Lineup.** Run `qm-verify drive squad-lineup-player lineup -- --lang en --autostart club_puddlemere_united --screen lineup`. Seven starters on the pitch, the squad list beside it, the tactics toggle.
- **Player profile.** Pick a player id. Canon players are the files under `data/packs/1993-94/players/` (`player_<first>_<last>.json`, the id is the file name without `.json`, `grep -l '"club_puddlemere_united"' data/packs/1993-94/players/*.json` lists the club's). Generated players are `filler_<club>_<position>_<n>` (`src/world/filler_generator.gd`) and national-team fillers `player_nt_<country>_<name>`. Run `qm-verify drive squad-lineup-player player -- --lang en --autostart club_puddlemere_united --screen player --player <player_id>`. For `player_benjy_williams` the profile shows `Benjy Williams`, `Seeker`, 26 years old, value `503 G`, wage `13 G`, contract `Jun 1994`, the tabs Profile, Progress, History, Contract and Reports, the attribute groups with the position's key attributes marked, and the broom card. Value and wage match the squad table's row.
- **Compare.** Run `qm-verify drive squad-lineup-player compare -- --lang en --autostart club_puddlemere_united --screen compare --a player_benjy_williams --b player_gregory_cotton`. `Compare players` shows one column per player (club, position, age, value, wage, ability and potential stars, season stats, then every attribute group) and a difference column. For seed 7 Gregory Cotton is at Appleby Arrows.
- **Proof.** The screenshots and `.result` files. The player profile's contract and value must match the squad card's. Then `qm-verify cleanup`.

## Gotchas

- The squad screen's filter (All, First team, Reserves, Youth) and view buttons (General ... Contracts) are
  clicks. `--tab N` is ignored by the squad screen (only the player, calendar and encyclopedia screens read it).
  `squad-views` is proven only by the General view opening. The other views are not driveable.
- Player ids are generated per seed. A change in `WorldGenerator` or the data pack changes them. Take the id from
  the same seed you drive.
- Dragging a player onto a slot, right-click menus and the compare pick are mouse interactions, so they are not
  driveable. The lineup screenshot proves the screen and the assistant's lineup, not a manual change.
