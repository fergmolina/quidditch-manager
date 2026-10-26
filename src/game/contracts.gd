class_name Contracts  # [game]
extends RefCounted
## Contexts: "renew" (renewing one of your own), "free" (free agent), "transfer" (the selling club already accepted the
## transfer), "pre" (pre-contract with a player whose contract is ending at another club), "graduate" (a final-year
## student, who joins on leaving school).

const ROLES := ["star", "first_team", "rotation", "reserve", "youth"]
const MAX_ROUNDS := 3


## Role the player deserves by level within the club's squad (rank by CA).
static func deserved_role(w: World, p: Player, club: Club) -> String:
	if p.age(w.today) < 19 and p.ca() < 95.0:
		return "youth"
	var better := 0
	for q in w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
		if q.id != p.id and q.ca() > p.ca():
			better += 1
	if better < 2:
		return "star"
	if better < 7:
		return "first_team"
	if better < 11:
		return "rotation"
	return "reserve"


## What the player asks for: {wage, years, role, signing_fee}.
static func demand(w: World, p: Player, club: Club, context: String, fee: int = 0) -> Dictionary:
	var current: int = int(p.contract.get("wage_weekly", 10))
	var amb: float = (p.hid("ambition") - 10.0) / 10.0
	var value := p.market_value(w.today)
	var wage := 0
	var signing := 0
	match context:
		"renew":
			wage = int(maxf(current * (1.0 + 0.1 * p.hid("ambition") / 10.0), value / 40.0))
		"transfer":
			var d := Economy.agent_demand(w, p, club, fee)
			wage = int(d["wage"])
			signing = int(d["bonus"])
		_:
			wage = int(maxf(value / 40.0, current * 1.05))
			signing = int(wage * 3)
	var role := deserved_role(w, p, club)
	if amb > 0.4 and ROLES.find(role) > 0 and role != "youth":
		role = ROLES[ROLES.find(role) - 1]
	var age := p.age(w.today)
	var years := 4 if age >= 30 else (3 if age >= 24 else 2)
	return {"wage": maxi(wage, 4), "years": years, "role": role, "signing_fee": signing}


## Initial dialog terms: what the player asks for, with no bonuses or clause.
static func default_terms(w: World, p: Player, club: Club, context: String, fee: int = 0) -> Dictionary:
	var d := demand(w, p, club, context, fee)
	return {"wage_weekly": int(d["wage"]), "years": int(d["years"]), "role": str(d["role"]), "signing_fee": int(d["signing_fee"]),
		"bonus_goal": 0, "bonus_catch": 0, "bonus_title": 0, "yearly_rise_pct": 0, "release_clause": 0}


## Equivalent weekly value of a package, to compare against what the player asks.
static func package_value(w: World, p: Player, t: Dictionary) -> float:
	var st: Dictionary = p.season_stats.get(str(w.season - 1), {})
	if int(st.get("apps", 0)) == 0:
		st = p.season_stats.get(str(w.season), {})
	var weeks := 52.0
	var goals_week := float(st.get("goals", 0)) / weeks
	var catches_week := float(st.get("catches", 0)) / weeks
	var years := maxf(float(t.get("years", 2)), 1.0)
	var v := float(t.get("wage_weekly", 0))
	v += float(t.get("signing_fee", 0)) / (weeks * years)
	v += float(t.get("bonus_goal", 0)) * goals_week * 0.8
	v += float(t.get("bonus_catch", 0)) * catches_week * 0.8
	v += float(t.get("bonus_title", 0)) / weeks * 0.25
	v += float(t.get("wage_weekly", 0)) * float(t.get("yearly_rise_pct", 0)) / 100.0 * (years - 1.0) / 2.0
	return v


