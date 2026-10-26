extends UIScreen
## Scouts by region: knowledge 0-100, hire and assign.

var body: VBoxContainer
var balance_label: Label


func build() -> void:
	var hh := UI.hbox()
	hh.add_child(UI.title(T("ui.menu.scouting")))
	hh.add_child(UI.spacer())
	balance_label = UI.meta(Game.galleons(Game.my_club().balance))
	balance_label.size_flags_vertical = Control.SIZE_SHRINK_END
	hh.add_child(balance_label)
	root.add_child(hh)
	root.add_child(UI.gap(4))
	var p := UI.panel()
	body = UI.vbox(8)
	p.add_child(body)
	root.add_child(p)


func refresh() -> void:
	clear(body)
	var club := Game.my_club()
	balance_label.text = Game.galleons(club.balance)
	body.add_child(UI.subtitle(T("ui.scout.knowledge")))
	var regions := Game.loader.regions.keys()
	regions.sort()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	for rid in regions:
		var reg: Dictionary = Game.loader.regions[rid]
		var k: float = float(club.knowledge.get(rid, 0.0))
		var h := UI.hbox(6)
		var name := Loc.region(reg, rid)
		var l := UI.label(name, "ui_medium", 14)
		l.custom_minimum_size = Vector2(170, 0)
		h.add_child(l)
		var pb := ProgressBar.new()
		pb.min_value = 0
		pb.max_value = 100
		pb.value = k
		pb.custom_minimum_size = Vector2(110, 12)
		pb.show_percentage = false
		h.add_child(pb)
		h.add_child(UI.label("%d" % int(k), "table", 13))
		grid.add_child(h)
	body.add_child(grid)
	body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.scout.staff")))
	for i in club.scouts.size():
		var sc: Dictionary = club.scouts[i]
		var h := UI.hbox(8)
		h.add_child(UI.label("%s (%s %d)" % [sc.get("name", "?"), T("ui.scout.quality"), int(sc.get("quality", 2))], "ui_medium", 14))
		var items := []
		for rid in regions:
			var reg: Dictionary = Game.loader.regions[rid]
			items.append([rid, Loc.region(reg, rid)])
		var ob := UI.option(items, sc.get("region_id", club.region_id), func(v): sc["region_id"] = str(v))
		h.add_child(ob)
		h.add_child(UI.label("%s %s/%s" % [Game.galleons(int(sc.get("wage_monthly", 60))), "", T("ui.month")], "ui", 13, ThemeBuilder.INK_SOFT))
		var idx: int = i
		h.add_child(UI.button(T("ui.staff.fire") % Game.galleons(_severance(sc)), func(): _dismiss(idx)))
		body.add_child(h)
	if club.scouts.size() < 4:
		body.add_child(UI.button(T("ui.scout.hire"), _hire))
	body.add_child(UI.label(T("ui.scout.fee_note"), "ui_italic", 13, ThemeBuilder.INK_SOFT))
	body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.scout.assignments")))
	var cb := CheckBox.new()
	cb.text = T("ui.scout.opponent_toggle")
	cb.button_pressed = bool(Game.world.settings.get("scout_opponent", false))
	cb.toggled.connect(func(on): Game.world.settings["scout_opponent"] = on)
	cb.disabled = club.scouts.is_empty()
	body.add_child(cb)
	var pend := []
	var done := []
	for pid in club.scout_reports.keys():
		var r: Dictionary = club.scout_reports[pid]
		if bool(r.get("pending", false)):
			pend.append([str(pid), Game.date_text(int(r["due"]))])
		elif r.has("day"):
			done.append([int(r["day"]), str(pid), r])
	body.add_child(_pending_line(pend))
	if not done.is_empty():
		done.sort_custom(func(a, b): return a[0] > b[0])
		var t := UI.table([{"title": T("ui.col.name"), "width": 200, "expand": true}, {"title": T("ui.col.ability"), "width": 90}, {"title": T("ui.col.potential"), "width": 90}, {"title": T("ui.scout.verdict"), "width": 200}], 48 + 32 * mini(done.size(), 10))
		for d in done.slice(0, 10):
			var r2: Dictionary = d[2]
			var it := UI.row(t, [Game.player_name(d[1]), "★".repeat(int(r2["ca_est"])) + "☆".repeat(5 - int(r2["ca_est"])), "★".repeat(int(r2["pa_est"])) + "☆".repeat(5 - int(r2["pa_est"])), T(str(r2["verdict"]))], d[1])
			UI.player_cell(it, 0, d[1])
		body.add_child(t)
	body.add_child(UI.label(T("ui.scout.assign_note"), "ui_italic", 13, ThemeBuilder.INK_SOFT))
	body.add_child(UI.label(T("ui.scout.note"), "ui_italic", 13, ThemeBuilder.INK_SOFT))


func _pending_line(pend: Array) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parts := T("ui.scout.pending_list").split("%s")
	if parts[0].strip_edges() != "":
		flow.add_child(UI.label(parts[0].strip_edges(), "ui", 13))
	if pend.is_empty():
		flow.add_child(UI.label("—", "ui", 13))
	for i in pend.size():
		var pid := str(pend[i][0])
		var nl := UI.label(Game.player_name(pid), "ui", 13, ThemeBuilder.BLUE)
		UI.make_player_clickable(nl, pid)
		flow.add_child(nl)
		flow.add_child(UI.label("(%s)%s" % [str(pend[i][1]), "," if i < pend.size() - 1 else ""], "ui", 13))
	if parts.size() > 1 and parts[1].strip_edges() != "":
		flow.add_child(UI.label(parts[1].strip_edges(), "ui", 13))
	return flow


func _severance(sc: Dictionary) -> int:
	return int(sc.get("wage_monthly", 60))


func _hire() -> void:
	var club := Game.my_club()
	if club.balance < Scouting.max_hire_fee():
		main.toast(T("ui.market.no_funds"))
		return
	var names := Game.loader.names_for(club.region_id, club.country_id)
	var rng := Game.world.rng()
	var q: int = rng.irange(1, Scouting.MAX_QUALITY)
	var female := not rng.chance(0.5)
	var first := str(rng.pick(names["first_names_f"] if female else names["first_names_m"]))
	club.scouts.append({"name": "%s %s" % [first, FillerGenerator.female_last(names, str(rng.pick(names["last_names"])), female)], "region_id": club.region_id, "quality": q, "wage_monthly": Scouting.wage(q)})
	Economy.book(Game.world, club, "scouts", -Scouting.hire_fee(q))
	Game.world_changed.emit()


func _dismiss(i: int) -> void:
	var club := Game.my_club()
	if i < 0 or i >= club.scouts.size():
		return
	var cost := _severance(club.scouts[i])
	if club.balance < cost:
		main.toast(T("ui.market.no_funds"))
		return
	Economy.book(Game.world, club, "severance", -cost)
	club.scouts.remove_at(i)
	Game.world_changed.emit()
