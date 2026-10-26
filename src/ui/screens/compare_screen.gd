extends UIScreen
## Compare two players: attributes side by side with the difference colored (whatever the scouts don't know
## shows as «?»), basic info, value, wage and season stats.

const PlayerScreen := preload("res://src/ui/screens/player_screen.gd")

var a: Player
var b: Player
var body: VBoxContainer


func build() -> void:
	a = Game.world.player(str(params.get("a", "")))
	b = Game.world.player(str(params.get("b", "")))
	header(T("ui.compare.title"), "%s · %s" % [a.name() if a else "?", b.name() if b else "?"])
	body = UI.vbox(10)
	root.add_child(UI.scroll(body))


func refresh() -> void:
	clear(body)
	if a == null or b == null:
		body.add_child(UI.text("MetaItalic", T("ui.compare.missing")))
		return
	var w := Game.world
	var la: int = Game.knowledge_level(a)
	var lb: int = Game.knowledge_level(b)
	var names := UI.hbox(8)
	names.add_child(UI.player_link(a.id, a.name()))
	names.add_child(UI.text("Meta", "·"))
	names.add_child(UI.player_link(b.id, b.name()))
	body.add_child(names)
	var t := UI.table([{"title": "", "width": 200, "expand": true}, {"title": a.name(), "width": 160, "align": "right"}, {"title": b.name(), "width": 160, "align": "right"}, {"title": "±", "width": 70, "align": "right"}], 48 + 32 * 50)
	var basics := [
		[T("ui.col.club"), Game.club_name(a.club_id) if a.club_id != "" else T("ui.squad.free"), Game.club_name(b.club_id) if b.club_id != "" else T("ui.squad.free"), ""],
		[T("ui.col.pos"), T("pos." + a.position), T("pos." + b.position), ""],
		[T("ui.col.age"), str(a.age(w.today)), str(b.age(w.today)), ""],
		[T("ui.col.value"), Game.galleons(a.market_value(w.today)), Game.galleons(b.market_value(w.today)), ""],
		[T("ui.col.wage"), str(int(a.contract.get("wage_weekly", 0))), str(int(b.contract.get("wage_weekly", 0))), ""],
		[T("ui.col.ability"), _stars(a.ca()) if la >= 1 else "?", _stars(b.ca()) if lb >= 1 else "?", ""],
		[T("ui.col.potential"), _stars(a.pa) if la >= 2 else "?", _stars(b.pa) if lb >= 2 else "?", ""],
	]
	var sa: Dictionary = a.stats_for(w.season)
	var sb: Dictionary = b.stats_for(w.season)
	for k in [["ui.stat.apps", "apps"], ["ui.stat.goals", "goals"], ["ui.col.catches", "catches"], ["ui.stat.saves", "saves"]]:
		basics.append([T(k[0]), str(int(sa.get(k[1], 0))), str(int(sb.get(k[1], 0))), ""])
	for i in basics.size():
		var brow := UI.row(t, basics[i])
		if i == 0:
			UI.team_cell(brow, 1, a.club_id)
			UI.team_cell(brow, 2, b.club_id)
	for g in PlayerScreen.GROUPS.keys():
		var hi := UI.row(t, [T("ui.attr_group." + g), "", "", ""])
		hi.set_custom_font(0, ThemeBuilder.font("table_bold"))
		for k in PlayerScreen.GROUPS[g]:
			var va := int(round(float(a.attrs.get(k, 0)))) if la >= 2 else -1
			var vb := int(round(float(b.attrs.get(k, 0)))) if lb >= 2 else -1
			var d := (vb - va) if va >= 0 and vb >= 0 else 0
			var it := UI.row(t, ["   " + T("attr." + k), str(va) if va >= 0 else "?", str(vb) if vb >= 0 else "?", ("%+d" % d) if d != 0 else ""])
			if d != 0:
				it.set_custom_color(3, ThemeBuilder.GREEN if d > 0 else ThemeBuilder.SEALING_WAX)
				it.set_custom_color(1 if d < 0 else 2, ThemeBuilder.GREEN)
	body.add_child(UI.table_card(t))
	body.add_child(UI.text("MetaItalic", T("ui.compare.note")))


func _stars(ca: float) -> String:
	var n := clampi(int(round(ca / 36.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)
