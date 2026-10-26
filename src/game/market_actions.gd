class_name MarketActions
extends RefCounted
## Human manager market actions: offers, sales, contracts. Replies arrive in the inbox.


## Offer for a player at another club. The AI replies in 1-3 days: accept, reject or counter-offer (up to two rounds).
static func make_offer(w: World, p: Player, fee: int, swap_player_id: String = "", installments: int = 1) -> Dictionary:
	var me := w.my_club()
	if me == null or w.is_school_mode() or p.is_on_loan():
		return {"ok": false, "key": "ui.market.not_loanable"}
	if embargoed(me):
		return {"ok": false, "key": "ui.market.embargo"}
	fee = maxi(fee, 0)
	if fee / maxi(installments, 1) > me.balance:
		return {"ok": false, "key": "ui.market.no_funds"}
	if fee > me.transfer_budget:
		return {"ok": false, "key": "ui.market.over_budget"}
	if me.is_women_only() and p.gender != SimPlayer.Gender.F:
		return {"ok": false, "key": "ui.market.harpies_only_witches"}
	for o in w.pending_offers:
		if str(o["status"]) == "pending" and str(o["player_id"]) == p.id and str(o["from_id"]) == me.id:
			return {"ok": false, "key": "ui.market.offer_pending"}
	var offer := {"id": w.next_offer_id, "day": w.today, "resolve_day": w.today + 1 + (w.rng_state % 3), "player_id": p.id, "from_id": me.id, "to_id": p.club_id, "fee": fee, "wage": int(p.contract.get("wage_weekly", 10)) * 1.15, "status": "pending", "direction": "out", "rounds": 0, "swap_player_id": swap_player_id, "installments": maxi(installments, 1)}
	w.next_offer_id += 1
	w.pending_offers.append(offer)
	return {"ok": true, "key": "ui.market.offer_sent"}


## Swap: one of your own players plus money for the target.
static func make_swap_offer(w: World, target: Player, mine: Player, cash: int) -> Dictionary:
	if mine == null or mine.club_id != w.player_club_id or mine.is_on_loan():
		return {"ok": false, "key": "ui.market.not_loanable"}
	var seller: Club = w.club(target.club_id)
	if seller != null and seller.is_women_only() and mine.gender != SimPlayer.Gender.F:
		return {"ok": false, "key": "ui.market.harpies_only_witches"}
	return make_offer(w, target, cash, mine.id)


## The board has frozen the club's transfers over its debts: no bids, loans in or free signings; selling stays open.
static func embargoed(club: Club) -> bool:
	return club != null and club.manager_is_human and bool(club.board.get("embargo", false))


## Sign a free agent: direct contract.
static func sign_free_agent(w: World, p: Player, wage: int, years: int) -> Dictionary:
	var me := w.my_club()
	if me == null or w.is_school_mode():
		return {"ok": false, "key": "ui.market.not_loanable"}
	if not (p.club_id == "" and p.squad == Player.Squad.FREE):
		return {"ok": false, "key": "ui.market.not_free"}
	if embargoed(me):
		return {"ok": false, "key": "ui.market.embargo"}
	if me.is_women_only() and p.gender != SimPlayer.Gender.F:
		return {"ok": false, "key": "ui.market.harpies_only_witches"}
	if not Economy.player_accepts(w, p, me, wage, w.rng()):
		return {"ok": false, "key": "ui.market.player_refuses"}
	Economy.execute_transfer(w, p, me.id, 0, wage, years)
	Inbox.tell(w, &"from.club_secretary", "msg.signed.subject", "msg.signed.body", {"player": Say.player(p), "wage": Say.money(wage), "years": Say.num(years)})
	return {"ok": true, "key": "ui.market.signed"}


static func toggle_transfer_list(w: World, p: Player) -> void:
	p.transfer_listed = not p.transfer_listed
	if p.transfer_listed:
		p.loan_listed = false


static func toggle_shortlist(w: World, p: Player) -> void:
	if w.shortlist.has(p.id):
		w.shortlist.erase(p.id)
	else:
		w.shortlist.append(p.id)


static func toggle_loan_list(w: World, p: Player) -> void:
	p.loan_listed = not p.loan_listed
	if p.loan_listed:
		p.transfer_listed = false


