class_name Economy  # [FILLER, calibrated]
extends RefCounted


## Weekly wages.
static func pay_wages(w: World, club: Club) -> int:
	var total := 0
	for p in w.squad_of(club.id):
		total += int(p.contract.get("wage_weekly", 10))
	for role in club.staff.keys():
		total += int(club.staff[role].get("wage", 0))
	book(w, club, "wages", -total)
	return total


## Cash movement with its concept: adds or subtracts and, for the human club, records it in the month's ledger
## (`club.ledger["YYYY-MM"][concept]`). Concepts: gate, sponsor, merch, prizes, transfers_in, transfers_out, wages,
## staff, scouts, signing_fees, bonuses, severance, facilities, brooms.
const LEDGER_MONTHS_KEPT := 24


static func book(w: World, club: Club, kind: String, amount: int) -> void:
	if club == null or amount == 0:
		return
	club.balance += amount
	if club.manager_is_human and w != null:
		var key := "%04d-%02d" % [WDate.year(w.today), WDate.month(w.today)]
		if not club.ledger.has(key):
			club.ledger[key] = {}
			var keys := club.ledger.keys()
			keys.sort()
			while keys.size() > LEDGER_MONTHS_KEPT:
				club.ledger.erase(keys.pop_front())
		club.ledger[key][kind] = int(club.ledger[key].get(kind, 0)) + amount


## Hire/upgrade a staff role to the next level (fee = 20 weeks of wages).
static func upgrade_staff(w: World, club: Club, role: String, rng: SimRng, loader: SimLoader) -> Dictionary:  # [FILLER]
	var cur: int = club.staff_level(role)
	if cur >= 5:
		return {"ok": false, "key": "ui.staff.max"}
	var lvl := cur + 1
	var fee := Club.staff_wage(lvl) * 25
	if fee > club.balance:
		return {"ok": false, "key": "ui.market.no_funds"}
	book(w, club, "staff", -fee)
	var names: Dictionary = loader.names_for(club.region_id, club.country_id)
	var female := rng.chance(0.4)
	var first: String = str(rng.pick(names["first_names_f"] if female else names["first_names_m"]))
	club.staff[role] = {"name": "%s %s" % [first, FillerGenerator.female_last(names, str(rng.pick(names["last_names"])), female)], "level": lvl, "wage": Club.staff_wage(lvl)}
	return {"ok": true, "key": "ui.staff.hired", "fee": fee}


## The Department's gate-receipt share per match played (clubs have no stadium of their own).
## `fill` = pitch occupancy (Grounds.attendance): receipts rise or fall with attendance (0.7 = expected).
static func match_income(w: World, club: Club, rival: Club, rng: SimRng, fill: float = 0.7) -> int:
	var base: float = 0.0375 * (club.reputation + rival.reputation) / 2.0
	var comp := w.league_of(club.id)
	var matches_per_season: float = 24.0
	if comp != null and comp.club_ids.size() > 1:
		matches_per_season = float(2 * (comp.club_ids.size() - 1))
	base *= 24.0 / matches_per_season
	if Rivalries.are_rivals(w, club.id, rival.id):
		base *= Rivalries.GATE_BONUS
	var income: int = int(base * (0.8 + 0.4 * rng.next()) * (fill / 0.7))
	book(w, club, "gate", income)
	return income


static func monthly_sponsor(w: World, club: Club) -> int:
	var m: int = int(club.sponsor.get("monthly", 0))
	book(w, club, "sponsor", m)
	return m


## Monthly merchandising: based on reputation, last season's titles and fan mood.
static func monthly_merch(w: World, club: Club) -> int:  # [GoF 7] [FILLER]
	var titles := 0
	for h in w.history:
		if int(h["season"]) == w.season - 1 and str(h.get("champion_id", "")) == club.id:
			titles += 1
	var m := int(club.reputation * 0.02 * (1.0 + 0.1 * titles) * Fans.merch_factor(club))
	book(w, club, "merch", m)
	return m


## Lowest league position that still meets the board's objective, scaled to the size of the club's league.
static func objective_pos(w: World, club: Club) -> int:
	var league := w.league_of(club.id)
	var n: int = league.club_ids.size() if league != null else 13
	match str(club.board.get("objective", "")):
		"title":
			return 1
		"top_half":
			return maxi(1, (n + 1) / 2)
		"mid_table":
			return maxi(1, int(round(n * 9.0 / 13.0)))
		"avoid_last":
			return maxi(1, n - 1)
	return int(club.board.get("objective_min_pos", 7))


