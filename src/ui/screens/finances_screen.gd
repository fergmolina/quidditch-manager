extends UIScreen
## Gringotts ledger: balance, wages, sponsorship, brooms, facilities.

var body: VBoxContainer


func build() -> void:
	header(T("ui.menu.finances"), Game.my_club().name)
	body = UI.vbox(12)
	root.add_child(UI.scroll(body))


func refresh() -> void:
	clear(body)
	var w := Game.world
	var club := Game.my_club()
	var wages := 0
	for p in w.squad_of(club.id):
		wages += int(p.contract.get("wage_weekly", 0))
	var kp := UI.panel()
	var kv := UI.vbox(8)
	var kh := UI.hbox(24)
	var bal := UI.kpi(Game.galleons(club.balance), T("ui.finances.balance"))
	(bal.get_child(0) as Label).add_theme_color_override("font_color", ThemeBuilder.GREEN if club.balance >= 0 else ThemeBuilder.SEALING_WAX)
	kh.add_child(bal)
	var wk := UI.kpi("%s / %s" % [Game.galleons(wages), T("ui.week")], "%s (%s %s)" % [T("ui.finances.wages"), T("ui.finances.budget"), Game.galleons(club.wage_budget_weekly)])
	if wages > club.wage_budget_weekly:
		(wk.get_child(0) as Label).add_theme_color_override("font_color", ThemeBuilder.SEALING_WAX)
	kh.add_child(wk)
	kh.add_child(UI.kpi(Game.galleons(club.transfer_budget), T("ui.finances.transfer_budget")))
	kh.add_child(UI.kpi("%s / %s" % [Game.galleons(int(club.sponsor.get("monthly", 0))), T("ui.month")], "%s · %s · %s %s" % [T("ui.finances.sponsor"), Game.sponsor_name(str(club.sponsor.get("name", ""))), T("ui.until"), _season_span(int(club.sponsor.get("ends_season", 0)))]))
	kh.add_child(UI.kpi(T(Fans.mood_key(Fans.mood(club))), "%s (%d/100)" % [T("ui.fans.title"), int(Fans.mood(club))]))
	kh.add_child(UI.kpi(Game.galleons(Grounds.capacity_of(club)).replace(" G", ""), "%s · %s" % [T("ui.ground"), Grounds.name_of(club)]))
	kv.add_child(kh)
	kv.add_child(UI.text("MetaItalic", T("ui.finances.gate_note")))
	kp.add_child(kv)
	body.add_child(kp)
	_ledger(club)
	var fp := UI.panel()
	var fv := UI.vbox(8)
	fv.add_child(UI.subtitle(T("ui.finances.facilities")))
	for k in ["training", "medical", "broom_workshop", "academy"]:
		var lvl: int = club.academy_level() if k == "academy" else int(club.facilities.get(k, 1))
		var cost := 1500 * lvl
		var h := UI.hbox(10)
		var fl := UI.text("BodyMedium", T("facility." + k))
		fl.custom_minimum_size = Vector2(200, 0)
		h.add_child(fl)
		h.add_child(UI.segments(lvl, 5, ThemeBuilder.GREEN))
		h.add_child(UI.spacer())
		if lvl < 5:
			var b := UI.button(T("ui.finances.upgrade") % Game.galleons(cost), func(): _confirm_upgrade(k, cost))
			b.disabled = club.balance < cost
			if b.disabled:
				b.tooltip_text = T("ui.market.no_funds")
			h.add_child(b)
		else:
			h.add_child(UI.text("Meta", T("ui.finances.max_level")))
		fv.add_child(h)
	fp.add_child(fv)
	body.add_child(fp)
	var bp := UI.panel()
	var bv := UI.vbox(8)
	bv.add_child(UI.subtitle(T("ui.finances.brooms")))
	bv.add_child(UI.text("MetaItalic", T("ui.finances.brooms_note")))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	bv.add_child(grid)
	bp.add_child(bv)
	body.add_child(bp)
	for b in Game.loader.brooms.values():
		var year: int = int(b.get("available_from", b.get("year", 1900)))
		if year > w.season:
			continue
		var price: int = int(b.get("price", 500))
		var btn := UI.button("%s — %s" % [b["model"], Game.galleons(price)], func(): _buy_broom(str(b["id"]), price))
		var bi := UI.image_for("brooms", str(b["id"]))
		if bi != null:
			btn.icon = bi
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 40)
			btn.custom_minimum_size = Vector2(0, 44)
		btn.disabled = club.balance < price
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(btn)


