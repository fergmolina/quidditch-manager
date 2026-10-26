extends UIScreen
## Board: objective, confidence, manager's reputation.

var body: VBoxContainer


func build() -> void:
	var club := Game.my_club()
	if club == null:
		header(T("ui.menu.board"), "")
		return
	header(T("ui.menu.board"), club.name)
	_link_header_sub(club.id)
	var p := UI.panel()
	body = UI.vbox(8)
	p.add_child(UI.scroll(body))
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(p)


func _link_header_sub(club_id: String) -> void:
	var h: Node = root.get_child(0)
	if h.get_child_count() >= 3 and h.get_child(2) is Label:
		UI.make_team_clickable(h.get_child(2), club_id)


func refresh() -> void:
	var club := Game.my_club()
	if body == null or club == null:
		return
	clear(body)
	var comp := Game.league()
	body.add_child(UI.subtitle(T("ui.board.objective")))
	body.add_child(UI.label(T("objective." + str(club.board.get("objective", "mid_table"))), "title", 22))
	if comp != null and _played_in(comp, club.id) > 0:
		body.add_child(UI.label("%s: %s" % [T("ui.board.current_pos"), Game.ordinal(comp.position_of(club.id))]))
	var rival := Rivalries.board_rival(Game.world, club)
	if rival != "":
		var rl := UI.label(T("ui.board.rival_objective", {"rival": Game.world.team_name(rival)}), "ui_bold", 15)
		UI.make_team_clickable(rl, rival)
		rl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		body.add_child(rl)
		if comp != null and _played_in(comp, club.id) > 0:
			body.add_child(UI.text("Meta", T("ui.board.rival_status", {"rival": Game.world.team_name(rival), "rival_pos": Game.ordinal(comp.position_of(rival))})))
	body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.board.confidence")))
	body.add_child(UI.bar(float(club.board.get("confidence", 60.0)), 300, true))
	var areas: Dictionary = club.board.get("areas", {})
	if not areas.is_empty():
		var ah := UI.hbox(24)
		for k in ["results", "finances", "fans"]:
			ah.add_child(UI.kpi("%d/100" % int(areas.get(k, 0)), T("ui.board.area." + k)))
		body.add_child(ah)
	if club.board.has("ultimatum"):
		body.add_child(UI.label(T("ui.board.ultimatum_active"), "ui_bold", 14, ThemeBuilder.SEALING_WAX))
	body.add_child(UI.label(T("ui.board.manager") % [str(Game.world.manager.get("name", "")), int(Game.world.manager.get("reputation", 1000))]))
	body.add_child(UI.rule())
	if club.board.has("request"):
		var rq: Dictionary = club.board["request"]
		body.add_child(UI.subtitle(T("ui.board.pending")))
		var txt := T("ui.board.req." + str(rq["kind"])) % (T("facility." + str(rq.get("key", ""))) if rq["kind"] == "facility" else (T("pos." + str(rq.get("key", ""))) if rq["kind"] == "sell_surplus" else str(rq.get("limit", ""))))
		body.add_child(UI.text("Body", txt + " · " + T("ui.until") + " " + Game.date_text(int(rq["until"]))))
		body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.board.requests")))
	var h := UI.hbox()
	h.add_child(UI.button(T("ui.board.ask_budget"), _ask_budget))
	h.add_child(UI.button(T("ui.board.ask_wages"), _ask_wages))
	h.add_child(UI.button(T("ui.board.ask_facility"), _ask_facility))
	if WDate.month(Game.world.today) == 8 and not bool(club.board.get("negotiated", false)):
		h.add_child(UI.button(T("ui.board.negotiate"), _negotiate))
	body.add_child(h)
	body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.career.title")))
	var rep := int(Game.world.manager.get("reputation", 0))
	var ch := UI.hbox(24)
	ch.add_child(UI.kpi(str(rep), T("ui.career.reputation")))
	ch.add_child(UI.kpi(T(Career.rank_key(rep)), T("ui.career.rank")))
	ch.add_child(UI.kpi(str(int(Game.world.manager.get("seasons", 0))), T("ui.career.seasons")))
	ch.add_child(UI.kpi(str(int(Game.world.manager.get("titles", 0))), T("ui.career.titles")))
	body.add_child(ch)
	var nr := Career.next_rank(rep)
	var note := T("ui.career.note") + (" " + T("ui.career.next", {"n": int(nr[0]), "rank": T(str(nr[1]))}) if not nr.is_empty() else "")
	var cl := UI.text("MetaItalic", note)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(cl)
	body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.board.hall")))
	var hf := UI.hbox(24)
	for tc in club.trophy_counts():
		hf.add_child(UI.kpi(str(tc[1]), T(tc[0])))
	var last_season := int(club.history.get("last_title", 0))
	var last_year := int(club.history.get("last_league_title", 0))   # [QTTA c7]
	var last_txt := ("%d-%02d" % [last_season, (last_season + 1) % 100]) if last_season > 0 else (str(last_year) if last_year > 0 else "—")
	hf.add_child(UI.kpi(last_txt, T("ui.board.last_title")))
	body.add_child(hf)
	var legends := _legends(club)
	if not legends.is_empty():
		body.add_child(UI.text("Meta", T("ui.board.legends")))
		for l in legends:
			var ll := UI.text("Body", str(l[0]))
			UI.make_player_clickable(ll, str(l[1]))
			ll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			body.add_child(ll)
	body.add_child(UI.rule())
	body.add_child(UI.subtitle(T("ui.board.seasons")))
	body.add_child(UI.label(_history_text(), "ui", 14))


