extends UIScreen
## Competitions: every league (selector), European Cup and World Cup (groups and bracket).

var selector: OptionButton
var body: VBoxContainer
var selected_id := ""


func build() -> void:
	header(T("ui.menu.competitions"))
	var bar := UI.hbox()
	var groups := {"domestic": [], "continental": [], "international": [], "schools": []}
	var me := Game.my_club()
	var leagues: Array = Game.world.leagues().duplicate()
	var own: Competition = Game.world.competitions.get(me.league_id) if me != null else null
	if own != null and leagues.has(own):
		leagues.erase(own)
		leagues.push_front(own)
	for comp in leagues:
		groups["domestic"].append([comp.id, comp.display_name()])
	var others := Game.world.competitions.values().duplicate()
	others.sort_custom(func(a, b): return a.season > b.season if a.season != b.season else a.id < b.id)
	for comp in others:
		if comp.type != Competition.Type.LEAGUE:
			var cname: String = comp.display_name()
			if cname.find(str(comp.season)) < 0:
				cname += " · %d-%02d" % [comp.season, (comp.season + 1) % 100]
			groups[UI.competition_group(comp.id)].append([comp.id, cname])
	var items := []
	for g in ["domestic", "continental", "international", "schools"]:
		if groups[g].is_empty():
			continue
		items.append([null, T("ui.menu.schools") if g == "schools" else T("ui.comp_group." + g)])
		items.append_array(groups[g])
	var picks: Array = items.filter(func(x): return x[0] != null)
	selected_id = str(params.get("competition_id", me.league_id if me else (picks[0][0] if not picks.is_empty() else "")))
	if not Game.world.competitions.has(selected_id) and not picks.is_empty():
		selected_id = str(picks[0][0])
		if me != null and Game.world.is_school_mode():
			for it in picks:
				if str(it[0]).begins_with("comp_school_"):
					selected_id = str(it[0])
					break
	selector = UI.option(items, selected_id, func(v): selected_id = str(v); refresh(), 420)
	bar.add_child(selector)
	bar.add_child(UI.spacer())
	root.add_child(bar)
	body = UI.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(UI.scroll(body))


## Back from a club or a player returns to the competition that was open, not to the manager's league.
func nav_state() -> Dictionary:
	return {"competition_id": selected_id}


func refresh() -> void:
	clear(body)
	var comp: Competition = Game.world.competitions.get(selected_id)
	if comp == null:
		return
	if comp.type in [Competition.Type.WC_GROUPS, Competition.Type.WC_KNOCKOUT]:
		var art := UI.image_for("art", "world_cup")
		if art != null:
			var tr := TextureRect.new()
			tr.texture = art
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(0, 110)
			body.add_child(tr)
	match comp.type:
		"league", "school_cup":
			_league(comp)
		"wc_groups", "cont_groups":
			_groups(comp)
		"cup", "wc_knockout", "national_cup", "cont_knockout", "house_world":
			_bracket(comp)
		_:
			_all_fixtures(comp)


