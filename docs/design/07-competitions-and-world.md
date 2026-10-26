# 07: Competitions and world

> Sources abbreviated as in `docs/research/02-quidditch.md`: `[PS n]`…`[DH n]` books by chapter; `[QTTA cN]` *Quidditch Through the Ages*; `[PM-WC]` history of the World Cup (Pottermore); `[PM-2014]` reports from the 2014 World Cup; `[PM]` other JKR writings; `[DP]` *Daily Prophet* newsletters (1998-99); `[Cards]` trading cards; `[Prop]` film props (not canon); `[VG-*]` video games (not canon); `[Inference]` inference from the canon; **[FILLER]** our own invention, with a note on its inspiration.
>
> Rule: anything not in the books, QTTA or JKR's writings is marked **[FILLER]**. Where the canon is silent we pick the minimal option most compatible with the lore. No sport rules are invented.

---

## 1. Timeline and start year

### 1.1 Default season: 1993-94

The game starts in **August 1993**. Reasons (see `03-key-findings.md`, A4):

| What happens in 1993-94 | Source |
|---|---|
| Hogwarts has a full season: Oliver Wood's last as captain, Gryffindor wins the Cup after seven years | `[PoA]` |
| The **Firebolt** comes out (summer 1993); Harry receives one at Christmas | `[PoA 4, 11]` |
| The **1994 World Cup** (422nd edition) is played at **Dartmoor** in August 1994: it closes the player's first season | `[GoF 5-8]`, `[PM-WC]` |
| Viktor Krum is 17 and a Durmstrang student; he debuts for Bulgaria at 18 in that World Cup | `[GoF 7-8]` |
| Wood graduates in June 1994 and signs for the **Puddlemere United reserve team** | `[GoF 7]` |
| Ludo Bagman heads the Department of Magical Games and Sports | `[GoF 7]` |

### 1.2 Fixed history and open world

- **Before August 1993.** Everything is **fixed canon**. Honours, records, earlier World Cups (1990 Canada, 1966 Australia, 1974 Syria…), foundings, retired legends. It is loaded as the history of each club, player and competition.
- **From August 1993.** Everything is **simulated by the engine**. Nothing is scripted: Ireland may not win the 1994 World Cup, Gryffindor may lose the Cup. It is an open world with endless seasons.
- **Canon seeds** [FILLER, our mechanism]. Named players who appear later in the canon (2014 World Cup: Bogomil Levski, Noriko Sato, Tony Silva…, Ginny Weasley at the Harpies) exist in the database with their estimated birth date and enter the world when their time comes: as students at their regional school or as youngsters at a plausible club. The simulation decides what career they go on to have. So a player starting in 1993 crosses paths with the 2014 names as they grow up, without forcing results.
- **Canon institutional events** [our mechanism; **approved**: option A with the toggle on by default]. Facts that do not depend on any result and happen in the books no matter what, such as the **suspension of Quidditch at Hogwarts in 1994-95 for the Triwizard Tournament** `[GoF 12]`. Option A: they are reproduced as calendar events (more faithful to the lore; costs Hogwarts one youth season). Option B: they are not reproduced (pure open world). Recommendation: option A with a "Book events" toggle on by default.

### 1.3 Other start years (data packs / DLC)

| Pack | Season | What it offers | Source |
|---|---|---|---|
| Base | **1993-94** | What is described above | |
| "The Prince" | 1996-97 | Harry as captain, Ginny as Chaser, Wood a professional, Gorgovitch at the Cannons; the 1998 World Cup falls in the second season | `[HBP]`, `[DH 7]`, `[PM-WC]` |
| "Patagonia" | 2014-15 | Fuller canon rosters (Bulgaria, Brazil, Japan, USA, Wales, Norway, Nigeria, Liechtenstein…); Krum a champion and about to retire (38); Ginny Potter a journalist; Gwenog Jones manager of Wales; Toyohashi wins the Champion's League shortly after | `[PM-2014]`, `[PM-Mahoutokoro]` |
| "1926" | 1926-27 | US league (Fitchburg vs Sweetwater, "Grand Final"), Ilvermorny with a house cup, Beauxbatons leading a European league; first Cleansweep (1926) | `[FB]`/`[Prop]` (adaptation, not the books), `[QTTA c9]` |

Each pack is a set of data files (see `09-data-model.md`); the code does not change.

---

## 2. British and Irish Quidditch League

### 2.1 Competition rules

| Aspect | Rule | Source |
|---|---|---|
| Founding | 1674: the Department picked the 13 best teams; the rest had to disband | `[QTTA c7]` |
| Teams | **13** (the Banchory Bangers, disbanded in 1814, are not included) | `[QTTA c5, c7]` |
| Trophy | **League Cup**, contested every year | `[QTTA c7]` |
| Standings | **Accumulated points scored** (sum of the points each team scores in every match, goals + Snitch); no wins column | `[DP1-DP4]`, decision A3 |
| Table tiebreak | Fewer points conceded; then more Snitch catches | **[FILLER]** (no canon rule; we chose criteria already present in the sport: margin matters at Hogwarts `[HBP 24]`, catches break ties at the World Cup `[PM-WC]`) |
| Drawn matches | They exist and count (Cannons-Catapults; Proudsticks-Magpies 1986) | `[DP]`, `[QTTA c8]` |
| Rounds | **Double round-robin: 24 matches per team, 156 in total** | **[FILLER-inference]**: the Cannons' run of 16 straight defeats exceeds the 12 opponents of a single round `[DP]`; there are tables in July, February, June and October |
| Calendar | **August to June**, one matchday every 1-2 weeks, with gaps for the European Cup and international call-ups | **[FILLER]**; canon fixtures show matches on Friday, Saturday and Monday at varied times (11:00, midnight) `[DP]` |
| Venues | **No home stadiums**: teams travel to pitches prepared by the Department with anti-Muggle security on moors: Bodmin Moor, Exmoor (new stadium with an Invisibility Charm), Ilkley Moor, Yorkshire Moors, Ellis Moor | `[QTTA c5]`, `[DP]` |
| Home advantage | There is no stadium-based home advantage. The club has a **training base** in its town and a traveling fan base; the "home" effect is the proximity of the assigned moor and the number of fans | `[Inference]` from the above; see `03` B7 |
| Individual award | **Dangerous Dai Commemorative Medal**: to the player who took the most exciting and reckless risks of the season | `[QTTA c7]` |
| Other award | *Josef Wronski Award for Excellent Pitch Skills*: secondary award to the player with the best technique of the season (our criterion) | `[Prop]` (Cannons crest from the films; **included** by design decision, marked as film) |
| Governing bodies | Department of Magical Games and Sports (seat of the league, level 7 of the Ministry) `[OotP 7]`; Q.U.A.B.B.L.E. (Dunbar Oglethorpe) `[Cards]` | |
| Amateurs | Allowed outside the league if they meet the Department's requirements | `[QTTA c7]` (not simulated in v1) |
| Promotion/relegation | **None**: the league has been closed since 1674 | `[QTTA c7]` |