## Equivalent weekly wage the player needs to accept a package with this role, years and clause.
static func required_value(w: World, p: Player, club: Club, terms: Dictionary, context: String, fee: int = 0) -> float:
	var d := demand(w, p, club, context, fee)
	var required := float(d["wage"])
	var steps := ROLES.find(str(terms.get("role", "rotation"))) - ROLES.find(str(d["role"]))
	if steps > 0:
		required *= 1.0 + 0.15 * steps
	elif steps < 0:
		required *= 1.0 + 0.04 * steps
	var year_gap := int(d["years"]) - int(terms.get("years", 2))
	if year_gap > 0:
		required *= 1.0 + 0.05 * year_gap
	var amb: float = (p.hid("ambition") - 10.0) / 10.0
	var clause := int(terms.get("release_clause", 0))
	var value := maxf(p.market_value(w.today), 1.0)
	if clause > 0 and clause < value * 1.5:
		required *= 1.0 - 0.06 * maxf(amb, 0.0) - 0.02
	elif clause == 0 and amb > 0.3:
		required *= 1.03
	if context == "renew":
		required *= 1.0 - 0.08 * maxf((p.hid("loyalty") - 10.0) / 10.0, 0.0)
	return required


## Evaluates an offer: {accept, counter (terms they would accept), reason, final}.
static func evaluate(w: World, p: Player, club: Club, terms: Dictionary, context: String, fee: int = 0) -> Dictionary:
	if club.is_women_only() and p.gender != SimPlayer.Gender.F:
		return {"accept": false, "counter": {}, "reason": "ui.market.harpies_only_witches", "final": true}
	if context == "renew" and p.pre_contract != null:
		return {"accept": false, "counter": {}, "reason": "ui.contract.has_pre_contract", "final": true}
	if w.today < p.talks_blocked_until:
		return {"accept": false, "counter": {}, "reason": "ui.contract.blocked", "final": true}
	if package_value(w, p, terms) >= required_value(w, p, club, terms, context, fee) * 0.97:
		return {"accept": true, "counter": terms, "reason": "ui.contract.accepted", "final": true}
	var d := demand(w, p, club, context, fee)
	var counter := terms.duplicate()
	if ROLES.find(str(terms.get("role", "rotation"))) > ROLES.find(str(d["role"])):
		counter["role"] = str(d["role"])
	var extras := package_value(w, p, counter) - float(counter.get("wage_weekly", 0))
	counter["wage_weekly"] = maxi(int(ceilf(required_value(w, p, club, counter, context, fee) - extras)) + 1, int(terms.get("wage_weekly", 0)) + 1)
	return {"accept": false, "counter": counter, "reason": "ui.contract.counter", "final": false}


## One negotiation round from the UI: keeps count of rounds and locks after the third.
static func propose(w: World, p: Player, club: Club, terms: Dictionary, context: String, rounds: int, fee: int = 0) -> Dictionary:
	var r := evaluate(w, p, club, terms, context, fee)
	if not bool(r["accept"]) and not bool(r.get("final", false)) and rounds + 1 >= MAX_ROUNDS:
		p.talks_blocked_until = w.today + 30
		r["final"] = true
		r["reason"] = "ui.contract.walked"
	return r


## Last day (30 June) of a contract of `years` seasons signed today. From June the season being played is over, so
## the years count from the next one.
static func end_day_for(w: World, years: int) -> int:
	var base := w.season + (1 if w.today >= WDate.from_ymd(w.season + 1, 6, 1) else 0)
	return WDate.from_ymd(base + maxi(years, 1), 6, 30)


## Applies the terms to the player (already at the destination club).
static func apply_terms(w: World, p: Player, t: Dictionary) -> void:
	p.contract = {
		"wage_weekly": int(t.get("wage_weekly", 10)), "end_day": end_day_for(w, int(t.get("years", 2))),
		"role": str(t.get("role", "rotation")), "bonus_goal": int(t.get("bonus_goal", 0)), "bonus_catch": int(t.get("bonus_catch", 0)),
		"bonus_title": int(t.get("bonus_title", 0)), "yearly_rise_pct": int(t.get("yearly_rise_pct", 0)), "release_clause": int(t.get("release_clause", 0)),
		"start_day": w.today,
	}
	p.happiness.erase("contract")


