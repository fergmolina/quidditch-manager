class_name ContractDialog
extends AcceptDialog
## Contract negotiation: what the player asks for at the top and the package the club offers
## (wage, years, role, signing bonus, goal/catch/title bonuses, yearly raise, release clause).
## "Propose" evaluates the offer with `Contracts.propose`; if there is a counter-offer, its terms are loaded to
## accept them or keep adjusting. Three rounds without agreement and the player walks away from the table.

signal signed(result: Dictionary)

var w: World
var p: Player
var club: Club
var context := "renew"
var fee := 0
var swap_id := ""
var installments := 1
var terms: Dictionary = {}
var rounds := 0
var _spins: Dictionary = {}
var _role: OptionButton
var _status: Label
var _propose: Button
var _budget: Label = null
var _done := false


static func open(host: Node, world: World, player: Player, to_club: Club, ctx: String, transfer_fee: int = 0, swap_player_id: String = "", n_installments: int = 1) -> ContractDialog:
	var d := ContractDialog.new()
	d.w = world
	d.p = player
	d.club = to_club
	d.context = ctx
	d.fee = transfer_fee
	d.swap_id = swap_player_id
	d.installments = n_installments
	host.add_child(d)
	d._build()
	d.reset_size()
	d.popup_centered()
	return d


func _t(key: String) -> String:
	return TranslationServer.translate(key)


func _build() -> void:
	title = _t("ui.contract.title") % p.name()
	ok_button_text = _t("ui.close")
	terms = Contracts.default_terms(w, p, club, context, fee)
	var d := Contracts.demand(w, p, club, context, fee)
	var v := UI.vbox(8)
	v.custom_minimum_size = Vector2(560, 0)
	var ask := UI.label(_t("ui.contract.demand") % [Game.galleons(int(d["wage"])), int(d["years"]), _t("role." + str(d["role"])), Game.galleons(int(d["signing_fee"]))], "ui", 14, ThemeBuilder.INK)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.custom_minimum_size.x = 540
	v.add_child(ask)
	if context == "transfer":
		v.add_child(UI.label(_t("ui.contract.fee_line") % Game.galleons(fee), "ui", 13, ThemeBuilder.INK_SOFT))
	v.add_child(UI.rule())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	_add_spin(grid, "wage_weekly", "ui.contract.wage", 1, 5000, 1)
	_add_spin(grid, "years", "ui.contract.years", 1, 5, 1)
	grid.add_child(UI.label(_t("ui.contract.role"), "ui", 13))
	var roles: Array = []
	for r in Contracts.ROLES:
		roles.append([r, _t("role." + r)])
	_role = UI.option(roles, str(terms["role"]), func(val): terms["role"] = str(val))
	grid.add_child(_role)
	_add_spin(grid, "signing_fee", "ui.contract.signing_fee", 0, 200000, _arrow_step(int(terms.get("signing_fee", 0))))
	_add_spin(grid, "bonus_goal", "ui.contract.bonus_goal", 0, 500, 1)
	_add_spin(grid, "bonus_catch", "ui.contract.bonus_catch", 0, 2000, 5)
	_add_spin(grid, "bonus_title", "ui.contract.bonus_title", 0, 20000, 10)
	_add_spin(grid, "yearly_rise_pct", "ui.contract.yearly_rise", 0, 20, 1)
	_add_spin(grid, "release_clause", "ui.contract.release_clause", 0, 1000000, _arrow_step(p.market_value(w.today)))
	v.add_child(grid)
	if club.manager_is_human and not w.is_school_mode():
		_budget = UI.label("", "ui", 13, ThemeBuilder.INK_SOFT)
		_budget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_budget.custom_minimum_size.x = 540
		v.add_child(_budget)
		_refresh_budget()
	var hint := UI.label(_t("ui.contract.clause_hint"), "ui_italic", 12, ThemeBuilder.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 540
	v.add_child(hint)
	v.add_child(UI.rule())
	_status = UI.label("", "ui", 14, ThemeBuilder.INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(540, 40)
	v.add_child(_status)
	_propose = UI.primary(_t("ui.contract.propose"), _on_propose)
	_propose.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(_propose)
	add_child(v)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	if context == "renew" and p.pre_contract != null:
		_status.text = _t("ui.contract.has_pre_contract")
		_propose.disabled = true
	elif context == "free" and MarketActions.embargoed(club):
		_status.text = _t("ui.market.embargo_free")
		_status.add_theme_color_override("font_color", ThemeBuilder.SEALING_WAX)
		_propose.disabled = true
	elif w.today < p.talks_blocked_until:
		_status.text = _t("ui.contract.blocked")
		_propose.disabled = true


func _add_spin(grid: GridContainer, key: String, label_key: String, lo: int, hi: int, arrow_step: int) -> void:
	grid.add_child(UI.label(_t(label_key), "ui", 13))
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = 1
	sb.rounded = true
	sb.custom_arrow_step = arrow_step
	sb.value = int(terms.get(key, 0))
	terms[key] = int(sb.value)
	sb.custom_minimum_size = Vector2(120, 0)
	sb.value_changed.connect(func(val):
		terms[key] = int(val)
		if key == "wage_weekly":
			_refresh_budget())
	_spins[key] = sb
	grid.add_child(sb)


static func _arrow_step(amount: int) -> int:
	if amount < 100:
		return 1
	return 10 if amount < 1000 else 100


func _refresh_budget() -> void:
	if _budget == null:
		return
	var bill := 0
	for q in w.squad_of(club.id):
		bill += int(q.contract.get("wage_weekly", 0))
	var with_offer := bill + int(terms.get("wage_weekly", 0))
	if context == "renew" and p.club_id == club.id:
		with_offer -= int(p.contract.get("wage_weekly", 0))
	var left := club.transfer_budget - (fee if context == "transfer" else 0)
	_budget.text = _t("ui.contract.budgets") % [Game.galleons(left), Game.galleons(with_offer), Game.galleons(club.wage_budget_weekly)]
	_budget.add_theme_color_override("font_color", ThemeBuilder.SEALING_WAX if with_offer > club.wage_budget_weekly or left < 0 else ThemeBuilder.INK_SOFT)


func _load_terms(t: Dictionary) -> void:
	for k in _spins.keys():
		_spins[k].set_value_no_signal(int(t.get(k, 0)))
	for i in _role.item_count:
		if str(_role.get_item_metadata(i)) == str(t.get("role", "")):
			_role.select(i)
	terms = t.duplicate()
	_refresh_budget()


func _on_propose() -> void:
	if _done:
		return
	var r := Contracts.propose(w, p, club, terms, context, rounds, fee)
	rounds += 1
	Game.mark_dirty()
	if bool(r["accept"]):
		var s := Contracts.sign(w, p, club, terms, context, fee, swap_id, installments)
		_status.text = _t(str(s["key"]))
		if bool(s["ok"]) or str(s["key"]) == "ui.market.deal_off":
			_done = true
			_propose.disabled = true
			signed.emit(s)
		return
	if bool(r.get("final", false)):
		_status.text = _t(str(r["reason"])) % p.name() if str(r["reason"]) == "ui.contract.walked" else _t(str(r["reason"]))
		_done = true
		_propose.disabled = true
		return
	var c: Dictionary = r["counter"]
	_load_terms(c)
	_status.text = _t("ui.contract.counter") % [Game.galleons(int(c["wage_weekly"])), _t("role." + str(c["role"])), Contracts.MAX_ROUNDS - rounds]
