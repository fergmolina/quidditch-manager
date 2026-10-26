extends UIScreen
## Club (or house) profile: the squad first, then identity, honours and season history.

var body: VBoxContainer
var club: Club


func build() -> void:
	var w := Game.world
	var cid := str(params.get("club_id", w.player_club_id))
	club = w.team_club(cid)
	if club == null:
		header(T("ui.menu.club"), "")
		return
	header(club.name, club.display_city())
	var p := UI.panel()
	body = UI.vbox(8)
	p.add_child(UI.scroll(body))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(p)


func refresh() -> void:
	if club == null or body == null:
		return
	clear(body)
	var w := Game.world
	_title_marker(w)
	_squad_table(w)
	body.add_child(UI.rule())
	var h := UI.hbox()
	var art := UI.image_for("portraits", club.id)
	if art != null:
		var tr := TextureRect.new()
		tr.texture = art
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(190, 210)
		h.add_child(tr)
	var crest := Crest.new()
	crest.custom_minimum_size = Vector2(150, int(150 * 1.15))
	crest.set_club(club)
	h.add_child(crest)
	var v := UI.vbox(4)
	if club.founded > 0:
		v.add_child(UI.label("%s %d" % [T("ui.founded"), club.founded], "ui_medium", 15))
	var parts := []
	for tc in club.trophy_counts():
		parts.append("%s: %d" % [T(tc[0]), tc[1]])
	v.add_child(UI.label(" · ".join(parts)))
	if int(club.history.get("league_titles", 0)) > 0:
		var last_season := int(club.history.get("last_title", 0))
		var last_year := int(club.history.get("last_league_title", 0))   # [QTTA c7]
		if last_season > 0:
			v.add_child(UI.label("%s: %d-%02d" % [T("ui.board.last_title"), last_season, (last_season + 1) % 100]))
		elif last_year > 0:
			v.add_child(UI.label("%s: %d" % [T("ui.board.last_title"), last_year]))
	if club.manager_name != "":
		v.add_child(UI.label(T("ui.label_value") % [T("ui.manager"), club.manager_name]))
	if not club.ground.is_empty():
		v.add_child(UI.label("%s: %s · %s" % [T("ui.ground"), Grounds.name_of(club), T("ui.capacity") % Game.galleons(Grounds.capacity_of(club)).replace(" G", "")]))
	var past: Array = club.history.get("managers", [])
	if not past.is_empty():
		var names := []
		for m in past.slice(maxi(0, past.size() - 3)):
			names.push_front("%s (%d)" % [str(m.get("name", "")), WDate.year(int(m.get("until", 0)))])
		var pl := UI.label(T("ui.label_value") % [T("ui.past_managers"), NewsGenerator.list_sep().join(names)], "ui", 13, ThemeBuilder.INK_SOFT)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(pl)
	v.add_child(UI.label("%s: %d" % [T("ui.level"), club.level]))
	if str(club.identity.get("motto", "")) != "":
		v.add_child(UI.label("«%s»" % str(club.identity["motto"]), "title_italic", 16, ThemeBuilder.BRONZE_DARK))
	if club.is_women_only():
		v.add_child(UI.label(T("ui.women_only"), "ui_italic", 13, ThemeBuilder.INK_SOFT))
	h.add_child(v)
	body.add_child(h)
	body.add_child(UI.rule())
	var rivals: Array = club.identity.get("rivalries", [])
	if not rivals.is_empty():
		var rf := HFlowContainer.new()
		rf.add_theme_constant_override("h_separation", 6)
		rf.add_child(UI.label("%s:" % T("ui.rivalries")))
		for i in rivals.size():
			var rid := str(rivals[i])
			var name_txt := Game.club_name(rid) + ("," if i < rivals.size() - 1 else "")
			if w.clubs.has(rid) or w.houses.has(rid):
				rf.add_child(UI.team_link(rid, name_txt))
			else:
				rf.add_child(UI.label(name_txt))
		body.add_child(rf)
	_honours(w)
	var keys := club.season_summary.keys()
	keys.sort()
	for k in keys:
		var s: Dictionary = club.season_summary[k]
		body.add_child(UI.label("%s: %s · %s" % [k, Game.ordinal(int(s["pos"])), T("ui.pts_n") % int(s["pts"])], "table", 14))
	body.add_child(UI.rule())
	var bh := UI.hbox(8)
	bh.add_child(UI.button(T("ui.menu.squad"), func(): go("squad", {"club_id": club.id})))
	if club.id != w.player_club_id:
		bh.add_child(UI.button(T("ui.menu.lineup"), func(): go("lineup", {"club_id": club.id})))
	body.add_child(bh)


