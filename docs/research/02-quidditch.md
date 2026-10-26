# 02: Quidditch in the Harry Potter universe: complete research for the simulator

> Research document (not a design document). Goal: gather everything the canon and the extended canon say about Quidditch so the team can design the match engine rules, the team/player/broomstick database, and the game world.
> Compilation date: October 2, 2026.

---

## 0. How to read this document

### 0.1 Source tags (used throughout the report)

| Tag | Source | Canon level |
|---|---|---|
| `[PS n]`, `[CS n]`, `[PoA n]`, `[GoF n]`, `[OotP n]`, `[HBP n]`, `[DH n]` | The 7 books (n = chapter) | **Primary canon** |
| `[QTTA cN]` | *Quidditch Through the Ages* / *Quidditch a través de los tiempos* (Kennilworthy Whisp = J.K. Rowling, 2001), chapter N | **Primary canon** (main source for the rules) |
| `[PM-WC]` | "History of the Quidditch World Cup" (J.K. Rowling, Pottermore 2014 / harrypotter.com) | **Canon (JKR writings)** |
| `[PM-2014]` | 2014 World Cup reports in the *Daily Prophet* (Ginny Potter / Rita Skeeter, JKR, Pottermore 2014) | **Canon (JKR writings)** |
| `[PM-Firebolt]` | "Firebolt" (JKR, Pottermore) | **Canon (JKR writings)** |
| `[DP1..DP4]` | *Daily Prophet Newsletters* (Bloomsbury fan club, 1998-99, written by JKR) | **Secondary canon** |
| `[Cards]` | Famous Wizard cards (Chocolate Frog Cards) written by JKR for EA | **Secondary canon** |
| `[CC]` | *Harry Potter and the Cursed Child* (stage play) | Disputed canon |
| `[Film]` | Harry Potter films (WB) | Adaptation (not canon for rules) |
| `[Prop]` | Film props (MinaLima designs: newspapers, posters, trophies) | Adaptation |
| `[FB]` | *Fantastic Beasts* films and their props | Adaptation/disputed canon |
| `[VG-QWC]` | *Harry Potter: Quidditch World Cup* (EA, 2003) | **Video game** |
| `[VG-QC]` | *Harry Potter: Quidditch Champions* (Unbroken Studios / WB, 2024) | **Video game** |
| `[VG-HM]` | *Harry Potter: Hogwarts Mystery* (Jam City, 2018-) | **Video game** |
| `[VG-HL]` | *Hogwarts Legacy* (Avalanche / WB, 2023) | **Video game** |
| `[VG-MA]` | *Harry Potter: Magic Awakened* (2022-) | **Video game** |
| `[VG-film]` | Film tie-in games (EA 2001-2009) | **Video game** |
| `[TCG]` | *Harry Potter Trading Card Game* (Wizards of the Coast, 2001) | Collectible |
| `[Wiki]` | Harry Potter Wiki (Fandom) | Secondary/fan source (flagged when a fact appears **only** there) |
| `[Lexicon]` | Harry Potter Lexicon (essays and analysis) | Secondary/fan source |
| `[Inference]` | My own deduction from the data | **Not canon** |
| `[Real]` | Real-world quadball (IQA, US Quadball, MLQ) | Real world |

### 0.2 Naming conventions

- Proper names are kept in English. The official Spanish translation (Salamandra edition) is added when it is verified in the sources consulted. **Source-confirmed translations are few** (the wiki only records: *quaffle*, *bludger*, *la snitch dorada*). Those that come from my knowledge of the Salamandra edition are marked "(Salamandra, unverified in source)".
- Base terms (English = Spanish): Quaffle = **quaffle**; Bludger = **bludger**; Golden Snitch = **snitch dorada**; Keeper = **guardián**; Chaser = **cazador**; Beater = **golpeador**; Seeker = **buscador**; *Quidditch Through the Ages* = ***Quidditch a través de los tiempos***; Wronski Feint = **Amago de Wronski** (Salamandra, unverified in source); Daily Prophet = ***El Profeta***; Department of Magical Games and Sports = **Departamento de Juegos y Deportes Mágicos**.

---

## 1. Executive summary for design

1. **Substitutions.** The official 1750 rule says verbatim "*In the case of injury, no substitution of players will take place. The team will play on without the injured player*" `[QTTA c6]`. But the canon also shows: a record three-month match in which "*they had to keep bringing on substitutes so the players could get some sleep*" (Oliver Wood) `[PS 10]`; multi-day matches in 2014 with overnight breaks for sleep `[PM-2014]`; a team playing with six after a sending-off `[PM-2014]`; and a manager being asked to "substitute" a player **for the final** (between matches) `[PM-WC]`. Reserve teams exist (Puddlemere United reserve team) `[GoF 7]`, as do house substitutes (Harper, "substitute Seeker") `[HBP 14]`. Useful reading: **rotation between matches is canon; in-match replacement due to injury is forbidden; sent-off players are not replaced; relief for fatigue in multi-day matches is a canonical gray area** (see §3.6).
2. **The Snitch and balance.** 150 points and the end of the match. The canon itself already contains "patches": the World Cup limits group-stage matches to **4 hours**, decides by goals if there is no catch, and awards **2 points per win + a bonus of 1/3/5 for margins of 50/100/150** `[PM-WC]`. There are Seekers who **catch the Snitch while losing** to limit the margin (Krum 1994, Snuka 2014) or who **refuse to catch it** until their team comes back (Krum 2014). *Quidditch Champions* (2024) lowered it to **30 points, no automatic end, match decided by time or by reaching 100 points** `[VG-QC]`; real quadball uses **30 (IQA) / 35 (USQ-MLQ)** with a **20-minute "seeker floor"** `[Real]`.
3. **League format.** The British and Irish Quidditch League (1674) has **13 teams** that compete **every year** for the **League Cup** `[QTTA c7]`. The *Daily Prophet* tables rank teams by **accumulated points (multiples of 10), with no win/loss column** `[DP1, DP4]`, just like the Hogwarts Cup, which is decided by total points `[PS/PoA/HBP]`. **Draws** exist (Cannons-Catapults) `[DP]`. Matches **are not played in home stadiums** but on moors set aside by the Ministry (Bodmin Moor, Exmoor, Ilkley Moor, Yorkshire Moors, Ellis Moor), sometimes at midnight `[QTTA c5, DP]`.
4. **Durations.** From **3.5 seconds** (Plumpton, 1921) `[QTTA c7]` to **16 days** (Appleby-Vratsa, 1932) `[QTTA c7]`, **3 months** (record according to Wood) `[PS 10]`, or a Snitch that evaded capture for **6 months** on Bodmin Moor (1884, both teams gave up) `[QTTA c6]`. In the 2014 World Cup, catches happened anywhere from minute 42 to the third day; most between 1 and 2.5 hours `[PM-2014]`.
5. There are **10 named fouls** in QTTA (not 11, as the wiki says), out of **700 on record** whose full list is secret `[QTTA c6]`.
6. There are **13 named plays** in QTTA ch. 10, plus several in the books, the TCG, *Quidditch World Cup* (2003), and *Hogwarts Mystery*. All tabulated in §5.
7. Canonical economy and market data: Wilda Griffiths's transfer from Holyhead to Puddlemere for **1,000 Galleons** `[DP]`; managers who sign, sack, and substitute players (McLeod sacks Maddock for playing golf) `[DP]`; brooms from 600 to 5,000 Galleons in 1890 `[VG-HL]`.

---

## 2. Map of canon sources

| Source | What it contributes to Quidditch | Notes |
|---|---|---|
| *Philosopher's Stone* (1997) | Wood's explanation (ch. 10), first match (ch. 11), match with Snape as referee (ch. 13), Nimbus 2000, 3-month record with substitutes | "Introductory" rules base |
| *Chamber of Secrets* (1998) | Slytherin's Nimbus 2001s, rogue Bludger (Dobby), Wood's time-out, cancellation of the Cup | |
| *Prisoner of Azkaban* (1999) | Firebolt, match with dementors, foul-filled final, rule against attacking the Keeper | |
| *Goblet of Fire* (2000) | Full 1994 World Cup (ch. 5-9), Bagman, Krum, Wronski Feint, mascots, Omnioculars | The most detailed account of professional play |
| *Order of the Phoenix* (2003) | Ron as Keeper, "Weasley is Our King", Umbridge's lifetime ban, Ginny as Seeker | |
| *Half-Blood Prince* (2005) | Harry as captain, tryouts, Felix Felicis "placebo", McLaggen, Harper as substitute, Luna as commentator | |
| *Deathly Hallows* (2007) | Snitch with flesh memory, Cannons, Gorgovitch | |
| ***Quidditch Through the Ages*** (2001) | History, pitch, balls, positions, **1750 rules**, **fouls**, referees, **13 league teams**, teams of the world, **brooms**, **plays** | **Main source** |
| Pottermore / harrypotter.com (2014-2015) | History of the World Cup and its **qualification format**, full 2014 World Cup, Firebolt, Mahoutokoro, Castelobruxo | JKR writings |
| *Daily Prophet Newsletters* (1998-99) | **League tables**, fixtures, signings, sackings, riots | Official fan club |
| Famous Wizard cards | Dates and records of historical players | Written by JKR for EA |
| Films | Visual design of the pitch, balls, uniforms | Differ from the books |
| Video games | Complete invented rosters, special plays, balance mechanics | Not canon |

---

## 3. Complete rules

### 3.1 The pitch

| Element | Data | Source |
|---|---|---|
| Shape | Elongated **oval** | `[QTTA c6]` (description by Zacharias Mumps, 1398) |
| Length | **500 feet** (≈152 m) | `[QTTA c6]` |
| Width | **180 feet** (≈55 m) | `[QTTA c6]` |
| Central circle | ≈ **2 feet** in diameter (≈0.6 m); the 4 balls are released from there | `[QTTA c6]` |
| Maximum playing height | **No** height limit; leaving over the side boundaries is forbidden | `[QTTA c6, rule 1]` |
| Goals | **3 hoops** (*goal hoops*) at each end, on posts of **different heights** | `[QTTA c6]` |
| Hoop height | ≈ **50 feet** (≈15 m) in the 1994 World Cup stadium | `[GoF 8]` |
| Hoop height (other version) | "about thirty feet high" according to the wiki | `[Wiki]` (not found in the books) |
| Scoring area | Zone around the hoops; introduced before 1620 (diagram by Quintius Umfraville, *The Noble Sport of Warlocks*) | `[QTTA c6]` |
| Modern name of the area | "*scoring circle*" / "*scoring box*" | `[PM-2014]` |
| Boundary line | Officials around the perimeter make sure players and balls do not go out | `[QTTA c6]` |
| Surface | Grass "smooth as velvet" (1994 World Cup) | `[GoF 8]` |