## Loan in a player from an AI club until season end. Resolved immediately.
static func request_loan(w: World, p: Player, buy_option: int = 0) -> Dictionary:
	var me := w.my_club()
	var owner: Club = w.club(p.club_id)
	if me == null or w.is_school_mode() or owner == null or owner.manager_is_human or p.is_on_loan():
		return {"ok": false, "key": "ui.market.not_loanable"}
	if embargoed(me):
		return {"ok": false, "key": "ui.market.embargo"}
	if me.is_women_only() and p.gender != SimPlayer.Gender.F:
		return {"ok": false, "key": "ui.market.harpies_only_witches"}
	if w.squad_of(me.id).size() >= 17:
		return {"ok": false, "key": "ui.market.squad_full"}
	if not Economy.ai_accepts_loan(w, owner, p):
		return {"ok": false, "key": "ui.market.loan_refused"}
	if buy_option > 0 and buy_option < Economy.asking_price(w, p):
		return {"ok": false, "key": "ui.market.option_too_low"}
	if buy_option > me.transfer_budget:
		return {"ok": false, "key": "ui.market.over_budget"}
	if not Economy.player_accepts_loan(w, p, me, w.rng()):
		return {"ok": false, "key": "ui.market.player_refuses"}
	p.loan_option_fee = buy_option
	Economy.execute_loan(w, p, me.id)
	Inbox.tell(w, &"from.club_secretary", "msg.loan_in.subject", "msg.loan_in.body", {"player": Say.player(p), "club": Say.club(owner), "wage": Say.money(int(p.contract.get("wage_weekly", 10)))})
	return {"ok": true, "key": "ui.market.loan_done"}


## Return a loanee early (the owner always accepts).
static func end_loan_early(w: World, p: Player) -> void:
	var owner: Club = w.club(p.loan_owner_id())
	var borrower: Club = w.club(p.club_id)
	Economy.return_loan(w, p)
	if owner != null and owner.manager_is_human:
		Inbox.tell(w, &"from.club_secretary", "msg.loan_returned.subject", "msg.loan_returned.body", {"player": Say.player(p)})
	if borrower != null and Economy.lineup_has(borrower, p.id):
		borrower.lineup = WorldGenerator.best_lineup(w, borrower.id)


static func renew_contract(w: World, p: Player, wage: int, years: int) -> Dictionary:
	var me := w.my_club()
	if p.is_on_loan():
		return {"ok": false, "key": "ui.market.on_loan_no_action"}
	var current: int = int(p.contract.get("wage_weekly", 10))
	var wants: int = int(maxf(current * (1.0 + 0.1 * p.hid("ambition") / 10.0), p.market_value(w.today) / 40.0))
	if wage < wants and not w.rng().chance(0.2):
		return {"ok": false, "key": "ui.market.wants_more", "wants": wants}
	p.contract = {"wage_weekly": wage, "end_day": Contracts.end_day_for(w, years), "role": p.contract.get("role", "rotation")}
	p.morale = clampf(p.morale + 8.0, 0.0, 100.0)
	return {"ok": true, "key": "ui.market.renewed"}


## Transfer in instalments: 1/n is paid on signing and the rest in monthly payments (World.pending_payments).
## Returns the deferred amount.
static func schedule_installments(w: World, payer_id: String, receiver_id: String, fee: int, n: int, player_name: String) -> int:
	if n <= 1 or fee <= 0:
		return 0
	var per := fee / n
	var deferred := fee - per
	w.pending_payments.append({"from_id": payer_id, "to_id": receiver_id, "amount": per, "left": n - 1, "last": deferred - per * (n - 2), "player": player_name})
	return deferred


## This month's instalments (called by the engine on the 1st of each month).
static func process_installments(w: World) -> void:
	var keep: Array = []
	for pay in w.pending_payments:
		var left := int(pay["left"])
		var amount := int(pay["last"]) if left == 1 else int(pay["amount"])
		var payer: Club = w.club(str(pay["from_id"]))
		var receiver: Club = w.club(str(pay["to_id"]))
		if payer != null:
			Economy.book(w, payer, "transfers_out", -amount)
		if receiver != null:
			Economy.book(w, receiver, "transfers_in", amount)
		if payer != null and payer.manager_is_human:
			Inbox.tell(w, &"from.club_secretary", "msg.installment.subject", "msg.installment.body", {"player": Say.plain(str(pay["player"])), "amount": Say.money(amount), "left": Say.num(left - 1)}, Inbox.QUIET)
		pay["left"] = left - 1
		if int(pay["left"]) > 0:
			keep.append(pay)
	w.pending_payments = keep


## Loan purchase options (1 June): the human gets an owl to exercise theirs; AI clubs exercise the one
## the human offered them if the player is useful (better than their worst starter) and they can afford it.
static func loan_options_tick(w: World) -> void:
	for p in w.players_sorted():
		if not p.is_on_loan() or p.loan.buy_option <= 0:
			continue
		var fee: int = p.loan.buy_option
		var borrower: Club = w.club(p.club_id)
		var owner: Club = w.club(p.loan_owner_id())
		if borrower == null or owner == null:
			continue
		if borrower.manager_is_human:
			Inbox.ask(w, Inbox.Decision.new(Inbox.LOAN_OPTION, p.id, [Inbox.Choice.new(EXERCISE_OPTION, "ui.action.exercise_option"), Inbox.Choice.new(DECLINE_OPTION, "ui.action.decline_option", {}, Inbox.BACK)]),
				&"from.club_secretary", "msg.loan_option.subject", "msg.loan_option.body", {"player": Say.player(p), "club": Say.club(owner), "fee": Say.money(fee)})
		elif not borrower.manager_is_human and borrower.balance >= fee:
			var weakest := 999.0
			var l := borrower.lineup
			for pid in [l.get("K", "")] + l.get("C", []) + l.get("B", []) + [l.get("S", "")]:
				var q: Player = w.player(str(pid))
				if q != null and q.id != p.id and q.position == p.position:
					weakest = minf(weakest, q.ca())
			if p.ca() >= weakest:
				exercise_option(w, p)
				if owner.manager_is_human:
					Inbox.tell(w, &"from.club_secretary", "msg.option_exercised.subject", "msg.option_exercised.body", {"player": Say.player(p), "club": Say.club(borrower), "fee": Say.money(fee)})


