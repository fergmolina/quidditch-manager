extends UIScreen
## Club calendar and results: match list or month grid (opponent, home/away, competition and
## colored result). The chosen view is remembered in world.settings.calendar_view.

var table: Tree
var tab := 0
var month_day := 0
var list_card: Control
var month_box: VBoxContainer


func build() -> void:
	header(T("ui.menu.calendar"), Game.my_club().name if Game.my_club() != null else "")
	tab = int(params.get("tab", Game.world.settings.get("calendar_view", 0)))
	month_day = Game.world.today
	root.add_child(UI.tabs([T("ui.calendar.list"), T("ui.calendar.month")], tab, func(i):
		tab = i
		Game.world.settings["calendar_view"] = i
		refresh()))
	month_box = UI.vbox(8)
	month_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(month_box)
	table = UI.table([
		{"title": T("ui.col.date"), "width": 160}, {"title": T("ui.col.competition"), "width": 120}, {"title": T("ui.col.home"), "width": 180, "expand": true},
		{"title": T("ui.col.result"), "width": 100, "align": "center"}, {"title": T("ui.col.away"), "width": 180, "expand": true},
		{"title": T("ui.col.venue"), "width": 130}, {"title": T("ui.col.duration"), "width": 80, "align": "right"}, {"title": T("ui.col.snitch"), "width": 140},
	], 440)
	list_card = UI.table_card(table)
	root.add_child(list_card)


func refresh() -> void:
	list_card.visible = tab == 0
	month_box.visible = tab == 1
	if tab == 1:
		_month()
		return
	table.clear()
	table.create_item()
	var all_fx := _my_fixtures()
	var w := Game.world
	var me := w.player_club_id
	var nt_id := str(w.manager.get("national_team_id", ""))
	for f in all_fx:
		var comp: Competition = f["_comp"]
		var played: bool = bool(f.get("played", false))
		var res := "%d – %d" % [int(f.get("score_home", 0)), int(f.get("score_away", 0))] if played else str(f.get("hour", ""))
		var dur := ""
		var snitch := ""
		if played:
			var s: int = int(f.get("duration_s", 0))
			dur = "%dh%02d" % [s / 3600, (s % 3600) / 60] if s >= 3600 else "%d'" % (s / 60)
			snitch = Game.club_name(str(f.get("snitch_team_id", ""))) if str(f.get("snitch_team_id", "")) != "" else T("ui.no_catch")
		var kind := comp.display_name() if comp.type != Competition.Type.LEAGUE else T("ui.round_short", {"n": int(f.get("round", 0))})
		var it := UI.row(table, [Game.date_text(int(f["day"])), kind, Game.club_name(f["home_id"]), res, Game.club_name(f["away_id"]), Game.venue_text(f), dur, snitch], f["id"])
		UI.team_cell(it, 2, str(f["home_id"]))
		UI.team_cell(it, 4, str(f["away_id"]))
		if played:
			UI.team_cell(it, 7, str(f.get("snitch_team_id", "")))
		if comp.type != Competition.Type.LEAGUE:
			it.set_custom_color(1, ThemeBuilder.BRONZE_TEXT)
		if played:
			var mine_home: bool = f["home_id"] == me or f["home_id"] == nt_id
			var mine: int = int(f["score_home"]) if mine_home else int(f["score_away"])
			var theirs: int = int(f["score_away"]) if mine_home else int(f["score_home"])
			it.set_custom_color(3, ThemeBuilder.GREEN if mine > theirs else (ThemeBuilder.SEALING_WAX if mine < theirs else ThemeBuilder.INK_SOFT))
		elif int(f["day"]) == w.today + 1 or int(f["day"]) == w.today:
			it.set_custom_color(0, ThemeBuilder.SEALING_WAX)


func _my_fixtures() -> Array:
	var w := Game.world
	var me := w.player_club_id
	var all_fx: Array = []
	var nt_id := str(w.manager.get("national_team_id", ""))
	for comp in w.competitions.values():
		for f in comp.fixtures:
			if f["home_id"] == me or f["away_id"] == me or (nt_id != "" and (f["home_id"] == nt_id or f["away_id"] == nt_id)):
				var fx: Dictionary = f.duplicate()
				fx["_comp"] = comp
				all_fx.append(fx)
	all_fx.sort_custom(func(a, b): return int(a["day"]) < int(b["day"]))
	return all_fx


