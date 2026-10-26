extends UIScreen
## Lineup and tactics: 7 positions with dropdowns, sliders and canon instructions.
## Reached as "lineup" {club_id} for a club or house and as "national_tactics" {nt_id} for the national team the
## manager runs.

const COL_NAME := 1

var club: Club
var slots_box: VBoxContainer
var pitch: PitchView
var tactics_box: VBoxContainer
var tactics_panel: PanelContainer
var tactics_btn: Button
var assistant: RichTextLabel
var host: VBoxContainer
var editable := true
var squad_table: Tree
var hint_label: Label
var sel_pid := ""
var sel_slot := -1
var is_nt := false
var nt: Dictionary = {}
var _name_press := ""
var _name_press_pos := Vector2.ZERO


func build() -> void:
	var w := Game.world
	if params.has("nt_id"):
		is_nt = true
		nt = w.national_teams.get(str(params["nt_id"]), {})
		if nt.is_empty():
			header(T("ui.menu.national"), "")
			return
		editable = str(w.manager.get("national_team_id", "")) == str(nt["id"])
		var lineup: Dictionary = nt.get("lineup", {})
		var tactics: Dictionary = nt.get("tactics", {})
		if lineup.is_empty():
			lineup = NationalTeams.pick_squad(w, nt)
		if tactics.is_empty():
			tactics = SimTactics.defaults()
		if editable:
			nt["lineup"] = lineup
			nt["tactics"] = tactics
		club = Club.new()
		club.id = str(nt["id"])
		club.name = w.team_name(club.id)
		club.short_name = club.name
		club.colors = nt.get("colors", {"primary": "#888888", "secondary": "#dddddd"})
		club.lineup = lineup
		club.tactics = tactics
		header(T("ui.menu.national"), club.name)
	else:
		club = w.team_club(str(params.get("club_id", w.player_club_id)))
		if club == null:
			header(T("ui.menu.lineup"), "")
			return
		editable = club.id == w.player_club_id
		header(T("ui.menu.lineup"), club.name)
	var hb: Node = root.get_child(0)
	if hb.get_child_count() >= 3 and hb.get_child(2) is Label:
		UI.make_team_clickable(hb.get_child(2), club.id)
	host = root
	if is_nt:
		host = UI.vbox(12)
		host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sc := UI.scroll(host)
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(sc)
	var cols := UI.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_child(cols)
	var lp := UI.panel(8)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.25
	var lv := UI.vbox(6)
	var lh := UI.hbox(8)
	lh.add_child(UI.subtitle(T("ui.lineup.squad")))
	hint_label = UI.text("MetaItalic", T("ui.lineup.hint_dnd"))
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(160, 0)
	hint_label.tooltip_text = T("ui.lineup.hint_dnd")
	hint_label.mouse_filter = Control.MOUSE_FILTER_PASS
	lh.add_child(hint_label)
	lv.add_child(lh)
	squad_table = UI.table([
		{"title": T("ui.lineup.col_slot"), "width": 40, "align": "center"}, {"title": T("ui.col.name"), "width": 150, "expand": true},
		{"title": T("ui.col.pos"), "width": 36, "align": "center"}, {"title": T("ui.col.age"), "width": 36, "align": "right"},
		{"title": T("ui.col.cond"), "width": 48, "align": "right"}, {"title": T("ui.col.morale"), "width": 62},
		{"title": T("ui.col.ability"), "width": 72}, {"title": "", "width": 64, "align": "right"},
	], 380)
	squad_table.scroll_horizontal_enabled = true
	squad_table.item_selected.connect(_on_row_selected)
	squad_table.item_activated.connect(_on_row_activated)
	# Runs before the Tree's own handling (Control emits gui_input first): presses on a name are taken here.
	squad_table.gui_input.connect(_on_squad_input)
	squad_table.set_drag_forwarding(_squad_drag_data, _squad_can_drop, _squad_drop)
	lv.add_child(squad_table)
	slots_box = UI.vbox(4)
	lv.add_child(slots_box)
	lp.add_child(lv)
	cols.add_child(lp)
	var mp := UI.panel(8)
	mp.custom_minimum_size = Vector2(290, 0)
	mp.size_flags_horizontal = Control.SIZE_FILL
	mp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mv := UI.vbox(6)
	tactics_btn = UI.button(T("ui.lineup.show_tactics"), _toggle_tactics)
	tactics_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	mv.add_child(tactics_btn)
	pitch = PitchView.new()
	pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pitch.swap_requested.connect(_swap_slots)
	pitch.slot_pressed.connect(_on_slot_pressed)
	pitch.player_dropped.connect(_on_player_dropped)
	pitch.accept_drops = editable
	mv.add_child(pitch)
	mp.add_child(mv)
	cols.add_child(mp)
	var tp := UI.panel(10)
	tactics_panel = tp
	tp.visible = false
	tp.custom_minimum_size = Vector2(340, 0)
	tp.size_flags_horizontal = Control.SIZE_FILL
	tp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tactics_box = UI.vbox(6)
	tactics_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tsc := UI.scroll(tactics_box)
	tsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tp.add_child(tsc)
	cols.add_child(tp)
	var ap := UI.panel(8)
	assistant = UI.rich("")
	assistant.custom_minimum_size = Vector2(0, 70)
	ap.add_child(assistant)
	host.add_child(ap)
	if is_nt:
		_national_context(w)