func _title_marker(w: World) -> void:
	var lg: Competition = w.competitions.get(club.league_id)
	if lg == null:
		return
	var season := -1
	if not lg.fixtures.is_empty() and lg.is_finished():
		var st: Array = lg.standings()
		if not st.is_empty() and str(st[0]["club_id"]) == club.id:
			season = lg.season
	else:
		for h in w.history:
			if str(h.get("competition_id", "")) == lg.id:
				if str(h.get("champion_id", "")) == club.id and int(h["season"]) >= w.season - 1:
					season = int(h["season"])
				break
	if season < 0:
		return
	var l := UI.label("★ %s · %s %d-%02d" % [T("ui.cup.champion"), lg.display_name(), season, (season + 1) % 100], "title", 20, ThemeBuilder.AMBER)
	body.add_child(l)


func _honours(w: World) -> void:
	var by_comp := {}
	var order: Array = []
	for h in w.history:
		if str(h.get("champion_id", "")) != club.id:
			continue
		var cid := str(h.get("competition_id", ""))
		var y := int(h["season"])
		var key := Competition.series_of(cid)
		if not by_comp.has(key):
			var cname := _comp_name(h).replace(str(y), "").strip_edges().trim_suffix("·").trim_suffix("-").strip_edges()
			by_comp[key] = {"name": cname, "seasons": []}
			order.append(key)
		by_comp[key]["seasons"].append(str(y) if cid.begins_with("comp_world_cup") else "%d-%02d" % [y, (y + 1) % 100])
	if order.is_empty():
		return
	body.add_child(UI.subtitle(T("ui.club.honours")))
	for key in order:
		var seasons: Array = by_comp[key]["seasons"]
		seasons.reverse()
		var hl := UI.label("%s (%d): %s" % [str(by_comp[key]["name"]), seasons.size(), ", ".join(seasons)], "ui", 14)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(hl)
	body.add_child(UI.rule())


func _comp_name(h: Dictionary) -> String:
	var cid := str(h.get("competition_id", ""))
	var comp: Competition = Game.world.competitions.get(cid)
	if comp != null:
		return comp.display_name()
	var tmp := Competition.new()
	tmp.id = cid
	tmp.name = str(h.get("name", cid))
	tmp.name_en = tmp.name
	return tmp.display_name()


func _squad_table(w: World) -> void:
	var house := Schools.is_house(club.id)
	var players: Array[Player] = w.squad_of(club.id)
	var order := {"K": 0, "C": 1, "B": 2, "S": 3}
	players.sort_custom(func(a, b): return order[a.position] < order[b.position] if a.position != b.position else (a.ca() > b.ca() if a.ca() != b.ca() else a.id < b.id))
	var lineup_ids: Array = []
	if not club.lineup.is_empty():
		lineup_ids = [club.lineup.get("K", "")] + club.lineup.get("C", []) + club.lineup.get("B", []) + [club.lineup.get("S", "")]
	body.add_child(UI.subtitle("%s · %s" % [T("ui.menu.squad"), T("ui.squad.count") % players.size()]))
	var t := UI.table([
		{"title": T("ui.col.name"), "width": 200, "expand": true}, {"title": T("ui.col.pos"), "width": 40, "align": "center"},
		{"title": T("ui.col.age"), "width": 44, "align": "right"}, {"title": T("ui.col.year") if house else T("ui.col.squad"), "width": 90},
		{"title": T("ui.col.ability"), "width": 90}, {"title": "", "width": 60},
	], 0)
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	t.custom_minimum_size = Vector2(0, 40 + Settings.row_height() * maxi(players.size(), 1))
	UI.fit_rows(t)
	for p in players:
		var st := ""
		if p.injury_days > 0:
			st = "✚ %d" % p.injury_days
		elif p.suspension_matches > 0:
			st = "⊘ %d" % p.suspension_matches
		var sq := (T("ui.school.year") % Schools.school_year(p, w)) if p.squad == Player.Squad.SCHOOL else T("ui.squad." + p.squad)
		if p.is_on_loan():
			sq += " (%s)" % T("ui.loan_badge")
		var it := UI.row(t, [("★ " if p.is_captain else "") + p.name(), UI.pos_short(p.position), p.age(w.today), sq, _stars(p.ca()) if Game.knowledge_level(p) >= 1 else "?", st], p.id)
		UI.player_cell(it, 0, p.id)
		if lineup_ids.has(p.id):
			it.set_custom_font(0, ThemeBuilder.font("table_bold"))
		if not p.is_available():
			it.set_custom_color(0, ThemeBuilder.SEALING_WAX)
			it.set_custom_color(5, ThemeBuilder.SEALING_WAX)
			it.set_tooltip_text(5, UI.unavailable_text(p))
	t.item_activated.connect(func():
		var it := t.get_selected()
		if it != null and it.get_metadata(0) != null:
			go("player", {"player_id": str(it.get_metadata(0))}))
	body.add_child(UI.table_card(t))


func _stars(ca: float) -> String:
	var n := clampi(int(round(ca / 36.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)