func _league(comp: Competition) -> void:
	var sub := "%s · %d-%02d" % [comp.display_name(), comp.season, (comp.season + 1) % 100]
	if comp.type == Competition.Type.LEAGUE:
		sub += " · %s %d" % [T("ui.level"), comp.level]
	body.add_child(UI.subtitle(sub))
	var champ := ""
	var st_all: Array = comp.standings()
	if not comp.fixtures.is_empty() and comp.is_finished() and not st_all.is_empty():
		champ = str(st_all[0]["club_id"])
		var mine := champ == Game.world.player_club_id
		var pl := _podium_line(("★ " if mine else "") + T("ui.cup.champion"), champ, "title", 22, ThemeBuilder.AMBER if mine else ThemeBuilder.BRONZE_DARK)
		body.add_child(pl)
	var t := UI.table([
		{"title": T("ui.col.pos"), "width": 44, "align": "right"}, {"title": T("ui.col.club"), "width": 220, "expand": true},
		{"title": T("ui.col.played"), "width": 40, "align": "right"}, {"title": T("ui.col.won"), "width": 36, "align": "right"}, {"title": T("ui.col.drawn"), "width": 36, "align": "right"}, {"title": T("ui.col.lost"), "width": 36, "align": "right"},
		{"title": T("ui.col.points"), "width": 90, "align": "right"}, {"title": T("ui.col.against"), "width": 90, "align": "right"}, {"title": T("ui.col.catches"), "width": 70, "align": "right"},
	], 48 + 32 * maxi(comp.club_ids.size(), 4))
	UI.fit_rows(t)
	var i := 0
	for row in st_all:
		i += 1
		var club: Club = Game.team_as_club(str(row["club_id"]))
		var it := UI.row(t, [("★ %d" % i) if club.id == champ else str(i), club.name, row["pj"], row["w"], row["d"], row["l"], row["pts"], row["against"], row["catches"]], club.id)
		UI.club_cell(it, 1, club)
		it.set_meta("sort_keys", {0: i})
		if club.id == champ:
			it.set_custom_color(0, ThemeBuilder.AMBER)
		if club.id == Game.world.player_club_id:
			for c in t.columns:
				it.set_custom_bg_color(c, ThemeBuilder.SELECTION.lerp(ThemeBuilder.CARD, 0.45))
	t.item_activated.connect(func(): var it := t.get_selected(); if it and Game.world.clubs.has(str(it.get_metadata(0))): go("club", {"club_id": str(it.get_metadata(0))}))
	body.add_child(UI.table_card(t))
	_league_stats(comp)


func _monthly_awards(comp: Competition) -> void:
	var w := Game.world
	var rows: Array = []
	for a in w.monthly_awards:
		if str(a.get("competition_id", "")) == comp.id:
			rows.append(a)
	if rows.is_empty():
		return
	body.add_child(UI.subtitle(T("ui.stats.monthly_awards")))
	var t := UI.table([{"title": T("ui.col.month"), "width": 110}, {"title": T("award.player_month"), "width": 220, "expand": true}, {"title": T("award.young_month"), "width": 220, "expand": true}, {"title": T("award.manager_month"), "width": 220, "expand": true}], 48 + 32 * 3)
	UI.fit_rows(t)
	var by_month := {}
	var order: Array = []
	for a in rows:
		var key := "%d-%02d" % [int(a["season"]), int(a["month"])]
		if not by_month.has(key):
			by_month[key] = {}
			order.append(key)
		by_month[key][str(a["kind"])] = a
	var mnames: PackedStringArray = UI.month_names()
	for key in order.slice(0, 3):
		var d: Dictionary = by_month[key]
		var vals := [mnames[int(str(key).split("-")[1]) - 1].strip_edges()]
		for k in ["player_month", "young_month"]:
			var a: Dictionary = d.get(k, {})
			vals.append("%s (%s) · %s" % [Game.player_name(str(a["player_id"])), Game.club_name(str(a.get("club_id", ""))), str(a.get("value", ""))] if not a.is_empty() else "—")
		var m: Dictionary = d.get("manager_month", {})
		vals.append("%s (%s)" % [str(m.get("manager", "")), Game.club_name(str(m.get("club_id", "")))] if not m.is_empty() else "—")
		var arow := UI.row(t, vals)
		var pm: Dictionary = d.get("player_month", {})
		var ym: Dictionary = d.get("young_month", {})
		UI.player_cell(arow, 1, str(pm.get("player_id", "")))
		UI.player_cell(arow, 2, str(ym.get("player_id", "")))
		UI.team_cell(arow, 3, str(m.get("club_id", "")))
		if not pm.is_empty():
			UI.link_underline(arow, 1, Game.player_name(str(pm["player_id"])))
		if not ym.is_empty():
			UI.link_underline(arow, 2, Game.player_name(str(ym["player_id"])))
	body.add_child(t)