**Historical evolution of the goal.** Trees at either end of the marsh (11th c.) → **barrels on stilts** (12th c., Goodwin Kneen's letter) → **baskets on poles** (14th c., Mumps) → smaller, higher baskets (1620) → **fixed-size hoops from February 12, 1883**, after years of cheating (a Barnton team gave its opponents tiny baskets and itself "wicker caverns"). There were riots: "*Bring Back Our Baskets!*" `[QTTA c6]`.

**Differences in the films** `[Film]`. The pitch is wider, with a larger central circle and a **halfway line**; the stands are on **tall towers**; players fly around and outside the towers (which in the books would mean leaving the boundaries) `[Wiki]`.

### 3.2 The four balls

| Ball (Spanish name) | Number | Size / material | Behavior | Who uses it | History | Source |
|---|---|---|---|---|---|---|
| **Quaffle** (quaffle) | 1 | **12 inches** (≈30 cm) in diameter, leather, seamless, **scarlet** | Inert; bewitched (**Pennifold Quaffle**) to **fall slowly** as if sinking through water; with a **Gripping Charm** (1875) so it can be held with one hand | Chasers (and Keeper) | Originally patched leather with a strap or finger holes; red since the winter of **1711** because it could not be seen in mud; Daisy Pennifold invented the slow fall shortly after | `[QTTA c6]`, `[PS 10]` |
| **Bludger** (bludger) | 2 | **10 inches** (≈25 cm), **iron**, black | Bewitched to **chase indiscriminately** and unseat players; **attack the nearest player** if no one diverts them | Beaters (with bats) | "Blooders": flying rocks → carved rocks (Mumps) → lead (16th c., too soft, dented and flew crooked) → iron | `[QTTA c6]` |
| **Golden Snitch** (snitch dorada) | 1 | Size of a **walnut**, same weight as a Golden Snidget, gold with rotational-joint **silver wings** | Bewitched to **evade capture as long as possible** and **not leave the boundaries** of the pitch; can hover | Seekers only | Invented by **Bowman Wright** (Godric's Hollow; card: 1492-1560) to replace the protected Snidget | `[QTTA c4, c6]`, `[Cards]` |

Additional Snitch details:
- **Flesh memory.** It remembers the first person to touch it, to settle disputed catches; it is made and handled with gloves; that is why a new one is used in every match `[DH 7]`.
- It can be caught with the mouth (Harry, 1991) `[PS 11]`; it can be "stuffed up a sleeve" (Plumpton Pass) `[QTTA c10]`.
- Eunice Murray (Montrose Magpies, †1942) asked for a "**faster Snitch because this is just too easy**" `[QTTA c7]`.
- Ginny comments that Snitches can vary in speed or "wear out" `[Wiki]` (not found).
- Spectators are considered to feel "cheated" if the Snitch is caught in the first five minutes `[QTTA c10]`.

**Films** `[Film]`. The Quaffle has **four indentations** (it is not a perfect sphere); the Bludgers are **small** and dark brown (in the book they measure 10" against the Quaffle's 12"); the theme park Snitch has a bird's foot engraved on it (a nod to the Snidget) `[Wiki]`.

**Bats.** Beaters use bats (formerly "clubs") **magically reinforced** (since the 15th c.) `[QTTA c6]`. Briefly lending the bat to a non-Beater is not a foul `[Wiki]`; McLaggen takes Peakes's bat and fractures Harry's skull `[HBP 19]`.

### 3.3 The seven positions

| Position (Spanish name) | No. | Role | What they can / cannot do | Physical profile | Source |
|---|---|---|---|---|---|
| **Keeper** (guardián) | 1 | Defends the 3 hoops | Must block **in front of** the hoop (Flacking if they put part of their body through the hoop from behind). Since 1620 advised to stay in the scoring area, but **may leave it** to intimidate or head off Chasers. In Mumps's time (1398) could roam the pitch and **score** ("a matter for the Keeper's conscience"). **Cannot be attacked with Bludgers unless the Quaffle is inside the scoring area**. Restarts play after a goal against | Burly, more protective gear (helmet, chest guard) | `[QTTA c6]`, `[PoA 15]`, `[PM-2014]` |
| **Chaser** (cazador) | 3 | Pass the Quaffle and score (10 pts) | **Oldest position** ("Catchers" in the 12th c.). Since **1884** only **the Chaser carrying the Quaffle** may enter the scoring area: if more than one enters, **the goal is disallowed** (anti-*stooging* rule). Must throw the Quaffle (not carry it through the hoop: Haversacking). May not tamper with the Quaffle | Fast and agile | `[QTTA c6]`, `[PS 10]` |
| **Beater** (golpeador) | 2 | Divert Bludgers away from teammates and hit them toward opponents | **Never** score or touch the Quaffle (there is no record of them doing so). May not hit Bludgers at the crowd (Bumphing). Need strength and balance to let go with both hands | Strong; historically more wizards than witches (exceptions: Gwenog Jones) | `[QTTA c6]` |
| **Seeker** (buscador) | 1 | Catch the Snitch (150 pts, end of match) | Only player allowed to touch the Snitch (Snitchnip for anyone else). Originated in 1269 as the "**Hunter**" | The **lightest and fastest**, good eyesight, fly one-handed or no-handed; the **most fouled and the ones who suffer the worst injuries** ("*Take out the Seeker*", the first rule of *The Beaters' Bible*) | `[QTTA c4, c6]`, `[PS 10]` |
| **Captain** (capitán) | 1 of the 7 | Additional role | Calls **time-outs** and can **agree to end the match** with the opposing captain; at Hogwarts organizes tryouts and training, silver badge, prefects' bathroom | | `[QTTA c6]`, `[HBP]` |

Position data useful for attributes:
- In the team photo, the Seeker sits in the center of the front row `[DH 10]` `[Wiki]`.
- The Keeper wears more protection: helmet, shoulder/chest pads, knee pads `[Wiki]`.
- Standard equipment: helmet, goggles, shin, knee, and arm guards, gloves; uniform = robes/cloak + jersey with colors and emblem `[Wiki]` (partly from `[PS 11]`).

### 3.4 Scoring and end of the match

| Rule | Detail | Source |
|---|---|---|
| Goal | **10 points** for putting the Quaffle through any of the three hoops | `[PS 10]`, `[QTTA c6]` |
| Snitch | **150 points** to the team whose Seeker catches it (in memory of Barberus Bragge's 150 Galleons in 1269; QTTA estimates this was equivalent to "over a million Galleons today") | `[QTTA c4]` |
| End | The match ends **only** when the Snitch is caught **or by mutual consent of both captains** | `[QTTA c6, rule 7]` |
| Winner | The team with **the most points** at the end, not the one that catches the Snitch. You can lose while catching it (Krum, 1994: Ireland 170, Bulgaria 160) | `[GoF 8]` |
| Draw | No tiebreak rule in the canon; **however, draws are on record**: Chudley Cannons-Caerphilly Catapults (ending a 16-match losing streak) `[DP]`; Patonga Proudsticks-Montrose Magpies (1986) `[QTTA c8]` | Mixed |
| No periods | No halves or quarters: indefinite duration | `[PS 10]` |
| Start | The referee carries the 4 balls to the central circle; the 14 players around it; the Bludgers and Snitch are released, **the referee throws the Quaffle into the air**, and everyone kicks off at the whistle ("*Mount your brooms, please*") | `[QTTA c6]`, `[PS 11]` |
| Restart after a goal | The **Keeper of the team that conceded** puts the Quaffle back into play | `[Wiki]`, `[VG-QWC]`, `[VG-QC]` (not explicit in the books) |
| Ends | Teams do not switch ends during the match | `[Wiki]` |
| Out of bounds | If a player crosses the boundary, **their team must surrender the Quaffle** to the opponents | `[QTTA c6, rule 1]` |

### 3.5 The official rules of the Department of Magical Games and Sports (1750)

Text of QTTA ch. 6 (faithfully summarized):

1. There is no height limit, but no player may **cross the boundary lines**. If a player does, their team must **surrender the Quaffle** to the opposing team.
2. The **captain** may call a **time out** by signaling to the referee. It is the **only time players' feet may touch the ground** during a match. The time out may be extended to **two hours** if the match has already lasted **more than twelve hours**. Failure to return to the pitch after two hours = **disqualification**.
3. The referee may award **penalties**. The Chaser taking the penalty flies **from the central circle toward the scoring area**. All players except the opposing Keeper must stay **well back**.
4. The **Quaffle may be taken** from another player's hands, but **no player may seize any part of** another player's body.
5. **In the case of injury, no substitution of players will take place. The team will play on without the injured player.**
6. **Wands** may be taken onto the pitch (a right established by the ICW in 1692), but must **never be used** against opposing players, their brooms, the referee, the balls, or the crowd. (The ban on using wands against the opponent dates from **1538**.)
7. The match ends only when the Snitch is caught or by **mutual consent of the captains**.

Later rules and amendments, or rules from other sources:

| Year | Rule | Source |
|---|---|---|
| 1362 / 1368 / 1419 | Playing within 50 miles of Muggle towns forbidden (1362), then 100 miles (1368); 1419 decree: do not play "anywhere near where there is the slightest chance that a Muggle might be watching or we'll see how well you can play while chained to a dungeon wall" | `[QTTA c5]` |
| 1538 | Using a wand against the opposing team forbidden (eliminates 90% of the 700 fouls) | `[QTTA c6]` |
| 1674 | The League is founded: the 13 best teams; the rest must disband; amateurs allowed under conditions | `[QTTA c7]` |
| 1692 | Statute of Secrecy: each Ministry responsible for sports in its territory | `[QTTA c5]` |
| 1750 | The 7 official rules | `[QTTA c6]` |
| 1849 | If a spectator casts **any spell** on a player, **that spectator's team automatically forfeits** the match, whether or not the team ordered it | `[PM-2014]` (USA vs Jamaica) |
| 1883 | Fixed-size hoops instead of baskets | `[QTTA c6]` |
| June 22, 1884 | "Stooging Penalty": only the Chaser carrying the Quaffle may enter the scoring area; if more than one enters, the goal is disallowed | `[QTTA c6]` |
| 1894 | Appleby supporters banned from firing arrows from their wands after every goal (they pierced referee Nugent Potts's nose) | `[QTTA c7]` |
| n.d. | Beaters **may not attack the Keeper unless the Quaffle is in the scoring area** (Lee Jordan shouts this during the 1993-94 final; in 2014 a Bludger hit on the Keeper while the Quaffle was at the other end "gave Brazil a penalty") | `[PoA 15]`, `[PM-2014]` |
| n.d. | **Snitchnip** = **forfeit of the match** ("*Only the Seeker may capture the Snitch and any other player catching it will forfeit the game*", "one of the oldest rules") | `[PM-2014]` |
| 1995 | ICWQC motion to limit mascots to "herbivores, smaller than a cow and nothing that breathes fire": **rejected** | `[PM-2014]` |
| 2014 | The ICWQC bans "**managerial trash talk**" (insults between managers) | `[PM-2014]` |
| World Cup | ICWQC rulebook of **19 volumes** on magic on and off the pitch; e.g., "no dragon may be introduced into the stadium for any purpose, including mascot, coach or cup warmer" | `[PM-WC]` |

### 3.6 Substitutions and substitutes (complete evidence)

**This is the most important area for a manager game. The canon is not unanimous.** All the evidence:

| # | Evidence | What it implies | Source |
|---|---|---|---|
| 1 | Rule 5 of 1750: "*In the case of injury, no substitution of players will take place. The team will play on without the injured player.*" | **No in-match substitutions for injury**; the team continues short-handed | `[QTTA c6]` (primary canon) |
| 2 | Oliver Wood: "*I think the record is three months, they had to keep bringing on substitutes so the players could get some sleep*" | In matches of extreme length **there were rotations for fatigue** | `[PS 10]`; repeated as an official fact on harrypotter.com ("*They had to keep bringing on subs so the players could get a bit of rest!*") |
| 3 | Liechtenstein-Chad 2014 (3 days): "*players have broken for a short sleep*"; on day 2 the players show "severe fatigue", Otmar Frick falls asleep on his broom, Chad's Seeker fails to see the Snitch above his eyebrow for 5 minutes | In the modern era, in long matches **play is paused for sleep** and **the same seven play** (no substitutes are mentioned) | `[PM-2014]` |
| 4 | USA-Brazil 2014 (semifinal, ~20 h): the match "runs through the night"; the teams greet the dawn "tired but more focused" | Continuous night play; no mention of substitutions | `[PM-2014]` |
| 5 | New Zealand loses Dennis Moon to a **sending-off** (*sent off*) in minute 106 and plays with **six** ("*the six-strong Kiwis*"); "*New Zealand's team was reduced to six after a sending-off*" | **Sent-off players are not replaced** | `[PM-2014]` |
| 6 | 1809 World Cup: Niko Nenad's teammates "tried to persuade their **manager** to **substitute him for the final**", advice that was ignored | The **manager decides the lineup between matches** | `[PM-WC]` |
| 7 | Bulgaria 2014: Krum (38) is criticized for "**taking the place of a younger player**" for "sentimental" reasons | Squad selection/call-ups | `[PM-2014]` |
| 8 | Oliver Wood signs for Puddlemere United's **reserve team** ("*signed to the Puddlemere United reserve team*") | Professional clubs have a **reserve squad** | `[GoF 7]` |
| 9 | Puddlemere signs Wilda Griffiths from Holyhead; Holyhead replaces her with Valmai Morgan, who scores 10 goals in a match; the Magpies sack Maddock and replace him with Angus Campbell (ex-Catapults) | Signings, departures, and replacements **between matches** | `[DP2-DP4]` |
| 10 | Harper, "*the Slytherin substitute Seeker*", replaces Malfoy (who fakes illness) | Hogwarts has **substitutes** for whole matches | `[HBP 14]` |
| 11 | Ginny moves from Chaser to Seeker when Harry is banned; Dean Thomas comes in as Chaser for Katie Bell (cursed); McLaggen replaces Ron (poisoned) | Match-to-match replacements decided by the captain | `[OotP 21-30]`, `[HBP 14-24]` |
| 12 | With Harry unconscious in the hospital wing, Gryffindor plays the last fixture **"a player short"** and suffers "its worst defeat in 300 years" | At Hogwarts, if the Seeker is missing and there is no reserve, the team plays with six | `[CS 7]` |
| 13 | Alicia Spinnet was a "**reserve**" in 1990-91 | Houses have reserves | `[PS 11]` `[Wiki]` |
| 14 | Malfoy claims an arm injury and Slytherin gets **the fixture order changed** (Gryffindor plays Hufflepuff first) | Injuries can **reschedule** matches | `[PoA 8-9]` |
| 15 | Ravenclaw has a "**reserve Seeker**" (Andre Egwu) and a "reserve Keeper" (Brennan Doyle) | Substitutes at Hogwarts | `[VG-HM]` |
| 16 | *Quidditch Champions*: teams of 6, the player **switches control** among their players, no substitutions | Video game | `[VG-QC]` |
| 17 | Real quadball: **unlimited substitutions at any time** from behind the keeper zone; squad of up to 21 | Real world | `[Real]` |

**Synthesis** `[Inference]`:
- Firm canon: an injured player is not replaced during the match; a sent-off player leaves the team short-handed; squads have reserves and managers/captains choose the lineup **before** each match.
- Gray area: in matches lasting days, Wood says there were rotations so players could sleep (3-month record); in 2014 play was paused for sleep with no mention of rotations. A design allowing "relief for exhaustion only after X hours" or "during overnight breaks" would have partial canonical support (Wood + rule 2, which already distinguishes the 12-hour threshold).

### 3.7 Time-outs, breaks, and interruptions

| Type | Detail | Source |
|---|---|---|
| Captain's time-out | At any time; the only moment feet may touch the ground; up to 2 h if the match exceeds 12 h; failure to return = disqualification | `[QTTA c6]` |
| Example | Wood calls a time-out in the storm (Hermione charms Harry's glasses with *Impervius*) `[PoA 9]`; Wood calls a time-out because of the rogue Bludger `[CS 10]` | Books |
| Medical attention | After the Wronski Feint on Lynch, play stops so the mediwizards can treat him `[GoF 8]`; in the 2014 semifinal play "was stopped twice" so Healers could treat six Bulgarians with head injuries `[PM-2014]` | Canon |
| Security stoppage | Norway-Ivory Coast 2014: the match was stopped **twice** while security searched the stands for the source of jinxes against Lundekvam `[PM-2014]` | Canon |
| Bumphing | Hitting a Bludger into the crowd forces **play to stop** while officials protect the spectators (used by unscrupulous Beaters to halt an attack) `[QTTA c6]` | Canon |
| Video review | In the 2014 final, referee Herman Junker **reviews Omniocular footage** (19-minute stoppage) to decide whether Santos's bat strike on Krum was a foul: "No foul!" `[PM-2014]` | Canon |
| Overnight break | Liechtenstein-Chad: "*players have broken for a short sleep*"; "*play was stopped for the evening*" `[PM-2014]` | Canon |

### 3.8 Referee, penalties, and sanctions

| Topic | Detail | Source |
|---|---|---|
| Old name | "Quijudge" | `[QTTA c6]` |
| Requirements (Britain) | Chosen by the Department; rigorous **flying tests**, a **written exam** on the rules, and tests proving they will not curse players under pressure | `[QTTA c6]` |
| Typical injury | Neck strain (watching 14 players) | `[QTTA c6]` |
| Hazards | Cyprian Youdle (1312-1357), the only referee to die during a match (curse from the crowd, the culprit was never found); referees' brooms turned into **Portkeys** (they turn up months later in the Sahara) | `[QTTA c6]`, `[Cards]` |
| Boundary officials | In professional matches, officials around the perimeter make sure players and balls do not go out | `[QTTA c6]` |
| World Cup | Referees chosen by the ICWQC | `[PM-WC]` |
| Penalty | A Chaser flies from the central circle toward the scoring area; only the Keeper may intervene. Examples: Flint blocks Harry → free shot (scored by Alicia Spinnet) `[PS 11]`; Zograf "cobs" Mullet → penalty to Ireland, then another penalty `[GoF 8]`; Snape gives Hufflepuff a penalty because George hit a Bludger at him `[PS 13]` | Canon |
| Caution | Blancheflower (USA) "*cautioned by the referee*" for trying to jump onto a teammate's broom `[PM-2014]` | Canon |
| Sending-off | Dennis Moon (NZ) "*sent off*" for deliberate collision (decision by referee Georgios Xenakis) `[PM-2014]`; Iefan Rice "arguably should have been sent off" `[PM-2014]` | Canon |
| Suspensions | The Broadmoors (Falmouth, 1958-69) racked up **14 suspensions** from the Department `[QTTA c7]`; Umbridge imposes a "**lifetime ban**" on Harry, Fred, and George `[OotP 19]` | Canon |
| Disqualification | Haiti 2014 for Snitchnip; failure to return from a time-out; spells from the crowd (1849) | `[PM-2014]`, `[QTTA c6]` |
| Known referees | Rolanda Hooch (Hogwarts), Severus Snape (one match, 1992), Hassan Mostafa (1994 final; Egyptian, "Chairwizard of the International Association of Quidditch"; distracted by the veela), Georgios Xenakis, Herman Junker (German, 2014 final), Josiah Plunkett `[DP]`, Nugent Potts (1894), Leopoldina Smethwyck (1829-1910, first British witch to referee) `[Cards]`, Cyprian Youdle; in *QWC*: Dietrich Frenzen, Cyprien Alesi, Erika Ostensen `[VG-QWC]` | Mixed |
| Referee's spell | In USA-Jamaica 2014 the referee slows the Keeper's fall with "*arresto momentum!*" `[PM-2014]` | Canon |

### 3.9 Match durations: complete dataset

| Match | Duration / minute of catch | Result | Source |
|---|---|---|---|
| Tutshill Tornados vs Caerphilly Catapults (1921) | **3.5 seconds** (British record; Plumpton Pass) | Tornados | `[QTTA c7, c10]` |
| Gryffindor's last practice before playing Ravenclaw (1994) | Harry catches the Snitch ~10 seconds after it is released | Practice | `[PoA 13]` |
| Gryffindor vs Hufflepuff (1992) | **< 5 minutes** (Hogwarts record "in living memory") | Gryffindor | `[PS 13]` |
| Bulgaria vs Norway (2014, quarterfinal) | **42'** | 170-20 | `[PM-2014]` |
| Japan vs Poland (2014) | **59'** | 350-140 | `[PM-2014]` |
| Norway vs Ivory Coast (2014) | **128'** ("just over two hours") | 340-100 | `[PM-2014]` |
| Brazil vs Wales (2014, quarterfinal) | **131'** | 460-300 | `[PM-2014]` |
| Nigeria vs Fiji (2014) | **141'** | 400-160 | `[PM-2014]` |
| USA vs Liechtenstein (2014, quarterfinal) | **148'** | 450-290 | `[PM-2014]` |
| 2014 World Cup final | **2 h 45 min** | Bulgaria 170-60 Brazil | `[PM-2014]` |
| Brazil vs Haiti (2014) | "fourth hour" | Haiti disqualified | `[PM-2014]` |
| Bulgaria vs Japan (2014, semi) | **10 hours** | 610-460 | `[PM-2014]` |
| USA vs Brazil (2014, semi) | Snitch sighted in the **20th hour**; all night | Brazil 420-310 | `[PM-2014]` |
| Liechtenstein vs Chad (2014) | **3 days** with breaks for sleep | 470-330 | `[PM-2014]` |
| Moldova vs China (2010 final) | **3 days** | 750-640 | `[PM-WC]` |
| Norway vs Ivory Coast (earlier meeting) | **5 days** | | `[PM-2014]` |
| Sweetwater All-Stars vs Quiberon Quafflepunchers (1993) | **5 days** | Sweetwater | `[QTTA c8]` |
| Canada vs Scotland (1990 final) | "five days" according to the wiki | 270-240 | `[Wiki]` (not found in PM-WC) |
| Holyhead Harpies vs Heidelberg Harriers (1953) | **7 days** ("one of the finest games ever seen") | Harpies | `[QTTA c7]` |
| Appleby Arrows vs Vratsa Vultures (1932) | **16 days**, fog and rain | Arrows | `[QTTA c7]` |
| Record according to Wood | **3 months**, with substitutes so players could sleep | | `[PS 10]` |
| Bodmin Moor (1884) | Snitch **evades capture for 6 months**; both teams give up "disgusted" with their Seekers; the Snitch is said to still be living wild on the moor (Whisp could not confirm it) | No result | `[QTTA c6]` |

Average catch times (Ludo Bagman, first two rounds of 2014) `[PM-2014]`: **Japan 61 min**, **Bulgaria 88 min**, **USA 100 min**, **Brazil 131 min** (a single catch). Whole-tournament averages before the final: **Tony Silva 10 h 44 min**, **Viktor Krum 5 h 56 min** `[PM-2014]`.

Highest Hogwarts scoreline: **570-580** (1966-67 final) `[VG-HM]`.

### 3.10 Calibration dataset: results with deduced goals

Useful for tuning the engine (goal rate, win percentage of the team that catches the Snitch). Goals are deduced by subtracting 150 from the team that caught the Snitch `[Inference]`.

| Match | Result | Snitch | Goals A-B (deduced) | Duration | Approx. rate (goals/h) | Source |
|---|---|---|---|---|---|---|
| Gryffindor-Slytherin 1991 | 170-60 | Gryffindor | 2-6 | ? | | `[PS 11]` |
| Gryffindor-Ravenclaw 1994 | 230-30 | Gryffindor | 8-3 | ? | | `[PoA 13]` |
| Gryffindor-Slytherin 1994 (Cup final) | 230-20 | Gryffindor | 8-2 | ? | | `[PoA 15]` |
| Gryffindor-Slytherin 1995 | 160-40 | Gryffindor | 1-4 | ? | | `[OotP 19]` |
| Hufflepuff-Gryffindor 1996 | 240-230 | **Gryffindor** (loses) | 24-8 | ? | | `[OotP 26]` |
| Gryffindor-Slytherin 1996 | 250-0 | Gryffindor | 10-0 | ? | | `[HBP 14]` |
| Hufflepuff-Gryffindor 1997 | 320-60 | Hufflepuff | 17-6 | ? | | `[HBP 19]` |
| Gryffindor-Ravenclaw 1997 | 450-140 | Gryffindor | 30-14 | ? | | `[HBP 24]` |
| Ireland-Bulgaria (1994 final) | 170-160 | **Bulgaria** (loses) | 17-1 | short | | `[GoF 8]` |
| Canada-Scotland (1990 final) | 270-240 | ? | | 5 days (`[Wiki]`) | | `[PM-WC]` |
| Malawi-Senegal (1998 final) | 260-180 | ? | | ? | | `[PM-WC]` |
| Egypt-Bulgaria (2002 final) | 450-300 | Egypt | 30-30 | ? | | `[PM-WC]` |
| Burkina Faso-France (2006 final) | 300-220 | ? | | ? | | `[PM-WC]` |
| Moldova-China (2010 final) | 750-640 | ? | | 3 days | | `[PM-WC]` |
| Norway-Ivory Coast 2014 | 340-100 | Norway | 19-10 | 128' | ≈13.6 | `[PM-2014]` |
| Nigeria-Fiji 2014 | 400-160 | **Fiji** (loses) | 40-1 | 141' (40 Nigerian goals in the 1st hour) | ≈17.4 | `[PM-2014]` |
| Brazil-Haiti 2014 | 100-90 (DQ) | Haitian Snitchnip | 10-9 (Brazil made ~30 attacks on goal for 10 goals) | 4th hour | ≈5 | `[PM-2014]` |
| USA-Jamaica 2014 | 240-230 | USA | 9-23 | ? | | `[PM-2014]` |
| Liechtenstein-Chad 2014 | 470-330 | Liechtenstein | 32-33 | 3 days | | `[PM-2014]` |
| Bulgaria-New Zealand 2014 | 410-170 | Bulgaria | 26-17 | ? | | `[PM-2014]` |
| Japan-Poland 2014 | 350-140 | Japan | 20-14 | 59' | ≈34.6 | `[PM-2014]` |
| Wales-Germany 2014 | 330-100 | Wales | 18-10 | ? | | `[PM-2014]` |
| Brazil-Wales 2014 | 460-300 | Brazil | 31-30 | 131' | ≈28 | `[PM-2014]` |
| Bulgaria-Norway 2014 | 170-20 | Bulgaria | 2-2 | 42' | ≈5.7 | `[PM-2014]` |
| USA-Liechtenstein 2014 | 450-290 | USA | 30-29 (Frick: 16 goals) | 148' | ≈24 | `[PM-2014]` |
| Japan-Nigeria 2014 | 270-100 | Japan | 12-10 | ? | | `[PM-2014]` |
| Brazil-USA 2014 | 420-310 | Brazil | 27-31 | ~20 h | ≈2.9 | `[PM-2014]` |
| Bulgaria-Japan 2014 | 610-460 | Bulgaria | 46-46 (Japan led by as much as +250) | 10 h | ≈9.2 | `[PM-2014]` |
| Japan-USA 2014 (3rd place) | 330-120 | Japan | 18-12 | ? | | `[PM-2014]` |
| Bulgaria-Brazil (2014 final) | 170-60 | Bulgaria | 2-6 | 2 h 45 | ≈2.9 | `[PM-2014]` |

Observations `[Inference]`:
- The team that catches the Snitch wins in the vast majority of cases. Out of 15 matches in 2014 without a disqualification, the catching team lost **only once** (Fiji, a deliberate catch to end the match). In the books, Bulgaria 1994 and Gryffindor 1996 lost while catching it.
- The goal rate varies enormously (from ≈3 to ≈35 goals/hour). Short, lopsided matches have a high rate; long matches slow down due to fatigue (consistent with the "severe fatigue" of Liechtenstein-Chad).
- Published individual statistics the game could replicate: goals per player (Frick 16, Dembélé 7 of 10, Hyppolite 8 of 9, Valmai Morgan 10 in one match), goals conceded per Keeper (Zdravko 17 and 46; Blancheflower 23 and 18; Todoroki 12), goals prevented by a Beater (Darren Floyd "at least 17"), "Quaffle drops" (Gorgovitch's record), average catch time per Seeker.

---

## 4. Fouls

### 4.1 The 700 fouls

- The Department of Magical Games and Sports has **700 fouls** on record, and **all** of them were committed during the final of the first World Cup (**1473**, Transylvania vs Flanders). The complete list **has never been published**. The Department fears that witches and wizards "*might get ideas*" `[QTTA c6]`.
- Whisp saw the documents, and **90%** are impossible as long as the ban on using wands against the opposing team (1538) is respected; of the remaining 10%, most "would not occur to even the dirtiest player", for example "*setting fire to an opponent's broom tail*", "*attacking an opponent's broom with a club*", "*attacking an opponent with an axe*" `[QTTA c6]`.
- The 1473 final saw never-before-seen fouls: **transfiguring a Chaser into a polecat**, **attempting to decapitate a Keeper with a broadsword**, and **releasing a hundred blood-sucking vampire bats** from under the Transylvanian captain's robes `[QTTA c8]`.

### 4.2 The ten common fouls in QTTA

(The QTTA OCR reads "Matching". It is **Blatching**. The wiki mentions "11 common fouls" but QTTA lists **ten**.)

| Foul | Applies to | Definition (QTTA) | Canonical examples | Known sanction | Source |
|---|---|---|---|---|---|
| **Blagging** | All | Seizing the tail of an opponent's broom to slow or hinder them | Malfoy grabs the tail of Harry's Firebolt in the 1994 final → penalty (Hooch, "furious") | Penalty | `[QTTA c6]`, `[PoA 15]` |
| **Blatching** | All | Flying with intent to collide | Dimitrov nearly unseats Moran (penalty to Ireland) `[GoF 8]`; Harper rams Harry without Hooch seeing `[HBP 14]`; Dennis Moon (sent off) `[PM-2014]` | Penalty / sending-off | `[QTTA c6]` |
| **Blurting** | All | Locking broom handles with the aim of steering an opponent off course | Smackhammer's "broom-lock" with Picquery (a teammate) in 2014 | Penalty | `[QTTA c6]`, `[PM-2014]` |
| **Bumphing** | Beaters only | Hitting a Bludger toward the crowd, forcing play to stop; cheaters use it to prevent an opposing Chaser from scoring | Erika Rath (HM) | Stoppage of play | `[QTTA c6]` |
| **Cobbing** | All | Excessive use of elbows against opponents | Zograf against Mullet → penalty to Ireland `[GoF 8]` | Penalty | `[QTTA c6]` |
| **Flacking** | Keeper only | Sticking any part of the body through the hoop to punch the Quaffle out; the Keeper must block from the front, not from behind | | Probably a valid goal `[Inference]` | `[QTTA c6]` |
| **Haversacking** | Chasers only | Hand still on the Quaffle as it goes through the hoop (it must be thrown) | | Goal disallowed `[Inference]` | `[QTTA c6]` |
| **Quaffle-pocking** | Chasers only | Tampering with the Quaffle, e.g., puncturing it so it falls faster or zigzags | | | `[QTTA c6]` |
| **Snitchnip** | All except the Seeker | Any player other than the Seeker touching or catching the Snitch | Bloncourt (Haiti) stuffs the Snitch down his underwear and displays it: **disqualification** `[PM-2014]`; an Appleby Chaser brushes it while dodging a Bludger and sparks a riot `[VG-HM]` | **Forfeit of the match** | `[QTTA c6]`, `[PM-2014]` |
| **Stooging** | Chasers only | More than one Chaser inside the scoring area. Origin: two Chasers would ram the Keeper to leave the hoop open for the third | Banned on 6-22-1884 amid protests ("*I loved stooging... Me and me dad like watching them Keepers flattened*") | **Goal disallowed** (1884) | `[QTTA c6]` |

### 4.3 Other fouls, conduct, and unlisted "fouls"

| Conduct | Detail | Source |
|---|---|---|
| **Blocking** | Deliberately getting in the way of the opposing Seeker (Flint blocks Harry → penalty) | `[PS 11]`; name from `[TCG]` |
| Grabbing an opponent's body | Forbidden by rule 4 (Montague grabs Katie Bell's head in the 1994 final → penalty) | `[QTTA c6]`, `[PoA 15]` |
| Hitting a player with the bat | Bole hits Alicia with his bat (penalty); Santos hits Krum on the head (reviewed: "no foul" because unintentional) | `[PoA 15]`, `[PM-2014]` |
| Attacking the Keeper without the Quaffle in the area | Penalty (Iefan Rice on Almeida, 2014) | `[PoA 15]`, `[PM-2014]` |
| Play after the whistle | Crabbe hits a Bludger at Harry after the final whistle; Harry and George punch Malfoy → lifetime ban (Umbridge) | `[OotP 19]` |
| Wand use / jinxes | Forbidden (1538); in 1999 the Portree and Appleby Seekers hit each other with illegal jinxes (McBride turns Cotton's head into a cabbage) | `[QTTA c6]`, `[DP3]` |
| Crowd interference | Automatic forfeit (1849) | `[PM-2014]` |
| Potions | An American Seeker disqualified in 1926 regrets using an "*unlawful elixir*" (prop) `[FB]`; using Felix Felicis in tryouts is cheating (Asuka) `[VG-HL]`; Ron "takes" Felix (placebo) and Hermione accuses him of doing something illegal `[HBP 14]` | Mixed |
| Broom tampering | The Department has "strict safety guidelines" for players' brooms `[QTTA c6]`; *The Quibbler* accuses the Tornados of "torture, blackmail and illegal broom tampering" `[OotP 10]` | Canon |
| Bewitching Bludgers | Dobby bewitches a Bludger to chase only Harry `[CS 10]`; as a student, Gwenog Jones tried to make a Bludger attack only opponents and cursed it `[VG-HM]` | Mixed |
| Manager trash talk | Banned by the ICWQC in 2014 | `[PM-2014]` |

---

## 5. Plays, tactics, and playing styles

### 5.1 Canonical plays from *Quidditch Through the Ages* (ch. 10)

| Play (EN) | Spanish name | Position | Description (QTTA) | What it counters / effect | Origin | Risk | Source |
|---|---|---|---|---|---|---|---|
| **Bludger Backbeat** | no verified official translation | Beater | A backhand stroke that sends the Bludger **backward** instead of forward | Confusing opponents; hard to execute precisely | | Low accuracy | `[QTTA c10]` |
| **Dopplebeater Defence** | no verified translation | 2 Beaters | **Both Beaters hit the same Bludger at the same time** for extra power | A more severe Bludger attack (taking down a key opponent) | | Leaves the other Bludger free `[Inference]` | `[QTTA c10]` (TCG: "Double-Beater Defence") |
| **Double Eight Loop** | no verified translation | Keeper | The Keeper **swerves around all three hoops** at high speed to block | **Penalties** (usual use) | | | `[QTTA c10]` |
| **Hawkshead Attacking Formation** | no verified translation | 3 Chasers | The Chasers fly together in an **arrowhead** toward the hoops | **Intimidates** and forces opponents to scatter | Invented by **Darren O'Hare** (Kenmare Keeper, Ireland captain) `[QTTA c7]` | | `[QTTA c10]`; Ireland uses it in 1994 `[GoF 8]` |
| **Parkin's Pincer** | no verified translation | 3 Chasers | **Two Chasers close in** on an opposing Chaser from either side while **the third flies head-on** at them | Winning the Quaffle / punishing the carrier | Founders of the Wigtown Wanderers (Walter Parkin's 7 children) | Borders on Blatching `[Inference]` | `[QTTA c10]` |
| **Plumpton Pass** | no verified translation | Seeker | A **seemingly careless swerve** that scoops the Snitch up the sleeve | Surprise catch | Roderick Plumpton, 1921 (3.5 s); critics say it was an accident | If a non-Seeker touches it = Snitchnip | `[QTTA c10]` |
| **Porskoff Ploy** | no verified translation | 2 Chasers | The Chaser with the Quaffle **flies upward**, as if breaking away to score, drawing the opponents with them, and then **throws it downward** to a waiting teammate | Beating a defense that chases the carrier | **Petrova Porskoff** (Russian Chaser); Troy uses it against Ivanova in 1994 `[GoF 8]` | Requires exact timing | `[QTTA c10]` |
| **Reverse Pass** | no verified translation | Chaser | Throwing the Quaffle **over the shoulder** to a teammate | Unexpected passes | Masters: the **Tchamba Charmers** (Togo) `[QTTA c8]`; Angelina and Katie use it `[OotP 14, 19]` | Hard to make accurate | `[QTTA c10]` |
| **Sloth Grip Roll** | no verified translation | Any | Hanging **upside down** from the broom, gripping tightly with hands and feet | **Dodging a Bludger** | Harry masters it in 1995 `[OotP 18]` | | `[QTTA c10]` |
| **Starfish and Stick** | no verified translation | Keeper | Holds the broom **horizontally** with one hand and one foot, with **all limbs outstretched** ("starfish"). "*The Starfish Without Stick should never be attempted*" | Covering the hoops | | Without the stick = fall | `[QTTA c10]` |
| **Transylvanian Tackle** | no verified translation | Any | A **fake punch aimed at the nose**; as long as there is no contact, it **is not illegal** | Distracting / startling | First used: **1473 World Cup** | Hard at speed | `[QTTA c10]` |
| **Woollongong Shimmy** | no verified translation | Chasers | **High-speed zigzag** to throw off opposing Chasers | Evading markers | Perfected by the **Woollongong Warriors** (Australia). QTTA spells it "Woollongong"; the wiki and the real town's name use "Wollongong" | | `[QTTA c10]` |
| **Wronski Feint** | **Amago de Wronski** (Salamandra, unverified in source) | Seeker | The Seeker **plunges into a dive** pretending to have seen the Snitch far below and **pulls out just before hitting the ground**, so the opponent copies them and crashes. Omnioculars classify it as a "*Dangerous Seeker Diversion*" | Disabling or injuring the opposing Seeker; buying time to look for the Snitch | **Josef Wronski** (Polish Seeker, Grodzisk Goblins) | **Very high**: Pfeffer (Germany 2014) fails to pull out in time, crashes at ~60 mph, breaks almost every bone in his body, and believes he is a budgerigar called Klaus | `[QTTA c10]`, `[GoF 8]`, `[PM-2014]` |

### 5.2 Team tactics and styles mentioned in the canon (not formal "plays")

| Tactic / style | Who | Description | Source |
|---|---|---|---|
| **Long goal** | Vratsa Vultures (Bulgaria) | Pioneers of shooting from **outside the scoring area**. In 2014: Wenzel scores from 60 yards, Jernigan from 50, Flores "from well outside the box" | `[QTTA c8]`, `[PM-2014]` |
| **Beater-marking system** | Braga Broomfleet (Portugal) | "Revolutionary" **Beater-marking** system that took them into the elite | `[QTTA c8]` |
| **Formation looping** | Sumbawanga Sunrays (Tanzania) | Formation loops that delight crowds (the wiki interprets them as looping passes between two Chasers, from `[VG-QWC]`) | `[QTTA c8]` |
| **Offensive strategies** | Bigonville Bombers (Luxembourg) | Always among the top scorers | `[QTTA c8]` |
| **Rough play** | Falmouth Falcons | "*Let us win, but if we cannot win, let us break a few heads*" | `[QTTA c7]` |
| **Speed and showmanship** | Australian and New Zealand teams | "Speed and showmanship" | `[QTTA c8]` |
| **Solid defense** | Bulgaria 1994 | "rock solid defence"; twelve straight seasons winning the Eastern European championship | `[GoF 5]`, `[Film Wizardry]` |
| **Superior Chaser attack** | Ireland 1994 | "Superb" Chasers; they crush Peru in the semis | `[GoF 5, 8]` |
| **Dominant Beaters** | Japan 2014 (Hongo and Shingo), Nigeria 2014 (Okoye and Ojukwu) | "Battle of the Beaters"; Hongo breaks the tail of the Nigerian Seeker's broom | `[PM-2014]` |
| **"Take out the Seeker"** | General doctrine | First rule of *The Beaters' Bible* (Brutus Scrimgeour): eliminate the opposing Seeker | `[QTTA c6]` |
| **Protecting the Seeker** | Bulgaria 2014 | Vulchanov deliberately puts himself in the path of a Bludger to protect Krum | `[PM-2014]` |
| **Marking the opposing Seeker** | Gryffindor 1994 | Harry sticks to Malfoy to keep him from reaching the Snitch until Gryffindor has a lead | `[PoA 15]` |
| **Not catching the Snitch until ahead** | Wood 1994 | Gryffindor must win by more than 200: Harry must not catch the Snitch until they are **more than 50 points up** | `[PoA 15]` |
| **Catching the Snitch while losing to close it out** | Krum 1994; Snuka 2014 | Catching when the team is going to lose anyway, to **reduce the margin** / end it "on his own terms". Snuka's catch (losing 400-10, with the opponent far ahead) was seen as selfish: his manager said "*I'm going to kill him*" | `[GoF 8]`, `[PM-2014]` |
| **Refusing to catch the Snitch** | Krum 2014 (semifinal) | With Japan 250 up, Krum steers Sato away from the Snitch **without catching it**; Bulgaria comes back and he catches it in the tenth hour | `[PM-2014]` |
| **Decoy flight** | Krum 2014 | Sato thinks Krum is dodging Hongo's line of sight, and Krum catches the Snitch | `[PM-2014]` |
| **Spiral Dive** | Harry 1992 | A lightning dive to catch the Snitch in under 5 minutes | `[PS 13]`; name from `[TCG]` |
| **Twirl** | Harry 1992 | Midair spin to dodge the Bludger ("*Training for the ballet, Potter?*") | `[CS 10]`; name from `[TCG]`; "Talirek Twirl" in `[VG-HM]` |
| **Beaters glued to the Seeker as defense** | Fred and George 1992 | They escort Harry against the rogue Bludger (Harry asks them to back off) | `[CS 10]` |
| **Muggle football techniques** | Alasdair Maddock (Magpies) | Kicks the Quaffle to the Seeker; it cost a match; he was sacked for playing golf | `[DP2-DP3]` |

### 5.3 Plays from the *Trading Card Game* (2001)

`[TCG]` (collectible; not canon for rules): **Blocking**, **Body Blow** (two Chasers squeeze the carrier from both sides until they drop the Quaffle), **Check** (intercepting the Quaffle right at the pass), **Power Play** (concentrating players in one zone to open a path for the carrier), **Spiral Dive**, **Twirl**, **Double-Beater Defence**.

### 5.4 Plays from *Harry Potter: Quidditch World Cup* (2003)

`[VG-QWC]` (not canon). Individual and team special moves:

| Play | Type | Description |
|---|---|---|
| **Chelmondiston Charge** | Chaser shot | Stands on the broom, jumps, and **shoves** the Quaffle toward a hoop |
| **Dionysus Dive** | Chaser shot | Stands on the broom, jumps, and **punches** the Quaffle into the hoop |
| **Finbourgh Flick** | Chaser shot | Tosses the Quaffle into the air, rolls off the broom, and **hits it with the broom** toward the hoop |
| **D'Orazio Dive** | Steal | Flies behind the opponent, leaps with a double somersault, steals the Quaffle, and lands on their own broom |
| **Sabryn Steal** | Steal | Passes beneath the opponent, jumps up on the left and steals, lands on the right |
| **Speelman Steal** | Steal | Passes beneath and kicks the opponent's broom; picks up the Quaffle |
| **Quaffle shots** | Shot types | Straight Ball, Fast Ball, Curve Ball (unpredictable curve), Knuckle Ball (spiraling), from the WB website |

Team special plays `[VG-QWC]` (all score "unstoppable" goals and lower the opponent's Snitch bar):

| Team | Play | Value | Essence |
|---|---|---|---|
| Gryffindor | **Weasley Wangler** | 10 pts; greatly lowers the opponent's bar | The two Beaters escort the Chaser by passing a Bludger between them and fire it at the Keeper |
| Ravenclaw | **Burdish of Raven** | **30 pts** (the highest in the game) | Diving V; three goals in a row, one per hoop |
| Hufflepuff | **Cedric Swoop'n'Swagger** | 20 pts | Chain of passes and two goals |
| Slytherin | **Zeeburger Slither** | 20 pts | Chasers and Beaters sweep away defenders; *cobbing* the Keeper "without a penalty" |
| England | **Rowntree Counter** | 10 pts | Dive with a Union Jack trail, bicycle-kick finish |
| United States | **Harlem Shuffle** | 20 pts | Basketball style (Harlem Globetrotters) |
| Japan | **Tsunami** | 20 pts | Martial arts, spinning kicks |
| Germany | **Barrenheim Barrage** | | Football style, header finish |
| France | **Blitzen Ballet** | 10 pts | Trapeze between brooms |
| Scandinavia | **Björn Blizzard** | 20 pts | Freezing fog that blinds opponents |
| Australia | (unnamed) | 20 pts | "Surfing" on brooms and a volleyball-style spike |
| Spain | (unnamed) | 10 pts | Dance/bullfighting; strike with the broom |
| Bulgaria | (unlockable) | | |

### 5.5 Plays from *Hogwarts Mystery*

`[VG-HM]` (not canon): **Anticipating Moves** (reading the opponent's shoulders and eyes), **Blind Spot** (tactic exploiting Erika Rath's blind spot), **Broom Drifting** (broom skids using a *Slowing Charm*), **Extreme Dive and Pull Up** (a prerequisite for the Wronski Feint), **Flick Broomstick** and **Hanging Broomstick** (Keeper: hitting with the broom / hanging and kicking), **Inspired Broom Surfing** (Chaser standing on the broom), **Power Play**, **Rebound to Chaser** (Keeper quickly returns the ball to a Chaser), **Strong Braking**, **Talirek Twirl**, **Thimblerig Shuffle** (Hawkshead → three in a line that "shuffle" like a shell game → fake Porskoff Ploy; the third Chaser, whom nobody is watching, scores), **Throw Bat to Teammate**.

---

## 6. Broomsticks (equipment)

### 6.1 History of the racing broom

- Flying brooms in Europe since **962 AD**; medieval ones made of unvarnished ash with hazel twigs, a single speed (`[QTTA c1]`).
- **1820**: Elliot Smethwyck invents the **Cushioning Charm** `[QTTA c9]`.
- Until the early 19th century: brooms handmade by individual craftsmen, attractive but slow and hard to handle at great height `[QTTA c9]`.
- **1926**: the Ollerton brothers found Cleansweep and mass production begins; from then on, brand competition `[QTTA c9]`.
- **1993**: the Firebolt leaves Nimbus behind; in 2014 elite teams use the Firebolt Supreme, Thunderbolt VII, Varápidos, Yajirushi, Starsweeper XXI `[PM-2014]`.

### 6.2 Manufacturers

| Manufacturer | Founded | Founders / base | Models | Notes | Source |
|---|---|---|---|---|---|
| **Cleansweep Broom Company** | 1926 | Bob, Bill, and Barnaby Ollerton | Cleansweep One, Two, Three, Five, Six, Seven, Eleven | First to mass-produce sports brooms; fierce rivalry with Comet | `[QTTA c9]` |
| **Comet Trading Company** | 1929 | **Randolph Keitch and Basil Horton**, Falmouth Falcons players | Comet 140, 180, 220, 260, 290 | Patent: **Horton-Keitch Braking Charm** | `[QTTA c9]` |
| **Ellerby and Spudmore** | ? | Black Forest (Germany); Ellerby and Able Spudmore | Tinderblast (1940), Swiftstick (1952) | Well made, not very popular; the son, Randolph, created the Firebolt | `[QTTA c9]`, `[PM-Firebolt]` |
| **Universal Brooms Ltd** | ?, closed in **1978** | | Shooting Star (1955) | Went bankrupt because its brooms aged badly | `[QTTA c9]` |
| **Nimbus Racing Broom Company** | **1967** | **Devlin Whitehorn** (b. 1945) | Nimbus 1000, 1001, 1500, 1700, 2000, 2001; Fambus Station Wagon (family broom) | Market leader until the Firebolt; the 2000 and 2001 outsold all other high-end brooms combined 3 to 1 | `[QTTA c9]`, `[Cards]`, `[PM-Firebolt]` |
| **Flyte and Barker** | ? | | Twigger 90 (1990) | | `[QTTA c9]` |
| **Randolph Spudmore** (designer) | | | Firebolt (1993), Firebolt Supreme (presumably) | **Goblin-made** fittings (frequent strikes → low production) | `[PM-Firebolt]` |
| **Thunderbolt** | 21st c. | Manchester, England | Thunderbolt VII (2014) | Rumor: Nigerian wizards went to its headquarters after the failure at the World Cup | `[PM-2014]` |
| Artisan makers | 19th-20th c. | Elias Grimstone (Portsmouth), Gladys Boothby, Leonard Jewkes | Oakshaft 79, Moontrimmer, Silver Arrow | Individual production: demand outstripped supply | `[QTTA c9]` |
| Brooklyn Brooms, McTawny Broomsticks (NY, 1702, "Hibernian wood") | | USA | | Newspaper ads from 1926 | `[Prop]`/`[FB]` |
| Spintwitches Sporting Needs (Hogsmeade) | | Albie Weekes (1890) | Sells brooms and the "Hogwarts House Broom" | Shop | `[VG-HL]` |

### 6.3 Model table

| Model (EN) | ES (Salamandra, unverified) | Manufacturer | Year | Speed / performance | Features | Price | Known use | Source |
|---|---|---|---|---|---|---|---|---|
| Generic medieval | | Artisan | 10th-12th c. | One speed; up, down, and stop | Unvarnished ash, hazel twigs | | | `[QTTA c1]` |
| **Oakshaft 79** | | Elias Grimstone | 1879 | Slow on corners | Thick oak handle; **endurance** and strong winds; too heavy for Quidditch; today a valuable antique | | Jocunda Sykes: **first Atlantic crossing** by broom (1935) | `[QTTA c9]` |
| **Moontrimmer** | | Gladys Boothby | 1901 | **Flies higher** than any other, controllable at height | Slender ash handle; insufficient artisan production | | Highly sought after by players | `[QTTA c9]` |
| **Silver Arrow** | | Leonard Jewkes | before 1890 / early 20th c. | **Up to 70 mph with a tailwind**; "the true forerunner of the racing broom" | Individual production | **5,000 Galleons** (1890) `[VG-HL]` | Madam Hooch learned to fly on one | `[QTTA c9]`, `[PoA 13]` |
| **Cleansweep One** | Barredora 1 | Cleansweep | 1926 | Corners "like never before" | First mass-produced racing broom | | Within a year, **every British team** | `[QTTA c9]` |
| Cleansweep Two | Barredora 2 | Cleansweep | 1934 | Improved | | | | `[QTTA c9]` |
| Cleansweep Three | Barredora 3 | Cleansweep | 1937 | Improved | | | | `[QTTA c9]` |
| Cleansweep Five | Barredora 5 | Cleansweep | 1937-1953 | | | | Gwendolyn Morgan (1953, uses it to concuss Rudolf Brand); Fred and George | `[QTTA c7]`, `[CS 7]` |
| Cleansweep Six | Barredora 6 | Cleansweep | before 1991 | | A wizard claims to have flown to the Moon on one (*The Quibbler*) | | | `[OotP]` |
| Cleansweep Seven | Barredora 7 | Cleansweep | before 1991 | | | | Most of Ravenclaw (1993-94) | `[PoA]` |
| **Cleansweep Eleven** | Barredora 11 | Cleansweep | ≤1995 | **0 to 70 mph in 10 s** | **Spanish oak** handle, **anti-jinx varnish**, built-in **vibration control** | Expensive (Molly hesitates) | Ron Weasley (Keeper) | `[OotP 9]` |
| **Comet 140** | Cometa 140 | Comet | 1929 | | First with the **Horton-Keitch Braking Charm** (fewer offsides and less overshooting the goal); 140 = number of prototypes tested | | Many British and Irish teams | `[QTTA c9]` |
| Comet 180 | Cometa 180 | Comet | 1938 | | | | | `[QTTA c9]` |
| Comet 220 | Cometa 220 | Comet | ≤1985 | | | Secondhand (Splinter and Kreek's) | Skye Parkin | `[VG-HM]`, `[DP]` |
| **Comet 260** | Cometa 260 | Comet | ≈1985 | "Flashy, but not in the same league as the Nimbus" | | | Malfoy (before 1992), Cho Chang, Tonks | `[PS 10]`, `[PoA 13]` |
| Comet 290 | Cometa 290 | Comet | ≤1995 | **0 to 60 mph** (with a decent tailwind, according to *Which Broomstick?*) | | | | `[OotP 9]` |
| **Tinderblast** | | Ellerby & Spudmore | 1940 | Slower than Cleansweep and Comet | **Very resilient** | | | `[QTTA c9]` |
| **Swiftstick** | | Ellerby & Spudmore | 1952 | Faster than the Tinderblast | **Loses power when climbing**; never used by professionals | | | `[QTTA c9]` |
| **Shooting Star** | Estrella Fugaz | Universal Brooms | 1955 | Loses **speed and height as it ages** | The **cheapest** racing broom of its day | Cheap; sold secondhand in 1999 | Hogwarts school brooms (pull to the left, vibrate at height); Ron | `[QTTA c9]`, `[PS 9]`, `[DP2]` |
| **Nimbus 1000** | Nimbus 1000 | Nimbus | 1967 | **Up to 100 mph**; **360-degree turn in midair on the spot** | "The reliability of the old Oakshaft + the easy handling of the best Cleansweeps" | | Immediately the favorite of European professional teams | `[QTTA c9]` |
| Nimbus 1001 | | Nimbus | 1967-1990 | | | | Professionals | `[QTTA c9]` |
| Nimbus 1500 | | Nimbus | 1967-1990 | | | | Professionals | `[QTTA c9]` |
| Nimbus 1700 | | Nimbus | ≤1990 | | | | Professionals | `[QTTA c9]` |
| **Twigger 90** | | Flyte and Barker | 1990 | **Warps at high speed** | Warning whistle and self-straightening brush; "for wizards with more Galleons than sense" | Expensive | | `[QTTA c9]` |
| **Nimbus 2000** | Nimbus 2000 | Nimbus | 1991 | The fastest of 1991 | Mahogany; protections against tampering | | Harry (1991-93, destroyed by the Whomping Willow); Japan 1994 `[VG-QWC]` | `[PS 9]`, `[PoA 9]` |
| **Nimbus 2001** | Nimbus 2001 | Nimbus | Aug. 1992 | Faster than the 2000 | (Film: black and silver, swiveling stirrups) | | All of Slytherin (gift from Lucius Malfoy); "most teams in the world" | `[CS 7]`, `[PM-Firebolt]` |
| **Firebolt** | **Saeta de Fuego** | Randolph Spudmore | 1993 | **0 to 150 mph in 10 s**; the fastest in the world in 1994 | Polished **ash** handle, hand-numbered `[PoA 4]` (Pottermore says ebony; the book takes precedence); **birch** twigs (more thrust on climbs) or **hazel** (hair-trigger steering); **goblin** fittings (stability, power in bad weather, non-slip footrests); **unbreakable Braking Charm**; hovers at mounting height; hand-numbered twigs | "**Price on request**" | Harry; Ireland and Bulgaria national teams (1994) | `[PoA 4]`, `[PM-Firebolt]`, `[GoF 8]` |
| **Firebolt Supreme** | | (Spudmore, presumably) | ≤2014 | 2014 elite | | | Bulgaria 2014 | `[PM-2014]` |
| **Thunderbolt VII** | | Thunderbolt (Manchester) | 2014 | Rivals the Firebolt Supreme | "Sacrificed safety for speed": a Bludger tore off its tail (professional brooms must withstand all Bludger hits) → official investigation | | Nigeria 2014 | `[PM-2014]` |
| **Varápidos** | |: (Brazil) | 2014 | Elite | | | Brazil 2014 | `[PM-2014]` |
| **Yajirushi** | |: (Japan) | 2014 | Elite; debuted at the World Cup | | | Japan 2014 | `[PM-2014]` |
| **Starsweeper XXI** | | | 2014 | Elite | | | United States 2014 | `[PM-2014]` |
| **Bluebottle** | | | ≤1994 | | "A broom for all the family – safe, reliable and with **built-in anti-burglar buzzer**" | | Family broom (advertised at the 1994 World Cup) | `[GoF 8]` |
| Fambus Station Wagon | | Nimbus | ≤1996 | | Family broom | | Advertised in the *Daily Prophet* | `[Prop]` |
| Air Wave Gold / Turbo XXX | | | 1990s | | Compared in *Seeker Weekly* (1996) | | | `[Prop]` |
| Australian Flyabout 50 | |: (Australia) | 1994 | World-class | | | Australia 1994 | `[VG-QWC]` (concept art) |
| Siberian Arrow | |: (Siberia) | 1994 | World-class | | | Nordic team 1994 | `[VG-QWC]` (concept art) |
| Transylvanian Barb | | | | | Cut from the game | | Transylvania | `[VG-QWC]` (cut) |
| 1890 brooms (Spintwitches): Wind Wisp, Ember Dash, Yew Weaver, Moon Trimmer (ash, "stable") | | | ≤1890 | | Shop descriptions | **600 Galleons** each | | `[VG-HL]` |
| Dark Lightning / Family Antique / Aeromancer / Sky Scythe | | | ≤1890 | | | **2,000 / 2,500 / 3,000 / 5,000 Galleons** | | `[VG-HL]` |
| Bright Spark, Lavender Borealis, Lickety Swift, Night Dancer, Wild Fire, Hogwarts House Broom | | | ≤1890 | | Cosmetic | | | `[VG-HL]` |
| Cavalier, Oakshaft, Stormrider (Firestorm, Typhoon), Legacy | | | | | Cosmetic | | | `[VG-QC]` |

Notes useful for modeling "equipment" `[Inference]`:
- Attributes with a canonical basis: **top speed**, **acceleration** (0-60/70/150 in 10 s), **height ceiling** (Moontrimmer), **resilience/durability** (Tinderblast, Oakshaft; Thunderbolt VII fragile), **braking** (Horton-Keitch, the Firebolt's unbreakable Braking Charm), **turning** (Nimbus 1000: 360° on the spot; Cleansweep One: cornering), **bad-weather stability** (goblin fittings), **degradation with use** (Shooting Star), **high-speed failures** (Twigger 90 warps), **loss of power when climbing** (Swiftstick), **jinx resistance** (the Cleansweep Eleven's anti-jinx varnish; the Nimbus 2000's anti-tampering protections), **scarcity** (Firebolt: production limited by goblin strikes; Moontrimmer, Silver Arrow: demand > supply).
- In *Quidditch World Cup*, difficulty is tied to brooms: Comet 260 < Nimbus 2000 < Nimbus 2001 < Firebolt `[VG-QWC]`. In *Hogwarts Legacy* brooms are upgraded at the shop (speed, boost) `[VG-HL]`.
- Maintenance gear: Broomstick Servicing Kit (Hermione's gift to Harry, `[PoA 1]`), *Fleetwood's High-Finish Handle Polish* `[PoA 1]` (from memory, unverified in source).

---

## 7. Teams

### 7.1 British and Irish Quidditch League: the 13 clubs

All data in this table is `[QTTA c7]` unless otherwise noted. "League titles" = League Cup titles.

| Team | Town / region | Founded | Colors and emblem | League titles | Other titles | Motto / identity | Rivalries | Known players and staff | Notes |
|---|---|---|---|---|---|---|---|---|---|
| **Appleby Arrows** | Appleby-in-Westmorland, Cumbria, northern England | **1612** | Pale blue with a **silver arrow** | | | Finest hour: beating European champions the **Vratsa Vultures** in **1932** in a **16-day** match played in fog and rain. Their supporters fired arrows from their wands after every goal (banned in 1894 after one pierced referee Nugent Potts's nose) | **Wimbourne Wasps** (traditional and fierce) | Gregory Cotton (S, 1999; head turned into a cabbage by McBride) `[DP3]`; Marvin Pringle (S, 2010s) `[VG-MA]` | 7th in Oct. 1999 `[DP4]` |
| **Ballycastle Bats** | Ballycastle, Northern Ireland | ? | Black with a **scarlet bat** across the chest | **27** (2nd most successful) | | Mascot **Barny the Fruitbat**, also the face of the Butterbeer ads ("*I'm just batty about Butterbeer!*") | | Finbar Quigley (1999) `[DP2]` | Leader in 1999 (760 → 820 pts) `[DP2-DP4]` |
| **Caerphilly Catapults** | Caerphilly, Wales | **1402** | **Vertical** stripes of light green and scarlet | **18** | **European Cup 1956** (vs Karasjok Kites) | Their star "Dangerous" Dai Llewellyn (eaten by a chimaera on Mykonos; a day of national mourning in wizarding Wales); Dangerous Dai Commemorative Medal | | Dai Llewellyn; Angus Campbell (former player, moves to the Magpies) `[DP]` | Lost to the Tornados in 3.5 s in 1921 |
| **Chudley Cannons** | Chudley, England | ? (founding member 1674) (film: "Est. 1753" `[Prop]`) | **Bright orange**, cannonball and black double "C" | **21** (the last in **1892**) | Josef Wronski Award 1931 `[Prop]`; played the 1972 International Quidditch Tournament `[Prop]` | Motto until 1972: "*We shall conquer*"; since 1972: "**Let's all just keep our fingers crossed and hope for the best**" | | Manager Ragmar Dorkins (faints from the shock of winning) `[DP]`; S Galvin Gudgeon (the Snitch bounced off his nose twice) `[DP]`; B Joey Jenkins `[GoF]`; C Dragomir Gorgovitch (record for "Quaffle drops" in a season) `[DH 7]`; K Gordon Horton `[Wiki]` | Ron's team; fan club; **16-match losing streak** broken by a **draw** with Caerphilly `[DP]`; JKR: they would need to "replace the entire team and get several cauldrons of Felix Felicis" |
| **Falmouth Falcons** | Falmouth, Cornwall | ? | **Dark gray and white**, falcon's head | | | Rough play. Motto: "**Let us win, but if we cannot win, let us break a few heads**" | | Beaters **Kevin and Karl Broadmoor** (1958-69, **14 suspensions**); Randolph Keitch and Basil Horton (founded Comet, 1929) `[QTTA c9]` | Last in 1999 (350 → 360) |
| **Holyhead Harpies** | Holyhead, Anglesey, Wales | **1203** (2nd oldest) | **Dark green** with a **golden talon** | | | **Signs only witches** (unique in the world). 1953 match against the Heidelberg Harriers (7 days), won with a catch by **Glynnis Griffiths**; opposing captain Rudolf Brand proposed to captain **Gwendolyn Morgan**, who concussed him with her Cleansweep Five | **Puddlemere United** (1999) `[DP]` | Gwenog Jones (B, captain; later Wales manager) `[HBP 4]`, `[PM-2014]`; Wilda Griffiths (C, transferred to Puddlemere for 1,000 G) `[DP]`; Valmai Morgan (C, 10 goals in a match) `[DP]`; **Ginny Weasley** (C, 2000s) `[JKR]`; Erika Rath (B) `[VG-HM]`; Zola Farrell (C) `[VG-MA]`; coach Jordanna Bodiment `[VG-MA]` | 9th in Oct. 1999 |
| **Kenmare Kestrels** | Kenmare, County Kerry, Ireland | **1291** | **Emerald green** with two yellow back-to-back "K"s | | | **Leprechaun** mascots; supporters who play the **harp** | | **Darren O'Hare** (K 1947-60; Ireland captain three times; inventor of the Hawkshead) | Seamus Finnigan's team `[OotP 11]`; 5th in 1999 |
| **Montrose Magpies** | Montrose, Scotland | ? | **Black and white**, one magpie on the chest and another on the back | **32** (the most successful) | **European Cup ×2** | Fans all over the world | | S **Eunice Murray** (†1942; asked for a faster Snitch); **Hamish MacFarlan** (captain 1957-68, later Head of the Department); C **Fabius Watkins** (captain, 1940-1975, dies in a collision with a helicopter) `[Cards]`; C Alasdair Maddock (sacked) `[DP]`; S Lennox Campbell `[DP]`; manager **Cormack McLeod** `[DP]` | McGonagall's team `[PM]`; draw with the Patonga Proudsticks (1986) `[QTTA c8]` |
| **Pride of Portree** | Portree, Isle of Skye | **1292** | **Deep purple** with a **golden star** | ≥2 (1960s) | | Fans: the "Prides" | | C **Catriona McCormack** (captain, 2 league titles in the 1960s, 36 caps for Scotland; cover of the 3,000th issue of *Quidditch Times*, 1964); her daughter **Meaghan McCormack** (K); her son Kirley (guitarist for The Weird Sisters); S Dougal McBride `[DP]` | 6th in 1999 |
| **Puddlemere United** | River Piddle, Dorset (no real town) | **1163** (the oldest) | **Navy blue** with two **crossed golden bulrushes** (formerly "mud brown", changed in 1998) `[DP]` | **22** | **European Cup ×2** | Anthem "**Beat Back Those Bludgers, Boys, and Chuck That Quaffle Here**" (recorded by Celestina Warbeck for St Mungo's); Dumbledore wishes them luck in the foreword to QTTA | Holyhead Harpies `[DP]` | C **Joscelind Wadcock** (b. 1911; 20th-century record for goals in a match, 1931 vs the Bats) `[Cards]`; **Oliver Wood** (reserve team, 1994) `[GoF 7]`; S Benjy Williams `[DP]`; manager **Philbert Deverill** `[DP]` | 2nd in 1999; **reserve team** |
| **Tutshill Tornados** | Tutshill (near Chepstow), western England | **1520** | **Sky blue** with a dark blue double "T" on chest and back | ≥5 (**5 in a row**, a British record, in the early 20th century with **Roderick Plumpton** as captain-Seeker) | | | | S **Roderick Plumpton** (1889-1987; 22 caps for England); captain Brevis Birch `[DP]`; K Mervyn Fenwick (narcolepsy) `[DP]` | Leaders in autumn 1995 `[OotP 12]` and in July 1998 (750) `[DP1]`; Cho Chang has supported them since she was six (Ron: "they only support them since they started winning") |
| **Wigtown Wanderers** | Wigtown, Scotland (Borders) | **1422** | **Blood red** with a silver **meat cleaver** | | | Founded by the **seven children of Walter Parkin**, a butcher, who attended with his wand in one hand and his cleaver in the other; there is almost always a Parkin on the team | | The 7 Parkins; Ethan and Skye Parkin `[VG-HM]` | Kennilworthy Whisp's team; 12th in 1999 |
| **Wimbourne Wasps** | Wimbourne (West Country), England | **1312** | **Horizontal** yellow and black stripes, wasp on the chest | **18** | European Cup semifinalists ×2 | Emblem adopted after a match (mid-17th century) in which a Beater batted a **wasps' nest** at the Appleby Seeker, who had to retire. Supporters: the "**Stingers**", who **buzz** to distract Chasers taking penalties | **Appleby Arrows** | B **Ludo Bagman** (3 league titles in a row with him) `[GoF 7]` | 10th in 1999 |

Defunct club: the **Banchory Bangers** (Scotland), famous for their poor play and their partying; after a match against Appleby in **1814** they let their Bludgers loose into the night and set off to capture a **Hebridean Black** as a mascot; they were arrested over Inverness and **disbanded** `[QTTA c5]`. (Hogwarts Mystery "refounds" them with a dragon mascot `[VG-HM]`.) Banchory's exit (1814) implies that some club joined after 1674 or that the league continued with 12 until someone took their place `[Inference]`.

Other historical British teams: Goodwin Kneen's **Yorkshire** team (12th c.; scored **42 goals** against **Ilkley**) `[QTTA c3]`; **Lancashire** vs **Cork** (1385; the Irish win with new tricks and flee the mob) `[QTTA c8]`; the amateur **Barnton** team (cheating baskets, 1883) `[QTTA c6]`.

### 7.2 League tables published in the *Daily Prophet*

**Important.** The tables show only **points** (always multiples of 10), **with no matches played, wins, or losses** `[DP]`. According to the Lexicon, although the newsletters are dated 1998-99, their internal chronology corresponds to 1992-93 `[Lexicon]`.

| Pos. | July 31, 1998 `[DP1]` | Pts | Oct. 1, 1999 `[DP4]` (sorted by points) | Pts |
|---|---|---|---|---|
| 1 | Tutshill Tornados | 750 | Ballycastle Bats | 820 |
| 2 | Montrose Magpies | 730 | Puddlemere United | 790 |
| 3 | Appleby Arrows | 660 | Montrose Magpies | 780 |
| 4 | Kenmare Kestrels | 620 | Tutshill Tornados | 770 |
| 5 | Puddlemere United | 610 | Kenmare Kestrels | 720 |
| 6 | Caerphilly Catapults | 590 | Pride of Portree | 700 |
| 7 | Ballycastle Bats | 550 | Appleby Arrows | 680 |
| 8 | Pride of Portree | 520 | Caerphilly Catapults | 650 |
| 9 | Wigtown Wanderers | 470 | Holyhead Harpies | 620 |
| 10 | Holyhead Harpies | 410 | Wimbourne Wasps | 530 |
| 11 | Falmouth Falcons | 340 | Chudley Cannons | 490 |
| 12 | Wimbourne Wasps | 290 | Wigtown Wanderers | 480 |
| 13 | Chudley Cannons | 230 | Falmouth Falcons | 360 |

Intermediate data: Feb. 8, 1999, Bats first with **760** and Cannons last with **230** `[DP2]`; June 1, 1999, Bats **800**, Falcons last with **350** `[DP3]`. (The Lexicon's version of DP4 misnumbers some positions: 7, 8, 9, 8, 10, 12, 11, 13; above it is corrected by points.)

Reading `[Inference]`: the jumps (e.g., Falcons +10 after losing to the Cannons; Cannons +260 after beating Wigtown and Falmouth) are consistent with a system of **accumulated points = sum of the points scored in each match**, just like the Hogwarts Cup. The Lexicon reaches the same conclusion ("*the scores carry over*").

Published fixtures (they show the schedule and the venues) `[DP]`:
- Saturday: Wigtown Wanderers vs Puddlemere United, **midnight**, Yorkshire Moors ("DO NOT CHEER TOO LOUDLY, Muggles came looking for the source of the noise last time").
- Monday: Falmouth Falcons vs Pride of Portree, **11:00**, Exmoor ("an **Invisibility Charm** has been placed on the new stadium; collect **re-visibility goggles** at the ticket office or you won't find the pitch").
- Friday: Tutshill vs Wigtown, Bodmin Moor. Saturday: Ballycastle vs Caerphilly, "**venue to be confirmed** (Muggles camping on Ellis Moor)". Monday: Kenmare vs Wigtown.
- Harpies vs Puddlemere at Ilkley Moor: **wands confiscated at the entrance** for fear of riots; many handed over fake wands; Wilda Griffiths vanishes midway through the match; riot; Gwenog Jones arrested; a 23-year-old fan ends up with a rat's tail.

### 7.3 Clubs from the rest of the world

| Club | Country | Data | Source |
|---|---|---|---|
| **Vratsa Vultures** | Bulgaria | **7 European Cups** (champions in 1931); pioneers of the **long goal**; "always willing to give new players a chance"; lost a 16-day match to Appleby (1932) | `[QTTA c7-c8]` |
| **Quiberon Quafflepunchers** | France | Frequent French league champions; **flamboyant** play; **shocking-pink** robes. European Cup 1922 `[Prop]`; league titles 1798, 1801, 1805, 1832, 1867, 1870, 1874, 1904, 1916, 1917, 1920, 1927, 1928, 1929 `[Prop]`; fan club on Rue Malabête (1392) `[Prop]`; lost a 5-day match to Sweetwater (1993) | `[QTTA c8]` |
| **Heidelberg Harriers** | Germany | "Fiercer than a dragon and twice as clever" (Darren O'Hare); 7 days vs the Harpies (1953); captain Rudolf Brand | `[QTTA c7-c8]` |
| **Bigonville Bombers** | Luxembourg | Offensive strategies, always among the top scorers | `[QTTA c8]` |
| **Braga Broomfleet** | Portugal | Broke into the elite with their **Beater-marking system** | `[QTTA c8]` |
| **Grodzisk Goblins** | Poland | Club of **Josef Wronski**, "the world's most innovative Seeker" | `[QTTA c8]` |
| **Karasjok Kites** | Norway | 1956 European Cup finalists | `[QTTA c7]` |
| **Gorodok Gargoyles** | Lithuania | Narrowly beat the Toyohashi Tengu in 1994 | `[QTTA c8]` |
| **Moutohora Macaws** | New Zealand | Red, yellow, and blue robes; **phoenix mascot "Sparky"**; speed and showmanship | `[QTTA c8]` |
| **Thundelarra Thunderers** | Australia | Dominated the Australian league for nearly a century together with the Warriors; legendary rivalry ("*Yeah, and I think I'll volunteer to ref the next Thunderer-Warrior game*") | `[QTTA c8]` |
| **Wollongong (Woollongong) Warriors** | Australia | Ditto; inventors of the Woollongong Shimmy | `[QTTA c8, c10]` |
| **Patonga Proudsticks** | Uganda | **Drew with the Montrose Magpies in 1986**; **six** of their players were part of the Ugandan national team (a record for players from a single club on a national team) | `[QTTA c8]` |
| **Tchamba Charmers** | Togo | Masters of the **reverse pass** | `[QTTA c8]` |
| **Gimbi Giant-Slayers** | Ethiopia | **Two-time** winners of the **All-Africa Cup** | `[QTTA c8]` |
| **Sumbawanga Sunrays** | Tanzania | Very popular for their **formation looping** | `[QTTA c8]` |
| **Moose Jaw Meteorites** | Canada | Almost disbanded in the 1970s for their celebratory flights over towns with sparks trailing from their broom tails; now they do it only on the pitch and are a tourist attraction | `[QTTA c8]` |
| **Haileybury Hammers** | Canada | Among the best in the world | `[QTTA c8]` |
| **Stonewall Stormers** | Canada | Among the best in the world | `[QTTA c8]` |
| **Sweetwater All-Stars** | Texas, USA | Beat Quiberon in 1993 after **5 days**; 1926 US league final against Fitchburg `[FB]` | `[QTTA c8]` |
| **Fitchburg Finches** | Massachusetts, USA | **7 US league titles**; their Seeker **Maximus Brankovitch III** captained the US at two World Cups | `[QTTA c8]` |
| **Tarapoto Tree-Skimmers** | Peru | Peru's most famous team; acclaimed European tour; captain João Coelho (Castelobruxo alumnus) `[PM]` | `[QTTA c8]` |
| **Toyohashi Tengu** | Japan | Japan's most successful club; **burn their brooms when they lose** (the ICWQC criticizes it as a "waste of good timber"); **Champion's League** winners (c. 2016), train over a stormy sea near Mahoutokoro dodging planes from a Muggle base | `[QTTA c8]`, `[PM-Mahoutokoro]` |

### 7.4 National teams

| National team | Key data | Known squad | Source |
|---|---|---|---|
| **Ireland** | **1994 champions** (Ireland 170-160 Bulgaria); crushed Peru in the semis; Firebolts; green with names embroidered in silver; **leprechaun** mascots (shower of gold that vanishes); failed to qualify in 2014 | C Troy, Mullet, Moran; B Connolly, Quigley; K Barry Ryan; S **Aidan Lynch**. Historical: K Darren O'Hare (captain) | `[GoF 8]`, `[QTTA c7]`, `[PM-WC]` |
| **Bulgaria** | 1994 and 2002 finalists; **2014 champions**; twelve straight seasons as Eastern European champions before 1994 `[Film Wizardry]`; **veela** mascots; scarlet; Firebolts (1994), Firebolt Supreme (2014) | 1994: C Dimitrov, Ivanova, Levski; B Volkov, Vulchanov; K Zograf; S **Viktor Krum**. 2014: C Bogomil Levski, Nikola Vassileva, Stoyanka Grozda; B **Boris Vulchanov**, Dimitar Draganov; K Georgi Zdravko; S Krum (Levski and Vulchanov are the sons of the 1994 players) | `[GoF 8]`, `[PM-2014]` |
| **Brazil** | **5 World Cups** (according to Bagman); finalists in 1982 ("their first final since 1982") and 2014; "wilderness years" in the 1990s and 2000s; manager **José Barboza** rebuilt with young players (average age 22); **curupira** mascots; Varápidos brooms | 2014: C Fernando Diaz, Alejandra Alonso, Gonçalo Flores; B Rafael Santos, Carlos Clodoaldo; K Raul Almeida; S Tony Silva | `[PM-2014]` |
| **Japan** | 3rd in 2014; Beaters **Hongo and Shingo** ("second-best duo in history" after Volkov and Vulchanov); Yajirushi brooms; train at Mahoutokoro | 2014: C Ryuichi Yamaguchi, Kimiko Kurosawa, Yoshi Wakahisa; B Masaki Hongo, Shintaro Shingo; K Todoroki; S Noriko Sato | `[PM-2014]` |
| **United States** | 4th in 2014 (best result ever); Quodpot held back its development; Starsweeper XXI; their fans kidnapped Hans the augurey | 2014: C Quentin Kowalski, Mercy Wardwell, Arsenia Gonzales; B Lucas Picquery, Pringle; K Susan Blancheflower; S Darius Smackhammer. Historical: S Maximus Brankovitch III (captain 1986-90) | `[PM-2014]`, `[QTTA c8]` |
| **Wales** | Lost to Uganda in 1994; 2014 quarterfinals; manager **Gwenog Jones** | 2014: C Jackie Jernigan; B Iefan Rice, Darren Floyd; S Eurig Cadwallader | `[GoF 5]`, `[PM-2014]` |
| **Norway** | Co-favorites in 2014 (with Nigeria); usual mascots: **trolls**; in 2014 a **Selma** (lake serpent) | C Lars Lundekvam; K Karl Wang; S Sigrid Kristoffersen; manager Arnulf Moe; coach Oddvar Spillum | `[PM-2014]` |
| **Nigeria** | Co-favorites in 2014; **sasabonsam** mascot; Thunderbolt VII | B Aliko Okoye, Mercy Ojukwu; S Samuel Equiano | `[PM-2014]` |
| **Liechtenstein** | Pulled off a surprise by beating China (the runners-up) in their qualifying group; mascot **Hans**, a melancholy augurey with a fan club | C Willi Wenzel, Otmar Frick ("The Rugged Man of Ruggell"); S Bruno Bruunhart; coach-manager Ferdinand Jägendorf | `[PM-WC]`, `[PM-2014]` |
| **Chad** | 2014 (3 days vs Liechtenstein) | S Jacques Miskine | `[PM-2014]` |
| **Fiji** | 2014; **dukuwaqa** mascot (shark-man) | B Quintia Qarase, Narinder Singh; S Joseph Snuka; manager-coach Hector Bolobolo | `[PM-2014]` |
| **Haiti** | 2014; rumors of **Inferi** as mascots (confirmed at the ceremony); disqualified for Snitchnip | C Clairvius Hyppolite; B Jean-Baptiste Bloncourt; K Lenelle Paraison; S Sylvian Jolicoeur | `[PM-2014]` |
| **Ivory Coast** | 2014; **river-spirit** mascots | C Elodie Dembélé (18); S Sylvian Boigny | `[PM-2014]` |
| **Jamaica** | 2014 | K Kquewanda Bailey; S Shanice Higgins | `[PM-2014]` |
| **New Zealand** | 2014 ("Kiwis") | C Dennis Moon (sent off); S Ngapo Ponika (21); manager Charlie Baverstock | `[PM-2014]` |
| **Poland** | 2014, young team | S Wladyslaw Wolfke; S Bonawentura Wójcik (accused of being the Italian Luciano Volpi in disguise); C Ladislaw Zamojski `[OotP]`; historical: Josef Wronski | `[PM-WC]`, `[PM-2014]` |
| **Germany** | 2014 | S Thorsten Pfeffer; manager Franziska Faust | `[PM-2014]` |
| **England** | Lost **390-10** to Transylvania in 1994; failed to qualify in 2014 | Historical: S Roderick Plumpton (22 caps), B Ludo Bagman (vs Turkey, 1981), B Lucas Bargeworthy (1877), S Blythe Parkin (1994 `[VG-QWC]`) | `[GoF 5]`, `[QTTA c7]`, `[GoF 30]`, `[PM-WC]` |
| **Scotland** | 1990 finalists (lost 270-240 to Canada; Seeker Hector Lamont blamed his father for not giving him longer fingers); "massacred" by Luxembourg in 1994 | C Catriona McCormack (36 caps) | `[PM-WC]`, `[GoF 5]`, `[QTTA c7]` |
| **Canada** | **1990 champions** | S Angelus Peel (1877, backward knees) | `[PM-WC]` |
| **Australia** | **1966 champions** | C Royston Idlewind (later head of the ICWQC) | `[PM-WC]` |
| **Syria** | **1974 champions** (vs Madagascar) | | `[PM-WC]` |
| **Malawi** | **1998 champions** (260-180 vs Senegal; the second all-African final) | | `[PM-WC]` |
| **Senegal** | 1998 finalists; **yumboes** mascots (arrested; they stole all the food within a 10-mile radius) | | `[PM-WC]` |
| **Egypt** | **2002 champions** (450-300 vs Bulgaria) | S **Rawya Zaghloul** | `[PM-WC]` |
| **Burkina Faso** | **2006 champions** (300-220 vs France) | S **Joshua Sankara** (appointed Minister for Magic, resigned two days later to keep playing) | `[PM-WC]` |
| **Moldova** | **2010 champions** (750-640 vs China, 3 days); always strong teams; did not go to 2014 because of **dragon pox** in their training camp | | `[PM-WC]` |
| **China** | 2010 finalists | | `[PM-WC]` |
| **France** | 2006 finalists | | `[PM-WC]` |
| **Madagascar** | 1974 finalists | | `[PM-WC]` |
| **Romania** / **New Spain (Mexico)** | 1809 final ("Attack of the Killer Forest") | Romania: B **Niko Nenad**, Ivan Popa | `[PM-WC]` |
| **Transylvania** / **Flanders** | 1473 final (the most violent in history); Transylvania beats England 390-10 in 1994 | | `[QTTA c8]`, `[GoF 5]` |
| **Peru** | "The most skilled nation in South America", a contender to become the first Latin champion; 1994 semifinalists | | `[QTTA c8]`, `[GoF 5]` |
| **Argentina** | Quarterfinals in the 20th century; 2014 hosts (Patagonia); in 1877 half the national team turned up tied up in a cellar in Cardiff | | `[QTTA c8]`, `[PM-WC]` |
| **Luxembourg**, **Uganda**, **Italy** (S Luciano Volpi), **Turkey**, **Portugal**, **India**, **Morocco** | Minor appearances | | `[GoF 5]`, `[PM-WC]`, `[GoF 30]` |

Complete 1994 rosters for **England, France, Germany, Spain, USA, Australia, Japan, Scandinavia (Nordic team)** exist **only in the video game** `[VG-QWC]` (see §9.3). Rosters for **Canada, China, India, Mexico, South Africa, Sweden, Uganda** and for **Beauxbatons/Durmstrang** exist **only in** `[VG-QC]`.

### 7.5 Hogwarts house teams

| House | Colors | Known players (books) | Video game players |
|---|---|---|---|
| **Gryffindor** | Scarlet, lion | 1991-94: K/capt **Oliver Wood**; C **Angelina Johnson**, **Alicia Spinnet**, **Katie Bell**; B **Fred and George Weasley**; S **Harry Potter**. 1995-96: capt Angelina; K **Ron Weasley**; B **Andrew Kirke**, **Jack Sloper** (after the bans); S **Ginny Weasley**. 1996-97: capt/S Harry; C Ginny, Katie, **Demelza Robins** (great at dodging Bludgers), **Dean Thomas** (substitute); B **Jimmy Peakes**, **Ritchie Coote**; K Ron (substitute **Cormac McLaggen**). Earlier: **Charlie Weasley** (S/capt; "could have played for England"), **James Potter** (C, according to JKR; the film says Seeker), **Minerva McGonagall** (injured in her last match vs Slytherin) | Edgar Hexsmith `[VG-MA]`; Rose Granger-Weasley (C) `[CC]` |
| **Hufflepuff** | Yellow, badger | S/capt **Cedric Diggory**; S **Summerby**; C/capt **Zacharias Smith**; C **Cadwallader** | `[VG-QWC]`: K Herbert Fleet; C Malcolm Preece, Heidi Macavoy, Tamsin Applebee; B Anthony Rickett, Maxine O'Flaherty, Michael McManus |
| **Ravenclaw** | Blue, eagle | S **Cho Chang** (Comet 260; the only girl on the team in 1993-94); C/capt **Roger Davies**; C **Bradley**, **Chambers** | `[VG-QWC]`: C Jeremy Stretton, Randolph Burrow; K Grant Page; B Duncan Inglebee, Jason Samuels |
| **Slytherin** | Green, serpent | C/capt **Marcus Flint** (1991-94), **Graham Montague** (capt 1995-96), **Urquhart** (capt 1996-97); C **Adrian Pucey**, **Cassius Warrington**, **Vaisey**; B **Lucian Bole**, **Peregrine Derrick** (1993-94), **Vincent Crabbe**, **Gregory Goyle** (1995-96); K **Miles Bletchley**; S **Terence Higgs**, **Draco Malfoy** (from 1992, Nimbus 2001), **Harper** (substitute 1996); earlier **Regulus Black** (S, 1970s) | |

Hogwarts rules and customs: **first-years may not have a broom or join the team** (exception: Harry, "the youngest in a century") `[PS 9]`; the **captain** organizes tryouts and picks the team; the Head of House appoints the captain `[HBP]`; referee: Madam Hooch; commentators: Lee Jordan (with McGonagall beside him), Zacharias Smith, Luna Lovegood `[PS-HBP]`; the stands are decorated in both teams' colors, alternating `[Wiki]`; matches usually at **11 in the morning** `[Lexicon]`.

### 7.6 Other schools and teams

- **Beauxbatons** and **Durmstrang** have their own teams and pitches; the *Triwizard Schools Quidditch Cup* is a competition invented by `[VG-QC]` (Durmstrang: S/capt Viktor Krum; Beauxbatons: S Fleur Delacour, C Gabrielle Delacour). In `[GoF]` Hogwarts Quidditch is suspended in the year of the Triwizard Tournament.
- **Ilvermorny**: inter-house Quidditch Cup; **Pukwudgie** won it in 1926 `[FB]`/`[Prop]`.
- **Mahoutokoro** (Japan): training over the sea during storms; base of the Toyohashi Tengu and the Japanese national team `[PM-Mahoutokoro]`.
- **Castelobruxo** (Brazil): alumni such as João Coelho, captain of the Tarapoto Tree-Skimmers `[PM]`.
- **Team Weasley**: family games in the orchard at the Burrow `[HBP]`; the *Weasley Burrow Garden Cup* is the tutorial in `[VG-QC]`.

---

## 8. Competitions

### 8.1 British and Irish Quidditch League

| Aspect | Data | Source |
|---|---|---|
| Founded | **1674**: the Department selected the **13 best teams** in Britain and Ireland; the rest had to disband | `[QTTA c7]` |
| Reason | Maintaining secrecy from Muggles by **limiting the number of matches per year** | `[QTTA c7]` |
| Trophy | **League Cup**, contested **every year** | `[QTTA c7]` |
| Standings | By **accumulated points** (multiples of 10), with no wins column | `[DP1-DP4]` |
| Draws | They exist (Cannons-Catapults) | `[DP]` |
| Schedule | Matches on different days (Friday, Saturday, Monday), at varied times (11:00, **midnight**) | `[DP]` |
| Venues | **No home stadiums**: "teams do not play in their home towns but travel to pitches prepared by the Department with anti-Muggle security"; deserted moors | `[QTTA c5]` |
| Known stadiums | **Bodmin Moor** (Cornwall), **Exmoor** (new stadium with an Invisibility Charm), **Ilkley Moor** (Yorkshire), **Yorkshire Moors**, **Ellis Moor** (occupied by Muggle campers) | `[DP]`, `[QTTA c6]` |
| Final or playoff? | A **film poster** shows a "league final" Magpies vs Puddlemere at the "Bodmin Moor Millenium Stadium" | `[Prop]` (**not canon**) |
| Amateurs | Allowed if they meet the Department's requirements | `[QTTA c7]` |
| Individual awards | **Dangerous Dai Commemorative Medal**: to the league player who took the most exciting and reckless risks of the season `[QTTA c7]`; **Josef Wronski Award for Excellent Pitch Skills** (Chudley Cannons 1931) `[Prop]` | Mixed |
| Bodies | Department of Magical Games and Sports (league headquarters on level 7 of the Ministry) `[OotP 7]`; **Q.U.A.B.B.L.E.** (*Quidditch Union for the Administration and Betterment of the British League and its Endeavours*), head Dunbar Oglethorpe (b. 1968) `[Cards]` | Mixed |
| Season length | Unknown. Clues: tables in July, February, June, and October; the Cannons' 16-match losing streak exceeds the 12 possible opponents → **double round-robin or a streak spanning seasons** `[Inference]` | |

### 8.2 European Cup

- Created in **1652**, played **every three years** `[QTTA c8]`.
- Known champions: **Vratsa Vultures** ×7 (incl. 1931), **Montrose Magpies** ×2, **Puddlemere United** ×2, **Caerphilly Catapults** 1956 (final vs Karasjok Kites), **Quiberon Quafflepunchers** 1922 `[Prop]`. Wimbourne Wasps: semifinalists ×2 `[QTTA c7-c8]`.
- Format unknown (the wiki says "knockout" without a source) `[Wiki]`.
- A "European Quidditch League" also appears, in which Beauxbatons was in first place in 1926 `[FB]`/`[Prop]`.

### 8.3 Quidditch World Cup

**Organization.** The **ICWQC** (*International Confederation of Wizards' Quidditch Committee*, created after the 1692 Statute of Secrecy) chooses venues (moors, deserts, uninhabited islands), organizes transport (up to **100,000 spectators** per final), oversees matches, and **chooses the referees**. Official guide: *The Official Guide to the Quidditch World Cup* (**39 Galleons**, "ridiculously expensive") `[PM-WC]`. In 1994 the British organizer was the Department of Magical Games and Sports (Bagman) `[GoF]`; GoF also mentions the "**International Association of Quidditch**" (Mostafa, its chairwizard) `[GoF 8]`.

**Format (JKR canon, `[PM-WC]`)**:
1. Any country may enter within the **12 months following the previous final**.
2. **Group stage**: **16 groups**; round-robin over **two years**.
3. In the group stage, matches have a **4-hour cap** "to prevent player exhaustion". If the Snitch is not caught, **the result is decided by goals**.
4. **Points**: win = **2 points**; win by **more than 150** = **+5**; by **100** = **+3**; by **50** = **+1** (i.e., 2, 3, 5, or 7 points per match won).
5. **Tiebreak.** The team that **caught the Snitch most often**, or **fastest**.
6. The **16 group winners** advance to **knockout rounds**, seeded by points: 1st plays 16th, 2nd plays 15th, etc. "In theory, the two best teams reach the final" (in 2014 Nigeria and Norway, the two top-ranked teams, could meet in the semis).
7. **Third-place match** between the semifinal losers `[PM-2014]`.
8. The knockout rounds are played **with no time cap** (matches of 3 days, 20 hours, 10 hours in 2014) `[PM-2014]`.

**History and editions**:

| Year | Edition | Venue | Final / result | Notes | Source |
|---|---|---|---|---|---|
| 1473 | 1st | Europe | **Transylvania vs Flanders** (winner not explicit in QTTA; the wiki gives Transylvania) | European teams only; the 700 fouls; the Transylvanian Tackle is born | `[QTTA c8, c10]` |
| 17th c. | | | | First non-European teams; purists date the "true" World Cup from here | `[QTTA c8]`, `[PM-WC]` |
| c. 1801-1805 | | Britain | | Through lobbying by Minister Artemisia Lufkin | `[PM-ministers]` `[Wiki]` |
| 1809 | | Edge of the West Siberian Plain | **Romania vs New Spain** | "**Attack of the Killer Forest**": Niko Nenad (Romania) hits a Bludger into a haunted forest; the trees march on the stadium; 7-hour battle; deaths; Nenad is crushed to death by a fir tree. His teammates had asked the manager to substitute him for the final | `[PM-WC]` |
| 1877 | | Ryn Desert (Kazakhstan) | ? | "**The Tournament that Nobody Remembers**": nobody remembers anything; Bargeworthy without teeth, Peel with backward knees, half of Argentina tied up in Cardiff | `[PM-WC]` |
| 1878 | | ? | ? | Replayed; every 4 years since then | `[PM-WC]` |
| 20th c. | | | | Argentina and Brazil reach the quarterfinals | `[QTTA c8]` |
| c. 1964 | | Britain | | "Britain hasn't hosted the Cup for thirty years" (Molly, 1994) | `[GoF 3]` |
| 1966 | | ? | **Australia** champions | Royston Idlewind | `[PM-WC]` |
| 1974 | 417th | ? | **Syria vs Madagascar** | "Royston Idlewind and the Dissimulators": total ban on wands; 100,000 fans with "Dissimulator" instruments that were disguised wands; Idlewind resigns | `[PM-WC]` |
| 1982 | | ? | Brazil finalists | | `[PM-2014]` |
| 1986 | | ? | ? | USA with Brankovitch III as captain | `[QTTA c8]` |
| 1990 | | ? | **Canada 270-240 Scotland** | Hector Lamont misses the Snitch by millimeters | `[PM-WC]` |
| **1994** | **422nd** | **Dartmoor**, England | **Ireland 170-160 Bulgaria** | See §10.2. Transylvania 390-10 England; Luxembourg massacres Scotland; Uganda beats Wales; Ireland crushes Peru in the semis. Death Eater attack and Dark Mark after the final | `[GoF 5-9]`, `[PM-WC]` |
| 1998 | | ? | **Malawi 260-180 Senegal** | Second all-African final; maximum security after 1994. (In the DH1 film *The Quibbler* announces "World Cup canceled due to death threats" `[Film]`, which contradicts JKR's result) | `[PM-WC]` |
| 2002 | | ? | **Egypt 450-300 Bulgaria** | Zaghloul narrowly beats Krum to the Snitch; Krum retires in tears | `[PM-WC]` |
| 2006 | | ? | **Burkina Faso 300-220 France** | Sankara, Minister for Magic for two days | `[PM-WC]` |
| 2010 | | ? | **Moldova 750-640 China** | 3 days; "the best Quidditch of the century" | `[PM-WC]` |
| **2014** | **427th** | **Patagonian Desert**, Argentina | **Bulgaria 170-60 Brazil** (July 11) | 91-day tournament; 10,000 Portkeys; see bracket below | `[PM-2014]` |

**2014 World Cup bracket** `[PM-2014]`:

| Round | Match | Result |
|---|---|---|
| Round of 16 | Norway-Ivory Coast | 340-100 |
| Round of 16 | Nigeria-Fiji | 400-160 |
| Round of 16 | Brazil-Haiti | 100-90 (Haiti disqualified) |
| Round of 16 | USA-Jamaica | 240-230 (investigated and upheld) |
| Round of 16 | Liechtenstein-Chad | 470-330 (3 days) |
| Round of 16 | Bulgaria-New Zealand | 410-170 |
| Round of 16 | Japan-Poland | 350-140 |
| Round of 16 | Wales-Germany | 330-100 |
| Quarterfinal | Brazil-Wales | 460-300 |
| Quarterfinal | Bulgaria-Norway | 170-20 |
| Quarterfinal | USA-Liechtenstein | 450-290 |
| Quarterfinal | Japan-Nigeria | 270-100 |
| Semifinal | Brazil-USA | 420-310 (~20 h) |
| Semifinal | Bulgaria-Japan | 610-460 (10 h) |
| 3rd place | Japan-USA | 330-120 |
| **Final** | **Bulgaria-Brazil** | **170-60** (2 h 45) |

Ludo Bagman's odds before the semis: Japan 4/1, Brazil 9/1, USA 12/1, Bulgaria 50/1 `[PM-2014]`.

**Numbering.** If it has been played every 4 years since 1473, 2014 would be the ~135th, not the 427th. JKR explains the 1877/1878 shift but **not** the 422/427 figure; the Lexicon proposes theories (changes in frequency from annual → biennial → quadrennial) `[Lexicon]`.

### 8.4 Hogwarts Inter-House Quidditch Cup

| Aspect | Data | Source |
|---|---|---|
| Format | **Single round-robin league**: each house plays the other three (6 matches per year) | `[PS]`, `[Lexicon]` |
| Standings | By **total points scored**, not by wins: "*it was entirely possible for one team to lose to another, but still claim the Cup*" | `[Wiki]`, evidence in `[PoA 15]` |
| 1994 example | Slytherin led by **200 points**; Gryffindor needed to win **by more than 200** → Harry must not catch the Snitch until they were **50 points up**. They won 230-20 (margin of 210) | `[PoA 15]` |
| 1997 example | "*If Gryffindor beat Ravenclaw by a margin of three hundred points... they would win the championship. If they won by less... second to Ravenclaw; if they lost by a hundred points they would be third behind Hufflepuff, and if they lost by more than a hundred, they would be in fourth place*". This implies that **the margin (point difference)** counts, not just points scored | `[HBP 24]` |
| Inconsistency | The Lexicon shows that the HBP 24 figures fit neither "total points" nor "point difference" (the differences would add up to 360 instead of 0); it concludes that JKR's arithmetic is inconsistent or that there is a hybrid system | `[Lexicon]` |
| Typical schedule | 1st G-S (1st/2nd week of November); 2nd H-R (late November); 3rd R-S (late February); 4th G-H (early March); 5th H-S (early May); 6th G-R (late May) | `[Wiki]` (deduced from the books) |
| Rescheduling | Due to a claimed injury (Malfoy 1993) | `[PoA 8]` |
| Cancellation | Due to the basilisk attacks (1993) `[CS 14]`; due to the Triwizard Tournament (1994-95) `[GoF 12]`; by decision of headmaster Phineas Nigellus Black after a student was injured in the previous final (1890-91) `[VG-HL]`; in the OotP film, by Umbridge's decree `[Film]` | Mixed |
| Trophy | Huge silver cup with four handles bearing the house animals; kept in the office of the winning house's Head | `[Wiki]` |
| Relation to the House Cup | Winning matches earns points for the house (Harry fears losing "the lead he had won in the last match" when 50 points are taken from him) | `[PS 15]` |

### 8.5 Other competitions

| Competition | Data | Source |
|---|---|---|
| **All-Africa Cup** | Gimbi Giant-Slayers champions ×2 | `[QTTA c8]` |
| **Australian league** | Dominated by Thundelarra and Wollongong | `[QTTA c8]` |
| **US league** (Inter-State League / USA Quidditch League) | Fitchburg Finches ×7; 1926 "Grand Final" Fitchburg vs Sweetwater "on the first full moon of Aquarius" | `[QTTA c8]`, `[FB]` |
| **French league** | Quiberon frequent champions | `[QTTA c8]` |
| **Eastern European Championship** | Bulgaria won 12 straight seasons before 1994 | `[Film Wizardry]` |
| **Champion's League** | Toyohashi Tengu champions (c. 2016) | `[PM-Mahoutokoro]` |
| **International Quidditch Tournament** | 1972, between regional teams; the Chudley Cannons took part | `[Prop]` |
| **Japanese, Polish, Canadian leagues, All-Africa Quidditch League** | Mentioned only in games | `[VG]` |
| **Triwizard Schools Quidditch Cup** | Hogwarts, Beauxbatons, Durmstrang | `[VG-QC]` |
| **Ligue de Grenoble** | Mentioned in *Fantastic Beasts* props | `[FB]` |

---

## 9. Named players

Abbreviations: K = Keeper, C = Chaser, B = Beater, S = Seeker, capt = captain.

### 9.1 Professionals and historical figures (canon)

| Player | Team(s) | Pos. | Era | Traits / facts | Source |
|---|---|---|---|---|---|
| **Viktor Krum** | Bulgaria; Durmstrang | S | b. 1976; national team at 18 (1994), 2002, 2014 | Thin, dark, large curved nose, thick black eyebrows, "like an overgrown bird of prey"; clumsy and round-shouldered on the ground but graceful in the air. Wronski Feint on Lynch (twice); catches the Snitch with a broken nose to "end it on his own terms" while losing 170-160. Retires in tears in 2002; returns at **38** in 2014 ("to win the World Cup before he dies"), champion. Great sportsmanship (does not take advantage when Sato saves Vulchanov) | `[GoF 7-8]`, `[PM-WC]`, `[PM-2014]` |
| **Ludovic "Ludo" Bagman** | Wimbourne Wasps; England | B | 1970s-1981 | A great former athlete "gone to seed", broken nose (probably from a Bludger); the Wasps' best Beater (3 league titles in a row); later Head of the Department; commentator for the 1994 final; compulsive gambler (pays with leprechaun gold, flees the goblins); in 2014 acts as bookmaker in the *Daily Prophet* | `[GoF 5-8, 30, 37]`, `[PM-2014]` |
| **Oliver Wood** | Gryffindor (K/capt 1991-94); Puddlemere United (reserve) | K | b. ~1975 | Obsessive, extremely long speeches, tactics blackboard; the 1994 Cup | `[PS-PoA]`, `[GoF 7]` |
| **Ginny Weasley (Potter)** | Gryffindor; **Holyhead Harpies** | C/S | 1995-2000s | Practiced in secret on her brothers' brooms; later senior Quidditch correspondent for the *Daily Prophet* | `[OotP 26]`, `[PM-2014]`, JKR web chat 2007 |
| **Gwenog Jones** | Holyhead Harpies (B/capt); **Wales** manager (2014) | B | b. 1968; Harpies since 1986 | "Brilliant but dangerous"; member of the Slug Club; death threats to Wilda Griffiths; arrested after a riot; in 2014 tries to "rip the face off" the Brazilian manager with a curse | `[HBP 4]`, `[DP]`, `[Cards]`, `[PM-2014]` |
| **Aidan Lynch** | Ireland | S | 1994 | Victim of the Wronski Feint; finishes the final propped up by teammates | `[GoF 8]` |
| Troy, Mullet, Moran | Ireland | C | 1994 | Troy scores the first goal and pulls off a Porskoff Ploy; Mullet takes Zograf's elbow; Moran nearly unseated by Dimitrov | `[GoF 8]` |
| Connolly, Quigley | Ireland | B | 1994 | Quigley breaks Krum's nose | `[GoF 8]` |
| Barry Ryan | Ireland | K | 1994 | | `[GoF 8]` |
| Dimitrov, Ivanova, Levski | Bulgaria | C | 1994 | Ivanova scores Bulgaria's only goal; Dimitrov commits blatching | `[GoF 8]` |
| Volkov, Vulchanov | Bulgaria | B | 1994 | "Best Beater duo in history" (2014 poll) | `[GoF 8]`, `[PM-2014]` |
| Zograf | Bulgaria | K | 1994 | Commits cobbing | `[GoF 8]` |
| **Joscelind Wadcock** | Puddlemere United | C | b. 1911 | 20th-century British league record for goals in a match (1931, vs the Ballycastle Bats) | `[Cards]` |
| **Roderick Plumpton** | Tutshill Tornados; England (22 caps) | S/capt | 1889-1987 | 3.5 s (1921); 5 league titles in a row; "Plumpton Pass" | `[QTTA c7, c10]`, `[Cards]` |
| **"Dangerous" Dai Llewellyn** | Caerphilly Catapults | ? | 20th c. | The most famous player of his club for his risk-taking; eaten by a chimaera on Mykonos; medal in his honor; Whisp wrote his biography *He Flew Like a Madman*; the Serious Bites ward at St Mungo's is named after him | `[QTTA c7]`, `[Wiki]` |
| **Catriona McCormack** | Pride of Portree; Scotland (36 caps) | C/capt | 1960s | Two league titles | `[QTTA c7]` |
| Meaghan McCormack | Pride of Portree | K | 1990s | Catriona's daughter | `[QTTA c7]` |
| **Darren O'Hare** | Kenmare Kestrels; Ireland (capt ×3) | K | 1947-60 | Inventor of the Hawkshead | `[QTTA c7]` |
| **Eunice Murray** | Montrose Magpies | S | †1942 | Asked for a faster Snitch "because this is just too easy" | `[QTTA c7]` |
| **Hamish MacFarlan** | Montrose Magpies | capt | 1957-68 | Later Head of the Department of Magical Games and Sports | `[QTTA c7]` |
| **Fabius Watkins** | Montrose Magpies | C/capt | 1940-1975 | "Legendary"; dies colliding with a helicopter | `[Cards]` |
| **Glynnis Griffiths** | Holyhead Harpies | S | 1953 | Spectacular catch after 7 days | `[QTTA c7]` |
| **Gwendolyn Morgan** | Holyhead Harpies | capt | 1953 | Concusses the opposing captain who proposes to her, with her Cleansweep Five | `[QTTA c7]` |
| **Rudolf Brand** | Heidelberg Harriers | capt | 1953 | The suitor | `[QTTA c7]` |
| **Karl and Kevin Broadmoor** | Falmouth Falcons | B | 1958-69 | 14 suspensions | `[QTTA c7]` |
| **Randolph Keitch and Basil Horton** | Falmouth Falcons | ? | 1929 | Founders of Comet | `[QTTA c9]` |
| **Josef Wronski** | Grodzisk Goblins (Poland) | S | 20th c. | "The world's most innovative Seeker" | `[QTTA c8, c10]` |
| **Petrova Porskoff** | ? (Russia) | C | ? | Porskoff Ploy | `[QTTA c10]` |
| **Maximus Brankovitch III** | Fitchburg Finches; USA (capt 1986, 1990) | S | 1980s-90s | | `[QTTA c8]` |
| **Galvin Gudgeon** | Chudley Cannons | S | 1998-99 | The Snitch bounced off his nose twice; the manager asks the fans not to turn him into a toad | `[DP1]` |
| **Joey Jenkins** | Chudley Cannons | B | 1990s | | `[GoF]` |
| **Dragomir Gorgovitch** | Chudley Cannons | C | 1997 | Record for "Quaffle drops" in a season (Ron mentions it) | `[DH 7]` |
| Gordon Horton | Chudley Cannons | K | ? | | `[Wiki]` |
| **Wilda Griffiths** | Holyhead → Puddlemere | C | 1999 | **1,000-Galleon transfer**; death threats from Gwenog; vanishes midway through the Harpies-Puddlemere match | `[DP2-DP4]` |
| **Valmai Morgan** | Holyhead Harpies | C | 1999 | Griffiths's replacement: 10 goals in a match | `[DP]` |
| **Benjy Williams** | Puddlemere United | S | 1999 | Catches the Snitch during the riot | `[DP]` |
| **Gregory Cotton** / **Dougal McBride** | Appleby Arrows / Pride of Portree | S | 1999 | Collision, illegal jinxes, cabbage head (referee Josiah Plunkett) | `[DP3]` |
| **Alasdair Maddock** | Montrose Magpies | C | 1998-99 | Muggle football fan; sacked by manager McLeod after being caught playing golf; replaced by **Angus Campbell** (ex-Catapults) | `[DP]` |
| **Lennox Campbell** | Montrose Magpies | S | 1999 | Misses the Snitch a teammate kicked to him | `[DP]` |
| **Brevis Birch** / **Mervyn Fenwick** | Tutshill Tornados | capt / K | 1999 | Birch blames a defeat on Fenwick's **narcolepsy** | `[DP]` |
| **Finbar Quigley** | Ballycastle Bats | ? | 1999 | | `[DP2]` |
| **Royston Idlewind** | Australia | C | 1966 (champion) | International Director of the ICWQC (1971-74); hated fans | `[PM-WC]` |
| **Niko Nenad** / **Ivan Popa** | Romania | B / ? | 1809 | Nenad: the worst fit of rage in history; Popa: Order of Merit for saving lives | `[PM-WC]` |
| **Lucas Bargeworthy** | England | B | 1877 | Toothless after the tournament nobody remembers | `[PM-WC]` |
| **Angelus Peel** | Canada | S | 1877 | Backward knees | `[PM-WC]` |
| **Hector "Stubby" Lamont** | Scotland | S | 1990 | Blames his father for not giving him longer fingers | `[PM-WC]` |
| **Rawya Zaghloul** | Egypt | S | 2002 | "Outstanding"; beats Krum to the Snitch | `[PM-WC]` |
| **Joshua Sankara** | Burkina Faso | S | 2006 | Minister for Magic for two days | `[PM-WC]` |
| **Luciano Volpi** | Italy | S | 2014 | "Famous"; suspected of being Wójcik in disguise | `[PM-WC]` |
| **Bonawentura Wójcik** | Poland | S | 2014 | | `[PM-WC]` |
| **Ladislaw Zamojski** | Poland | C | 1990s | Mentioned by Ron | `[OotP]` `[Wiki]` |
| **Eurig Cadwallader** | Wales | S | 2014 | Catches the Snitch 11 minutes after Pfeffer's crash | `[PM-2014]` |
| **Jackie Jernigan**, **Iefan Rice**, **Darren Floyd** | Wales | C, B, B | 2014 | Jernigan: superb 50-yard goal; Floyd: prevented "at least 17 goals"; Rice: Bludger hit on the Keeper | `[PM-2014]` |
| **Tony Silva** | Brazil | S | 2014 | Fast and accurate but struggles to **locate** the Snitch (average 10 h 44 min) | `[PM-2014]` |
| **Fernando Diaz, Alejandra Alonso, Gonçalo Flores** | Brazil | C | 2014 | 68 goals up to the final; Flores, Albus Potter's idol, long-range shooting specialist; Alonso, star of the first two rounds | `[PM-2014]` |
| **Rafael Santos, Carlos Clodoaldo** | Brazil | B | 2014 | Weak at first, decisive in the semis | `[PM-2014]` |
| **Raul Almeida** | Brazil | K | 2014 | Star of the semifinal | `[PM-2014]` |
| **Bogomil Levski, Nikola Vassileva, Stoyanka Grozda** | Bulgaria | C | 2014 | 74 goals up to the final (more than Brazil) | `[PM-2014]` |
| **Boris Vulchanov, Dimitar Draganov** | Bulgaria | B | 2014 | "Competent, not exceptional", great physical courage | `[PM-2014]` |
| **Georgi Zdravko** | Bulgaria | K | 2014 | Weak: 17 goals conceded vs NZ, 46 vs Japan | `[PM-2014]` |
| **Masaki Hongo, Shintaro Shingo** | Japan | B | 2014 | Veterans; replicas of their robes are the best-sellers | `[PM-2014]` |
| **Noriko Sato** | Japan | S | 2014 | "Gifted"; saves Vulchanov; spectacular catches | `[PM-2014]` |
| **Todoroki** | Japan | K | 2014 | "Unsung hero" | `[PM-2014]` |
| **Ryuichi Yamaguchi, Kimiko Kurosawa, Yoshi Wakahisa** | Japan | C | 2014 | | `[PM-2014]` |
| **Darius Smackhammer** | USA | S | 2014 | Risky catches among the Bludgers | `[PM-2014]` |
| **Quentin Kowalski, Mercy Wardwell, Arsenia Gonzales** | USA | C | 2014 | Kowalski: weaving and rolling; Wardwell hits herself on the head after her 5th miss | `[PM-2014]` |
| **Susan Blancheflower** | USA | K | 2014 | 23 goals conceded vs Jamaica and 18 vs Japan; cautioned for trying to jump onto her own Beater's broom; strays too far from the area and concedes a goal | `[PM-2014]` |
| **Lucas Picquery, Pringle** | USA | B | 2014 | Picquery hits a Bludger at his own Keeper | `[PM-2014]` |
| **Lars Lundekvam** | Norway | C | 2014 | "Celebrated"; target of jinxes from the crowd | `[PM-2014]` |
| **Sigrid Kristoffersen** | Norway | S | 2014 | Bangs her head against the ground after losing | `[PM-2014]` |
| **Karl Wang** | Norway | K | 2014 | | `[PM-2014]` |
| **Aliko Okoye, Mercy Ojukwu** | Nigeria | B | 2014 | Very ferocious | `[PM-2014]` |
| **Samuel Equiano** | Nigeria | S | 2014 | Broom broken by a Bludger | `[PM-2014]` |
| **Willi Wenzel, Otmar Frick** | Liechtenstein | C | 2014 | Wenzel: goal from 60 yards after two Bludgers to the head; Frick: 16 goals vs USA | `[PM-2014]` |
| **Bruno Bruunhart** | Liechtenstein | S | 2014 | Exhausted catch on the third day | `[PM-2014]` |
| **Jacques Miskine** | Chad | S | 2014 | Failed to see the Snitch above his eyebrow for 5 minutes | `[PM-2014]` |
| **Elodie Dembélé** / **Sylvian Boigny** | Ivory Coast | C / S | 2014 | Dembélé (18): 7 of 10 goals | `[PM-2014]` |
| **Clairvius Hyppolite**, **Lenelle Paraison**, **Sylvian Jolicoeur**, **Jean-Baptiste Bloncourt** | Haiti | C, K, S, B | 2014 | Paraison: nose broken twice, one of three female Keepers in the tournament; Bloncourt: Snitchnip | `[PM-2014]` |
| **Kquewanda Bailey** / **Shanice Higgins** | Jamaica | K / S | 2014 | Bailey faints from an infected sasabonsam bite | `[PM-2014]` |
| **Quintia Qarase, Narinder Singh** / **Joseph Snuka** | Fiji | B / S | 2014 | Snuka, "selfish" | `[PM-2014]` |
| **Dennis Moon** / **Ngapo Ponika** | New Zealand | C / S | 2014 | Moon sent off; feud with Bogomil Levski | `[PM-2014]` |
| **Wladyslaw Wolfke** | Poland | S | 2014 | "Daring and elegant" | `[PM-2014]` |
| **Thorsten Pfeffer** | Germany | S | 2014 | Failed Wronski Feint | `[PM-2014]` |

### 9.2 Hogwarts (canon): see also §7.5

| Player | House | Pos. | Traits | Source |
|---|---|---|---|---|
| Harry Potter | Gryffindor | S/capt | The youngest in a century; played only 9 matches at Hogwarts and lost 2 (dementors; McLaggen) | `[PS 9]`, `[PM-feature]` |
| Charlie Weasley | Gryffindor | S/capt | "Could have played for England if he hadn't gone off chasing dragons" | `[PS 6, 10]` |
| Fred and George Weasley | Gryffindor | B | "Human Bludgers" | `[PS 9]` |
| Katie Bell, Angelina Johnson, Alicia Spinnet | Gryffindor | C | Angelina captain 1995-96 | `[PS]`, `[OotP]` |
| Ron Weasley | Gryffindor | K | Nerves; brilliant when confident (Felix "placebo") | `[OotP]`, `[HBP]` |
| Cormac McLaggen | Gryffindor | K (substitute) | Arrogant; tries to run the team; fractures Harry's skull | `[HBP 19]` |
| Demelza Robins | Gryffindor | C | Very good at dodging Bludgers | `[HBP 11]` |
| Jimmy Peakes / Ritchie Coote | Gryffindor | B | Peakes: short and broad-chested, ferocious hit; Coote: weedy but accurate | `[HBP 11]` |
| Andrew Kirke / Jack Sloper | Gryffindor | B | The twins' replacements, poor | `[OotP 21]` |
| Cedric Diggory | Hufflepuff | S/capt | Asks for a rematch of the dementor match | `[PoA 9]` |
| Zacharias Smith | Hufflepuff | C | Partisan commentator | `[HBP 14]` |
| Cho Chang | Ravenclaw | S | Very good; Comet 260 | `[PoA 13]` |
| Roger Davies | Ravenclaw | C/capt | | `[PoA 13]` |
| Marcus Flint | Slytherin | C/capt | Big and brutish; repeats a year | `[PS 11]` |
| Draco Malfoy | Slytherin | S | Gets onto the team with his father's Nimbus 2001s | `[CS 7]` |
| Harper | Slytherin | S (substitute) | Commits blatching against Harry | `[HBP 14]` |
| Regulus Black | Slytherin | S | Team photo at Grimmauld Place | `[OotP]` |
| Minerva McGonagall | Gryffindor | ? | Injured in her last match (Slytherin foul) | `[PM-McGonagall]` |
| James Potter | Gryffindor | C | (JKR, 2000; the PS film says Seeker) | Scholastic interview 2000 |

### 9.3 Players who exist only in video games

| Team | Squad | Source |
|---|---|---|
| England 1994 | C Edric Vosper, Avery Hawksworth (capt), Keaton Flitney; B Dawn Withey, Indira Choudry; K Denison Frisby; S Blythe Parkin | `[VG-QWC]` |
| France 1994 | C Mathilde Mallard, Josephine Marat (capt), Hildegarde Lafarge; B Alain Lacroix, Ninon Saucet; K Bastien Janvier; S Cybèle Peltier | `[VG-QWC]` |
| Germany 1994 | C Kurt Todt, Kursten Blijk, Igor Brand; B Katrina von Glockenspieler (capt), Elena Eldritch; K Hermann Wiel; S Konrad Weiss | `[VG-QWC]` |
| Spain 1994 | C Carmen García, Ana de Lebrón, Chavelle Arbelo Cartaya; B Vasco Santini, Tiago Montoya; K Sendelina de la Felino; S Iñigo Fuente Marrero | `[VG-QWC]` |
| USA 1994 | C Gianni Fedele, Debbie Muntz, Robert Green; B Greg Ruczinski, Troy Duvall (capt); K Ralph Heidelberger; S Ariel Singleton | `[VG-QWC]` |
| Australia 1994 | C Matthew Echunga, Maria Monteith, Kenneth Hastings; B Kelly Whakkaarangapawarau, Kylie Meadows; K Jonny Nuhaka; S Lucy Karoonda (capt) | `[VG-QWC]` |
| Japan 1994 | C Noriyuki Sato, Yoshihiro Suzuki, Ryotaro Tanaka (capt); B Minaka Hirakata, Keiko Takahashi; K Tamotsu Iwamoto; S Shizuka Watanabe | `[VG-QWC]` |
| Scandinavia 1994 | C Olaf Andersen, Lorre Gustafson, Peter Hansen; B Asgeir Knutsen, Asgard Pettersson; K Martin Helstrom; S Tina Lundstrom (capt) | `[VG-QWC]` |
| QWC commentators / referees | Lee Jordan and Seamus Finnigan (Hogwarts); Ludo Bagman with Jacqueline Lejeune, Millie Gudabi (former Thundelarra Keeper), or Arnold Vogler (ex-Heidelberg); referees Dietrich Frenzen, Cyprien Alesi, Erika Ostensen | `[VG-QWC]` |
| Canada, China, India, Mexico, South Africa, Sweden, Uganda, Beauxbatons, Durmstrang | Squads of 6 (one Beater) | `[VG-QC]` |
| Hogwarts 1984-91 | Skye Parkin, Orion Amari, Erika Rath, Murphy McNully (commentator, inventor of the Thimblerig Shuffle), Ethan Parkin (Wigtown), Angelica Cole, etc. | `[VG-HM]` |
| 19th c. | Imelda Reyes (Slytherin capt c. 1890), Chiyo Kogawa (flying instructor; tried out for Toyohashi as K), Asuka (Toyohashi C, used Felix Felicis in the tryout) | `[VG-HL]` |

---

## 10. Matches narrated in the books

### 10.1 Hogwarts

| Date | Match | Result | Plays, incidents, and rules illustrated | Source |
|---|---|---|---|---|
| Nov. 1991 | Gryffindor-Slytherin | **170-60** | Harry's debut; Flint blocks him (penalty, scored by Spinnet); Quirrell jinxes the broom; Harry catches the Snitch in his mouth; Lee Jordan penalizes verbally | `[PS 11]` |
| 1992 | Gryffindor-Hufflepuff | G wins (Snitch < 5 min) | Snape referees, unfair penalties for Hufflepuff; Dumbledore in the stands | `[PS 13]` |
| 1992 | Ravenclaw-Gryffindor | R wins comfortably | Gryffindor without a Seeker (Harry in the hospital wing): worst defeat in 300 years | `[PS 17]`, `[CS 7]` |
| Nov. 1992 | Gryffindor-Slytherin | G wins (≈150-60) | Bludger bewitched by Dobby; time-out; broken arm; Slytherin 60-0 up before the catch | `[CS 10]` |
| 1993 | Gryffindor-Hufflepuff | Canceled | Cup canceled because of the basilisk | `[CS 14]` |
| Nov. 1993 | Hufflepuff-Gryffindor | H wins by 100 | Storm; *Impervius*; dementors; Harry falls 50 feet; Nimbus 2000 destroyed; Diggory asks for a rematch, Wood accepts defeat | `[PoA 9]` |
| Feb. 1994 | Gryffindor-Ravenclaw | **230-30** | Firebolt; Harry marks Cho; Malfoy and company disguised as dementors; Patronus | `[PoA 13]` |
| May 1994 | Gryffindor-Slytherin (decider) | **230-20** | Needed +200; Harry waits until they are 50 up; many fouls (blagging by Malfoy, Montague, Bole); Gryffindor wins the Cup | `[PoA 15]` |
| Nov. 1995 | Gryffindor-Slytherin | **160-40** | Ron debuts, nervous; "Weasley is Our King"; Crabbe hits after the whistle; fight; lifetime bans | `[OotP 19]` |
| Feb.-Mar. 1996 | Hufflepuff-Gryffindor | **240-230** | Ginny catches the Snitch and they lose; Ron poor | `[OotP 26]` |
| June 1996 | Gryffindor-Ravenclaw | G wins | Ginny catches the Snitch from under Cho's nose; Ron brilliant; Gryffindor wins the Cup | `[OotP 30]` |
| 1996 | Gryffindor-Slytherin | **250-0** | Harper replaces Malfoy; Ron believes he took Felix Felicis; Zacharias Smith commentates | `[HBP 14]` |
| 1997 | Hufflepuff-Gryffindor | **320-60** | McLaggen instead of Ron; takes Peakes's bat and fractures Harry's skull; Luna commentates (clouds, "Loser's Lurgy") | `[HBP 19]` |
| May 1997 | Gryffindor-Ravenclaw | **450-140** | Ginny as Seeker, Dean as Chaser; Gryffindor wins the Cup on margin | `[HBP 24]` |

### 10.2 1994 World Cup final (Ireland-Bulgaria), in detail `[GoF 8]`

- Stadium built in a year by 500 Ministry employees, 100,000 seats, gold, golden light, Top Box at the halfway point, **giant blackboard** with advertising and scoreboard, velvet programs, **Omnioculars** (10 Galleons) with replay, slow motion, and play-by-play breakdown `[GoF 7-8]`.
- 200 Portkeys in Britain; staggered arrivals (cheap tickets had to arrive two weeks early); campsite with a Muggle manager (Mr. Roberts) whose memory had to be modified several times `[GoF 6-7]`.
- Mascots: **veela** (Bulgaria), who bewitch men and the referee and, when enraged, turn into bird-headed creatures; **leprechauns** (Ireland), who form a giant shamrock and throw gold that vanishes `[GoF 8]`.
- How it unfolded: Troy scores first; two more Irish goals; Ivanova scores for Bulgaria; Krum performs the Wronski Feint, Lynch crashes (time-out for the mediwizards); Ireland reaches 130-10; Zograf commits cobbing → penalty; another scuffle → another penalty; Mostafa is distracted by the veela and then wants to send them off the field; Quigley breaks Krum's nose; Lynch sees the Snitch, but **Krum catches it: 170-160 Ireland** `[GoF 8]`.
- Fred and George's bet with Bagman: "Ireland win but Krum catches the Snitch" `[GoF 7]`.
- Sponsors (according to *Harry Potter Film Wizardry*): Butterbeer, pumpkin juice, Gringotts, Nimbus 2001 `[Film Wizardry]`. Ads on the blackboard: Bluebottle, Mrs. Skower's All-Purpose Magical Mess Remover, Gladrags Wizardwear `[GoF 8]`.

---

## 11. History and world

### 11.1 Timeline of the sport

| Year | Milestone | Source |
|---|---|---|
| 962 | First documented flying brooms in Europe | `[QTTA c1]` |
| 10th c. | Annual Swedish broom race (Kopparberg-Arjeplog, ~300 miles, crosses a dragon reservation; trophy in the shape of a Swedish Short-Snout) | `[QTTA c2]` |
| 1105 | Painting *Günther der Gewalttätige ist der Gewinner* (Stichstock) | `[QTTA c2]` |
| 11th c. (c. 1050) | **Queerditch Marsh**: **Gertie Keddle**'s diary (leather ball, trees as goals, flying rocks; "a great Scottish wizard") | `[QTTA c3]` |
| 12th c. (c. 1150) | **Goodwin Kneen**'s (Yorkshire) letter to his Norwegian cousin Olaf: "Kwidditch", "Catcher", "Blooder", three barrels at each end, 42 goals against Ilkley | `[QTTA c3]` |
| 1269 | **Barberus Bragge** releases a **Golden Snidget** and offers 150 Galleons; **Modesty Rabnott** saves it with a Summoning Charm (fine: 10 Galleons). The "Hunter" (Seeker) and the 150 points are born | `[QTTA c4]` |
| 14th c. | The Snidget becomes a protected species (Elfrida Clagg); Modesty Rabnott reservation in Somerset; **Bowman Wright** invents the **Golden Snitch** | `[QTTA c4]` |
| 1357 | Referee Cyprian Youdle dies (Norfolk) | `[QTTA c6]` |
| 1362/1368 | Playing within 50/100 miles of towns forbidden | `[QTTA c5]` |
| 1385 | Cork team wins in Lancashire | `[QTTA c8]` |
| 1398 | **Zacharias Mumps**: first complete description of the game | `[QTTA c5]` |
| 1419 | "Chained to a dungeon wall" decree | `[QTTA c5]` |
| 15th c. | Reinforced bats; the game reaches Europe (Norway: Ingolfr the Iambic; France: Malecrit) | `[QTTA c6, c8]` |
| 1473 | **First World Cup** | `[QTTA c8]` |
| 16th c. | Lead Bludgers; later iron | `[QTTA c6]` |
| 1538 | Using a wand against the opponent forbidden | `[QTTA c6]` |
| 1620 | *The Noble Sport of Warlocks* (Quintius Umfraville): scoring areas | `[QTTA c6]` |
| 17th c. | Reaches New Zealand (herbologists) and North America; World Cup opened to other continents | `[QTTA c8]` |
| 1652 | **European Cup** | `[QTTA c8]` |
| 1674 | **British and Irish League** (13 teams) | `[QTTA c7]` |
| 1692 | International Statute of Secrecy; ICWQC | `[QTTA c5]`, `[PM-WC]` |
| 1711 | Scarlet Quaffle; Pennifold Quaffle | `[QTTA c6]` |
| 18th c. | Reaches Australia; Abraham Peasegood invents **Quodpot** in the US | `[QTTA c8]` |
| 1750 | The Department's **official rules** | `[QTTA c6]` |
| 1762 | Creaothceann outlawed | `[QTTA c2]` |
| 1814 | The Banchory Bangers disbanded | `[QTTA c5]` |
| 1820 | Cushioning Charm | `[QTTA c9]` |
| 1849 | Automatic forfeit for spells from the crowd | `[PM-2014]` |
| 1875 | Gripping Charms | `[QTTA c6]` |
| 1879 | Oakshaft 79 | `[QTTA c9]` |
| 1883 | **Fixed hoops** instead of baskets | `[QTTA c6]` |
| 1884 | **Stooging Penalty**; the Bodmin Moor Snitch | `[QTTA c6]` |
| 1894 | Appleby supporters' arrows banned | `[QTTA c7]` |
| 1901 | Moontrimmer | `[QTTA c9]` |
| 1926-29 | Cleansweep and Comet: the industrial era of the broom | `[QTTA c9]` |
| 1935 | First Atlantic crossing by broom (Jocunda Sykes) | `[QTTA c9]` |
| 1967 | Nimbus 1000 | `[QTTA c9]` |
| 1993 | Firebolt | `[PM-Firebolt]` |
| 1994 | World Cup at Dartmoor | `[GoF]` |
| 2014 | World Cup in Patagonia | `[PM-2014]` |

### 11.2 Institutions

| Institution | Role | Source |
|---|---|---|
| **Department of Magical Games and Sports** (British Ministry, level 7) | Regulates all sport; headquarters of the League, the Official Gobstones Club, and the Ludicrous Patents Office; untidy, relaxed atmosphere with team posters. Created between 1811 and 1819 (Minister Grogan Stump) according to PM; QTTA links it to 1692/1750. Heads: Hamish MacFarlan (from 1968), Ludo Bagman (until 1995). Chooses referees, suspends players, disbands teams, puts Invisibility Charms on stadiums, confiscates wands | `[OotP 7]`, `[QTTA]`, `[PM]`, `[DP]` |
| **ICWQC** | International regulator; World Cup; 19-volume rulebook; director Royston Idlewind (1971-74); president Mentor Metaxas (Greek, 2014) | `[PM-WC]`, `[PM-2014]` |
| **International Association of Quidditch** | Mentioned in GoF; its "Chairwizard" Hassan Mostafa | `[GoF 8]` |
| **Q.U.A.B.B.L.E.** | Union/governing body of the British league; head Dunbar Oglethorpe | `[Cards]` |
| **Museum of Quidditch** (London) | Holds Gertie Keddle's diary, the Snidget tapestry, Rabnott's letter, medieval brooms | `[QTTA]` |
| **Quality Quidditch Supplies** (Diagon Alley) | Equipment shop; Firebolt prototype in the window; Ireland ordered seven | `[PS 5]`, `[PoA 4]` |
| Splinter and Kreek's | Secondhand brooms | `[DP]` |

### 11.3 Media and commentators

- ***Daily Prophet***: league tables, fixtures, match reports; **Ginny Potter**, senior Quidditch correspondent; Rita Skeeter, gossip columnist `[DP]`, `[PM-2014]`.
- ***Seeker Weekly*** `[GoF]`, ***Which Broomstick?*** (broom reviews: Ron's "*Which Broomstick*") `[OotP 9]`, ***Quidditch Times*** (3,000th issue in 1964) `[QTTA-IE]`.
- Books: *The Beaters' Bible* (Brutus Scrimgeour), *Flying with the Cannons*, *Quidditch Teams of Britain and Ireland*, *The Noble Sport of Warlocks*, *Beating the Bludgers — A Study of Defensive Strategies in Quidditch*, *The Wonder of Wigtown Wanderers*, *He Flew Like a Madman* (Whisp) `[QTTA]`, `[PS]`.
- Radio: Wizarding Wireless Network `[Wiki]`.
- **Commentators**: Lee Jordan (Hogwarts; biased toward Gryffindor, McGonagall corrects him), Zacharias Smith, Luna Lovegood (surreal commentary), Ludo Bagman (1994 final, with *Sonorus*), Ginny Potter and Rita Skeeter (2014 final, live minute-by-minute text) `[books]`, `[PM-2014]`.
- **Omnioculars.** Binoculars with replay, slow motion, play identification ("Hawkshead Attacking Formation", "Dangerous Seeker Diversion"), and **footage used as evidence** by the referee in 2014 `[GoF 7-8]`, `[PM-2014]`.

### 11.4 Supporters, mascots, merchandise, and atmosphere

- Merchandise: luminous rosettes, shamrock hats, scarves, flags, moving player figurines, animated posters, badges (Tornados), jerseys `[GoF 7]`, `[Wiki]`.
- Famous supporters: "Stingers" (Wasps, buzz during penalties), harpists (Kenmare), arrows (Appleby, banned 1894), chants ("Weasley is Our King") `[QTTA c7]`, `[OotP 19]`.
- Crowd violence: riots (Harpies-Puddlemere 1999), jinxes against players (Lundekvam 2014), "Dissimulators" (1974), wand confiscation `[DP]`, `[PM]`.
- **Mascots** (World Cup): veela (Bulgaria), leprechauns (Ireland and Kenmare), trolls (Norway), Selma (Norway 2014), dukuwaqa (Fiji), curupiras (Brazil), sasabonsams (Nigeria), Inferi (Haiti), river spirits (Ivory Coast), yumboes (Senegal), Hans the augurey (Liechtenstein), the hoo-hoo, the Japanese firebird (gift to the US); clubs: Barny the Fruitbat (Bats), Sparky the phoenix (Moutohora); the Banchory Bangers tried to capture a dragon `[PM]`, `[QTTA]`.
- Rituals: the Japanese **burn their brooms when they lose** `[QTTA c8]`; the Moose Jaw Meteorites make spark-trailing flights at the end of every match `[QTTA c8]`; the American celebrations in 2014 required the memories of 2,000 Muggles to be wiped `[PM-2014]`.
- **Betting.** Bagman takes bets (and pays with leprechaun gold); odds published in 2014 `[GoF]`, `[PM-2014]`.

### 11.5 Stadiums and concealment from Muggles

- Mumps's doctrine (1398): "Choose areas of deserted moorland far from Muggle habitations... Muggle-repelling charms are useful if you are laying down a permanent pitch... It is advisable, too, to play at night" `[QTTA c5]`.
- Today: pitches prepared by the Department on moors with anti-Muggle security; teams travel `[QTTA c5]`.
- Canonical techniques: Muggle-repelling charms on "every inch" of the 1994 stadium; **Invisibility Charm** with **re-visibility goggles** (Exmoor) `[DP]`; **midnight** matches; venue changed because of Muggle campers `[DP]`; Portkeys; memory wiping; Muggles report escaped Quaffles as **UFOs** (fines for improper storage) `[DP1]`.
- Stadiums: Hogwarts (stands on towers, practice pitch), the Trillenium Stadium at Dartmoor (1994, 100,000), Patagonia (2014, ornamental lake for the dukuwaqa), the British league's moors. In `[VG-QWC]` each national team has a themed stadium (English castle, Versailles, German walled city, Japanese koi pond, Nordic glacier crevasse, Spanish bullring, Outback canyon, New England farm, Bulgarian castle).

### 11.6 Economy and professionalism (data for manager mode)

| Data point | Value | Source |
|---|---|---|
| Wilda Griffiths's transfer (Harpies → Puddlemere) | **1,000 Galleons** ("poached") | `[DP]` |
| Bragge's original reward | 150 Galleons (≈ "over a million Galleons today") | `[QTTA c4]` |
| Official World Cup guide | 39 Galleons | `[PM-WC]` |
| Omnioculars | 10 Galleons | `[GoF 7]` |
| The twins' bet | 37 Galleons, 15 Sickles, 3 Knuts + a joke wand | `[GoF 7]` |
| Brooms (1890) | 600-5,000 Galleons | `[VG-HL]` |
| Tickets | Cheap ones require arriving two weeks early; Top Box through Ministry connections | `[GoF 6-7]` |
| Named managers | Ragmar Dorkins (Cannons), Philbert Deverill (Puddlemere), Cormack McLeod (Magpies), José Barboza (Brazil), Gwenog Jones (Wales), Franziska Faust (Germany), Arnulf Moe (Norway), Ferdinand Jägendorf (Liechtenstein, "coach and manager"), Charlie Baverstock (NZ), Hector Bolobolo (Fiji, "manager and trainer") | `[DP]`, `[PM-2014]` |
| Coaches | Oddvar Spillum (Norway), Jordanna Bodiment (Harpies, `[VG-MA]`), Madam Hooch supervises practices at Hogwarts | `[PM-2014]`, `[PoA 12]` |
| Manager powers in the canon | Choosing/substituting players for a match (1809), sacking (Maddock), signing (Griffiths, Campbell), selecting veterans (Krum), choosing the mascot (Moe), talking to the press | `[PM-WC]`, `[DP]`, `[PM-2014]` |
| Injuries and medicine | Mediwizards at professional matches; Skele-Gro on the pitch; "few deaths" despite many injuries | `[PM-2014]`, `[Lexicon]` |
| Sponsorship | 1994 World Cup: Butterbeer, pumpkin juice, Gringotts, Nimbus 2001 | `[Film Wizardry]` |

### 11.7 Other broom sports

| Sport | Origin | Rules | Status | Source |
|---|---|---|---|---|
| **Stichstock** | Germany | A **20-foot** pole topped with an inflated dragon bladder; a guardian tied with a rope (max. 10 feet) defends it with his wand; the others try to puncture it with the sharpened ends of their brooms | Died out in the 14th c. | `[QTTA c2]` |
| **Aingingein** | Ireland | Carrying the "Dom" (a goat's gallbladder) through **burning barrels** on stilts and throwing it through the last one; the fastest player who doesn't catch fire wins (Fingal the Fearless, champion) | Ancient | `[QTTA c2]` |
| **Creaothceann** | Scotland | Each player wears a **cauldron on their head**; up to **100 rocks** fall from 100 feet; catch as many as possible | **Illegal since 1762** (failed campaign by Magnus "Dent-Head" Macdonald in the 1960s) | `[QTTA c2]` |
| **Shuntbumps** | Devon, England | Crude jousting: knock the others off; the last one on their broom wins | Children's game | `[QTTA c2]` |
| **Swivenhodge** | Herefordshire, England | Sitting **backward** on the broom, batting a pig's bladder over a hedge with the bristles; whoever misses concedes a point; first to **50** wins | Still played, not very popular | `[QTTA c2]` |
| **Quodpot** | USA (18th c., Abraham Peasegood) | **11 a side**; the "Quod" (modified Quaffle) **explodes**: whoever is holding it when it explodes leaves the pitch; putting it in the "pot" (a cauldron with a solution that defuses it) = **1 point** | Popular in America; a minority sport in Europe | `[QTTA c8]` |
| **Snidget-hunting** | 12th c. | Hunting the Golden Snidget with nets, wands, or bare hands; gold reward | Banned (protected species) | `[QTTA c4]` |
| **Annual Swedish race** | 10th c. | Kopparberg → Arjeplog | Still held, international | `[QTTA c2]` |
| Polo with winged horses | Lord Stoddard Withers (1672-1769) | A mix of Quidditch and polo | Never caught on | `[Cards]` |

---

## 12. The films: differences from the books

| Topic | Books | Films | Source |
|---|---|---|---|
| Pitch | Oval 500×180 feet, 2-foot central circle | Wider, large central circle, **halfway line**; stands on tall **towers** with colored canvas | `[Film]`, `[Wiki]` |
| Boundaries | Crossing the boundary is not allowed | Players fly between and outside the towers; in CS the Bludger chases Harry outside the stadium and under the stands | `[Film]` |
| Quaffle | Perfect sphere, red | Red with **four indentations** | `[Film]` |
| Bludgers | Black iron, 10" (almost the size of the Quaffle) | Dark brown and considerably **smaller**; transported in a chest with rattling chains | `[Film]` |
| Snitch | Golden sphere with wings | Design with thin wings, engraved ornaments | `[Film]` |
| Uniforms | Robes in team colors | Padded robes with leather guards, gloves, goggles; numbers on the back (in QC: Keeper 1, Beaters 2-3, Chasers 4-6, Seeker 7) | `[Film]`, `[VG-QC]` |
| Violence | Fouls are penalized | More tolerance: in PS Marcus Flint **takes a Beater's bat** and hits a Bludger at Wood with no penalty; elbowing (cobbing) between Seekers | `[Film]` |
| PS | Wood explains the rules (ch. 10) | Wood explains using the ball chest; gives Harry a bat and Harry hits well ("you could be a Beater") | `[Film]` |
| PoA | Matches vs Hufflepuff, Ravenclaw, and Slytherin | Only the storm-and-dementors match; Harry receives the Firebolt at the end | `[Film]` |
| GoF | 1994 final narrated play by play | The entrance of the teams and mascots is shown; **the match is not shown**; cut to the campsite | `[Film]` |
| OotP | Ron as Keeper, "Weasley is Our King", bans | **No Quidditch**; Umbridge issues a decree canceling all matches | `[Film]` |
| HBP | Several matches and tryouts | Keeper tryouts (McLaggen Confunded by Hermione), G-S match with Ron's "Felix" and Ginny as Chaser | `[Film]` |
| James Potter | Chaser (JKR) | McGonagall says he was a **Seeker** | `[Film]` |
| Brooms | Nimbus 2001 with no described color | Black and silver Nimbus 2001 with swiveling stirrups | `[Film]` |
| Cannons | League member since 1674 | Crest with "Est. 1753" | `[Prop]` |
| 1998 World Cup | Malawi champions (JKR) | DH1: *The Quibbler* headline "World Cup canceled amid death threats" | `[Film]` vs `[PM-WC]` |

---

## 13. Video games: how they adapted the rules

### 13.1 *Harry Potter: Quidditch World Cup* (EA, 2003) `[VG-QWC]`

- **Teams.** 4 houses + 9 national teams (England, France, Germany, Spain, Bulgaria, which is unlockable, Scandinavia, USA, Australia, Japan). Set in 1993-94.
- **Controls.** Almost all the time you control the **Chasers** (pass, shoot, charged shot, tackle). The Keeper who concedes restarts play.
- **Snitch bar (momentum).** Each team fills its half of a bar by completing passes (more if charged) and **combos** (chains of passes/volleys, max. 8, which are "banked" when scoring or retaining possession). **When the two halves meet, the Snitch appears** and control passes to the Seekers, who race in a chase with boost proportional to the accumulated momentum. **During the chase the score is frozen**. Catching it = **150 points** and the end.
- **Mechanics that lower the opponent's bar**: player-directed **Bludger** attack (wins back possession and lowers the opponent's bar slightly), individual **special move** (cinematic steal or unstoppable shot), and **team special play** (several unstoppable goals; greatly lowers the opponent's bar). See §5.4.
- **Competitions.** Single round-robin Hogwarts Cup (3 matches) with training sessions that unlock mechanics; World Cup as a **16-match home-and-away league** (each opponent at home and away). **Standings are decided by total points**, as in the books.
- **Difficulty** tied to brooms: Comet 260, Nimbus 2000, Nimbus 2001, Firebolt.
- **Altered rules.** The scoring area does not limit entry to one Chaser (stooging effectively allowed); plays with several goals in a row.
- **Balance.** The Snitch bar means that **the Seeker only comes into play when the team plays well** and that **match length depends on the Chasers' play**, not on chance.

### 13.2 *Harry Potter: Quidditch Champions* (Unbroken Studios / Portkey Games, 2024) `[VG-QC]`

| Rule | Book | *Quidditch Champions* |
|---|---|---|
| Players | 7 (2 Beaters) | **6** (a single Beater); JKR expressly authorized it |
| Snitch | 150 pts, ends the match | **30 pts** and **does not end** the match (except in overtime) |
| End | Only with the Snitch | **On time** or when a team reaches **100 points** (100 can be exceeded if the Snitch is caught with 80+) |
| Tie at the end of time | | **"Golden score" overtime**: the next goal or the Snitch wins |
| Snitch appearance | From the start | Appears **some time after** kickoff; the Seekers come on to look for it and leave after the catch (there can be more than one Snitch per match) |
| Keeper | Protected unless the Quaffle is in the area | Not protected; untouchable, however, when holding the Quaffle after a save |
| Stooging | Forbidden | **Allowed** |
| Back pass | | You can pass to your own Keeper |
| Own goal | | Does not count |
| Boundaries | Side boundary, no ceiling | Invisible walls and a ceiling |
| Bludgers | Unseat players | Health bar; when depleted the player is dazed and may fall |
| Carrying the Quaffle through the hoop | Haversacking | Forbidden |

- The specialist press summed it up as "*after 27 long years, Quidditch Champions finally acknowledges that Quidditch is a dumb sport — by hard-nerfing the Golden Snitch*" (GamesRadar).
- House styles: Gryffindor **balanced**, Hufflepuff **defensive**, Ravenclaw **strategic**, Slytherin **aggressive**.
- Tournaments: Weasley Burrow Garden Cup (tutorial) → House Cup → Triwizard Schools Quidditch Cup → World Cup.

### 13.3 *Hogwarts Mystery* (2018-) `[VG-HM]`

- Quidditch added in 2019; seasons by position (Chaser → Beater → Keeper → Seeker), "friendlies" for practice, cup matches, plays learned through chapters (Parkin's Pincer, Thimblerig Shuffle, etc.).
- Contributes worldbuilding: **substitutes** (Ravenclaw's reserve Keeper/Seeker), players who turn professional (Wigtown recruits a newly graduated Keeper as a reserve), interim captains, a **suspension for bad grades** (Bean), the 1966-67 final (570-580, the highest in Hogwarts history), commentator Murphy McNully.
- I could not verify the match mechanics in detail (see §18).

### 13.4 *Hogwarts Legacy* (2023) `[VG-HL]`

- **There are no Quidditch matches.** Headmaster Phineas Nigellus Black **cancels the 1890-91 season** after a (pure-blood) student was injured in the previous final; flying instructor Chiyo Kogawa protests.
- Contributes: the Spintwitches broom shop (prices 600-5,000 G), timed **flying trials** (Imelda Reyes, Slytherin captain), **upgradable** brooms, the Japanese club Toyohashi Tengu, and the anecdote about Felix Felicis in a tryout.

### 13.5 Other games

| Game | Quidditch | Source |
|---|---|---|
| *Philosopher's Stone* / *Chamber of Secrets* (EA, 2001-02) | Seeker-focused matches: following the Snitch's trail through rings; Quidditch Cup; in PS (GBA) Gryffindor 180-20 Hufflepuff | `[VG-film]` |
| *Prisoner of Azkaban* / *Goblet of Fire* (EA) | No playable matches (the PoA match appears in cutscenes) | `[VG-film]` |
| *Order of the Phoenix* (EA, 2007) | No matches | `[VG-film]` |
| *Half-Blood Prince* (EA, 2009) | Matches as Seeker (flight guided by rings/trail) | `[VG-film]` |
| *Magic Awakened* | Flying on the pitch, scoring on courses; Harpies players (Zola Farrell), coach Bodiment | `[VG-MA]` |
| *Wizards Unite* | Leagues (Japanese, Polish, Canadian, All-Africa) mentioned in the registry | `[VG]` |
| Famous Wizard cards (EA) | Plumpton, Wadcock, Gwenog Jones, Youdle, Smethwyck, Bowman Wright, Devlin Whitehorn, Dunbar Oglethorpe, Fabius Watkins (written by JKR) | `[Cards]` |
| *Trading Card Game* (WotC, 2001) | Quidditch cards with play names (Body Blow, Check, Power Play, Spiral Dive, Twirl, Blocking) | `[TCG]` |

---

## 14. *Fantastic Beasts*, *The Cursed Child*, and other sources

- ***Fantastic Beasts*** (1926 newspaper props) `[FB]`/`[Prop]`: *The New York Ghost* announces the **US league Grand Final** Fitchburg Finches vs Sweetwater All-Stars "on the first full moon of Aquarius"; a disqualified Seeker regrets using an "unlawful elixir"; the Finches "score high" in the league; a French newspaper puts **Beauxbatons first in the European Quidditch League**; Ilvermorny has a **Quidditch Cup** (Pukwudgie 1926); ads for Brooklyn Brooms and McTawny Broomsticks. Newt tells Mary Lou Barebone he is "*more of a Chaser*" `[FB1]`. Snitches and Bludgers among the decoy objects in the suitcase in *Secrets of Dumbledore* `[Wiki]`.
- ***Harry Potter and the Cursed Child*** `[CC]`: Albus Potter is terrible at flying (humiliated in flying class); Rose Granger-Weasley joins the Gryffindor team as a Chaser `[Wiki]`; Scorpius and Albus don't play.
- **JKR's writings on Pottermore**: McGonagall (a Montrose Magpies fanatic; injured by a Slytherin foul in her last, decisive match), Mahoutokoro, Castelobruxo, Firebolt, History of the World Cup, 2014 World Cup `[PM]`.
- **Editions of QTTA.** The illustrated edition (Emily Gravett, 2020) and the 2017 reissue add minor material (e.g., the *Quidditch Times* cover with Catriona McCormack) `[Wiki]`.
- **JKR on the design of the sport.** She invented it after an argument with her boyfriend in a Manchester hotel; "*I always wanted to see a game where there was more than one ball in play at the same time*"; "what I like most is the violence"; she acknowledged that the Snitch's disproportion "**exasperates**" many readers (men above all) `[Lexicon]`, `[PM-feature]`, Guardian 2013.

---

## 15. Real-world quadball (formerly "muggle quidditch"): **separate section, not canon**

Only what contributes balance ideas `[Real]`:

| Aspect | IQA (international) | US Quadball / Major League Quadball |
|---|---|---|
| Name | "Quidditch" (2005, Middlebury College) → **Quadball** (2022) to avoid trademark problems with WB and distance itself from JKR | Same |
| Players | 7 per team (3 Chasers, 1 Keeper, 2 Beaters, 1 Seeker); squad of up to **21** | Same |
| Substitutions | **Unlimited, at any time**, from behind the keeper zone | Same |
| Pitch | Rectangle of **60 × 33 m**; 3 hoops per side at heights of 0.91 / 1.37 / 1.83 m | Same |
| Balls | Quaffle (deflated volleyball), **3 bludgers** (dodgeballs) for 4 Beaters (one Beater always without a ball → "bludger control") | Same |
| Goal | 10 points; can be scored from the front or the back | Same |
| Bludger hit | The player hit **drops the ball, dismounts, and must touch their own hoops** before returning | Same |
| Snitch / flag | **Flag** (formerly snitch): a tennis ball in a sock hanging from the shorts of a neutral **"flag runner"** who evades the Seekers | Same |
| Value | **30 points** | **35 points** |
| Seeker floor | Neither flag runner nor Seekers during the **first 20 minutes** (formerly 17); the runner enters at 19', the Seekers at 20' | 20 minutes |
| End | The catch ends the match; if the catching team ends up **level or behind**, there is **overtime** with a target of "opponent's points + 30" | **"Set score"**: at minute 20 a target is set = leader's score **+60**; the first to reach it wins (MLQ) |
| Flag runner handicaps | At 25' must stay near midfield; at 30' may use only one arm; at 35' further restrictions | Variants |
| Sanctions | Back-to-hoops, **blue** card (1 minute or until the next goal), **yellow**, **red**; penalty box | Same |
| Gender rule | Max. 4 (since 2024: 3 during seeker floor and overtime) players of the same gender on the pitch | Same |
| Emergent strategy | Teams that are behind **defend the flag** to delay the catch; teams that are ahead want to catch quickly | |

---

## 16. Balance problems of the sport and known solutions

### 16.1 The criticisms

1. **The Snitch is worth too much.** 150 points = 15 goals, and it also ends the match. "*It's like a soccer match where there's a little chocolate bunny hidden somewhere on the field which will give you 15 points and end the game*" (blogger quoted by the Lexicon). The Seeker "overshadows" the other six `[Lexicon]`.
2. **"Only the Seekers matter".** In the canon, the catching team almost always wins (≈93% in 2014, see §3.10).
3. **Indefinite duration.** From 3.5 seconds to months; matches suspended overnight; spectators "feel cheated" if it ends in 5 minutes `[QTTA c10]`.
4. **Perverse incentives.** The Seeker of a team losing by more than 150 should **avoid** catching the Snitch; one whose team is narrowly behind may want to **close it out** (Krum 1994) to limit the margin; in leagues with accumulated points, it pays to **drag out** the match if your Chasers are dominating (the Lexicon speculates that Slytherin "bribed" Ravenclaw to prolong a match).
5. **Exhaustion.** Without substitutions, long matches degrade performance (Liechtenstein-Chad).
6. **Inconsistent arithmetic** in the Hogwarts Cup canon (§8.4).

### 16.2 Defenses within the canon

- **Leagues add up points, not wins.** Goals count even if you lose; this "makes the sport less unbalanced than it seems" (Lexicon, "Who says Quidditch is stupid?") `[Lexicon]`, `[DP]`.
- **Margin matters.** Hogwarts (PoA 15, HBP 24) and the World Cup (bonus for 50/100/150) reward winning big, so Chasers have strategic value and the Seeker must **choose the moment** to catch.
- **The Seeker decides when.** Wood orders Harry not to catch until +50; Krum in 2014 refuses the Snitch until his team overturns a 250-point deficit. The "timing" of the catch is a tactical decision with a canonical basis.
- **4-hour cap in the World Cup groups** and resolution by goals `[PM-WC]`.
- **Tiebreak by catches** (more catches or faster ones) `[PM-WC]`.
- **Snitch countermeasures**: Beaters against the opposing Seeker ("Take out the Seeker"), marking the Seeker (Harry on Malfoy), protecting your own Seeker (Vulchanov), Wronski Feint.

### 16.3 Video game solutions

| Game | Solution |
|---|---|
| *Quidditch World Cup* (2003) | The Snitch only appears when **the Chasers' play fills a momentum bar**; momentum also gives an advantage in the chase; defensive plays drain the opponent's bar; score frozen during the chase |
| *Quidditch Champions* (2024) | Snitch worth **30 points** without ending the match; match **on time** or to **100 points**; Snitch that **appears late**; golden score |
| Film tie-in games | They simply separate the "Seeker match" from the rest |

### 16.4 Real quadball solutions

- Reduced value (**30/35**), 20-minute **seeker floor**, **progressive handicaps** on the runner so the match doesn't drag on forever, **overtime** if the catch doesn't produce a win, **set score +60** (MLQ), **unlimited substitutions**.

### 16.5 Recurring fan proposals `[fan]`

(Collected from forums and articles; not canon, only as an inventory of ideas): lower the Snitch to 30-50 points; have the Snitch not end the match but open a "final phase"; allow it to be caught only after X minutes or after X goals; make it worth more the longer the match lasts, or less if the match is short; timed matches with the Snitch as a "bonus"; leagues with points per win plus a bonus for margin (like JKR's World Cup).

---

## 17. Contradictions between sources

| Topic | Version A | Version B | Comment |
|---|---|---|---|
| Substitutions | QTTA rule 5: no substitutions for injury | Wood: 3-month record with substitutes so players could sleep | See §3.6 |
| Longest match | Wood: **3 months** (record) `[PS 10]` | QTTA: Snitch at large for **6 months** on Bodmin Moor (1884), unfinished `[QTTA c6]` | The Bodmin match didn't end with a catch (abandoned); they are compatible if the "record" refers to finished matches |
| Number of common fouls | QTTA: **10** | Wiki: 11 | Wiki error |
| Hoop height | **50 feet** (1994 World Cup) `[GoF 8]` | ~30 feet `[Wiki]` | May vary by stadium |
| Founding of the Department | QTTA: rules set "by the Department on its formation, **1750**" | PM: created under Grogan Stump (**1811-1819**) | JKR's internal contradiction |
| Year of the bans on playing near towns | QTTA: 1362, 1368, 1419 | Wiki: "1398 Mumps, 1362/1368" mixed up | Use QTTA |
| Founding of the Chudley Cannons | QTTA: in the league since 1674 | Film crest: "Est. 1753" | Prop |
| Winner of the 1473 World Cup | QTTA doesn't say | Wiki: Transylvania | No primary source |
| Date of the 1994 final | Wiki: August 18 or 22 | Lexicon: August 25 | Fuzzy GoF chronology |
| 1998 World Cup | PM: **Malawi** champions | DH1 film: World Cup **canceled** | JKR canon prevails |
| World Cup numbering | Every 4 years since 1473 → ~135th edition in 2014 | **422nd** (1994) and **427th** (2014) | JKR inconsistency (Lexicon theories) |
| Brazil 1982 | Wiki: "reached the 1982 final" | PM-2014: "their first final since 1982" (canon that confirms it) | Consistent |
| Hogwarts scoring | PoA 15: total points | HBP 24: margin matters; impossible figures | See §8.4 |
| James Potter | Chaser (JKR) | Seeker (film) | |
| Attacking the Keeper | Forbidden unless the Quaffle is in the area `[PoA 15]` | QC: the Keeper is not protected | Video game |
| Stooging | Forbidden (goal disallowed) | QWC and QC allow it | Video games |
| Date of the Snitch | QTTA c4: the Snidget becomes protected and Bowman Wright invents the Snitch in the **mid-14th century** (Elfrida Clagg's Wizards' Council) | JKR's cards: Bowman Wright **1492-1560**; Elfrida Clagg **1612-1687** (the wiki hedges with "between 1396 and 1560") | Affects the timeline in §11.1 |
| Dating of the Silver Arrow | QTTA c9: later than the Moontrimmer (1901) | *Hogwarts Legacy*: on sale in 1890 for 5,000 G | Video game vs canon |
| Wollongong / Woollongong | QTTA: "Woollongong" | Real city and wiki: "Wollongong" | Spelling |
| Teams | 7 players | QC: 6 | Video game, authorized by JKR |
| Snitch and end of match | Ends the match | QC: does not end it (except in overtime) | Video game |

---

## 18. What I could not verify

- **Official Spanish translations** of most plays, fouls, and brooms (I only verified *quaffle*, *bludger*, *snitch dorada* in a source; the rest is from memory of the Salamandra edition: "Amago de Wronski", "Saeta de Fuego", "Barredora", "Cometa", "Estrella Fugaz"). It would be worth checking against a copy of *Quidditch a través de los tiempos* (Salamandra) for the names of fouls and plays.
- **Tiebreak rule** (a tie when the Snitch is caught). No source explains it, although draws exist.
- **Whether the British league has a final or playoff.** Only a film poster suggests it.
- **How many matches each team plays per season** and how long the season lasts.
- The actual **internal dates** of the *Daily Prophet* newsletters (published 1998-99 vs 1992-93 according to the Lexicon).
- **Exact height and diameter of the hoops** in the rules (there is only "50 feet" for the 1994 stadium).
- **Pitch dimensions in the films**.
- The wiki's claim that the 1990 final lasted **five days** (I did not find it in JKR's text).
- **Detailed match mechanics in *Hogwarts Mystery*** and the **broom attributes/stats** in *Hogwarts Legacy* and *Quidditch Champions*.
- Fine details of the book match accounts cited from memory (e.g., Lee Jordan's exact words about not attacking the Keeper, PoA 15; who scored each penalty in GoF 8).
- Price of the Nimbus 2000/2001 and the Firebolt (only "price on request").

---

## 19. Sources

Primary (text consulted):
- *Quidditch Through the Ages* (Kennilworthy Whisp / J.K. Rowling, 2001), full text consulted: https://archive.org/details/quidditch-through-the-ages_jkr
- History of the Quidditch World Cup (J.K. Rowling): https://www.harrypotter.com/writing-by-jk-rowling/history-of-the-quidditch-world-cup
- Quidditch World Cup 2014: Daily Prophet reports (J.K. Rowling): https://www.harrypotter.com/writing-by-jk-rowling/quidditch-world-cup-2014-daily-prophet-reports
- Quidditch World Cup 2014: Final live report (J.K. Rowling): https://www.harrypotter.com/writing-by-jk-rowling/quidditch-world-cup-final-live-report
- Firebolt (J.K. Rowling): https://www.harrypotter.com/writing-by-jk-rowling/firebolt
- A few things you might not know about Quidditch: https://www.harrypotter.com/features/things-you-might-not-know-about-quidditch
- Quidditch comes to Hogwarts Mystery: https://www.harrypotter.com/news/quidditch-comes-to-harry-potter-hogwarts-mystery

Harry Potter Lexicon:
- Quidditch: https://www.hp-lexicon.org/thing/quidditch/
- An Almanac of Quidditch at Hogwarts: https://www.hp-lexicon.org/2007/07/18/an-almanac-of-quidditch-at-hogwarts/
- Unusual Quidditch Matches: https://www.hp-lexicon.org/2008/02/22/unusual-quidditch-matches/
- Who says Quidditch is stupid? (league tables from the Daily Prophet Newsletters): https://www.hp-lexicon.org/2014/06/17/says-quidditch-stupid/
- How many Quidditch World Cups have there been anyway?: https://www.hp-lexicon.org/2014/07/14/many-quidditch-world-cups-anyway/
- The Changing Quidditch World Cup Schedule: https://www.hp-lexicon.org/2018/03/14/changing-quidditch-world-cup-schedule/
- Famous Wizard Cards: https://www.hp-lexicon.org/2016/12/29/famous-wizard-cards/

Harry Potter Wiki (Fandom), pages consulted via API (https://harrypotter.fandom.com/wiki/...): Quidditch, Quaffle, Bludger, Golden_Snitch, Golden_Snidget, Keeper, Chaser, Beater, Seeker, Quidditch_pitch, Goalpost, Scoring_Circle, Blagging, Blatching, Blocking, Blurting, Bumphing, Cobbing, Flacking, Haversacking, Quaffle-pocking, Snitchnip, Stooging, Quidditch_referee, Quidditch_Captain, Beater's_bat, Quidditch_World_Cup, 1994_Quidditch_World_Cup, 2014_Quidditch_World_Cup, British_and_Irish_Quidditch_League, League_Cup, European_Cup, Inter-House_Quidditch_Cup, Department_of_Magical_Games_and_Sports, International_Confederation_of_Wizards_Quidditch_Committee, Quidditch_commentator, Hassan_Mostafa, the 13 league teams + Banchory_Bangers + Puddlemere_United_reserve_team, the play pages (Category:Quidditch_tactics), broom pages (Category:Broomsticks) and manufacturers, all national teams (Category:National_Quidditch_teams), the international clubs (Category:Quidditch_teams), Viktor_Krum, Ludovic_Bagman, Oliver_Wood, Gwenog_Jones, Aidan_Lynch, Josef_Wronski, Dai_Llewellyn, Roderick_Plumpton, Catriona_McCormack, Joscelind_Wadcock, Murphy_McNully, Harry_Potter:_Quidditch_Champions, Harry_Potter:_Quidditch_World_Cup, Quidditch_in_Harry_Potter:_Hogwarts_Mystery, Hogwarts_Legacy, Phineas_Nigellus_Black, Imelda_Reyes.
- Direct examples: https://harrypotter.fandom.com/wiki/Quidditch · https://harrypotter.fandom.com/wiki/Harry_Potter:_Quidditch_Champions · https://harrypotter.fandom.com/wiki/2014_Quidditch_World_Cup_final

Video games and press:
- GamesRadar, "After 27 long years, Harry Potter: Quidditch Champions finally acknowledges that Quidditch is a dumb sport": https://www.gamesradar.com/games/sports/after-27-long-years-harry-potter-quidditch-champions-finally-acknowledges-that-quidditch-is-a-dumb-sport-by-hard-nerfing-the-golden-snitch/
- Push Square, "Snitch has been dramatically nerfed": https://www.pushsquare.com/news/2024/08/harry-potter-quidditch-champions-snitch-has-been-dramatically-nerfed-on-ps5-ps4
- Screen Rant, Snitch rule change: https://screenrant.com/quidditch-champions-golden-snitch-rule-change/
- Game Rant: https://gamerant.com/harry-potter-quidditch-champions-catching-golden-snitch-wont-end-game/
- Wikipedia, *Harry Potter: Quidditch World Cup*: https://en.wikipedia.org/wiki/Harry_Potter:_Quidditch_World_Cup
- Wikipedia, *Harry Potter: Quidditch Champions*: https://en.wikipedia.org/wiki/Harry_Potter:_Quidditch_Champions

Real quadball:
- Wikipedia, Quadball: https://en.wikipedia.org/wiki/Quadball
- IQA Rulebook 2024: https://www.iqasport.org/wp-content/uploads/2024/08/IQARulebook2024.pdf
- US Quadball, How to play: https://www.usquadball.org/how-to-play
- Major League Quadball, Scoring: https://www.mlquadball.com/rules/scoring
- US Quadball 24-25 Rulebook: https://www.usquadball.org/news/us-quadball-24-25-rulebook-release

Criticism and analysis:
- HubPages, "10 Reasons Why Quidditch From Harry Potter Is a Terrible Sport": https://discover.hubpages.com/literature/Why-Quidditch-From-Harry-Potter-Is-a-Terrible-Sport
- CBR, "Quidditch in Harry Potter, Explained": https://www.cbr.com/harry-potter-quidditch-explained/
