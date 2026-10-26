# 08: Transfers, training and economy

> The systems around the match, modeled on FM 07 (`docs/research/01-football-manager-and-pc-futbol.md` §2bis.4, §2bis.8) and anchored in the little the canon says about the economics of Quidditch (`docs/research/02-quidditch.md` §11.6). Almost all the numbers are **[FILLER, calibrated]** from the only canon market figure (a 1,000-Galleon transfer, 1999) and from prices in the books.

## 1. Training (FM 07: categories × load × coaches)

### Categories and the attributes they work on

| Category | Attributes | Coach |
|---|---|---|
| **Physical** | Stamina, Strength, Natural fitness, Work rate | Fitness coach |
| **Flying** | Speed, Acceleration, Agility, Broom control, Balance, Altitude, Diving | Flying coach |
| **Quaffle** | Passing, Catching, Shooting, Dodging, Stealing, Interception, Creativity | Chasers coach |
| **Beating** | Beating, Beat accuracy, Anticipation (Beaters), Bravery | Beaters coach |
| **Keeper** | Keeping, Reflexes, Positioning, Concentration | Keepers coach |
| **Seeking** | Eyesight, Snitch catching, Concentration, Diving, Composure | Seekers coach |
| **Tactics** | Decisions, Off the ball, Positioning, Teamwork, Anticipation + familiarity with the Chaser style | Assistant / tactics coach |
| **Plays** | The named plays the team wants to master (Hawkshead, Porskoff, Dopplebeater, Wronski Feint…) | Depends on the play |

- **Load** per category: light / medium / intense (slider). Intense physical and flying work during the season means more injuries; it belongs in pre-season.
- **Schedules** per group (starters, reserves, youngsters) or individual; shareable files as in FM 07.
- **Coaches.** Each with a rating per category (stars) and a **maximum workload**; overloaded, they perform worse. The club starts with a minimal staff already hired (FM 07: "default staff").
- **Age.** Youngsters need less load; veterans get injured more under intense load.
- **Summer break.** Attributes drop a little; pre-season recovers them.
- **Facilities**: training ground (level 1-5), infirmary with a mediwizard, broom workshop **[FILLER]**; the level multiplies the effect of training and the quality of youngsters.

Training in the canon: Wood trained Gryffindor three times a week with a tactics board [PS 9]; Harry practiced the Sloth Grip Roll; the Tengu train over the sea in storms [PM-Mahoutokoro].

## 2. Squad and reserves

- A club has **starters** (7), **reserves** (canon reserve team: Wood at Puddlemere) and **youngsters** (recent graduates or players aged 17-19 in development). Typical size 14-18 players **[FILLER]**.
- Reserves play reserve matches between clubs **[minimal FILLER: the canon names the "reserve team" but not its competition]**; they give minutes for development.
- **Loans** between clubs **[FILLER; FM 07]**. There is no canon evidence of loans and nothing contradicts them; they are included (design decision) as a mechanism to give minutes to youngsters: one season, with or without a purchase option; the parent club can require that the player plays.

## 3. Scouts and knowledge (FM 07)

- Each scout has **knowledge per region** (bars): Britain and Ireland, Western Europe, Eastern Europe, Nordic countries, North America, South America, Africa, Asia, Oceania. A scout is assigned to a region for a period and learns from where they have been.
- The **manager** also has knowledge per country (it matters when applying for jobs abroad).
- **Reports** with ability and potential stars, phrases describing hidden attributes and a recommendation; accuracy depends on the scout's quality and their knowledge of the region (OOTP: a bad scout does not lie, they are just less reliable).
- **Masking.** Attributes of players in other leagues appear hidden (ranges) until they are scouted.
- **Schools.** Scouts can go and watch school matches (Hogwarts, Beauxbatons…) and spot youngsters before they graduate.
- Watch list ("shortlist").

## 4. Market and contracts

