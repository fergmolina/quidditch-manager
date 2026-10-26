extends UIScreen
## Encyclopedia: rules, fouls, brooms and clubs, all from data/ and the translation keys. No invented text.

var tab := 0
var body: VBoxContainer


func build() -> void:
	tab = int(params.get("tab", 0))
	header(T("ui.menu.encyclopedia"))
	root.add_child(UI.tabs(T("ui.enc.tabs").split(","), tab, func(i): tab = i; refresh()))
	body = UI.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)


func nav_state() -> Dictionary:
	return {"tab": tab}


func refresh() -> void:
	clear(body)
	match tab:
		0:
			_rules()
		1:
			_fouls()
		2:
			_brooms()
		3:
			_clubs()
		_:
			_world_cups()


func _world_cups() -> void:
	var w := Game.world
	var p := UI.panel(8)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	var art := UI.image_for("art", "world_cup")
	if art != null:
		var tr := TextureRect.new()
		tr.texture = art
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(0, 100)
		v.add_child(tr)
	v.add_child(UI.text("MetaItalic", T("ui.enc.wc_note")))
	var t := UI.table([{"title": T("ui.enc.col.year"), "width": 70, "align": "right"}, {"title": T("ui.enc.champion"), "width": 200, "expand": true}, {"title": T("ui.enc.runner_up"), "width": 200, "expand": true}, {"title": T("ui.col.result"), "width": 90, "align": "center"}], 400)
	var rows: Array = []
	for h in w.history:
		if str(h["competition_id"]).begins_with("comp_world_cup_") and str(h["competition_id"]).ends_with("_final"):
			rows.append(h)
	rows.sort_custom(func(a, b): return int(a["season"]) > int(b["season"]))
	for h in rows:
		var it := UI.row(t, [int(h["season"]), w.team_name(str(h["champion_id"])), w.team_name(str(h.get("runner_up_id", ""))) if str(h.get("runner_up_id", "")) != "" else "—", str(h.get("score", ""))], str(h["season"]))
		UI.team_cell(it, 1, str(h["champion_id"]))
		UI.team_cell(it, 2, str(h.get("runner_up_id", "")))
	v.add_child(t)
	p.add_child(v)
	body.add_child(p)


func _rules() -> void:
	var p := UI.panel()
	var v := UI.vbox(8)
	var intro := UI.text("MetaItalic", T("ui.enc.rules_intro"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	var txt := UI.text("Prose", T("ui.enc.rules_text"))
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(txt)
	var src := UI.text("Meta", T("ui.enc.sources_line"))
	src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(src)
	p.add_child(v)
	body.add_child(UI.scroll(p))


func _fouls() -> void:
	var p := UI.panel(8)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var t := UI.table([{"title": T("ui.col.name"), "width": 150}, {"title": T("ui.enc.col.who"), "width": 90}, {"title": "", "width": 500, "expand": true}], 560)
	for f in Game.loader.fouls:
		var id := str(f["id"])
		var it := UI.row(t, [T("foul." + id), T("ui.enc.foul_who." + str(f.get("who", "any"))), T("foul." + id + ".desc")], id)
		it.set_custom_font(0, ThemeBuilder.font("table_bold"))
		it.set_autowrap_mode(2, TextServer.AUTOWRAP_WORD_SMART)
		it.custom_minimum_height = 40
	p.add_child(t)
	body.add_child(p)


func _brooms() -> void:
	var p := UI.panel(8)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	v.add_child(UI.text("MetaItalic", T("ui.enc.brooms_note")))
	var cols := [{"title": T("ui.col.broom"), "width": 150, "expand": true}, {"title": T("ui.enc.col.manufacturer"), "width": 170}, {"title": T("ui.enc.col.year"), "width": 60, "align": "right"}]
	for k in ["speed", "acceleration", "turning", "braking", "altitude", "stability"]:
		cols.append({"title": T("broom." + k), "width": 58, "align": "center"})
	cols.append({"title": T("ui.finances.price") if tr("ui.finances.price") != "ui.finances.price" else "G", "width": 70, "align": "right"})
	var t := UI.table(cols, 540)
	var list: Array = Game.loader.brooms.values()
	list.sort_custom(func(a, b): return int(a.get("year", 0)) < int(b.get("year", 0)))
	for b in list:
		if int(b.get("available_from", b.get("year", 1900))) > Game.world.season:
			continue
		var vals := [b["model"], str(b.get("manufacturer", "")), int(b.get("year", 0))]
		for k in ["speed", "acceleration", "turning", "braking", "altitude", "stability"]:
			vals.append("")
		vals.append(Game.galleons(int(b.get("price", 0))))
		var it := UI.row(t, vals, str(b["id"]))
		var bi := UI.image_for("brooms", str(b["id"]))
		if bi != null:
			it.set_icon(0, bi)
			it.set_icon_max_width(0, 36)
			it.custom_minimum_height = 30
		for i in 6:
			UI.attr_cell(it, 3 + i, float(b.get(["speed", "acceleration", "turning", "braking", "altitude", "stability"][i], 10)))
		it.set_tooltip_text(0, Loc.name("broom.notes." + str(b["id"]), ""))
	v.add_child(t)
	p.add_child(v)
	body.add_child(p)


func _clubs() -> void:
	var v := UI.vbox(10)
	v.add_child(UI.text("MetaItalic", T("ui.enc.clubs_note")))
	for c in Game.world.clubs_sorted():
		var keys: Array = c.history.get("notes_keys", []).duplicate()
		if keys.is_empty():
			var tag := str(c.identity.get("style_tags", ["balanced"])[0]) if not c.identity.get("style_tags", []).is_empty() else "balanced"
			keys.append("club.generic.style." + (tag if TranslationServer.translate("club.generic.style." + tag) != "club.generic.style." + tag else "balanced"))
			var titles := int(c.history.get("league_titles", 0))
			keys.append(("club.generic.no_titles" if titles == 0 else ("club.generic.one_title" if titles == 1 else "club.generic.titles")))
		var p := UI.panel()
		var cv := UI.vbox(4)
		var h := UI.hbox(10)
		var cr := UI.crest(c, 36)
		UI.make_team_clickable(cr, c.id)
		h.add_child(cr)
		var tv := UI.vbox(0)
		var cn := UI.h2(c.name)
		UI.make_team_clickable(cn, c.id)
		tv.add_child(cn)
		var founded_txt := (" · %s %d" % [T("ui.founded"), c.founded]) if c.founded > 0 else ""
		var parts := []
		for tc in c.trophy_counts():
			if int(tc[1]) > 0 or tc[0] == "ui.league_titles":
				parts.append("%s: %d" % [T(tc[0]), tc[1]])
		tv.add_child(UI.meta("%s%s · %s" % [c.display_city(), founded_txt, " · ".join(parts)]))
		h.add_child(tv)
		h.add_child(UI.spacer())
		h.add_child(UI.link(T("ui.menu.club") + " ▸", func(): go("club", {"club_id": c.id})))
		cv.add_child(h)
		for k in keys:
			var l := UI.text("Prose", "• " + T(str(k)).format({"n": int(c.history.get("league_titles", 0))}))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cv.add_child(l)
		p.add_child(cv)
		v.add_child(p)
	body.add_child(UI.scroll(v))
