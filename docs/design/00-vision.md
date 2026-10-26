# 00: Vision

## Pitch

**Quidditch Manager** is a sports management simulator in the style of *Football Manager 2007*, set in the world of Quidditch from the Harry Potter books. The player is a club's manager. They build the squad, train, sign players, deal with the board and choose the tactics. Matches are simulated by a custom engine and shown animated in top-down 2D; the manager picks the lineup before each match and, during the match, only adjusts tactics and calls time-outs, as the rules in the books allow. They never control a player.

It is a non-commercial **fan project** that uses the teams, players and names from the canon.

## Design pillars

1. **The spreadsheet is the game.** As in FM 07, the depth lies in the attributes, the reports and the management decisions, not in reflexes. All the information relevant to a decision has to be on screen, on a readable scale (1-20).
2. **Players are alive.** They have current and potential ability, improve with training, playing time and age, and decline afterwards. They get injured, get upset, become legends or wasted prospects. The manager sees that evolution (improvement/decline arrows, progress reports).
3. **The match is watched, not played.** The engine simulates deterministically and the 2D animation replays what happened. The manager intervenes from the sidelines only with what the canon allows: changing tactics (Seeker instructions, Beater instructions, Chaser formation) and calling time-outs. There are no player substitutions during a match. The lineup is set between matches. A match can be watched in full, as key moments, or as the result only.
4. **The rules are the books' rules, unadapted.** Positions, balls, scoring (the Snitch is worth 150 and ends the match), indefinite duration, fouls, named plays, brooms and teams come straight from the canon (the seven books, *Quidditch Through the Ages* and J.K. Rowling's writings). No rules are invented. Where the canon is silent (European Cup format, economy, leagues in other countries), the gap is filled with the minimal option most compatible with the lore and marked **[FILLER]**.
5. **A whole world.** Leagues on several continents, the European Cup, the World Cup with national teams every four years, and Hogwarts and other wizarding schools as academies that produce the youth players.
6. **No server dependency.** An installable desktop game for Windows and Mac, plus a browser build from the same code (`12-web-version.md`). Everything runs locally. Desktop saves are stored on disk, and browser saves stay in the player's browser or in save files they download and upload.

### Marker convention

The design and research docs tag content that does not come from the books:

- **[FILLER]**: invented content, not in the canon, used only where the canon is silent and the game needs an answer. Kept minimal and as close to the lore as possible.
- **[game]**: a gameplay rule or numeric effect chosen for the game (e.g. the exact bonus a named play gives), as opposed to something stated in the books.

Book citations use abbreviations such as [QTTA c7] (*Quidditch Through the Ages*, chapter 7) or [PoA 15] (*Prisoner of Azkaban*, chapter 15).

## Target audience

- People who have played hundreds of hours of Football Manager or PC Fútbol and want that same loop in another sport.
- Harry Potter fans who want a Quidditch game with the depth of a management sim, not an arcade game.
- PC/Mac players who are comfortable with a dense interface of text, tables and reports.

## What it is NOT

- It is not an action game, and you do not fly the broom with the keyboard.
- It is not an online game. The desktop builds need no account or connection, the browser build only downloads the game, and saves never leave the player's machine.
- It is not a commercial product. It is not sold or monetized.
- It does not reproduce the plot of the books. The player creates their own story in the world of Quidditch.

## Practical legal note (fan project)

This summarizes `docs/research/04-harry-potter-games-aesthetics.md` §7 and is not legal advice. Quidditch, the clubs, the characters and the trademarks belong to Warner Bros. / J.K. Rowling. To keep a low profile: free distribution, with no donations, Patreon or crowdfunding tied to the game; a visible "unofficial fan project, not affiliated" notice; art, crests, typefaces and icons that are 100% original or freely licensed (no WB logos, no MinaLima designs, no fan fonts imitating the logo, no actors' faces); and the canon names kept in data files separate from the code, so that if a complaint ever arrived the database could be changed without rewriting the game.

## References

- **Football Manager 2007.** Main reference for the player model, training, the top-down 2D engine, the tactics screen with arrows, the transfer market and the economy.
- **PC Fútbol (4.0 to 7 / 2001).** Reference for presentation, accessibility and lighter game modes.
- **The Harry Potter books and *Quidditch Through the Ages*.** The canon.
- Research details in `docs/research/`.
