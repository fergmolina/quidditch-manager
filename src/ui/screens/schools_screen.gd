extends UIScreen
## Schools: House Cup visible (table, matches, teams) for schools with houses;
## youth academy (youngsters who left the school) for all. They are not managed.

var body: VBoxContainer
var school_sel: OptionButton
var selected := ""


func build() -> void:
	header(T("ui.menu.schools"))
	var items := []
	var ids := Game.loader.schools.keys()
	ids.sort()
	for sid in ids:
		items.append([sid, Game.school_name(sid, false)])
	var me := Game.my_club()
	var my_school := ""
	if me != null:
		my_school = Schools.school_for(Game.loader, me.region_id, me.country_id)
	selected = str(params.get("school_id", my_school if my_school != "" else (str(items[0][0]) if not items.is_empty() else "")))
	school_sel = UI.option(items, selected, func(v): selected = str(v); refresh(), 420)
	var bar := UI.hbox()
	bar.add_child(school_sel)
	bar.add_child(UI.spacer())
	root.add_child(bar)
	body = UI.vbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(UI.scroll(body))


## Back from a student's profile returns to the school that was open.
func nav_state() -> Dictionary:
	return {"school_id": selected}


func refresh() -> void:
	clear(body)
	var sc: Dictionary = Game.loader.schools.get(selected, {})
	if sc.is_empty():
		return
	var houses: Array = sc.get("houses", [])
	var w := Game.world
	if not houses.is_empty():
		_house_cup(sc, houses)
		_rosters(sc, houses)
	else:
		body.add_child(UI.text("MetaItalic", T("ui.school.note")))
	_alumni()


func _house_cup(sc: Dictionary, houses: Array) -> void:
	var w := Game.world
	var cid := "comp_school_%s_%d" % [selected.trim_prefix("school_"), w.season]
	var comp: Competition = w.competitions.get(cid)
	var top := UI.hbox(12)
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var tp := UI.panel(8)
	tp.custom_minimum_size = Vector2(430, 0)
	var tv := UI.vbox(6)
	tv.add_child(UI.subtitle("%s · %d-%02d" % [T("ui.school.cup"), w.season, (w.season + 1) % 100]))
	if comp == null:
		tv.add_child(UI.text("MetaItalic", T("ui.school.no_cup")))
	else:
		var t := UI.table([{"title": "", "width": 30, "align": "right"}, {"title": T("ui.school.house"), "width": 150, "expand": true}, {"title": T("ui.col.played"), "width": 36, "align": "right"}, {"title": T("ui.col.won"), "width": 30, "align": "right"}, {"title": T("ui.col.points"), "width": 60, "align": "right"}, {"title": T("ui.col.catches"), "width": 50, "align": "right"}, {"title": T("ui.school.cups"), "width": 50, "align": "right"}, {"title": T("ui.school.world_cups"), "width": 50, "align": "right"}], 190)
		var i := 0
		for row in comp.standings():
			i += 1
			var hid := str(row["club_id"])
			var hd: Dictionary = w.houses.get(hid, {})
			var it := UI.row(t, [i, w.team_name(hid), row["pj"], row["w"], row["pts"], row["catches"], int(hd.get("cups", 0)), int(hd.get("world_cups", 0))], hid)
			UI.club_cell(it, 1, Game.team_as_club(hid))
			it.set_custom_font(4, ThemeBuilder.font("table_bold"))
		tv.add_child(t)
	tp.add_child(tv)
	top.add_child(tp)
	var fp := UI.panel(8)
	fp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fv := UI.vbox(6)
	fv.add_child(UI.subtitle(T("ui.school.fixtures")))
	if comp != null:
		var ft := UI.table([{"title": T("ui.col.date"), "width": 120}, {"title": T("ui.col.home"), "width": 110, "expand": true}, {"title": T("ui.col.result"), "width": 80, "align": "center"}, {"title": T("ui.col.away"), "width": 110, "expand": true}, {"title": T("ui.col.snitch"), "width": 130}], 220)
		for f in comp.fixtures:
			var res := "%d – %d" % [int(f.get("score_home", 0)), int(f.get("score_away", 0))] if bool(f.get("played", false)) else str(f.get("hour", ""))
			var catcher := Game.player_name(str(f.get("snitch_player_id", ""))) if str(f.get("snitch_player_id", "")) != "" else ""
			var it := UI.row(ft, [Game.date_text(int(f["day"])), w.team_name(str(f["home_id"])), res, w.team_name(str(f["away_id"])), catcher], str(f["id"]))
			UI.team_cell(it, 1, str(f["home_id"]))
			UI.team_cell(it, 3, str(f["away_id"]))
			UI.player_cell(it, 4, str(f.get("snitch_player_id", "")))
			if bool(f.get("played", false)):
				it.set_custom_color(2, ThemeBuilder.GREEN)
				it.set_custom_font(2, ThemeBuilder.font("table_bold"))
		fv.add_child(ft)
	fp.add_child(fv)
	top.add_child(fp)
	body.add_child(top)


