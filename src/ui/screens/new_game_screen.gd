extends UIScreen
## New game: New / Load tabs, club list by league with a color stripe
## and two lines (Tree), club profile with KPIs, sign button at the end; advanced options collapsed.

var name_edit: LineEdit
var club_tree: Tree
var seed_edit: LineEdit
var saves_list: ItemList
var info_box: VBoxContainer
var sign_btn: Button
var name_hint: Label
var tab := 0
var body: HBoxContainer
var selected_cid := "club_puddlemere_united"
var start_seed := -1
var preview: World = null
var map_tab := 0
var map_box: HBoxContainer
var map_list: Tree
var map_title: Label
var world_map: LeagueMap
var europe_map: LeagueMap
var map_sel := ""
var pin_filter := 0
var nationality := ""
var nat_option: OptionButton
var legend: PanelContainer
var _syncing := false
const MAP_H := 290.0


func build() -> void:
	var bg := UI.image_for("art", "title_bg")
	if bg != null:
		var tr := TextureRect.new()
		tr.texture = bg
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.modulate = Color(1, 1, 1, 0.28)
		tr.show_behind_parent = true
		add_child(tr)
		move_child(tr, 0)
	var bar := UI.hbox(12)
	bar.add_child(UI.title(T("ui.title.new")))
	bar.add_child(UI.spacer())
	root.add_child(bar)
	body = UI.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)


func _preview() -> World:
	if start_seed < 0:
		start_seed = randi() % 100000
	if preview == null or preview.seed_value != start_seed:
		preview = WorldGenerator.new(Game.loader).preview_clubs(start_seed)
	return preview


func refresh() -> void:
	clear(body)
	if tab == 0:
		_build_new()
	else:
		_build_load()