func _league_stats(comp: Competition) -> void:
	_monthly_awards(comp)
	var w := Game.world
	var stats := {}
	var players: Array = []
	for cid in comp.club_ids:
		for p in w.club_players(str(cid)):
			var st: Dictionary = p.comp_stats.get(Player.comp_key(comp.season, comp.id), {})
			if int(st.get("apps", 0)) > 0:
				players.append(p)
				stats[p.id] = st
	if players.is_empty():
		return
	body.add_child(UI.subtitle(T("ui.stats.leaders")))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var most := 0
	for pid in stats:
		most = maxi(most, int(stats[pid].get("apps", 0)))
	var min_apps := clampi(most / 2, 1, 5)
	var boards := [["ui.stat.goals", func(st): return float(int(st.get("goals", 0))), "%d"], ["ui.col.catches", func(st): return float(int(st.get("catches", 0))), "%d"],
		["ui.stat.saves", func(st): return float(int(st.get("saves", 0))), "%d"], ["ui.stat.rating", func(st): return Awards.avg_rating(st) if int(st.get("apps", 0)) >= min_apps else 0.0, "%.2f"]]
	for b in boards:
		var p := UI.panel(8)
		var v := UI.vbox(2)
		v.add_child(UI.text("Caption", T(b[0])))
		var score: Callable = b[1]
		var sorted := players.duplicate()
		sorted.sort_custom(func(a, c): var sa: float = score.call(stats[a.id]); var sc: float = score.call(stats[c.id]); return sa > sc if sa != sc else a.id < c.id)
		for i in mini(5, sorted.size()):
			var q: Player = sorted[i]
			var val: float = score.call(stats[q.id])
			if val <= 0.0:
				break
			var h := UI.hbox(6)
			var nl := UI.link(q.name(), func(): go("player", {"player_id": q.id}))
			nl.clip_text = true
			nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nl.alignment = HORIZONTAL_ALIGNMENT_LEFT
			h.add_child(nl)
			var cl := UI.text("Meta", w.club(q.club_id).short_name if w.club(q.club_id) else "")
			UI.make_team_clickable(cl, q.club_id)
			h.add_child(cl)
			h.add_child(UI.text("TableBold", (str(b[2]) % val) if b[2] == "%d" else (str(b[2]) % val)))
			v.add_child(h)
		p.add_child(v)
		grid.add_child(p)
	body.add_child(grid)
	var longest := {"s": 0}
	var most_goals := {"g": -1}
	var biggest := {"d": -1}
	for c in w.competitions.values():
		if c.type != comp.type or c.region_id != comp.region_id or (comp.type != Competition.Type.LEAGUE and c.series() != comp.series()):
			continue
		for f in c.fixtures:
			if not bool(f.get("played", false)):
				continue
			var d := int(f.get("duration_s", 0))
			if d > int(longest["s"]):
				longest = {"s": d, "f": f}
			var g := int(f.get("score_home", 0)) + int(f.get("score_away", 0))
			if g > int(most_goals["g"]):
				most_goals = {"g": g, "f": f}
			var diff := absi(int(f.get("score_home", 0)) - int(f.get("score_away", 0)))
			if diff > int(biggest["d"]):
				biggest = {"d": diff, "f": f}
	if longest.has("f"):
		var rp := UI.panel(8)
		var rv := UI.vbox(2)
		rv.add_child(UI.text("Caption", T("ui.stats.records")))
		rv.add_child(_fx_line("ui.stats.longest", longest["f"], [int(longest["s"]) / 3600, (int(longest["s"]) % 3600) / 60]))
		rv.add_child(_fx_line("ui.stats.most_points", most_goals["f"], [int(most_goals["g"])]))
		rv.add_child(_fx_line("ui.stats.biggest", biggest["f"], [int(biggest["d"])]))
		rp.add_child(rv)
		body.add_child(rp)


