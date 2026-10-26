# 05: UI/UX of management games and a design system for Quidditch Manager

> Interface research. It starts from an unsparing critique of the six current screenshots (`docs/screenshots/`), looks at how the best management games (sports and non-sports) solve their interfaces, and ends with a **concrete design system, implementable in Godot 4.7 with `Control` nodes and `StyleBoxFlat`, with no hand-painted textures**, plus a prioritized list of changes to make in one session.

## Evidence conventions

The same as in `01` and `04`:

- **[F]** = confirmed in a source consulted in this session (URL alongside).
- **[R]** = my own recollection, not verified in this session.
- **[I]** = my own inference, judgment, or proposal.
- **[C]** = verified by calculation in this session (WCAG 2 contrasts, measurements on the code or the screenshots).

The screenshots are from October 2, 2026, 22:44. Some files in `src/ui/screens/` were modified afterward (e.g., `new_game_screen.gd` already formats the founding year as an integer and has a language selector), so a couple of the defects in the critique may already be fixed in the code; they are flagged anyway because they are what you see.

---

## Contents

1. Critique of the six screenshots
2. Lessons from the games researched
3. Design system for Godot
4. Do first: prioritized changes for one session
5. Art direction: what to keep and what to throw out
6. Sources

---

## 1. Critique of the six screenshots

### 1.0 Cross-cutting problems (affecting every screen)

Before going screen by screen, the defects that repeat. They are the main reason it "looks horrible". It is not a problem of ornament, it is one of **structure**.

1. **There is no figure and ground.** The content area is `PARCHMENT #EFE4C8` and the panels (`UI.panel()`) are `#F4EBD6`, **a contrast of 1.07:1** between box and background [C]. The only separation is a 1 px bronze rule. The result is "boxes inside boxes" of the same color, with brown borders everywhere: wooden frame → bronze border of the paper → rule under the title → panel border → Tree/ItemList border → border of each column header. In the squad screen there are **six levels of lines** between the edge of the window and a number.
2. **The attribute colors convey nothing.** The three text tones for the levels (`BRONZE_DARK #6E4E1E`, `GREEN #2F5A2A`, `INK_SOFT #5C4A36`) have contrasts of **1.05 to 1.11:1** against each other [C]. To the naked eye they are the same dark brown. Only the sealing-wax red (1-5) stands out. Also, §6.4 of `04` asks for bold for 16-20, and `attr_color()` only changes the color. The most important information channel in a management game is switched off.
3. **A type scale with no system.** The code mixes 11, 12, 13, 14, 15, 16, 18, 20, 22, 26, and 40 px with six families/weights, chosen screen by screen. Important data labels at 12-13 px (player profile, condition in the match) and panel titles in IM Fell SC at 18 px in bronze. Letterpress small caps at that size read as texture, not as words. The prose (Alegreya serif 16) is **larger** than the data (Alegreya Sans 13-14), the opposite of what a manager needs.
4. **Dead space instead of density.** Every screen leaves between 120 and 260 px empty at the bottom (squad: ~250 px of empty Tree; lineup: ~120 px below the panels; player profile: ~125 px; new game: the entire 190 px side column empty). Meanwhile the player profile **runs off the screen** on the right. The layout does not adapt to the viewport: fixed minimum widths and badly distributed `EXPAND_FILL`.
5. **The top bar changes material.** With a club selected, the bar switches from wood to navy blue (`pc.darkened(0.35)`) with a 2 px gold border, a saturated blue rectangle on a brown frame. The idea (FM 07: bar tinted with the club color) is good; the execution tints the **whole** bar and clashes with everything else.
6. **Flat, poorly afforded navigation.** Sixteen identical items in a list with 1 px underlines (they look like notebook lines, not buttons); the selected one is a brass box narrower than the row; no icons, no grouping (the design, `10` §2, asks for a tree Club ▸ / Market ▸ / Competitions ▸), no visible hover. The back/forward buttons are two 22 px squares with 8 px ◂ ▸ glyphs.
7. **"Continue" is well placed but does not stand out enough**, and the bottom bar lies: it shows "Next match: vs Falmouth" while you are watching the end of that very match, and the button says "Go to match ▸" when it is already over. "Save" appears on the new game screen, where there is nothing to save.
8. **Glyphs instead of graphics.** Stars ★☆, broom segments ▮▯, form ●◐○, arrows ▲↗. They depend on the font having the glyph (the last broom segment on the player profile shows up as a missing-glyph box) and they neither align nor scale. Godot draws bars and rectangles for free.
9. **Border noise on controls.** Every `OptionButton` is a parchment rectangle with a bronze border, the same as the buttons; the lineup screen has **14 identical dropdowns** that look like 14 buttons. You cannot tell what is an action (button), what is an editable value (input), and what is data.
10. **Scaling is turned off.** `project.godot` has `window/stretch/mode="disabled"`. On a 1080p or 1440p monitor everything ends up small and the empty space grows; there is no text-size option.

### 1.1 New game (`nueva_partida.png`)

In order of severity:

1. **Mixed language.** Titles and buttons in English ("Choose your club", "Sign the contract", "Load game") and data in Spanish ("Inglaterra", "Irlanda del Norte", "río Piddle"). The game's first screen looks broken. (Later code already adds a language selector; what is missing is for the default language to be the one from `locale/fallback="es"` and not the operating system's.)
2. **Floating-point numbers on display**: "Founded 1163.0", "League titles: 22.0", "Level: 1.0". This is what screams "prototype" the loudest. (Fixed in later code with `int()`.)
3. **The saved game reads "— 1994-07-01 ()"**, with no club or manager and empty parentheses. You cannot tell what is being loaded.
4. **The wooden side column, empty.** 190 px × 710 px of nothing in the first impression.
5. **Choosing the club, which is the emotional decision of the game, is a 15 px text list** with no colors or crest, with the town repeated on the same line, and it leaves 300 px empty below. The profile of the chosen club is a paragraph in a small panel: no colors, no motto, no board expectations, no budget, no standout players with a readable position.
6. **Inverted hierarchy.** The actual title of the screen ("A Quidditch manager true to the books") is in 18 px bronze small caps tucked into the top right; the h1 on the left does not exist (the header is drawn empty) and the top bar repeats "Quidditch Manager".
7. **The sealing-wax "Sign the contract" button is in the middle of the form**, before you see the club profile; the primary action should close the flow (bottom right) after choosing.
8. "World seed" is a technical concept in the foreground; it belongs in "Advanced options".

### 1.2 Squad (`plantilla.png`)

