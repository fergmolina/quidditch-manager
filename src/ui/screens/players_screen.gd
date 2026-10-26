extends UIScreen
## Worldwide player search: name, position and region, plus collapsed advanced filters. Sorted by
## ability; what you see of each player depends on what your scouts know (same as in the rest of the game).
## Available in any mode (club, Hogwarts house or unemployed).

var body: VBoxContainer
var name_filter := ""
var pos_filter := ""
var region_filter := ""
var adv_open := false
var adv := {"age_min": 15, "age_max": 45, "value_max": 0, "wage_max": 0, "contract_year": 0, "nat": "", "status": "", "stars_min": 0, "attr": "", "attr_min": 1}
var page_size := 200


func build() -> void:
	header(T("ui.explorer.players"))
	body = UI.vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := UI.scroll(body)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sc)


func refresh() -> void:
	clear(body)
	_players()


func _players() -> void:
	var w := Game.world
	var bar := UI.hbox(8)
	var ne := LineEdit.new()
	ne.placeholder_text = T("ui.explorer.search")
	ne.text = name_filter
	ne.custom_minimum_size = Vector2(240, 0)
	ne.text_submitted.connect(func(t): name_filter = t.strip_edges(); refresh())
	bar.add_child(ne)
	bar.add_child(UI.option([["", T("ui.explorer.all_positions")], ["K", T("pos.K")], ["C", T("pos.C")], ["B", T("pos.B")], ["S", T("pos.S")]], pos_filter, func(v): pos_filter = str(v); refresh()))
	var regs := [["", T("ui.explorer.all_regions")]]
	var rids := Game.loader.regions.keys()
	rids.sort()
	for rid in rids:
		var rd: Dictionary = Game.loader.regions[rid]
		regs.append([rid, Loc.region(rd, rid)])
	bar.add_child(UI.option(regs, region_filter, func(v): region_filter = str(v); refresh()))
	bar.add_child(UI.button(T("ui.explorer.search_btn"), func(): name_filter = ne.text.strip_edges(); refresh()))
	bar.add_child(UI.button(T("ui.explorer.less_filters") if adv_open else T("ui.explorer.more_filters"), func(): adv_open = not adv_open; refresh()))
	body.add_child(bar)
	if adv_open:
		body.add_child(_adv_panel())
	var found: Array = []
	var q := name_filter.to_lower()
	for p in w.players.values():
		if p.squad == Player.Squad.ABROAD and q == "":
			continue
		if pos_filter != "" and p.position != pos_filter:
			continue
		if q != "" and p.name().to_lower().find(q) < 0:
			continue
		if region_filter != "":
			var reg := ""
			if p.club_id != "" and w.clubs.has(p.club_id):
				reg = w.clubs[p.club_id].region_id
			else:
				reg = Game.loader.region_of_country(p.nationality)
			if reg != region_filter:
				continue
		if not _adv_ok(w, p):
			continue
		found.append(p)
	var known := {}
	var ca := {}
	for p in found:
		known[p.id] = Game.knowledge_level(p) >= 1
		ca[p.id] = p.ca()
	found.sort_custom(func(a, b):
		if known[a.id] != known[b.id]:
			return known[a.id]
		if known[a.id] and ca[a.id] != ca[b.id]:
			return ca[a.id] > ca[b.id]
		return a.name() < b.name() if a.name() != b.name() else a.id < b.id)
	body.add_child(UI.text("Meta", T("ui.explorer.found") % found.size()))
	var t := UI.table([{"title": T("ui.col.name"), "width": 200, "expand": true}, {"title": T("ui.col.pos"), "width": 40}, {"title": T("ui.col.age"), "width": 44, "align": "right"}, {"title": T("ui.col.club"), "width": 200}, {"title": T("ui.col.value"), "width": 80, "align": "right"}, {"title": T("ui.col.wage"), "width": 70, "align": "right"}, {"title": T("ui.col.ability"), "width": 90}, {"title": T("ui.col.potential"), "width": 90}], 520)
	for p in found.slice(0, page_size):
		var lvl: int = Game.knowledge_level(p)
		var team := w.team_name(p.club_id) if p.club_id != "" else (w.team_name(Schools.house_id(p.school_id, p.house)) if p.squad == Player.Squad.SCHOOL else (T("ui.squad.abroad") if p.squad == Player.Squad.ABROAD else T("ui.squad.free")))
		var erow := UI.row(t, [p.name(), UI.pos_short(p.position), p.age(w.today), team, Game.galleons(p.market_value(w.today)) if lvl >= 1 else "?", Game.galleons(int(p.contract.get("wage_weekly", 0))) if p.club_id != "" else "—", _stars(p.ca()) if lvl >= 1 else "?", _stars(p.pa) if lvl >= 2 else "?"], p.id)
		UI.player_cell(erow, 0, p.id)
		UI.team_cell(erow, 3, p.club_id if p.club_id != "" else (Schools.house_id(p.school_id, p.house) if p.squad == Player.Squad.SCHOOL else ""))
	t.item_activated.connect(func():
		var it := t.get_selected()
		if it != null:
			go("player", {"player_id": str(it.get_metadata(0))}))
	body.add_child(UI.table_card(t))
	if found.size() > page_size:
		body.add_child(UI.button(T("ui.explorer.show_more") % (found.size() - page_size), func(): page_size += 200; refresh()))


