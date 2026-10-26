extends UIScreen
## Training: weekly focus, workload, delegate to the assistant; individual plan; recent squad changes.

var body: VBoxContainer
var editor: VBoxContainer
var sel_id := ""
var plan_grid: GridContainer
var plan_opts: Array = []
var share_label: Label
var load_opt: OptionButton
var delegate: CheckBox
var table: Tree


func build() -> void:
	header(T("ui.menu.training"))
	body = UI.vbox(12)
	root.add_child(UI.scroll(body))
	var club := Game.my_club()
	var bar := UI.hbox(10)
	delegate = CheckBox.new()
	delegate.text = T("ui.training.delegate")
	delegate.button_pressed = bool(Game.world.settings.get("delegate_training", true))
	delegate.toggled.connect(func(v): Game.world.settings["delegate_training"] = v; Game.mark_dirty(); _update_enabled())
	bar.add_child(delegate)
	bar.add_child(UI.label(T("ui.training.load")))
	load_opt = UI.option([[1, T("ui.training.light")], [2, T("ui.training.medium")], [3, T("ui.training.intense")]], int(club.tactics.get("training_load", 2)), func(v): club.tactics["training_load"] = int(v); Game.mark_dirty())
	bar.add_child(load_opt)
	bar.add_child(UI.spacer())
	body.add_child(bar)
	if not club.tactics.has("training_plan"):
		var plan := {}
		for k in Progression.TRAINING.keys():
			plan[k] = 2 if k == str(club.tactics.get("training_focus", "tactics")) else 1
		club.tactics["training_plan"] = plan
	var pp := UI.panel(10)
	var pv := UI.vbox(6)
	pv.add_child(UI.subtitle(T("ui.training.plan")))
	plan_grid = GridContainer.new()
	plan_grid.columns = 4
	plan_grid.add_theme_constant_override("h_separation", 14)
	plan_grid.add_theme_constant_override("v_separation", 6)
	for k in Progression.TRAINING.keys():
		var l := UI.label(T("training." + k), "ui_medium", 13)
		l.custom_minimum_size = Vector2(130, 0)
		l.tooltip_text = ", ".join(Progression.TRAINING[k].map(func(a): return T("attr." + a)))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		plan_grid.add_child(l)
		var cat: String = k
		var opt := UI.option([[0, T("ui.training.none")], [1, T("ui.training.light")], [2, T("ui.training.medium")], [3, T("ui.training.intense")]], int(club.tactics["training_plan"].get(k, 1)), func(v): club.tactics["training_plan"][cat] = int(v); Game.mark_dirty(); _update_shares(), 130)
		plan_opts.append(opt)
		plan_grid.add_child(opt)
	pv.add_child(plan_grid)
	share_label = UI.label("", "ui", 12, ThemeBuilder.INK_SOFT)
	share_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(share_label)
	pp.add_child(pv)
	body.add_child(pp)
	_update_shares()
	body.add_child(_note(T("ui.training.note")))
	var ep := UI.panel(10)
	editor = UI.vbox(6)
	ep.add_child(editor)
	body.add_child(ep)
	body.add_child(UI.subtitle(T("ui.training.recent")))
	table = UI.table([{"title": T("ui.col.name"), "width": 160, "expand": true}, {"title": T("ui.col.pos"), "width": 40, "align": "center"}, {"title": T("ui.col.age"), "width": 40, "align": "right"}, {"title": T("ui.training.focus_ind"), "width": 120}, {"title": T("ui.training.mentor"), "width": 150}, {"title": T("ui.training.improved"), "width": 260, "expand": true}, {"title": T("ui.training.declined"), "width": 260, "expand": true}], 0)
	table.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	table.set_column_title_tooltip_text(3, T("ui.training.focus_tip"))
	table.set_column_title_tooltip_text(4, T("ui.training.mentor_tip"))
	table.item_selected.connect(func():
		var it := table.get_selected()
		if it != null and str(it.get_metadata(0)) != sel_id:
			sel_id = str(it.get_metadata(0))
			_fill_editor())
	table.item_activated.connect(func():
		var it := table.get_selected()
		if it != null:
			go("player", {"player_id": str(it.get_metadata(0))}))
	body.add_child(UI.table_card(table))
	_update_enabled()


func _update_enabled() -> void:
	var d := delegate.button_pressed
	load_opt.disabled = d
	for o in plan_opts:
		o.disabled = d
	_fill_editor()


func _update_shares() -> void:
	var plan: Dictionary = Game.my_club().tactics.get("training_plan", {})
	var total := 0.0
	for k in plan.keys():
		total += float(plan[k])
	var parts := []
	for k in Progression.TRAINING.keys():
		if float(plan.get(k, 0)) > 0.0 and total > 0.0:
			parts.append("%s %d%%" % [T("training." + k), int(round(100.0 * float(plan[k]) / total))])
	share_label.text = T("ui.training.shares") % (", ".join(parts) if not parts.is_empty() else "—")


