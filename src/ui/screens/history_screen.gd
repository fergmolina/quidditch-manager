extends UIScreen
## History: champions by season and records of the game world.

var body: VBoxContainer
var awards_comp := ""
var champions_group := ""


func build() -> void:
	header(T("ui.menu.history"))
	var p := UI.panel()
	body = UI.vbox(6)
	p.add_child(UI.scroll(body))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(p)


func refresh() -> void:
	clear(body)
	body.add_child(UI.subtitle(T("ui.history.champions")))
	if Game.world.history.is_empty():
		body.add_child(UI.label(T("ui.history.none"), "ui_italic", 14, ThemeBuilder.INK_SOFT))
	else:
		var gopts := [["", T("ui.inbox.all")]]
		for g in ["domestic", "continental", "international", "schools"]:
			gopts.append([g, T("ui.menu.schools") if g == "schools" else T("ui.comp_group." + g)])
		var gopt := UI.option(gopts, champions_group, func(v): champions_group = str(v); refresh())
		gopt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		body.add_child(gopt)
	var t := UI.table([{"title": T("ui.col.season"), "width": 90}, {"title": T("ui.col.competition"), "width": 300, "expand": true}, {"title": T("ui.col.champion"), "width": 240}], 360)
	for h in Game.world.history:
		var cid := str(h["competition_id"])
		if champions_group != "" and UI.competition_group(cid) != champions_group:
			continue
		var wc := cid.begins_with("comp_world_cup")
		var season_txt := str(int(h["season"])) if wc else "%d-%02d" % [int(h["season"]), (int(h["season"]) + 1) % 100]
		var hrow := UI.row(t, [season_txt, _competition_name(h), Game.world.team_name(str(h["champion_id"]))], cid)
		UI.team_cell(hrow, 2, str(h["champion_id"]))
	body.add_child(UI.table_card(t))
	Records.seed_canon(Game.world)
	body.add_child(UI.subtitle(T("ui.records.title")))
	var rt := UI.table([{"title": T("ui.records.record"), "width": 220}, {"title": T("ui.records.value"), "width": 110, "align": "right"}, {"title": T("ui.records.holder"), "width": 360, "expand": true}, {"title": T("ui.col.season"), "width": 90}], 48 + 32 * 6)
	UI.fit_rows(rt)
	for key in ["fastest_catch", "longest_match", "highest_score", "biggest_margin", "season_goals"]:
		var rec: Dictionary = Game.world.records.get(key, {})
		if rec.is_empty():
			continue
		var holder := str(rec.get("text", "")) + ((" · " + Say.text(Say.comp(str(rec["competition_id"])))) if rec.has("competition_id") else "") + (" [QTTA]" if bool(rec.get("canon", false)) else "")
		var rrow := UI.row(rt, [T("ui.records." + key), Records.format_value(key, float(rec["value"])), holder, str(int(rec.get("season", 0)))])
		if str(rec.get("player_id", "")) != "":
			UI.player_cell(rrow, 2, str(rec["player_id"]))
		elif str(rec.get("club_id", "")) != "":
			UI.team_cell(rrow, 2, str(rec["club_id"]))
	body.add_child(UI.table_card(rt))
	body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.history.awards")))
	var comp_ids: Array = []
	for a in Game.world.awards:
		var acid := str(a["competition_id"])
		if str(a["kind"]) != "team_of_season" and not comp_ids.has(acid):
			comp_ids.append(acid)
	if awards_comp == "" or not comp_ids.has(awards_comp):
		var mine := Game.league()
		awards_comp = mine.id if mine != null and comp_ids.has(mine.id) else (str(comp_ids[0]) if not comp_ids.is_empty() else "")
	if not comp_ids.is_empty():
		var by_group := {"domestic": [], "continental": [], "international": [], "schools": []}
		for c in comp_ids:
			by_group[UI.competition_group(str(c))].append([c, Say.text(Say.comp(str(c)))])
		var opts: Array = []
		for g in ["domestic", "continental", "international", "schools"]:
			var grp: Array = by_group[g]
			if grp.is_empty():
				continue
			grp.sort_custom(func(a, b): return str(a[1]) < str(b[1]))
			opts.append([null, T("ui.menu.schools") if g == "schools" else T("ui.comp_group." + g)])
			opts.append_array(grp)
		var opt := UI.option(opts, awards_comp, func(v): awards_comp = str(v); refresh())
		opt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		body.add_child(opt)
	var arows: Array = []
	for a in Game.world.awards:
		if str(a["kind"]) == "team_of_season" or str(a["competition_id"]) != awards_comp:
			continue
		arows.append(a)
	if arows.is_empty():
		body.add_child(UI.text("MetaItalic", T("ui.history.none")))
	else:
		var at := UI.table([{"title": T("ui.col.season"), "width": 80}, {"title": T("ui.history.col.award"), "width": 260}, {"title": T("ui.col.name"), "width": 200, "expand": true}, {"title": T("ui.col.club"), "width": 200, "expand": true}, {"title": T("ui.records.value"), "width": 220}], 48 + 32 * arows.size())
		UI.fit_rows(at)
		for a in arows:
			var note := T("award." + str(a["kind"]) + ".note") if tr("award." + str(a["kind"]) + ".note") != "award." + str(a["kind"]) + ".note" else ""
			var aid := str(a.get("club_id", ""))
			var arow := UI.row(at, ["%d-%02d" % [int(a["season"]), (int(a["season"]) + 1) % 100], T("award." + str(a["kind"])), Game.player_name(str(a["player_id"])), Game.club_name(aid) if aid != "" else "—", ("%s %s" % [str(a.get("value", "")), note]).strip_edges()])
			UI.player_cell(arow, 2, str(a["player_id"]))
			UI.team_cell(arow, 3, aid)
		body.add_child(UI.table_card(at))
	body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.history.canon")))
	for cid in Game.loader.club_ids():
		var c: Club = Game.world.club(cid)
		if c == null:
			continue
		var ch := UI.hbox(6)
		var cn := UI.label(c.name, "ui", 14)
		UI.make_team_clickable(cn, c.id)
		ch.add_child(cn)
		ch.add_child(UI.label("— %s: %d" % [T("ui.league_titles"), int(c.history.get("league_titles", 0))], "ui", 14))
		body.add_child(ch)
	body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.history.transfers")))
	var moves: Array = Game.world.transfers.filter(func(tr_): return not World.is_release(tr_)).slice(0, 30)
	var tt := UI.table([{"title": T("ui.col.date"), "width": 100}, {"title": T("ui.col.name"), "width": 200, "expand": true}, {"title": T("ui.history.col.from"), "width": 200, "expand": true}, {"title": T("ui.history.col.to"), "width": 200, "expand": true}, {"title": T("ui.history.col.fee"), "width": 110, "align": "right"}], 48 + 32 * maxi(moves.size(), 1))
	for tr_ in moves:
		var from_id := str(tr_["from_id"])
		var to_id := str(tr_["to_id"])
		var trow := UI.row(tt, [WDate.to_iso(int(tr_["day"])), Game.player_name(str(tr_["player_id"])), (Game.club_name(from_id) if from_id != "" else T("ui.free_agent")), Game.club_name(to_id), (T("ui.loan_badge") if bool(tr_.get("loan", false)) else Game.galleons(int(tr_["fee"])))])
		UI.player_cell(trow, 1, str(tr_["player_id"]))
		UI.team_cell(trow, 2, from_id)
		UI.team_cell(trow, 3, to_id)
	body.add_child(UI.table_card(tt))


func _competition_name(h: Dictionary) -> String:
	var cid := str(h["competition_id"])
	if str(h.get("name", "")) != "":
		var tmp := Competition.new()
		tmp.id = cid
		tmp.name = str(h["name"])
		return tmp.display_name()
	var comp: Competition = Game.world.competitions.get(cid)
	if comp != null:
		return comp.display_name()
	if cid.begins_with("comp_school_"):
		var sid := "school_" + cid.trim_prefix("comp_school_").get_slice("_", 0)
		return T("ui.history.school_cup") % Game.school_name(sid)
	if cid.begins_with("comp_world_cup"):
		return T("ui.history.world_cup")
	if cid.begins_with("comp_european_cup"):
		return T("ui.history.european_cup")
	return cid
