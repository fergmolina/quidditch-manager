# 04: Aesthetics: the Harry Potter video games and an art direction for Quidditch Manager

> Art-direction research. Reviews every official Harry Potter video game (plus the visual references from the books and films) with a focus on interface, typography, palette, iconography and how they portrayed Quidditch, and closes with a style proposal that **a very small team can produce** in Godot 4.

## Evidence conventions

The same as in `01-football-manager-and-pc-futbol.md`:

- **[F]** = confirmed in a source consulted during this session (numbered at the end: [F12]).
- **[R]** = my own recollection, not verified in this session. Probably correct, but it should be checked before being used as data.
- **[C]** = sources disagree; the versions are reported.
- **[I]** = my own inference or proposal.

**Limits of this research.** MobyGames (403), the Harry Potter Fandom wiki (402) and some reviews blocked automated reading. The **screenshot galleries** are listed with their URLs so they can be opened by hand, but **I could not open them**. I describe the screens from reviews and, where there is no review, from memory (marked [R]). Nobody publishes a technical breakdown of the UI of *Quidditch World Cup* (2003). About its HUD I verified a single concrete detail, the Snitch bar.

---

## Contents

1. Executive summary
2. Game-by-game profiles
   - 2.1 EA games based on the films (2001-2011)
   - 2.2 *Quidditch World Cup* (2003)
   - 2.3 *Quidditch Champions* (2024)
   - 2.4 *Hogwarts Legacy* (2023)
   - 2.5 *Hogwarts Mystery* (2018-)
   - 2.6 Other official games (Magic Awakened, Wizards Unite, Puzzles & Spells, LEGO, Wonderbook, Kinect, TCG, mobile)
3. Cross-cutting visual references: MinaLima, book covers and illustrations
4. Football Manager 2007 and PC Fútbol: what needs to be "disguised"
5. Common patterns in the visual identity of the wizarding world
6. Art-direction proposal (3 alternatives and a recommendation)
7. Practical legal notes
8. Screenshot galleries to look at
9. Sources

---

## 1. Executive summary

- **No official game ever made a "management" Quidditch.** All of them are third-person action games (QWC 2003, Quidditch Champions 2024, the film tie-in minigames) or simplified mobile minigames (Hogwarts Mystery, Magic Awakened). The only **top-down** views of Quidditch are on the handhelds (GBC *Chamber of Secrets*, DS *Half-Blood Prince*), and reviewers treated them as the weakest part of each game [F30]. **We have no direct visual reference for the 2D match viewer.** We have to design it ourselves.
- **The recurring pattern in Quidditch HUDs is always the same: it is hard to see where the Quaffle is and who belongs to which team** (the central criticism of Quidditch Champions [F8]; in the PS/CoS minigames the camera and the "speed" rings obscure everything [F22]). In the 2D viewer, legibility of balls and teams is requirement number one.
- **The visual identity people recognize from the wizarding world is MinaLima's** (The Daily Prophet, the 422 World Cup poster, programs, tickets): printed Victorian ephemera, aged paper, letterpress typography with irregularities, and "a reality shifted a few degrees" [F38]. That aesthetic is **print and paper**, which means it translates well to a flat interface of panels and text, which is exactly what a manager game is.
- **Recommendation.** "**The manager's office**": a paper-and-ink interface on a dark-wood frame with brass trim, free antique-letterpress typefaces for headings only and a humanist sans with tabular figures for tables, The Daily Prophet as the news screen, and a flat top-down 2D viewer with colored player tokens and shadows that indicate altitude. It is the cheapest of the three options I compare to produce (it all fits in a Godot `Theme` with nine-patch textures) and the one that best hides the FM 07 spreadsheet without making it less legible.

---

## 2. Game-by-game profiles

Format of each profile: facts · visual style · UI · Quidditch · what worked and what didn't · **what is useful to us**. Games with no Quidditch and no interface lessons for us get short profiles.

### 2.1 EA games based on the films (2001-2011)

Shared context [F31]: EA held the license from 2001 to 2011. Up to *Goblet of Fire* (2005) **each platform got its own game, made by a different studio**; from 2005 on they were made by EA UK / EA Bright Light. Quidditch appears as a minigame in PS, CoS and HBP; in PoA it is almost nonexistent; it disappears in OotP, DH1 and DH2.

#### Harry Potter and the Philosopher's Stone (2001; PC, Mac, PS1, GBC, GBA)

| | |
|---|---|
| **Studios** | PC: KnowWonder (Unreal Engine 1); PS1: Argonaut (*Croc* engine); GBC and GBA: Griptonite [F22][F23][F24][F25][F31] |
| **Visual style** | PC: 3D very close to the film, well-executed "spooky" lighting [F25]. PS1: 3D with jagged polygons, slowdowns [F22]. GBC: turn-based top-down RPG with "vibrant colors" [F23]. GBA: 2D/isometric with "lush backgrounds" and recognizable characters from the films [F24]. |
| **UI** | [R] Pause menu as a **book/folio** with tabs (spells, Famous Wizard cards, house points). The **Famous Wizard Cards** (Chocolate Frog cards) as collectibles with an ornate frame [F25: the review praises "the detail of the wizard cards"]. **House points** counter as an hourglass [R]. |
| **Quidditch** | PS1: Harry flies through **rings** left by the Snitch; three phases (rings alone, race against the rival Seeker, catch); there is a "Quidditch Cup" accessible from the menu [F22]. GBA: Harry flies through rings to reach the Snitch [F24]. GBC: **no Quidditch**, only side-scrolling flight: the developers said they could not do it justice on that console [F23]. |
| **Worked / didn't** | Visual fidelity and atmosphere were praised; the simple gameplay was criticized [F25]. The PS1 Quidditch suffered from camera problems and slowdown [F22]; the GBA one from a "lack of ambition" [F24]. PS1 sold 8 million [F22]. |
| **Useful to us** | The **Famous Wizard cards** as a collectible profile format (face + data + frame), which we reuse for the player profile. And the GBC decision: **better not to show a poor Quidditch than to show it badly**. |

**PS 2003 (PS2, Xbox, GC)**, by Warthog, is a console remake on a different engine [F31]. [R] Its Quidditch is a Snitch chase through rings, as in CoS. Nothing new for us.

#### Harry Potter and the Chamber of Secrets (2002; PC, Mac, PS1, PS2, Xbox, GC, GBC, GBA)

| | |
|---|---|
| **Studios** | [C] Wikipedia credits the consoles to Eurocom [F31]; another source specifies that the **PS1** version was by **Argonaut** and the PS2/Xbox/GC versions by Eurocom. Most likely both are true: Argonaut on PS1, Eurocom on the sixth generation. PC: KnowWonder [R]. |
| **Visual style** | Continuity with PS: film-style 3D, explorable Hogwarts. |
| **UI** | [R] Same as PS: folio, wizard cards, house gems. |
| **Quidditch** | Consoles: the Snitch leaves **rings of light**; flying through them increases speed and the turbo bar [F, search snippet]. PC: Gryffindor is usually 0-110 down and depends on the player catching the Snitch [F, TV Tropes snippet]. **GBC**: The Spriters Resource has a "Quidditch" sheet and a "Quidditch Field" background; the site lists "bird's-eye/isometric" and "side" views for the game, but **does not say which one Quidditch uses** [F26]. [R] I believe it is top-down, but this is not verified. |
| **Useful to us** | The GBC "Quidditch Field" background is probably **the closest thing to a pixelated top-down pitch** that exists in an official game. It is worth looking at as a reference for **what falls short** (resolution) and for how they handled the hoops seen from above. |

#### Harry Potter and the Prisoner of Azkaban (2004)

EA UK; PS2, Xbox, GC, PC, GBA [F31]. "Increasingly bright" graphics, characters modeled on the actors, and live switching between Harry, Ron and Hermione [F27]. **No playable Quidditch** [R] (the GBA version has Buckbeak flight). **Useful to us.** Little; it confirms the trend of copying the films' look.

#### Harry Potter and the Goblet of Fire (2005)

EA UK; PS2, Xbox, GC, PC, DS, GBA, PSP [F31]. Three-player co-op action. GameSpot: competent environments, small on-screen characters, and **"comic-book style" cutscenes, similar to the book covers** [F28]. [R] The Quidditch World Cup appears only as the setting of the campsite / Death Eater attack, not as a match. **Useful to us.** Proof that **book-style 2D illustration** fits in an HP game without clashing, and that it is much cheaper than 3D animation. It is a precedent for handling our narrative scenes (season launch, interviews) with still panels.

#### Harry Potter and the Order of the Phoenix (2007)

EA UK; PS2, PS3, X360, Wii, PC, Mac, DS, GBA, PSP [F31]. All of Hogwarts is explorable. **The Marauder's Map as a navigation system.** You pick a destination and footprints appear on the floor to guide you. Some called it innovative and essential; others complained that the footprints appeared late or not at all [F29]. **No Quidditch** (the film has none) [R]. **Useful to us.** **A canonical object as interface** (the map as navigator) is far more memorable than a menu. The same goes for The Daily Prophet as the news screen and a "Gringotts ledger" as the finances screen.