func _toggle_tactics() -> void:
	tactics_panel.visible = not tactics_panel.visible
	tactics_btn.text = T("ui.lineup.hide_tactics") if tactics_panel.visible else T("ui.lineup.show_tactics")


func _national_context(w: World) -> void:
	var nt: Dictionary = w.national_teams[club.id]
	var row := UI.hbox(14)
	var nf := {}
	var ncomp: Competition = null
	for comp in w.competitions.values():
		if not comp.club_ids.has(club.id):
			continue
		var f: Dictionary = comp.next_fixture_of(club.id, w.today)
		if not f.is_empty() and (nf.is_empty() or int(f["day"]) < int(nf["day"])):
			nf = f
			ncomp = comp
	var np := UI.panel(10)
	var nv := UI.vbox(2)
	nv.add_child(UI.text("Caption", T("ui.menu.next_match")))
	if nf.is_empty():
		nv.add_child(UI.text("MetaItalic", T("ui.no_match")))
	else:
		var rival: String = str(nf["away_id"]) if str(nf["home_id"]) == club.id else str(nf["home_id"])
		var rh := UI.hbox(6)
		rh.add_child(UI.flag(str(w.national_teams.get(rival, {}).get("country_id", "")), 18))
		rh.add_child(UI.link(w.team_name(rival), func(): go("national", {"nt_id": rival})))
		nv.add_child(rh)
		nv.add_child(UI.meta("%s · %s · %s" % [ncomp.display_name(), Game.date_text(int(nf["day"])), Game.venue_text(nf)]))
		nv.add_child(UI.link(T("ui.menu.competitions") + " ▸", func(): go("competitions", {"competition_id": ncomp.id})))
	np.add_child(nv)
	row.add_child(np)
	for comp in w.competitions.values():
		if comp.type != Competition.Type.WC_GROUPS or not comp.club_ids.has(club.id):
			continue
		for g in comp.groups.keys():
			if not comp.groups[g].has(club.id):
				continue
			var gp := UI.panel(10)
			var gv := UI.vbox(2)
			gv.add_child(UI.text("Caption", "%s · %s %s" % [comp.display_name(), T("ui.wc.group"), g]))
			var t := UI.table([{"title": T("ui.col.team"), "width": 160, "expand": true}, {"title": T("ui.col.played"), "width": 36, "align": "right"}, {"title": T("ui.col.points"), "width": 60, "align": "right"}], 40 + 30 * comp.groups[g].size())
			for r in comp.standings(comp.groups[g]):
				var it := UI.row(t, [w.team_name(str(r["club_id"])), int(r["pj"]), int(r["pts"])], str(r["club_id"]))
				UI.team_cell(it, 0, str(r["club_id"]))
				if str(r["club_id"]) == club.id:
					it.set_custom_font(0, ThemeBuilder.font("table_bold"))
			gv.add_child(t)
			gp.add_child(gv)
			row.add_child(gp)
	host.add_child(row)
	var pool := w.players_of_nationality(str(nt["country_id"]))
	var pp := UI.panel(10)
	var pv := UI.vbox(4)
	pv.add_child(UI.text("Caption", "%s · %d" % [T("ui.nt.pool"), pool.size()]))
	var t := UI.table([{"title": T("ui.col.name"), "width": 170, "expand": true}, {"title": T("ui.col.pos"), "width": 40}, {"title": T("ui.col.age"), "width": 44, "align": "right"}, {"title": T("ui.col.club"), "width": 170}, {"title": T("ui.col.ability"), "width": 90}, {"title": T("ui.col.cond"), "width": 60, "align": "right"}], 260)
	var ids: Array = [club.lineup.get("K", "")] + club.lineup.get("C", []) + club.lineup.get("B", []) + [club.lineup.get("S", "")]
	for p in pool.slice(0, 40):
		var club_name := w.team_name(p.club_id) if p.club_id != "" else (T("ui.squad.abroad") if p.squad == Player.Squad.ABROAD else T("ui.squad.free"))
		var it := UI.row(t, [p.name(), UI.pos_short(p.position), p.age(w.today), club_name, _stars(p.ca()), "%d" % int(p.condition)], p.id)
		UI.player_cell(it, 0, p.id)
		UI.team_cell(it, 3, p.club_id)
		if ids.has(p.id):
			it.set_custom_font(0, ThemeBuilder.font("table_bold"))
		if not p.is_available():
			it.set_custom_color(0, ThemeBuilder.SEALING_WAX)
			it.set_tooltip_text(0, UI.unavailable_text(p))
	t.item_activated.connect(func():
		var it := t.get_selected()
		if it != null:
			go("player", {"player_id": str(it.get_metadata(0))}))
	pv.add_child(t)
	pp.add_child(pv)
	host.add_child(pp)