## Why the purchase option can't be exercised now ("" if it can): the loan is over, or the borrower lacks the cash
## or (a human manager) the transfer budget.
static func exercise_option_block(w: World, p: Player) -> String:
	if not p.is_on_loan():
		return "ui.market.loan_ended"
	var fee := p.loan.buy_option
	var borrower: Club = w.club(p.club_id)
	var owner: Club = w.club(p.loan_owner_id())
	if borrower == null or owner == null:
		return "ui.market.loan_ended"
	if borrower.balance < fee:
		return "ui.market.no_funds"
	if borrower.manager_is_human and fee > borrower.transfer_budget:
		return "ui.market.over_budget"
	return ""


## Exercises the option: the loanee joins the club holding them, paying the agreed price to the owner.
## The transfer budgets move as in Economy.execute_transfer.
static func exercise_option(w: World, p: Player) -> bool:
	if exercise_option_block(w, p) != "":
		return false
	var fee := p.loan.buy_option
	var borrower: Club = w.club(p.club_id)
	var owner: Club = w.club(p.loan_owner_id())
	p.loan = null
	p.transfer_listed = false
	p.loan_listed = false
	if p.pre_contract != null and p.pre_contract.club_id != borrower.id:
		p.pre_contract = null
	Economy.book(w, owner, "transfers_in", fee)
	Economy.book(w, borrower, "transfers_out", -fee)
	if borrower.manager_is_human:
		borrower.transfer_budget = maxi(0, borrower.transfer_budget - fee)
	if owner.manager_is_human:
		owner.transfer_budget += fee / 2
	p.contract["end_day"] = maxi(int(p.contract.get("end_day", 0)), WDate.from_ymd(w.season + 2, 6, 30))
	w.log_transfer(p.id, owner.id, borrower.id, fee)
	return true


## What the player still has to be paid on their contract (weeks to the end × wage).
static func remaining_wages(w: World, p: Player) -> int:
	var weeks := maxi(0, (int(p.contract.get("end_day", 0)) - w.today) / 7)
	return weeks * int(p.contract.get("wage_weekly", 0))


## Mutual termination: the player agrees to leave for a share of what they are still owed.
## A happy young starter doesn't want to leave; one who doesn't play, is transfer-listed or has low morale
## settles for less. Returns {ok, key, cost, remaining}.
static func mutual_terms(w: World, p: Player) -> Dictionary:  # [game]
	var me := w.my_club()
	var remaining := remaining_wages(w, p)
	if me == null or p.club_id != me.id or p.is_on_loan():
		return {"ok": false, "key": "ui.market.not_loanable", "cost": 0, "remaining": remaining}
	var starter := Economy.lineup_has(me, p.id)
	if starter and p.morale >= 55.0 and p.age(w.today) < 32:
		return {"ok": false, "key": "ui.mutual.refused", "cost": 0, "remaining": remaining}
	var factor := 0.5
	if p.transfer_listed or not starter:
		factor -= 0.2
	if p.morale < 40.0:
		factor -= 0.1
	if p.age(w.today) >= 32:
		factor -= 0.1
	var cost := int(remaining * maxf(factor, 0.15))
	return {"ok": true, "key": "ui.mutual.offer", "cost": cost, "remaining": remaining}


## Leaves the club for `cost` (the full payoff on termination; the agreed amount on mutual consent).
static func terminate_contract(w: World, p: Player, cost: int) -> bool:
	var me := w.my_club()
	if me == null or p.club_id != me.id or me.balance < cost:
		return false
	Economy.book(w, me, "severance", -cost)
	release_player(w, p)
	return true


static func release_player(w: World, p: Player) -> void:
	if p.is_on_loan():
		end_loan_early(w, p)
		return
	var from_id := p.club_id
	var was_captain := p.is_captain
	close_bids(w, p.id)
	w.move_player(p, "", "free")
	w.log_release(p.id, from_id)
	p.is_captain = false
	p.free_since = w.season
	if was_captain and w.clubs.has(from_id) and WorldGenerator.ensure_captain(w, w.clubs[from_id]):
		Economy.notify_new_captain(w, from_id)