## The board's objective for a season from the club's reputation rank in its league (1 = the biggest
## name of `n`) and last season's finish (`last_pos`, 0 if unknown), which weighs a third. Only the league's biggest
## name, or the defending champion, is asked for the title.
static func objective_for_rank(rank: int, n: int, last_pos: int = 0) -> String:  # [game]
	if (rank == 1 and last_pos <= 3) or last_pos == 1:
		return "title"
	var expected := float(rank) if last_pos <= 0 else (2.0 * rank + last_pos) / 3.0
	if expected <= (n + 1) / 2.0:
		return "top_half"
	if expected <= n * 9.0 / 13.0:
		return "mid_table"
	return "avoid_last"


## Typical weekly wage budget and reputation of a club of each level.
const LEVEL_WAGE_BUDGET := [400.0, 400.0, 250.0, 150.0]
const LEVEL_REPUTATION := [8000.0, 8000.0, 4800.0, 2500.0]


## The board's weekly wage budget for a season: the level's typical budget, scaled by the club's reputation
## against the level's typical name (0.8 to 1.3), a tenth more after a title and a tenth less after finishing in the
## bottom two or with the club in the red. Rounded to 5 G.
static func wage_budget_for(club: Club, last_pos: int, n: int) -> int:  # [game]
	var lvl := clampi(club.level, 1, 3)
	var b: float = float(LEVEL_WAGE_BUDGET[lvl]) * clampf(float(club.reputation) / float(LEVEL_REPUTATION[lvl]), 0.8, 1.3)
	if last_pos == 1:
		b *= 1.1
	elif last_pos > 0 and last_pos >= n - 1:
		b *= 0.9
	if club.balance < 0:
		b *= 0.9
	return maxi(5, int(round(b / 5.0)) * 5)


## Monthly board evaluation: confidence from position vs. objective. Skipped until the club has played a league
## match.
static func board_review(w: World, club: Club, comp: Competition, table: Array = []) -> void:
	var pos := -1
	if table.is_empty():
		table = comp.standings()
	for i in table.size():
		if table[i]["club_id"] == club.id:
			if int(table[i].get("pj", 0)) == 0:
				return
			pos = i + 1
	if pos <= 0:
		return
	var target: int = objective_pos(w, club)
	var results: float = clampf(55.0 + float(target - pos) * 7.0, 15.0, 92.0)
	var bill := 0
	for p in w.squad_of(club.id):
		bill += int(p.contract.get("wage_weekly", 10))
	var year_bill := maxf(float(bill) * 52.0, 1.0)
	var finances: float = 50.0 + 30.0 * clampf(float(club.balance) / year_bill, -1.0, 1.0)
	if club.board.has("last_balance"):
		finances += clampf(float(club.balance - int(club.board["last_balance"])) / maxf(float(bill) * 4.0, 1.0) * 10.0, -20.0, 10.0)
	club.board["last_balance"] = club.balance
	if bill > club.wage_budget_weekly * 1.15:
		finances -= 10.0
	finances = clampf(finances, 10.0, 90.0)
	var fans: float = Fans.mood(club)
	club.board["areas"] = {"results": int(results), "finances": int(finances), "fans": int(fans)}
	var deserved: float = clampf(results * 0.6 + finances * 0.2 + fans * 0.2, 15.0, 92.0)
	var conf: float = float(club.board.get("confidence", 60.0))
	conf = clampf(conf + (deserved - conf) * 0.3, 0.0, 100.0)
	club.board["confidence"] = conf