func refresh() -> void:
	if club == null or slots_box == null:
		return
	clear(slots_box)
	clear(tactics_box)
	var w := Game.world
	if club.lineup.is_empty() and not is_nt:
		club.lineup = Schools.best_lineup(w, club.id) if Schools.is_house(club.id) else WorldGenerator.best_lineup(w, club.id)
	var squad: Array[Player] = w.players_of_nationality(str(nt.get("country_id", ""))) if is_nt else w.squad_of(club.id)
	squad_table.clear()
	squad_table.create_item()
	var slot_of := {}
	for i in PitchView.SLOTS.size():
		var pid := _slot_value(PitchView.SLOTS[i], _slot_index(i))
		if pid != "":
			slot_of[pid] = i
	var order := {"K": 0, "C": 1, "B": 2, "S": 3}
	var rows: Array = squad.duplicate()
	rows.sort_custom(func(a, b):
		var sa: int = slot_of.get(a.id, 99)
		var sb: int = slot_of.get(b.id, 99)
		if sa != sb:
			return sa < sb
		if a.position != b.position:
			return order[a.position] < order[b.position]
		return a.ca() > b.ca())
	for p in rows:
		var st := ""
		if p.injury_days > 0:
			st = "✚ %d" % p.injury_days
		elif p.suspension_matches > 0:
			st = "⊘ %d" % p.suspension_matches
		elif p.on_duty():
			st = "✈ %d" % p.duty_days
		var starter: bool = slot_of.has(p.id)
		var lvl: int = Game.knowledge_level(p)
		var it := UI.row(squad_table, [UI.pos_short(PitchView.SLOTS[slot_of[p.id]]) if starter else "", p.name(), UI.pos_short(p.position), p.age(w.today), "%d%%" % int(p.condition), T(UI.morale_key(p.morale)), _stars(p.ca()) if lvl >= 1 else "?", st], p.id)
		UI.player_cell(it, COL_NAME, p.id)
		if starter:
			it.set_custom_font(1, ThemeBuilder.font("table_bold"))
			it.set_custom_font(0, ThemeBuilder.font("table_bold"))
			it.set_custom_color(0, ThemeBuilder.BRONZE_TEXT)
		if not p.is_available():
			it.set_custom_color(1, ThemeBuilder.SEALING_WAX)
			it.set_custom_color(7, ThemeBuilder.SEALING_WAX)
		elif not starter:
			it.set_custom_color(1, ThemeBuilder.INK_SOFT)
		if p.id == sel_pid:
			it.select(1)
	var bh := UI.hbox(8)
	var valid := _valid()
	var vl := UI.label(T("ui.lineup.valid") if valid else T("ui.lineup.invalid"), "ui_bold", 14, ThemeBuilder.GREEN if valid else ThemeBuilder.SEALING_WAX)
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bh.add_child(vl)
	if editable:
		bh.add_child(UI.button(T("ui.squad.auto_lineup"), func(): _auto_lineup(); Game.mark_dirty(); sel_pid = ""; sel_slot = -1; refresh()))
	slots_box.add_child(bh)
	_update_pitch()

	var t := club.tactics
	tactics_box.add_child(UI.subtitle(T("ui.tactics.team")))
	var real_club: bool = not is_nt and w.clubs.has(club.id)
	if real_club and editable:
		club.ensure_tactic_sets()
		var sh := UI.hbox(6)
		var sl0 := UI.label(T("ui.tactics.saved"), "ui_medium", 13)
		sl0.custom_minimum_size = Vector2(110, 0)
		sh.add_child(sl0)
		var sets: Array = []
		for i in 3:
			sets.append([i, T("ui.tactics.set." + str(club.tactic_sets[i]["name"]))])
		var so := UI.option(sets, club.active_set, func(v): _switch_set(int(v)))
		so.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sh.add_child(so)
		tactics_box.add_child(sh)
	for key in ["mentality", "tempo", "pass_style", "long_shots", "pressing", "hard_play", "time_wasting"]:
		var h := UI.hbox(6)
		var l := UI.label(T("tactic." + key), "ui_medium", 13)
		l.custom_minimum_size = Vector2(110, 0)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.tooltip_text = T("tactic." + key)
		h.add_child(l)
		h.add_child(UI.label(T("tactic." + key + ".low"), "ui", 12, ThemeBuilder.INK_SOFT))
		var sl := UI.slider(float(t.get(key, 10)), func(v): t[key] = int(v))
		sl.editable = editable
		h.add_child(sl)
		h.add_child(UI.label(T("tactic." + key + ".high"), "ui", 12, ThemeBuilder.INK_SOFT))
		tactics_box.add_child(h)
	tactics_box.add_child(UI.rule())
	_option_row("chaser_formation", [["free", T("formation.free")], ["hawkshead", T("formation.hawkshead")], ["porskoff", T("formation.porskoff")], ["shimmy", T("formation.shimmy")], ["reverse_pass", T("formation.reverse_pass")], ["looping", T("formation.looping")]])
	if real_club:
		var fam := club.familiarity_of(str(t.get("chaser_formation", "free")))
		var fl := UI.label(T("ui.tactics.familiarity") % int(fam), "ui", 12, ThemeBuilder.GREEN if fam >= 75.0 else (ThemeBuilder.INK_SOFT if fam >= 50.0 else ThemeBuilder.SEALING_WAX))
		fl.tooltip_text = T("ui.tactics.familiarity_tip")
		fl.mouse_filter = Control.MOUSE_FILTER_PASS
		tactics_box.add_child(fl)
	_option_row("chaser_defence", [["zone", T("defence.zone")], ["pincer", T("defence.pincer")], ["mark", T("defence.mark")]])
	_option_row("beater_instruction", [["nearest", T("beaters.nearest")], ["hunt_seeker", T("beaters.hunt_seeker")], ["protect_seeker", T("beaters.protect_seeker")], ["protect_chasers", T("beaters.protect_chasers")], ["punish_carrier", T("beaters.punish_carrier")], ["mark_beaters", T("beaters.mark_beaters")], ["dopplebeater", T("beaters.dopplebeater")], ["backbeat", T("beaters.backbeat")]])
	_option_row("seeker_catch", [["always", T("seeker.always")], ["if_wins", T("seeker.if_wins")], ["ahead_by", T("seeker.ahead_by")]])
	var hh := UI.hbox(6)
	var l2 := UI.label(T("tactic.seeker_ahead_by"), "ui_medium", 13)
	l2.custom_minimum_size = Vector2(110, 0)
	hh.add_child(l2)
	hh.add_child(UI.option([[0, "0"], [30, "+30"], [50, "+50"], [100, "+100"], [150, "+150"], [200, "+200"]], int(t.get("seeker_ahead_by", 50)), func(v): t["seeker_ahead_by"] = int(v); Game.mark_dirty(); assistant.text = _assistant_text()))
	tactics_box.add_child(hh)
	_option_row("seeker_search", [["free", T("seeker.search_free")], ["mark_rival", T("seeker.search_mark")]])
	_option_row("seeker_feint", [["never", T("feint.never")], ["if_chance", T("feint.if_chance")], ["seek", T("feint.seek")]])
	_option_row("keeper_position", [["stay", T("keeper.stay")], ["rush", T("keeper.rush")], ["starfish", T("keeper.starfish")], ["double_eight", T("keeper.double_eight")]])
	assistant.text = _assistant_text()