## Processes pending offers (called by the engine every day).
static func process_pending(w: World, engine) -> void:
	var rng: SimRng = w.rng()
	for offer in w.pending_offers.duplicate():
		if str(offer["status"]) != "pending" or int(offer["resolve_day"]) > w.today:
			continue
		var p: Player = w.player(str(offer["player_id"]))
		if p == null:
			_set_status(w, offer, "void")
			continue
		if str(offer["direction"]) == "out":
			var seller: Club = w.club(str(offer["to_id"]))
			var me := w.my_club()
			if seller == null or me == null or str(offer["from_id"]) != me.id:
				_set_status(w, offer, "void")
				continue
			if not deal_still_valid(p, me, seller.id) or swap_problem(w, str(offer.get("swap_player_id", "")), me, seller) != "":
				_set_status(w, offer, "void")
				Inbox.tell(w, &"from.club_secretary", "msg.deal_off.subject", "msg.deal_off.body", {"player": Say.player(p)})
				continue
			var fee := int(offer["fee"])
			var swap: Player = w.player(str(offer.get("swap_player_id", "")))
			var effective := fee + (Economy.swap_value(w, seller, swap) if swap != null else 0)
			if int(offer.get("installments", 1)) > 1:
				effective = int(effective * 0.95)
			var ask := Economy.asking_price(w, p)
			if effective >= ask or Economy.ai_accepts_sale(w, seller, p, effective, rng):
				_set_status(w, offer, "accepted")
				_contract_stage(w, p, seller, offer, rng)
			elif int(offer.get("rounds", 0)) < 2 and effective >= ask * 0.65:
				var counter: int = int(maxf(ask, effective * 1.12)) - (Economy.swap_value(w, seller, swap) if swap != null else 0)
				_set_status(w, offer, "countered")
				offer["counter"] = counter
				Inbox.ask(w, Inbox.Decision.new(Inbox.COUNTER, str(offer["id"]), [Inbox.Choice.new(ACCEPT_COUNTER, "ui.action.accept_counter"),
						Inbox.Choice.new(COUNTER_AGAIN, "ui.action.counter_again"), Inbox.Choice.new(WITHDRAW_OFFER, "ui.action.withdraw", {}, Inbox.BACK)]),
					&"from.club_secretary", "msg.offer_countered.subject", "msg.offer_countered.body",
					{"player": Say.player(p), "club": Say.club(seller), "fee": Say.money(fee), "counter": Say.money(counter)})
			else:
				_set_status(w, offer, "rejected")
				Inbox.tell(w, &"from.club_secretary", "msg.offer_rejected.subject", "msg.offer_rejected.body", {"player": Say.player(p), "club": Say.club(seller), "fee": Say.money(fee), "ask": Say.money(ask)})
	_prune_offers(w)
	if WDate.day_of_month(w.today) == 15 and w.my_club() != null and not w.is_school_mode():
		var me := w.my_club()
		for p in w.squad_of(me.id):
			if p.is_on_loan() or p.squad == Player.Squad.SCHOOL:
				continue
			var clause := int(p.contract.get("release_clause", 0))
			if clause > 0 and rng.chance(0.25):
				var payers: Array = []
				for c in w.clubs_sorted():
					if c.id != me.id and not c.manager_is_human and c.balance >= clause and c.reputation >= me.reputation * 0.7 and (not c.is_women_only() or p.gender == SimPlayer.Gender.F):
						payers.append(c)
				if not payers.is_empty() and clause <= p.market_value(w.today) * 2.5 and p.pre_contract == null:
					var payer: Club = rng.pick(payers)
					var was_starter := Economy.lineup_has(me, p.id)
					close_bids(w, p.id)
					Economy.execute_transfer(w, p, payer.id, clause, int(int(p.contract.get("wage_weekly", 10)) * 1.2), 3)
					if was_starter:
						me.lineup = WorldGenerator.best_lineup(w, me.id)
					Inbox.tell(w, &"from.club_secretary", "msg.release_clause.subject", "msg.release_clause.body", {"player": Say.player(p), "club": Say.club(payer), "fee": Say.money(clause)})
					continue
			if (p.transfer_listed and rng.chance(0.5)) or (p.ca() >= 130.0 and rng.chance(0.08)):
				if p.pre_contract != null:
					continue
				var buyers: Array = []
				for c in w.clubs_sorted():
					if c.id != me.id and not c.manager_is_human and c.balance > p.market_value(w.today) and (not c.is_women_only() or p.gender == SimPlayer.Gender.F):
						buyers.append(c)
				if buyers.is_empty():
					continue
				var buyer: Club = rng.pick(buyers)
				var fee: int = int(p.market_value(w.today) * (0.9 + 0.4 * rng.next()))
				_ask_bid(w, p, buyer, fee, true)


