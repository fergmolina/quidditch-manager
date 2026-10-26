extends UIScreen
## League table by accumulated points scored.

var table: Tree
var note: RichTextLabel


func build() -> void:
	var comp := Game.league()
	if comp == null:
		header(T("ui.menu.table"), "")
		var np := UI.panel(8)
		np.add_child(UI.rich(T("ui.table.no_competition")))
		root.add_child(np)
		return
	header(comp.display_name(), "%d-%02d" % [comp.season, (comp.season + 1) % 100])
	table = UI.table([
		{"title": T("ui.col.pos"), "width": 44, "align": "right"}, {"title": T("ui.col.club"), "width": 220, "expand": true},
		{"title": T("ui.col.played"), "width": 40, "align": "right"}, {"title": T("ui.col.won"), "width": 36, "align": "right"}, {"title": T("ui.col.drawn"), "width": 36, "align": "right"}, {"title": T("ui.col.lost"), "width": 36, "align": "right"},
		{"title": T("ui.col.points"), "width": 90, "align": "right"}, {"title": T("ui.col.against"), "width": 90, "align": "right"}, {"title": T("ui.col.catches"), "width": 70, "align": "right"}, {"title": T("ui.col.form"), "width": 70},
	], 420)
	table.item_activated.connect(_open_club)
	root.add_child(UI.table_card(table))
	var np := UI.panel(8)
	note = UI.rich(T("ui.table.note"))
	np.add_child(note)
	root.add_child(np)


func refresh() -> void:
	if table == null:
		return
	table.clear()
	table.create_item()
	var comp := Game.league()
	var i := 0
	for row in comp.standings():
		i += 1
		var club: Club = Game.team_as_club(str(row["club_id"]))
		var form: Array = row["form"]
		var it := UI.row(table, [i, club.name, row["pj"], row["w"], row["d"], row["l"], row["pts"], row["against"], row["catches"], UI.form_dots_from_results(form) if not form.is_empty() else "—"], club.id)
		UI.club_cell(it, 1, club)
		it.set_custom_font(6, ThemeBuilder.font("table_bold"))
		it.set_custom_color(9, ThemeBuilder.INK_SOFT)
		if club.id == Game.world.player_club_id:
			it.set_custom_font(1, ThemeBuilder.font("table_bold"))
			for c in table.columns:
				it.set_custom_bg_color(c, ThemeBuilder.SELECTION.lerp(ThemeBuilder.CARD, 0.45))


func _open_club() -> void:
	var it := table.get_selected()
	if it != null and Game.world.clubs.has(str(it.get_metadata(0))):
		go("club", {"club_id": str(it.get_metadata(0))})
	elif it != null and Schools.is_house(str(it.get_metadata(0))):
		go("schools")