func _switch_set(i: int) -> void:
	Game.mark_dirty()
	club.ensure_tactic_sets()
	club.tactic_sets[club.active_set]["tactics"] = club.tactics.duplicate(true)
	club.active_set = i
	club.tactics = SimTactics.merge(club.tactic_sets[i]["tactics"]).duplicate(true)
	refresh()


func _update_pitch() -> void:
	var ps: Array = []
	for i in PitchView.SLOTS.size():
		var pid := _slot_value(PitchView.SLOTS[i], _slot_index(i))
		var p: Player = Game.world.player(pid)
		ps.append({"pos": PitchView.SLOTS[i], "name": p.name(), "condition": p.condition, "id": p.id, "available": p.is_available()} if p != null else {})
	pitch.highlight = sel_slot
	pitch.set_lineup(club, ps, str(club.tactics.get("chaser_formation", "free")))
	if hint_label != null:
		hint_label.text = T("ui.lineup.hint_slot") if sel_slot >= 0 else (T("ui.lineup.hint_player") if sel_pid != "" else T("ui.lineup.hint_dnd"))


func _slot_index(i: int) -> int:
	match i:
		2: return 1
		3: return 2
		5: return 1
	return 0


func _on_row_selected() -> void:
	if UI.rmb_selected(squad_table):
		# Not left selected either: a later left click on the same row must still pick him (a Tree doesn't report
		# a click on the row that is already selected).
		squad_table.deselect_all.call_deferred()
		return
	var it := squad_table.get_selected()
	if it == null or it.get_metadata(0) == null:
		return
	_pick_player(str(it.get_metadata(0)))