func refresh() -> void:
	var w := Game.world
	table.clear()
	table.create_item()
	var squad: Array[Player] = w.squad_of(w.player_club_id)
	var sel_item: TreeItem = null
	for p in squad:
		var up := []
		var down := []
		for k in Player.ATTR_KEYS:
			var now := float(p.attrs.get(k, 8.0))
			var prev := float(p.prev_attrs.get(k, now))
			var d := now - prev
			if absf(d) <= 0.1:
				continue
			var steps := int(floor(now)) - int(floor(prev))
			var txt: String = T("attr." + k) + " " + ("%+d" % steps if steps != 0 else ("↗" if d > 0.0 else "↘"))
			if d > 0.0:
				up.append([d, txt])
			else:
				down.append([-d, txt])
		var ups := _summary(up)
		var downs := _summary(down)
		var focus_txt := T("training." + p.training_focus) if p.training_focus != "" else "—"
		var mentor := Progression.valid_mentor(p, w)
		var mentor_txt := mentor.name() if mentor != null else "—"
		var trow := UI.row(table, [p.name(), UI.pos_short(p.position), p.age(w.today), focus_txt, mentor_txt, ups[0], downs[0]], p.id, [null, null, null, ThemeBuilder.BLUE, ThemeBuilder.BRONZE_TEXT, ThemeBuilder.GREEN, ThemeBuilder.SEALING_WAX])
		if mentor != null:
			UI.player_cell(trow, 4, mentor.id)
		if ups[1] != "":
			trow.set_tooltip_text(5, ups[1])
		if downs[1] != "":
			trow.set_tooltip_text(6, downs[1])
		if p.id == sel_id:
			sel_item = trow
	table.custom_minimum_size.y = 40 + Settings.row_height() * maxi(squad.size(), 1)
	UI.fit_rows(table)
	if sel_item != null:
		sel_item.select(0)
	_fill_editor()


func _summary(changes: Array) -> Array:
	changes.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else str(a[1]) < str(b[1]))
	var names: Array = changes.map(func(c): return str(c[1]))
	var short := ", ".join(names.slice(0, 3))
	if names.size() > 3:
		short += " " + T("ui.training.more") % (names.size() - 3)
	return [short, ", ".join(names)]


func _fill_editor() -> void:
	if editor == null:
		return
	clear(editor)
	editor.add_child(UI.subtitle(T("ui.training.individual")))
	var w := Game.world
	var p: Player = w.player(sel_id) if sel_id != "" else null
	if p == null or not w.squad_of(w.player_club_id).has(p):
		sel_id = ""
		editor.add_child(_note(T("ui.training.pick_hint")))
		return
	var pid := p.id
	editor.add_child(UI.label("%s · %s · %d" % [p.name(), T("pos." + p.position), p.age(w.today)], "ui_medium", 15))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 6)
	g.add_child(UI.label((T("ui.label_value") % [T("ui.training.focus_ind"), ""]).strip_edges()))
	var items := [["", T("ui.training.focus_team")]]
	for k in Progression.TRAINING.keys():
		items.append([k, T("training." + k)])
	var fo := UI.option(items, p.training_focus, func(val): _set_plan(pid, "focus", str(val)))
	fo.disabled = delegate.button_pressed
	fo.tooltip_text = T("ui.training.focus_tip")
	g.add_child(fo)
	g.add_child(UI.label((T("ui.label_value") % [T("ui.training.mentor"), ""]).strip_edges()))
	var ms := [["", "—"]]
	for q in w.squad_of(w.player_club_id):
		if q.age(w.today) >= 28 and q.id != p.id:
			ms.append([q.id, "%s (%d, %s %d)" % [q.name(), q.age(w.today), T("ui.training.prof"), int(q.hid("professionalism"))]])
	var mo := UI.option(ms, p.mentor_id, func(val): _set_plan(pid, "mentor", str(val)))
	mo.disabled = p.age(w.today) > 23
	mo.tooltip_text = T("ui.training.mentor_tip")
	g.add_child(mo)
	editor.add_child(g)
	var h2 := UI.hbox(10)
	var clr := UI.button(T("ui.training.clear"), func(): _set_plan(pid, "clear", ""))
	clr.disabled = p.training_focus == "" and p.mentor_id == ""
	h2.add_child(clr)
	h2.add_child(UI.button(T("ui.view_profile"), func(): go("player", {"player_id": pid})))
	h2.add_child(UI.spacer())
	editor.add_child(h2)
	if delegate.button_pressed:
		editor.add_child(_note(T("ui.training.delegated")))
	elif p.pa - p.ca() < 0.5:
		editor.add_child(_note(T("ui.training.at_potential")))
	editor.add_child(_note(T("ui.training.mentor_tip")))


func _note(s: String) -> Label:
	var l := UI.label(s, "ui_italic", 13, ThemeBuilder.INK_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _set_plan(pid: String, what: String, val: String) -> void:
	var p: Player = Game.world.player(pid)
	if p == null:
		return
	if what == "focus" or what == "clear":
		p.training_focus = val
	if what == "mentor" or what == "clear":
		p.mentor_id = val
	Game.mark_dirty()
	refresh.call_deferred()