func _season_span(y: int) -> String:
	return "%d-%02d" % [y, (y + 1) % 100] if y > 0 else "—"


func _upgrade_staff(role: String) -> void:
	var r := Economy.upgrade_staff(Game.world, Game.my_club(), role, Game.world.rng(), Game.loader)
	main.toast(T(str(r["key"])), "check-circle" if r["ok"] else "x-circle", "ok" if r["ok"] else "error")
	Game.world_changed.emit()


func _confirm_upgrade(k: String, cost: int) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = T("ui.finances.facilities")
	dlg.dialog_text = T("ui.finances.upgrade_confirm") % [T("facility." + k), Game.galleons(cost)]
	dlg.ok_button_text = T("ui.finances.upgrade") % Game.galleons(cost)
	dlg.cancel_button_text = T("ui.cancel")
	UI.cancel_right(dlg)
	dlg.confirmed.connect(func(): _upgrade(k, cost); dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _upgrade(k: String, cost: int) -> void:
	var club := Game.my_club()
	Economy.book(Game.world, club, "facilities", -cost)
	club.facilities[k] = (club.academy_level() if k == "academy" else int(club.facilities.get(k, 1))) + 1
	Game.world_changed.emit()


func _buy_broom(id: String, price: int) -> void:
	var w := Game.world
	var club := Game.my_club()
	var broom: Dictionary = Game.loader.brooms.get(id, {})
	var suggested: Player = null
	var worst_speed := 99.0
	for p in w.squad_of(club.id, [Player.Squad.FIRST]):
		var sp := float(Game.loader.brooms.get(str(p.broom.get("model_id", "")), {}).get("speed", 10))
		if sp < worst_speed:
			worst_speed = sp
			suggested = p
	var dlg := ConfirmationDialog.new()
	dlg.title = str(broom.get("model", id))
	dlg.ok_button_text = T("ui.finances.buy_for") % (suggested.name() if suggested else "—")
	dlg.cancel_button_text = T("ui.cancel")
	UI.cancel_right(dlg)
	var v := UI.vbox(8)
	v.custom_minimum_size = Vector2(620, 0)
	var head := UI.text("Body", T("ui.finances.pick_player") % [str(broom.get("model", id)), Game.galleons(price)])
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(600, 0)
	v.add_child(head)
	var lineup_ids: Array = [club.lineup.get("K", "")] + club.lineup.get("C", []) + club.lineup.get("B", []) + [club.lineup.get("S", "")]
	var t := UI.table([{"title": T("ui.col.name"), "width": 200, "expand": true}, {"title": T("ui.col.pos"), "width": 40, "align": "center"}, {"title": T("ui.col.broom"), "width": 150}, {"title": T("broom.speed"), "width": 70, "align": "right"}, {"title": T("ui.finances.broom_state"), "width": 70, "align": "right"}], 48 + 32 * 10)
	var chosen: Array = [suggested]
	var players := w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE])
	var order := {"K": 0, "C": 1, "B": 2, "S": 3}
	players.sort_custom(func(a, b): return (0 if lineup_ids.has(a.id) else 1) < (0 if lineup_ids.has(b.id) else 1) if lineup_ids.has(a.id) != lineup_ids.has(b.id) else order[a.position] < order[b.position])
	for p in players:
		var cur: Dictionary = Game.loader.brooms.get(str(p.broom.get("model_id", "")), {})
		var it := UI.row(t, [p.name() + (" · " + T("ui.finances.suggested") if p == suggested else ""), p.position, str(cur.get("model", "?")), str(int(cur.get("speed", 0))), "%d%%" % int(p.broom.get("condition", 100.0))], p.id)
		if lineup_ids.has(p.id):
			it.set_custom_font(0, ThemeBuilder.font("table_bold"))
		if p == suggested:
			it.select(0)
	t.item_selected.connect(func():
		var it := t.get_selected()
		if it != null:
			chosen[0] = w.player(str(it.get_metadata(0)))
			dlg.ok_button_text = T("ui.finances.buy_for") % chosen[0].name())
	v.add_child(t)
	v.add_child(UI.text("MetaItalic", T("ui.finances.broom_target_note") % str(int(broom.get("speed", 0)))))
	dlg.add_child(v)
	dlg.confirmed.connect(func():
		if chosen[0] != null:
			_assign_broom(chosen[0], id, price)
		dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.reset_size()
	dlg.popup_centered()


func _assign_broom(p: Player, id: String, price: int) -> void:
	var club := Game.my_club()
	if club.balance < price:
		main.toast(T("ui.market.no_funds"), "x-circle", "error")
		return
	Economy.book(Game.world, club, "brooms", -price)
	p.broom = {"model_id": id, "condition": 100.0}
	Inbox.tell(Game.world, &"from.club_secretary", "msg.broom_bought.subject", "msg.broom_bought.body", {"broom": Say.plain(str(Game.loader.brooms[id]["model"])), "player": Say.player(p)})
	main.toast(T("msg.broom_bought.subject") + ": " + p.name(), "check-circle", "ok")
	Game.world_changed.emit()


func _debug_broom() -> void:
	_buy_broom("broom_nimbus_2000", 800)


const LEDGER_KINDS := ["gate", "sponsor", "merch", "prizes", "investment", "transfers_in", "wages", "staff", "scouts", "transfers_out", "signing_fees", "bonuses", "severance", "facilities", "brooms"]


func _ledger(club: Club) -> void:
	var lp := UI.panel()
	var lv := UI.vbox(8)
	lv.add_child(UI.subtitle(T("ui.finances.ledger")))
	var months: Array = club.ledger.keys()
	months.sort()
	months = months.slice(maxi(0, months.size() - 6))
	if months.is_empty():
		lv.add_child(UI.text("MetaItalic", T("ui.finances.ledger_empty")))
		lp.add_child(lv)
		body.add_child(lp)
		return
	var cols: Array = [{"title": T("ui.finances.concept"), "width": 170, "expand": true}]
	var mnames: PackedStringArray = UI.month_names()
	for m in months:
		var parts: PackedStringArray = str(m).split("-")
		cols.append({"title": "%s %s" % [mnames[int(parts[1]) - 1].strip_edges().left(3), parts[0].substr(2)], "width": 80, "align": "right"})
	var used: Array = []
	for k in LEDGER_KINDS:
		for m in months:
			if int(club.ledger[m].get(k, 0)) != 0:
				used.append(k)
				break
	var t := UI.table(cols, 48 + 32 * (used.size() + 1))
	UI.fit_rows(t)
	for k in used:
		var vals: Array = [T("ledger." + k)]
		for m in months:
			var v := int(club.ledger[m].get(k, 0))
			vals.append(Game.galleons(v) if v != 0 else "—")
		var it := UI.row(t, vals)
		for i in months.size():
			var v2 := int(club.ledger[months[i]].get(k, 0))
			if v2 != 0:
				it.set_custom_color(i + 1, ThemeBuilder.GREEN if v2 > 0 else ThemeBuilder.SEALING_WAX)
	var tot: Array = [T("ui.finances.net")]
	var totals: Array = []
	for m in months:
		var sum := 0
		for k in club.ledger[m].keys():
			sum += int(club.ledger[m][k])
		totals.append(sum)
		tot.append(Game.galleons(sum))
	var ti := UI.row(t, tot)
	ti.set_custom_font(0, ThemeBuilder.font("table_bold"))
	for i in totals.size():
		ti.set_custom_font(i + 1, ThemeBuilder.font("table_bold"))
		ti.set_custom_color(i + 1, ThemeBuilder.GREEN if int(totals[i]) >= 0 else ThemeBuilder.SEALING_WAX)
	lv.add_child(t)
	lp.add_child(lv)
	body.add_child(lp)