## Season end: objective fulfilment and sackings. For the manager's club a cup won that season (national,
## continental or the European Cup) also meets the objective, and a manager hired after New Year has not had half a
## season to be sacked for.
static func season_verdict(w: World, club: Club, final_pos: int) -> String:
	var target: int = objective_pos(w, club)
	var conf: float = float(club.board.get("confidence", 60.0))
	var league := w.league_of(club.id)
	var last_pos: int = league.club_ids.size() if league != null else 99
	if final_pos <= target or (club.manager_is_human and _won_cup(w, club.id)):
		club.board["confidence"] = minf(100.0, conf + 15.0)
		club.board["missed_streak"] = 0
		club.board["last_streak"] = 0
		return "met"
	var missed: int = int(club.board.get("missed_streak", 0)) + 1
	var lasts: int = (int(club.board.get("last_streak", 0)) + 1) if final_pos >= last_pos else 0
	club.board["missed_streak"] = missed
	club.board["last_streak"] = lasts
	var late_hire: bool = club.manager_is_human and int(club.board.get("manager_since", 0)) > WDate.from_ymd(w.season + 1, 1, 1)
	if not late_hire and ((final_pos > target + 4 and conf < 50.0) or conf < 20.0 or missed >= 3 or lasts >= 2):
		club.board["confidence"] = 40.0
		club.board["missed_streak"] = 0
		club.board["last_streak"] = 0
		return "sacked"
	club.board["confidence"] = maxf(20.0, conf - 10.0)
	return "missed"


static func _won_cup(w: World, club_id: String) -> bool:
	for h in w.history:
		if int(h.get("season", -1)) != w.season or str(h.get("champion_id", "")) != club_id:
			continue
		var c: Competition = w.competitions.get(str(h.get("competition_id", "")))
		if c != null and ["national_cup", "cont_knockout", "cup"].has(c.type):
			return true
	return false


## Asking price a club sets for a player.
static func asking_price(w: World, p: Player) -> int:
	var v := p.market_value(w.today)
	if p.transfer_listed:
		return int(v * 0.85)
	return int(v * 1.3)


## Does an AI club accept selling this player for this offer?
static func ai_accepts_sale(w: World, club: Club, p: Player, offer: int, rng: SimRng) -> bool:
	if p.is_captain and rng.chance(0.7):
		return false
	var ask := asking_price(w, p)
	var starters := 0
	for q in w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
		if q.position == p.position:
			starters += 1
	if starters <= 1 and p.squad == Player.Squad.FIRST and rng.chance(0.8):
		return false
	return offer >= ask or (offer >= ask * 0.9 and rng.chance(0.4))


## Player agent demands: requested wage and signing fee (commission).
static func agent_demand(w: World, p: Player, to_club: Club, fee: int) -> Dictionary:  # [FILLER]
	var current: int = int(p.contract.get("wage_weekly", 10))
	var amb: float = (p.hid("ambition") - 10.0) / 10.0
	var wage: int = int(maxf(current * (1.15 + 0.1 * amb), p.market_value(w.today) / 38.0))
	if to_club.level < 2:
		wage = int(wage * 1.05)
	var bonus: int = int(maxf(fee * 0.07, wage * 2))
	return {"wage": maxi(wage, 4), "bonus": bonus}


## Value an AI club assigns to a player offered in a swap (less if it doesn't need them).
static func swap_value(w: World, club: Club, p: Player) -> int:
	var v := p.market_value(w.today)
	var same := 0
	for q in w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
		if q.position == p.position:
			same += 1
	if same >= 4:
		v = int(v * 0.6)
	if p.age(w.today) >= 31:
		v = int(v * 0.7)
	return v


## Does the player accept the contract at the destination club?
static func player_accepts(w: World, p: Player, to_club: Club, wage: int, rng: SimRng) -> bool:
	if to_club.is_women_only() and p.gender != SimPlayer.Gender.F:
		return false
	var current: int = int(p.contract.get("wage_weekly", 10))
	var from_club: Club = w.club(p.club_id)
	var amb: float = (p.hid("ambition") - 10.0) / 10.0
	var loy: float = (p.hid("loyalty") - 10.0) / 10.0
	var score: float = float(wage - current) / maxf(current, 1.0)
	if from_club != null:
		if to_club.level < from_club.level:
			score += 0.15 * (1.0 + amb)
		elif to_club.level > from_club.level:
			score -= 0.15 * (1.0 - amb)
		score -= 0.2 * loy
	else:
		score += 0.3
	return score > 0.05 or rng.chance(0.15)


