extends UIScreen
## Squad: dense table with heat map, grouped by position, side preview.

const VIEWS := {
	"general": ["speed", "agility", "passing", "shooting", "keeping", "beating", "snitch_catching", "decisions", "stamina"],
	"flying": ["speed", "acceleration", "agility", "broom_control", "balance", "altitude", "dive"],
	"technical": ["passing", "catching", "shooting", "dodging", "stealing", "interception", "keeping", "beating", "beat_accuracy", "snitch_catching"],
	"mental": ["aggression", "anticipation", "bravery", "composure", "concentration", "creativity", "decisions", "determination", "flair", "influence", "off_ball", "positioning", "teamwork", "work_rate"],
	"physical": ["stamina", "strength", "natural_fitness", "reflexes", "eyesight"],
	"contracts": [],
}
const KEY_ATTRS := {
	"K": ["keeping", "reflexes", "positioning", "anticipation"],
	"C": ["passing", "catching", "shooting", "dodging", "speed"],
	"B": ["beating", "beat_accuracy", "strength", "balance"],
	"S": ["eyesight", "snitch_catching", "speed", "acceleration", "agility"],
}

var table: Tree
var table_box: VBoxContainer
var preview: VBoxContainer
var view := "general"
var filter := "all"
var club_id := ""
var selected_pid := ""


func build() -> void:
	club_id = str(params.get("club_id", Game.world.player_club_id))
	selected_pid = str(params.get("player_id", ""))
	var club: Club = Game.world.team_club(club_id)
	if club == null:
		header(T("ui.menu.squad"), "")
		return
	var squad := Game.world.squad_of(club_id)
	var injured := 0
	var away := 0
	for p in squad:
		if p.injury_days > 0:
			injured += 1
		elif p.on_duty():
			away += 1
	header(club.name if club_id != Game.world.player_club_id else T("ui.menu.squad"), (T("ui.squad.count") % squad.size()) + ((" · " + T("ui.squad.injured_n") % injured) if injured > 0 else "") + ((" · " + T("ui.squad.on_duty_n") % away) if away > 0 else ""))
	if club_id != Game.world.player_club_id:
		UI.make_team_clickable(root.get_child(0).get_child(0), club_id)
	var bar := UI.hbox(10)
	if not Schools.is_house(club_id):
		bar.add_child(UI.tabs([T("ui.filter.all"), T("ui.filter.first"), T("ui.filter.reserve"), T("ui.filter.youth")], 0, func(i): filter = ["all", "first", "reserve", "youth"][i]; refresh()))
	bar.add_child(UI.spacer())
	bar.add_child(UI.text("Meta", T("ui.squad.view")))
	bar.add_child(UI.tabs([T("ui.view.general"), T("ui.attr_group.flying"), T("ui.attr_group.technical"), T("ui.attr_group.mental"), T("ui.attr_group.physical"), T("ui.view.contracts")], 0, func(i): view = ["general", "flying", "technical", "mental", "physical", "contracts"][i]; _rebuild()))
	root.add_child(bar)
	var cols := UI.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var tp := UI.panel(8)
	tp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_box = UI.vbox(0)
	tp.add_child(table_box)
	cols.add_child(tp)
	var pp := UI.panel(16)
	pp.custom_minimum_size = Vector2(280, 0)
	pp.size_flags_horizontal = Control.SIZE_SHRINK_END
	pp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview = UI.vbox(6)
	pp.add_child(preview)
	cols.add_child(pp)
	_rebuild()


func _rebuild() -> void:
	clear(table_box)
	var cols := [
		{"title": T("ui.col.name"), "width": 120, "expand": true}, {"title": T("ui.col.pos"), "width": 34, "align": "center"},
		{"title": T("ui.col.age"), "width": 34, "align": "right"}, {"title": T("ui.col.cond"), "width": 44, "align": "right", "tooltip": T("ui.col.cond_tip")}, {"title": T("ui.col.form"), "width": 44, "align": "center"},
	]
	for k in VIEWS[view]:
		cols.append({"title": T("attr.short." + k), "width": 32, "align": "center", "tooltip": T("attr." + k)})
	if view == "contracts":
		cols.append({"title": T("ui.contract.role"), "width": 100})
		cols.append({"title": T("ui.contract_until"), "width": 80, "align": "right"})
		cols.append({"title": T("ui.col.mood"), "width": 170})
	cols.append({"title": T("ui.col.broom"), "width": 135})
	if Schools.is_house(club_id):
		cols.append({"title": T("ui.col.year"), "width": 70, "align": "right"})
		cols.append({"title": "", "width": 10})
	else:
		cols.append({"title": T("ui.col.wage"), "width": 52, "align": "right"})
		cols.append({"title": T("ui.col.value"), "width": 58, "align": "right"})
	table = UI.table(cols, 300)
	table.item_activated.connect(_open_player)
	table.item_selected.connect(_on_selected)
	table_box.add_child(table)
	refresh()


