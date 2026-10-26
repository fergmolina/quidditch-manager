extends UIScreen
## National team page, params {nt_id}: flag and name, standing and World Cup record, next
## match, the current seven and the pool of players of the nationality (including those "abroad", in leagues the
## game does not simulate). If the manager runs this national team, a button opens its tactics and line-up
## ("national_tactics", lineup_screen in national-team mode).

const SLOT_NAMES := ["K", "C", "C", "C", "B", "B", "S"]

var nt_id := ""
var nt: Dictionary = {}
var body: VBoxContainer


func build() -> void:
	var w := Game.world
	nt_id = str(params.get("nt_id", w.manager.get("national_team_id", "")))
	nt = w.national_teams.get(nt_id, {})
	if nt.is_empty():
		header(T("ui.menu.national"), "")
		return
	var h := UI.hbox(10)
	h.add_child(UI.flag(str(nt.get("country_id", "")), 26))
	h.add_child(UI.title(w.team_name(nt_id)))
	h.add_child(UI.spacer())
	var m := UI.meta(T("ui.menu.national"))
	m.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(m)
	if _is_mine():
		h.add_child(UI.primary(T("ui.menu.lineup"), func(): go("national_tactics", {"nt_id": nt_id})))
	root.add_child(h)
	root.add_child(UI.gap(4))
	var p := UI.panel()
	body = UI.vbox(10)
	p.add_child(UI.scroll(body))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(p)


func _is_mine() -> bool:
	return nt_id != "" and str(Game.world.manager.get("national_team_id", "")) == nt_id


func refresh() -> void:
	if nt.is_empty() or body == null:
		return
	clear(body)
	var w := Game.world
	var seven := _current_seven(w)
	_summary(w)
	_next_match(w)
	body.add_child(UI.subtitle(T("ui.lineup.starters")))
	_seven_table(w, seven)
	_pool_table(w, seven)
	_world_cup_record(w)


func _current_seven(w: World) -> Array:
	var fed := NationalTeams.pick_squad(w, nt)
	var lineup := fed
	if _is_mine() and not nt.get("lineup", {}).is_empty():
		var mine := NationalTeams._patched_lineup(w, nt, nt["lineup"], fed)
		if NationalTeams.lineup_valid(w, nt, mine):
			lineup = mine
	var ids: Array = [str(lineup.get("K", ""))]
	for pos in ["C", "B"]:
		var arr: Array = lineup.get(pos, [])
		for i in (3 if pos == "C" else 2):
			ids.append(str(arr[i]) if i < arr.size() else "")
	ids.append(str(lineup.get("S", "")))
	return ids


func _summary(w: World) -> void:
	var finals := _finals(w).size()
	var tier := str(nt.get("tier", "mid"))
	var row := UI.hbox(24)
	row.add_child(UI.kpi(_stars(NationalTeams.strength(w, nt_id)), T("ui.col.ability")))
	row.add_child(UI.kpi(T("ui.nt.tier." + tier) if tr("ui.nt.tier." + tier) != "ui.nt.tier." + tier else tier, T("ui.nt.tier")))
	row.add_child(UI.kpi(str(int(nt.get("world_cup_titles", 0))), T("ui.explorer.wc_titles")))
	row.add_child(UI.kpi(str(finals), T("ui.nt.finals")))
	if _is_mine():
		row.add_child(UI.kpi(str(w.manager.get("name", "")), T("ui.manager")))
	body.add_child(row)
	body.add_child(UI.rule())


func _next_match(w: World) -> void:
	var nf := {}
	var ncomp: Competition = null
	for comp in w.competitions.values():
		if not comp.club_ids.has(nt_id):
			continue
		var f: Dictionary = comp.next_fixture_of(nt_id, w.today)
		if not f.is_empty() and (nf.is_empty() or int(f["day"]) < int(nf["day"])):
			nf = f
			ncomp = comp
	var nv := UI.vbox(2)
	nv.add_child(UI.text("Caption", T("ui.menu.next_match")))
	if nf.is_empty():
		nv.add_child(UI.text("MetaItalic", T("ui.no_match")))
	else:
		var rival: String = str(nf["away_id"]) if str(nf["home_id"]) == nt_id else str(nf["home_id"])
		var rh := UI.hbox(6)
		rh.add_child(UI.flag(str(w.national_teams.get(rival, {}).get("country_id", "")), 18))
		rh.add_child(UI.team_link(rival, w.team_name(rival)))
		nv.add_child(rh)
		nv.add_child(UI.meta("%s · %s · %s" % [ncomp.display_name(), Game.date_text(int(nf["day"])), Game.venue_text(nf)]))
		var cid := ncomp.id
		nv.add_child(UI.link(T("ui.menu.competitions") + " ▸", func(): go("competitions", {"competition_id": cid})))
	body.add_child(nv)