func _rosters(sc: Dictionary, houses: Array) -> void:
	var w := Game.world
	body.add_child(UI.subtitle(T("ui.school.roster")))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for h in houses:
		var hid := Schools.house_id(selected, str(h))
		var hd: Dictionary = w.houses.get(hid, {})
		var p := UI.panel(8)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(4)
		var hh := UI.hbox(8)
		var hcrest := UI.crest(Game.team_as_club(hid), 30)
		UI.make_team_clickable(hcrest, hid)
		hh.add_child(hcrest)
		var hname := UI.h2(w.team_name(hid))
		UI.make_team_clickable(hname, hid)
		hh.add_child(hname)
		v.add_child(hh)
		var t := UI.table([{"title": T("ui.col.name"), "width": 110, "expand": true}, {"title": T("ui.col.pos"), "width": 32, "align": "center"}, {"title": T("ui.col.age"), "width": 36, "align": "right"}, {"title": T("ui.ca_stars"), "width": 64}, {"title": T("ui.pa_stars"), "width": 64}, {"title": T("ui.col.broom"), "width": 84}, {"title": T("ui.school.after_school"), "width": 84, "tooltip": T("ui.school.after_school_tip")}], 120 + 26 * 9)
		t.scroll_horizontal_enabled = false
		t.item_activated.connect(func(): var it := t.get_selected(); if it: go("player", {"player_id": str(it.get_metadata(0))}))
		var students := Schools.students_of(w, selected, str(h))
		for s in students:
			var name := s.name() + (" ★" if s.is_captain else "")
			var bname := str(Game.loader.brooms.get(str(s.broom.get("model_id", "")), {}).get("model", "?"))
			var book := Schools.book_destination(w, s)
			var leaving := Schools.school_year(s, w) >= Schools.FINAL_YEAR or book != ""
			var signed_id := s.pre_contract.club_id if s.pre_contract != null and s.pre_contract.graduate else ""
			if book != "":
				signed_id = book
			if not w.clubs.has(signed_id):
				signed_id = ""
			var after := (Game.club_name(signed_id) if signed_id != "" else "—") if leaving else ""
			var it := UI.row(t, [name, UI.pos_short(s.position), s.age(w.today), _stars(s.ca()), _stars(s.pa), bname, after], s.id)
			UI.player_cell(it, 0, s.id)
			UI.team_cell(it, 6, signed_id)
			if leaving:
				it.set_custom_color(2, ThemeBuilder.BRONZE_TEXT)
				it.set_tooltip_text(2, T("ui.school.graduates"))
		v.add_child(t)
		_tryouts(v, hid, hd)
		p.add_child(v)
		grid.add_child(p)
	body.add_child(grid)


func _tryouts(v: VBoxContainer, hid: String, hd: Dictionary) -> void:
	var w := Game.world
	var season := "%d-%02d" % [w.season, (w.season + 1) % 100]
	var t: Dictionary = hd.get("tryouts", {})
	if not t.is_empty() and w.league_of(hid) != null:   # [OotP 13]
		var n_cands := 0
		for pl in t.get("places", []):
			n_cands += pl.get("candidates", []).size()
		var row := UI.hbox(8)
		var l := UI.text("MetaItalic", T("ui.school.tryouts_pending", {"season": season, "n": t.get("places", []).size(), "cands": n_cands, "date": Game.date_text(int(t.get("deadline", w.today)))}))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		if hid == w.player_club_id:
			row.add_child(UI.primary(T("ui.tryouts.hold"), func():
				var td = TryoutsDialog.new()
				td.done.connect(func(): Game.world_changed.emit())
				td.canceled.connect(func(): Schools.snooze_tryouts(w, hid); Game.mark_dirty(); Game.world_changed.emit())
				td.open_for(self, w, hid)))
		v.add_child(row)
	var members := Schools.intake_of(w, hid)
	if members.is_empty():
		return
	var parts: Array = []
	var by := ""
	for mb in members:
		var q: Player = w.player(str(mb.get("id", "")))
		if q == null:
			continue
		parts.append(Say.phrase("ui.list.name_detail", {"name": Say.player(q), "detail": Say.key("pos." + str(mb.get("pos", q.position)))}).as_arg())
		if str(mb.get("by", "auto")) != "auto":
			by = str(mb["by"])
	if parts.is_empty():
		return
	var line := Say.render(Say.phrase("ui.school.tryouts_line", {"season": Say.plain(str(season)), "players": Say.list(parts)}), true)
	v.add_child(UI.rich_links(line + (" " + T("ui.school.tryouts_by_" + by) if by != "" else "")))


func _alumni() -> void:
	var w := Game.world
	var p := UI.panel(8)
	var v := UI.vbox(6)
	v.add_child(UI.subtitle(T("ui.school.alumni")))
	var rows: Array[Player] = []
	for q in w.players.values():
		if q.school_id == selected and q.age(w.today) <= 21 and q.squad != Player.Squad.SCHOOL:
			rows.append(q)
	rows.sort_custom(func(a, b): return a.pa > b.pa)
	var t := UI.table([{"title": T("ui.col.name"), "width": 200, "expand": true}, {"title": T("ui.col.pos"), "width": 40, "align": "center"}, {"title": T("ui.col.age"), "width": 40, "align": "right"}, {"title": T("ui.col.club"), "width": 200}, {"title": T("ui.ca_stars"), "width": 80}, {"title": T("ui.pa_stars"), "width": 80}], 48 + 32 * mini(rows.size(), 40))
	t.item_activated.connect(func(): var it := t.get_selected(); if it: go("player", {"player_id": str(it.get_metadata(0))}))
	for q in rows.slice(0, 40):
		var lvl := Game.knowledge_level(q)
		var qrow := UI.row(t, [q.name(), UI.pos_short(q.position), q.age(w.today), (Game.club_name(q.club_id) if q.club_id != "" else T("ui.free_agent")), _stars(q.ca()) if lvl >= 1 else "?", _stars(q.pa) if lvl >= 2 else "?"], q.id)
		UI.player_cell(qrow, 0, q.id)
		UI.team_cell(qrow, 3, q.club_id)
	v.add_child(t)
	p.add_child(v)
	body.add_child(p)


func _stars(ca: float) -> String:
	var n := clampi(int(round(ca / 36.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)
