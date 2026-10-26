extends UIScreen
## National team ranking: every national team sorted by the strength of its best seven, with World Cups won
## (click one to open its page). Available in any mode (club, Hogwarts house or unemployed).

var body: VBoxContainer


func build() -> void:
	header(T("ui.explorer.national"))
	body = UI.vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := UI.scroll(body)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sc)


func refresh() -> void:
	clear(body)
	_national()


func _national() -> void:
	var w := Game.world
	var rows: Array = []
	for nt_id in w.national_team_ids_sorted():
		rows.append([nt_id, NationalTeams.strength(w, nt_id)])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	var t := UI.table([{"title": "#", "width": 46, "align": "right"}, {"title": T("ui.col.team"), "width": 240, "expand": true}, {"title": T("ui.col.ability"), "width": 90}, {"title": T("ui.explorer.wc_titles"), "width": 110, "align": "right"}], 600)
	var i := 0
	for r in rows:
		i += 1
		var nt: Dictionary = w.national_teams[r[0]]
		var it := UI.row(t, [i, w.team_name(r[0]), _stars(float(r[1])), int(nt.get("world_cup_titles", 0))], r[0])
		UI.team_cell(it, 1, str(r[0]))
		var fl := UI.image_for("flags", str(nt.get("country_id", "")))
		if fl != null:
			it.set_icon(1, fl)
			it.set_icon_max_width(1, 22)
	t.item_activated.connect(func():
		var it := t.get_selected()
		if it != null:
			go("national", {"nt_id": str(it.get_metadata(0))}))
	body.add_child(UI.table_card(t))


func _stars(ca: float) -> String:
	var n := clampi(int(round(ca / 36.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)
