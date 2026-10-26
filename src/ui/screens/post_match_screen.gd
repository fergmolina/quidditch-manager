extends UIScreen
## Post-match summary: score, key moments, player ratings, stats and reaction.


func build() -> void:
	var lm := Game.engine.last_match
	if lm == null:
		header(T("ui.post.title"))
		root.add_child(UI.button(T("ui.back"), func(): go("inbox")))
		return
	var r := lm.result
	var home := lm.home
	var away := lm.away
	var f := lm.fixture
	var comp: Competition = Game.world.competitions.get(lm.comp_id)
	var hc := Game.team_as_club(r.home_id)
	var ac := Game.team_as_club(r.away_id)
	var me_home := Game.engine._is_human(r.home_id)
	var my_id := r.home_id if me_home else r.away_id
	var my_score := r.score_home if me_home else r.score_away
	var their := r.score_away if me_home else r.score_home
	var top := UI.wood_panel(12)
	var th := UI.hbox(16)
	var hcrest := UI.crest(hc, 44)
	UI.make_team_clickable(hcrest, hc.id)
	th.add_child(hcrest)
	var hl := UI.label(hc.name, "title", 22, ThemeBuilder.PARCHMENT)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.make_team_clickable(hl, hc.id)
	th.add_child(hl)
	th.add_child(UI.label("%d – %d" % [r.score_home, r.score_away], "title", 36, ThemeBuilder.BRASS))
	var al := UI.label(ac.name, "title", 22, ThemeBuilder.PARCHMENT)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.make_team_clickable(al, ac.id)
	th.add_child(al)
	var acrest := UI.crest(ac, 44)
	UI.make_team_clickable(acrest, ac.id)
	th.add_child(acrest)
	top.add_child(th)
	root.add_child(top)
	var verdict := T("ui.post.won") if my_score > their else (T("ui.post.lost") if my_score < their else T("ui.post.drew"))
	var catcher := Game.player_name(r.snitch_player_id) if r.snitch_player_id != "" else "—"
	var sub := UI.hbox(12)
	sub.add_child(UI.text("BodyMedium", verdict, ThemeBuilder.GREEN if my_score > their else (ThemeBuilder.SEALING_WAX if my_score < their else ThemeBuilder.AMBER)))
	sub.add_child(UI.spacer())
	var att_txt := (" · " + T("ui.attendance") % Game.galleons(int(f["attendance"])).replace(" G", "")) if int(f.get("attendance", 0)) > 0 else ""
	var info := UI.hbox(4)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(UI.meta("%s · %s%s · %s · %s · %s:" % [comp.display_name() if comp else "", Game.venue_text(f), att_txt, T("weather." + r.weather), _dur(r.duration_s), T("ui.col.snitch")]))
	var cm := UI.meta(catcher)
	UI.make_player_clickable(cm, r.snitch_player_id)
	info.add_child(cm)
	var stm := UI.meta("(%s)" % (Game.world.team_name(r.snitch_team_id) if r.snitch_team_id != "" else T("ui.post.no_snitch")))
	UI.make_team_clickable(stm, r.snitch_team_id)
	info.add_child(stm)
	sub.add_child(info)
	root.add_child(sub)
	var cols := UI.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var mine: SimTeam = home if me_home else away
	var rival: SimTeam = away if me_home else home
	var won := my_score > their
	var left := UI.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rp := UI.panel(8)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rv := UI.vbox(6)
	rv.add_child(UI.subtitle(T("ui.post.ratings")))
	var t := UI.table([{"title": T("ui.col.pos"), "width": 36, "align": "center"}, {"title": T("ui.col.name"), "width": 120, "expand": true}, {"title": T("ui.stat.goals"), "width": 50, "align": "right"}, {"title": T("ui.stat.saves"), "width": 56, "align": "right"}, {"title": T("ui.stat.bludger_hits"), "width": 60, "align": "right"}, {"title": T("ui.stat.fouls"), "width": 50, "align": "right"}, {"title": T("ui.col.cond"), "width": 54, "align": "right"}, {"title": T("ui.stat.rating"), "width": 56, "align": "right"}], 240)
	var best: SimPlayer = null
	var best_r := -1.0
	for side_pair in [[home, r.score_home > r.score_away], [away, r.score_away > r.score_home]]:
		var side_team: SimTeam = side_pair[0]
		for cand in side_team.players:
			var cand_r := Progression.match_rating(cand.stats, cand.position, bool(side_pair[1]))
			if cand_r > best_r:
				best_r = cand_r
				best = cand
	for sp in mine.players:
		var rating := Progression.match_rating(sp.stats, sp.position, won)
		var it := UI.row(t, [UI.pos_short(sp.position), sp.name + (" ✚" if sp.injured else "") + (" ⊘" if sp.sent_off else ""), int(sp.stats.get("goals", 0)), int(sp.stats.get("saves", 0)), int(sp.stats.get("bludger_hits_dealt", 0)), int(sp.stats.get("fouls", 0)), int(sp.condition), "%.1f" % rating], sp.id)
		UI.player_cell(it, 1, sp.id)
		it.set_custom_color(7, ThemeBuilder.GREEN if rating >= 7.0 else (ThemeBuilder.SEALING_WAX if rating < 5.5 else ThemeBuilder.INK))
		it.set_custom_font(7, ThemeBuilder.font("table_bold"))
		if sp.injured:
			it.set_custom_color(1, ThemeBuilder.SEALING_WAX)
	t.item_activated.connect(func(): var it := t.get_selected(); if it and Game.world.player(str(it.get_metadata(0))): go("player", {"player_id": str(it.get_metadata(0))}))
	rv.add_child(t)
	UI.fit_rows(t)
	if best != null:
		var tmpl := T("ui.post.best")
		var at := tmpl.find("%s")
		if at < 0:
			rv.add_child(UI.text("Meta", tmpl % [best.name, best_r]))
		else:
			var potm := UI.hbox(4)
			if tmpl.left(at).strip_edges() != "":
				potm.add_child(UI.text("Meta", tmpl.left(at).strip_edges()))
			var potm_name := UI.text("Meta", best.name, ThemeBuilder.BLUE)
			UI.make_player_clickable(potm_name, best.id)
			potm.add_child(potm_name)
			var tail := tmpl.substr(at + 2)
			var best_team := r.home_id if home.players.has(best) else r.away_id
			if best_team != my_id:
				tail = (" · %s" % Game.world.team_short(best_team)) + tail
			potm.add_child(UI.text("Meta", (tail % best_r).strip_edges()))
			rv.add_child(potm)
	rp.add_child(rv)
	left.add_child(rp)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left_gutter := MarginContainer.new()
	left_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_gutter.add_theme_constant_override("margin_right", 14)
	left_gutter.add_child(left)
	left_scroll.add_child(left_gutter)
	cols.add_child(left_scroll)
	var side := UI.vbox(12)
	side.custom_minimum_size = Vector2(380, 0)
	side.size_flags_horizontal = Control.SIZE_SHRINK_END
	var kp := UI.panel(12)
	var kv := UI.vbox(4)
	kv.add_child(UI.subtitle(T("ui.post.key_moments")))
	var shown := 0
	var moments: Array = _key_moments(r.events, 10)
	for e in moments:
		var key: String = e.text_key if tr(e.text_key) != e.text_key else "match." + e.type
		var seed_value := hash("%s:%d:%s" % [str(f["id"]), e.tick, e.type])
		var ckey := Commentary.key_for(Commentary.for_match(lm.comp_id, f), e, seed_value)
		if ckey != "" and not Commentary.is_reaction(e.type):
			key = ckey
		var moment := Say.phrase(key, {"team": Say.entity(e.team_id, Game.club_name(e.team_id)), "player": Say.entity(e.player_id, Game.player_name(e.player_id)),
			"other": Say.entity(e.other_player_id, Game.player_name(e.other_player_id)), "score": Say.plain("%d-%d" % [e.score_home, e.score_away]),
			"severity": Say.key("severity." + str(e.params.get("severity", "")))})
		var l := UI.rich_links_styled("%s  %s" % [e.clock_text(), Say.render(moment, true, seed_value)], "ui", 15)
		kv.add_child(l)
		shown += 1
	if shown == 0:
		kv.add_child(UI.text("MetaItalic", "—"))
	kp.add_child(kv)
	side.add_child(kp)
	var sp2 := UI.panel(12)
	var sv := UI.vbox(2)
	sv.add_child(UI.subtitle(T("ui.match.stats")))
	for pair in [["ui.stat.shots", "shots"], ["ui.stat.saves", "saves"], ["ui.stat.bludger_hits", "bludger_hits_dealt"], ["ui.stat.fouls", "fouls"], ["ui.stat.sightings", "snitch_sightings"], ["ui.stat.possessions", "possessions"]]:
		var h := UI.hbox(4)
		h.add_child(UI.text("Body", T(pair[0])))
		h.add_child(UI.spacer())
		var a := int(mine.stats.get(pair[1], 0))
		var b := int(rival.stats.get(pair[1], 0))
		var la := UI.text("TableBold" if a > b else "TableText", str(a))
		la.custom_minimum_size = Vector2(50, 0)
		la.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(la)
		var lb := UI.text("TableBold" if b > a else "TableText", str(b))
		lb.custom_minimum_size = Vector2(50, 0)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(lb)
		sv.add_child(h)
	sp2.add_child(sv)
	side.add_child(sp2)
	var me := Game.my_club()
	if me != null and (r.home_id == me.id or r.away_id == me.id):
		var bp := UI.panel(12)
		var bv := UI.vbox(4)
		bv.add_child(UI.subtitle(T("from.head_of_house") if Game.world.is_school_mode() else T("ui.menu.board")))
		var conf := float(me.board.get("confidence", 60.0))
		bv.add_child(UI.text("Body", T(("ui.post.house_" if Game.world.is_school_mode() else "ui.post.board_") + ("up" if won else ("flat" if my_score == their else "down")))))
		bv.add_child(UI.bar(conf, 120, true))
		bp.add_child(bv)
		left.add_child(bp)
	if comp != null:
		var others: Array = []
		for of in comp.fixtures_on(int(f["day"])):
			if str(of["id"]) != str(f["id"]) and bool(of.get("played", false)):
				others.append(of)
		if not others.is_empty():
			var op := UI.panel(12)
			var ov := UI.vbox(2)
			ov.add_child(UI.subtitle(T("ui.post.other_results")))
			for of in others.slice(0, 8):
				var orow := UI.hbox(4)
				var oh := UI.text("TableText", Game.world.team_short(str(of["home_id"])))
				UI.make_team_clickable(oh, str(of["home_id"]))
				orow.add_child(oh)
				orow.add_child(UI.text("TableText", "%d – %d" % [int(of.get("score_home", 0)), int(of.get("score_away", 0))]))
				var oa := UI.text("TableText", Game.world.team_short(str(of["away_id"])))
				UI.make_team_clickable(oa, str(of["away_id"]))
				orow.add_child(oa)
				ov.add_child(orow)
			op.add_child(ov)
			side.add_child(op)
	if me != null and (r.home_id == me.id or r.away_id == me.id) and not Game.world.is_school_mode() and str(Game.world.settings.get("talk_done", "")) != str(f["id"]):
		var tp := UI.panel(12)
		var tv := UI.vbox(4)
		tv.add_child(UI.subtitle(T("ui.post.talk")))
		var tl := UI.text("MetaItalic", T("ui.post.talk_hint"))
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(tl)
		var talk_h := UI.hbox(4)
		for tone in TeamTalk.TONES:
			var tb := UI.button(T("talk.tone." + tone), func():
				var res := TeamTalk.post_match(Game.world, me, tone, my_score, their, hash("%s:post" % str(f["id"])))
				Game.world.settings["talk_done"] = str(f["id"])
				Game.mark_dirty()
				tl.text = T(str(res["summary_key"]))
				for c in talk_h.get_children():
					c.disabled = true)
			tb.tooltip_text = T("talk.tone." + tone + ".tip")
			talk_h.add_child(tb)
		tv.add_child(talk_h)
		tp.add_child(tv)
		left.add_child(tp)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.size_flags_horizontal = Control.SIZE_SHRINK_END
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.custom_minimum_size = Vector2(side.custom_minimum_size.x + 16, 0)
	var side_gutter := MarginContainer.new()
	side_gutter.add_theme_constant_override("margin_right", 14)
	side_gutter.add_child(side)
	side_scroll.custom_minimum_size.x += 14
	side_scroll.add_child(side_gutter)
	cols.add_child(side_scroll)
	var bh := UI.hbox()
	bh.add_child(UI.spacer())
	var press_due := not Game.world.is_school_mode() and comp != null and comp.type != Competition.Type.FRIENDLY and bool(Game.world.settings.get("press", true)) and str(Game.world.settings.get("press_done", "")) != str(f["id"]) and Game.engine._is_human(my_id) and not str(my_id).begins_with("nt_")
	if press_due:
		bh.add_child(UI.primary(T("ui.press.go"), func(): go("press", {"fixture_id": str(f["id"])})))
	else:
		bh.add_child(UI.primary(T("ui.post.continue"), func(): go("inbox")))
	root.add_child(bh)


func _dur(s: int) -> String:
	var h := s / 3600
	var m := (s % 3600) / 60
	return T("ui.duration_hm", {"h": h, "m": "%02d" % m}) if h > 0 else T("ui.duration_m", {"m": m})


func _key_moments(events: Array, n: int) -> Array:
	var tiers: Array = [[], [], [], []]
	for e in events:
		if e.importance < MatchEvent.Importance.MAJOR or e.type in ["kickoff", "tactics_change", "night_pause", "long_match_regime"]:
			continue
		match str(e.type):
			"snitch_caught", "match_end":
				tiers[0].append(e)
			"send_off", "injury":
				tiers[1].append(e)
			"goal", "penalty_goal":
				tiers[2].append(e)
			_:
				tiers[3].append(e)
	var keep: Array = []
	for tier in tiers:
		var room := n - keep.size()
		if room <= 0:
			break
		if tier.size() <= room:
			keep.append_array(tier)
			continue
		for i in room:
			keep.append(tier[int(floor((i + 0.5) * tier.size() / float(room)))])
	return events.filter(func(e): return keep.has(e))