func _pick_player(pid: String) -> void:
	if not editable:
		return
	if sel_slot >= 0:
		_place(pid, sel_slot)
		sel_slot = -1
		sel_pid = ""
		refresh()
		return
	sel_pid = pid
	_update_pitch()


func _on_squad_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var it := squad_table.get_item_at_position(mb.position)
	var on_name: bool = it != null and it.get_metadata(0) != null and squad_table.get_column_at_position(mb.position) == COL_NAME
	if mb.pressed:
		_name_press = ""
		if not on_name:
			return
		squad_table.accept_event()
		if editable and sel_slot >= 0:
			_pick_player(str(it.get_metadata(0)))
			return
		_name_press = str(it.get_metadata(0))
		_name_press_pos = mb.position
	elif _name_press != "":
		var pid := _name_press
		_name_press = ""
		if on_name and str(it.get_metadata(0)) == pid and mb.position.distance_to(_name_press_pos) < 8.0:
			squad_table.accept_event()
			go("player", {"player_id": pid})


func _squad_drag_data(at_position: Vector2) -> Variant:
	_name_press = ""
	if not editable:
		return null
	var it := squad_table.get_item_at_position(at_position)
	if it == null or it.get_metadata(0) == null:
		return null
	var pid := str(it.get_metadata(0))
	# Per drag: a Tree clears its drop mode flags when any drag ends, and while they are set it draws the drop
	# highlight instead of the ordinary row hover.
	squad_table.set_drop_mode_flags(Tree.DROP_MODE_ON_ITEM)
	var prev := UI.label(it.get_text(COL_NAME), "ui_bold", 14, ThemeBuilder.INK)
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", ThemeBuilder.flat(ThemeBuilder.CARD, ThemeBuilder.BRASS, 1, 4, 6))
	pp.add_child(prev)
	squad_table.set_drag_preview(pp)
	return {"player_id": pid}


## Called on every mouse motion of the drag: it must not change anything.
func _squad_can_drop(at_position: Vector2, data: Variant) -> bool:
	if not editable or not (data is Dictionary):
		return false
	var pid := str(data.get("player_id", ""))
	if pid == "":
		return false
	var it := squad_table.get_item_at_position(at_position)
	if it == null or it.get_metadata(0) == null:
		return false
	var target := str(it.get_metadata(0))
	return target != pid and (_slot_of(pid) >= 0 or _slot_of(target) >= 0)