#### Harry Potter and the Half-Blood Prince (2009)

EA UK; PS2, PS3, X360, Wii, PC, Mac, DS, PSP [F31]. Three core minigames: dueling, potions and Quidditch. **Quidditch = flying through rings behind the Snitch**, with training dummies that give time bonuses [F30]. On **DS**, Quidditch has a **simplistic top-down view** and is played with the stylus; the review says it "would be more at home on a Game Boy Color" and that it is clumsy [F30]. **Useful to us.** It confirms that **no official game handled top-down Quidditch well**, and that a top-down view needs **altitude information** (otherwise the 3D sport flattens out and loses its meaning). See the shadow proposal in §6.

#### Harry Potter and the Deathly Hallows Part 1 (2010) and Part 2 (2011)

EA UK; PS3, X360, Wii, PC, DS [F31]. Third-person shooter [F, MobyGames via search]. Desaturated, blue-gray palette, like the films [R]. **No Quidditch.** **Useful to us.** An **anti-reference**. The gloomy "75% black" tone of the later films' marketing [F19] is the opposite of what a spreadsheet game that people look at for hours needs.

---

### 2.2 Harry Potter: Quidditch World Cup (EA, 2003): the main reference

| | |
|---|---|
| **Year / platforms** | October-November 2003; PS2, Xbox, GameCube, PC and GBA [F1] |
| **Studios** | EA UK (main versions); Magic Pockets (GBA) [F1] |
| **Teams** | 4 houses + 9 national teams: England, France, Germany, Spain, Bulgaria (unlockable, with Krum), Scandinavia/Nordic, USA, Australia, Japan [F1][F4] |
| **Commentary** | Lee Jordan with Seamus Finnigan in the Hogwarts Cup; Ludo Bagman in the international matches [F1] |
| **Reception** | 53-71% depending on platform: characters and graphics were praised; sluggish controls and shallow gameplay were criticized [F1]. 2024 retrospective review: 5/10, "fun but fleeting" [F2] |

**Visual style.** Sixth-generation 3D, saturated colors that "pop" [F2]. Each national team has **its own kit and themed stadium**; the most praised are the **Nordic team's tundra** and **Japan's** [F2][F4]. [R] The stadiums are national variations on the same layout (oval pitch, hoops at each end, stands with pennants) in very different settings: meadow, snow, desert, mountain. The player models are "copy and paste" of one another. They are distinguished only by their kit [F2].

**UI and presentation.**
- **Match HUD.** A **thin bar across the top** of the screen with **half a golden Snitch at each end**; each team fills its half with passes and goals, and when the halves meet the Snitch appears [F, Wikipedia snippet quoted in search][F1]. See the full mechanic in `02-quidditch.md` §13.1. [R] The scores sit in the top corners with each team's crest; the combo counter appears next to the player.
- **Camera.** [R] third person behind the Quaffle carrier; the Snitch hunt is a separate race sequence during which the score freezes [F, see 02 §13.1].
- **Menus.** [R] screens with wood backgrounds, crests and parchment; team selection with large flags/crests; an **album of collectible cards** that unlock moves and brooms [F1: "cards"; F3: card guides on hp-games.net]. **I could not verify** typefaces or the exact menu layout. Screenshots need to be checked.
- **Sound as interface.** The reviewer highlights the **horn when the Quaffle goes through the hoop**, the whoosh of the broom, the thud of the Bludger and the roar of the crowd [F2]. For a manager game, **the goal sound is half the feedback**.

**What worked and what didn't.**
- Worked: the atmosphere, the sound, the variety of stadiums and kits, the team-specific special moves [F2].
- Didn't work: brooms that look different but perform the same; interchangeable players with no personality [F2]; little replay value [F1][F2].

**What is useful to us.**
1. **The Snitch bar as a HUD element** (half a Snitch at each end). Although our mechanic is different (canonical 150-point Snitch), a top bar showing "momentum" or the **catch probability** is a proven, legible visual device.
2. **Stadium = club identity.** The themed stadium was the most memorable thing. For us: each club has its own viewer background (moor, coast, forest, mountain), cheap in 2D (a single background per stadium).
3. **The mistake to avoid.** QWC made the visuals promise differences (brooms, players) that the simulation did not have. In a manager game it is the opposite: **attributes have to be visible**. If a Firebolt is better, it has to show in the viewer (longer trail, acceleration).
4. **Mind the canon.** QWC invents rosters and teams (Scandinavia, Spain, Japan with video-game players). In our database those players are tagged `[VG-QWC]`, as in doc 02.

**GBA (Magic Pockets).** **Side** view, not top-down, according to The Spriters Resource [F5]. GameFAQs has 681 user screenshots of that version [F6].

---

### 2.3 Harry Potter: Quidditch Champions (Unbroken Studios / Portkey Games, 2024)

| | |
|---|---|
| **Year / platforms** | September 3, 2024 (PS4/PS5, Xbox, PC; free with PS Plus on day one); Switch on November 8, 2024 [F7] |
| **Rules** | 6 players (a single Beater); Snitch = **30 points** and does not end the match; ends on time or on reaching 100; tie → golden goal [F7] |
| **Reception** | Metacritic 63-66 [F7]; reviews from 5 to 7 out of 10; 48% drop in PSN players in the second week [F7] |
| **Venues** | The Burrow, Hogwarts pitch, Beauxbatons (floral decorations and blue pennants), Durmstrang (over a dark, icy sea, with Nordic imagery), Ilvermorny and Forbidden Forest (multiplayer only), World Cup Stadium [F12] |

**Visual style.** **Cartoonish and stylized**, unlike the realism of *Hogwarts Legacy* [F7]: "charming cartoonish versions of Harry, Hermione, Ron" [F8]; "close to realistic but with cartoon charm" [F, review snippet]. **Kits.** The house kits are **identical except for color**, with the Hogwarts crest on the chest and long, wide sleeves [F11]; the national kits are inspired by flags (Canada: red and white diagonals; Uganda: yellow, black and red with a cape and geometric motifs; Durmstrang: pieces reminiscent of armor) [F11]. [R] Balls and padded robes copied from the film designs (red Quaffle with indentations, thin-winged Snitch), numbers on the back (in `02-quidditch.md` §12: Keeper 1, Beaters 2-3, Chasers 4-6, Seeker 7).

**UI and HUD.**
- **The HUD is weak.** It does not make it easy to see where the Quaffle is, let alone tell friend from foe, and this discourages passing and teamwork [F8]. Speed rings, arrows and indicators "clutter the screen" [F, review snippet]. The camera does not keep up with the speed [F8].
- In its favor: "the interface is clean and the particles don't overwhelm" [F, review snippet].
- **I did not find** a structural description of the scoreboard or the menus. [R] Scoreboard top center with crests and clock; modern sports-game menus (dark backgrounds, house-color accents, character cards), with a season pass and cosmetics.
- Little customization: you run into players identical to you [F9].

**What is useful to us.**
1. **The most important lesson for the 2D viewer.** QC's number-one problem (you can't see the Quaffle or who belongs to which team) is our number-one requirement in reverse. The Quaffle is **always** visible and outlined; teams are distinguished by **shape + color**, not by color alone (accessibility for color-blind players).
2. **House kits identical except for color.** This is exactly the producible system we need. **A single robe template recolored per club** (two colors + emblem).
3. **Venues per institution** with two or three strong traits (flowers and blue at Beauxbatons; icy sea at Durmstrang). That is how you design a cheap, recognizable background.
4. **What not to take.** Non-canonical rules (30 points, 6 players). Already ruled out in `03-key-findings.md` A2.

---

### 2.4 Hogwarts Legacy (Avalanche Software / Portkey Games, 2023)

| | |
|---|---|
| **Year / platforms** | February 10, 2023; PS5, Xbox Series, PC; later PS4, Xbox One, Switch and Switch 2 [F14][F31] |
| **Setting** | The 1890s [R; very well-known fact] |
| **Sequel** | *Hogwarts Legacy 2* confirmed in development, tied to the HBO series [F50] |

**Visual style.** High-end realism, warm lighting. According to a design analysis, the UI draws on **medieval texts and illuminated manuscripts** "with a touch of magic" and aims to blend in with the environment; in choosing the typefaces, **legibility** was prioritized without losing consistency with the logo [F16].

**Typography.**
- According to Game Font Library (community identification, not an official source): main typeface **Columna** (URW), secondary **Ford's Folly** (Ascender), tertiary **Hybrid** (ParaType) [F14]. **[F, community identification]**.
- Logo: "HOGWARTS" is reportedly a custom version of **Tongari**, by **Pentagram** (who also made the *Fantastic Beasts* logos), and "LEGACY" is in **University Oldstyle Bold** [F15, secondary source].
- All of them are **commercial**; we cannot use them. What is useful is the **logic**: Roman lapidary capitals (Columna) for headings and a reading serif for body text.