func _played_in(comp: Competition, club_id: String) -> int:
	for row in comp.standings():
		if str(row["club_id"]) == club_id:
			return int(row.get("pj", 0))
	return 0


func _legends(club: Club) -> Array:
	var w := Game.world
	var out: Array = []
	var by_goals := {}
	for a in w.awards:
		if str(a.get("club_id", "")) == club.id and str(a["kind"]) != "team_of_season":
			out.append(["%d-%02d · %s — %s" % [int(a["season"]), (int(a["season"]) + 1) % 100, T("award." + str(a["kind"])), Game.player_name(str(a["player_id"]))], str(a["player_id"])])
	for p in w.players.values():
		if p.club_id != club.id:
			continue
		var g := 0
		for k in p.season_stats.keys():
			g += int(p.season_stats[k].get("goals", 0))
		if g >= 40:
			by_goals[p.id] = g
	var ids := by_goals.keys()
	ids.sort_custom(func(a, b): return by_goals[a] > by_goals[b] if by_goals[a] != by_goals[b] else str(a) < str(b))
	for pid in ids.slice(0, 3):
		out.append([T("ui.board.top_scorer_hist") % [Game.player_name(str(pid)), by_goals[pid]], str(pid)])
	return out.slice(0, 8)


func _negotiate() -> void:
	var club := Game.my_club()
	var dlg := ConfirmationDialog.new()
	dlg.cancel_button_text = T("ui.cancel")
	UI.cancel_right(dlg)
	dlg.title = T("ui.board.negotiate")
	dlg.ok_button_text = T("ui.board.propose")
	var v := UI.vbox(8)
	v.custom_minimum_size = Vector2(440, 0)
	v.add_child(UI.text("Body", T("ui.board.negotiate_note")))
	var cur := str(club.board.get("objective", "mid_table"))
	var chosen: Array = [cur]
	v.add_child(UI.option([["title", T("objective.title")], ["top_half", T("objective.top_half")], ["mid_table", T("objective.mid_table")], ["avoid_last", T("objective.avoid_last")]], cur, func(val): chosen[0] = str(val)))
	dlg.add_child(v)
	dlg.confirmed.connect(func():
		var rank := {"title": 0, "top_half": 1, "mid_table": 2, "avoid_last": 3}
		var minpos := {"title": 3, "top_half": 7, "mid_table": 9, "avoid_last": 12}
		var diff: int = int(rank[chosen[0]]) - int(rank[cur])
		club.board["objective"] = chosen[0]
		club.board["objective_min_pos"] = minpos[chosen[0]]
		club.board["negotiated"] = true
		if diff < 0:
			club.transfer_budget += 1500 * -diff
			club.board["confidence"] = clampf(float(club.board.get("confidence", 60.0)) + 4.0, 0.0, 100.0)
			Inbox.tell(Game.world, &"from.board", "msg.objective_up.subject", "msg.objective_up.body", {"objective": Say.key("objective." + chosen[0]), "amount": Say.money(1500 * -diff)})
		elif diff > 0:
			club.transfer_budget = int(club.transfer_budget * 0.7)
			club.board["confidence"] = clampf(float(club.board.get("confidence", 60.0)) - 4.0, 0.0, 100.0)
			Inbox.tell(Game.world, &"from.board", "msg.objective_down.subject", "msg.objective_down.body", {"objective": Say.key("objective." + chosen[0])})
		dlg.queue_free()
		Game.world_changed.emit())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _ask_budget() -> void:
	var club := Game.my_club()
	var conf: float = float(club.board.get("confidence", 60.0))
	if conf >= 70.0 and club.balance > 1000 and int(club.board.get("asked_budget", 0)) != Game.world.season:
		var add := int(club.balance * 0.2)
		club.transfer_budget += add
		club.board["confidence"] = conf - 5.0
		club.board["asked_budget"] = Game.world.season
		Inbox.tell(Game.world, &"from.board", "msg.budget_granted.subject", "msg.budget_granted.body", {"amount": Say.money(add)})
	else:
		club.board["confidence"] = maxf(0.0, conf - 3.0)
		Inbox.tell(Game.world, &"from.board", "msg.budget_denied.subject", "msg.budget_denied.body")
	Game.world_changed.emit()