- **Transfer market open all year** (canon: signings in mid-season [DP]).
- **Transfer.** Offer in Galleons + installments **[FILLER: installments]**; the selling club accepts based on value, need and relationship. The player accepts based on Ambition, Loyalty, Adaptability, promised role and wage. Gwenog Jones threatened Griffiths with death for leaving, so rivalries (Harpies-Puddlemere) affect the player's willingness and the fans' reaction.
- **Contract**: length 1-5 years, weekly wage, role (star, starter, rotation, reserve, youngster), bonuses per goal/catch/title, optional release clause. Renewal triggered by appearances or by negotiation.
- **Free agents.** When the contract expires. **Retirements** at the end of the season: players under CA 70 may retire from 31 (50% a year), everyone from 34 (25%, plus 10% per year over 34), and everyone at 38; players a book event still needs (Krum, the 2014 World Cup final) play on until it. Position and Professionalism do not change it yet.
- **Graduating youngsters.** Every June the 17-18-year-olds from the schools enter the market; clubs with scouts at the school get first contact **[FILLER]**. Hogwarts mainly feeds the 13 British clubs.
- **Holyhead Harpies only sign witches** (canon). The club AI respects the rule and the Harpies manager cannot sign wizards.
- **Market value.** f(CA, PA, age, position, remaining contract, fame). Scale **[FILLER, calibrated]**: Griffiths (Harpies Chaser, 1999) = 1,000 G, so an average league starter is 500-1,500 G; a star 3,000-8,000 G; a youngster 50-300 G.
- There are no agents in the canon; the player negotiates alone (or with their club's manager).

## 5. Club economy

Currency: Galleons (17 Sickles, 29 Knuts). Everything in small, readable numbers, as in the books.

| Income | Detail | Canon basis |
|---|---|---|
| Gate receipts | The Department's share per match played, scaled by the attendance at the home side's ground (fans' mood, rival, cup matches) | Ministry moors [QTTA c5]; World Cup tickets [GoF 7] **[FILLER: the share; game: club grounds]** |
| Sponsorship | Annual deals with wizarding brands: Nimbus, Cleansweep, Comet, Butterbeer, Gringotts, Gladrags, Mrs Skower's, Bluebottle | 1994 World Cup advertising [GoF 8], [Film Wizardry] |
| Merchandise | Rosettes, scarves, figurines, replica robes (Hongo and Shingo) | [GoF 7], [PM-2014] |
| Prize money | League Cup, European Cup, World Cup **[FILLER: amounts]** | |
| Transfers | Player sales | [DP] |

| Expense | Detail |
|---|---|
| Wages | Wage budget set by the board |
| Brooms | Purchase per player or in bulk; the Firebolt is "price on request" and scarce (seven for Ireland) |
| Staff and mediwizards | Wages |
| Facilities | Upgrades |
| Travel | To the moors and abroad (European Cup) **[FILLER]** |

No catering, parking or advertising boards. Those subsystems did not add decisions in PC Fútbol.

## 6. Board and career

- The board (or the owner) sets a **season objective** in the style of Promanager / FM 07: avoid last place, mid-table, challenge for the league, win the league, qualify for the European Cup. **[FILLER: the British league has no relegation in the canon, with 13 fixed clubs since 1674, so the minimum objective is not finishing last, with the Cannons' humiliation as the reference.]**
- **Confidence** by area: results, signings, finances, fans.
- Requests: more budget, better facilities, new brooms.
- **Manager reputation.** It rises when objectives are met and falls on failure; it determines the job offers. Job center with vacancies in every league.
- Sacked if confidence collapses; in career mode, you go back to waiting for offers (unlike PC Fútbol Manager, where being sacked ended the game).
- Press relations: a press conference after every official club match and a short one the day before it (see below; originally planned: only occasional *Daily Prophet* questions, no press conferences). Planned: the option to comment on referees and players, with consequences ("managerial trash talk" was banned in 2014 [PM-2014], so until then it is allowed, with the risk of a Department fine **[FILLER: the fine]**).

## 7. Fans and atmosphere

- Fans with **mood** (results, style, signings) and **hostility** (rivalries: Appleby-Wimbourne, Harpies-Puddlemere). It affects gate receipts, pressure during the match and *Daily Prophet* events (riots, confiscated wands, hexes from the stands). If a fan hexes a player, the team forfeits the match under the 1849 rule.
- Mascots and chants as flavor in match reports (Stingers, Kenmare harps).

## 8. Medical

- Club mediwizard (level 1-5) reduces injury days and treats players on the pitch (without the player returning if they went off).
- Hogwarts hospital wing (Madam Pomfrey) for the youngsters: short injuries (Skele-Gro).

## Loans and reserve matches (added October 3, 2026)

Both are **gameplay mechanics taken from Football Manager, not canon rules** (the books have reserve teams, since Wood signs for Puddlemere's [GoF 7], but do not describe how they work; loans between clubs are design [FILLER]).

- **Loans** (`Economy.execute_loan/return_loan`, `MarketActions.request_loan/toggle_loan_list/end_loan_early`). They last until June 30 of the season; the receiving club pays the wage; a loaned player cannot be sold or renewed; he returns automatically at the season rollover. The AI loans out non-starters (`ai_accepts_loan`) and takes loanees for squad depth when it has the bare minimum in a position and fewer than 17 players (`ai_transfer_tick`). The player accepts if he will get minutes (`player_accepts_loan`).
- **Reserve matches** (`GameEngine._reserve_matches`). Every week the human club plays a simulated friendly (reserves against the reserves of a league rival, 2-hour cap, no gate receipts, only minor injuries) that gives match sharpness and ratings; the substitutes of AI clubs only gain sharpness abstractly up to 70, so it does not cost 10 s per season.

## Negotiation, agents, swaps, press and talks (added October 3, 2026)

FM mechanics, not canon: the AI makes counteroffers (up to two rounds, `MarketActions.process_pending/resolve_counter`), the player's agent asks for wage and bonus (`Economy.agent_demand`; haggling can make him walk away), player + cash swaps (`make_swap_offer`, `Economy.swap_value`), counteroffers to incoming bids (+25%). Press conference after every official club match (`src/game/press.gd`: humble / confident / critical / evasive, affecting morale, confidence, reputation) and a pre-match conference before official matches (`Press.pre_questions`/`apply_pre`). Since 2026-10-22 both conferences draw from context-triggered pools (19 pre-match and 32 post-match questions: streaks, derbies (`Rivalries`), the manager's former club, a former player now with the rival, an injured star, cup ties, top-of-the-table clashes, weather, long matches), never repeat a question within the club's last 5 conferences (`w.manager.press_recent`), and offer "let your assistant answer" (no effect, ends the conference) and individual talks (praise, demand, promise a starting place: three matches within 60 days). National teams: the federation makes an offer on August 15 if the manager's reputation reaches the tier's threshold and they have managed enough seasons (`Career.NT_SEASONS`: 2 for weak and mid tiers, 3 for strong and elite); sacked if the team does not get past the group stage.