func _squad_drop(at_position: Vector2, data: Variant) -> void:
	if not editable or not (data is Dictionary):
		return
	var it := squad_table.get_item_at_position(at_position)
	if it == null or it.get_metadata(0) == null:
		return
	_drop_on_player(str(data.get("player_id", "")), str(it.get_metadata(0)))


func _drop_on_player(pid: String, target: String) -> void:
	if not editable or pid == "" or pid == target or Game.world.player(pid) == null or Game.world.player(target) == null:
		return
	var target_slot := _slot_of(target)
	if target_slot >= 0:
		_place(pid, target_slot)
	else:
		var own_slot := _slot_of(pid)
		if own_slot < 0:
			return
		_place(target, own_slot)
	sel_pid = ""
	sel_slot = -1
	refresh()


func _on_player_dropped(pid: String, i: int) -> void:
	if not editable or pid == "" or Game.world.player(pid) == null:
		return
	sel_pid = pid
	sel_slot = -1
	_on_slot_pressed(i)


func _on_row_activated() -> void:
	if not editable:
		return
	var it := squad_table.get_selected()
	if it == null or it.get_metadata(0) == null:
		return
	var pid := str(it.get_metadata(0))
	var p: Player = Game.world.player(pid)
	if p == null:
		return
	var cur := _slot_of(pid)
	if cur >= 0:
		_set_slot(PitchView.SLOTS[cur], _slot_index(cur), "")
	else:
		var first := PitchView.SLOTS.find(p.position)
		_place(pid, first)
	sel_pid = ""
	sel_slot = -1
	refresh()


func _on_slot_pressed(i: int) -> void:
	if not editable:
		return
	if sel_pid != "":
		_place(sel_pid, i)
		sel_pid = ""
		sel_slot = -1
		refresh()
		return
	sel_slot = -1 if sel_slot == i else i
	_update_pitch()


func _slot_of(pid: String) -> int:
	for i in PitchView.SLOTS.size():
		if _slot_value(PitchView.SLOTS[i], _slot_index(i)) == pid:
			return i
	return -1


func _place(pid: String, i: int) -> void:
	var from := _slot_of(pid)
	var occupant := _slot_value(PitchView.SLOTS[i], _slot_index(i))
	_set_slot_quiet(PitchView.SLOTS[i], _slot_index(i), pid)
	if from >= 0 and from != i and occupant != "" and occupant != pid:
		_set_slot_quiet(PitchView.SLOTS[from], _slot_index(from), occupant)


func _swap_slots(a_id: String, b_id: String) -> void:
	if not editable:
		return
	var slots := [["K", 0], ["C", 0], ["C", 1], ["C", 2], ["B", 0], ["B", 1], ["S", 0]]
	var sa: Array = []
	var sb: Array = []
	for sl in slots:
		if _slot_value(sl[0], sl[1]) == a_id:
			sa = sl
		if _slot_value(sl[0], sl[1]) == b_id:
			sb = sl
	if sa.is_empty() or sb.is_empty():
		return
	_set_slot_quiet(sa[0], sa[1], b_id)
	_set_slot_quiet(sb[0], sb[1], a_id)
	sel_pid = ""
	sel_slot = -1
	refresh()


func _auto_lineup() -> void:
	var w := Game.world
	if is_nt:
		var l := NationalTeams.pick_squad(w, nt)
		for k in l.keys():
			club.lineup[k] = l[k]
	else:
		club.lineup = Schools.best_lineup(w, club.id) if Schools.is_house(club.id) else WorldGenerator.best_lineup(w, club.id)


func _valid() -> bool:
	if not is_nt:
		return Game.engine._lineup_valid(club)
	var l := club.lineup
	if str(l.get("K", "")) == "" or str(l.get("S", "")) == "" or l.get("C", []).size() != 3 or l.get("B", []).size() != 2:
		return false
	var seen := {}
	for pid in [l["K"]] + l["C"] + l["B"] + [l["S"]]:
		var p: Player = Game.world.player(str(pid))
		if p == null or seen.has(pid) or p.nationality != str(nt.get("country_id", "")) or not p.is_fit():
			return false
		seen[pid] = true
	return true


func _option_row(key: String, items: Array) -> void:
	var h := UI.hbox(6)
	var l := UI.label(T("tactic." + key), "ui_medium", 13)
	l.custom_minimum_size = Vector2(110, 0)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.tooltip_text = T("tactic." + key)
	h.add_child(l)
	var ob := UI.option(items, club.tactics.get(key, items[0][0]), func(v): club.tactics[key] = v; Game.mark_dirty(); assistant.text = _assistant_text(); _update_pitch(), 120)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.fit_to_longest_item = false
	ob.disabled = not editable
	h.add_child(ob)
	tactics_box.add_child(h)