## The club that holds the player's contract: a loanee's club_id is the borrower, the contract stays with the owner.
static func holder_id(p: Player) -> String:
	return p.loan.owner_id if p.is_on_loan() else p.club_id


## Sign: renews, signs a free agent, closes a transfer or leaves the pre-contract signed. Returns {ok, key}.
static func sign(w: World, p: Player, club: Club, t: Dictionary, context: String, fee: int = 0, swap_player_id: String = "", installments: int = 1) -> Dictionary:
	var signing := int(t.get("signing_fee", 0))
	match context:
		"renew":
			if p.pre_contract != null:
				return {"ok": false, "key": "ui.contract.has_pre_contract"}
			if holder_id(p) != club.id:
				return {"ok": false, "key": "ui.market.on_loan_no_action"}
			if signing > 0 and club.balance < signing:
				return {"ok": false, "key": "ui.market.no_funds"}
			Economy.book(w, club, "signing_fees", -signing)
			apply_terms(w, p, t)
			p.morale = clampf(p.morale + 8.0, 0.0, 100.0)
			return {"ok": true, "key": "ui.market.renewed"}
		"free":
			if not (p.club_id == "" and p.squad == Player.Squad.FREE):
				return {"ok": false, "key": "ui.market.not_free"}
			if MarketActions.embargoed(club):
				return {"ok": false, "key": "ui.market.embargo_free"}
			if signing > 0 and club.balance < signing:
				return {"ok": false, "key": "ui.market.no_funds"}
			Economy.book(w, club, "signing_fees", -signing)
			Economy.execute_transfer(w, p, club.id, 0, int(t["wage_weekly"]), int(t["years"]))
			apply_terms(w, p, t)
			Inbox.tell(w, &"from.club_secretary", "msg.signed.subject", "msg.signed.body", {"player": Say.player(p), "wage": Say.money(int(t["wage_weekly"])), "years": Say.num(int(t["years"]))})
			return {"ok": true, "key": "ui.market.signed"}
		"transfer":
			var problem := MarketActions.deal_problem(w, p, club, MarketActions.accepted_seller_id(w, p, club), swap_player_id)
			if problem != "":
				MarketActions.close_accepted_offer(w, p, club, "void")
				return {"ok": false, "key": problem}
			if MarketActions.embargoed(club):
				return {"ok": false, "key": "ui.market.embargo"}
			var fee_first := fee / maxi(installments, 1)
			if club.balance < fee_first + signing:
				return {"ok": false, "key": "ui.market.no_funds"}
			if club.manager_is_human and fee > club.transfer_budget:
				return {"ok": false, "key": "ui.market.over_budget"}
			var seller_id := p.club_id
			var swap: Player = w.player(swap_player_id)
			var deferred := MarketActions.schedule_installments(w, club.id, seller_id, fee, installments, p.name())
			Economy.execute_transfer(w, p, club.id, fee, int(t["wage_weekly"]), int(t["years"]), fee - deferred)
			MarketActions.close_accepted_offer(w, p, club, "signed")
			apply_terms(w, p, t)
			Economy.book(w, club, "signing_fees", -signing)
			if swap != null:
				var was_starter := Economy.lineup_has(club, swap.id)
				Economy.execute_transfer(w, swap, seller_id, 0, int(swap.contract.get("wage_weekly", 10)), 2)
				if was_starter:
					club.lineup = WorldGenerator.best_lineup(w, club.id)
			Inbox.tell(w, &"from.club_secretary", "msg.signed.subject", "msg.signed.body", {"player": Say.player(p), "wage": Say.money(int(t["wage_weekly"])), "years": Say.num(int(t["years"]))})
			return {"ok": true, "key": "ui.market.signed"}
		"graduate":
			if not graduate_offer_allowed(w, p, club):
				return {"ok": false, "key": "ui.contract.graduate_not_allowed"}
			if signing > 0 and club.balance < signing:
				return {"ok": false, "key": "ui.market.no_funds"}
			p.pre_contract = _pre_contract(club, t, w.today, true)
			Inbox.tell(w, &"from.club_secretary", "msg.graduate_signed.subject", "msg.graduate_signed.body", {"player": Say.player(p), "school": Say.plain(str(p.school_id))})
			return {"ok": true, "key": "ui.contract.graduate_signed"}
		"pre":
			if not pre_contract_allowed(w, p, club):
				return {"ok": false, "key": "ui.contract.pre_not_allowed"}
			if signing > 0 and club.balance < signing:
				return {"ok": false, "key": "ui.market.no_funds"}
			p.pre_contract = _pre_contract(club, t, w.today)
			Inbox.tell(w, &"from.club_secretary", "msg.pre_contract.subject", "msg.pre_contract.body", {"player": Say.player(p), "season": Say.season(w.season + 1)})
			return {"ok": true, "key": "ui.contract.pre_signed"}
	return {"ok": false, "key": "ui.market.not_loanable"}