func _adv_ok(w: World, p: Player) -> bool:
	var age := p.age(w.today)
	if age < int(adv["age_min"]) or age > int(adv["age_max"]):
		return false
	if int(adv["value_max"]) > 0 and p.market_value(w.today) > int(adv["value_max"]):
		return false
	if int(adv["wage_max"]) > 0 and int(p.contract.get("wage_weekly", 0)) > int(adv["wage_max"]):
		return false
	if int(adv["contract_year"]) > 0 and (p.club_id == "" or WDate.year(int(p.contract.get("end_day", 0))) > int(adv["contract_year"])):
		return false
	if str(adv["nat"]) != "" and p.nationality != str(adv["nat"]):
		return false
	match str(adv["status"]):
		"free":
			if p.club_id != "":
				return false
		"listed":
			if not p.transfer_listed:
				return false
		"loan":
			if not p.loan_listed:
				return false
	var lvl: int = Game.knowledge_level(p)
	if int(adv["stars_min"]) > 0 and (lvl < 1 or _stars(p.ca()).count("★") < int(adv["stars_min"])):
		return false
	if str(adv["attr"]) != "" and (lvl < 2 or float(p.attrs.get(str(adv["attr"]), 0.0)) < float(adv["attr_min"])):
		return false
	return true


func _adv_spin(grid: GridContainer, key: String, label: String, lo: int, hi: int, step: int) -> void:
	grid.add_child(UI.label(label, "ui", 13))
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value = int(adv[key])
	sb.custom_minimum_size = Vector2(110, 0)
	sb.value_changed.connect(func(v): adv[key] = int(v))
	grid.add_child(sb)


func _adv_panel() -> Control:
	var w := Game.world
	var p := UI.panel(10)
	var v := UI.vbox(8)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	_adv_spin(grid, "age_min", T("ui.explorer.age_min"), 15, 45, 1)
	_adv_spin(grid, "age_max", T("ui.explorer.age_max"), 15, 45, 1)
	_adv_spin(grid, "value_max", T("ui.explorer.value_max"), 0, 100000, 100)
	_adv_spin(grid, "wage_max", T("ui.explorer.wage_max"), 0, 2000, 5)
	_adv_spin(grid, "contract_year", T("ui.explorer.contract_until"), 0, w.season + 6, 1)
	_adv_spin(grid, "stars_min", T("ui.explorer.stars_min"), 0, 5, 1)
	grid.add_child(UI.label(T("ui.explorer.nationality"), "ui", 13))
	var nats := {}
	for q in w.players.values():
		nats[q.nationality] = true
	var nat_items := [["", T("ui.explorer.any")]]
	var keys := nats.keys()
	keys.sort_custom(func(a, b): return Loc.name("country." + str(a), str(a)) < Loc.name("country." + str(b), str(b)))
	for k in keys:
		nat_items.append([k, Loc.name("country." + str(k), str(k))])
	grid.add_child(UI.option(nat_items, adv["nat"], func(val): adv["nat"] = str(val)))
	grid.add_child(UI.label(T("ui.explorer.status"), "ui", 13))
	grid.add_child(UI.option([["", T("ui.explorer.any")], ["free", T("ui.squad.free")], ["listed", T("ui.market.listed_short")], ["loan", T("ui.market.loan_short")]], adv["status"], func(val): adv["status"] = str(val)))
	grid.add_child(UI.label(T("ui.explorer.attr"), "ui", 13))
	var attr_items := [["", T("ui.explorer.any")]]
	for k in Player.ATTR_KEYS:
		attr_items.append([k, T("attr." + k)])
	grid.add_child(UI.option(attr_items, adv["attr"], func(val): adv["attr"] = str(val)))
	_adv_spin(grid, "attr_min", T("ui.explorer.attr_min"), 1, 20, 1)
	v.add_child(grid)
	var note := UI.label(T("ui.explorer.adv_note"), "ui_italic", 12, ThemeBuilder.INK_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var hb := UI.hbox(8)
	hb.add_child(UI.primary(T("ui.explorer.search_btn"), func(): page_size = 200; refresh()))
	hb.add_child(UI.button(T("ui.explorer.reset"), func(): adv = {"age_min": 15, "age_max": 45, "value_max": 0, "wage_max": 0, "contract_year": 0, "nat": "", "status": "", "stars_min": 0, "attr": "", "attr_min": 1}; refresh()))
	v.add_child(hb)
	p.add_child(v)
	return p


func _stars(ca: float) -> String:
	var n := clampi(int(round(ca / 36.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)