func _fx_line(key: String, f: Dictionary, args: Array) -> Control:
	var tmpl := T(key)
	var at := tmpl.find("%s")
	if at < 0:
		return UI.text("Body", tmpl % ([_fx_text(f)] + args))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tmpl.left(at).strip_edges() != "":
		flow.add_child(UI.text("Body", tmpl.left(at).strip_edges()))
	var hid := str(f["home_id"])
	var aid := str(f["away_id"])
	var hl := UI.text("Body", Game.club_name(hid))
	UI.make_team_clickable(hl, hid)
	flow.add_child(hl)
	flow.add_child(UI.text("Body", "%d–%d" % [int(f.get("score_home", 0)), int(f.get("score_away", 0))]))
	var al := UI.text("Body", Game.club_name(aid))
	UI.make_team_clickable(al, aid)
	flow.add_child(al)
	flow.add_child(UI.text("Body", ("(%s)" % Game.date_text(int(f["day"]))) + (tmpl.substr(at + 2) % args)))
	return flow


func _fx_text(f: Dictionary) -> String:
	return "%s %d–%d %s (%s)" % [Game.club_name(str(f["home_id"])), int(f.get("score_home", 0)), int(f.get("score_away", 0)), Game.club_name(str(f["away_id"])), Game.date_text(int(f["day"]))]