## The signing fee moves out of the terms onto the pre-contract, which pays it on arrival.
static func _pre_contract(club: Club, t: Dictionary, today: int, graduate: bool = false) -> Player.PreContract:
	var terms := t.duplicate()
	var signing := int(terms.get("signing_fee", 0))
	terms.erase("signing_fee")
	return Player.PreContract.new(club.id, terms, today, graduate, signing)


## From 1 January, a player at another club whose contract ends on 30 June can sign for free for next season.
static func pre_contract_allowed(w: World, p: Player, club: Club) -> bool:  # [game]
	if p.club_id == "" or p.club_id == club.id or p.squad in Player.Squad.AWAY_FROM_CLUBS or p.is_on_loan():
		return false
	if p.pre_contract != null:
		return false
	var m := WDate.month(w.today)
	if m < 1 or m > 6:
		return false
	return int(p.contract.get("end_day", 0)) <= WDate.from_ymd(w.season + 1, 6, 30)


## A club can promise a final-year student a contract for when they leave school: from 1 January to 30 June of
## their seventh year, while no other club holds one. Not in school mode. Not for a student the books send to
## another club on leaving school.
static func graduate_offer_allowed(w: World, p: Player, club: Club) -> bool:  # [game] [GoF 7]
	if club == null or w.is_school_mode() or p.squad != Player.Squad.SCHOOL or p.pre_contract != null:
		return false
	if club.is_women_only() and p.gender != SimPlayer.Gender.F:
		return false
	var book_club := Schools.book_destination(w, p)
	if book_club != "" and book_club != club.id:
		return false
	var m := WDate.month(w.today)
	return m >= 1 and m <= 6 and Schools.school_year(p, w) >= Schools.FINAL_YEAR


## At season close: pre-contracts are executed (called before contract expiries).
static func execute_pre_contracts(w: World) -> Array:
	var done: Array = []
	for p in w.players_sorted():
		if p.pre_contract == null:
			continue
		var cid: String = p.pre_contract.club_id
		var t: Dictionary = p.pre_contract.terms
		var signing: int = p.pre_contract.signing_fee
		p.pre_contract = null
		if not w.clubs.has(cid) or p.club_id == cid:
			continue
		if p.is_on_loan():
			Economy.return_loan(w, p)
		var from_id: String = p.club_id
		Economy.execute_transfer(w, p, cid, 0, int(t.get("wage_weekly", 10)), int(t.get("years", 2)))
		apply_terms(w, p, t)
		Economy.book(w, w.clubs[cid], "signing_fees", -signing)
		done.append({"player_id": p.id, "from_id": from_id, "to_id": cid})
	return done