func _month() -> void:
	clear(month_box)
	var w := Game.world
	var me := w.player_club_id
	var nt_id := str(w.manager.get("national_team_id", ""))
	var y := WDate.year(month_day)
	var m := WDate.month(month_day)
	var first := WDate.from_ymd(y, m, 1)
	var next_first := WDate.from_ymd(y + (1 if m == 12 else 0), 1 if m == 12 else m + 1, 1)
	var by_day := {}
	for f in _my_fixtures():
		var d := int(f["day"])
		if d >= first and d < next_first:
			by_day[d] = f
	var months := UI.month_names()
	var bar := UI.hbox(8)
	bar.add_child(UI.button("◂", func(): month_day = first - 1; _month()))
	var title := UI.text("Caption", T("ui.date_month_year", {"mon": months[m - 1], "m": m, "y": y}))
	title.custom_minimum_size = Vector2(200, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	bar.add_child(UI.button("▸", func(): month_day = next_first; _month()))
	bar.add_child(UI.spacer())
	bar.add_child(UI.button(T("ui.calendar.today"), func(): month_day = w.today; _month()))
	month_box.add_child(bar)
	var card := UI.panel(10)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var days := T("ui.weekdays").split(",")
	for i in 7:
		var hl := UI.text("Caption", days[(i + 1) % 7])
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(hl)
	var lead := (WDate.weekday(first) + 6) % 7
	for i in lead:
		grid.add_child(Control.new())
	for d in range(first, next_first):
		grid.add_child(_day_cell(d, by_day.get(d, {}), me, nt_id))
	card.add_child(grid)
	month_box.add_child(card)


func _day_cell(d: int, f: Dictionary, me: String, nt_id: String) -> Control:
	var w := Game.world
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(0, 92)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := ThemeBuilder.CARD if f.is_empty() else ThemeBuilder.ZEBRA
	var sb := ThemeBuilder.flat(bg, ThemeBuilder.SEALING_WAX if d == w.today else ThemeBuilder.BORDER, 2 if d == w.today else 1, 4, 6)
	cell.add_theme_stylebox_override("panel", sb)
	var v := UI.vbox(2)
	var dl := UI.text("TableBold" if d == w.today else "TableText", str(WDate.day_of_month(d)))
	dl.modulate = Color(1, 1, 1, 0.55) if d < w.today and f.is_empty() else Color.WHITE
	v.add_child(dl)
	if not f.is_empty():
		var comp: Competition = f["_comp"]
		var home: bool = f["home_id"] == me or f["home_id"] == nt_id
		var rival_id: String = str(f["away_id"] if home else f["home_id"])
		var h := UI.hbox(4)
		var rc: Club = w.club(rival_id)
		if rc != null:
			var cr := UI.crest(rc, 22)
			UI.make_team_clickable(cr, rival_id)
			h.add_child(cr)
		h.add_child(UI.text("Body", T("ui.calendar.home_short") if home else T("ui.calendar.away_short")))
		var rn := UI.text("Body", w.team_short(rival_id))
		rn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		rn.tooltip_text = w.team_name(rival_id)
		rn.mouse_filter = Control.MOUSE_FILTER_PASS
		UI.make_team_clickable(rn, rival_id)
		h.add_child(rn)
		v.add_child(h)
		var kind := comp.display_name() if comp.type != Competition.Type.LEAGUE else T("ui.round_short", {"n": int(f.get("round", 0))})
		var kl := UI.text("Meta", kind)
		kl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		kl.tooltip_text = kind
		kl.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(kl)
		if bool(f.get("played", false)):
			var mine: int = int(f["score_home"]) if home else int(f["score_away"])
			var theirs: int = int(f["score_away"]) if home else int(f["score_home"])
			var res := UI.text("TableBold", "%d – %d" % [mine, theirs])
			res.add_theme_color_override("font_color", ThemeBuilder.GREEN if mine > theirs else (ThemeBuilder.SEALING_WAX if mine < theirs else ThemeBuilder.INK_SOFT))
			v.add_child(res)
	cell.add_child(v)
	return cell
