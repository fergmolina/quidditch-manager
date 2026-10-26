extends UIScreen
## My career: manager profile (reputation, rank, seasons, titles, monthly awards), club history
## with from/to/reason/titles/best finish, vacancies to apply for, and resigning.

var body: VBoxContainer


func build() -> void:
	header(T("ui.menu.manager"), str(Game.world.manager.get("name", "")))
	body = UI.vbox(12)
	root.add_child(UI.scroll(body))


func refresh() -> void:
	clear(body)
	var w := Game.world
	var m: Dictionary = w.manager
	var rep := int(m.get("reputation", 0))
	var pp := UI.panel()
	var pv := UI.vbox(8)
	var ph := UI.hbox(24)
	ph.add_child(UI.kpi(str(m.get("name", "")), Loc.name("country." + str(m.get("nationality", "eng")), str(m.get("nationality", "eng")))))
	ph.add_child(UI.kpi(str(rep), T("ui.career.reputation")))
	ph.add_child(UI.kpi(T(Career.rank_key(rep)), T("ui.career.rank")))
	ph.add_child(UI.kpi(str(int(m.get("seasons", 0))), T("ui.career.seasons")))
	ph.add_child(UI.kpi(str(int(m.get("titles", 0))), T("ui.career.titles")))
	ph.add_child(UI.kpi(str(int(m.get("motm_count", 0))), T("award.manager_month")))
	pv.add_child(ph)
	var club := Game.my_club()
	if club != null:
		var parts := T("ui.manager.current").split("%s")
		var sh := UI.hbox(5)
		if parts[0].strip_edges() != "":
			sh.add_child(UI.label(parts[0].strip_edges(), "ui_bold", 15))
		var cl := UI.label(club.name, "ui_bold", 15)
		UI.make_team_clickable(cl, club.id)
		sh.add_child(cl)
		if parts.size() > 1 and parts[1].strip_edges() != "":
			sh.add_child(UI.label(parts[1].strip_edges(), "ui_bold", 15))
		pv.add_child(sh)
	else:
		pv.add_child(UI.label(T("ui.career.unemployed"), "ui_bold", 15))
	pp.add_child(pv)
	body.add_child(pp)
	body.add_child(UI.subtitle(T("ui.manager.history")))
	var career: Array = m.get("career", [])
	var t := UI.table([{"title": T("ui.col.club"), "width": 220, "expand": true}, {"title": T("ui.manager.from"), "width": 80, "align": "right"}, {"title": T("ui.manager.to"), "width": 80, "align": "right"}, {"title": T("ui.manager.reason"), "width": 140}, {"title": T("ui.career.titles"), "width": 70, "align": "right"}, {"title": T("ui.manager.best_pos"), "width": 90, "align": "right"}], 48 + 32 * maxi(career.size(), 1))
	for i in range(career.size() - 1, -1, -1):
		var e: Dictionary = career[i]
		var cid := str(e.get("club_id", ""))
		var from_s := int(e.get("from", e.get("season", w.season)))
		var to_s := int(e.get("to", w.season))
		var titles := 0
		for h in w.history:
			if str(h.get("champion_id", "")) == cid and int(h["season"]) >= from_s and int(h["season"]) <= to_s:
				titles += 1
		var best := 0
		var c: Club = w.club(cid)
		if c != null:
			for k in c.season_summary.keys():
				if int(k) >= from_s and int(k) <= to_s:
					var pos := int(c.season_summary[k].get("pos", 0))
					if pos > 0 and (best == 0 or pos < best):
						best = pos
		var reason := str(e.get("reason", ""))
		var crow := UI.row(t, [Game.club_name(cid), "%d-%02d" % [from_s, (from_s + 1) % 100], ("%d-%02d" % [to_s, (to_s + 1) % 100]) if e.has("to") else "—", T("ui.manager.reason." + reason) if reason != "" else T("ui.manager.reason.current"), str(titles), Game.ordinal(best) if best > 0 else "—"], cid)
		if c != null:
			UI.club_cell(crow, 0, c)
		else:
			UI.team_cell(crow, 0, cid)
	UI.fit_rows(t)
	body.add_child(t)
	body.add_child(UI.subtitle(T("ui.manager.vacancies")))
	var vac := Game.engine.vacancies()
	if vac.is_empty():
		body.add_child(UI.text("MetaItalic", T("ui.manager.no_vacancies")))
	var applied := {}
	for a in m.get("applications", []):
		applied[str(a["club_id"])] = true
	var sent: Dictionary = m.get("applied_vacancies", {})
	var open_now := {}
	for c in vac:
		open_now[c.id] = _vacancy_day(c)
	for k in sent.keys():
		if not open_now.has(k) or int(sent[k]) != int(open_now[k]):
			sent.erase(k)
	for c in vac:
		var h := UI.hbox(10)
		var nl := UI.label(c.name, "ui", 14)
		UI.make_team_clickable(nl, c.id)
		h.add_child(nl)
		var cl := UI.label("· %s · %s %d" % [w.league_of(c.id).display_name() if w.league_of(c.id) != null else "", T("ui.manager.requires"), Career.club_requirement(c)], "ui", 14)
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(cl)
		var cid2: String = c.id
		var vday: int = int(open_now[cid2])
		var done := applied.has(cid2) or sent.has(cid2)
		var b := UI.button(T("ui.manager.applied") if done else T("ui.manager.apply"), func():
			if Game.engine.apply_for(cid2):
				var sv: Dictionary = Game.world.manager.get("applied_vacancies", {})
				sv[cid2] = vday
				Game.world.manager["applied_vacancies"] = sv
			main.toast(T("ui.manager.applied"))
			refresh())
		b.disabled = done
		if not done and Career.club_requirement(c) > rep * GameEngine.APPLICATION_REACH:
			b.disabled = true
			b.tooltip_text = T("ui.manager.out_of_reach")
		h.add_child(b)
		body.add_child(h)
	if club != null and not Game.world.is_school_mode():
		body.add_child(UI.rule())
		var rb := UI.seal_button(T("ui.manager.resign"), _confirm_resign)
		rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		body.add_child(rb)


func _vacancy_day(c: Club) -> int:
	var past: Array = c.history.get("managers", [])
	return int(past[-1].get("until", -1)) if not past.is_empty() else -1


func _confirm_resign() -> void:
	if Game.engine.match_awaits_finish():
		main.toast(T("ui.match.finish_first"), "warning", "warning")
		return
	var dlg := ConfirmationDialog.new()
	dlg.cancel_button_text = T("ui.cancel")
	UI.cancel_right(dlg)
	dlg.title = T("ui.manager.resign")
	dlg.dialog_text = T("ui.manager.resign_confirm") % Game.my_club().name
	dlg.ok_button_text = T("ui.manager.resign")
	dlg.confirmed.connect(func():
		dlg.queue_free()
		Game.engine.resign()
		Game.world_changed.emit()
		go("inbox"))
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()