func refresh() -> void:
	if table == null:
		return
	var w := Game.world
	var club: Club = w.team_club(club_id)
	if club == null:
		return
	table.clear()
	table.create_item()
	var lineup_ids: Array = []
	if not club.lineup.is_empty():
		lineup_ids = [club.lineup.get("K", "")] + club.lineup.get("C", []) + club.lineup.get("B", []) + [club.lineup.get("S", "")]
	var squads: Array = ["first", "reserve", "youth"] if filter == "all" else [filter]
	var players := w.squad_of(club_id, squads)
	var order := {"K": 0, "C": 1, "B": 2, "S": 3}
	players.sort_custom(func(a, b): return order[a.position] < order[b.position] if a.position != b.position else a.ca() > b.ca())
	var last_pos := ""
	var counts := {"K": 0, "C": 0, "B": 0, "S": 0}
	for p in players:
		counts[p.position] += 1
	var loaned: Array = _loaned_out(club_id) if filter == "all" and not Schools.is_house(club_id) else []
	var rows: Array = []
	rows.append_array(players)
	rows.append_array(loaned)
	for p: Player in rows:
		var out_on_loan := loaned.has(p)
		var group := "loaned_out" if out_on_loan else p.position
		if group != last_pos:
			last_pos = group
			UI.group_row(table, "%s · %d" % [T("ui.squad.loaned_out"), loaned.size()] if out_on_loan else "%s · %d" % [T("pos." + p.position), counts[p.position]])
		var marker := "★ " if p.is_captain else ""
		var status := ""
		if p.injury_days > 0:
			status = "  ✚ %d" % p.injury_days
		elif p.suspension_matches > 0:
			status = "  ⊘"
		elif p.on_duty():
			status = "  ✈ %d" % p.duty_days
		if out_on_loan:
			status += "  (→ %s)" % Game.club_name(p.club_id)
		elif p.is_on_loan():
			status += "  (%s)" % T("ui.loan_badge")
		var vals: Array = [marker + p.name() + status, UI.pos_short(p.position), p.age(w.today), "%d" % int(p.condition), ""]
		for k in VIEWS[view]:
			vals.append("")
		if view == "contracts":
			var role := str(p.contract.get("role", "rotation"))
			vals.append(T("role." + role) if tr("role." + role) != "role." + role else role)
			var ends := int(p.contract.get("end_day", 0))
			vals.append(str(WDate.year(ends)) if ends > 0 else "—")
			var worry := Happiness.main_worry(p)
			vals.append(T("ui.happiness.worried") % T("ui.happiness." + worry) if worry != "" else T("ui.happiness.content"))
		var bname := str(Game.loader.brooms.get(str(p.broom.get("model_id", "")), {}).get("model", "?"))
		var broom_col := vals.size()
		vals.append(bname)
		if p.squad == Player.Squad.SCHOOL:
			vals.append(T("ui.school.year") % Schools.school_year(p, w))
			vals.append("")
		else:
			vals.append(Game.galleons(int(p.contract.get("wage_weekly", 0))))
			vals.append(Game.galleons(p.market_value(w.today)) if Game.knowledge_level(p) >= 1 else "?")
		var it := UI.row(table, vals, p.id)
		UI.player_cell(it, 0, p.id)
		it.set_tooltip_text(broom_col, bname)
		if p.injury_days > 0:
			it.set_custom_color(0, ThemeBuilder.SEALING_WAX)
		elif p.transfer_listed or p.loan_listed:
			it.set_custom_color(0, ThemeBuilder.BLUE)
		if lineup_ids.has(p.id):
			it.set_custom_font(0, ThemeBuilder.font("table_bold"))
		it.set_custom_color(3, ThemeBuilder.bar_color(p.condition))
		it.set_text(4, UI.form_dots(p.form) if not p.form.is_empty() else "—")
		it.set_custom_color(4, ThemeBuilder.INK_SOFT)
		var lvl := Game.knowledge_level(p)
		var c0 := 5
		for i in VIEWS[view].size():
			var k: String = VIEWS[view][i]
			UI.attr_cell(it, c0 + i, float(p.attrs.get(k, 8.0)), lvl, Game.attr_text(p, k))
		if selected_pid == p.id:
			it.select(0)
	if selected_pid == "" and not players.is_empty():
		selected_pid = players[0].id
	_show_preview()


