# Start a career

A new player sees the title screen, chooses a club (or a Hogwarts house, or no club) on the New game screen, names
their manager and starts in August 1993 with welcome owls in the inbox and a Continue button that advances time.

## Sub-features

- `career-title` the title screen opens with New game, Load and (when a save exists) Continue.
- `career-new-game` the New game screen lists clubs by league with a preview of the chosen club.
- `career-start-club` a career with a club starts on 1 August 1993 with the board's welcome owl and tutorial owls.
- `career-start-house` a career as a Hogwarts house coach hides market, finances and board in the side menu.
- `career-start-unemployed` a career without a club starts with job offers (not driveable, see Gotchas).

## How to get to it (user POV)

- Launch the game: the title screen.
- Choose `New game`, pick a club in the list or on the map, type a name, choose `Start`.
- On the New game screen, choose a school house instead of a club.

## Driving it with qm-verify

Preconditions:

- A run with an empty HOME (`qm-verify start`), `qm-verify doctor` passes.
- No save exists in the run (nothing has been saved yet).

- **Title screen.** Launch with no game. Run `qm-verify drive start-a-career title -- --lang en --screen title`. The screenshot shows the title with New game and Load buttons and no Continue entry (no save yet).
- **New game screen.** Open the club picker. Run `qm-verify drive start-a-career new-game -- --lang en --screen new_game`. The screenshot shows the league list with clubs and the preview panel.
- **Start with a club.** Start the reference career and land on the inbox. Run `qm-verify drive start-a-career inbox -- --lang en --autostart club_puddlemere_united --screen inbox`. The top bar reads `Puddlemere United`, `Sun 1 August 1993` and `15,000 G`. The inbox lists the board's welcome owl and five tutorial owls (Inbox (6) in the menu).
- **Start as a house coach.** Run `qm-verify drive start-a-career house -- --lang en --autostart hs_hogwarts_gryffindor --screen inbox`. The top bar reads `Gryffindor` in the house's red. The side menu has a `Schools` group and no Transfers, Scouting, Finances, Staff, Board, My career or Club entries. The inbox holds the Head of House's welcome and five tips. The next match is against Hufflepuff.
- **Proof.** The three screenshots plus their `.result` files. The inbox screenshot's date and balance are the starting state every other feature builds on. Then `qm-verify cleanup`.

## Gotchas

- `--autostart` calls `Game.new_game` directly with manager name "Manager" and seed 7: it stands in for typing a
  name and pressing Start on the New game screen. The New game form itself (typing, the map, the Start button) is
  not driveable from the command line. The `new-game` screenshot only proves the screen opens and lists clubs.
- A career without a club (`Game.new_game("")`) has no flag: `career-start-unemployed` is unreachable here.
- House ids are `hs_<school>_<house>`. Check `data/` if `hs_hogwarts_gryffindor` is renamed.
- A fresh HOME starts in Spanish. `--lang en` is required for English evidence and is not saved.