## An AI club's bid for the manager's `p`: an incoming entry in pending_offers (direction "in", status "offered")
## and the question about it. `first`: the opening bid, answered within OFFER_DAYS, with a sell-on variant and a
## counter; otherwise the buyer's reply to our counter, to take or leave with no deadline.
static func _ask_bid(w: World, p: Player, buyer: Club, fee: int, first: bool) -> void:
	var offer := {"id": w.next_offer_id, "day": w.today, "player_id": p.id, "from_id": buyer.id, "to_id": w.player_club_id, "fee": fee,
		"status": "offered", "direction": "in", "first": first}
	w.next_offer_id += 1
	w.pending_offers.append(offer)
	var choices: Array[Inbox.Choice] = [Inbox.Choice.new(SELL, "ui.action.accept_sale")]
	if first:
		choices.append(Inbox.Choice.new(SELL_WITH_SELL_ON, "ui.action.accept_sale_sell_on", {"fee": Say.money(int(fee * SELL_ON_FEE))}))
		choices.append(Inbox.Choice.new(COUNTER_BID, "ui.action.counter_incoming"))
	choices.append(Inbox.Choice.new(REFUSE_BID, "ui.action.reject", {}, Inbox.BACK))
	var q := Inbox.Decision.new(Inbox.BID, str(offer["id"]), choices)
	Inbox.ask(w, q.until(w.today + GameEngine.OFFER_DAYS) if first else q, &"from.club_secretary", "msg.incoming_offer.subject",
		"msg.incoming_offer.body" if first else "msg.incoming_counter_ok.body", {"player": Say.player(p), "club": Say.club(buyer), "fee": Say.money(fee)})


## The agent's terms for an accepted bid go on the offer itself (offer.terms), and the manager is asked about them.
static func _contract_stage(w: World, p: Player, seller: Club, offer: Dictionary, rng: SimRng) -> void:
	var me := w.my_club()
	var fee := int(offer["fee"])
	var demand := Economy.agent_demand(w, p, me, fee)
	var ok := Economy.player_accepts(w, p, me, int(demand["wage"]), rng)
	if ok:
		offer["terms"] = {"wage": int(demand["wage"]), "bonus": int(demand["bonus"]), "years": 3}
		Inbox.ask(w, Inbox.Decision.new(Inbox.TERMS, str(offer["id"]), [Inbox.Choice.new(SIGN, "ui.action.sign"), Inbox.Choice.new(NEGOTIATE, "ui.action.negotiate"),
				Inbox.Choice.new(COUNTER_TERMS, "ui.action.contract_counter"), Inbox.Choice.new(WITHDRAW_TERMS, "ui.action.withdraw", {}, Inbox.BACK)]),
			&"from.agent", "msg.agent_terms.subject", "msg.agent_terms.body",
			{"player": Say.player(p), "club": Say.club(seller), "fee": Say.money(fee), "wage": Say.money(int(demand["wage"])), "bonus": Say.money(int(demand["bonus"]))})
	else:
		Inbox.tell(w, &"from.club_secretary", "msg.player_refuses.subject", "msg.player_refuses.body", {"player": Say.player(p), "club": Say.club(seller)})


static func find_offer(w: World, id: int) -> Dictionary:
	for o in w.pending_offers:
		if int(o["id"]) == id:
			return o
	return {}


## Seller of the human club's latest accepted bid for `p` ("" if there is none on record).
static func accepted_seller_id(w: World, p: Player, buyer: Club) -> String:
	var seller := ""
	if buyer == null:
		return seller
	for o in w.pending_offers:
		if str(o["status"]) == "accepted" and str(o["player_id"]) == p.id and str(o["from_id"]) == buyer.id:
			seller = str(o["to_id"])
	return seller


## A bid the seller accepted can still be closed: the player is still at the selling club (when known), is not out
## on loan and is not already at the buying club.
static func deal_still_valid(p: Player, buyer: Club, seller_id: String) -> bool:
	if buyer == null or p.club_id == "" or p.club_id == buyer.id or p.is_on_loan():
		return false
	return seller_id == "" or p.club_id == seller_id


## Why a swap player can't be handed to `seller` ("" if they can): they are no longer at the buying club (sold,
## released) or only on loan there, or the seller can't field them (Holyhead Harpies: witches only). No swap: "".
static func swap_problem(w: World, swap_player_id: String, buyer: Club, seller: Club) -> String:
	if swap_player_id == "":
		return ""
	var swap: Player = w.player(swap_player_id)
	if swap == null or buyer == null or swap.club_id != buyer.id or swap.is_on_loan():
		return "ui.market.deal_off"
	if seller != null and seller.is_women_only() and swap.gender != SimPlayer.Gender.F:
		return "ui.market.harpies_only_witches"
	return ""