1. **The attribute colors cannot be read** (see 1.0.2): 16 (bronze), 13 (green), and 9 (soft ink) look the same. It is the most used screen in the game and its main channel does not work.
2. **Columns that convey nothing.** "Cond." 100% in all 14 rows, "Morale" Normal in all 14, "Form" empty in all 14, column 0 (★/▸ marker) empty but with a header. Four columns, ~250 px, without a single bit of information. When all values are equal, the column should collapse to an icon or show "—".
3. **No sorting by column.** The headers look like buttons (they have a button border and background) but they do not sort, a false affordance. No `column_title_clicked` is connected.
4. **No zebra striping, and nearly invisible separators** (`guide_color #D4C5A3` on `#EFE4C8`: 1.35:1 [C]). In a 25-column table the eye loses the row when crossing from "Name" to "Value". The selected row (`#DCCB9E`) has 1.27:1 against the background [C], so it is barely visible.
5. **Truncated, hard-to-read header.** "Eda" ("Edad"/Age cut off at 46 px), three-letter attribute abbreviations without tooltips, bold headers the same size as the body with borders on every cell.
6. **Grouping by position without separators.** The 2 Keepers, 7 Chasers, 3 Beaters, and 2 Seekers run together; FM and OOTP separate them or allow grouping.
7. **250 px empty below the table** and no context panel (the selected player could be shown in a side panel with his summary, like FM's "player preview").
8. Number alignment: centered attributes are fine; "Wage" without a unit ("24"); "Value" with the "G" stuck to it; "Broom" takes 110 px of repeated text ("Nimbus 1700") that could be an icon + number.
9. "Let the assistant pick the team" on the squad screen is an action for the lineup screen.

### 1.3 Lineup and tactics (`alineacion.png`)

1. **There is no pitch.** The design (`10` §3.4) asks for a diagram of the pitch with the seven; the implementation is seven dropdowns with "Name · 100%". You cannot see who is where, nor their key attributes, nor their condition in a graphic, nor the bench. It is the screen that should feel most like a "game" and it is a form.
2. **Fourteen identical controls.** Seven player dropdowns and seven instruction dropdowns with the same button style; the sliders have 11 px end labels ("defensive" / "attacking") in soft ink and a white knob that does not belong to the palette. Neither the numerical value nor the name of the current setting ("Balanced") is shown.
3. **Choosing a player in an `OptionButton`** forces you to open a menu, read names without attributes, and choose blind. FM solves this with a squad list + dragging onto the pitch.
4. **The assistant speaks at the bottom in an isolated one-line box**; its comment ("he will catch the Snitch even if we are losing by more than 150") is a **tactical alert** and should look like one (icon, color) next to the control that produces it ("Seeker: catch").
5. "Lineup valid" in 13 px green under the button. The validity status is top-level information (FM puts it in the screen bar).
6. ~120 px empty at the bottom, and the left column ends halfway down.

### 1.4 Text match (`partido_texto.png`)

It is the best of the six (it has a large scoreboard, a commentary feed with a clock, live tactics), but:

1. **Inconsistent frame state.** The top bar says "Go to match ▸" and the bottom one "Next match: vs Falmouth Falcons" while you are watching the end of that match.
2. **The commentary has no consistent hierarchy.** Goals in bold green sans, the Snitch in bold bronze, fouls in regular sealing-wax serif, the Seeker joining in bronze serif, the rest in black serif. Four styles without a legend and a mix of families (sans/serif) within the same list. The decisive moments (goal, Snitch, penalty) have no visual marker (an icon or a color bar on the left), and the final line of the match is at 13 px.
3. **The scoreboard does not show what matters in Quidditch**: the points difference, the Snitch status (not sighted / sighted / being chased), and the clock are left on a small line underneath ("50m 45s Snitch sighted!"), when they should be in the scoreboard strip.
4. **Condition without a number.** 90 px green bars with no figure or threshold (at what point should you worry?); names at 12 px with the position stuck to them ("K Evelyn Fettle").
5. **Statistics in a paragraph** ("Shots: 41 / 13") in the prose serif font. They should be a two-column table with a comparison bar (in the style of the FM/F1 Manager match summary).
6. The team colors only appear in two 4 px rules next to the names.
7. The "Finish and return to the office" button sits inside the commentary, at the end of the scroll; the exit action belongs in the scoreboard strip or in Continue.

### 1.5 Player profile (`ficha_jugador.png`)

1. **The screen runs off the right edge.** The Status/Contract/Actions panel and the header subtitle ("Puddlemere Un…") are cut off. Cause [C]: four attribute columns with `custom_minimum_size` 150 px + 18 px separation + margins ≈ 678 px, plus the 240 card and the 250 side panel with separations of 14, which gives **≈ 1,196 px minimum in a usable area of ≈ 1,146 px** (`player_screen.gd:94-96`, `:30-43`). It is the most serious defect in the six screenshots.
2. **Attributes at 13 px with long labels** ("Natural fitness") in narrow columns, indistinguishable colors (1.0.2), and the Physical column almost empty while Mental reaches the bottom. Four columns with heights of 7/9/14/5 leave a big gap in the central panel.
3. **Irrelevant attributes are not dimmed.** For a Seeker, Passing/Shooting/Batting 6 have the same visual weight as Snitch catching 16. FM highlights the key attributes for the position.
4. **The card is flat.** A blue circle with initials, the broom in ▮▯ glyphs with a broken glyph, stars ★☆, and underneath 11-12 px text ("Canon player" in bronze: 4.5:1 at 11 px [C], borderline).
5. **The actions are four identical stacked buttons** plus a sealing-wax one with radius 12 (yet another button style). Tooltips explaining the consequence are missing ("Renew contract (+15%)" does not say for how many years or what happens if he refuses). The result of the action appears in a 12 px italic label at the end of the panel, invisible feedback.
6. "Form: (6.0)" with parentheses and without points; "This season" on a line that gets cut off; "Until: 1995-06-30" in ISO instead of "30 Jun 1995".
7. ~125 px empty at the bottom; there are no tabs (Profile / Progress / History / Contract / Reports, as `10` §3.3 asks for).

### 1.6 The Daily Prophet (`el_profeta.png`)

1. **It is not a newspaper, it is a list.** A single 900 px column with eight identical blocks of "headline in bold sans 13 px + sentence". `04` §6.10 asks for three columns, a large headline, a standfirst, a drop cap; the blackletter masthead is the only thing that says "newspaper".
2. **Lines of 110-120 characters** in 16 px serif at full width, too long to read (comfortable is 60-75).
3. **Everything weighs the same.** Your own result (Puddlemere 160-180) is in the same place and size as the rest; the league table is a sentence ("Top: Appleby Arrows (320)…") when it should be a small "points only" table.
4. **Repetitive generated text** ("In X, after N min of play, Y caught the Snitch" ×6). It is content, not UI, but the layout makes it more obvious by stacking it.
5. The list of editions is a 200 px column with ISO dates and 70% empty; it could be a horizontal strip of numbers at the top or a dropdown.
6. The newspaper paper (`#E9E2CF`) on the parchment of the area (`#EFE4C8`) is barely distinguishable, figure/ground again.

---

## 2. Lessons from the games researched

Web research from October 2, 2026. **[F]** = the source states it explicitly; **[I]** = my own inference (from screenshots or judgment); "(snippet)" = the page blocked reading and the data point comes from the search-result text. No source publishes row heights or font sizes in pixels for these games. The numbers in §3 are mine.

### 2.1 Football Manager 2024 (and FM19-FM24 conventions)

1. **Saved views per table.** The same player list is viewed with different sets of columns ("Views"), because not all attributes fit; "Customize current view" lets you reorder and resize columns [F], https://community.sports-interactive.com/sigames-manual/football-manager-2024/the-user-interface-r4951/ (snippet). → Our General/Flying/Technical/Mental/Physical views are already along those lines; what is missing is the Contracts view and remembering the last one used.
2. **Scaling with a single control.** "Size of Text & Images" from 85 to 125% [F], https://steamcommunity.com/app/2252570/discussions/0/3879347492851596080/ (snippet).
3. **An always-present sidebar** with icon + text at large resolutions and icon only at small ones, reorderable [F], https://coffeehousefm.com/fmrensieblog/2021/11/15/the-game-of-shortcuts
4. **Attribute color is relative and configurable.** The user sets the green/yellow thresholds on the 1-20 scale (16/14 at a big club, 14/12 at a small one) and the chosen role highlights key attributes (green) and preferable ones (blue) [F], https://x.com/FM_Stag/status/1721107345114063325 ; https://community.sports-interactive.com/forums/topic/586813-which-highlighted-attributes-are-key-and-which-are-important-green-or-blue/ (snippet). → Heat-map thresholds as a preference; mark the key attributes for the position (§3.12 player profile).
5. **Conditional Continue.** A message that requires a response has a red accent and "Must Respond" replaces the Continue button; Space = Continue [F], https://community.sports-interactive.com/sigames-manual/football-manager-2024/inbox-and-news-r4956/ (snippet).
6. **Row status by text color** (dark red = shortlisted, muted blue = on loan) and **three-letter badges** (Inj/Sus/Int/...) in a single narrow column [F], https://www.fmscout.com/a-fm19-gui-hints-and-tips.html
7. **A tooltip on every column header**, Shift+click resets the sort, right-click context menu, attributes optionally as bars; F2-F11 jump to the main screens [F], same URL.

### 2.2 Football Manager 26: what worked and what didn't

- **What changed.** The Portal replaces the inbox; screens are built from *tiles* (summaries) that open *cards* (detail); declared principles "Efficiency, Familiarity, Predictability" and the promise to "fix illegible font sizes and define contrasts" [F], https://www.footballmanager.com/fm26/features/fm26s-reimagined-user-interface . The sidebar was replaced by a top bar with 6 categories + bookmarks, to gain width for tables [F], https://www.fmscout.com/a-fm26-reimagined-ui.html
- **Worked.** Separate tactical boards in and out of possession; unified search (players, screens, glossary) and bookmarks [F], https://www.operationsports.com/its-still-not-perfect-but-ive-learned-to-love-fm26/ ; https://fullerfm.com/2025/11/14/my-thoughts-on-football-manager-26/
- **Didn't work, density.** Of negative Steam reviews, 34% mention the interface (43.8% of those in English); complaints drop from 45.6% (< 10 h) to 31.7% (200+ h). People got used to it, the problems stayed [F], https://www.fmscout.com/a-fm26-reviews-what-went-wrong.html . "A bigger monitor doesn't show more: the same tiles in the same places" [F], same URL.
- **Didn't work, scaling.** Font size with no intermediate step (small at 1080p, huge at 4K); panels, row heights, and margins do not shrink with the text [F], https://www.fmscout.com/q-34023-FM26-text-bigger.html (snippet). Text cut off with "…" and numbers "squashed out of the box" [F], https://fullerfm.com/2025/11/14/my-thoughts-on-football-manager-26/
- **Didn't work, slow feedback.** Dragging from the bench to the XI took 3-4 s and tactical changes 1-2 s; patch 26.0.4 added a transition-speed setting [F], https://ingenuityfantasy.com/feature-articles/how-to-make-fm26-feel-like-fm24-best-mods-and-settings/ . More than 100 clicks for one week of training [F], https://www.galaxus.at/en/page/football-manager-26-is-floundering-in-an-interface-labyrinth-40507
- **What had to be brought back by patch.** Dropdown menus in the bar, reorderable columns (26.1.2), sorting by value/ability/potential and remembered filters (26.3), attribute colors stable while scrolling [F], https://www.operationsports.com/fm26-update-26-3-focuses-on-youth-development-ui-fixes-and-database-changes/ ; https://www.operationsports.com/fm-26-26-1-2-patch-brings-navigation-enhancements-and-stability-fixes/ . Miles Jacobson (May 12, 2026) admitted that unifying PC, console, and mobile was "detrimental" [F], https://www.fmscout.com/a-miles-admits-fm26-missed-the-mark.html
- **FM27 (announced).** Tiles that are "primarily informational," three density modes (Default / Detailed / Condensed), ultrawide support, remappable shortcuts [F], https://simulationdaily.com/news/football-manager-27-expanded-ui/
- **Lesson for us [I].** Design for desktop and mouse with no concessions to console; density is a virtue; text and density scale separately; every interaction responds in < 100 ms (no transition animations between screens); sorting and filtering in every table from day one.

### 2.3 FM Touch / FM Mobile

1. FM Mobile 2024: title bar with large lettering, bookmarks menu, side menu only on large screens, **an action bar at the foot of each screen** [F], https://community.sports-interactive.com/sigames-manual/football-manager-mobile-2024/the-interface-r5223/ (snippet).
2. FM Touch 2016: +/- buttons that "require a minimum of 20 taps" → no *steppers* for wide ranges; use a slider or dropdown [F], https://toucharcade.com/2015/12/15/football-manager-touch-2016-review/
3. FM Touch 2018 brings together ratings, statistics, attacking focus, and events in panels at the same time during the match [F], https://toucharcade.com/2017/12/01/football-manager-touch-2018-review/ → our match screen with commentary + tabbed panel.
4. FM26 Touch: the bench does not indicate who can play in the same position and you have to open each profile [F], https://www.pockettactics.com/football-manager-26-touch/review → the squad list on the Lineup screen shows position and condition in the row.

### 2.4 Championship Manager 01/02

1. **Text lists with no animation.** Screens are instant and the day-to-day loop is short [I], https://retrododo.com/how-championship-manager-created-a-legacy/
2. Match in text commentary only [F], https://gmgames.org/championship-manager-champman-0102/ (snippet). → The commentary is a legitimate and beloved mode; it deserves good typography.
3. **Masked attributes.** Not seeing what you realistically would not know is a mechanic [F], https://en.wikipedia.org/wiki/Championship_Manager:_Season_01/02 → our `knowledge_level` should show as a range ("9-13"), not as a gray number.
4. When ported to Xbox (SD TV), "text size and readability suffer" [F], https://www.ogxbox.co.uk/game-reviews/championship-manager-season-01-02-review

### 2.5 Football Manager 2007

1. **Header in club colors.** Primary color as background and secondary for the text, inverted if they clash [F], https://sites.google.com/site/michaeltmurrayuk/index-guides/fm09_skinningguide_p1/p2/p3 ; https://sortitoutsi.net/content/68631/how-to-modify-an-existing-skin-to-display-club-colours-on-the-headertitle-bar . (We tone it down to a two-color line because it clashes on wood; see §1.0.5.)
2. **A top strip with Back, Continue, Forward, menus, date, club, and search; Continue never moves** [F], same guide.
3. A new GUI "created with user feedback" and tips during saving/loading [F], https://en.wikipedia.org/wiki/Football_Manager_2007
4. Reviews called it clean, "without the clutter of previous versions," but "spreadsheets" without audio feedback [F], https://www.consolemonster.com/reviews/football-manager-2007-review/

### 2.6 Football Chairman (Pro)

1. Only 4 positions and a single 1-99 rating per player [F], https://siboyle.wixsite.com/sismatters/single-post/2016/09/25/gaming-matters-football-chairman-pro-review → it knows when to simplify, so the squad preview can show 4 key attributes, not 50.
2. A fixed weekly order (results, table, finances, transfers) and "Skip To End" [F], same URL.
3. High-contrast text, large touch targets, VoiceOver compatible [F], https://www.familygamingdatabase.com/en-us/accessibility/Football+Chairman+Pro
4. **Color used sparingly and only for status** (happiness "turns red") [F], same review as 1.

### 2.7 Hattrick

1. The 2020 redesign raised the minimum from 1024×768 to 1280×960 to fit more information on one page [F], https://devblog.hattrick.org/2020/09/all-you-need-to-know-about-the-hattrick-design-update/ (snippet).
2. Switch to Roboto and somewhat larger body text; even so there were requests for a bigger size [F], same URL.
3. **Skills as words** (passable 6, titanic 15, divine 20) with no sublevels; users install extensions to see numbers again → offer both forms [F], https://wiki.hattrick.org/wiki/Denominations (snippet). → Our tactical slider labels ("Balanced") + number in a tooltip.

### 2.8 Out of the Park Baseball 25/26

1. **Skins + font + font size** as separate settings, icon bar on the left or right, option to tint the interface with the team colors [F], https://wiki.ootpdevelopments.com/index.php?title=OOTP_Baseball%3AScreens_and_Menus%2FFile_Menu%2FSettings
2. **The player chooses the density.** Ratings as color bars or "numbers only," scrolling or paginated lists, a mouse-over popup with a delay or turned off [F], https://manuals.ootpdevelopments.com/index.php?man=ootp21&page=game_preferences
3. A 20-80 scale colored red (poor) / yellow (average) / blue (star); the manager's office has a **To-Do** box that is checked "at least once a day" [F], https://douglassun.substack.com/p/out-of-the-park-baseball-25-tips → a "to-do" panel in the Inbox.
4. **Column views** in families, saved by name; "Repeat Columns" takes advantage of wide screens [F], https://wiki.ootpdevelopments.com/index.php?title=OOTP_Baseball%3AControls%2FViews
5. **Browser-style navigation.** Back/forward, Backspace or right-click to go back, bookmarks on F1-F9, a context menu on any name, text with links, a status bar with date and upcoming matches [F], https://manuals.ootpdevelopments.com/index.php?man=ootp21&page=general-controls . Against: OOTP 26 looks tiny on high-resolution monitors until you manually change "Use Windows DPI scaling" [F], https://forums.ootpdevelopments.com/showthread.php?t=361011 (snippet).

### 2.9 Motorsport Manager (2016)

1. Its creator: "we learned not to use sliders for strategy and to use buttons clearly labeled with their function" [F], https://www.gamedeveloper.com/design/making-formula-1-accessible-with-i-motorsport-manager-i- → our tactical sliders always show the value in words; for options with 3-5 values, a segmented control instead of a slider.
2. Race: standings at top left with green/red arrows for position changes; fuel in **laps**, the unit in which decisions are made [F], https://steamcommunity.com/sharedfiles/filedetails/?id=801128239 → player condition in "minutes of flying left" would be the useful unit [I].
3. A fixed tab bar with a sober "business software" design [F], same URL and https://www.digitallydownloaded.net/2016/11/review-motorsport-manager-pc.html
4. A "stylish" palette and smooth transitions were praised; on mobile it looked "spacious on tablet, cramped on phone". Density is designed per screen size [F], https://toucharcade.com/2014/08/28/motorsport-manager-review/

### 2.10 F1 Manager 24

1. Praised for a "simple-to-read font and contrasting colors" that "reads at a distance" [F], https://moviesgamesandtech.com/2024/09/13/review-f1-manager-2024/
2. Three color-blindness modes [F], https://www.shacknews.com/article/140757/f1-manager-2024-review-we-think-it-might-be-plan-a
3. **Thresholds with progressive color.** Temperatures that turn orange and then red; the ideal range as a blue window; wear as a "real" white line over an "expected" block with a danger band [F], https://traxion.gg/f1-manager-2024-tips-and-tricks/ → condition bars with thresholds (green/amber/sealing-wax red) and an "expected" mark.
4. At ×2 the view switches from TV cameras to a map; "very menu-heavy" [F], https://www.thesixthaxis.com/2024/07/29/f1-manager-24-review/ . Against: tutorials that come back after you close them [F] (Shacknews).

### 2.11 Pro Cycling Manager

1. Rider panels with bars colored by resource (yellow effort, red attack, green endurance) and **numbers that flash red** when the effort is not enough [F], https://web.cyanide-studio.com/games/cycling/2025/pcm/guide/?page=race-controls
2. Continue jumps to the next event, Space advances one day; a countdown to the next event always visible; messages with "!" require attention [F], https://web.cyanide-studio.com/games/cycling/2025/pcm/guide/?page=career-manage
3. **What not to do.** PCM 2023 put "a big black box" behind each rider's name, which "only serves to make everything look the same" [F], https://www.rapidreviewsuk.com/pro-cycling-manager-2023-review/ → exactly our problem of identical boxes.
4. PCM 26 promised "better readability" and delivered "more clutter" [F], https://veloracycling.com/tech/pro-cycling-manager-26-review-race-planner-2026

### 2.12 Basketball GM / ZenGM

1. Bootstrap tables `table-hover table-sm table-striped table-borderless`: **compact, zebra-striped, borderless, and with hover**; a fixed header and 0-3 fixed left columns [F, source code], https://raw.githubusercontent.com/zengm-games/zengm/master/src/ui/components/DataTable/index.tsx → the exact recipe for §3.7.
2. A "…" menu on every table to reorder/hide columns; per-column filters with expressions (">40&<60") [F], https://zengm.com/blog/2025/01/bulk-actions/
3. Shading proportional to magnitude instead of highlighting only the winner (which gave a misleading 2-2) [F], https://zengm.com/blog/2024/10/four-factors-improvements/ → comparison bars for match statistics.
4. **League leaders in bold**: emphasis without color [F], https://zengm.com/blog/2023/03/bold-league-leaders/
5. A Ctrl/Cmd+K command palette with fuzzy search (@ players, / teams) [F], https://zengm.com/blog/2022/01/command-palette/ ; the owner's cryptic messages became a chart of three scores: "is guessing really fun?" [F], https://zengm.com/blog/2019/09/owner-messages-revamp/ → Board confidence as bars, not as sentences.

### 2.13 Crusader Kings III

1. **Nested tooltips.** Highlighted concepts inside a tooltip open their own [F], https://www.gamewatcher.com/news/crusader-kings-3-tutorials-highlighted-text-encyclopedia
2. Configurable tooltip locking (by time ~1-2 s, middle button) [F], same URL.
3. The encyclopedia shares the highlighted vocabulary; you learn "by playing" [F], https://www.pcgamesn.com/victoria-3/nested-tooltip-system → a Quidditch glossary (Wronski Feint, cobbing, blagging) linked from tooltips.
4. Limit nesting to 2-3 levels [F, analyst's opinion], https://philip.design/blog/tooltips-in-tooltips/
5. Tutorial cut from 67 boxes to a third, window sized to its content; on console they kept the density because "the community wants all the information possible at hand" [F], https://www.gamedeveloper.com/design/deep-dive-refreshing-the-crusader-kings-iii-tutorial-mode-through-optimized-ux ; https://www.paradoxinteractive.com/games/crusader-kings-iii/news/ck3-console-dev-diary-3-uiux-and-controls

### 2.14 RimWorld

1. The Work tab is a colonists × tasks grid with priority 1-4 [F], https://rimworldwiki.com/wiki/Work
2. Each cell: **outline color = skill**, flames = passion, hover = exact number [F], same URL. → The per-cell heat map is a proven solution.
3. **Letters colored by severity** (blue good, gray neutral, yellow bad, red threat), click to go to the event; persistent alerts kept separate [F], https://rimworldwiki.com/wiki/Events ; https://rimworldwiki.com/wiki/User_interface
4. Speeds ×1/×3/×5 as 1/2/3 triangles [F], https://rimworldwiki.com/wiki/User_interface
5. Tynan Sylvester (GDC 2017): "intensity hierarchy" and "minimal noise"; UI boxes are "one color with a frame of another" [F], https://spdskatr.github.io/RWModdingResources/artstyle.html

### 2.15 Against the Storm

1. Interface redesign: "the old UI was pretty but in places illegible"; now "fewer large decorative elements," mostly dark panel and tooltip backgrounds, fonts changed for readability [F], https://eremitegames.com/interface-update/ → **the clearest precedent for what needs to be done with the parchment theme**. Ornament goes to the frame, content stays flat.
2. Icons "enlarged to distinguish buildings"; small icons instead of large cards [F], same URL.
3. Tooltips in sections (a "produced in" line, recipes as a list) [F], https://eremitegames.com/1-3-update/
4. **Opposing bars** Reputation (blue, toward a crown) vs the Queen's Impatience (red, toward a skull); tooltips with exact values; clicking the alert goes to the building [F], https://eremitegames.com/ats-quality-of-life-update-2/
5. Tooltips still too small at high resolution, so they need their own size setting [F], https://steamcommunity.com/app/1336490/discussions/0/4288061719898018701/

### 2.16 Frostpunk

1. The radial UI mirrors the ring-shaped city [F], https://news.xbox.com/en-us/2019/09/20/frostpunk-console-edition-radial-driven-design-of-gameplay-and-controls/
2. **Temperature is the biggest number**, top center, with the day and the forecast; toggleable heat map [F], https://pixeltwelve.com/guides/frostpunk-beginner-guide-workers-heat-map-screen → in the match, the scoreboard and the Snitch status are "the temperature."
3. Hope (blue) vs Discontent (red) bars always visible [F], same URL.
4. "A lot of information with relatively few menus" [F], https://multiplierau.substack.com/p/frostpunk-2018-review

### 2.17 Two Point Hospital

1. Fixed layout: quick menu bottom left, information panel bottom right, objectives top right [F], https://www.thesixthaxis.com/2020/02/21/two-point-hospital-console-review-ps4-switch-xbox-one/
2. Console: larger fonts and an overview mode; still "tiny" on Switch Lite → test scaling on the smallest screen [F], https://www.dualshockers.com/two-point-hospital-developer-video-shows-console-features/
3. Icons above rooms for queues, understaffing, priority [F], https://two-point-hospital.fandom.com/wiki/Icons (snippet).
4. From Theme Hospital: **the same symbol in the alert and in the world** [F/I], https://www.gamesradar.com/the-making-of-theme-hospital-the-legendary-sim-that-paved-the-way-for-two-point-hospital/ (snippet) → the injury icon is the same in the table, the player profile, the inbox, and on the pitch.

### 2.18 Stardew Valley

1. **Interface scale (75-150%) separate from zoom (75-200%)**, in 5% steps [F], https://stardewvalleywiki.com/Options
2. A menu background that darkens the scene behind it [F], same URL.
3. **Wood is only the frame.** Text goes in dark ink on flat parchment [I, from screenshots]. It is the model for our theme.
4. Detail on mouse-over + an optional "advanced information" setting; the end-of-day summary stopped being full screen [F], https://stardewvalleywiki.com/Shipping (snippet) → the post-match summary and the daily one should be compact and easy to close.

### 2.19 Accessibility: reference numbers

- **Xbox Accessibility Guidelines 101** [F], https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101 : minimum text **PC 18 px at 1080p** (36 px at 4K), console 26 px at 1080p; scale up to 200% without losing content; at least one sans-serif and one unstylized option for each stylized font; lines ≤ 80 characters; line spacing ≥ 1.5.
- **XAG 102** [F], https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102 : contrast 4.5:1 normal, 3:1 large and inactive text, 7:1 in high-contrast mode; on non-solid backgrounds it is measured against the lowest-contrast area; do not rely on color alone.
- **Game Accessibility Guidelines** [F]: "28 px minimum on a 1080p screen… as a minimum, not a target", https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/ (intended for TV at a distance [I]); 4.5:1, https://gameaccessibilityguidelines.com/provide-high-contrast-between-text-ui-and-background/ ; long texts ~70 characters per line, https://gameaccessibilityguidelines.com/use-simple-clear-text-formatting/ ; color only as reinforcement, https://gameaccessibilityguidelines.com/ensure-no-essential-information-is-conveyed-by-a-colour-alone/
- **WCAG 2.1** [F], https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html : 1.4.3 = 4.5:1 (3:1 large), 1.4.6 = 7:1, 1.4.11 non-text = 3:1.
- **Skeuomorphic themes**: "Flat 2.0: visual simplicity without sacrificing interaction cues" [F], https://www.nngroup.com/articles/flat-design/

**How our system measures up against this [C/I].** At 1366×800 the table uses 14 px; with `canvas_items` at 1920×1080 it scales ×1.35, which gives **≈ 19 px, above the XAG minimum for PC (18 px)**. At native 1366×800 we fall below that number (it is a screen 1366 wide, not 1080p), hence the 16 px option for tables and the 115-130% scale. All the text pairs in §3.3 exceed 4.5:1 and the body ones exceed 7:1. IM Fell (stylized) is only used for titles ≥ 20 px, with a plain alternative (Alegreya Sans) for everything else. The prose of the *Daily Prophet* and the inbox is limited to ~60-75 characters per line.

### 2.20 Synthesis: the ten lessons that matter most for Quidditch Manager

1. **Ornament goes on the frame; content stays flat** (Against the Storm, Stardew, RimWorld, NN/g).
2. **Identical boxes = everything looks the same** (PCM 2023): figure and ground with two clearly separated surfaces.
3. **Readable, configurable attribute colors**, with the key attributes for the position highlighted (FM, RimWorld, ZenGM bold).
4. **Compact, zebra-striped, borderless tables with hover, a fixed header, sorting, and header tooltips** (ZenGM, FM, OOTP).
5. **Density > tiles** (the failure of FM26); a bigger monitor should show more.
6. **Text and density scale separately**, with intermediate steps (FM26, Stardew, OOTP).
7. **A fixed Continue, with a shortcut, that says what is pending** (FM07, FM24, PCM).
8. **Browser-style navigation**: back/forward, links on every name, context menu, F-key shortcuts (OOTP, FM).
9. **Immediate feedback** and alerts by severity that click through to their source (FM26 as a counterexample, RimWorld, Against the Storm).
10. **Tooltips that teach the game** (CK3) and the units in which decisions are made (Motorsport Manager).


---

## 3. Design system for Godot

Everything that follows is **[I]** (my own proposal) except where a lesson from §2 or a calculation [C] is cited. It is designed for `ThemeBuilder` + `UI` as they stand today: **only `StyleBoxFlat`, `FontVariation`, `ColorRect`, and `_draw()`**. This departs from `04` §6.11, which planned 8-10 nine-patch textures. We do not need them for it to look good, and every texture is an asset to maintain.

### 3.0 Principles (in order of priority)

1. **Data first, theme second.** No aesthetic decision may reduce the readability of a 25-row table. The theme lives in the **frame** (wood, headers, titles, the Daily Prophet), not inside the cells.
2. **A single box.** At most two surface levels below the frame: *desk* (the background of the content area) and *card* (a panel). Inside a card there are no more boxes. Sections are separated by a label and space.
3. **Color is information, never decoration** inside the data: green = good/rising, sealing-wax red = bad/falling/danger, amber = attention, ink blue = link/interactive, brass = selection/primary action. Always accompanied by a number, icon, or shape.
4. **All usable space works.** If a list is short, the leftover space is taken by a context panel (player preview, assistant summary); it is not left empty.
5. **Every action has a visible response** in under a second (toast, row change, discreet sound).

### 3.1 Pixel budget at 1366×800

| Element | Today | Proposal |
|---|---|---|
| Top bar | 48 px | **44 px** |
| Bottom bar | 42 px | **removed**: "next match" moves to the foot of the side menu and "Save" to Ctrl+S and the menu |
| Side menu | 190 px (empty on new game) | **200 px**, collapsible to 56 px (icons only); hidden on New game |
| Content margin | 14 px | **16 px** |
| **Usable content area** | ≈ 1,146 × 682 px | **1,134 × 724 px** (+42 px of height) |

All the wireframes in §3.12 add up to exactly that width and height.

### 3.2 Scaling

- `project.godot`: `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`, base size 1366×800. With `expand`, the extra area at 16:9 or 16:10 becomes more rows and columns, not black bars; `canvas_items` rescales vector fonts crisply.
- An **"Interface size"** option 90 / 100 / 115 / 130% that modifies `get_tree().root.content_scale_factor`. At 1920×1080 with `expand` the base scale ends up at `min(1920/1366, 1080/800) = 1.35` [C].
- A **"Table text size"** option: 13 / 14 / 16 px (changes the `font_size` of `Tree` and the row height in the same proportion). FM, OOTP, and Basketball GM offer size or density control (§2).
- A **"Density"** option: Normal (row 26) / Compact (row 22, card padding 12), the equivalent of the Default/Condensed modes announced for FM27 (§2.2). Text and density are adjusted separately, which is exactly what FM26 did not do.
- An **"Attribute thresholds"** option, with the heat-map cutoffs (6 / 11 / 16 by default) editable, as in FM24 (§2.1.4).

### 3.3 Revised palette (parchment/wood base kept)

The base from `04` §6.4 is kept because it is what makes it feel like "the Harry Potter of the books" at zero cost and it has very high text contrasts. What was wrong was not the palette but **how the tones are layered**. The paper of the desk, of the panels, and of the rows were almost identical (1.07-1.15:1) [C]. The fix: darken the *desk* and lighten the *card* so the card "floats," and move the attributes from colored text to a **heat map in the cell background**.

**Surfaces**

| Token | Hex | Use | Contrast [C] |
|---|---|---|---|
| `wood` | `#2B1D14` | Frame, side menu | |
| `wood_mid` | `#3D2A1E` | Top bar, table headers, menu hover | |
| `wood_sel` | `#4A3424` | Selected menu item | parchment on top 10.3:1 |
| `desk` | `#E2D3AE` | Background of the content area (previously `#EFE4C8`) | card on desk 1.32:1 + shadow |
| `card` | `#F7F1E1` | Panels and tables (previously `#F4EBD6`) | ink 14.4:1 |
| `zebra` | `#EDE3CA` | Odd rows | ink 12.7:1; vs card 1.13:1 |
| `hover` | `#E6D7B2` | Row under the mouse | ink 11.4:1; vs card 1.26:1 |
| `selection` | `#E9CF86` | Selected row (light brass) | ink 10.6:1; vs card 1.36:1 |
| `input` | `#FFFBF0` | Background of LineEdit/SpinBox/OptionButton | ink 15.7:1 |
| `border` | `#CBB88C` | Card bottom border, section separators | decorative |
| `border_control` | `#8A6428` | Border of inputs and secondary buttons | 5.2:1 on input (≥3:1 WCAG 1.4.11) |
| `newspaper` | `#EEE8D8` | *Daily Prophet* paper | ink 13.3:1 |

**Text and semantics**

| Token | Hex | Use | On `card` [C] |
|---|---|---|---|
| `ink` | `#2A1E14` | Main text | 14.4:1 |
| `ink_soft` | `#5C4A36` | Secondary, labels, attributes 6-10 | 7.5:1 |
| `ink_faded` | `#7C6A52` | Disabled, irrelevant to the position | 4.6:1 |
| `bronze_text` | `#7A5A26` | Section labels (not for body text) | 5.6:1 |
| `ink_blue` | `#2E4A6B` | Links (players, clubs), keyboard focus | 8.1:1 |
| `ink_green` | `#2F5A2A` | Positive, rising, high condition | 7.1:1 |
| `amber` | `#8C5E0A` | Attention (medium condition, contract about to expire) | 5.0:1; 3.8:1 on bar track |
| `sealing_wax` | `#8E1F1C` | Negative, falling, injury, danger | 7.9:1 |
| `brass` | `#C9A14A` | Brass accent **only on wood** | 6.7:1 on wood; 5.6:1 on wood_mid |
| `brass_button` | `#E2C25A` | Primary button background | ink on top 9.4:1 |
| `menu_text` | `#E9DDBF` | Side menu text | 12.1:1 on wood |
| `menu_faded` | `#9C8B72` | Menu group labels | 4.9:1 on wood |

**Attributes 1-20: heat map in the cell background** (replaces `attr_color()`):

| Range | Cell background | Text | Weight | Text contrast [C] |
|---|---|---|---|---|
| 1-5 | `#EDB8A8` (sealing-wax pink) | `sealing_wax` | Regular | 5.1:1 |
| 6-10 | none | `ink_soft` | Regular | 7.5:1 |
| 11-15 | `#BFD596` (light green) | `ink` | Regular | 10.2:1 |
| 16-20 | `#2F5A2A` (solid ink green) | `card` | **Bold** | 7.1:1 |

The backgrounds were checked against **both** row surfaces [C]: 1-5 = 1.55:1 on `card` and 1.37:1 on `zebra`; 11-15 = 1.41:1 and 1.25:1; 16-20 = 7.1:1 and 6.3:1. (A first version with `#D6E3B8` came out at 1.06:1 on the zebra, so the "good" level vanished on odd rows.)

Three channels at once (background, weight, number). The three upper levels (6-10 → 11-15 → 16-20) are stepped in luminance (empty → light → solid) and can be told apart in grayscale; the 1-5 level has a luminance similar to 11-15 and is distinguished by hue and by the sealing-wax text. In `Tree`: `item.set_custom_stylebox(col, chip)` (a `StyleBoxFlat` with radius 3; if you want a chip with some breathing room inside the cell, draw it with `set_custom_draw_callback`) or `set_custom_bg_color(col, c)`, + `set_custom_color(col, c)` + `set_custom_font(col, table_bold)`. On the player profile, each number goes inside a 30×20 `PanelContainer` with the same `StyleBoxFlat`. For attributes estimated by scouting (knowledge < 2) the range "9-13" is shown with no background, in italic `ink_soft`.

**Club colors.** Never as the background of an entire bar. They are used in: a 4 px strip (two colors) before the name in tables, a **3 px line on the bottom edge of the top bar** split into color 1 / color 2, the portrait/crest, the player tokens on the pitch, and the match scoreboard strip.

### 3.4 Typography

Families available in `assets/fonts/`: IM Fell English (+SC, +Italic), Alegreya Sans Regular/Medium/Bold/Italic, Alegreya (variable), UnifrakturMaguntia. **There is no need to add any**; optionally Alegreya Sans **ExtraBold** for the scoreboard.

| Level | Use | Font | Size / line height | Color |
|---|---|---|---|---|
| `Display` | Match scoreboard, Daily Prophet masthead | IM Fell English / Unifraktur | 40 / 44 | ink or parchment |
| `H1` | Screen title | IM Fell English | 28 / 32 | ink |
| `H2` | Card title | IM Fell English | 20 / 24 | ink |
| `Caption` | Section label inside a card, table header, menu group | Alegreya Sans Bold, UPPERCASE, `spacing_glyph = 1` | 12 / 16 | `bronze_text` (card), parchment (header), `menu_faded` (menu) |
| `KPI` | Highlighted figures (balance, value, condition on profile) | Alegreya Sans Bold with `tnum` | 22 / 26 | ink |
| `Body` | Interface text, buttons, menu, forms | Alegreya Sans Regular / Medium | 15 / 20 | ink |
| `TableText` | Cells | Alegreya Sans Regular with `tnum`+`lnum` | 14 / row 26 | ink |
| `Meta` | Secondary data (town, date, unit) | Alegreya Sans Regular | 13 / 18 | `ink_soft` |
| `Prose` | Letters, the Daily Prophet, reports | Alegreya (serif) | 17 / 24, max width 680 px | ink |

Rules:
- **Absolute minimum of 13 px** for any text that has to be read (12 only for the uppercase `Caption`, which gains apparent size). The current 11 and 12 px sizes are removed.
- **IM Fell never below 20 px** and never the SC version for small labels. Today the panel titles in IM Fell SC 18 px bronze are the least readable part of the interface.
- Data > prose. The important figure on a card is bigger than its explanation.
- Implementation: **`Theme` type variations** instead of per-control overrides: `th.set_type_variation("H1", "Label")`, `th.set_font("font", "H1", font("title"))`, `th.set_font_size("font_size", "H1", 28)`, etc., and `label.theme_type_variation = "H1"`. `UI.label()` changes to take a level (`UI.text("H2", "Contrato")`) and stops accepting loose sizes. The label's `spacing_glyph` is done with a `FontVariation`.

### 3.5 Spacing and grid

- 4 px unit. Allowed scale: **4, 8, 12, 16, 24, 32**. Nothing outside the scale.
- Content area margin 16; separation between cards 12; card inner padding 16 (12 on dense match cards); separation between form rows 8; between a label and its control 4; between sections inside a card 16 + label.
- Heights: table row 26 (24 in compact mode), attribute list row 22, control (button/input/dropdown) 32, compact button 28, Continue 32 in a 44 bar, menu item 30.
- Column grid for the usable area: 12 columns of 83 px with a 12 px gutter (12×83 + 11×12 = 1,128 ≈ 1,134). Standard side panels take 3 or 4 columns (≈ 280 / 370 px).

### 3.6 Surface hierarchy (at most 2 levels below the frame)

| Level | What it is | Style |
|---|---|---|
| 0 · Frame | Top bar, side menu | `wood` / `wood_mid`, no borders except the club-color line |
| 1 · Desk | Background of the content area | `desk`, no border |
| 2 · Card | Panel with content | `card`, `border_width_bottom = 1` in `border`, `shadow_size = 4`, `shadow_offset = (0, 1)`, `shadow_color = #2B1D1426`, radius 4, padding 16 |

Forbidden: a card inside a card; a border around a `Tree` or `ItemList` that is already in a card (the Tree's `panel` = `StyleBoxEmpty`); a rule under every screen title (the H1 already separates; it is replaced by 12 px of space). The only exceptions: the *Daily Prophet* paper (it is an object, a newspaper on the desk) and tooltips/popups (they float).

### 3.7 Tables (`Tree`)

| Property | Value |
|---|---|
| Font / size | `table` (tnum+lnum) 14 px; header `Caption` 12 px Bold uppercase |
| Row height | 26 px: `v_separation = 4` and `TreeItem.custom_minimum_height = 26` |
| Header | `wood_mid` background, `card` text (12.0:1 [C]), no per-cell borders; 1 px vertical separator `#5A4330` only between column groups; sorted column in `brass` (5.6:1) with ▲/▼. The `Tree` header already stays fixed when scrolling |
| Zebra | `set_custom_bg_color` on odd rows with `zebra` (there is no native zebra in `Tree`) |
| Horizontal separators | none (the zebra replaces them): theme constant `draw_guides = 0` |
| Hover | the Tree's `hovered` stylebox with `hover` |
| Selected | `selected` / `selected_focus` with `selection`, no border, radius 0 |
| Your own club's row (league tables) | Bold text + a 4 px club-color strip, as `04` §6.7 asks for |
| Alignment | text on the left; figures on the right with tnum; 1-20 attributes centered in 34 px columns; icons centered |
| Widths | name `expand` (min. 180); position 36 (badge); age 40; attributes 34; condition 64 (bar + number); morale 28 (icon); form 64 (5 drawn squares); money 72; date 84 |
| Sorting | `column_title_clicked` → re-sort and redraw; a second click reverses; the sort is remembered per screen |
| Grouping | non-selectable label rows ("KEEPERS · 2") with a `desk` background in squad tables when sorted by position |
| Columns without information | if all values are equal (morale "Normal" for the whole squad), the neutral icon or "—" is shown, never the same word 14 times |
| Tooltips | on every abbreviated cell (`TreeItem.set_tooltip_text`) and on every header (`Tree.set_column_title_tooltip_text`, full attribute name) |
| Double-click / Enter | opens the profile; right-click → actions menu (`PopupMenu`) |
| Empty | if the table has fewer rows than the available height, the table shrinks (`SIZE_SHRINK_BEGIN` + height by rows) and the space is taken by the context panel |

API verified in this session with `godot --doctool` on Godot 4.7.2 [C]: `Tree` has the styleboxes `hovered`, `hovered_selected`, `selected`, `selected_focus`, `title_button_*`, the constants `draw_guides`, `v_separation`, `inner_item_margin_*`, the signal `column_title_clicked`, and `set_column_title_tooltip_text`; `TreeItem` has `custom_minimum_height`, `set_custom_bg_color`, `set_custom_stylebox` (per-cell background: works for the heat map with a rounded chip), `set_custom_font`, `set_custom_draw_callback`, and `set_tooltip_text`.

For things `Tree` does not draw (condition bars, form squares, badges), use `set_cell_mode(col, TreeItem.CELL_MODE_CUSTOM)` + `set_custom_draw_callback(col, callable)`, which in Godot 4 receives the `TreeItem` and the cell's `Rect2`. That way the table remains a single `Tree` (fast, with scrolling and sorting) and not a grid of hundreds of `Control`s.

### 3.8 Buttons and inputs

Height 32, horizontal padding 16, radius 4 for **all** of them (no more sealing-wax button with radius 12). Font `Body` Medium 15 (Bold on primary and danger).

| Type | Use | Normal | Hover | Pressed | Disabled | Focus (keyboard) |
|---|---|---|---|---|---|---|
| **Primary** | One primary action per screen; Continue | `brass_button` background, ink Bold text, `border_bottom 2` in `#8A6428` | `#EBCD6A` | `#C9A14A`, border on top instead of bottom (it "sinks") | `#E7DDC4` background, `ink_faded` text | 2 px `ink_blue` outline (`expand_margin` 2) |
| **Secondary** | Normal actions | transparent background, 1 px `border_control` border, ink text | `zebra` background | `hover` background | `#CBB88C` border, `ink_faded` text | same |
| **Tertiary / link** | Navigate to a player or club, "see all" | no background or border, `ink_blue` text | underline | | `ink_faded` | same |
| **Danger (sealing wax)** | Irreversible: terminate, sign | `sealing_wax` background, `card` Bold text | `#A52622` | `#6E1512` | as primary | same |
| **On wood** | Back/forward, collapse menu | 16 px icon in `menu_text`, no background, 32×32 | `wood_sel` background | | 40% opacity | same |

- Irreversible actions ask for confirmation with a dialog and the sealing-wax seal (the idea from `10` §3.1 is kept); everything else executes instantly and shows a toast.
- **Inputs** (`LineEdit`, `SpinBox`, **and also `OptionButton`**): `input` background, 1 px `border_control` border, radius 3, height 32; focus: 2 px `ink_blue` border. The dropdown stops looking like a button. It is a field with a chevron. Placeholder in `ink_faded`.
- **Segmented controls** (table views, profile tabs): `TabBar` with a `desk` background, active tab `card` with Bold text and a 2 px `brass` bottom line; inactive ones in `ink_soft` text.
- **Sliders**: 4 px `border` track, `bronze_text` fill, 14 px circular `card` knob with a 2 px `bronze_text` border (drawn with `StyleBoxFlat` into the `grabber` icons via an `ImageTexture` generated once, or a custom `Control`). Always with the current value in words on the right ("Balanced", "High pressure").

### 3.9 Bars, badges, icons, tooltips, toasts

- **Progress bars** (condition, morale, confidence, knowledge): 8 px tall (6 in tables), `desk` track, radius 2; semantic fill: ≥ 75 `ink_green`, 50-74 `amber`, < 50 `sealing_wax` (all three ≥ 3.8:1 against the track [C]); **always with the number** on the right in `TableText`.
- **Badges**: height 18, radius 9, `Caption` 12. Position: 1 px ink outline and letter (G/C/B/S in Spanish, K/C/B/S in English) with the icon of the position's ball; status: Injured (solid `sealing_wax`), Suspended (solid `amber`), Transfer-listed (`ink_blue` outline), Captain (solid `brass_button`, ink text), Youth (`ink_green` outline).
- **Icons**: **Phosphor Icons** (MIT, 1,500+ icons, regular/bold/fill weights, 16-32 px grid) for everything generic: menu, filters, sorting, search, arrows, alerts, save. **game-icons.net** (CC BY 3.0, requires credits) for the magical: broom, owl, cauldron, wand, parchment, Galleon. Import SVG at 2× (`svg/scale = 2`) and tint with `modulate`/`self_modulate`. Sizes: 16 in tables and menu, 20 in buttons, 24 in headers. For positions (hoop, Quaffle, bat, Snitch), draw 4 simple custom SVG icons; there are no good free equivalents [I].
- **Tooltips**: `wood` background, `menu_text` text 14 px, 1 px `brass` border, radius 4, padding 8×12, max width 320 (`_make_custom_tooltip()` with `RichTextLabel` and autowrap), 0.4 s delay (`gui/timers/tooltip_delay_sec`). Content: full name + what it does + how it is used in the match (`10` §4). Later, CK3-style nested tooltips for terms ("Wronski Feint") (§2).
- **Toasts** (action feedback): top right under the bar, `wood` background, `menu_text` text, semantic icon on the left, 3 s, stackable, with an optional link ("View contract"). They replace the 12 px italic labels at the bottom of the panels.
- **Empty states**: 32 px icon + one line in `ink_soft` + an action ("No offers. Search for players ▸").

### 3.10 Common frame

```
┌ top bar 44 px · wood_mid ────────────────────────────────────────────────────────────────────────────────┐
│ [◀][▶]  [crest 28] Puddlemere United  · Squad                 Sun 1 Aug 1993  ·  15,000 G  · 🦉 3  [Continue ▸]│
├═══ 3 px line: navy blue │ gold (club colors) ═════════════════════════════════════════════════════════════════┤
│ menu 200 px    │ desk · 16 px margin                                                                          │
│ OFFICE         │                                                                                              │
│  ✉ Inbox     3 │                                                                                              │
│  ▤ The Prophet │                                                                                              │
│ TEAM           │                                                                                              │
│  ☰ Squad       │                       usable area 1,134 × 724                                                │
│  ⌖ Lineup      │                                                                                              │
│  ↗ Training    │                                                                                              │
│ COMPETITION    │                                                                                              │
│  ▦ Table       │                                                                                              │
│  ▢ Fixtures    │                                                                                              │
│  ◎ Competit.   │                                                                                              │
│ MARKET         │                                                                                              │
│  ⇄ Transfers   │                                                                                              │
│  ⌕ Scouting    │                                                                                              │
│  ⌂ Schools     │                                                                                              │
│ CLUB           │                                                                                              │
│  G Finances    │                                                                                              │
│  ♜ Board       │                                                                                              │
│  ⓘ Club · Hist.│                                                                                              │
│ ┌────────────┐ │                                                                                              │
│ │NEXT MATCH   │ │                                                                                              │
│ │▌Falmouth F. │ │                                                                                              │
│ │Sat 4 Sep    │ │                                                                                              │
│ │Yorkshire M. │ │                                                                                              │
│ └────────────┘ │                                                                                              │
└────────────────┴──────────────────────────────────────────────────────────────────────────────────────────────┘
```

- Top bar: always stays wood; the club shows in the crest and the two-color bottom line. Breadcrumbs ("· Squad") in `menu_faded` next to the club.
- **Continue**: primary, 160×32, at the far right, with the **Space** shortcut (and Enter) shown in the tooltip. Its text says what is going to happen ("Continue", "Answer 3 owls", "Play vs Falmouth"); when something is blocking, it gets a `sealing_wax` dot. Lesson from FM (§2).
- Owl with a counter = shortcut to the Inbox (like the messages icon in FM/OOTP).
- Menu: labeled groups, 30 px item with a 16 px icon, `wood_mid` hover, selected `wood_sel` + 3 px `brass` left bar + Bold text. F1-F8 shortcuts for the most used sections, Alt+←/→ back/forward, Ctrl+S save.
- The foot of the menu shows the **next match** (or "Match in progress" / "No match," consistent with the actual state). Today it says "next" for the match being watched.

### 3.11 Match: scoreboard strip

An 88 px `PanelContainer` in `wood` across the full width of the usable area: home club color block (8 px) · crest 40 · H2 name in parchment · **Display 40 scoreboard** · difference ("−20") in `Meta` · tnum clock · **three-state Snitch indicator** (gray icon "not sighted" / gold "sighted by Huckle" / flashing gold "chase: Goodbody vs Huckle") · name · crest · away color block. Below, in the same strip, speed controls ×1 ×2 ×4 and "Pause". Consistent with `04` §6.9.7.

### 3.12 Wireframes of the six screens (usable area 1,134 × 724)

#### New game (no side menu: area 1,334 × 724)

```
┌ H1 "New game"                           [ New game | Load game ]  (TabBar) ──────────────────────────────────────────┐
├─ CHOOSE YOUR CLUB 360 ───────┬─ CLUB PROFILE 560 (expand) ─────────────────────┬─ YOUR PROFILE 390 ───────────────────┤
│ ▸ BRITISH AND IRISH LEAGUE   │ [crest 96]   Puddlemere United (H1 IM Fell 32) │ MANAGER NAME                          │
│ ┃▌Appleby Arrows        44px │              «motto in italics»               │ [Your name                        ]   │
│ ┃ Appleby, Cumbria · Eng.    │              Dorset, England · founded 1163   │ NATIONALITY    [England ▾]            │
│ ┃▌Ballycastle Bats           │ ┌ KPI ─────┬ KPI ─────┬ KPI ───────┬ KPI ───┐  │ LANGUAGE       [English ▾]            │
│ ┃ Ballycastle, Antrim        │ │ 22       │ 2        │ Favorite   │ 15,000G│  │                                       │
│ ┃▌...                        │ │ Leagues  │ Eur. Cups│ Expectation│ Cash   │  │ ▸ Advanced options (seed, leagues)    │
│ ┃▌Puddlemere United  (sel.)  │ └──────────┴──────────┴────────────┴────────┘  │                                       │
│ ┃▌...                        │ KNOWN PLAYERS (table: pos·name·age·★)         │ You start on 1 Aug 1993. The season   │
│ ┃ 14 clubs · 44 px row       │ S Benjy Williams   25 ★★★☆☆                     │ ends with the Dartmoor World Cup.     │
│ ┃ = 616 px, no gap           │ ...                                            │                                       │
│ ▸ NO CLUB (unemployed)       │ STADIUM · ... Moor  · BOARD expects...         │        (space)                        │
│                              │                                                │ [ Sign with Puddlemere United ] wax   │
└──────────────────────────────┴────────────────────────────────────────────────┴───────────────────────────────────────┘
```
Load game: the same central card turns into a table of saved games (club with color strip, manager, in-game date, real save date, season) and the primary button says "Load".

#### Squad

```
┌ H1 "Squad" · Meta "14 players · 3 injured"                        [View: General|Flying|Technical|Mental|Physical|Contracts] ┐
│ [All|Starters|Reserves|Youth]  [⌕ search   ]                                           [Actions ▾]                        │ 36 px
├─ TABLE 822 px (card) ────────────────────────────────────────────────────────────┬─ PREVIEW 300 px (card) ───────────────┤
│ ▌ NAME             POS AGE  COND    MOR FORM   SPD AGI PAS SHO ATK BAT CAT DEC STA  $/WK VALUE │ [portrait 64] Benjy Williams (H2)│
│ KEEPERS · 2                                                                        │ (S) Seeker · 25 · Eng. · Starter      │
│ ★ Evelyn Fettle     K   31  ▬▬▬ 100  ☺  ■■■■□  12  13  16  11 [19] 11  14  10   8   24   979│ ─ KEY ATTRIBUTES ──────────────  │
│   Jemima Wriggl.    K   20  ...                                                    │ Catching ■■■■■■■■ 16              │
│ CHASERS · 7                                                                        │ Vision   ■■■■■■■■ 16              │
│   ...                                                                              │ Speed    ■■■■■■■■ 16              │
│ (26 px × 14 rows + 4 labels + header = 494 px)                                     │ Dive     ■■■■■■■■ 16              │
│                                                                                    │ ─ STATUS ─ Cond 100 · Morale ☺    │
│                                                                                    │ ─ CONTRACT ─ 13 G/wk · Jun 1995  │
│ (with 25+ players the table reaches the bottom and scrolls)                        │ [View profile] [Actions ▾]        │
└────────────────────────────────────────────────────────────────────────────────────┴───────────────────────────────────────┘
```
The preview follows the selected row (like FM's player panel and OOTP's sidebar); with short squads the leftover space is its own.

#### Lineup and tactics

```
┌ H1 "Lineup & tactics"   ● Lineup valid (green) · Assistant: 1 warning (amber)   [Let the assistant pick the team] ┐ 40
├─ SQUAD 320 ──────────────────┬─ PITCH 470 (card, _draw) ────────────────────────┬─ INSTRUCTIONS 320 ───────────────────┤
│ POS NAME          COND  ★    │  ╭──────────────────────────────────────────╮    │ TEAM                                 │
│ K ▸Evelyn Fettle  100 ★★★    │ ⊙⊙⊙   C        C        C                 ⊙⊙⊙    │ Mentality   ──●──  Balanced          │
│ K  Jemima W.       100 ★★     │  │        B          B                      │    │ Tempo       ──●──  Normal            │
│ C ▸Digby Duckett  100 ★★★    │  │   K                         S            │    │ Passing     ──●──  Mixed             │
│ ...                          │  ╰──────────────────────────────────────────╯    │ Shooting / Pressing / Hard play / Time│
│ (▸ = on the pitch; drag      │  44 px tokens: number, short name, cond. bar      │ CHASERS     [Free ▾]                 │
│  onto a token to swap)       │  click a token → its row is highlighted on left   │ BEATERS     [Nearest ▾]              │
│                              ├─ ASSISTANT (inside the same card) ───────────────┤ SEEKER      [Always catch ▾]  ⚠      │
│ BENCH                        │ ⚠ The Seeker will catch the Snitch even if we    │   Margin    [+50 ▾]                  │
│ C  Declan Cloggs  100        │   are losing by more than 150. [Change to "only  │   Search    [Freely ▾]               │
│ ...                          │   if +50"]  ✓ Chasers master "Free" at 70%       │   Wronski   [If there's a chance ▾]  │
│                              │                                                  │ KEEPER      [In the area ▾]          │
└──────────────────────────────┴──────────────────────────────────────────────────┴──────────────────────────────────────┘
```
The assistant's warning is anchored with ⚠ to the control that triggers it and brings the action to fix it.

#### Match (text commentary)

```
┌ SCOREBOARD STRIP 88 px (§3.11), full width ───────────────────────────────────────────────────────────────────────────────┐
│ ▌[crest] Puddlemere United  160 – 180    Falmouth Falcons [crest]▌   50:45 · ✦ Snitch caught by Huckle!   [Continue ▸]│
├─ COMMENTARY 680 (card) ─────────────────────────────────────────────┬─ [Team | Tactics | Statistics] 442 (card) ────────┤
│ [All | Key]                                                           │ TEAM (condition)                                   │
│ ┃ 43:30  ◉  GOAL by Evelyn Wanless!                       150–20      │ K  Evelyn Fettle      ▬▬▬▬▬▬▬▬▬ 98                 │
│   43:55  ⊗  Bludger smashes into Godwin Rumbelow                      │ C  Digby Duckett      ▬▬▬▬▬▬▬▬  91                 │
│   45:35  ✋  Fettle saves from Rumbelow                                │ C  Niamh Bramble      ▬▬▬▬▬▬    74  (amber)        │
│ ┃ 49:00  ✦  Eldred Huckle spots the Snitch                             │ ...                                                │
│ ┃ 49:30  ⚑  Cobbing: Duckett elbows Beamish. Penalty.                  │ STATISTICS              US              THEM       │
│ ┃ 50:45  ✦  HUCKLE CATCHES THE SNITCH!!                   160–180      │ Shots        41 ▬▬▬▬▬▬▬▬▬▬▬▬|▬▬▬▬ 13              │
│ (24 px row; ┃ = 3 px bar in the semantic color on key events;       │ Saves         7 ▬▬|▬▬▬▬▬▬▬ 19                       │
│  a single family: Alegreya Sans; key events in Bold)                  │ Bludger hits / Fouls / Sightings                   │
└───────────────────────────────────────────────────────────────────────┴────────────────────────────────────────────────────┘
```
When it ends, Continue says "Finish and return to the office" and the bottom bar/menu stops announcing this match as the next one.

#### Player profile

```
┌ HEADER 88 px (card) ─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [portrait 64] Benjy Williams (H1)  ▌Puddlemere United (link)     VALUE    WAGE       CONTRACT     COND   MORALE [Actions ▾]  │
│              (S) Seeker · 25 years · England · Starter           503 G    13 G/wk    Jun 1995     100    ☺      [Renew]      │
├ [ Profile | Progress | History | Contract | Reports ]  (TabBar, 36) ────────────────────────────────────────────────────────┤
├─ ATTRIBUTES 810 (card, 2 columns of 395) ─────────────────────────────────────────────┬─ CARD 312 (card) ─────────────────┤
│ FLYING                             │ MENTAL                                         │ BROOM · Nimbus 2000                 │
│ Speed                ▲  [16]       │ Aggression               10                    │ Speed       ■■■■■  Accel.  ■■■■□    │
│ Acceleration            [15]       │ Anticipation             10                    │ Turning     ■■■■□  Braking ■■■■□    │
│ Agility                 [15]       │ Bravery               [15]                     │ Altitude    ■■■■□  Stab.   ■■■■□    │
│ ... (7)                            │ ... (14)                                       │ Condition 100% ▬▬▬▬▬▬▬▬▬             │
│ TECHNICAL                          │ PHYSICAL                                       │ ABILITY ★★★☆☆  POTENTIAL ★★★★☆      │
│ Snitch catching ◆       [16]       │ Stamina                  11                    │ (drawn stars, not glyphs)           │
│ Passing (dimmed: not key)  6       │ ... (5)                                        │ THIS SEASON (2×4 table)             │
│ ... (10)                           │                                                │ Apps 0 · Catches 0 · Rating –       │
│ 22 px row: 17 and 19 rows + 2 labels ≈ 470 px                                       │ ASSISTANT'S REPORT (prose 15)       │
│ ◆ = key attribute for the position (bold); not key = ink_faded, no background    │ «Balanced. Canon player.»           │
└────────────────────────────────────────────────────────────────────────────────────┴─────────────────────────────────────┘
```
Width: 810 + 12 + 312 = 1,134 [C]. Secondary actions (transfer-list, make captain) go in "Actions ▾"; "Terminate" lives in the menu with a sealing-wax confirmation, not as a permanent red button.

#### The Daily Prophet

```
┌ NEWSPAPER PAPER (newspaper #EEE8D8, shadow) across the whole area ─────────────────────────────────────────────────────────────┐
│                                   The Daily Prophet  (Unifraktur 48)                           [◀ No. 5]  No. 6  [No. 7 ▶]   │
│ ═══════ Mon 6 Sep 1993 · No. 6 · 5 Knuts ═════════════════════════════════════════════════════════════════════════════════ │
├─ FRONT PAGE (2 columns of prose, 700) ──────────────────────────────────────┬─ SPORT (390) ───────────────────────────────┤
│ CANNONS STUN THE BATS (IM Fell 34, uppercase)                               │ MATCHDAY 1 RESULTS                          │
│ Gudgeon caught the Snitch after 54 minutes at Yorkshire Moors (Alegreya it.)│ ▌Chudley C.     190–110  Ballycastle B. ▌   │
│ ┌ "moving photo"     ┐  D rop cap. Body Alegreya 17/24 in two columns       │ ▌Wigtown W.      50–290  Tutshill T.    ▌   │
│ │  320×180, 2-4 frames│  of 330 px (≈ 60 characters per line)...           │ ... (6 tnum rows)                           │
│ └─────────────────────┘                                                     │ ─────────────────────────────────────────── │
│ ─────────────────────────────────────────────────────────────────────────── │ TABLE (points only, like the Prophet)       │
│ OUR TEAM: Puddlemere fall 160–180 to Falmouth (H2) · 3 lines                │ 1 Appleby Arrows 320 · 2 Tutshill 290 ...   │
├─ IN BRIEF (3 columns of 360) ───────────────────────────────────────────────┴─────────────────────────────────────────────┤
│ INJURIES: Wilda Griffiths, 5 days │ TRANSFERS: rumors…            │ WITCH'S HEART: romance between rival Seekers?        │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```
1 px ink rules between columns (yes, here the rule is part of the "newspaper" object). The editions selector moves to the masthead and frees up 200 px.

---

## 4. Do first: prioritized changes for one session

Ordered by **visible impact / effort**. Times are estimates [I] for someone who knows the code; the files are the ones that need to be touched.

| # | Change | Files | Effort | Impact |
|---|---|---|---|---|
| 1 | **Fix the player profile overflow**: remove the 150 `custom_minimum_size` from the attribute columns, switch to 2 columns (Flying+Technical / Mental+Physical) in a `GridContainer` with `EXPAND_FILL`; `clip_contents` on the content area | `player_screen.gd:30-43, 94-96` | 20 min | Critical: content is cut off today |
| 2 | **Separate figure and ground**: content area in `desk #E2D3AE`, panels in `card #F7F1E1` with bottom border + shadow, no perimeter border; remove the border of the `Tree`/`ItemList` inside panels and the rule under the H1 | `main.gd` (paper), `ui.gd: panel()`, `theme_builder.gd` (Panel, Tree, ItemList), `ui_screen.gd: header()` | 30 min | Very high: the "boxes inside boxes" effect disappears on every screen |
| 3 | **Attributes as a heat map** (cell background + bold for 16-20) in the squad and player profile; rewrite `attr_color()` as `attr_style()` returning background, text, and font | `theme_builder.gd`, `squad_screen.gd`, `player_screen.gd` | 40 min | Very high: the main data point becomes readable at a glance |
| 4 | **Tables**: dark header without per-cell borders, zebra, 26 px row, selection `#E9CF86`, `draw_guides` off, sort by header click (`column_title_clicked`), tooltips on abbreviations, "Age" not truncated | `theme_builder.gd` (Tree), `ui.gd: table()/row()`, `squad_screen.gd` | 60 min | Very high in Squad, Table, Transfers, Scouting |
| 5 | **Type scale as theme variations** (`H1`, `H2`, `Caption`, `KPI`, `Meta`, `Prose`), remove 11-12 px, take IM Fell SC out of panel titles | `theme_builder.gd`, `ui.gd` (`title`, `subtitle`, `label`) | 45 min | High: clear hierarchy on every screen |
| 6 | **Frame consistency**: top bar always wood with a 3 px club-color line; remove the bottom bar and move "next match" to the foot of the menu with the correct state (do not announce the match being watched); hide the menu and Save when there is no game; Continue with the Space shortcut | `main.gd` (`_build`, `_refresh_bars`) | 45 min | High: +42 px of height and an end to the contradictory messages |
| 7 | **Grouped side menu with icons** (5 groups, 30 px item, selected with a brass bar) | `main.gd` (`MENU`, `_rebuild_menu`), 16 Phosphor SVGs in `assets/icons/` | 45 min | High: readable, "game-like" navigation |
| 8 | **System buttons and inputs** (primary/secondary/danger/link with radius 4; `OptionButton` looking like a field; blue focus) | `theme_builder.gd`, `ui.gd` (`button`, `seal_button`) | 30 min | Medium-high: action is distinguished from value (the lineup stops being 14 buttons) |
| 9 | **Glyphs → drawing**: broom segments, stars, form, and condition as a `Control` with `_draw()` or `CELL_MODE_CUSTOM` cells; bars always with a number | `ui.gd` (new `segments()`, `stars()`, `bar()`), `player_screen.gd`, `match_screen.gd` | 45 min | Medium: no more broken glyphs and mute bars |
| 10 | **Scaling**: `stretch/mode = canvas_items`, `aspect = expand` | `project.godot` | 5 min | Medium-high on monitors ≥ 1080p |
| 11 | **New game**: no side menu, club list with color strip and two lines, club profile with KPIs, sign button at the end, load as a tab, Spanish as the default language | `new_game_screen.gd`, `main.gd` | 60 min | High for the first impression |
| 12 | **Preview in Squad** (300 px side panel that follows the selection) | `squad_screen.gd` | 45 min | High: uses the empty space and saves clicks |
| 13 | **Toasts** for the result of actions (renew, make an offer, transfer-list, save) | `main.gd` (`toast()`), screens that use `_last_msg` today | 30 min | Medium |
| 14 | **The Daily Prophet in three columns** with the editions selector in the masthead | `news_screen.gd` | 60 min | Medium (high for "flavor") |
| 15 | **Pitch in Lineup** (`Control` with `_draw()` of the oval and 7 clickable tokens; dragging later) | `lineup_screen.gd` + new `pitch_view.gd` | 2-3 h | Very high, but it does not fit in the session alongside the rest: next session |

**For a ~6-hour session: 1 to 10 (≈ 6 h)**, which mostly touch `theme_builder.gd`, `ui.gd`, and `main.gd` and therefore improve all 19 screens at once. 11-14 in the next one; 15 is a job of its own.

Verification: regenerate the six screenshots with `--autostart club_puddlemere_united --screen <id> --shot docs/screenshots/<id>.png` (already exists in `main.gd:_handle_cmdline`) and compare against the wireframes in §3.12. No panel should end more than 24 px before the bottom edge of the usable area unless its content is smaller than its minimum.

---

## 5. Art direction: what to keep and what to throw out

**Keep**

- **The "manager's office" metaphor** (`04` §6.3): wood + parchment + ink + sealing wax. It is cheap, different from every football manager (which are dark and "techy"), and faithful to the books. Text contrasts are 6 to 14:1 [C]; the problem was never the text palette.
- **IM Fell English** for H1/H2 and headlines (≥ 20 px), **Alegreya Sans with tnum** for data, **Alegreya** for prose, **Unifraktur only** in the *Daily Prophet* masthead.
- **Sealing wax as danger/irreversible** and the **seal** on confirmations.
- **The 4 px club-color strip** before every name (already requested in `04` §6.7, not yet implemented in the tables).
- **The Daily Prophet as an object** (different paper, blackletter masthead, rules). It is the only place where ornament does pay off.
- **FM 07 structure**: side menu, back/forward, Continue at the top right.

**Change**

- **Paper tones**: darker desk (`#E2D3AE`), lighter card (`#F7F1E1`); zebra and selection recalibrated (§3.3).
- **Attribute colors**: from colored text (indistinguishable, 1.05-1.11:1 between levels [C]) to a heat map in the cell background.
- **Top bar tinted entirely in the club color** → wooden bar with a two-color line and crest.
- **Panel titles in IM Fell SC 18 px bronze** → IM Fell English 20 px ink (H2) and section labels in Alegreya Sans Bold uppercase 12 px.
- **Rounded sealing-wax buttons (radius 12)** → the same radius 4 as everything else.

**Throw out**

- **The bronze rules everywhere** (paper border, panel border, Tree border, border of every column header, rule under every title). A single type of line remains: the 1 px section separator in `border`, plus the *Daily Prophet* rules.
- **The plan for 8-10 nine-patch textures** from `04` §6.11. `StyleBoxFlat` + shadow is enough, and it is what the "no hand-painted textures" constraint calls for. If an illustrator comes on board later, a very subtle paper texture (3% noise) on the *desk* and a wood-grain one are the only ones worth it.
- **Typographic glyphs as graphics** (★☆▮▯●◐○▲↗). They get drawn.
- **The bottom bar.**
- **The "vignette in the panel corner"** from `04` §6.7. With 20 cards on screen it would be noise.

---

## 6. Sources

The URLs of the web sources are next to each lesson in §2 (consulted on October 2, 2026). Local verifications from this session:

- WCAG 2 contrasts calculated with my own script on the hex values in `src/ui/theme/theme_builder.gd`, `src/ui/ui.gd`, `src/ui/main.gd`, and the proposed palette [C].
- `Tree`/`TreeItem` API verified with `godot --doctool` on Godot 4.7.2 (the version in `project.godot`) [C].
- Layout measurements on the code (`player_screen.gd`, `main.gd`) and on the screenshots in `docs/screenshots/` at 1366×800 [C].
- Phosphor Icons: MIT license, ~1,500 icons in six weights, https://github.com/phosphor-icons/homepage [F]. game-icons.net: CC BY 3.0 (`04` §6.6) [R].