In the game each club has a home ground **[game, FILLER]** (`data/shared/grounds.json`: its region's landscape plus its city, with stands sized by level); club matches are played there and finals at a neutral venue. The canon rows of this table describe the books.

Points scale: a canon match gives each team 170-610 points (`02` §3.10). With 24 matches, season totals land around 5,000-7,000. The *Daily Prophet* tables (230-820) are read as a loose approximation by JKR; we do not calibrate against them.

### 2.2 The 13 clubs

All data is `[QTTA c7]` unless stated. "Canon players active in 1993-94": the *Daily Prophet* newsletters are dated 1998-99 but their internal chronology is 1992-93 according to the Lexicon, so their players are considered active in 1993-94 `[DP]`+`[Inference]`. Ages: estimated **[Inference]** unless there is a canon date.

| Club | Town | Founded | Colors / emblem | Canon honours | Identity | Rivalry | Canon players and staff active in 1993-94 | Tier |
|---|---|---|---|---|---|---|---|---|
| **Montrose Magpies** | Montrose, Scotland | ? | Black and white; magpie on chest and back | **32 leagues** (record), **2 European Cups** | The most successful club; fans all over the world; McGonagall's club `[PM]` | | C Alasdair Maddock (fan of Muggle football, ~25); S Lennox Campbell (~24); manager Cormack McLeod `[DP]` | **Big** |
| **Ballycastle Bats** | Ballycastle, Northern Ireland | ? | Black; scarlet bat | **27 leagues** | Mascot Barny the Fruitbat (face of the Butterbeer ads) | | Finbar Quigley (position not stated, ~27) `[DP2]` | **Big** |
| **Puddlemere United** | River Piddle, Dorset | **1163** (oldest) | Navy blue; two crossed golden bulrushes (formerly mud brown, changed in 1998 `[DP]`) | **22 leagues**, **2 European Cups** | Anthem "Beat Back Those Bludgers, Boys, and Chuck That Quaffle Here"; has a **reserve team** `[GoF 7]` | Holyhead Harpies `[DP]` | S Benjy Williams (~26); manager Philbert Deverill `[DP]`; **Oliver Wood** joins the reserves in summer 1994 (K, 18) `[GoF 7]` | **Big** |
| **Tutshill Tornados** | Tutshill, West of England | **1520** | Sky blue; double dark-blue T | 5 straight leagues in the early 20th century (record) | Leaders in autumn 1995 `[OotP 12]` and in 1998 `[DP1]`; "they only support them since they started winning" (Ron) | | Captain Brevis Birch (~30); K Mervyn Fenwick (narcoleptic, ~28) `[DP]` | **Big** (rising) |
| **Caerphilly Catapults** | Caerphilly, Wales | **1402** | Light-green and scarlet vertical stripes | **18 leagues**, **1956 European Cup** | Legend "Dangerous" Dai Llewellyn; medal in his honor | | C Angus Campbell (~27; moves to the Magpies in 1999) `[DP]` | Mid |
| **Wimbourne Wasps** | Wimbourne, West Country | **1312** | Yellow and black horizontal stripes; wasp | **18 leagues**; 2 European Cup semifinals | "Stingers" fans who buzz during penalties; 3 straight leagues with Bagman (1970s-80s) `[GoF 7]` | **Appleby Arrows** (fierce) | No named active player (Bagman retired, at the Ministry) | Mid (declining: 12th in 1998 `[DP1]`) |
| **Holyhead Harpies** | Holyhead, Anglesey, Wales | **1203** | Dark green; golden talon | No known leagues; 7-day match won against Heidelberg (1953) | **Witches only** (unique in the world); violent fans (Ilkley Moor riot) `[DP]` | **Puddlemere United** `[DP]` | B/capt **Gwenog Jones** (b. 1968 → 25; at the club since 1986) `[Cards]`, `[HBP 4]`; C Wilda Griffiths (~24); C Valmai Morgan (~22) `[DP]`. Ginny Weasley arrives in the 2000s | Mid |
| **Kenmare Kestrels** | Kenmare, Kerry, Ireland | **1291** | Emerald green; two yellow Ks | No known titles | Leprechaun mascots; fans with harps; Seamus Finnigan's team `[OotP 11]`; legend Darren O'Hare (K 1947-60) | | No named active player | Mid |
| **Pride of Portree** | Portree, Isle of Skye | **1292** | Purple; golden star | **2 leagues** (1960s, with Catriona McCormack) | "Prides" fans | | K **Meaghan McCormack** (Catriona's daughter, ~24); S Dougal McBride (~23) `[DP]` | Mid |
| **Appleby Arrows** | Appleby, Cumbria | **1612** | Pale blue; silver arrow | Victory over the Vratsa Vultures in 1932 (16 days) | Fans who used to fire arrows (banned 1894) | **Wimbourne Wasps** | S Gregory Cotton (~22) `[DP3]` | Mid |
| **Wigtown Wanderers** | Wigtown, Scotland | **1422** | Blood red; silver meat cleaver | No known titles | Founded by the 7 children of butcher Walter Parkin; "there is nearly always a Parkin on the team"; Kennilworthy Whisp's team | | A **Parkin** in the squad **[FILLER guided by canon]** (name to be generated) | Small |
| **Falmouth Falcons** | Falmouth, Cornwall | ? | Dark gray and white; falcon head | No known titles | Hard play: "Let us win, but if we cannot win, let us break a few heads"; the Broadmoors (14 suspensions, 1958-69) | | No named active player | Small (last in 1999 `[DP4]`) |
| **Chudley Cannons** | Chudley | ? (founder 1674) | Orange; cannonball and black double C | **21 leagues, the last in 1892** | Motto since 1972: "Let's all just keep our fingers crossed and hope for the best"; Ron's club; 16 straight defeats `[DP]` | | B **Joey Jenkins** (~28) `[GoF]`; S Galvin Gudgeon (~24); K Gordon Horton (`[Wiki]`, no primary source); manager Ragmar Dorkins `[DP]`. C Dragomir Gorgovitch appears around 1996 `[DH 7]` | Small (last in 1998 `[DP1]`) |

**Tier for the career ladder** `[Inference]` from honours and the 1998-99 tables:
- **Small** (where career mode starts; objective "don't finish last" / "mid-table"): Chudley Cannons, Falmouth Falcons, Wigtown Wanderers.
- **Mid** (objective "mid-table" / "challenge near the top"): Wimbourne Wasps, Appleby Arrows, Kenmare Kestrels, Pride of Portree, Holyhead Harpies, Caerphilly Catapults.
- **Big** (objective "title" / "European Cup"): Tutshill Tornados, Puddlemere United, Ballycastle Bats, Montrose Magpies.

Each club needs **7 starters + 5-7 reserves** (and Puddlemere, an explicit reserve team). With 1-3 canon players per club, we need **~130 [FILLER] players** generated with British and Irish names in JKR's style (see `09-data-model.md`).

---

## 3. European Cup

| Aspect | Data | Source |
|---|---|---|
| Created | **1652**; played **every three years** | `[QTTA c8]` |
| Known champions | Vratsa Vultures ×7 (incl. 1931); Montrose Magpies ×2; Puddlemere United ×2; Caerphilly Catapults 1956 (final vs Karasjok Kites); Wimbourne Wasps semifinalists ×2 | `[QTTA c7-c8]` |
| Champion per film props | Quiberon Quafflepunchers 1922 | `[Prop]` (not used as canon) |
| Years in the game | The canon dates (1931, 1956) are not mutually compatible with a strict three-year cycle. We anchor on the only described final, **1956**: editions in **1995, 1998, 2001, 2004…** The first falls in the player's second season | **[FILLER-inference]** |
| Participants | **16 clubs**: champion and runner-up of each European league in the game (British and Irish, France, Germany, Eastern Europe, Iberia-Luxembourg, Nordic = 12) plus the 4 best third-placed teams | **[FILLER]**; inspiration: the two British clubs with European Cups are the two with the most league honours |
| Format | **Single-match** knockout at a neutral venue (European moors chosen by the ICWQC); a draw is **replayed** | Minimal **[FILLER]**; a replay is the only tiebreak idea that appears in the canon (Diggory offers one in `[PoA 9]`); see `03` table C |
| Calendar | Four rounds spread between October and May of the edition's year | **[FILLER]** |

---

## 4. Quidditch World Cup

### 4.1 Format (JKR canon)

All `[PM-WC]` unless stated:

1. Any country may **enter** within the 12 months after the previous final.
2. **Group stage**: **16 groups**, round-robin, over **two years**.
3. In the groups, matches have a **4-hour cap** "to prevent player exhaustion". If the Snitch is not caught, **it is decided on goals**.
4. **Points**: win = **2**; win by more than **150** = **+5**; by more than **100** = **+3**; by more than **50** = **+1**.
5. **Tiebreak**: the team that **caught the Snitch most often**, or **fastest**.
6. The **16 group winners** advance to the **knockout stage**, seeded by points: 1st vs 16th, 2nd vs 15th, etc.
7. **Third-place match** between the losing semifinalists `[PM-2014]`.
8. Knockout matches are played **with no time cap** (3 days, 20 hours, 10 hours in 2014) `[PM-2014]`.
9. The **ICWQC** chooses the venue (moors, deserts, desert islands), organizes transport (up to 100,000 spectators) and **chooses the referees**. A 19-volume rulebook.
10. 1849 rule: if a spectator casts a spell on a player, **their team automatically loses** `[PM-2014]`. **Snitchnip** = forfeit of the match `[PM-2014]`. National mascots allowed (the 1995 motion to limit them was rejected) `[PM-2014]`.
11. Frequency: **every 4 years** since 1878; canon numbering 422nd (1994), 427th (2014). The canon numbering is used as is, even though it does not fit the cycle `[PM-WC]`, `[GoF 5]`.

Group size: the canon does not say. With ~40 canon national teams plus filler up to **64 entrants**, that gives **16 groups of 4** (6 matches per team over two years) **[FILLER]**.

### 4.2 Canon history (fixed)

| Year | Venue | Final | Notes | Source |
|---|---|---|---|---|
| 1473 | Europe | Transylvania vs Flanders | First World Cup; the 700 fouls | `[QTTA c8]` |
| 1809 | Western Siberia | Romania vs New Spain | "Attack of the Killer Forest"; Niko Nenad | `[PM-WC]` |
| 1877 | Ryn Desert | ? | "The tournament nobody remembers"; replayed in 1878 | `[PM-WC]` |
| 1966 | ? | **Australia** champions | Royston Idlewind | `[PM-WC]` |
| 1974 | ? | **Syria** vs Madagascar | The "Dissimulators" | `[PM-WC]` |
| 1982 | ? | Brazil finalists | | `[PM-2014]` |
| 1990 | ? | **Canada 270-240 Scotland** | Hector Lamont and his short fingers | `[PM-WC]` |
| **1994** | **Dartmoor** | *simulated* (canon: Ireland 170-160 Bulgaria) | The game's first World Cup | `[GoF 8]` |
| 1998, 2002, 2006, 2010, 2014 | | *simulated* (canon: Malawi, Egypt, Burkina Faso, Moldova, Bulgaria) | "History" only if a later pack is enabled | `[PM-WC]` |

### 4.3 How it fits into the game calendar

- **When the game starts in August 1993, the 1994 World Cup group stage is already halfway through** (1992-94). The game starts with the 16 group tables **preloaded** consistently with the canon: Ireland, Bulgaria, Peru, Transylvania, Luxembourg, Uganda, Wales, Scotland and England are still in contention (all of them appear in the 1994 final stage `[GoF 5]`). The remaining positions are **[FILLER]**. Simulation takes over from there.
- The second half of the groups is played on **international dates** interspersed through the 1993-94 season (3 per season) **[FILLER]**; the final stage, in **August 1994** at Dartmoor, between two league seasons.
- Next cycle: entry August 1994 to August 1995; groups 1995-96 and 1996-97 (3 dates per season); final stage August 1998. And so on every four years.
- **Call-ups.** National teams are run by the AI in v1 (`03` B13), or by the manager who took the federation's job. They call up the best fit players of their nationality **three days before each match** (the whole fortnight ahead in the final stage, so the squad stays together through the tournament); the players are on **international duty** until the day after the match (`Player.duty_days`, since 0.11.0): the club or house cannot field them (the lineup screen, squad and profile show "On duty with …"), the national team can, and the club gets an owl when its players are called. They come back with the match's fatigue and may come back **injured**; for the August final stage, called-up players arrive late to pre-season. National team matches count toward **progression** (high-level minutes). A school student can be called up: Krum played the 1994 World Cup while a Durmstrang student `[GoF 7-8]`.
- World Cup venue: the ICWQC chooses it; for 1994 it is Dartmoor (canon); for later ones, it is drawn among entered countries with suitable moors **[FILLER]** (2014 was in Patagonia, canon).

---

## 5. Leagues in the rest of the world

### 5.1 Principle

The canon names **~22 clubs in 15 countries** and confirms that there are leagues in France, the United States, Australia and an **All-Africa Cup** `[QTTA c8]`, an **Eastern European Championship** for national teams (`[Film Wizardry]`, adaptation) and a **Champion's League** won by Toyohashi `[PM-Mahoutokoro]`. Nothing more. Everything else is **[FILLER]**:

- Default format of each league: the British one (accumulated points scored, double round-robin, closed league without promotion) **[FILLER]**. Neighboring countries are grouped into a regional league when the canon gives few clubs, so that each league has between **8 and 12 clubs**.
- Filler clubs are **generated**: name = real town in the region + alliterative noun (canon pattern: Quiberon Quafflepunchers, Gorodok Gargoyles, Moutohora Macaws), colors, one identity trait and a founding year between 1650 and 1950. Names are **not hand-written** here. The generator in `09-data-model.md` produces them from per-region tables.
- Venues: outside Britain the canon does not say whether there are home stadiums; in `[VG-QWC]` each national team has a themed stadium. By default, the same system of moors run by the local Ministry **[FILLER]**.

### 5.2 Playable leagues in v1

| League (region) | Countries | Canon clubs (trait) | Filler | Level | Justification of the level |
|---|---|---|---|---|---|
| **British and Irish League** | United Kingdom, Ireland | 13 (see §2) | 0 | **1** | Best-documented league; 4 European Cups among its clubs `[QTTA c7]` |
| **Eastern European League** | Bulgaria, Poland, Lithuania, Romania, Moldova, Transylvania | Vratsa Vultures (BG; 7 European Cups; long shots), Grodzisk Goblins (PL; Wronski's club), Gorodok Gargoyles (LT; beat Toyohashi in 1994) | 7-9 | **1** | Bulgaria 12 straight Eastern European championships; finalist 1994 and 2002, champion 2014; Moldova champion 2010; Transylvania 390-10 over England `[GoF 5]`, `[PM-WC]` |
| **French League** | France | Quiberon Quafflepunchers (shocking-pink robes; frequent champions) | 7-9 | **2** | France finalist 2006 `[PM-WC]`; canon "French league" `[QTTA c8]` |
| **German League** | Germany, Austria, Switzerland, Liechtenstein | Heidelberg Harriers ("fiercer than a dragon") | 7-9 | **2** | Germany in the round of 16 in 2014; Liechtenstein the 2014 surprise `[PM-2014]` |
| **Iberian and Luxembourg League** | Portugal, Spain, Luxembourg | Braga Broomfleet (PT; Beater marking), Bigonville Bombers (LU; attacking) | 6-8 | **2** | Luxembourg "flattened" Scotland in 1994 `[GoF 5]`; Spain only in `[VG-QWC]` |
| **Nordic League** | Norway, Sweden, Denmark, Finland, Iceland | Karasjok Kites (NO; 1956 European Cup finalists) | 7-9 | **2** | Norway joint favorite in 2014 `[PM-2014]`; Swedish broom race `[QTTA c2]` |
| **USA Quidditch League** | United States | Fitchburg Finches (MA; 7 leagues), Sweetwater All-Stars (TX) | 8-10 | **2-3** | "Quodpot held back its development"; 4th in 2014 is its best result `[QTTA c8]`, `[PM-2014]`; canon league with a "Grand Final" `[FB]` |
| **Canadian League** | Canada | Moose Jaw Meteorites, Haileybury Hammers, Stonewall Stormers ("among the best in the world") | 5-7 | **1-2** | Canada champion 1990 `[PM-WC]` |
| **Argentine League** | Argentina (with Uruguay and Paraguay as neighbors without a league) | None named | 8-10 | **2** | Argentina quarterfinalist in the 20th century `[QTTA c8]`; host of the 2014 World Cup in Patagonia `[PM-2014]`; half the team tied up in a Cardiff cellar in 1877 `[PM-WC]`. **Own league by design decision (must-have)**; all its clubs are [FILLER] named after Argentine towns |
| **Brazilian League** | Brazil | None named (Castelobruxo as the regional school) | 8-10 | **1** | Brazil 5 World Cups according to Bagman, finalist 1982 and 2014; manager José Barboza rebuilt with young players `[PM-2014]` |
| **Andean League** | Peru, Chile, Bolivia, Ecuador, Colombia | Tarapoto Tree-Skimmers (PE; Peru's most famous club, acclaimed European tour) | 7-9 | **1-2** | Peru "the most skilled nation in South America", semifinalist 1994 `[QTTA c8]`, `[GoF 5]` |
| **Mexico and Caribbean League** | Mexico, Haiti, Jamaica, Cuba, Central America | None named | 6-8 | **3** | New Spain (Mexico) finalist 1809 `[PM-WC]`; Haiti and Jamaica in the round of 16 in 2014 `[PM-2014]` |
| **All-Africa League** | Uganda, Togo, Ethiopia, Tanzania, Nigeria, Malawi, Senegal, Egypt, Burkina Faso, Ivory Coast, Chad | Patonga Proudsticks (UG; drew with the Magpies), Tchamba Charmers (TG; reverse pass), Gimbi Giant-Slayers (ET; 2 All-Africa Cups), Sumbawanga Sunrays (TZ; formation looping) | 8-10 | **1** | Three straight World Cups for Africa (1998, 2002, 2006); Uganda beat Wales in 1994; Nigeria joint favorite in 2014 `[PM-WC]`, `[GoF 5]`. The canon **All-Africa Cup** is modeled as this league |
| **Japanese League** | Japan | Toyohashi Tengu (burn their brooms when they lose; train over the sea at Mahoutokoro) | 7-9 | **2** | Japan 3rd in 2014; Toyohashi Champion's League winners `[PM-2014]`, `[PM-Mahoutokoro]` |
| **Oceania League** | Australia, New Zealand, Fiji | Thundelarra Thunderers and Woollongong Warriors (AU; legendary rivalry, dominant for "almost a century"), Moutohora Macaws (NZ; Sparky the phoenix) | 6-8 | **1-2** | Australia champion 1966 `[PM-WC]`; canon "Australian league" `[QTTA c8]` |

Total: **16 leagues, ~145-160 clubs, of which 35 canon and ~115 [FILLER]**. Latin America has four leagues (Argentina, Brazil, Andean, Mexico and the Caribbean) by design request; the canon names only one club (Tarapoto) in the whole region, so almost everything is filler, with real town names and alliterative nouns in Spanish and Portuguese. Other countries with a canon national team but no league (Egypt, Syria, Madagascar, China, India, Turkey, Italy…) get **generated players without a domestic club** who play in neighboring leagues **[FILLER]**; their national teams exist all the same.

> *Note on the current data:* the shipped 1993-94 pack has grown beyond this v1 plan: it has **20 leagues and 194 clubs**, 35 canon and 159 filler clubs, now hand-authored as data files with `source: filler_authored` instead of being generated at start (it adds, among others, Italian, Low Countries, Central European, Indian and East Asian leagues). See `09-data-model.md` and `data/packs/1993-94/competitions/`.

**Continental cups.** Only the European Cup and the All-Africa Cup have a canon basis. No cups are invented for the Americas, Asia or Oceania in v1. Toyohashi's "Champion's League" is post-2014 and is not modeled in the base pack.

### 5.3 National teams

Relative strength `[Inference]` from canon results; squads are assembled by calling up the best of each nationality in the game world, with canon players assigned to plausible clubs.

| Strength | National teams | Canon evidence |
|---|---|---|
| **Elite** | Bulgaria, Ireland, Brazil, Peru, Transylvania | 1994 final; "rock solid defence" and 12 Eastern championships; Brazil 5 World Cups; Peru semifinalist 1994; Transylvania 390-10 over England `[GoF 5, 8]`, `[PM-2014]` |
| **Strong** | Canada, Australia, Moldova, Egypt, Nigeria, Norway, Japan, Uganda, Luxembourg, Scotland, Malawi | Champions 1990, 1966, 2010, 2002, 1998; joint favorites 2014; 3rd 2014; Uganda and Luxembourg won in 1994 `[PM-WC]`, `[PM-2014]`, `[GoF 5]` |
| **Mid** | Wales, United States, France, Germany, Syria, Senegal, Burkina Faso, China, Poland, New Zealand, Fiji, Liechtenstein, Argentina, Madagascar | Quarterfinals and round of 16 in 2014; occasional finalists and champions `[PM-WC]`, `[PM-2014]` |
| **Weak** | England, Chad, Haiti, Ivory Coast, Jamaica, Italy, Turkey, Portugal, India, Morocco, Flanders, Romania, New Spain (Mexico) | England 10-390; minor appearances `[GoF 5, 30]`, `[PM-WC]` |

Canon mascots per national team (veela, leprechauns, trolls, curupiras, sasabonsams, Inferi, yumboes, dukuwaqa, river jinn, Hans the augurey) are used as flavor in match reports and in the match viewer (`02` §11.4).

### 5.4 Rivalries and derbies

Rivalries live in each club's `identity.rivalries` (club ids, always symmetric) with `identity.rivalries_source` = `canon` or `filler` and a line in the club's `notes`; `src/game/rivalries.gd` (`Rivalries.are_rivals`, `Rivalries.rivals_of`) reads them. The **British and Irish League keeps only the canon rivalries**: Appleby-Wimbourne `[QTTA c7]` and Harpies-Puddlemere `[DP]` (Thundelarra-Woollongong `[QTTA c8]` is the third canon pair, in the Oceania League). Every other league gets **one to three invented derbies [FILLER]**: same city or region, the two biggest clubs, or an old feud built from the clubs' cities, founding years and history. The invented pairs are also in `tools/author_clubs.py` (`RIVALRIES`), so regenerating the filler clubs keeps them.

What a derby does in the game **[game; amounts FILLER]**:

- **Daily Prophet preview** in the Monday edition before the match: always for the manager's own derbies (lead-level importance) and the derbies of the manager's league; from the rest of the world, only the biggest top-flight derby of the week. The same pass previews the manager's **return to a former club** (a club from an earlier, closed spell).
- **Gate receipts +25 %** for both clubs (`Economy.match_income`).
- **Result.** Fan mood ±2 and player morale ±3 on top of the usual swing for the winners and losers; a draw adds nothing.
- **Former player stars against you.** A player the manager's club sold (a permanent transfer in the transfer log; loans and releases do not count) who rates 8 or more against it gets a Prophet item (the best-rated one if there are several).
- **Board secondary objective.** A club with a rival in its own league is also asked to **finish above that rival** (the first such rival by id; derived, not stored). It is judged at the season end after the main verdict: +5 confidence above, −5 below (never below 25 on its own, the ultimatum line), with an owl from the board. It is never a sacking reason by itself and has no effect on AI boards. Shown on the board screen.

| League | Derby | Basis | Source |
|---|---|---|---|
| British and Irish Quidditch League | Appleby Arrows vs Wimbourne Wasps | Traditional and fierce; the Wasps' emblem dates from a match in which a Wimbourne Beater batted a wasps' nest at the Appleby Seeker | `[QTTA c7]` |
| British and Irish Quidditch League | Holyhead Harpies vs Puddlemere United | Attested in the newsletters: the Ilkley Moor match (wands confiscated at the entrance, riot) and Wilda Griffiths's move to Puddlemere. The game takes the feud as already alive in 1993-94, with Griffiths still at Holyhead that season | `[DP]` + `[Inference]` |
| All-Africa League | Cairo Crocodiles vs Gimbi Giant-Slayers | The Nile derby: the league's most-titled club against the two-time All-Africa Cup winners from the Blue Nile highlands | **[FILLER]** |
| All-Africa League | Dakar Dune-Dancers vs Abidjan Antelopes | The two French-speaking clubs of the West African coast | **[FILLER]** |
| All-Africa League | Lagos Lightningbolts vs Kano Kingfishers | The league's two Nigerian clubs | **[FILLER]** |
| Andean League | Bogotá Brujas vs Medellín Mariposas | The Colombian derby | **[FILLER]** |
| Andean League | Quito Quetzales vs Guayaquil Guacamayos | The Ecuadorian derby: the highland capital against the coast | **[FILLER]** |
| Andean League | Santiago Saetas vs Valparaíso Vientos | The Chilean derby: the capital against the port | **[FILLER]** |
| Argentine League | Buenos Aires Búhos vs Rosario Relámpagos | The league's two most successful clubs | **[FILLER]** |
| Argentine League | Córdoba Cometas vs Mendoza Montañeses | The derby of the interior, plains against mountains | **[FILLER]** |
| Argentine League | Mar del Plata Mareas vs Bahía Blanca Ballenas | The Atlantic coast derby | **[FILLER]** |
| Brazilian League | Porto Alegre Pampeiros vs Curitiba Curupiras | The southern derby | **[FILLER]** |
| Brazilian League | Recife Raposas vs Salvador Sabiás | The north-east derby | **[FILLER]** |
| Brazilian League | Rio Redemoinhos vs São Paulo Sacis | The league's two most successful clubs | **[FILLER]** |
| Canadian League | Haileybury Hammers vs Trois-Rivières Tonnerres | Ontario against Quebec; both clubs were founded in 1890 | **[FILLER]** |
| Canadian League | Moose Jaw Meteorites vs Stonewall Stormers | The prairie derby, Saskatchewan against Manitoba | **[FILLER]** |
| Canadian League | Vancouver Voyageurs vs Calgary Coyotes | The western derby across the Rockies | **[FILLER]** |
| Central European League | Bratislava Bludičky vs Košice Kuvici | The Slovak derby | **[FILLER]** |
| Central European League | Budapest Boszorkányok vs Debrecen Délibábok | The Hungarian derby, the capital against the Great Plain | **[FILLER]** |
| Central European League | Praha Golemové vs Brno Draci | The Czech derby, Bohemia against Moravia | **[FILLER]** |
| East and Southeast Asian League | Bangkok Garudas vs Chiang Mai Chang Phueak | The Thai derby | **[FILLER]** |
| East and Southeast Asian League | Beijing Baihu vs Shanghai Shenlong | The league's two most successful clubs | **[FILLER]** |
| East and Southeast Asian League | Seoul Samjogo vs Busan Bulgasari | The Korean derby | **[FILLER]** |
| Eastern European League | Kraków Kruki vs Wrocław Wilki | The southern Polish derby | **[FILLER]** |
| Eastern European League | Moskva Medvedi vs Sankt-Peterburg Sirini | The Russian derby, the two old capitals | **[FILLER]** |
| Eastern European League | Vilnius Vytis vs Kaunas Kometos | The Lithuanian derby | **[FILLER]** |
| French League | Bordeaux Busards vs Toulouse Tarasques | The Garonne derby | **[FILLER]** |
| French League | Paris Phénix vs Marseille Mistrals | The capital against the Mediterranean, the two most successful clubs after Quiberon | **[FILLER]** |
| German and Alpine League | Berlin Blitze vs München Mondkälber | North against south, the league's two most successful clubs | **[FILLER]** |
| German and Alpine League | Wien Windhunde vs Salzburg Salamander | The Austrian derby | **[FILLER]** |
| Iberian and Luxembourg League | Lisboa Lobisomens vs Porto Pégasos | The Portuguese derby, Lisbon against the north | **[FILLER]** |
| Iberian and Luxembourg League | Madrid Mantícoras vs Barcelona Basiliscos | The league's two most successful clubs | **[FILLER]** |
| Indian League | Bombay Bulbuls vs Delhi Dholes | The league's two most successful clubs | **[FILLER]** |
| Indian League | Madras Mongooses vs Bangalore Banyans | The southern derby | **[FILLER]** |
| Italian League | Napoli Nottole vs Benevento Befane | The Campania derby | **[FILLER]** |
| Italian League | Roma Ruggenti vs Milano Mangiafuoco | The league's two most successful clubs | **[FILLER]** |
| Japanese League | Tokio Tatsu vs Osaka Oni | East against west, the two great cities | **[FILLER]** |
| Japanese League | Toyohashi Tengu vs Nagoya Namazu | The Aichi derby | **[FILLER]** |
| Low Countries League | Amsterdam Aalscholvers vs Rotterdam Reigers | The Dutch derby | **[FILLER]** |
| Low Countries League | Gent Gnomen vs Brugge Beren | The Flemish derby | **[FILLER]** |
| Mexico and Caribbean League | La Habana Huracanes vs Kingston Krakens | The Caribbean derby | **[FILLER]** |
| Mexico and Caribbean League | Veracruz Víboras vs Oaxaca Ocelotes | Neighbours on the Gulf and in the southern mountains | **[FILLER]** |
| Nordic League | Helsinki Haukat vs Tampere Tontut | The Finnish derby | **[FILLER]** |
| Nordic League | Oslo Ormer vs Bergen Bjørner | The Norwegian derby | **[FILLER]** |
| Nordic League | Stockholm Stormar vs Göteborg Gripar | The Swedish derby | **[FILLER]** |
| Oceania League | Sydney Sundowners vs Melbourne Mopokes | The two great Australian cities | **[FILLER]** |
| Oceania League | Thundelarra Thunderers vs Wollongong Warriors | Legendary; the two clubs dominated the Australian league for almost a century | `[QTTA c8]` |
| USA Quidditch League | Fitchburg Finches vs Sweetwater All-Stars | Inferred from their 1926 US league Grand Final `[FB]` | **[FILLER]** |
| USA Quidditch League | Los Angeles Luminaries vs San Francisco Sea-Serpents | The Californian derby | **[FILLER]** |
| USA Quidditch League | New York Nifflers vs Boston Banshees | The East Coast derby | **[FILLER]** |

School houses have no rivalries in this system (Gryffindor-Slytherin is canon, but the House Cup has its own logic).

---

## 6. Schools as youth academies

### 6.1 Hogwarts (full canon)

| Aspect | Rule | Source |
|---|---|---|
| Teams | 4 houses: Gryffindor, Hufflepuff, Ravenclaw, Slytherin | Books |
| Format | **Single round-robin league**: each house plays the other three (6 matches per year) | `[PS]`, `[Lexicon]` |
| Standings | **Total points scored**: "it was perfectly possible to lose to another team and still win the Cup" | `[PoA 15]`, `[HBP 24]` (the arithmetic of HBP 24 is inconsistent; total points are used) |
| Typical calendar | 1st Gryffindor-Slytherin (November); 2nd Hufflepuff-Ravenclaw (late November); 3rd Ravenclaw-Slytherin (February); 4th Gryffindor-Hufflepuff (March); 5th Hufflepuff-Slytherin (May); 6th Gryffindor-Ravenclaw (late May). In 1993-94 Slytherin managed to change the order by citing Malfoy's injury | `[Lexicon]` deduced from the books; `[PoA 8-9]` |
| Eligibility | **First-years may not own a broom or play** (Harry, an exception granted by McGonagall) | `[PS 9]` |
| Captain | Appointed by the head of house; organizes **tryouts** and training; badge | `[HBP 6, 11]` |
| Substitutes | Reserves exist (Alicia Spinnet 1990-91; Harper; Dean Thomas) and rule 5 still applies: without Harry, Gryffindor played with six | `[PS 11]`, `[HBP 14]`, `[CS 7]` |
| Referee | Madam Rolanda Hooch (Snape in one 1992 match) | `[PS 13]` |
| Commentator 1993-94 | Lee Jordan, with McGonagall beside him correcting him | `[PoA]` |
| Time | 11 in the morning, usually | `[Lexicon]` |
| Trophy | Silver cup with four handles | `[Wiki]`, `[PoA 15]` |
| Canon suspensions | 1992-93 (basilisk); 1994-95 (Triwizard Tournament); see §1.2 | `[CS 14]`, `[GoF 12]` |

**Canon 1993-94 squads** (age = year + 11, `[Inference]`):

| House | Squad | Source |
|---|---|---|
| **Gryffindor** | K/capt Oliver Wood (7th year, 17); C Angelina Johnson (5th, 15), Alicia Spinnet (5th, 15), Katie Bell (4th, 14); B Fred and George Weasley (5th, 15); S Harry Potter (3rd, 13; Nimbus 2000 → Firebolt) | `[PoA]` |
| **Slytherin** | C/capt Marcus Flint (repeating 7th year, 18), Adrian Pucey, Cassius Warrington; B Lucian Bole, Peregrine Derrick; K Miles Bletchley; S Draco Malfoy (3rd, 13; Nimbus 2001) | `[PoA 15]`, `[CS 7]` |
| **Ravenclaw** | S Cho Chang (4th, 14; Comet 260; the only girl on the team); C/capt Roger Davies; the rest **[FILLER]** (5 players) | `[PoA 13]` |
| **Hufflepuff** | S/capt Cedric Diggory (5th, 15); the rest **[FILLER]** (6 players) | `[PoA 9]` |

Later canon players who are already at Hogwarts in 1993-94 and join the teams when their time comes: Ron Weasley (K, 1995), Ginny Weasley (S/C, 1995), Zacharias Smith, Cadwallader, Summerby, Montague, Vaisey, Crabbe and Goyle (B, 1995), Harper, Demelza Robins, Jimmy Peakes, Ritchie Coote, Cormac McLaggen, Dean Thomas, Andrew Kirke, Jack Sloper, Bradley, Chambers `[OotP]`, `[HBP]`. The engine decides whether they actually make it (tryouts), but they exist with the correct age.

### 6.2 The other schools

| School | Region it feeds | What the canon says about its Quidditch | Source |
|---|---|---|---|
| **Durmstrang** | Eastern Europe, Nordic, Germany | Krum is a student and at the same time Bulgaria's Seeker (1994); it has a pitch and a team | `[GoF 7, 15]`, `[VG-QC]` for the team |
| **Beauxbatons** | France, Iberia | Has a team; Fleur and Gabrielle only in a video game | `[GoF]`, `[VG-QC]`; `[FB]`/`[Prop]` puts it first in a "European Quidditch League" (1926) |
| **Ilvermorny** | United States, Canada | Quidditch Cup among its 4 houses (Horned Serpent, Wampus, Thunderbird, Pukwudgie); Pukwudgie champion 1926 | `[PM-Ilvermorny]` for the houses; `[FB]`/`[Prop]` for the cup |
| **Mahoutokoro** | Japan | They train over the sea in storms, dodging Muggle planes; the base of the Toyohashi Tengu and of the national team | `[PM-Mahoutokoro]` |
| **Castelobruxo** | South America | Alumni such as João Coelho, captain of the Tarapoto Tree-Skimmers | `[PM-Castelobruxo]` |
| **Uagadou** | Africa | No information about Quidditch | `[PM-Uagadou]` → its team is **[FILLER]** |
| **Koldovstoretz** | Russia / Eastern Europe | They play a version of Quidditch on **uprooted trees** instead of brooms | `[PM-Wizarding Schools]` → modeled as a normal academy; the tree detail only as flavor |

Model (since October 2026): **all eleven schools have four houses and their own internal Quidditch Cup** (single round-robin, six matches between November and May), which the engine simulates and which the player can watch or manage. Their role in the game is to **produce youngsters** for their region.

#### The three unnamed schools **[FILLER]**

JKR wrote that there are eleven major wizarding schools and named eight `[PM-Wizarding Schools]`. The three missing ones are invented and cover the game regions that had no school:

| School | Where | Region it feeds |
|---|---|---|
| **Wollemi Academy of Magic** | Mount Wollemi, Blue Mountains (Australia) | Oceania |
| **Kapadokya Institute of Magic** | Fairy chimneys of Cappadocia (Turkey) | Middle East; since there is no league there, its graduates also go to Eastern Europe |
| **Nilgiri School of Magic** | Nilgiri Hills, southern India | South Asia |

#### Invented houses **[FILLER]**

Only Hogwarts and Ilvermorny have houses in the canon. Those of the other nine follow the Ilvermorny model (magical creatures and local folklore) and live in `data/shared/schools.json` (names) and `data/packs/1993-94/schools/<school>.json` (colors, emblem and inspiration, `source: filler`):

| School | Houses [FILLER] | Inspiration |
|---|---|---|
| **Beauxbatons** | Abraxan, Vouivre, Melusine, Tarasque | Madame Maxime's winged horses [GoF 15], the only canon nod. Vouivre: winged serpent with a ruby on its forehead, folklore of Franche-Comté and Burgundy. Melusine: fairy of the springs with a serpent's tail, French medieval legend. The Tarasque of Tarascon (Provence): six-legged dragon with a shell. |
| **Durmstrang** | Lindworm, Huldra, Jotunn, Sleipnir | Lindwurm/lindorm: wingless serpent-dragon from Germanic and Scandinavian folklore. Huldra: Norwegian forest spirit with a cow's tail. Jötunn: frost giants of Norse mythology. Sleipnir: Odin's eight-legged horse. |
| **Koldovstoretz** | Zhar Ptitsa, Leshy, Rusalka, Zmey | Zhar-ptitsa: the firebird of Russian tales. Leshy: Slavic guardian of the forest. Rusalka: Slavic river spirit. Zmey Gorynych: three-headed dragon of the Russian byliny. |
| **Mahoutokoro** | Kirin, Tengu, Kitsune, Ryu | Kirin: benevolent beast of Japanese folklore. Tengu: mountain spirit, master of martial arts. Kitsune: nine-tailed magical fox. Ryū: Japanese water dragon (jade, like the Mahoutokoro palace [PM]). |
| **Castelobruxo** | Caipora, Iara, Uirapuru, Boto | Caiporas: the spirits that look after Castelobruxo [PM-Wizarding Schools], canon nod. Iara: mermaid of the Amazon rivers. Uirapuru: Amazonian bird with a magical song. Boto cor-de-rosa: river dolphin that turns into a man, Amazonian legend. |
| **Uagadou** | Impundulu, Ninki Nanka, Anansi, Kongamato | Impundulu: lightning bird of Zulu and Xhosa folklore. Ninki Nanka: swamp dragon of West Africa. Anansi: the cunning spider of Ashanti tales. Kongamato: "boat-breaker", a flying creature from Zambian tales. |
| **Wollemi** | Yowie, Min Min, Thylacine, Lyrebird | Yowie: hairy creature of Australian bush tales. Min Min lights: floating lights of the Queensland outback. Thylacine: the Tasmanian tiger (in the wizarding world, perhaps not extinct). Lyrebird: mimics any sound; a bird of the New South Wales forests. |
| **Kapadokya** | Zumruduanka, Sahmeran, Tepegoz, Ejder | Zümrüdüanka: giant emerald bird of Turkish tales (the Persian Simurgh). Şahmeran: queen of serpents, Anatolian legend. Tepegöz: the one-eyed giant of the Book of Dede Korkut. Ejder: dragon of Turkish tales; the fairy chimneys of Cappadocia. |
| **Nilgiri** | Yali, Makara, Airavata, Naga | Yali: beast of South Indian temples. Makara: sea creature of Indian iconography. Airavata: the many-tusked white elephant. Naga: many-headed serpent of South Asian folklore. |

#### House World Cup **[FILLER]**

The books do not mention it. In June, once the school year is over, the Cup champions of each school (eleven, or fewer if a school suspends its cup, like Hogwarts in 1994-95) play a **single-match knockout** at the pitch of a host school that rotates every year. The strongest teams (sum of the ability of their seven best students) get a bye in the first round. Rounds are played on Saturdays in June, so it ends before July 1, when the seventh-years graduate. With book events on, the Hogwarts champion is the one written in the books (Gryffindor in 1993-94, 1995-96 and 1996-97), unless the player manages a Hogwarts house. Code: `GameEngine._create_house_world_cup`.

### 6.3 Youth pipeline

| Step | Rule | Source |
|---|---|---|
| Intake | At 11. They do not play in first year | `[PS 9]` |
| Eligibility | From second year (12) to seventh (17-18) | `[Inference]` from the above |
| Progression at school | Annual tryouts organized by the captain; starters and reserves play the cup; the rest train | `[HBP 11]` |
| International call-up while a student | Possible: Krum with Bulgaria at 18, a Durmstrang student | `[GoF 7-8]` |
| Graduation | At 17-18 (end of seventh year). The best sign for a professional club, usually for its **reserve team** (Wood → Puddlemere reserves, 1994); the rest leave the sport or stay on the market as free agents | `[GoF 7]`; `[VG-HM]` shows Wigtown recruiting a newly graduated Keeper as a reserve (video game, supporting evidence) |
| Scouts | Clubs scout school matches in their region | **[FILLER]**, inspired by Charlie Weasley "could have played for England" `[PS 6]`: school talent is known |
| Parents and lineage | Children of players (Meaghan McCormack, daughter of Catriona; Levski and Vulchanov, sons of the 1994 players) | `[QTTA c7]`, `[PM-2014]` → the generator can create "son/daughter of" players with a canon surname **[FILLER]** |

**Decided (B6).** The player can **manage a house team**, implemented in v0.8.0 as school mode (New Game > School group; `World.house_club`; no wages, transfers or board; the Head of House reviews the year; see `11`, v0.8.0). In the canon, house teams are run by the **student captain**, not an adult; Madam Hooch only supervises `[PoA 12]`, so the manager role is a **[game]** liberty.

---

## 7. The surrounding world

| Element | What it is in the game | Source |
|---|---|---|
| **Department of Magical Games and Sports** | Regulates the British league, appoints referees, suspends players, assigns moors, confiscates wands at heated matches. Head in 1993: **Ludo Bagman** (former Beater for the Wasps and England); before him, Hamish MacFarlan (from 1968). Appears as the sender of sanctions and notices | `[GoF 7]`, `[QTTA c7]`, `[DP]`, `[OotP 7]` |
| **ICWQC** | Organizes the World Cup; chooses venues and referees; 19-volume rulebook; bans "managerial trash talk" (2014) | `[PM-WC]`, `[PM-2014]` |
| **International Association of Quidditch** | Its "Chairwizard" Hassan Mostafa referees the 1994 final | `[GoF 8]` |
| **The Daily Prophet** | Generated weekly newspaper: tables, fixtures, transfers, sackings, riots, betting odds. In 1993-94 there is no canon Quidditch correspondent; **Rita Skeeter** writes gossip from 1994 `[GoF]`; **Ginny Potter** is senior correspondent much later (2014) `[PM-2014]`: both enter the timeline when appropriate | `[DP]`, `[GoF 10]`, `[PM-2014]` |
| **Which Broomstick?** | Broom review magazine; source of each model's "spec sheet" in the shop | `[OotP 9]` |
| **Seeker Weekly**, **Quidditch Times** | Magazines; covers and flavor awards | `[GoF]`, `[QTTA]` |
| **Wizarding Wireless Network** | Radio; possible match commentary | `[Wiki]` (no primary source; optional flavor) |
| **Quality Quidditch Supplies** (Diagon Alley) | Broom and equipment shop; Ireland ordered seven Firebolts | `[PS 5]`, `[PoA 4]`, `[GoF 8]` |
| **Splinter and Kreek's** | Second-hand brooms | `[DP]` |
| **Betting** | Bagman takes bets; odds in the *Daily Prophet* (2014); the player does not bet (it is not canon for a manager to bet) | `[GoF 7]`, `[PM-2014]` |
| **Fan bases** | Stingers (Wasps, buzzing during penalties), harpists (Kenmare), "Prides" (Portree), banned arrows (Appleby), chants ("Weasley is Our King"), riots (Harpies-Puddlemere), hexes from the stands (automatic forfeit) | `[QTTA c7]`, `[OotP 19]`, `[DP]`, `[PM-2014]` |
| **Mascots** | Club mascots (Barny the Fruitbat, Sparky the phoenix, Kenmare's leprechauns) and national ones; they appear in match reports and in the viewer, and can cause incidents (veela distracting the referee) | `[QTTA c7-c8]`, `[GoF 8]`, `[PM-2014]` |
| **Hiding from Muggles** | Flavor in reports and fixtures: midnight matches, venues moved because of Muggle campers, Revisibility goggles, Quaffles reported as UFOs, memory wiping after celebrations | `[DP]`, `[QTTA c5]`, `[PM-2014]` |
| **Mediwizards** | Treat players on the pitch (Skele-Gro); the club hires a mediwizard for its staff | `[GoF 8]`, `[PM-2014]`; club staff **[FILLER]** (see `08`) |
| **Canon managers** | Ragmar Dorkins (Cannons), Philbert Deverill (Puddlemere), Cormack McLeod (Magpies) in the British league; the player takes the job of the manager of whichever club they choose (the canon manager is replaced or moves to another club) | `[DP]` |
| **Other broom sports** | Quodpot (popular in the US; explains its low level in Quidditch), Swivenhodge, Shuntbumps, the Swedish race: only mentioned in club and country histories | `[QTTA c2, c8]` |