## Why an accepted bid is dead ("" if it can still be closed), checked before any money or player moves: the target
## is still at the seller and not out on loan (deal_still_valid), the swap player (if any) is still ours and welcome
## at the seller (swap_problem). A non-empty answer voids the bid. The buyer's own passing states are the callers'
## business and don't void it: a transfer embargo (embargoed), funds and budget.
static func deal_problem(w: World, p: Player, buyer: Club, seller_id: String, swap_player_id: String) -> String:
	if not deal_still_valid(p, buyer, seller_id) or not w.clubs.has(p.club_id):
		return "ui.market.deal_off"
	return swap_problem(w, swap_player_id, buyer, w.club(p.club_id))


## Closes the human club's accepted bid for `p` ("signed", "void" or "withdrawn").
static func close_accepted_offer(w: World, p: Player, buyer: Club, status: String) -> void:
	if buyer == null:
		return
	for o in w.pending_offers:
		if str(o["status"]) == "accepted" and str(o["player_id"]) == p.id and str(o["from_id"]) == buyer.id:
			_set_status(w, o, status)


## The one writer of an offer's status. Leaving "countered", "accepted" or "offered" closes the question about it
## without a closing line (the clicked answer writes its own), so a contract signed in the dialog or a deal that
## died anywhere closes its owl by itself.
static func _set_status(w: World, offer: Dictionary, status: String) -> void:
	var was := str(offer.get("status", ""))
	offer["status"] = status
	var kind: StringName = {"countered": Inbox.COUNTER, "accepted": Inbox.TERMS, "offered": Inbox.BID}.get(was, &"")
	if kind != &"" and was != status:
		Inbox.close(w, Inbox.find(w, kind, str(offer["id"])))


## Once a player has left, no bid for them can be answered.
static func close_bids(w: World, player_id: String) -> void:
	for o in w.pending_offers:
		if str(o["status"]) == "offered" and str(o["player_id"]) == player_id:
			_set_status(w, o, "void")


## The manager no longer runs `club_id`: every deal still waiting on them is void, which closes its question.
static func void_open_offers(w: World, club_id: String) -> void:
	for o in w.pending_offers:
		if ["countered", "accepted", "offered"].has(str(o["status"])) and (str(o["from_id"]) == club_id or str(o["to_id"]) == club_id):
			_set_status(w, o, "void")


static func _incoming_still_valid(w: World, p: Player, buyer: Club, fee: int) -> bool:
	var me := w.my_club()
	if me == null or buyer == null or buyer.manager_is_human or buyer.id == me.id:
		return false
	if p.club_id != me.id or p.is_on_loan() or p.squad == Player.Squad.SCHOOL:
		return false
	if buyer.is_women_only() and p.gender != SimPlayer.Gender.F:
		return false
	return buyer.balance >= fee


## Closed offers stay on the list this long after they resolved; an accepted or countered one longer, since the
## player may still sign on it.
const ACCEPTED_OFFER_RETENTION_DAYS := 120
const CLOSED_OFFER_RETENTION_DAYS := 60


static func _prune_offers(w: World) -> void:
	var today := w.today
	w.pending_offers = w.pending_offers.filter(func(o):
		var status := str(o.get("status", ""))
		if status == "pending":
			return true
		var age := today - int(o.get("resolve_day", o.get("day", today)))
		return age <= (ACCEPTED_OFFER_RETENTION_DAYS if status == "accepted" or status == "countered" else CLOSED_OFFER_RETENTION_DAYS))


const SELL := &"sell"
const SELL_WITH_SELL_ON := &"sell_with_sell_on"
const COUNTER_BID := &"counter_bid"
const REFUSE_BID := &"refuse_bid"
const ACCEPT_COUNTER := &"accept_counter"
const COUNTER_AGAIN := &"counter_again"
const WITHDRAW_OFFER := &"withdraw_offer"
const SIGN := &"sign"
const NEGOTIATE := &"negotiate"
const COUNTER_TERMS := &"counter_terms"
const WITHDRAW_TERMS := &"withdraw_terms"
const EXERCISE_OPTION := &"exercise_option"
const DECLINE_OPTION := &"decline_option"
## The sell-on variant of an incoming bid: 90 % of the fee now and 20 % of the player's next sale.
const SELL_ON_FEE := 0.9
const SELL_ON_PCT := 20
## Our counter to an incoming bid asks this much more; the agent's terms countered by these factors.
const COUNTER_BID_RAISE := 1.25
const COUNTER_WAGE := 0.85
const COUNTER_BONUS := 0.5