func _ask_wages() -> void:
	var club := Game.my_club()
	var conf: float = float(club.board.get("confidence", 60.0))
	if conf >= 60.0 and int(club.board.get("asked_wages", 0)) != Game.world.season:
		var add := int(club.wage_budget_weekly * 0.15)
		club.wage_budget_weekly += add
		club.board["confidence"] = conf - 5.0
		club.board["asked_wages"] = Game.world.season
		Inbox.tell(Game.world, &"from.board", "msg.wages_granted.subject", "msg.wages_granted.body", {"amount": Say.money(add)})
	else:
		club.board["confidence"] = maxf(0.0, conf - 2.0)
		Inbox.tell(Game.world, &"from.board", "msg.budget_denied.subject", "msg.budget_denied.body")
	Game.world_changed.emit()


func _ask_facility() -> void:
	var club := Game.my_club()
	var conf: float = float(club.board.get("confidence", 60.0))
	var lowest := ""
	for k in ["training", "medical", "broom_workshop", "academy"]:
		var lv: int = club.academy_level() if k == "academy" else int(club.facilities.get(k, 1))
		var lw: int = (club.academy_level() if lowest == "academy" else int(club.facilities.get(lowest, 1))) if lowest != "" else 99
		if lv < 5 and lv < lw:
			lowest = k
	if lowest != "" and conf >= 70.0 and int(club.board.get("asked_facility", 0)) != Game.world.season:
		club.facilities[lowest] = (club.academy_level() if lowest == "academy" else int(club.facilities.get(lowest, 1))) + 1
		club.board["confidence"] = conf - 8.0
		club.board["asked_facility"] = Game.world.season
		Inbox.tell(Game.world, &"from.board", "msg.facility_granted.subject", "msg.facility_granted.body", {"facility": Say.key("facility." + lowest)})
	else:
		club.board["confidence"] = maxf(0.0, conf - 2.0)
		Inbox.tell(Game.world, &"from.board", "msg.budget_denied.subject", "msg.budget_denied.body")
	Game.world_changed.emit()


func _history_text() -> String:
	var club := Game.my_club()
	var parts := []
	var keys := club.season_summary.keys()
	keys.sort()
	for k in keys:
		var s: Dictionary = club.season_summary[k]
		parts.append("%s: %s (%s)" % [k, Game.ordinal(int(s["pos"])), T("ui.pts_n") % int(s["pts"])])
	return "\n".join(parts)