func _loaned_out(owner_id: String) -> Array:
	var out: Array = []
	for p in Game.world.players.values():
		if p.is_on_loan() and p.loan.owner_id == owner_id:
			out.append(p)
	var order := {"K": 0, "C": 1, "B": 2, "S": 3}
	out.sort_custom(func(a, b): return order[a.position] < order[b.position] if a.position != b.position else (a.ca() > b.ca() if a.ca() != b.ca() else a.id < b.id))
	return out


func _on_selected() -> void:
	var it := table.get_selected()
	if it == null or it.get_metadata(0) == null:
		return
	selected_pid = str(it.get_metadata(0))
	_show_preview()


func _show_preview() -> void:
	clear(preview)
	var p: Player = Game.world.player(selected_pid)
	if p == null:
		preview.add_child(UI.text("Meta", T("ui.squad.preview")))
		return
	var w := Game.world
	var club: Club = w.club(p.club_id)
	var top := UI.hbox(10)
	top.add_child(UI.portrait(p, club, 56))
	var tv := UI.vbox(0)
	var name_lbl := UI.h2(p.name())
	name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UI.make_player_clickable(name_lbl, p.id)
	tv.add_child(name_lbl)
	tv.add_child(UI.meta("%s · %d %s · %s" % [T("pos." + p.position), p.age(w.today), T("ui.age_word"), T("ui.squad." + p.squad)]))
	top.add_child(tv)
	preview.add_child(top)
	preview.add_child(UI.gap(4))
	preview.add_child(UI.subtitle(T("ui.key_attributes")))
	var lvl := Game.knowledge_level(p)
	for k in KEY_ATTRS.get(p.position, []):
		var h := UI.hbox(6)
		var l := UI.text("Body", T("attr." + k))
		l.custom_minimum_size = Vector2(90, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.tooltip_text = T("attr." + k)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(l)
		var v := float(p.attrs.get(k, 8.0))
		if lvl == 2:
			var st := ThemeBuilder.attr_style(v)
			h.add_child(UI.bar(v * 5.0, 70, false, st["bg"] if v >= 11.0 else ThemeBuilder.BRONZE_TEXT))
			var nl := UI.text("TableBold", str(int(v)))
			nl.custom_minimum_size = Vector2(24, 0)
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.add_child(nl)
		else:
			h.add_child(UI.spacer())
			h.add_child(UI.text("MetaItalic", Game.attr_text(p, k)))
		preview.add_child(h)
	preview.add_child(UI.gap(4))
	preview.add_child(UI.subtitle(T("ui.status")))
	var ch := UI.hbox(6)
	ch.add_child(UI.text("Body", T("ui.col.cond")))
	ch.add_child(UI.spacer())
	ch.add_child(UI.bar(p.condition, 90, true))
	preview.add_child(ch)
	preview.add_child(UI.text("Body", T("ui.label_value") % [T("ui.col.morale"), T(UI.morale_key(p.morale))]))
	var fh := UI.hbox(6)
	fh.add_child(UI.text("Body", T("ui.col.form")))
	fh.add_child(UI.spacer())
	fh.add_child(UI.form_boxes(p.form))
	preview.add_child(fh)
	if p.injury_days > 0:
		preview.add_child(UI.text("BodyMedium", T("ui.injured_days") % p.injury_days, ThemeBuilder.SEALING_WAX))
	elif p.on_duty():
		preview.add_child(UI.text("BodyMedium", T("ui.on_duty") % [Game.world.team_name(p.duty_team), p.duty_days], ThemeBuilder.SEALING_WAX))
	preview.add_child(UI.gap(4))
	if p.squad == Player.Squad.SCHOOL:
		preview.add_child(UI.subtitle(T("ui.school.student")))
		preview.add_child(UI.text("Body", "%s · %s" % [T("ui.school.year") % Schools.school_year(p, w), T("ui.school.graduates_at")]))
	else:
		preview.add_child(UI.subtitle(T("ui.contract")))
		var cl := UI.text("Body", "%s / %s · %s %s" % [Game.galleons(int(p.contract.get("wage_weekly", 0))), T("ui.week"), T("ui.until"), Game.date_text(int(p.contract.get("end_day", 0)))])
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview.add_child(cl)
		preview.add_child(UI.text("Body", T("ui.label_value") % [T("ui.col.value"), Game.galleons(p.market_value(w.today)) if lvl >= 1 else "?"]))
	preview.add_child(UI.spacer(false))
	var bh := UI.hbox(8)
	bh.add_child(UI.primary(T("ui.view_profile"), func(): go("player", {"player_id": p.id})))
	preview.add_child(bh)


func _open_player() -> void:
	var it := table.get_selected()
	if it != null and it.get_metadata(0) != null:
		go("player", {"player_id": str(it.get_metadata(0))})