**UI.**
- Minimal HUD: only the bottom corners [F16]. **Spell diamond** with more than 20 assignable spells [F16].
- **UX criticism.** The **3D map is not intuitive**, the icons are too small to select; in the menus it is hard to find options and understand the icons ("as if you'd been hit with a Confundus Charm") [F13]. The progressive tutorial and the clear combat iconography are praised [F13].
- **"Parchment and bronze" palette.** The original brief mentions it and it matches my recollection (dark translucent panels, gold/bronze trim, parchment in the Field Guide) [R], but **I did not find a source describing it**.
- **Brooms.** There is no shop with a catalog as such. **Spintwitches Sporting Needs** (Hogsmeade, owner Albie Weekes) unlocks upgrades through time-trial quests; the broom has **three levels** (speed, acceleration, handling) shown as **three segments** in the gear menu [F18].
- **No playable Quidditch**, only broom races [F18]. [R] The game justifies it in the story. The season is suspended.

**What is useful to us.**
1. **What goes wrong when the magical interface obscures the information:** small icons, confusing categories, cryptic terminology [F13]. Our game is 90% menus. The theming goes into the frame and the headings, **never into the data**.
2. **Broom upgrades in segments.** A good pattern for our brooms (speed / acceleration / handling in 3-5-segment bars), legible at a glance.
3. **Roman capitals for headings + a reading serif** as a type system. We replicate it with free typefaces (§6).
4. **Period.** Legacy (1890s) shows that the late-Victorian aesthetic works as "wizarding world" even though the saga takes place in the '90s. For us, the 1990s world of the books **is still printed in Victorian type** (MinaLima's Daily Prophet). There is no need to modernize.

---

### 2.5 Harry Potter: Hogwarts Mystery (Jam City, 2018-)

| | |
|---|---|
| **Year / platforms** | April 2018; iOS and Android [F31] |
| **Setting** | The 1980s; the player is a new student [F19] |
| **Art direction** | David Nakayama [F19] |

**Visual style.** **More cartoonish than realistic**, a decision driven by screen size: imitating the films' photorealism "wouldn't work on a phone" [F19]. They rejected the "75% black" tone of the films' marketing in favor of something brighter [F19]. **Simplification rule.** Repeated patterns are reduced by about **20%** (if a tapestry has five tassels in the film, in the game it has four) [F19]. '80s and punk fashion (Merula Snyde) and deliberate diversity in character design [F19].