func _slot_value(pos: String, idx: int) -> String:
	if pos == "C" or pos == "B":
		var arr: Array = club.lineup.get(pos, [])
		return str(arr[idx]) if idx < arr.size() else ""
	return str(club.lineup.get(pos, ""))


func _set_slot(pos: String, idx: int, pid: String) -> void:
	_set_slot_quiet(pos, idx, pid)
	refresh()


func _set_slot_quiet(pos: String, idx: int, pid: String) -> void:
	Game.mark_dirty()
	for k in ["K", "S"]:
		if str(club.lineup.get(k, "")) == pid:
			club.lineup[k] = ""
	for k in ["C", "B"]:
		var arr: Array = club.lineup.get(k, [])
		for i in arr.size():
			if str(arr[i]) == pid:
				arr[i] = ""
	if pos == "C" or pos == "B":
		var arr: Array = club.lineup.get(pos, [])
		while arr.size() < (3 if pos == "C" else 2):
			arr.append("")
		arr[idx] = pid
		club.lineup[pos] = arr
	else:
		club.lineup[pos] = pid


func _assistant_text() -> String:
	var t := club.tactics
	var lines := []
	var opp := _next_opponent()
	if opp != null and not opp.manager_is_human and Game.engine != null:
		var style: String = str(Game.engine._ai_style(opp).get("chaser_formation", "free"))
		var counter := SimTactics.counter_to(style)
		if counter != "":
			var mine := SimTactics.defence_of(t)
			var sname := _formation_name(style)
			if mine == counter:
				lines.append(T("ui.assistant.counter_ok") % [T("defence." + counter), sname])
			else:
				lines.append(T("ui.assistant.counter") % [sname + " (" + opp.short_name + ")", T("defence." + counter)])
		var their_def := SimTactics.defence_of(Game.engine._ai_style(opp))
		if their_def != "zone":
			lines.append(T("ui.assistant.attack_vs_" + their_def) % opp.short_name)
	var form := str(t.get("chaser_formation", "free"))
	if form != "free":
		var req := {"hawkshead": ["teamwork", "bravery"], "porskoff": ["creativity", "altitude"], "shimmy": ["agility", "dodging"], "reverse_pass": ["passing", "creativity"], "looping": ["teamwork", "broom_control"]}
		var keys: Array = req.get(form, [])
		var avg := 0.0
		var n := 0
		for pid in club.lineup.get("C", []):
			var p: Player = Game.world.player(str(pid))
			if p == null:
				continue
			for k in keys:
				avg += float(p.attrs.get(k, 8.0))
				n += 1
		avg = avg / maxf(n, 1)
		lines.append(T("ui.assistant.formation") % [T("formation." + form), int(avg)])
	match str(t.get("seeker_catch", "always")):
		"always":
			lines.append(T("ui.assistant.seeker_always"))
		"if_wins":
			lines.append(T("ui.assistant.seeker_if_wins"))
		"ahead_by":
			lines.append(T("ui.assistant.seeker_ahead") % int(t.get("seeker_ahead_by", 50)))
	if int(t.get("hard_play", 10)) >= 15:
		lines.append(T("ui.assistant.hard_play"))
	if int(t.get("pressing", 10)) >= 15 and int(t.get("tempo", 10)) >= 15:
		lines.append(T("ui.assistant.tiring"))
	return "[b]%s:[/b] " % T("ui.assistant") + " ".join(lines)


func _stars(ca: float) -> String:
	var n := clampi(int(round(ca / 36.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)


func _next_opponent() -> Club:
	var w := Game.world
	var best := {}
	for comp in w.competitions.values():
		if not comp.club_ids.has(club.id):
			continue
		var f: Dictionary = comp.next_fixture_of(club.id, w.today)
		if not f.is_empty() and (best.is_empty() or int(f["day"]) < int(best["day"])):
			best = f
	if best.is_empty():
		return null
	var rid: String = str(best["away_id"]) if str(best["home_id"]) == club.id else str(best["home_id"])
	return w.clubs.get(rid)


func _formation_name(style: String) -> String:
	return T("formation." + style)