## The manager's answer to a market question (bids, counter-offers, agent terms, loan options). Inbox.choose routes
## here; each kind reads its record (the offer by the question's key, or the loaned player).
static func answer_owl(w: World, engine: GameEngine, d: Inbox.Decision, c: Inbox.Choice) -> Inbox.Reply:
	match d.kind:
		Inbox.BID:
			var bid := find_offer(w, int(d.key))
			match c.verb:
				SELL:
					return _sell(w, engine, bid, int(bid.get("fee", 0)), 0)
				SELL_WITH_SELL_ON:
					return _sell(w, engine, bid, int(int(bid.get("fee", 0)) * SELL_ON_FEE), SELL_ON_PCT)
				COUNTER_BID:
					return _counter_bid(w, bid)
				REFUSE_BID:
					if not bid.is_empty():
						_set_status(w, bid, "rejected")
					return Inbox.Reply.done()
		Inbox.COUNTER:
			return _answer_counter(w, find_offer(w, int(d.key)), c.verb)
		Inbox.TERMS:
			return _answer_terms(w, find_offer(w, int(d.key)), c.verb)
		Inbox.LOAN_OPTION:
			var op: Player = w.player(d.key)
			match c.verb:
				EXERCISE_OPTION:
					if op == null:
						return Inbox.Reply.done()
					var why := exercise_option_block(w, op)
					if why == "" and exercise_option(w, op):
						return Inbox.Reply.done().with_toast(Say.phrase("ui.market.option_done"))
					return Inbox.Reply.done().with_toast(Say.phrase(why if why != "" else "ui.market.no_funds"))
				DECLINE_OPTION:
					return Inbox.Reply.done()
	return Inbox.Reply.unhandled(d, c)


## Human replies to a counter-offer from the selling club.
static func _answer_counter(w: World, offer: Dictionary, verb: StringName) -> Inbox.Reply:
	if offer.is_empty():
		return Inbox.Reply.done()
	var p: Player = w.player(str(offer["player_id"]))
	var seller: Club = w.club(str(offer["to_id"]))
	var me := w.my_club()
	if p == null or seller == null or me == null:
		_set_status(w, offer, "void")
		return Inbox.Reply.done()
	if verb != WITHDRAW_OFFER and (not deal_still_valid(p, me, seller.id) or embargoed(me)):
		_set_status(w, offer, "void")
		Inbox.tell(w, &"from.club_secretary", "msg.deal_off.subject", "msg.deal_off.body", {"player": Say.player(p)})
		return Inbox.Reply.done()
	match verb:
		ACCEPT_COUNTER:
			var counter := int(offer.get("counter", offer["fee"]))
			if counter / maxi(int(offer.get("installments", 1)), 1) > me.balance:
				_set_status(w, offer, "void")
				Inbox.tell(w, &"from.club_secretary", "msg.no_funds.subject", "msg.no_funds.body", {"player": Say.player(p)})
				return Inbox.Reply.done()
			if counter > me.transfer_budget:
				_set_status(w, offer, "void")
				Inbox.tell(w, &"from.club_secretary", "msg.over_budget.subject", "msg.over_budget.body", {"player": Say.player(p), "fee": Say.money(counter), "budget": Say.money(me.transfer_budget)})
				return Inbox.Reply.done()
			offer["fee"] = counter
			_set_status(w, offer, "accepted")
			_contract_stage(w, p, seller, offer, w.rng())
		COUNTER_AGAIN:
			var fee := int(offer["fee"])
			var mid := int((fee + int(offer.get("counter", fee))) / 2.0)
			var halfway := mini(mid, me.transfer_budget)
			if halfway < mid and halfway <= fee:
				_set_status(w, offer, "void")
				Inbox.tell(w, &"from.club_secretary", "msg.over_budget.subject", "msg.over_budget.body", {"player": Say.player(p), "fee": Say.money(int(offer.get("counter", fee))), "budget": Say.money(me.transfer_budget)})
				return Inbox.Reply.done()
			offer["fee"] = halfway
			offer["rounds"] = int(offer.get("rounds", 0)) + 1
			_set_status(w, offer, "pending")
			offer["resolve_day"] = w.today + 1 + (w.rng_state % 3)
		_:
			_set_status(w, offer, "withdrawn")
	return Inbox.Reply.done()


## Our counter to an AI club's bid: they come back with a higher bid or walk away. [draw] one chance, as before.
static func _counter_bid(w: World, bid: Dictionary) -> Inbox.Reply:
	var p: Player = w.player(str(bid.get("player_id", "")))
	var buyer: Club = w.club(str(bid.get("from_id", "")))
	if p == null or buyer == null:
		return Inbox.Reply.done()
	_set_status(w, bid, "countered_by_us")
	var want := int(int(bid["fee"]) * COUNTER_BID_RAISE)
	if not _incoming_still_valid(w, p, buyer, 0):
		Inbox.tell(w, &"from.club_secretary", "msg.deal_off.subject", "msg.deal_off.body", {"player": Say.player(p)})
		return Inbox.Reply.done()
	if want <= buyer.balance and want <= buyer.transfer_budget * 1.5 and w.rng().chance(0.55):
		_ask_bid(w, p, buyer, want, false)
	else:
		Inbox.tell(w, &"from.club_secretary", "msg.incoming_counter_no.subject", "msg.incoming_counter_no.body", {"player": Say.player(p), "club": Say.club(buyer), "fee": Say.money(want)})
	return Inbox.Reply.done()