**Quidditch.** It arrived with the **September 4, 2019** update (not 2020 as the brief says), the biggest since launch [F20]. It unlocks in Year 2, Chapter 6; there are **practice friendlies**, specialization by position (Chaser, Beater, Keeper, Seeker) and moves with canonical names that are learned over seasons (e.g. **Parkin's Pincer**, a Quaffle pass) [F20]. Rewards: brooms, kits and **face paint in house colors** [F20]. [R] The match is presented as a sequence of decisions/taps over illustrations with energy bars, not as a sport simulated in real time. `02-quidditch.md` has `[VG-HM]` players (the re-founding of the Banchory Bangers, Ethan and Skye Parkin, etc.).

**What is useful to us.**
1. **The 20% rule.** Simplify ornaments for the screen. For a dense UI, **50%** is better: a single rule line, a single corner vignette.
2. **Moves with canonical names as unlockable content.** For us: named plays (Parkin's Pincer, Wronski Feint, Porskoff Ploy) as **tactical instructions** with their own icon.
3. **Remove the darkness of the films' marketing** from screens used for long stretches.

---

### 2.6 Other official games

#### Harry Potter: Magic Awakened (NetEase / Zen Studio, 2021; PC 2023)
- **Style.** The most distinctive of all the HP games: **an illustrated book come to life**, gothic-whimsical, "cozy-spooky", with comparisons to Tim Burton and *Coraline* [F21]. Very high production quality (art, voices, narrative) [F21].
- **UI.** Collectible card game (gacha): the cards carry a lot of visual weight [R].
- **Quidditch.** Matches with a **tap-to-dodge** mechanic and a **race** mode [F21]. It introduced league players such as Marvin Pringle (Appleby) and Zola Farrell (Harpies) `[VG-MA]` (see 02 §7.1).
- **Shutdown.** WB shut it down in the Americas, Europe and Oceania in October 2024 [F51].
- **Useful to us.** The **illustrated book** aesthetic is the one that best sets an HP game apart. But it requires top-tier illustrators. It is alternative B in §6, and I rule it out on cost.

#### Harry Potter: Wizards Unite (Niantic / WB Games SF, 2019-2022)
- *Pokémon Go*-style augmented reality. "Foundables" are recovered by **tracing a spell** and filed in the **Registry**, organized into themed categories (Magical Creatures, Dark Arts, Hogwarts School, Ministry, **Magical Games and Sports**…) [F33]. Shut down in January 2022 [F52].
- **Useful to us.** The **Registry** as a collection/archive metaphor. It is a precedent for our "archive of the Department of Magical Games and Sports" (club history, records, hall of fame).

#### Harry Potter: Puzzles & Spells (Zynga, 2020)
- Match-3 with Chocolate Frogs, winged keys and wizard chess pieces as obstacles [F34]. Colorful, generic mobile UI [R]. **No relevant Quidditch** [R]. **Useful to us.** Nothing in particular.

#### LEGO Creator: Harry Potter (2001) and LEGO Creator: Chamber of Secrets (2002)
- PC building games [F31]. **Useful to us.** Nothing.

#### LEGO Harry Potter: Years 1-4 (2010) and Years 5-7 (2011)
- Traveller's Tales. Central hub at Hogwarts, six levels per film, spell lessons [F32]. **Quidditch.** The level "A Jinxed Broom" (Year 1) includes Quidditch, and the World Cup appears as a level [F32]. Physical humor with no dialogue (in 1-4) [R].
- **Useful to us.** **Legibility by silhouette** (characters recognizable by hair, scarf and color with very few pixels). This is exactly the problem of our top-down tokens.

#### LEGO Dimensions (2015-2017)
- *Fantastic Beasts* and Harry Potter packs [F31]. **Useful to us.** Nothing.

#### Wonderbook: Book of Spells (2012) and Book of Potions (2013)
- London Studio / Sony; PS3 with PlayStation Move and augmented reality on a physical book; based on Miranda Goshawk's *Book of Spells* [F36]. "Whimsical" style, like "a textbook straight out of the stories"; Metacritic 72 [F36].
- **Useful to us.** **A canonical textbook as interface**. A direct precedent for presenting the rules, glossary and tutorial as pages of *Quidditch Through the Ages* (with our own design, not that of the real edition).

#### Harry Potter for Kinect (2012)
- Eurocom / WB; a collection of minigames based on scenes from the films; Metascore 54 [F37]. [R] Includes a ring-based Quidditch minigame. **Useful to us.** Nothing.

#### Harry Potter Trading Card Game (Wizards of the Coast, 2001-2002)
- Released in August 2001; the **Quidditch Cup** expansion (November 2001) added the Quidditch lesson type and **Match** cards [F35]. Illustrations by various artists **based on the descriptions in the books, not on the films** [F35].
- **Useful to us.** Two things. (1) **An official precedent for per-type iconography** (each lesson type with its own icon and frame color). It is the model for our position icons (Keeper, Chaser, Beater, Seeker). (2) **Art based on the books rather than the films**, which is our fidelity rule. Gallery: tcdb [F35].

#### EA and other mobile phone games
- *Find Scabbers* (2005), *Mastering Magic* (2007), Java phone versions of OotP, HBP, DH1 and DH2 (EA Romania, Gameloft Chengdu) [F31]. **Useful to us.** Nothing.

#### "Harry Potter: Spells" (iOS)
- **Not verified.** It does not appear in the Wikipedia list [F31]. [R] It may have been a minor promotional app. I do not include it as a reference.

#### Outside video games
- *Harry Potter: Defenders of Hogwarts* is a recent **board game** [F, search snippet]; not applicable.
- The **HBO series** (2026-2027) will refresh the "official" look of the characters [F50]. Another reason **not to use actors' faces** (see §7).

---

## 3. Cross-cutting visual references

### 3.1 MinaLima (Miraphora Mina and Eduardo Lima)

- **What they did.** All the graphic design for the eight films and for *Fantastic Beasts*: The Daily Prophet, The Quibbler, the Marauder's Map, the World Cup posters, the Honeydukes and Weasleys' Wizard Wheezes packaging [F38].
- **The World Cup (*Goblet of Fire*).** They designed **hundreds of programs, tickets and souvenirs**, most of them destroyed on screen [F38], and the **poster for the 422nd World Cup** (Bulgaria-Ireland final) [F39]. They sell reproductions in their shop: the World Cup poster, the campsite map, Daily Prophet front pages such as "Bulgaria vs Ireland" and "Terror at the Quidditch World Cup" [F39].
- **Method.** **Drawers full of scanned period ephemera**, because the originals "have little nuances and irregularities" that a digital typeface lacks. The guiding principle is to **take a reality and shift it a few degrees** toward the magical [F38].
- **The Daily Prophet evolves with the plot.** Whimsical at first and propagandistic once the Ministry falls, influenced by **1920s Russian Constructivism** [F38].
- **Visual traits** [R, from the known pieces]: headlines in **condensed capitals**, a mix of many type families in a single piece (like Victorian posters), **rules and borders**, aged paper, black ink with **a single accent color** (red, green, gold), framed moving photographs, tight columns with drop caps.
- **MinaLima illustrated editions** of books 1-3 (2018-), with color illustration on almost every page and eight interactive paper elements (such as the fold-out Hogwarts letter) [F43].

**What is useful to us.** It is **the visual language our interface comes from**. The grammar (rules, borders, condensed capitals, one accent color on paper, a mix of families in headings) can be **rebuilt with free typefaces**. The concrete pieces (Daily Prophet layouts, the World Cup poster) **are not copied** (§7).

### 3.2 Book covers and illustrations

- **Mary GrandPré** (Scholastic covers and chapter vignettes, USA): pastels on paper, by hand, no computer, in a style she calls **"soft geometry"** (straight lines, sharp angles and curves); colorful and whimsical at first, and darker, with charcoal, from book 3 onward [F42].
- **Jim Kay** (Bloomsbury illustrated editions since 2015): expressive pencil and watercolor on almost every page; in the Quidditch chapter, the Snitch bears the Old English inscription "MEC HEHT WYRCAN" ("ordered me to be made"), a nod to Bowman Wright [F41].
- **Emily Gravett** (*Quidditch Through the Ages*, illustrated edition, Bloomsbury, October 1, 2020): two-time winner of the Kate Greenaway Medal. She **made real objects** (a broom, silk badges, ceramics) and **photographed them** for the illustrations; it has two large fold-outs; the cover is **gold on teal** with colorful Quidditch accessories [F40].
- [R] GrandPré's **chapter vignettes** (small black-and-white drawings at the start of each chapter) are, of the entire graphic universe of the books, the closest thing to an **icon system**.

**What is useful to us.** Gravett is the **most canonical** reference for Quidditch (she illustrates Whisp's book, which is our primary source), and her idea of **"club memorabilia"** (badges, scarves, programs) is exactly what a manager game needs to give identity to 13 clubs. But her technique (handmade, photographed objects) **is not producible** by us. We take the concept (each club with its badge, scarf and program) and execute it in flat vector.

---

## 4. Football Manager 2007 and PC Fútbol: what needs to be "disguised"

The details are in `01-football-manager-and-pc-futbol.md` §2.10, §2bis and §3.12. What matters for the art:

- **FM 07** [F, doc 01] has a **spreadsheet/dashboard** aesthetic: tables with filters and configurable columns, profiles with 1-20 attributes **colored by range** (configurable in an XML file) or as a chart, **browser-style navigation** (back/forward) and a **default skin with the club's colors in the top bar** and a toolbar at the bottom. Immersion comes from the inbox, the press and the stories, **not from the visual environment**.
- **PC Fútbol** [F, doc 01] has menus by area (Manager, Finances, Stadium, Scouting, Market, Staff); the "office" as a metaphor **was not verified**.
- Takeaway for us [I]:
  1. **What stays untouched:** density, sortable tables, the 1-20 scale, the "Continue" button, the inbox, back/forward. That is the game.
  2. **What gets disguised:** the frame (top bar, sidebar, backgrounds), the headings, the icons, the treatment of news, the crests and kits, the 2D viewer.
  3. **The bridge.** In FM 07 the only variable part of the skin was **the club color** in the top bar. We do the same: **a fixed parchment theme + the two colors of the manager's club** in the top frame and the accents.

---

## 5. Common patterns in the visual identity of the wizarding world

What recurs across the games, films and books (synthesis [I] of the above):

| Pattern | Where it appears | Use in our UI |
|---|---|---|
| **Parchment / aged paper** | MinaLima (everything), Legacy's Field Guide [R], Wonderbook [F36], QWC menus [R] | Background of **content panels** (tables, profiles). Flat color with a very subtle texture; **never** stains or burnt edges behind text |
| **Dark wood** | Offices and classrooms in the films; menus of QWC and the early games [R] | Application **frame**: top bar, sidebar, background behind the panels |
| **Bronze / brass / gold** | Legacy's trim [R], the Snitch, trophies, Gravett's cover (gold) [F40] | 1-2 px rules, panel borders, primary button, selected state. **For text on parchment, dark bronze only** (gold has no contrast: see §6.4) |
| **Wax seal** | Hogwarts letters (film and MinaLima), MinaLima Edition [F43] | **Confirmation of irreversible actions** (signing a contract, accepting a transfer) and important alerts. A single element, a single color (sealing-wax red) |
| **Victorian letterpress typography** | The Daily Prophet, posters, programs [F38][R] | Screen headings and news headings |
| **Blackletter (gothic)** | The Daily Prophet masthead [R] | **Only** the Daily Prophet masthead and perhaps trophy names |
| **Handwritten calligraphy** | Letters, signatures, Hermione's notes, the Marauder's Map | Signatures on contracts, assistant's notes. Decorative, never for data |
| **The "Harry P" (book/film logo)** | Official logos; the fan font "Harry P" imitates it [F44] | **Not used** (§7) |
| **Victorian / art nouveau ornament** | MinaLima borders, wizard card frames [R] | Vignettes in **the corners of large panels** and on ceremony screens (end of season, trophies). Never in table rows |
| **The four house colors** | Every game; house kits in QC = a single recolored template [F11] | Youth academies / schools; the same two-color system as the clubs |
| **Colors of the 13 clubs (QTTA ch. 7)** | `02-quidditch.md` §7.1 | See table in §6.4 |
| **Canonical object as interface** | Marauder's Map (OotP) [F29], Book of Spells (Wonderbook) [F36], Registry (Wizards Unite) [F33] | The Daily Prophet = news; QTTA = rules and glossary; Gringotts ledger = finances; Department registry = history |

---

## 6. Art-direction proposal

### 6.1 Starting constraints

- A very small team, with no full-time dedicated illustrator [assumption from the brief].
- Godot 4: the interface is built with **`Theme`** (nine-patch `StyleBoxTexture` for panels, `StyleBoxFlat` for rows and buttons, type variations per component) and with `Tree`/`ItemList`/`GridContainer` for tables [R, Godot 4 API]. The 2D viewer, with `Node2D` and sprites.
- Godot 4 applies OpenType features per font through **`FontVariation.opentype_features`** (e.g. `{"tnum": 1, "lnum": 1}`) [R, Godot 4 API]. This makes it possible to use **tabular figures** in tables, and dense tables do not work without them.
- Priority: **legibility of 30-40-row tables at 13-14 px** above any ornament.

### 6.2 Three alternatives

#### A. "The manager's office": paper, ink and The Daily Prophet (MinaLima style)
The screen is the manager's desk: a dark-wood frame, light parchment panels with bronze trim, headings in 17th-19th-century letterpress typefaces, news in The Daily Prophet, contracts with a wax seal. The manager's club color tints the top bar (as in FM 07).

#### B. "The illustrated book": *Quidditch Through the Ages* à la Gravett / Magic Awakened
Everything inside a book: hand-illustrated pages, photographed or painted club memorabilia, an illustration on every screen, chapter vignettes as icons.

#### C. "The stadium": Omnioculars and the World Cup (*Quidditch World Cup* style)
A sports-broadcast interface: stadium boards, illuminated scoreboards, the Omnioculars view as the match viewer, pennants, saturated colors.

#### Comparison

| Criterion | A. Office (MinaLima) | B. Illustrated book (Gravett) | C. Stadium (QWC) |
|---|---|---|---|
| **Production cost** | **Low**: one `Theme`, 6-8 nine-patch textures, 3 free typefaces, ~60 line icons | **Very high**: illustration per screen, per club and per event; Gravett's technique (photographed real objects) is simply unfeasible [F40] | Medium: few assets, but the viewer needs a lot of "shine" (lights, crowds, effects) so as not to look cheap |
| **Legibility of dense tables** | High: dark ink on light paper (11-13:1 contrast, §6.4) | Low: the text competes with the illustration | Medium: dark themes with neon are tiring over long sessions |
| **Fidelity to the world of the books** | High: The Daily Prophet, parchment, quills and owls are the canonical means of communication | Very high (Whisp is the source) | Medium: Omnioculars are canon (GoF), but an illuminated scoreboard feels more like a Muggle stadium |
| **How much it disguises the FM spreadsheet** | A lot: a table on paper with rules "is" a Daily Prophet listing | A lot, at the expense of legibility | Little: a stadium board is still a spreadsheet |
| **Scales to 13 clubs + national teams** | Trivially: two colors + a vector emblem per club | Expensive: an illustration per club | Easily |
| **Risk of looking like a "copy" of official material** | Medium: we must avoid tracing MinaLima's layouts (§7) | Medium | Low |

### 6.3 Recommendation: A ("The manager's office"), with two borrowings from C

**A** for all of the management side. From **C** we take two things, on match day only: the **top Snitch bar** (QWC) and the **pre-match screen as a match program** (MinaLima designed programs for the World Cup [F38], so it also counts as A). From **B** we take only the **concept** of club memorabilia (badge + scarf + colors), executed in flat vector.

### 6.4 Palette

The hex values are **[I]**. The canon gives color names, not values. Contrasts are calculated with the WCAG 2 formula.

**Interface base**

| Token | Hex | Use | Contrast |
|---|---|---|---|
| `wood` | `#2B1D14` | Application background, sidebars | |
| `wood_mid` | `#3D2A1E` | Hover on wood, separators | |
| `parchment` | `#EFE4C8` | Panel and table background | |
| `parchment_alt` | `#E4D5B0` | Alternating rows, table headers | |
| `ink` | `#2A1E14` | Main text | 12.8:1 on parchment; 11.2:1 on alt |
| `ink_soft` | `#5C4A36` | Secondary text, labels | 6.7:1 / 5.8:1 |
| `bronze_dark` | `#6E4E1E` | Rules, accent text on paper | 6.0:1 / 5.2:1 |
| `bronze` | `#8A6428` | Rules and borders (**not** small text: 4.2:1) | |
| `brass` | `#C9A14A` | Text and rules **on wood**; selection | 6.7:1 on wood |
| `snitch_gold` | `#D4AF37` | The Snitch, trophies, primary button **on wood** | 7.8:1 on wood; **1.7:1 on parchment → never on paper** |
| `sealing_wax` | `#8E1F1C` | Alerts, negatives, confirmation seal | 7.0:1 / 6.1:1 |
| `ink_green` | `#2F5A2A` | Positives, increases | ≥5:1 on both papers [I, adjusted from #3F6B3A, which gave 4.3:1 on alt] |
| `ink_blue` | `#2E4A6B` | Links (clickable player and club names) | 7.2:1 / 6.3:1 |

**1-20 attributes (on parchment):** 1-5 `sealing_wax`, 6-10 `ink_soft`, 11-15 `ink_green`, 16-20 `bronze_dark` **in bold** with a small star. Color is never the only channel (the number is always readable) [I].

**British and Irish Quidditch League clubs** (color names from QTTA ch. 7, see `02-quidditch.md` §7.1; hex [I])

| Club | Color 1 | Color 2 | Emblem (canon) |
|---|---|---|---|
| Appleby Arrows | pale blue `#8FB3D9` | silver `#BFC5CB` | silver arrow |
| Ballycastle Bats | black `#1B1B1B` | scarlet `#C8102E` | scarlet bat |
| Caerphilly Catapults | light green `#7CC36B` | scarlet `#C8102E` | **vertical** stripes |
| Chudley Cannons | orange `#F07F13` | black `#1B1B1B` | cannonball and double C |
| Falmouth Falcons | dark gray `#4A4F55` | white `#F4F4F0` | falcon head |
| Holyhead Harpies | dark green `#1F4D2B` | gold `#D4A017` | golden talon |
| Kenmare Kestrels | emerald `#009B4D` | yellow `#F5D21F` | two back-to-back Ks |
| Montrose Magpies | white `#F4F4F0` | black `#1B1B1B` | magpie (chest and back) |
| Pride of Portree | purple `#4B1F6F` | gold `#E3B505` | golden star |
| Puddlemere United | navy blue `#1B2A4A` | gold `#C9A227` | two crossed golden bulrushes |
| Tutshill Tornados | sky blue `#8ECFF0` | dark blue `#1F3A6E` | dark-blue double T |
| Wigtown Wanderers | blood red `#7A0A0A` | silver `#BFC5CB` | meat cleaver |
| Wimbourne Wasps | yellow `#F2C200` | black `#1B1B1B` | **horizontal** stripes, wasp |

**Hogwarts houses** (book canon [R, very well known]): Gryffindor scarlet `#7F0909` and gold `#D3A625`; Slytherin green `#1A472A` and silver `#AAAAAA`; Ravenclaw **blue and bronze** (books; the films use blue and silver) `#0E1A40` / `#946B2D`; Hufflepuff yellow `#ECB939` and black `#1B1B1B`.

**Color clashes in the viewer [I].** Bats-Wasps-Magpies-Cannons share black, Harpies-Kestrels share green and Arrows-Tornados share sky blue. An **"away robes" rule** is needed: if the color distance between the two teams is low, the away team uses its color 2 as primary and the viewer adds a **shape pattern** to the tokens (stripe, double ring). The canon says nothing about alternate robes, so this is **[FILLER]**.

### 6.5 Typography (all free, OFL)

| Role | Family | Why | Where |
|---|---|---|---|
| **Headings and headlines** | **IM Fell English** / **IM Fell English SC** (and DW Pica for variety) | Revivals of John Fell's types (17th c.), with the letterpress irregularity MinaLima aims for; OFL, on Google Fonts [F46] | Screen headings, club names in headers, Daily Prophet headlines. **Never in tables**: their irregularity does not read well at 11-13 px [I] |
| **Interface and tables** | **Alegreya Sans** (and **Alegreya**, the serif, for long texts) | Humanist sans with calligraphic roots (fits the world), OFL, seven weights, small caps (`smcp`) and four sets of figures, including **tabular (`tnum`) and lining (`lnum`)** [F45] | All tables, profiles, buttons, menus; Alegreya serif for news bodies, mail and reports |
| **Daily Prophet masthead** | **UnifrakturMaguntia** (or **Grenze Gotisch**, variable 100-900) | Blackletter, both OFL [F47] | **Only** the newspaper masthead and perhaps trophy names |
| *(Optional)* Handwriting | An OFL script from Google Fonts (e.g. **Pinyon Script**) [R: license to be verified] | Signatures | The manager's signature on contracts; nothing else |

Godot setup [I]: a "table" `FontVariation` based on Alegreya Sans with `opentype_features = {tnum: 1, lnum: 1}`; another "text" one with `onum` (oldstyle figures) for prose; small caps (`smcp`) for column headers.

### 6.6 Icons

- **Style.** **1.5-2 px line, ink on paper**, with the look of an engraving or a chapter vignette; flat fills only in the active state. 24 px grid (16 px in tables) [I].
- **Custom set (about 25).** Positions (Keeper = hoop; Chaser = Quaffle; Beater = bat; Seeker = Snitch), balls, brooms (by manufacturer: Nimbus, Firebolt, Cleansweep, Comet), injury (bandage), card/foul (whistle), owl (messages), The Daily Prophet (newspaper), Gringotts (Galleon), contract (parchment + wax seal), training, youth (generic Hogwarts, **not the official crest**), form/morale.
- **Generic base.** **game-icons.net** (CC BY 3.0, requires attribution) has brooms, wands, cauldrons and owls [R]; **Phosphor** or **Lucide** (MIT) for generic interface items (filters, arrows, search) [R]. Line weight needs to be made consistent.
- Inspiration: the per-lesson-type icons of the 2001 TCG [F35] and GrandPré's chapter vignettes [R].

### 6.7 What a league table looks like [I]

```
╔═ wood ════════════════════════════════════════════════════════════════════╗
║ [crest] PUDDLEMERE UNITED · top bar tinted navy blue/gold                 ║
╠═══════════════════════════════════════════════════════════════════════════╣
║ ┌─ parchment ─────────────────────────────────────────────────────────┐  ║
║ │  British and Irish Quidditch League · Season 1994-95  (IM Fell)     │  ║
║ │ ───────────────────────── bronze rule ───────────────────────────── │  ║
║ │  POS  CLUB                  P    W   L   POINTS  SNITCH  FORM      │  ║ ← small caps
║ │   1   ▌Ballycastle Bats     12   9   3     820     8/12  ●●○●●    │  ║ ← parchment
║ │   2   ▌Puddlemere United    12   8   4     790     7/12  ●●●○●    │  ║ ← parchment_alt
║ │  ...                                                                │  ║
║ │  13   ▌Falmouth Falcons     12   2  10     360     3/12  ○○●○○    │  ║
║ └─────────────────────────────────────────────────────────────────────┘  ║
╚══════════════════════════════════════════════════════════════════════════╝
```

- A **4 px vertical stripe** with the club's two colors before the name. It gives identity without large crests.
- **POINTS** (points scored, the canonical criterion; see 03 A3) in bold with tabular figures; the "Snitch" column (catches) is specific to Quidditch.
- The manager's club row: `parchment` background with a 2 px **left border in `brass`**.
- No borders in the table. Ornament is limited to a vignette in the panel corner.
- A "Daily Prophet-style" variant (points only, no P or W/L, as in the real tables [F, 02 §7.2]) for the newspaper's sports section.

### 6.8 What a player profile looks like [I]

Inspired by the **Famous Wizard cards** (frame + portrait + data) [F25], but **with our own design**:

- **Left (card, ~260 px).** Portrait in an oval frame with the club colors; name in IM Fell English SC; position with its icon; age, nationality, broom (with manufacturer icon), number. Below, an **Alegreya italic caption** with the nickname or a press line ("*Hit a Bludger 3 feet from Krum's head*").
- **Portraits.** **Silhouettes or simple portraits generated from layers** (face, hair, skin, accessories) in flat vector. **Never actors' faces** (§7). Minimum option: a silhouette in the club robes with initials.
- **Center.** 1-20 attributes in three columns (Flying / Technique / Mental, plus Physical; the names are defined by the GDD), numbers in tabular figures colored as per §6.4; ▲▼ progress arrows in `ink_green` / `sealing_wax`.
- **Right.** Status (morale, form, injury with a bandage icon), contract (with a mini wax seal if "signed"), season-by-season history.
- **Broom with segments** (speed / acceleration / handling in 5 segments), in the style of Hogwarts Legacy [F18].

### 6.9 The top-down 2D viewer [I]

**Problem to solve** (learned from HBP DS [F30] and from QC [F8]). Quidditch is 3D. Seen from above, **altitude is lost**, and with it the hoops (at 50 feet), the difference between the Seeker up high and the Chasers below, and the Wronski Feint.

**Producible solutions:**
1. **Altitude = token-shadow separation + scale.** Each player is a token with an **elliptical shadow on the ground**. The higher they fly, the farther the token separates from the shadow (offset down and to the right), the bigger the token looks and the fainter the shadow. A dive (Wronski Feint) reads as the token falling onto its shadow.
2. **Player tokens.** An 18-22 px circle in the **club's two colors** (outer ring color 1, center color 2), a **number** in Alegreya Sans Bold, and a **short broom line** showing direction (with bristles at the tail). The **shape** changes by position: Keeper = circle with a double ring, Beater = with the bat drawn on, Seeker = with a golden glint on the edge. That way team and position are distinguished **without relying on color alone**.
3. **Balls** (book canon, not film canon):
   - **Quaffle.** A **red** leather sphere (no indentations, which come from the film [F, 02 §12]), 10-12 px, **always with a light outline** and its own shadow. **It is never lost from view** (the number-one criticism of QC).
   - **Bludgers.** Two **black iron** spheres with a metallic gray rim and a short, jittery trail (they move "with ill intent").
   - **Snitch.** A 4-5 px golden dot with two little flickering wing strokes; it leaves a brief **golden trail** when a Seeker spots it. Almost always out of view; an **edge-of-screen indicator** appears only when a Seeker detects it.
4. **Pitch.** An oval of **500 × 180 feet** with the small **center circle** and the **three goal hoops at each end** (of different heights: the tallest hoop has the farthest shadow) [canon, 02]. Scoring areas marked. No halfway line as in the films [F, 02 §12].
5. **Moorland stadium.** A flat painted background per stadium: **heather** (purplish brown and olive green), stones and mist for the Scottish and northern clubs; coast and cliff for Holyhead, Falmouth, Ballycastle and Kenmare; meadows for Puddlemere; forest for Wimbourne. **Stands** as color bands on the edge of the oval with **alternating banners of the two clubs** (a Hogwarts custom [F, 02 §7.5]). **Stands, not towers.** The towers come from the film [F, 02 §12].
6. **Weather as an overlay** (rain, fog, wind, storm). A shader or particles on top of everything. Fog is canon and epic (Appleby's 16-day match, 1932).
7. **Viewer HUD.** At the top, on a **wood strip**, the two crests and the scores in IM Fell; in the center, the **game clock** and a **"Snitch probability" bar** with half a Snitch at each end (borrowed from QWC [F1]). At the bottom, the **commentary line** (Alegreya, one line) with the text narration. On the right, collapsible, the substitutions and tactics panel.
8. **Visible brooms.** The best brooms leave a longer trail and accelerate harder in replays. That way attributes and equipment **are visible** (the QWC lesson [F2]).

### 6.10 The Daily Prophet as the news screen [I]

- **A screen, not an email.** The inbox (owls) is for private messages (board, agents, players). **The Daily Prophet is the public front page**: results, transfer rumors, tables, interviews. One edition per matchday.
- **Masthead** in UnifrakturMaguntia: newspaper name, date, price in Knuts [R: the canonical price needs verifying] and issue number. Below it, a **double ink rule**.
- **3-column layout** with the main headline in **IM Fell English** (condensed capitals, 36-48 px), standfirst in Alegreya italic and body in Alegreya with a **drop cap** in the first paragraph. **A single ink (`ink`) on newsprint one shade grayer** than the parchment (`#E9E2CF` [I]) and at most one accent color per edition.
- **"Moving photos".** The photos are **2-4-frame mini-loops** (the player token celebrating, a silhouette waving) in a bordered frame. They serve both as a nod to the canon and as cheap liveliness.
- **Sections.** Sport (Quidditch), Transfers (rumors), Table (the newspaper's "points only" version), Opinion column (a fictional journalist with a slant, **not Rita Skeeter** in the lead role [I], since she is a plot character). For gossip, a secondary "magazine" in the style of *Witch Weekly* and, for the absurd, *The Quibbler*. All three publications are canon.
- **Tone.** **Do not trace** MinaLima's front pages (§7). Take the grammar (borders, mix of families, tight columns) and build our own layout.

### 6.11 Assets to produce

| Group | Assets | Approx. quantity | Difficulty |
|---|---|---|---|
| **Godot Theme** | `Theme` .tres with styles for Panel, Button (normal/hover/pressed/disabled), Tree, ItemList, TabContainer, LineEdit, ScrollBar, Tooltip, PopupMenu | 1 resource | Low (programmer) |
| **Nine-patch textures** | Parchment panel, wood frame, bronze rule, brass primary button, paper secondary button, corner vignette, wax seal (confirmation button), newsprint | 8-10 PNGs of 64-128 px | Low-medium |
| **Fonts** | IM Fell English (+SC), Alegreya, Alegreya Sans, UnifrakturMaguntia; `FontVariation` with tnum/lnum/smcp | 4 families | Trivial |
| **Icons** | Custom set + homogenized CC BY / MIT base | ~60 SVGs | Medium |
| **Club crests** | 13 league clubs + national teams + schools, **drawn by us from the canon descriptions** (arrow, bat, cannon…), in a single style (fixed shield shape, two colors, line emblem) | ~40 SVGs | Medium (the longest part of the graphics work) |
| **Robes/scarves** | 1 robe template + 1 scarf template, recolorable via shader (2 colors + pattern: plain, vertical stripes, horizontal stripes) | 2 templates + shader | Low |
| **Portraits** | Layered generator (5-8 faces, 10 hairstyles, 6 skin tones, accessories: glasses, beard) | ~40 pieces | Medium-high (or silhouette as plan B) |
| **2D viewer** | Pitch (oval, hoops, areas), tokens per position (4 shapes), shadows, Quaffle, 2 Bludgers, Snitch (3 frames), trails | ~15 sprites | Low |
| **Stadiums** | 5-6 template backgrounds (moor, coast, meadow, forest, snowy mountain, generic Hogwarts) recolored per club, + stands as bands | 6 backgrounds | Medium |
| **Weather** | Rain, fog, wind, storm (particles/shader) | 4 | Low-medium |
| **The Daily Prophet** | Layout template (Godot scene), masthead, rules, photo frames | 1 scene | Low |
| **Ceremonies** | Trophy screens (league cup, European Cup, World Cup) with one simple illustration each | 3-4 | Medium |
| **Interface sound** *(not art, but it is in QWC [F2])* | Goal horn, quill writing (confirm), owl (new message), seal (sign), page turning, crowd roar at 3 levels | ~10 | Low |

---

## 7. Practical legal notes

> I am not a lawyer. This is a practical risk guide, not legal advice.

**Three distinct categories that should not be mixed up:**

**1. Typefaces**
- **"Harry P"** (Phoenix Phonts / Graham Meade, 2000) is a **fan** font, not an official one. Its license is **contradictory depending on the site** (freeware on FontSpace; "personal use only" elsewhere) [F44]. What is decisive is something else. **It imitates the graphic mark of the WB logo**, and using it to write "Quidditch" or "Harry Potter" comes close to reproducing the trademark. **Do not use**, whatever the license. The same applies to the other fan "Harry Potter" fonts (Magic School, Parseltongue, Lumos…) [F, fontspace/1001fonts listings].
- **The actual fonts of the games** (Columna, Ford's Folly, Hybrid in Hogwarts Legacy [F14]; Tongari and University Oldstyle in its logo [F15]) are **commercial**. They cannot be redistributed inside a game without a license, not even for free.
- **Safe alternatives.** The OFL fonts in §6.5 (IM Fell, Alegreya/Alegreya Sans, UnifrakturMaguntia, Grenze Gotisch). The OFL **allows embedding and redistributing them** with the game, including the license file [F45][F46][F47].

**2. Trademarks and protected works (do not reproduce)**
- **WB / Wizarding World / Portkey Games / Harry Potter logos**, the **Hogwarts crest** and the house crests **in their film designs**.
- **MinaLima designs.** Daily Prophet layouts and mastheads, the 422 World Cup poster, programs, the Marauder's Map. They are protected works (they sell them as prints [F39]). We take the **grammar** (borders, rules, mix of typefaces), **never the piece**.
- **Illustrations** by GrandPré, Jim Kay, Gravett and MinaLima, and **game art** (QWC, QC, Legacy, Magic Awakened): not as a background, not as a texture, not "as a placeholder" in a public build.
- **Actors' faces and voices** (personality rights, on top of WB's rights). The HBO series will add a new cast [F50]. Our portraits are generic.
- **Specific designs of film objects** (Quaffle with indentations, Snitch with fine engraved wings, padded robes). Besides not being book canon [F, 02 §12], **they are WB production designs**. We use the book descriptions with our own execution.
- **What we can draw.** The club crests **from the QTTA text** ("black with a scarlet bat") with our own design, because there is no official design to copy. [I] This is safer ground than the houses, but the names still belong to WB/JKR.

**3. The underlying risk**
- The pattern of WB actions I found is triggered by **commercial activity and fundraising**: fan festivals selling merchandise [F48], a crowdfunding campaign for a "themed" game that was pulled, and a Kickstarter campaign forced to change its name [F49]. A non-commercial fan game **still remains at WB's discretion**. There is no public Wizarding World "fan content" policy equivalent to those of other franchises [R: I did not find one].
- **Triggers to avoid.** Selling the game or DLC, accepting donations or Patreon tied to the game, crowdfunding, using official logos or the name "Harry Potter" in the title or icon, publishing on storefronts with monetization, and using official art or fonts.
- **Measures that lower the profile [I].** Our own title without "Harry Potter" (e.g. just *Quidditch Manager*, or something more generic); a visible "unofficial fan project, not affiliated with WB or JKR" notice; free distribution; **100% original art**; and an architecture where **canon names live in a separate data file** (the player and club database), so that, if a letter from WB ever arrived, the database could be changed without rewriting the game. **Strongly recommended**, because it is FM's practice with licenses (doc 01) and costs little to do from the start.

---

## 8. Screenshot galleries to look at

**I could not open any MobyGames gallery (403).** The IDs come from search results and should work in a browser. Appending `screenshots/` to the end of the game URL takes you to the gallery.

| Game | URL |
|---|---|
| **Quidditch World Cup (2003)** | https://www.mobygames.com/game/15500/harry-potter-quidditch-world-cup/screenshots/ |
| QWC GBA: 681 user screenshots | https://gamefaqs.gamespot.com/gba/914744-harry-potter-quidditch-world-cup |
| QWC GBA: title screens (sprites) | https://www.spriters-resource.com/game_boy_advance/harrypotterquidditchworldcup/ |
| QWC: fan resources (cards, saves, demo) | https://hp-games.net/menu-qwc-en |
| **Quidditch Champions (2024)** | https://www.mobygames.com/game/229918/harry-potter-quidditch-champions/screenshots/ |
| Philosopher's Stone PC (2001) | https://www.mobygames.com/game/5416/harry-potter-and-the-sorcerers-stone/screenshots/ |
| Philosopher's Stone consoles (2003) | https://www.mobygames.com/game/43584/harry-potter-and-the-sorcerers-stone/screenshots/ |
| Philosopher's Stone PC: system sprites (menus) | https://www.spriters-resource.com/pc_computer/harrypotterthephilosophersstone/asset/81984/ |
| Chamber of Secrets (2002) | https://www.mobygames.com/game/7726/harry-potter-and-the-chamber-of-secrets/screenshots/ |
| CoS consoles (another entry) | https://www.mobygames.com/game/142391/harry-potter-and-the-chamber-of-secrets/screenshots/ |
| **CoS GBC: Quidditch pitch** | https://www.spriters-resource.com/game_boy_gbc/harrypotterthechamberofsecrets/asset/16449/ |
| CoS GBC: all sheets | https://www.spriters-resource.com/game_boy_gbc/harrypotterthechamberofsecrets/ |
| Prisoner of Azkaban (two entries; probably one per platform) | https://www.mobygames.com/game/13733/harry-potter-and-the-prisoner-of-azkaban/screenshots/ · https://www.mobygames.com/game/23722/harry-potter-and-the-prisoner-of-azkaban/screenshots/ |
| Order of the Phoenix | https://www.mobygames.com/game/30217/harry-potter-and-the-order-of-the-phoenix/screenshots/ |
| Half-Blood Prince | https://www.mobygames.com/game/46583/harry-potter-and-the-half-blood-prince/screenshots/ |
| Deathly Hallows 1 | https://www.mobygames.com/game/51968/harry-potter-and-the-deathly-hallows-part-1/screenshots/ |
| LEGO Years 5-7 | https://www.mobygames.com/game/56489/lego-harry-potter-years-5-7/screenshots/ |
| Wonderbook: Book of Spells | https://www.mobygames.com/game/61326/wonderbook-book-of-spells/screenshots/ |
| All HP-licensed games | https://www.mobygames.com/group/931/harry-potter-licensees/ |
| Hogwarts Mystery: official gallery | https://www.harrypotterhogwartsmystery.com/gallery/ |
| Hogwarts Legacy: UI concept (Lynda Mc Donald; **I did not confirm whether it is official work or a personal concept**) | https://www.artstation.com/artwork/8ealGx · https://dribbble.com/shots/14913366-Hogwarts-Legacy-UI-Design |
| TCG Quidditch Cup (2001): card gallery | https://www.tcdb.com/Gallery.cfm/sid/91183/2001-Wizards-Harry-Potter-Quidditch-Cup-TCG |
| MinaLima: World Cup poster | https://minalima.com/product/quidditch-world-cup-poster/ |
| MinaLima: The Daily Prophet "Bulgaria vs Ireland" | https://minalima.com/product/the-daily-prophet-bulgaria-vs-ireland/ |
| MinaLima: Quidditch collection | https://minalima.com/shop-wizarding-world/shop-by-collection/quidditch/ |
| MinaLima: Daily Prophet collection | https://minalima.com/shop-wizarding-world/shop-by-collection/the-daily-prophet/ |
| Illustrated QTTA (Gravett): covers | https://www.mugglenet.com/2020/03/check-out-the-cover-of-the-new-illustrated-quidditch-through-the-ages/ |
| Jim Kay: illustration details | https://mugglenet.com/2016/01/easter-eggs-in-jim-kays-illustrations-for-harry-potter-and-the-sorcerers-stone/ |

**To watch on video** [I]: full QWC (PS2/GC) and QC matches on YouTube (search for "Quidditch World Cup full match" and "Quidditch Champions gameplay no commentary"). They show the actual HUD, the menus and the typefaces I could not verify.

---

## 9. Sources

**Quidditch World Cup**
1. Wikipedia, *Harry Potter: Quidditch World Cup*: https://en.wikipedia.org/wiki/Harry_Potter:_Quidditch_World_Cup (includes, according to a search-engine snippet, the description of the top bar with half a Snitch at each end)
2. Off The Shelf Media, "EA Caught the Snitch but Lost the Match" (2024): https://offtheshelfmedia.com/2024/09/17/ea-caught-the-snitch-but-lost-the-match-harry-potter-quidditch-world-cup-review/
3. hp-games.net, Quidditch World Cup: https://hp-games.net/menu-qwc-en
4. Harry Potter Database, QWC: https://www.harrypotterdatabase.com/video-games/harry-potter-quidditch-world-cup
5. The Spriters Resource, QWC (GBA): https://www.spriters-resource.com/game_boy_advance/harrypotterquidditchworldcup/
6. GameFAQs, QWC (GBA) (search-engine snippet: 681 screenshots): https://gamefaqs.gamespot.com/gba/914744-harry-potter-quidditch-world-cup

**Quidditch Champions**
7. Wikipedia, *Harry Potter: Quidditch Champions*: https://en.wikipedia.org/wiki/Harry_Potter:_Quidditch_Champions
8. TheSixthAxis, review: https://www.thesixthaxis.com/2024/09/12/harry-potter-quidditch-champions-review/
9. Push Square, review (PS5): https://www.pushsquare.com/reviews/ps5/harry-potter-quidditch-champions
10. Gaming Nexus, review: https://www.gamingnexus.com/Article/14093/Harry-Potter-Quidditch-Champions/
11. GameRant, best uniforms: https://gamerant.com/harry-potter-quidditch-champions-best-uniforms/
12. GameRant, non-Hogwarts school venues (search-engine snippet, plus the venue list from the Fandom wiki via search engine): https://gamerant.com/quidditch-champions-non-hogwarts-schools-venues/

**Hogwarts Legacy**
13. Antidote.gg, Hogwarts Legacy UX Review: https://antidote.gg/hogwarts-legacy-ux-review/
14. Game Font Library, Hogwarts Legacy (community identification): https://www.gamefontlibrary.com/games/hogwarts-legacy
15. Search-engine snippet about the logo (Tongari customized by Pentagram; University Oldstyle Bold), attributable to FontBolt / the DaFont forum: https://www.fontbolt.com/font/hogwarts-legacy-font/ · https://www.dafont.com/forum/read/451346/hogwarts-legacy-font
16. Muzli / Medium, "Discover the Magic Behind the UI/UX Design of Hogwarts Legacy" (search-engine snippet): https://medium.muz.li/discover-the-magic-behind-the-ui-ux-design-of-hogwarts-legacy-4611bec7ffea
17. Lynda Mc Donald, Hogwarts Legacy UI Design (ArtStation / Dribbble): https://www.artstation.com/artwork/8ealGx
18. Fextralife / PCGamesN / search-engine snippets, brooms and Spintwitches: https://hogwartslegacy.wiki.fextralife.com/Brooms · https://www.pcgamesn.com/hogwarts-legacy/broom-upgrades-best

**Hogwarts Mystery**
19. SYFY Wire, "Inside the magical '80s art of Harry Potter: Hogwarts Mystery": https://www.syfy.com/syfy-wire/inside-the-magical-80s-art-of-harry-potter-hogwarts-mystery
20. Jam City / harrypotter.com / Potterish, arrival of Quidditch (September 4, 2019): https://www.jamcity.com/quidditch-arrives-in-harry-potter-hogwarts-mystery-mobile-game-from-jam-city/ · https://potterish.com/hogwarts-mystery-quidditch-available/?lang=en

**Other games**
21. GameRefinery / Udonis, Magic Awakened (illustrated-book style; Quidditch): https://www.gamerefinery.com/harry-potter-magic-awakened-deconstruction/ · https://www.blog.udonis.co/mobile-marketing/mobile-games/harry-potter-magic-awakened
22. Wikipedia, Philosopher's Stone (PlayStation): https://en.wikipedia.org/wiki/Harry_Potter_and_the_Philosopher%27s_Stone_(PlayStation_video_game)
23. Wikipedia, Philosopher's Stone (Game Boy Color): https://en.wikipedia.org/wiki/Harry_Potter_and_the_Philosopher%27s_Stone_(Game_Boy_Color_video_game)
24. Wikipedia, Philosopher's Stone (Game Boy Advance): https://en.wikipedia.org/wiki/Harry_Potter_and_the_Philosopher's_Stone_(Game_Boy_Advance_video_game)
25. Wikipedia, Philosopher's Stone (PC) and MobyGames (search-engine snippets): https://en.wikipedia.org/wiki/Harry_Potter_and_the_Philosopher's_Stone_(PC_video_game) · https://www.mobygames.com/game/5416/harry-potter-and-the-sorcerers-stone/
26. The Spriters Resource, Chamber of Secrets (GBC): https://www.spriters-resource.com/game_boy_gbc/harrypotterthechamberofsecrets/
27. GameSpot / IMDb, Prisoner of Azkaban (search-engine snippets): https://www.gamespot.com/reviews/harry-potter-and-the-prisoner-of-azkaban-review/1900-6100652/
28. GameSpot, Goblet of Fire (search-engine snippet): https://www.gamespot.com/reviews/harry-potter-and-the-goblet-of-fire-review/1900-6140431/
29. GameSpot / bit-tech / Nintendo Life, Order of the Phoenix, Marauder's Map (search-engine snippets): https://www.gamespot.com/reviews/harry-potter-and-the-order-of-the-phoenix-review/1900-6176135/ · https://bit-tech.net/reviews/gaming/pc/harry_potter_order_of_the_phoenix_pc/2/
30. GamesRadar / Nintendo-x2 (DS), Half-Blood Prince, Quidditch (search-engine snippets): https://www.gamesradar.com/harry-potter-and-the-half-blood-prince-10/ · https://www.nintendo-x2.com/games/2122/review/22122
31. Wikipedia, *Harry Potter video games* (full table of titles, studios and platforms): https://en.wikipedia.org/wiki/Harry_Potter_video_games
32. Wikipedia, LEGO Harry Potter: Years 1-4 (search-engine snippets): https://en.wikipedia.org/wiki/Lego_Harry_Potter:_Years_1%E2%80%934
33. Game Developer, "Deconstruction: Harry Potter: Wizards Unite" and wiki (search-engine snippets): https://www.gamedeveloper.com/design/deconstruction---harry-potter-wizards-unite
34. Hollywood Reporter / Zynga, Puzzles & Spells: https://www.hollywoodreporter.com/lifestyle/arts/zynga-launches-harry-potter-puzzles-spells-game-4065266/
35. Wikipedia, Harry Potter Trading Card Game; TCDB (Quidditch Cup gallery): https://en.wikipedia.org/wiki/Harry_Potter_Trading_Card_Game · https://www.tcdb.com/Gallery.cfm/sid/91183/2001-Wizards-Harry-Potter-Quidditch-Cup-TCG
36. Wikipedia / Push Square, Book of Spells: https://en.wikipedia.org/wiki/Book_of_Spells · https://www.pushsquare.com/reviews/ps3/wonderbook_book_of_spells
37. Wikipedia / Metacritic, Harry Potter for Kinect: https://en.wikipedia.org/wiki/Harry_Potter_for_Kinect

**MinaLima and illustrators**
38. Harry Potter Fan Zone, "Meet MinaLima" (interview) and wiki snippets: https://www.harrypotterfanzone.com/exclusive-meet-minalima-part-1/
39. MinaLima, shop (World Cup poster, The Daily Prophet): https://minalima.com/product/quidditch-world-cup-poster/ · https://minalima.com/product/the-daily-prophet-bulgaria-vs-ireland/
40. Harry Potter Fan Zone / MuggleNet / Waterstones, QTTA illustrated by Emily Gravett: https://www.harrypotterfanzone.com/bloomsbury-to-publish-quidditch-through-the-ages-illustrated-edition-with-artwork-by-emily-gravett/ · https://www.waterstones.com/book/quidditch-through-the-ages-illustrated-edition/j-k-rowling/emily-gravett/9781526608123
41. Waterstones / MuggleNet, Jim Kay: https://www.waterstones.com/blog/the-illustrated-harry-potter-and-the-philosophers-stone · https://mugglenet.com/2016/01/easter-eggs-in-jim-kays-illustrations-for-harry-potter-and-the-sorcerers-stone/
42. Lerner Publishing / Today, Mary GrandPré: https://lernerbooks.com/contributors/12778 · https://www.today.com/popculture/illustrator-puts-bit-herself-potter-cover-wbna7127158
43. Scholastic, MinaLima Edition: https://shop.scholastic.com/parent-ecommerce/books/harry-potter-and-the-sorcerers-stone-minalima-edition-9781338596700.html

**Typefaces**
44. FontSpace and others, Harry P: https://www.fontspace.com/harry-p-font-f44342 · https://www.1001freefonts.com/harry-p.font
45. Huerta Tipográfica, Alegreya Sans (GitHub) / Beautiful Web Type: https://github.com/huertatipografica/Alegreya-Sans · https://www.beautifulwebtype.com/alegreya-sans/
46. Fonts In Use, IM Fell English: https://fontsinuse.com/typefaces/47227/im-fell-english
47. Fontsource / Unifraktur, UnifrakturMaguntia; Google Fonts / Omnibus-Type, Grenze Gotisch: https://unifraktur.sourceforge.net/maguntia.html · https://github.com/Omnibus-Type/Grenze-Gotisch

**Legal and context**
48. FOX 29 / CBR, WB vs. fan festivals: https://www.fox29.com/news/warner-bros-crackdown-puts-dark-mark-over-harry-potter-festivals · https://www.cbr.com/warner-bros-harry-potter-fan-festivals/
49. World IP Review, pulled crowdfunding and name change (2015): https://www.worldipreview.com/copyright/warner-bros-sees-no-magic-in-unauthorised-harry-potter-game-8016
50. NME, Hogwarts Legacy 2 confirmed: https://www.nme.com/news/gaming-news/hogwarts-legacy-2-sequel-announced-harry-potter-release-date-3962324
51. PC Gamer, Magic Awakened shutdown: https://www.pcgamer.com/games/just-over-a-year-after-it-launched-on-pc-warner-bros-is-shutting-down-harry-potter-magic-awakened/
52. Wikipedia, Wizards Unite (shut down in January 2022): https://en.wikipedia.org/wiki/Harry_Potter:_Wizards_Unite

**Internal documents**
- `docs/research/01-football-manager-and-pc-futbol.md` (FM 07 and PC Fútbol: interface)
- `docs/research/02-quidditch.md` (club and house colors, differences between books and films, QWC and QC mechanics)
- `docs/research/03-key-findings.md` (decisions on the Snitch and the league)

### What remained unverified (summary)
- Typefaces, menu layout, scoreboard and camera of **Quidditch World Cup**. I only verified the top Snitch bar. The rest is [R].
- HUD, scoreboard and menus of **Quidditch Champions**, beyond the criticism "weak HUD, you can't tell the Quaffle or the teams apart".
- **Hogwarts Legacy**'s "parchment and bronze" palette: [R]. Its fonts come from a community identification, not from Avalanche.
- Quidditch perspective in **CoS GBC**. The site lists top-down and side views without saying which.
- Studio for **CoS PS1**: [C] Argonaut vs Eurocom.
- **"Harry Potter: Spells" (iOS)**. I found no evidence that it exists as an official game.
- Whether a public Wizarding World fan content policy exists. I did not find one.
- Exact license of **Pinyon Script** and of the icon sets (game-icons.net CC BY 3.0, Phosphor/Lucide MIT): [R], verify before including them.
- No MobyGames gallery could be opened (403).