## The AI offers pre-contracts to the human's best players whose contracts are ending (February-June).
static func ai_pre_contract_tick(w: World, rng: SimRng) -> void:
	var me := w.my_club()
	if me == null or w.is_school_mode() or WDate.month(w.today) < 2 or WDate.month(w.today) > 6:
		return
	for p in w.squad_of(me.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
		if p.squad == Player.Squad.SCHOOL or p.pre_contract != null or int(p.contract.get("end_day", 0)) > WDate.from_ymd(w.season + 1, 6, 30):
			continue
		if p.ca() < 95.0 or not rng.chance(0.12):
			continue
		var buyers: Array = []
		for c in w.clubs_sorted():
			if c.id != me.id and not c.manager_is_human and c.reputation >= me.reputation * 0.8 and (not c.is_women_only() or p.gender == SimPlayer.Gender.F):
				buyers.append(c)
		if buyers.is_empty():
			continue
		var buyer: Club = rng.pick(buyers)
		var t := default_terms(w, p, buyer, "pre")
		t["wage_weekly"] = int(t["wage_weekly"] * 1.1)
		if Economy.player_accepts(w, p, buyer, int(t["wage_weekly"]), rng):
			p.pre_contract = _pre_contract(buyer, t, w.today)
			_close_renewal_talks(w, p)
			var decided := int(p.contract.get("let_go_season", -1)) == w.season
			Inbox.ask(w, Inbox.Decision.new(Inbox.ACK, "", [Inbox.Choice.go("ui.view_profile", &"player", {"player_id": p.id}), Inbox.Choice.ok()]).blocking(not decided),
				&"from.assistant", "msg.pre_contract_lost.subject", "msg.pre_contract_lost.body_decided" if decided else "msg.pre_contract_lost.body",
				{"player": Say.player(p), "club": Say.club(buyer)})


static func _close_renewal_talks(w: World, p: Player) -> void:
	Inbox.close(w, Inbox.find(w, Inbox.COMPLAINT, p.id), Say.phrase("ui.contract.has_pre_contract"))


const LET_GO := &"let_go"


## "Let them go" on the contract review: the players still listed are marked on their contracts for this season, so
## the pre-contract tick reads the decision from the players. A renewed contract is a new dict, which clears it.
static func answer_owl(w: World, d: Inbox.Decision, c: Inbox.Choice) -> Inbox.Reply:
	if c.verb != LET_GO:
		return Inbox.Reply.unhandled(d, c)
	var me := w.my_club()
	var review: Dictionary = me.board.get("contract_review", {}) if me != null else {}
	for pid in review.get("player_ids", []):
		var p: Player = w.player(str(pid))
		if p != null:
			p.contract["let_go_season"] = int(review.get("season", w.season))
	if me != null:
		me.board.erase("contract_review")
	return Inbox.Reply.done(Say.phrase("msg.contracts.outcome_let_go"))


## Per-match bonuses (human club): goal and catch, per the contract.
static func match_bonuses(w: World, club: Club, stats: Dictionary) -> int:
	var total := 0
	for pid in stats.keys():
		var p: Player = w.player(str(pid))
		if p == null or p.club_id != club.id:
			continue
		var st: Dictionary = stats[pid]
		total += int(p.contract.get("bonus_goal", 0)) * int(st.get("goals", 0))
		total += int(p.contract.get("bonus_catch", 0)) * int(st.get("snitch_catch", 0))
	Economy.book(w, club, "bonuses", -total)
	return total


## Title bonus (league or cup) for the club's whole squad.
static func title_bonuses(w: World, club: Club) -> int:
	var total := 0
	for p in w.squad_of(club.id):
		total += int(p.contract.get("bonus_title", 0))
	Economy.book(w, club, "bonuses", -total)
	return total


## Season change (1 July, w.season already the new one): agreed yearly raise. A contract that starts with this
## season is not raised yet.
static func yearly_rises(w: World) -> void:
	var new_from := WDate.from_ymd(w.season, 6, 1)
	var new_to := WDate.from_ymd(w.season, 7, 1)
	for p in w.players.values():
		var pct := int(p.contract.get("yearly_rise_pct", 0))
		var start := int(p.contract.get("start_day", 0))
		if start >= new_from and start <= new_to:
			continue
		if pct > 0 and p.club_id != "":
			p.contract["wage_weekly"] = int(ceilf(int(p.contract.get("wage_weekly", 10)) * (1.0 + pct / 100.0)))