func _groups(comp: Competition) -> void:
	body.add_child(UI.subtitle(comp.display_name()))
	body.add_child(UI.label(T("ui.cont.groups_note" if comp.type == Competition.Type.CONT_GROUPS else "ui.wc.groups_note"), "ui_italic", 13, ThemeBuilder.INK_SOFT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	var letters := comp.groups.keys()
	letters.sort()
	for letter in letters:
		var p := UI.panel(6)
		var v := UI.vbox(2)
		v.add_child(UI.label("%s %s" % [T("ui.wc.group"), letter], "title_sc", 15, ThemeBuilder.BRONZE_DARK))
		var t := UI.table([{"title": T("ui.col.team"), "width": 180, "expand": true}, {"title": T("ui.col.played"), "width": 34, "align": "right"}, {"title": T("ui.col.won"), "width": 30, "align": "right"}, {"title": T("ui.col.points"), "width": 50, "align": "right"}, {"title": T("ui.col.catches"), "width": 46, "align": "right"}], 156)
		UI.fit_rows(t)
		for row in comp.group_standings(letter):
			var it := UI.row(t, [Game.world.team_name(str(row["club_id"])), row["pj"], row["w"], row["pts"], row["catches"]], row["club_id"])
			var gc: Club = Game.world.club(str(row["club_id"]))
			if gc != null:
				UI.club_cell(it, 0, gc)
			else:
				UI.team_cell(it, 0, str(row["club_id"]))
		v.add_child(t)
		p.add_child(v)
		grid.add_child(p)
	body.add_child(grid)
	_fixtures_list(comp, 12)


func _bracket(comp: Competition) -> void:
	body.add_child(UI.subtitle(comp.display_name()))
	if comp.champion_id != "":
		body.add_child(_podium_line(T("ui.cup.champion"), comp.champion_id, "title", 22, ThemeBuilder.BRONZE_DARK))
	if comp.third_id != "":
		body.add_child(_podium_line(T("ui.cup.third"), comp.third_id, "ui_medium", 15, ThemeBuilder.INK))
	var stages := {}
	for f in comp.fixtures:
		var st := str(f.get("stage", "r%d" % int(f["round"])))
		if not stages.has(st):
			stages[st] = []
		stages[st].append(f)
	for st in ["r16", "qf", "sf", "third", "final"]:
		if not stages.has(st):
			continue
		body.add_child(UI.label(T("stage." + st), "title_sc", 16, ThemeBuilder.BRONZE_DARK))
		var t := UI.table([{"title": T("ui.col.date"), "width": 175}, {"title": T("ui.col.home"), "width": 200, "expand": true}, {"title": T("ui.col.result"), "width": 100, "align": "center"}, {"title": T("ui.col.away"), "width": 200, "expand": true}, {"title": T("ui.col.venue"), "width": 160}, {"title": T("ui.col.duration"), "width": 70, "align": "right"}], 48 + 32 * stages[st].size())
		UI.fit_rows(t)
		for f in stages[st]:
			var played: bool = bool(f.get("played", false))
			var res := ("%d – %d" % [int(f.get("score_home", 0)), int(f.get("score_away", 0))]) if played else str(f.get("hour", ""))
			if bool(f.get("is_replay", false)):
				res += " (R)"
			var s: int = int(f.get("duration_s", 0))
			var dur := ("%dh%02d" % [s / 3600, (s % 3600) / 60] if s >= 3600 else "%d'" % (s / 60)) if played else ""
			var frow := UI.row(t, [Game.date_text(int(f["day"])), Game.world.team_name(str(f["home_id"])), res, Game.world.team_name(str(f["away_id"])), Game.venue_text(f), dur], f["id"])
			UI.team_cell(frow, 1, str(f["home_id"]))
			UI.team_cell(frow, 3, str(f["away_id"]))
		body.add_child(UI.table_card(t))


func _podium_line(caption: String, team_id: String, font_name: String, size: int, color: Color) -> Control:
	var h := UI.hbox(6)
	h.add_child(UI.label(caption + ":", font_name, size, color))
	var tl := UI.label(Game.world.team_name(team_id), font_name, size, color)
	UI.make_team_clickable(tl, team_id)
	h.add_child(tl)
	return h


func _all_fixtures(comp: Competition) -> void:
	var sub := comp.display_name()
	if sub.find(str(comp.season)) < 0:
		sub += " · %d-%02d" % [comp.season, (comp.season + 1) % 100]
	body.add_child(UI.subtitle(sub))
	var fx: Array = comp.fixtures.duplicate()
	fx.sort_custom(func(a, b): return int(a["day"]) < int(b["day"]))
	var t := UI.table([{"title": T("ui.col.date"), "width": 175}, {"title": T("ui.col.home"), "width": 200, "expand": true}, {"title": T("ui.col.result"), "width": 100, "align": "center"}, {"title": T("ui.col.away"), "width": 200, "expand": true}, {"title": T("ui.col.venue"), "width": 160}], 48 + 32 * maxi(fx.size(), 1))
	UI.fit_rows(t)
	for f in fx:
		var played: bool = bool(f.get("played", false))
		var res := ("%d – %d" % [int(f.get("score_home", 0)), int(f.get("score_away", 0))]) if played else str(f.get("hour", ""))
		var frow := UI.row(t, [Game.date_text(int(f["day"])), Game.world.team_name(str(f["home_id"])), res, Game.world.team_name(str(f["away_id"])), Game.venue_text(f)], f["id"])
		UI.team_cell(frow, 1, str(f["home_id"]))
		UI.team_cell(frow, 3, str(f["away_id"]))
	body.add_child(UI.table_card(t))


func _fixtures_list(comp: Competition, n: int) -> void:
	body.add_child(UI.label(T("ui.wc.recent"), "title_sc", 16, ThemeBuilder.BRONZE_DARK))
	var played := []
	for f in comp.fixtures:
		if bool(f.get("played", false)):
			played.append(f)
	played.sort_custom(func(a, b): return int(a["day"]) > int(b["day"]))
	var t := UI.table([{"title": T("ui.col.date"), "width": 175}, {"title": T("ui.col.home"), "width": 180, "expand": true}, {"title": T("ui.col.result"), "width": 90, "align": "center"}, {"title": T("ui.col.away"), "width": 180, "expand": true}, {"title": T("ui.wc.group"), "width": 50, "align": "center"}], 60 + 24 * mini(n, played.size()))
	UI.fit_rows(t)
	for f in played.slice(0, n):
		var grow := UI.row(t, [Game.date_text(int(f["day"])), Game.world.team_name(str(f["home_id"])), "%d – %d" % [int(f["score_home"]), int(f["score_away"])], Game.world.team_name(str(f["away_id"])), str(f.get("group", ""))], f["id"])
		UI.team_cell(grow, 1, str(f["home_id"]))
		UI.team_cell(grow, 3, str(f["away_id"]))
	body.add_child(UI.table_card(t))