func _build_new() -> void:
	var col := UI.vbox(12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(col)
	var mapcard := UI.panel(8)
	var mv := UI.vbox(6)
	var lh := UI.hbox(12)
	lh.add_child(UI.subtitle(T("ui.new_game.choose_club")))
	lh.add_child(UI.spacer())
	legend = UI.panel(6)
	legend.size_flags_horizontal = Control.SIZE_SHRINK_END
	var lgh := UI.hbox(6)
	lgh.add_child(LeagueMap.seal(false))
	lgh.add_child(UI.text("Caption", T("ui.new_game.legend_clubs")))
	var sep := Control.new()
	sep.custom_minimum_size.x = 10
	lgh.add_child(sep)
	lgh.add_child(LeagueMap.seal(true))
	lgh.add_child(UI.text("Caption", T("ui.new_game.legend_schools")))
	legend.add_child(lgh)
	lh.add_child(legend)
	lh.add_child(UI.tabs([T("ui.new_game.filter_all"), T("ui.new_game.filter_clubs"), T("ui.new_game.filter_schools")], pin_filter, func(i):
		pin_filter = i
		_apply_filter()))
	lh.add_child(UI.tabs([T("ui.new_game.map"), T("ui.new_game.list")], map_tab, func(i):
		map_tab = i
		_apply_map_tab()))
	mv.add_child(lh)
	mv.add_child(_build_map())
	mapcard.add_child(mv)
	col.add_child(mapcard)
	var row := UI.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var left := UI.panel(8)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_horizontal = Control.SIZE_FILL
	left.custom_minimum_size.x = Settings.px(440)
	var lv := UI.vbox(6)
	lv.add_child(map_title)
	lv.add_child(map_list)
	club_tree = Tree.new()
	club_tree.hide_root = true
	club_tree.columns = 2
	club_tree.set_column_expand(0, true)
	club_tree.set_column_custom_minimum_width(1, 110)
	club_tree.select_mode = Tree.SELECT_ROW
	club_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	club_tree.custom_minimum_size = Vector2(0, 160)
	club_tree.add_theme_constant_override("v_separation", 3)
	var root_it := club_tree.create_item()
	var free_it := club_tree.create_item(root_it)
	free_it.set_text(0, T("ui.new_game.unemployed"))
	free_it.set_custom_font(0, ThemeBuilder.font("ui_italic"))
	free_it.set_metadata(0, "")
	free_it.custom_minimum_height = 26
	var pw := _preview()
	var leagues := pw.leagues()
	leagues.sort_custom(func(a, b): return a.level < b.level if a.level != b.level else a.id < b.id)
	var my_league := str(pw.clubs[selected_cid].league_id) if pw.clubs.has(selected_cid) else ""
	for comp in leagues:
		var hdr := club_tree.create_item(root_it)
		hdr.set_meta("school", false)
		hdr.set_text(0, comp.display_name())
		hdr.set_custom_font(0, ThemeBuilder.font("label"))
		hdr.set_custom_font_size(0, 12)
		hdr.set_custom_color(0, ThemeBuilder.BRONZE_TEXT)
		hdr.set_selectable(0, false)
		hdr.set_selectable(1, false)
		hdr.set_text(1, "%s %d · %d" % [T("ui.level"), comp.level, comp.club_ids.size()])
		hdr.set_custom_color(1, ThemeBuilder.INK_FADED)
		hdr.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		hdr.set_custom_font_size(1, 12)
		hdr.collapsed = comp.id != my_league
		var ids: Array = comp.club_ids.duplicate()
		ids.sort_custom(func(a, b): return pw.clubs[a].name < pw.clubs[b].name)
		for cid in ids:
			var c: Club = pw.clubs[cid]
			var it := club_tree.create_item(hdr)
			it.custom_minimum_height = 40
			it.set_text(0, "%s\n%s" % [c.name, c.display_city()])
			var ctex := Crest.icon_for(c)
			if ctex != null:
				it.set_icon(0, ctex)
				it.set_icon_max_width(0, 30)
			it.set_metadata(0, cid)
			var titles := int(c.history.get("league_titles", 0))
			it.set_text(1, "★ %d" % titles if titles > 0 else "")
			it.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
			it.set_custom_color(1, ThemeBuilder.BRONZE_TEXT)
			if cid == selected_cid:
				it.select(0)
	for sid in Game.loader.schools.keys():
		var sc: Dictionary = Game.loader.schools[sid]
		var houses: Array = sc.get("houses", [])
		if houses.is_empty():
			continue
		var hdr := club_tree.create_item(root_it)
		hdr.set_meta("school", true)
		hdr.set_text(0, Game.school_name(sid))
		hdr.set_custom_font(0, ThemeBuilder.font("label"))
		hdr.set_custom_font_size(0, 12)
		hdr.set_custom_color(0, ThemeBuilder.BRONZE_TEXT)
		hdr.set_selectable(0, false)
		hdr.set_selectable(1, false)
		hdr.set_text(1, T("ui.new_game.school"))
		hdr.set_custom_color(1, ThemeBuilder.INK_FADED)
		hdr.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		hdr.set_custom_font_size(1, 12)
		hdr.collapsed = not Schools.is_house(selected_cid)
		var colors: Dictionary = Game.loader.school_students.get(sid, {}).get("house_colors", {})
		for h in houses:
			var hid := Schools.house_id(sid, str(h))
			var it := club_tree.create_item(hdr)
			it.custom_minimum_height = 40
			it.set_text(0, "%s\n%s" % [Loc.name("house." + str(h), str(h)), Game.school_name(sid)])
			var tmp := Club.new()
			tmp.id = hid
			tmp.name = str(h)
			tmp.colors = colors.get(h, tmp.colors)
			var ctex := Crest.texture_for(tmp)
			if ctex != null:
				it.set_icon(0, ctex)
				it.set_icon_max_width(0, 30)
			else:
				it.set_icon(0, UI.swatch())
				it.set_icon_modulate(0, ThemeBuilder.hex(str(tmp.colors.get("primary", "#888"))))
				it.set_icon_max_width(0, 6)
			it.set_metadata(0, hid)
			if hid == selected_cid:
				it.select(0)
	club_tree.item_selected.connect(_on_club_selected)
	lv.add_child(club_tree)
	_apply_map_tab()
	_apply_filter()
	left.add_child(lv)
	row.add_child(left)
	var infop := UI.panel()
	infop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	infop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_box = UI.vbox(6)
	infop.add_child(info_box)
	row.add_child(infop)
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_FILL
	right.custom_minimum_size.x = Settings.px(370)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var form := UI.panel()
	var fv := UI.vbox(6)
	fv.add_child(UI.subtitle(T("ui.new_game.manager")))
	var nh := UI.hbox(10)
	var nl := UI.text("Body", T("ui.new_game.name"))
	nl.custom_minimum_size = Vector2(160, 0)
	nh.add_child(nl)
	name_edit = LineEdit.new()
	name_edit.max_length = 40
	name_edit.placeholder_text = T("ui.new_game.name")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(name_edit)
	fv.add_child(nh)
	name_hint = UI.label(T("ui.new_game.name_required"), "ui_italic", 13, ThemeBuilder.INK_SOFT)
	fv.add_child(name_hint)
	name_edit.text_changed.connect(func(_t): _update_sign())
	var lh2 := UI.hbox(10)
	var ll := UI.text("Body", T("ui.language"))
	ll.custom_minimum_size = Vector2(160, 0)
	lh2.add_child(ll)
	var lo := UI.option(Settings.LANGUAGES, Settings.language, func(v): Game.set_language(str(v)); main.go("new_game"), 160)
	lh2.add_child(lo)
	lh2.add_child(UI.spacer())
	fv.add_child(lh2)
	var nath := UI.hbox(10)
	var natl := UI.text("Body", T("ui.new_game.nationality"))
	natl.custom_minimum_size = Vector2(160, 0)
	nath.add_child(natl)
	var nat_items: Array = []
	for ctry in Game.loader.countries.keys():
		var cd: Dictionary = Game.loader.countries[ctry]
		nat_items.append([str(ctry), Loc.name("country." + str(ctry), str(cd.get("name_en", ctry)))])
	nat_items.sort_custom(func(a, b): return str(a[1]) < str(b[1]))
	nat_option = UI.option(nat_items, _nationality(), func(v): nationality = str(v))
	nath.add_child(nat_option)
	nath.add_child(UI.spacer())
	fv.add_child(nath)
	var adv := UI.link("▸ " + T("ui.new_game.advanced"), Callable())
	var advbox := UI.hbox(10)
	advbox.visible = false
	var sl := UI.text("Body", T("ui.new_game.seed"))
	sl.custom_minimum_size = Vector2(160, 0)
	advbox.add_child(sl)
	seed_edit = LineEdit.new()
	seed_edit.text = str(_preview().seed_value)
	seed_edit.text_submitted.connect(func(t): start_seed = int(t) if t.is_valid_int() else absi(hash(t)) % 100000; refresh())
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	advbox.add_child(seed_edit)
	adv.pressed.connect(func(): advbox.visible = not advbox.visible; adv.text = ("▾ " if advbox.visible else "▸ ") + T("ui.new_game.advanced"))
	fv.add_child(adv)
	fv.add_child(advbox)
	fv.add_child(UI.text("MetaItalic", T("ui.new_game.start_note")))
	form.add_child(fv)
	right.add_child(form)
	right.add_child(UI.spacer(false))
	var bh := UI.hbox()
	bh.add_child(UI.spacer())
	sign_btn = UI.primary("", _start)
	sign_btn.custom_minimum_size = Vector2(260, 40)
	bh.add_child(sign_btn)
	_update_sign()
	right.add_child(bh)
	row.add_child(right)
	_show_club(selected_cid)


func _build_load() -> void:
	var p := UI.panel()
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(8)
	v.add_child(UI.subtitle(T("ui.new_game.load")))
	saves_list = ItemList.new()
	saves_list.custom_minimum_size = Vector2(0, 240)
	saves_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var saves := SaveManager.list_saves()
	for m in saves:
		var idx := saves_list.add_item(Game.save_label(m))
		saves_list.set_item_metadata(idx, m.get("dir", ""))
	if saves.is_empty():
		v.add_child(UI.text("MetaItalic", T("ui.saves.none")))
	else:
		saves_list.select(0)
		saves_list.item_activated.connect(func(_i): _load())
	v.add_child(saves_list)
	var bh := UI.hbox()
	bh.add_child(UI.spacer())
	var lb := UI.primary(T("ui.new_game.load_btn"), _load)
	lb.disabled = saves.is_empty()
	bh.add_child(lb)
	v.add_child(bh)
	p.add_child(v)
	body.add_child(p)


func _build_map() -> Control:
	map_box = UI.hbox(8)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shared/map.json"))
	var pw := _preview()
	var by_map := {"world": [], "europe": []}
	for pid in data["pins"].keys():
		var pin: Dictionary = data["pins"][pid]
		var label := ""
		var school: bool = str(pid).begins_with("school_")
		if school:
			if not Game.loader.schools.has(pid):
				continue
			label = Game.school_name(pid)
		else:
			if not pw.competitions.has(pid):
				continue
			label = pw.competitions[pid].display_name()
		by_map[str(pin["map"])].append({"id": pid, "x": pin["x"], "y": pin["y"], "label": label, "school": school})
	map_box.add_child(UI.spacer())
	world_map = LeagueMap.new()
	world_map.setup("world", by_map["world"])
	world_map.custom_minimum_size = Vector2(MAP_H / world_map.aspect, MAP_H)
	world_map.pin_pressed.connect(_map_select)
	map_box.add_child(world_map)
	europe_map = LeagueMap.new()
	europe_map.setup("europe", by_map["europe"])
	europe_map.custom_minimum_size = Vector2(MAP_H / europe_map.aspect, MAP_H)
	europe_map.pin_pressed.connect(_map_select)
	map_box.add_child(europe_map)
	map_box.add_child(UI.spacer())
	map_title = UI.text("Caption", T("ui.new_game.map_hint"))
	map_list = Tree.new()
	map_list.hide_root = true
	map_list.select_mode = Tree.SELECT_ROW
	map_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_list.custom_minimum_size = Vector2(0, 160)
	map_list.item_selected.connect(func():
		var it := map_list.get_selected()
		if not _syncing and it != null and it.get_metadata(0) != null and is_instance_valid(info_box):
			selected_cid = str(it.get_metadata(0))
			_show_club(selected_cid))
	var start := ""
	if Schools.is_house(selected_cid):
		start = Schools.school_of_house(selected_cid)
	elif pw.clubs.has(selected_cid):
		start = pw.clubs[selected_cid].league_id
	if start != "":
		_map_select(start)
	return map_box


func _map_select(id: String) -> void:
	map_sel = id
	world_map.selected = id
	europe_map.selected = id
	world_map.queue_redraw()
	europe_map.queue_redraw()
	map_list.clear()
	var root_it := map_list.create_item()
	var pw := _preview()
	if id.begins_with("school_"):
		var sc: Dictionary = Game.loader.schools.get(id, {})
		map_title.text = Game.school_name(id)
		var colors: Dictionary = Game.loader.school_students.get(id, {}).get("house_colors", {})
		for hname in sc.get("houses", []):
			var hid := Schools.house_id(id, str(hname))
			var tmp := Club.new()
			tmp.id = hid
			tmp.name = str(hname)
			tmp.colors = colors.get(hname, tmp.colors)
			_map_row(root_it, hid, Loc.name("house." + str(hname), str(hname)), Game.school_name(id), Crest.texture_for(tmp))
		return
	var comp: Competition = pw.competitions.get(id)
	if comp == null:
		return
	map_title.text = "%s · %s %d · %d" % [comp.display_name(), T("ui.level"), comp.level, comp.club_ids.size()]
	var ids: Array = comp.club_ids.duplicate()
	ids.sort_custom(func(a, b): return pw.clubs[a].name < pw.clubs[b].name)
	for cid in ids:
		var c: Club = pw.clubs[cid]
		_map_row(root_it, cid, c.name, c.display_city(), Crest.icon_for(c))


func _map_row(root_it: TreeItem, cid: String, name: String, sub: String, tex: Texture2D) -> void:
	var it := map_list.create_item(root_it)
	it.custom_minimum_height = 40
	it.set_text(0, "%s\n%s" % [name, sub])
	if tex != null:
		it.set_icon(0, tex)
		it.set_icon_max_width(0, 30)
	it.set_metadata(0, cid)
	if cid == selected_cid:
		it.select(0)


func _apply_map_tab() -> void:
	if map_box != null:
		map_box.visible = map_tab == 0
	if legend != null:
		legend.visible = map_tab == 0
	if map_list != null:
		map_list.visible = map_tab == 0
		map_title.visible = map_tab == 0
	if club_tree != null:
		club_tree.visible = map_tab == 1


func _apply_filter() -> void:
	var kind: String = ["all", "clubs", "schools"][pin_filter]
	for m in [world_map, europe_map]:
		if m != null:
			m.seal_filter = kind
			m.queue_redraw()
	if club_tree != null and club_tree.get_root() != null:
		for it in club_tree.get_root().get_children():
			if it.has_meta("school"):
				it.visible = kind == "all" or (kind == "schools") == bool(it.get_meta("school"))
	if kind == "all" or selected_cid == "" or (kind == "schools") == Schools.is_house(selected_cid):
		return
	var first: TreeItem = null
	if club_tree != null and club_tree.get_root() != null:
		for hdr in club_tree.get_root().get_children():
			if hdr.has_meta("school") and bool(hdr.get_meta("school")) == (kind == "schools") and hdr.get_first_child() != null:
				first = hdr.get_first_child()
				hdr.collapsed = false
				break
	if first == null:
		return
	selected_cid = str(first.get_metadata(0))
	_syncing = true
	first.select(0)
	if world_map != null and map_list != null:
		if Schools.is_house(selected_cid):
			_map_select(Schools.school_of_house(selected_cid))
		elif _preview().clubs.has(selected_cid):
			_map_select(str(_preview().clubs[selected_cid].league_id))
	_syncing = false
	club_tree.scroll_to_item(first)
	if is_instance_valid(info_box) and info_box.is_inside_tree():
		_show_club(selected_cid)


func _on_club_selected() -> void:
	if _syncing:
		return
	var it := club_tree.get_selected()
	if it == null or it.get_metadata(0) == null:
		return
	selected_cid = str(it.get_metadata(0))
	_show_club(selected_cid)


func _nationality() -> String:
	if nationality != "":
		return nationality
	var c: Club = _preview().clubs.get(selected_cid)
	if c != null and Game.loader.countries.has(c.country_id):
		return c.country_id
	return "eng"


func _sync_nationality() -> void:
	if nat_option == null or nationality != "":
		return
	var want := _nationality()
	for i in nat_option.item_count:
		if str(nat_option.get_item_metadata(i)) == want:
			nat_option.select(i)
			return


func _show_club(cid: String) -> void:
	_sync_nationality()
	clear(info_box)
	if cid == "":
		info_box.add_child(UI.h2(T("ui.new_game.unemployed")))
		var note := UI.text("Prose", T("ui.new_game.unemployed_note"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_box.add_child(note)
		sign_btn.text = T("ui.new_game.start_unemployed")
		return
	if Schools.is_house(cid):
		_show_house(cid)
		return
	var tmp: Club = _preview().clubs.get(cid)
	if tmp == null:
		return
	var top := UI.hbox(12)
	var art := UI.image_for("portraits", cid)
	if art != null:
		var tr := TextureRect.new()
		tr.texture = art
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(130, 150)
		top.add_child(tr)
	top.add_child(UI.crest(tmp, 48))
	var tv := UI.vbox(0)
	tv.add_child(UI.h2(tmp.name))
	tv.add_child(UI.meta(tmp.display_city() + ((" · %s %d" % [T("ui.founded"), tmp.founded]) if tmp.founded > 0 else "")))
	var lg: Competition = _preview().competitions.get(tmp.league_id)
	if lg != null:
		tv.add_child(UI.meta(lg.display_name()))
	top.add_child(tv)
	info_box.add_child(top)
	if str(tmp.identity.get("motto", "")) != "":
		info_box.add_child(UI.text("MetaItalic", "«%s»" % tmp.identity["motto"]))
	info_box.add_child(UI.gap(2))
	var kh := UI.hbox(16)
	for tc in tmp.trophy_counts():
		if tc[0] == "ui.league_titles" or int(tc[1]) > 0 or tc[0] == "ui.european_cups":
			kh.add_child(UI.kpi(str(tc[1]), T(tc[0])))
	kh.add_child(UI.kpi(str(tmp.level), T("ui.level")))
	kh.add_child(UI.kpi(Game.galleons(tmp.balance), T("ui.new_game.balance")))
	var obj := WorldGenerator.initial_objective(_preview(), tmp)
	var ok := UI.kpi(T("objective." + obj), T("ui.new_game.expectation"))
	for k in kh.get_children():
		_fit_kpi(k)
	_fixed_kpi(ok)
	kh.add_child(ok)
	info_box.add_child(kh)
	sign_btn.text = T("ui.new_game.sign_with") % tmp.short_name


func _fit_kpi(k: VBoxContainer) -> void:
	var vl := k.get_child(0) as Label
	var cl := k.get_child(1) as Label
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD
	var need := vl.get_theme_font("font").get_string_size(vl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, vl.get_theme_font_size("font_size")).x
	var cf := cl.get_theme_font("font")
	var cs := cl.get_theme_font_size("font_size")
	for word in cl.text.split(" "):
		need = maxf(need, cf.get_string_size(word.to_upper() if cl.uppercase else word, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x + 8.0)
	k.custom_minimum_size.x = ceilf(need) + 2.0


func _fixed_kpi(k: VBoxContainer) -> void:
	var vl := k.get_child(0) as Label
	vl.add_theme_font_size_override("font_size", 15)
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vl.custom_minimum_size = Vector2(170, 40)
	vl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	k.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	k.custom_minimum_size = Vector2(170, 0)


func _show_house(hid: String) -> void:
	var sid := ""
	var house := ""
	for s_id in Game.loader.schools.keys():
		for h in Game.loader.schools[s_id].get("houses", []):
			if Schools.house_id(s_id, str(h)) == hid:
				sid = s_id
				house = str(h)
	var sc: Dictionary = Game.loader.schools.get(sid, {})
	var hname := Loc.name("house." + house, house)
	var tmp := Club.new()
	tmp.id = hid
	tmp.name = hname
	tmp.colors = Game.loader.school_students.get(sid, {}).get("house_colors", {}).get(house, tmp.colors)
	var top := UI.hbox(12)
	top.add_child(UI.crest(tmp, 48))
	var tv := UI.vbox(0)
	tv.add_child(UI.h2(hname))
	tv.add_child(UI.meta(Game.school_name(sid, false)))
	top.add_child(tv)
	info_box.add_child(top)
	info_box.add_child(UI.gap(2))
	var kh := UI.hbox(16)
	var ok := UI.kpi(T("objective.house_cup"), T("ui.new_game.expectation"))
	_fixed_kpi(ok)
	kh.add_child(ok)
	info_box.add_child(kh)
	var note := UI.text("Body", T("ui.new_game.school_note"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_box.add_child(note)
	sign_btn.text = T("ui.new_game.sign_with") % hname


func _update_sign() -> void:
	if sign_btn == null or name_hint == null:
		return
	var empty := name_edit.text.strip_edges() == ""
	sign_btn.disabled = empty
	name_hint.visible = empty


func _start() -> void:
	var seed_value := _preview().seed_value
	var cid := selected_cid
	var mname := name_edit.text.strip_edges()
	if mname == "":
		return
	var nat := _nationality()
	await main.run_blocking(T("ui.loading.new_game"), func(): Game.new_game(cid, mname, nat, seed_value))
	go("inbox")


func _load() -> void:
	var sel := saves_list.get_selected_items()
	if sel.is_empty():
		return
	var sname := str(saves_list.get_item_metadata(sel[0]))
	if await main.run_blocking(T("ui.loading.load"), func(): return Game.load_game(sname)):
		go("inbox")