## Sells the player to the bidder: every other bid for them closes, then the transfer goes through.
static func _sell(w: World, engine: GameEngine, bid: Dictionary, fee: int, sell_on: int) -> Inbox.Reply:
	var p: Player = w.player(str(bid.get("player_id", "")))
	var buyer: Club = w.club(str(bid.get("from_id", "")))
	if p == null or buyer == null:
		return Inbox.Reply.done()
	if not _incoming_still_valid(w, p, buyer, fee):
		Inbox.tell(w, &"from.club_secretary", "msg.deal_off.subject", "msg.deal_off.body", {"player": Say.player(p)})
		return Inbox.Reply.done()
	var wage := int(maxf(int(p.contract.get("wage_weekly", 10)) * 1.1, 5))
	var me := w.my_club()
	_set_status(w, bid, "sold")
	close_bids(w, p.id)
	Economy.execute_transfer(w, p, buyer.id, fee, wage, 2)
	if sell_on > 0 and me != null:
		p.sell_on = {"club_id": me.id, "pct": sell_on}
	if not engine._lineup_valid(me):
		me.lineup = WorldGenerator.best_lineup(w, me.id)
	return Inbox.Reply.done()


## The manager's answer to the agent's terms, read from the accepted offer. A passing refusal (embargo, funds,
## budget) keeps the owl open to try again; NEGOTIATE opens the contract dialog on the same deal.
static func _answer_terms(w: World, offer: Dictionary, verb: StringName) -> Inbox.Reply:
	var p: Player = w.player(str(offer.get("player_id", "")))
	var me := w.my_club()
	if offer.is_empty() or p == null or me == null:
		return Inbox.Reply.done()
	if verb == NEGOTIATE:
		return Inbox.Reply.open_dialog(&"contract", {"player_id": p.id, "fee": int(offer.get("fee", 0)), "swap_player_id": str(offer.get("swap_player_id", "")), "installments": int(offer.get("installments", 1))})
	if verb == WITHDRAW_TERMS:
		close_accepted_offer(w, p, me, "withdrawn")
		return Inbox.Reply.done()
	var terms: Dictionary = offer.get("terms", {})
	var countered := verb == COUNTER_TERMS
	var wage := int(int(terms.get("wage", 10)) * (COUNTER_WAGE if countered else 1.0))
	var bonus := int(int(terms.get("bonus", 0)) * (COUNTER_BONUS if countered else 1.0))
	var years := int(terms.get("years", 3))
	var fee := int(offer.get("fee", 0))
	var swap_id := str(offer.get("swap_player_id", ""))
	if deal_problem(w, p, me, str(offer["to_id"]), swap_id) != "":
		close_accepted_offer(w, p, me, "void")
		Inbox.tell(w, &"from.club_secretary", "msg.deal_off.subject", "msg.deal_off.body", {"player": Say.player(p)})
		return Inbox.Reply.done()
	if embargoed(me):
		Inbox.tell(w, &"from.club_secretary", "msg.embargo_blocks.subject", "msg.embargo_blocks.body", {"player": Say.player(p)})
		return Inbox.Reply.stay()
	var n := maxi(int(offer.get("installments", 1)), 1)
	if fee / n + bonus > me.balance:
		Inbox.tell(w, &"from.club_secretary", "msg.no_funds.subject", "msg.no_funds.body", {"player": Say.player(p)})
		return Inbox.Reply.stay()
	if fee > me.transfer_budget:
		Inbox.tell(w, &"from.club_secretary", "msg.over_budget.subject", "msg.over_budget.body", {"player": Say.player(p), "fee": Say.money(fee), "budget": Say.money(me.transfer_budget)})
		return Inbox.Reply.stay()
	if countered:
		var amb: float = (p.hid("ambition") - 10.0) / 10.0
		if not w.rng().chance(clampf(0.55 - 0.3 * amb, 0.15, 0.85)):
			close_accepted_offer(w, p, me, "void")
			Inbox.tell(w, &"from.agent", "msg.agent_walks.subject", "msg.agent_walks.body", {"player": Say.player(p)})
			return Inbox.Reply.done()
	var swap: Player = w.player(swap_id)
	var seller_id := p.club_id
	var fee_now := fee - schedule_installments(w, me.id, seller_id, fee, n, p.name())
	Economy.execute_transfer(w, p, me.id, fee, wage, years, fee_now)
	close_accepted_offer(w, p, me, "signed")
	Economy.book(w, me, "signing_fees", -bonus)
	if swap != null:
		var was_starter := Economy.lineup_has(me, swap.id)
		Economy.execute_transfer(w, swap, seller_id, 0, int(swap.contract.get("wage_weekly", 10)), 2)
		if was_starter:
			me.lineup = WorldGenerator.best_lineup(w, me.id)
	Inbox.tell(w, &"from.club_secretary", "msg.signed.subject", "msg.signed.body", {"player": Say.player(p), "wage": Say.money(wage), "years": Say.num(years)})
	return Inbox.Reply.done()