## Does the player accept a loan? A reserve wants minutes; only rejects a much weaker destination if ambitious.
static func player_accepts_loan(w: World, p: Player, to_club: Club, rng: SimRng) -> bool:
	if to_club.is_women_only() and p.gender != SimPlayer.Gender.F:
		return false
	var from_club: Club = w.club(p.club_id)
	var amb: float = (p.hid("ambition") - 10.0) / 10.0
	var score := 0.3 if p.squad in Player.Squad.DEVELOPING else 0.05
	if from_club != null and to_club.level > from_club.level:
		score -= 0.15 * (to_club.level - from_club.level) * (1.0 + amb)
	return score > 0.0 or rng.chance(0.15)


## Executes a transfer. `fee` is the full agreed fee (transfer budget, history and sell-on share); `cash_now` is the
## part paid today when the rest is deferred in instalments (-1 = the whole fee is paid now).
static func execute_transfer(w: World, p: Player, to_club_id: String, fee: int, wage: int, years: int, cash_now: int = -1) -> void:
	var from_id := p.club_id
	var paid := fee if cash_now < 0 else cash_now
	if fee > 0 and not p.sell_on.is_empty() and str(p.sell_on.get("club_id", "")) != to_club_id:
		var so: Club = w.club(str(p.sell_on["club_id"]))
		var cut := int(fee * float(p.sell_on.get("pct", 0)) / 100.0)
		if so != null and cut > 0 and from_id != so.id:
			book(w, so, "transfers_in", cut)
			if w.clubs.has(from_id):
				book(w, w.clubs[from_id], "transfers_out", -cut)
			if so.manager_is_human:
				Inbox.tell(w, &"from.club_secretary", "msg.sell_on_paid.subject", "msg.sell_on_paid.body", {"player": Say.player(p), "club": Say.team(w, to_club_id), "amount": Say.money(cut)})
		p.sell_on = {}
	if from_id != "" and w.clubs.has(from_id):
		book(w, w.clubs[from_id], "transfers_in", paid)
		if w.clubs[from_id].manager_is_human:
			w.clubs[from_id].transfer_budget += fee / 2
	if w.clubs.has(to_club_id):
		book(w, w.clubs[to_club_id], "transfers_out", -paid)
		if w.clubs[to_club_id].manager_is_human:
			w.clubs[to_club_id].transfer_budget = maxi(0, w.clubs[to_club_id].transfer_budget - fee)
	if from_id != "" and w.clubs.has(from_id) and int(p.stats_for(w.season).get("apps", 0)) > 0:
		var top := true
		for q in w.squad_of(from_id):
			if q.id != p.id and int(q.stats_for(w.season).get("apps", 0)) > int(p.stats_for(w.season).get("apps", 0)):
				top = false
				break
		if top:
			Fans.idol_sold(w.clubs[from_id])
	p.loan = null
	p.loan_listed = false
	p.loan_option_fee = 0
	if p.pre_contract != null and p.pre_contract.club_id != to_club_id:
		p.pre_contract = null
	w.move_player(p, to_club_id, "first" if p.ca() >= 95.0 else "reserve")
	p.transfer_listed = false
	p.free_since = 0
	var was_captain := p.is_captain
	p.is_captain = false
	p.contract = {"wage_weekly": wage, "end_day": Contracts.end_day_for(w, years), "role": "first_team" if p.squad == Player.Squad.FIRST else "rotation"}
	p.morale = clampf(p.morale + 10.0, 0.0, 100.0)
	w.log_transfer(p.id, from_id, to_club_id, fee)
	if was_captain and from_id != "" and w.clubs.has(from_id):
		WorldGenerator.ensure_captain(w, w.clubs[from_id])
		if w.clubs[from_id].manager_is_human:
			notify_new_captain(w, from_id)