func _seven_table(w: World, seven: Array) -> void:
	var t := UI.table([
		{"title": T("ui.lineup.col_slot"), "width": 44, "align": "center"}, {"title": T("ui.col.name"), "width": 180, "expand": true},
		{"title": T("ui.col.pos"), "width": 40, "align": "center"}, {"title": T("ui.col.age"), "width": 44, "align": "right"},
		{"title": T("ui.col.club"), "width": 180}, {"title": T("ui.col.ability"), "width": 90}, {"title": T("ui.col.cond"), "width": 60, "align": "right"},
	], 0)
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	t.custom_minimum_size = Vector2(0, 40 + Settings.row_height() * SLOT_NAMES.size())
	UI.fit_rows(t)
	for i in SLOT_NAMES.size():
		var p: Player = w.player(str(seven[i])) if i < seven.size() else null
		if p == null:
			UI.row(t, [UI.pos_short(SLOT_NAMES[i]), "—", "", "", "", "", ""])
			continue
		var it := UI.row(t, [UI.pos_short(SLOT_NAMES[i]), p.name(), UI.pos_short(p.position), p.age(w.today), _club_text(p), _ability(p), "%d" % int(p.condition)], p.id)
		UI.player_cell(it, 1, p.id)
		UI.team_cell(it, 4, p.club_id)
		_abroad_tip(it, 4, p)
		it.set_custom_font(0, ThemeBuilder.font("table_bold"))
		it.set_custom_color(0, ThemeBuilder.BRONZE_TEXT)
		if p.position != SLOT_NAMES[i]:
			it.set_custom_color(2, ThemeBuilder.SEALING_WAX)
	_open_on_activate(t)
	body.add_child(UI.table_card(t))


func _pool_table(w: World, seven: Array) -> void:
	var pool := w.players_of_nationality(str(nt.get("country_id", "")))
	body.add_child(UI.subtitle("%s · %d" % [T("ui.nt.pool"), pool.size()]))
	var t := UI.table([
		{"title": T("ui.col.name"), "width": 180, "expand": true}, {"title": T("ui.col.pos"), "width": 40, "align": "center"},
		{"title": T("ui.col.age"), "width": 44, "align": "right"}, {"title": T("ui.col.club"), "width": 180},
		{"title": T("ui.col.ability"), "width": 90}, {"title": T("ui.col.cond"), "width": 60, "align": "right"}, {"title": "", "width": 56},
	], 0)
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	t.custom_minimum_size = Vector2(0, 40 + Settings.row_height() * clampi(pool.size(), 1, 16))
	for p in pool:
		var st := ""
		if p.injury_days > 0:
			st = "✚ %d" % p.injury_days
		elif p.suspension_matches > 0:
			st = "⊘ %d" % p.suspension_matches
		var it := UI.row(t, [p.name(), UI.pos_short(p.position), p.age(w.today), _club_text(p), _ability(p), "%d" % int(p.condition), st], p.id)
		UI.player_cell(it, 0, p.id)
		UI.team_cell(it, 3, p.club_id)
		_abroad_tip(it, 3, p)
		if seven.has(p.id):
			it.set_custom_font(0, ThemeBuilder.font("table_bold"))
		if not p.is_fit():
			it.set_custom_color(0, ThemeBuilder.SEALING_WAX)
			it.set_custom_color(6, ThemeBuilder.SEALING_WAX)
			it.set_tooltip_text(6, (T("ui.injured_days") % p.injury_days) if p.injury_days > 0 else (T("ui.suspended") % p.suspension_matches))
	_open_on_activate(t)
	body.add_child(UI.table_card(t))


func _world_cup_record(w: World) -> void:
	body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.nt.record")))
	var rows := _finals(w)
	if rows.is_empty():
		body.add_child(UI.text("MetaItalic", T("ui.nt.no_finals")))
		return
	var t := UI.table([
		{"title": T("ui.enc.col.year"), "width": 70, "align": "right"}, {"title": T("ui.enc.champion"), "width": 200, "expand": true},
		{"title": T("ui.enc.runner_up"), "width": 200, "expand": true}, {"title": T("ui.col.result"), "width": 90, "align": "center"},
	], 0)
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	t.custom_minimum_size = Vector2(0, 40 + Settings.row_height() * rows.size())
	UI.fit_rows(t)
	for h in rows:
		var champ := str(h["champion_id"])
		var runner := str(h.get("runner_up_id", ""))
		var it := UI.row(t, [int(h["season"]), w.team_name(champ), w.team_name(runner) if runner != "" else "—", str(h.get("score", ""))], str(h["season"]))
		for pair in [[1, champ], [2, runner]]:
			if str(pair[1]) == nt_id:
				it.set_custom_font(int(pair[0]), ThemeBuilder.font("table_bold"))
			else:
				UI.team_cell(it, int(pair[0]), str(pair[1]))
	body.add_child(UI.table_card(t))


func _finals(w: World) -> Array:
	var out: Array = []
	for h in w.history:
		var cid := str(h.get("competition_id", ""))
		if not (cid.begins_with("comp_world_cup_") and cid.ends_with("_final")):
			continue
		if str(h.get("champion_id", "")) == nt_id or str(h.get("runner_up_id", "")) == nt_id:
			out.append(h)
	out.sort_custom(func(a, b): return int(a["season"]) > int(b["season"]))
	return out


func _club_text(p: Player) -> String:
	if p.club_id != "":
		return Game.world.team_name(p.club_id)
	if p.squad == Player.Squad.FREE:
		return T("ui.free_agent")
	return "—"


func _abroad_tip(it: TreeItem, col: int, p: Player) -> void:
	if p.club_id == "" and p.squad == Player.Squad.ABROAD:
		it.set_tooltip_text(col, T("ui.squad.abroad"))


func _ability(p: Player) -> String:
	return _stars(p.ca()) if Game.knowledge_level(p) >= 1 else "?"


func _open_on_activate(t: Tree) -> void:
	t.item_activated.connect(func():
		var it := t.get_selected()
		if it != null and it.get_metadata(0) != null and Game.world.player(str(it.get_metadata(0))) != null:
			go("player", {"player_id": str(it.get_metadata(0))}))


func _stars(ca: float) -> String:
	var n := clampi(int(round(ca / 36.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)