## Tells the manager who the captain is now. Several departures on one day (the 1 July rollover) send a single owl
## with the final choice: earlier "new captain" owls from today are withdrawn.
static func notify_new_captain(w: World, club_id: String) -> void:
	var cap: Player = null
	for q in w.squad_of(club_id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
		if q.is_captain:
			cap = q
	if cap == null:
		return
	Inbox.tell(w, &"from.club_secretary", "msg.new_captain.subject", "msg.new_captain.body", {"player": Say.player(cap)}, Inbox.REPLACES_TODAY)


## Loan until 30 June of the current season, never past the end of the player's contract. The receiving club pays
## the wage.
static func execute_loan(w: World, p: Player, to_club_id: String) -> void:
	var owner := p.club_id
	var until := WDate.from_ymd(w.season + 1, 6, 30)
	if int(p.contract.get("end_day", 0)) > 0:
		until = mini(until, int(p.contract["end_day"]))
	p.loan = Player.Loan.new(owner, until, p.squad, p.loan_option_fee)
	p.loan_option_fee = 0
	p.loan_listed = false
	p.transfer_listed = false
	var was_captain := p.is_captain
	p.is_captain = false
	w.move_player(p, to_club_id, "first" if p.ca() >= 95.0 else "reserve")
	if was_captain and w.clubs.has(owner):
		WorldGenerator.ensure_captain(w, w.clubs[owner])
	p.morale = clampf(p.morale + 5.0, 0.0, 100.0)
	w.log_transfer(p.id, owner, to_club_id, 0, true)


## End of loan: returns to the parent club (called by the engine on season change).
static func return_loan(w: World, p: Player) -> void:
	var owner := p.loan_owner_id()
	var squad: String = p.loan.owner_squad if p.loan != null else Player.Squad.RESERVE
	p.loan = null
	p.is_captain = false
	if owner != "" and w.clubs.has(owner):
		w.move_player(p, owner, squad if squad != Player.Squad.YOUTH else Player.Squad.RESERVE)
	else:
		var borrower := p.club_id
		w.move_player(p, "", "free")
		w.log_release(p.id, borrower)
		p.free_since = w.season


static func lineup_has(club: Club, pid: String) -> bool:
	var l := club.lineup
	return str(l.get("K", "")) == pid or str(l.get("S", "")) == pid or l.get("C", []).has(pid) or l.get("B", []).has(pid)


## Does the AI club loan out this player? It loans those who are not clear starters (or young reserves).
static func ai_accepts_loan(w: World, club: Club, p: Player) -> bool:
	if p.is_on_loan() or p.is_captain or not seller_can_release(w, p):
		return false
	if p.squad in Player.Squad.DEVELOPING:
		return true
	var squad := w.squad_of(club.id, [Player.Squad.FIRST])
	squad.sort_custom(func(a, b): return a.ca() > b.ca() if a.ca() != b.ca() else a.id < b.id)
	var rank := squad.find(p)
	return rank >= 7


## Daily Prophet item for an AI signing: the fee as money or a free transfer, and the ids of the player and both
## clubs for the links. `fee` is also kept on the item to rank foreign transfers.
static func transfer_news(w: World, p: Player, to_club: Club, from_id: String, fee: int) -> Dictionary:
	return NewsGenerator.item("news.transfer" if fee > 0 else "news.transfer_free", 3, {"player": Say.player(p), "to": Say.club(to_club),
		"from": Say.team(w, from_id) if w.clubs.has(from_id) else Say.plain(""), "fee": Say.money(fee)}, {"clubs": [to_club.id, from_id], "fee": fee})


## Players who already changed club (transfer or loan) this season: the AI won't move them again until the next.
static func moved_this_season(w: World) -> Dictionary:
	var since := WDate.from_ymd(w.season, 7, 1)
	var out := {}
	for t in w.transfers:
		if int(t.get("day", 0)) < since:
			break
		if not World.is_release(t):
			out[str(t["player_id"])] = true
	return out


static func _ai_upgrade_purchase(w: World, club: Club, rng: SimRng, log: Array) -> void:
	var l := club.lineup
	if l.is_empty():
		return
	var starters: Array = [l.get("K", "")] + l.get("C", []) + l.get("B", []) + [l.get("S", "")]
	var weakest: Player = null
	for pid in starters:
		var p: Player = w.player(str(pid))
		if p != null and (weakest == null or p.ca() < weakest.ca()):
			weakest = p
	if weakest == null:
		return
	var pos := weakest.position
	var best: Player = null
	var best_fee := 0
	var weakest_ca := weakest.ca()
	var moved := moved_this_season(w)
	for other in w.clubs_sorted():
		if other.id == club.id or other.manager_is_human or other.reputation >= club.reputation:
			continue
		if other.region_id != club.region_id and club.level > 1:
			continue
		if club.is_women_only() == false and other.is_women_only():
			continue
		for p in w.squad_of(other.id, Player.Squad.SENIOR):
			if p.position != pos or p.ca() < weakest_ca + 8.0:
				continue
			if p.is_captain or p.is_on_loan() or moved.has(p.id) or p.pre_contract != null:
				continue
			if club.is_women_only() and p.gender != SimPlayer.Gender.F:
				continue
			var fee := asking_price(w, p)
			if fee > club.transfer_budget or fee > club.balance:
				continue
			if not seller_can_release(w, p):
				continue
			if best == null or p.ca() > best.ca():
				best = p
				best_fee = fee
	if best == null:
		return
	var wage: int = int(maxf(int(best.contract.get("wage_weekly", 10)) * 1.2, 6))
	if not player_accepts(w, best, club, wage, rng):
		return
	var seller: Club = w.club(best.club_id)
	execute_transfer(w, best, club.id, best_fee, wage, rng.irange(2, 4))
	club.transfer_budget -= best_fee
	if seller != null:
		seller.lineup = WorldGenerator.best_lineup(w, seller.id)
	club.lineup = WorldGenerator.best_lineup(w, club.id)
	if w.squad_of(club.id).size() > 15:
		var worst: Player = null
		for p in w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
			if p.position == pos and p.id != best.id and not p.is_captain and not p.is_on_loan() and (worst == null or p.ca() < worst.ca()):
				worst = p
		if worst != null and seller_can_release(w, worst):
			w.move_player(worst, "", "free")
			w.log_release(worst.id, club.id)
			worst.free_since = w.season
	log.append(transfer_news(w, best, club, seller.id if seller else "", best_fee))


## A club can let `p` go, sold or loaned out, if it keeps at least its position minimum (2 K, 3 C, 2 B, 1 S) between
## first team and reserves. Two Keepers, so that one injury or call-up does not put an outfield player in goal.
static func seller_can_release(w: World, p: Player) -> bool:
	var minimum := {"K": 2, "C": 3, "B": 2, "S": 1}
	var n := 0
	var is_house := Schools.is_house(p.club_id)
	for q in w.club_players(p.club_id):
		if not is_house and q.squad not in Player.Squad.SENIOR:
			continue
		if q.position == p.position and q.id != p.id and not q.is_on_loan():
			n += 1
	return n >= int(minimum.get(p.position, 1))


static func ai_transfer_tick(w: World, rng: SimRng, log: Array) -> void:
	var ctx := ai_transfer_begin(w)
	for club in w.clubs_sorted():
		ai_transfer_club(w, rng, log, ctx, club)


## The tick's shared state, computed once per tick: the candidates for sale and on loan by position
## ({pool, loan_pool}; the clubs' turns take players out of them).
static func ai_transfer_begin(w: World) -> Dictionary:
	var pool := {"K": [] as Array[Player], "C": [] as Array[Player], "B": [] as Array[Player], "S": [] as Array[Player]}
	for p in w.free_agents():
		if p.pre_contract == null:
			pool[p.position].append(p)
	var loan_pool := {"K": [] as Array[Player], "C": [] as Array[Player], "B": [] as Array[Player], "S": [] as Array[Player]}
	var moved := moved_this_season(w)
	for p in w.players_sorted():
		if moved.has(p.id) or p.pre_contract != null:
			continue
		if p.transfer_listed and p.club_id != "" and not p.is_on_loan():
			pool[p.position].append(p)
		elif p.loan_listed and p.club_id != "" and not p.is_on_loan():
			loan_pool[p.position].append(p)
	for pos in pool.keys():
		loan_pool[pos].sort_custom(func(a, b): return a.ca() > b.ca() if a.ca() != b.ca() else a.id < b.id)
		pool[pos].sort_custom(func(a, b): return a.ca() > b.ca() if a.ca() != b.ca() else a.id < b.id)
	return {"pool": pool, "loan_pool": loan_pool}


## One club's turn of the tick, in w.clubs_sorted() order: signings for its gaps, loans, a reinforcement, and the
## cuts and listings a club in the red makes.
static func ai_transfer_club(w: World, rng: SimRng, log: Array, ctx: Dictionary, club: Club) -> void:
	var pool: Dictionary = ctx["pool"]
	var loan_pool: Dictionary = ctx["loan_pool"]
	if club.manager_is_human:
		return
	var all_players := w.club_players(club.id)
	if all_players.size() >= 18:
		return
	var count := {"K": 0, "C": 0, "B": 0, "S": 0}
	for p in all_players:
		if p.squad in Player.Squad.SENIOR:
			count[p.position] += 1
	var need := {"K": 2, "C": 5, "B": 3, "S": 2}
	for pos in ["K", "C", "B", "S"]:
		var size_now := w.club_players(club.id).size()
		if size_now >= 18:
			break
		var wants_loan: bool = count[pos] <= need[pos] and size_now < 17
		var filled := false
		var candidates: Array[Player] = pool[pos] if count[pos] < need[pos] else ([] as Array[Player])
		for p in candidates:
			if p.club_id == club.id or (p.club_id != "" and not p.transfer_listed):
				continue
			if p.club_id != "" and w.clubs.has(p.club_id) and w.clubs[p.club_id].manager_is_human:
				continue
			if club.is_women_only() and p.gender != SimPlayer.Gender.F:
				continue
			if p.club_id != "" and not seller_can_release(w, p):
				continue
			var fee := 0 if p.club_id == "" else asking_price(w, p)
			if fee > club.transfer_budget or fee > club.balance:
				continue
			var wage: int = int(maxf(int(p.contract.get("wage_weekly", 10)) * 1.1, 6))
			if not player_accepts(w, p, club, wage, rng):
				continue
			execute_transfer(w, p, club.id, fee, wage, rng.irange(1, 3))
			club.transfer_budget -= fee
			pool[pos].erase(p)
			log.append(transfer_news(w, p, club, str(w.transfers[0]["from_id"]), fee))
			filled = true
			break
		if filled or not wants_loan:
			continue
		for p in loan_pool[pos]:
			if p.club_id == club.id or p.club_id == "" or not w.clubs.has(p.club_id) or p.is_on_loan() or (club.is_women_only() and p.gender != SimPlayer.Gender.F):
				continue
			if not seller_can_release(w, p):
				continue
			if not rng.chance(0.5):
				continue
			var owner: Club = w.club(p.club_id)
			execute_loan(w, p, club.id)
			loan_pool[pos].erase(p)
			if owner != null and owner.manager_is_human:
				Inbox.tell(w, &"from.club_secretary", "msg.loan_out.subject", "msg.loan_out.body", {"player": Say.player(p), "club": Say.club(club)})
			log.append(NewsGenerator.item("news.loan", 2, {"player": Say.player(p), "to": Say.club(club), "from": (Say.club(owner) if owner else Say.plain(""))}, {"clubs": [club.id, owner.id if owner else ""]}))
			break
	if club.transfer_budget >= 300 and club.balance > 500 and rng.chance(0.12):
		_ai_upgrade_purchase(w, club, rng, log)
	if rng.chance(0.15):
		var cand: Player = null
		for p in all_players:
			if p.squad == Player.Squad.RESERVE and p.age(w.today) <= 21 and count[p.position] >= need[p.position] and not p.loan_listed and not p.transfer_listed and not p.is_on_loan():
				if cand == null or p.ca() < cand.ca():
					cand = p
		if cand != null:
			cand.loan_listed = true
	if club.balance < 0:
		var worst_role := ""
		var worst_wage := 0
		for role in club.staff.keys():
			if int(club.staff[role].get("wage", 0)) > worst_wage and int(club.staff[role].get("level", 1)) > 1:
				worst_wage = int(club.staff[role].get("wage", 0))
				worst_role = str(role)
		if worst_role != "":
			var lvl: int = int(club.staff[worst_role]["level"]) - 1
			club.staff[worst_role]["level"] = lvl
			club.staff[worst_role]["wage"] = Club.staff_wage(lvl)
	if club.balance > 0:
		for p in w.squad_of(club.id, [Player.Squad.FIRST]):
			p.transfer_listed = false
	if club.balance < -3000:
		club.transfer_budget = 0
		var best: Player = null
		for p in w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
			if not p.is_captain and not p.is_on_loan() and seller_can_release(w, p) and (best == null or p.market_value(w.today) > best.market_value(w.today)):
				best = p
		if best != null:
			best.transfer_listed = true
	if club.balance < 0:
		var squad := w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE])
		if not squad.is_empty():
			var worst: Player = squad[squad.size() - 1]
			if worst.squad == Player.Squad.RESERVE and not worst.is_on_loan():
				worst.transfer_listed = true
