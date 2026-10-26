extends UIScreen
## Match in "text highlights" mode: event-by-event commentary, score, clock,
## live tactics (applied at the next stoppage) and timeout.

const SPEEDS := [[0, "ui.match.step"], [1, "ui.match.slow"], [2, "ui.match.normal"], [3, "ui.match.fast"]]
## Commentary view pacing: at slow and normal speed each line stays on screen this long (real seconds) and the quiet
## play in between runs through at once; fast advances a fixed number of ticks per frame.
const LINE_HOLD := [0.0, 3.2, 1.8, 0.0]
## Extra hold after the big moments (slow and normal speeds).
const HOLD_GOAL := 1.2
const HOLD_SIGHTED := 1.8
const HOLD_CATCH := 2.5
## Bludger hits come by the dozen in a long match: at most one line per this much match time; the hits in between are
## counted and summed up in the next line. Display only: the simulation and its events are untouched.
const BLUDGER_GAP_S := 240
## No-repeat window: a commentary text used in the last few lines gives way to another variant when there is one.
const RECENT_KEYS := 10
## The side panel (talk, stakes, my team, live tactics, stats): 312 px of content inside the card's padding, plus the
## room its scroll keeps for the scrollbar.
const SIDE_PANEL_MARGIN := 10
const SIDE_PANEL_CONTENT_W := 312
const SIDE_PANEL_W := SIDE_PANEL_CONTENT_W + 2 * SIDE_PANEL_MARGIN + UI.SCROLL_GUTTER

var ctx: GameEngine.PendingMatch
var sim: MatchSim
var me_home: bool
var score_label: Label
var clock_label: Label
var snitch_label: Label
var log: RichTextLabel
var log_scroll: ScrollContainer
var cond_box: VBoxContainer
var stakes_box: VBoxContainer
var counter_label: Label
var _stakes_sig := ""
var stats_box: VBoxContainer
var speed := 2
var running := false
var finished := false
var timer := 0.0
var min_imp := 3
var pending_tactics: Dictionary = {}
var my_team: SimTeam
var rival_team: SimTeam
var controls: HBoxContainer
var tactics_panel: VBoxContainer
var end_box: HBoxContainer
var talk_box: VBoxContainer
var replay_btn: Button
var play_btn: Button
var commentator := ""
var end_replay_btn: Button
var pitch: Pitch2D
var view_mode := "text"
var talk_pending := false
var talks_given := 0
var _silent := false
var _hud_sig := ""
var finish_btn: Button
var _end_armed_ms := 0
var _hold := 0.0
var _batch_lines := 0
var _batch_kinds: Dictionary = {}
var _last_bludger_s := -100000
var _bludgers_hidden := 0
var _recent_keys: Array[String] = []
var _variant_n: Dictionary = {}
var timeout_btn: Button
var speed_opt: OptionButton


func build() -> void:
	ctx = Game.engine.pending_match
	if ctx == null:
		header(T("ui.match.none"))
		root.add_child(UI.button(T("ui.back"), func(): go("inbox")))
		return
	sim = ctx.sim
	var f: Dictionary = ctx.fixture
	me_home = Game.engine._is_human(str(f["home_id"]))
	my_team = ctx.home if me_home else ctx.away
	rival_team = ctx.away if me_home else ctx.home
	finished = sim.is_over()

	var top := UI.wood_panel(10)
	var th := UI.hbox(16)
	var hc: Club = Game.team_as_club(str(f["home_id"]))
	var ac: Club = Game.team_as_club(str(f["away_id"]))
	th.add_child(UI.club_stripe(hc, 36))
	var hl := UI.label(hc.name, "title", 22, ThemeBuilder.PARCHMENT)
	hl.clip_text = true
	hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(hl)
	score_label = UI.label("0 – 0", "title", 30, ThemeBuilder.BRASS)
	th.add_child(score_label)
	var al := UI.label(ac.name, "title", 22, ThemeBuilder.PARCHMENT)
	al.clip_text = true
	al.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(al)
	th.add_child(UI.club_stripe(ac, 36))
	top.add_child(th)
	root.add_child(top)
	var info := UI.hbox(16)
	clock_label = UI.label(_clock(0), "table_bold", 16)
	info.add_child(clock_label)
	snitch_label = UI.label(T("ui.match.snitch_free"), "ui_medium", 15, ThemeBuilder.INK_SOFT)
	info.add_child(snitch_label)
	info.add_child(UI.spacer())
	commentator = Commentary.for_match(ctx.comp_id, f)
	var info_txt := "%s · %s · %s · %s" % [Game.venue_text(f), str(f.get("hour", "")), Game.date_text(int(f["day"])), T("weather." + sim.weather)]
	if commentator != "":
		info_txt += " · " + T("ui.match.commentator") % Commentary.display_name(commentator)
	info.add_child(UI.label(info_txt, "ui_italic", 14, ThemeBuilder.INK_SOFT))
	root.add_child(info)

	var cols := UI.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var lp := UI.panel(10)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lv := UI.vbox(6)
	lp.add_child(lv)
	pitch = Pitch2D.new()
	pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pitch.custom_minimum_size = Vector2(0, 430)
	pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pitch.size_flags_stretch_ratio = 3.0
	pitch.visible = false
	var cap := 20000
	if hc != null and str(f.get("venue", "")).begins_with("ground:"):
		cap = Grounds.capacity_of(hc)
	else:
		var mcomp: Competition = Game.world.competitions.get(ctx.comp_id)
		cap = Grounds.neutral_capacity(Game.loader, mcomp.type if mcomp != null else "default")
	pitch.capacity = cap
	pitch.fill = clampf(float(f.get("attendance", cap * 0.7)) / maxf(cap, 1.0), 0.3, 1.0)
	pitch.setup(sim, hc, ac)
	pitch.replay_started.connect(func(): set_meta("was_running", running); running = false)
	pitch.replay_finished.connect(func(): running = bool(get_meta("was_running", false)) and not finished)
	pitch.replay_started.connect(func(): if end_replay_btn: end_replay_btn.text = T("ui.match.replay_skip"))
	pitch.replay_finished.connect(func(): if end_replay_btn: end_replay_btn.text = T("ui.match.replay"))
	lv.add_child(pitch)
	log = UI.rich("")
	log.scroll_active = true
	log.fit_content = false
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log.custom_minimum_size = Vector2(0, 300)
	var bold := FontVariation.new()
	bold.base_font = ThemeBuilder.font("prose")
	bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	bold.fallbacks = ThemeBuilder.font("prose").fallbacks
	log.add_theme_font_override("bold_font", bold)
	log.add_theme_font_override("italics_font", ThemeBuilder.font("title_italic"))
	log.add_theme_font_override("bold_italics_font", ThemeBuilder.font("title_italic"))
	log.add_theme_font_size_override("bold_font_size", int(round(17 * Settings.text_scale)))
	log.add_theme_font_size_override("italics_font_size", int(round(18 * Settings.text_scale)))
	log.add_theme_font_size_override("bold_italics_font_size", int(round(18 * Settings.text_scale)))
	lv.add_child(log)
	controls = UI.hbox(6)
	play_btn = UI.primary("▶ " + T("ui.match.play"), _toggle_play)
	play_btn.custom_minimum_size = Vector2(120, 32)
	controls.add_child(play_btn)
	var nb := UI.button("⏭ " + T("ui.match.next_event"), _next_event)
	nb.tooltip_text = T("ui.match.next_event_tip")
	controls.add_child(nb)
	view_mode = str(Game.world.settings.get("match_view", "2d"))
	var vo := UI.option([["text", T("ui.match.view_text")], ["2d", T("ui.match.view_2d")], ["score", T("ui.match.view_score")]], view_mode, _set_view, 128)
	vo.tooltip_text = T("ui.match.view")
	vo.fit_to_longest_item = false
	controls.add_child(vo)
	var items := []
	for s in SPEEDS:
		items.append([s[0], T(s[1])])
	var so := UI.option(items, speed, func(v): speed = int(v), 96)
	so.tooltip_text = T("ui.match.speed")
	so.fit_to_longest_item = false
	controls.add_child(so)
	speed_opt = so
	min_imp = int(Game.world.settings.get("match_detail", 3))
	controls.add_child(UI.spacer())
	replay_btn = UI.button(T("ui.match.replay"), func():
		if pitch.is_busy():
			pitch.skip_replay()
		else:
			pitch.replay_last_play())
	replay_btn.tooltip_text = T("ui.match.replay_tip")
	replay_btn.disabled = true
	replay_btn.custom_minimum_size = Vector2(0, 32)
	controls.add_child(replay_btn)
	timeout_btn = UI.seal_button(T("ui.match.timeout"), _timeout)
	controls.add_child(timeout_btn)
	var skip_btn := UI.button("⏭⏭ " + T("ui.match.sim_to_end"), _sim_to_end)
	skip_btn.tooltip_text = T("ui.match.sim_to_end_tip")
	skip_btn.custom_minimum_size = Vector2(0, 32)
	controls.add_child(skip_btn)
	lv.add_child(controls)
	end_box = UI.hbox()
	end_box.visible = false
	end_replay_btn = UI.button(T("ui.match.replay"), func():
		if pitch.is_busy():
			pitch.skip_replay()
		else:
			pitch.replay_last_play())
	end_box.add_child(end_replay_btn)
	end_box.add_child(UI.spacer())
	finish_btn = UI.button(T("ui.match.finish"), _finish, true)
	end_box.add_child(finish_btn)
	lv.add_child(end_box)
	cols.add_child(lp)

	var rp := UI.panel(SIDE_PANEL_MARGIN)
	rp.custom_minimum_size = Vector2(SIDE_PANEL_W, 0)
	rp.size_flags_horizontal = Control.SIZE_SHRINK_END
	var rv := UI.vbox(6)
	rp.add_child(UI.scroll(rv))
	talk_box = UI.vbox(6)
	rv.add_child(talk_box)
	stakes_box = UI.vbox(2)
	rv.add_child(stakes_box)
	rv.add_child(UI.subtitle(T("ui.match.my_team")))
	cond_box = UI.vbox(2)
	rv.add_child(cond_box)
	rv.add_child(UI.rule())
	rv.add_child(UI.subtitle(T("ui.match.live_tactics")))
	var ap := CheckBox.new()
	ap.text = T("ui.match.autopause")
	ap.tooltip_text = T("ui.match.autopause_tip")
	ap.button_pressed = bool(Game.world.settings.get("match_autopause_snitch", true))
	ap.toggled.connect(func(on): Game.world.settings["match_autopause_snitch"] = on)
	rv.add_child(ap)
	counter_label = UI.text("MetaItalic", "")
	counter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(counter_label)
	tactics_panel = UI.vbox(4)
	rv.add_child(tactics_panel)
	_build_live_tactics()
	rv.add_child(UI.rule())
	rv.add_child(UI.subtitle(T("ui.match.stats")))
	stats_box = UI.vbox(2)
	rv.add_child(stats_box)
	cols.add_child(rp)
	_silent = true
	_append_events(sim.result.events)
	_silent = false
	_apply_view()
	if finished:
		_show_end_state()
	talk_pending = not finished and sim.tick == 0
	_update_hud()
	_show_talk()
	set_process(true)


func _build_live_tactics() -> void:
	var t: Dictionary = my_team.tactics
	var rows := [
		["mentality", UI.slider(float(t.get("mentality", 10)), func(v): _queue("mentality", int(v)))],
		["seeker_catch", UI.option([["always", T("seeker.always")], ["if_wins", T("seeker.if_wins")], ["ahead_by", T("seeker.ahead_by")]], t.get("seeker_catch", "always"), func(v): _queue("seeker_catch", v))],
		["seeker_ahead_by", UI.option([[0, "0"], [30, "+30"], [50, "+50"], [100, "+100"], [150, "+150"], [200, "+200"]], int(t.get("seeker_ahead_by", 50)), func(v): _queue("seeker_ahead_by", int(v)))],
		["beater_instruction", UI.option([["nearest", T("beaters.nearest")], ["hunt_seeker", T("beaters.hunt_seeker")], ["protect_seeker", T("beaters.protect_seeker")], ["protect_chasers", T("beaters.protect_chasers")], ["punish_carrier", T("beaters.punish_carrier")], ["dopplebeater", T("beaters.dopplebeater")], ["backbeat", T("beaters.backbeat")]], t.get("beater_instruction", "nearest"), func(v): _queue("beater_instruction", v))],
		["chaser_formation", UI.option([["free", T("formation.free")], ["hawkshead", T("formation.hawkshead")], ["porskoff", T("formation.porskoff")], ["shimmy", T("formation.shimmy")], ["reverse_pass", T("formation.reverse_pass")], ["looping", T("formation.looping")]], t.get("chaser_formation", "free"), func(v): _queue("chaser_formation", v))],
		["keeper_position", UI.option([["stay", T("keeper.stay")], ["rush", T("keeper.rush")], ["starfish", T("keeper.starfish")], ["double_eight", T("keeper.double_eight")]], t.get("keeper_position", "stay"), func(v): _queue("keeper_position", v))],
		["chaser_defence", UI.option([["zone", T("defence.zone")], ["pincer", T("defence.pincer")], ["mark", T("defence.mark")]], SimTactics.defence_of(t), func(v): _queue("chaser_defence", v))],
		["hard_play", UI.slider(float(t.get("hard_play", 10)), func(v): _queue("hard_play", int(v)))],
		["time_wasting", UI.slider(float(t.get("time_wasting", 10)), func(v): _queue("time_wasting", int(v)))],
	]
	for r in rows:
		var h := UI.hbox(4)
		var l := UI.label(T("tactic." + r[0]), "ui", 13)
		l.custom_minimum_size = Vector2(110, 0)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(l)
		var c: Control = r[1]
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if c is OptionButton:
			(c as OptionButton).fit_to_longest_item = false
			c.custom_minimum_size = Vector2(120, 32)
		h.add_child(c)
		tactics_panel.add_child(h)
	var club: Club = Game.world.club(my_team.id)
	if club != null and club.manager_is_human:
		club.ensure_tactic_sets()
	if club != null and club.tactic_sets.size() == 3:
		var sh := UI.hbox(4)
		for i in 3:
			var idx := i
			sh.add_child(UI.button(T("ui.tactics.set." + str(club.tactic_sets[i]["name"])), func(): _load_set(club, idx)))
		tactics_panel.add_child(sh)
	var tn := UI.text("MetaItalic", T("ui.match.tactics_note"))
	tn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tactics_panel.add_child(tn)


func _load_set(club: Club, i: int) -> void:
	if finished:
		return
	var t: Dictionary = club.tactic_sets[i]["tactics"]
	for k in ["mentality", "seeker_catch", "seeker_ahead_by", "beater_instruction", "chaser_formation", "chaser_defence", "hard_play", "time_wasting", "tempo", "pass_style", "long_shots", "pressing"]:
		if t.has(k):
			pending_tactics[k] = t[k]
	sim.queue_tactics(my_team, pending_tactics.duplicate())
	_append_line("[color=#5C4A36][i]%s[/i][/color]" % (T("ui.match.queued") % T("ui.tactics.set." + str(club.tactic_sets[i]["name"]))))


func _queue(key: String, value) -> void:
	if finished:
		return
	pending_tactics[key] = value
	sim.queue_tactics(my_team, {key: value})
	_append_line("[color=#5C4A36][i]%s[/i][/color]" % (T("ui.match.queued") % T("tactic." + key)))


func _timeout() -> void:
	if finished or not sim.can_timeout(my_team):
		return
	sim.request_timeout(my_team)
	running = false
	talk_pending = true
	_append_events()
	_update_hud()
	_show_talk()


func _set_view(v) -> void:
	view_mode = str(v)
	Game.world.settings["match_view"] = view_mode
	_apply_view()


func _apply_view() -> void:
	pitch.visible = view_mode == "2d"
	if end_replay_btn != null and finished:
		end_replay_btn.visible = view_mode == "2d"
	log.visible = view_mode != "score"
	if view_mode == "2d":
		log.custom_minimum_size = Vector2(0, 110)
		log.size_flags_stretch_ratio = 1.0
	else:
		log.custom_minimum_size = Vector2(0, 300)
		log.size_flags_stretch_ratio = 1.0
	if view_mode == "score":
		speed = 3
		if speed_opt != null:
			speed_opt.select(3)
	if speed_opt != null:
		speed_opt.disabled = view_mode == "score"
	if log.visible:
		_scroll_log_end()


func _scroll_log_end() -> void:
	await get_tree().process_frame
	if is_instance_valid(log):
		log.scroll_to_line(log.get_line_count() - 1)


func _show_talk() -> void:
	clear(talk_box)
	if not talk_pending or finished:
		return
	talk_box.add_child(UI.subtitle(T("ui.talk.title_pre") if sim.tick == 0 else T("ui.talk.title_timeout")))
	var note := UI.text("MetaItalic", T("ui.talk.note"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk_box.add_child(note)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for tone in TeamTalk.TONES:
		var b := UI.button(T("talk.tone." + tone), func(): _give_talk(tone))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = T("talk.tone." + tone + ".tip")
		grid.add_child(b)
	talk_box.add_child(grid)
	talk_box.add_child(UI.link(T("ui.talk.skip"), func(): talk_pending = false; _show_talk()))
	talk_box.add_child(UI.rule())


func _give_talk(tone: String) -> void:
	var diff: int = my_team.score - rival_team.score
	var before := {}
	for sp in my_team.players:
		before[sp.id] = sp.attrs.duplicate()
	var r := TeamTalk.apply(my_team, tone, diff, sim.tick == 0, hash("talk:%d:%d:%s" % [sim.tick, talks_given, tone]))
	TeamTalk.cap_effect(my_team, before)
	talks_given += 1
	talk_pending = false
	clear(talk_box)
	var txt := T(str(r["summary_key"]))
	if not r["good"].is_empty():
		txt += "\n" + T("ui.talk.good") % ", ".join(r["good"])
	if not r["bad"].is_empty():
		txt += "\n" + T("ui.talk.bad") % ", ".join(r["bad"])
	talk_box.add_child(UI.subtitle(T("ui.talk.reaction")))
	var l := UI.text("Body", txt)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	talk_box.add_child(l)
	talk_box.add_child(UI.rule())
	log.append_text("[color=#%s]%s: %s[/color]\n" % [ThemeBuilder.BLUE.to_html(false), T("talk.tone." + tone), T(str(r["summary_key"]))])


var _shown := 0


func _append_events(_evs: Array = []) -> void:
	var all: Array = sim.result.events
	_batch_lines = 0
	_batch_kinds = {}
	while _shown < all.size():
		var e: MatchEvent = all[_shown]
		_shown += 1
		_batch_kinds[e.type] = true
		if e.importance >= MatchEvent.Importance.MAJOR:
			_sound_for(e)
		if e.importance < min_imp and e.type != "tactics_change":
			continue
		var extra := ""
		if e.type == "bludger_hit" and min_imp > MatchEvent.Importance.FLOW:
			if e.clock_s - _last_bludger_s < BLUDGER_GAP_S:
				_bludgers_hidden += 1
				continue
			_last_bludger_s = e.clock_s
			if _bludgers_hidden > 0:
				extra = "  [color=#7C6A52][i]%s[/i][/color]" % Game.tn("ui.match.bludgers_more", _bludgers_hidden)
				_bludgers_hidden = 0
		if e.importance < MatchEvent.Importance.MAJOR:
			_sound_for(e)
		_append_line(_format_event(e) + extra)
		_batch_lines += 1
	if sim.is_over() and not finished:
		finished = true
		running = false
		if main != null and main.has_method("on_match_finished"):
			main.on_match_finished()
		_end_armed_ms = Time.get_ticks_msec() + 1200
		_show_end_state()
	elif _batch_kinds.has("snitch_sighted") and running and not _silent and view_mode != "score" and bool(Game.world.settings.get("match_autopause_snitch", true)):
		_pause()
		_append_line("[color=#2E4A6B][i]%s[/i][/color]" % T("ui.match.autopaused"))


func _show_end_state() -> void:
	controls.visible = false
	end_box.visible = true
	end_replay_btn.visible = view_mode == "2d"
	finish_btn.disabled = Time.get_ticks_msec() < _end_armed_ms
	_append_line("[b]%s[/b]" % (T("ui.match.over") % [ctx.home.name, sim.home.score, sim.away.score, ctx.away.name]))


func _sound_for(e: MatchEvent) -> void:
	if _silent or view_mode == "score":
		return
	match e.type:
		"goal", "penalty_goal":
			Sfx.play("goal", -2.0)
		"save", "penalty_saved":
			Sfx.play("save", -4.0)
		"bludger_hit":
			Sfx.play("bludger", -3.0)
		"snitch_caught":
			Sfx.play("snitch")
			Sfx.play("cheer", -2.0)
		"kickoff", "timeout", "foul", "send_off", "match_end":
			Sfx.play("whistle", -6.0)
		"snitch_sighted":
			Sfx.play("cheer", -10.0)


func _append_line(s: String) -> void:
	log.append_text(s + "\n")
	await get_tree().process_frame
	log.scroll_to_line(log.get_line_count() - 1)


func _format_event(e: MatchEvent) -> String:
	var team := Game.club_name(e.team_id) if e.team_id != "" else ""
	var p := Game.player_name(e.player_id) if e.player_id != "" else ""
	var p2 := Game.player_name(e.other_player_id) if e.other_player_id != "" else ""
	var key := e.text_key
	if tr(key) == key:
		key = "match." + e.type
	var seed_value := hash("%s:%d:%s" % [str(ctx.fixture["id"]), e.tick, e.type])
	var ckey := Commentary.key_for(commentator, e, seed_value)
	var reaction := ckey != "" and (Commentary.is_reaction(e.type) or (e.type == "match_end" and e.text_key != "match.end.snitch"))
	var cvar := _fresh_variant(ckey, seed_value) if ckey != "" else ""
	if cvar == "":
		ckey = ""
		reaction = false
	var params := {"team": team, "player": p, "other": p2, "score": "%d-%d" % [e.score_home, e.score_away], "severity": (tr("severity." + str(e.params.get("severity", ""))) if e.params.has("severity") else "")}
	var tkey := cvar
	if ckey == "" or reaction:
		tkey = _fresh_variant(key, seed_value)
		if tkey == "":
			tkey = _variant_key(key, absi(seed_value) % _variants(key))
		_remember(tkey)
	if ckey != "":
		_remember(cvar)
	var txt := Game.t(tkey, params)
	if reaction:
		txt += "  [i]%s[/i]" % Game.t(cvar, params)
	elif ckey != "":
		txt = "[i]%s[/i]" % txt
		var inter := Commentary.interjection_for(commentator, ckey, seed_value)
		var ivar := _fresh_variant(inter, seed_value / 3) if inter != "" else ""
		if ivar != "":
			_remember(ivar)
			txt += "\n        [color=#6E4E1E]%s[/color]" % Game.t(ivar, params)
	if e.type == "snitch_caught":
		return "[color=#5C4A36]%s[/color]  [font_size=%d][color=#94700E][b]%s[/b][/color][/font_size]" % [e.clock_text(), int(round(19 * Settings.text_scale)), txt]
	var color := "#2A1E14"
	match e.type:
		"goal", "penalty_goal":
			color = "#2F5A2A"
		"snitch_caught", "match_end":
			color = "#6E4E1E"
		"injury", "send_off", "foul":
			color = "#8E1F1C"
		"snitch_sighted", "snitch_chase_contest", "wronski_feint":
			color = "#8A6428"
		"timeout", "tactics_change", "night_pause", "long_match_regime":
			color = "#2E4A6B"
	var bold := e.importance >= MatchEvent.Importance.MAJOR
	var body := ("[b]%s[/b]" % txt) if bold else txt
	return "[color=#5C4A36]%s[/color]  [color=%s]%s[/color]" % [e.clock_text(), color, body]


func _variants(key: String) -> int:
	if not _variant_n.has(key):
		var n := 1
		while str(TranslationServer.translate("%s.v%d" % [key, n + 1])) != "%s.v%d" % [key, n + 1]:
			n += 1
		_variant_n[key] = n
	return int(_variant_n[key])


func _variant_key(key: String, idx: int) -> String:
	return key if idx == 0 else "%s.v%d" % [key, idx + 1]


func _fresh_variant(key: String, seed_value: int) -> String:
	var n := _variants(key)
	var start := absi(seed_value) % n
	for i in n:
		var k := _variant_key(key, (start + i) % n)
		if not _recent_keys.has(k):
			return k
	return ""


func _remember(k: String) -> void:
	_recent_keys.append(k)
	if _recent_keys.size() > RECENT_KEYS:
		_recent_keys.pop_front()


func _update_hud() -> void:
	score_label.text = "%d – %d" % [sim.home.score, sim.away.score]
	_update_stakes()
	_update_counter_hint()
	clock_label.text = _clock(sim.clock_s)
	if sim.is_over():
		var sp_id := sim.result.snitch_player_id
		snitch_label.text = (T("ui.match.snitch_caught_by") % Game.player_name(sp_id)) if sp_id != "" else T("ui.match.snitch_not_caught")
		snitch_label.add_theme_color_override("font_color", ThemeBuilder.BRONZE_TEXT if sp_id != "" else ThemeBuilder.INK_SOFT)
	elif sim.snitch_state == MatchSim.SnitchState.CHASE:
		snitch_label.text = (T("ui.match.snitch_chase") % Game.player_name(sim.chaser.id)) if sim.chaser else T("ui.match.snitch_sighted")
		snitch_label.add_theme_color_override("font_color", ThemeBuilder.SEALING_WAX)
	else:
		snitch_label.text = T("ui.match.snitch_free")
		snitch_label.add_theme_color_override("font_color", ThemeBuilder.INK_SOFT)
	var sig := _hud_signature()
	if sig == _hud_sig:
		return
	_hud_sig = sig
	clear(cond_box)
	for sp in my_team.players:
		var h := UI.hbox(4)
		var status := ""
		if sp.injured:
			status = " ✚"
		elif sp.sent_off:
			status = " ⊘"
		var nl := UI.label("%s %s%s" % [UI.pos_short(sp.position), sp.name, status], "ui", 13, ThemeBuilder.SEALING_WAX if not sp.is_active() else ThemeBuilder.INK)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		h.add_child(_rating_label(sp, my_team.score >= rival_team.score))
		h.add_child(UI.bar(sp.condition, 70, false))
		cond_box.add_child(h)
	cond_box.add_child(UI.text("Caption", T("ui.match.rival_team")))
	for sp in rival_team.players:
		var h2 := UI.hbox(4)
		var nl2 := UI.label("%s %s%s" % [UI.pos_short(sp.position), sp.name, " ✚" if sp.injured else (" ⊘" if sp.sent_off else "")], "ui", 12, ThemeBuilder.INK_SOFT)
		nl2.clip_text = true
		nl2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(nl2)
		h2.add_child(_rating_label(sp, rival_team.score > my_team.score))
		cond_box.add_child(h2)
	var ms := my_team.stats
	var rs := rival_team.stats
	clear(stats_box)
	var head := UI.hbox(4)
	head.add_child(UI.spacer())
	var hu := UI.text("Caption", T("ui.match.stats_us"))
	hu.custom_minimum_size = Vector2(60, 0)
	hu.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(hu)
	var ht := UI.text("Caption", T("ui.match.stats_them"))
	ht.custom_minimum_size = Vector2(60, 0)
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(ht)
	stats_box.add_child(head)
	for pair in [["ui.stat.shots", "shots"], ["ui.stat.saves", "saves"], ["ui.stat.bludger_hits", "bludger_hits_dealt"], ["ui.stat.fouls", "fouls"], ["ui.stat.sightings", "snitch_sightings"]]:
		var h := UI.hbox(4)
		h.add_child(UI.text("Body", T(pair[0])))
		h.add_child(UI.spacer())
		var a := int(ms.get(pair[1], 0))
		var b := int(rs.get(pair[1], 0))
		var la := UI.text("TableBold" if a > b else "TableText", str(a))
		la.custom_minimum_size = Vector2(60, 0)
		la.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(la)
		var lb := UI.text("TableBold" if b > a else "TableText", str(b))
		lb.custom_minimum_size = Vector2(60, 0)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(lb)
		stats_box.add_child(h)


func _hud_signature() -> String:
	var parts := PackedStringArray()
	for side in 2:
		var t: SimTeam = my_team if side == 0 else rival_team
		var winning := my_team.score >= rival_team.score if side == 0 else rival_team.score > my_team.score
		for sp: SimPlayer in t.players:
			parts.append("%s:%d:%d%d%d:%.1f" % [sp.id, int(sp.condition), int(sp.injured), int(sp.sent_off), int(sp.is_active()), Progression.match_rating(sp.stats, sp.position, winning)])
		for k in ["shots", "saves", "bludger_hits_dealt", "fouls", "snitch_sightings"]:
			parts.append(str(int(t.stats.get(k, 0))))
	return "|".join(parts)


func _clock(s: int) -> String:
	return MatchEvent.clock_of(s)


func _dismiss_talk() -> void:
	if talk_pending:
		talk_pending = false
		_show_talk()


func _play() -> void:
	if finished:
		return
	_dismiss_talk()
	if pitch != null and pitch.is_busy():
		set_meta("was_running", true)
		return
	running = true


func _toggle_play() -> void:
	if running:
		_pause()
	else:
		_play()


func _pause() -> void:
	if pitch != null and pitch.is_busy():
		set_meta("was_running", false)
	running = false


func _next_event() -> void:
	if finished:
		return
	if pitch != null and pitch.is_busy():
		pitch.skip_replay()
		return
	_dismiss_talk()
	var was_running := running
	running = false
	var first := _shown
	_silent = true
	for i in 20:
		sim.step(2000, min_imp)
		_append_events()
		if _batch_lines > 0 or finished:
			break
	_silent = false
	var all: Array = sim.result.events
	for i in range(all.size() - 1, first - 1, -1):
		var e: MatchEvent = all[i]
		if e.importance >= min_imp:
			_sound_for(e)
			break
	if pitch != null and pitch.is_visible_in_tree():
		pitch.catch_up()
	var sighting_pause: bool = _batch_kinds.has("snitch_sighted") and bool(Game.world.settings.get("match_autopause_snitch", true))
	if view_mode == "2d" and was_running and not finished and not sighting_pause:
		running = true
	_update_hud()


func _process(delta: float) -> void:
	if pitch != null:
		pitch.frozen = (not running or talk_pending) and not finished
	if play_btn != null:
		play_btn.text = ("⏸ " + T("ui.match.pause")) if running else ("▶ " + T("ui.match.play"))
	if timeout_btn != null and sim != null and not finished:
		var wait := sim.timeout_wait_minutes(my_team)
		timeout_btn.disabled = wait > 0
		var tip := T("ui.match.timeout_wait", {"m": wait}) if wait > 0 else T("ui.match.timeout_tip", {"m": int(sim.timeout_cooldown_minutes())})
		if timeout_btn.tooltip_text != tip:
			timeout_btn.tooltip_text = tip
	if replay_btn != null and pitch != null:
		replay_btn.disabled = view_mode != "2d" or not (pitch.has_last_play() or pitch.is_busy())
		replay_btn.text = T("ui.match.replay_skip") if pitch.is_busy() else T("ui.match.replay")
	if end_replay_btn != null and pitch != null and finished:
		end_replay_btn.disabled = not (pitch.has_last_play() or pitch.is_busy())
	if finish_btn != null and finish_btn.disabled and Time.get_ticks_msec() >= _end_armed_ms:
		finish_btn.disabled = false
	if not running or finished or sim == null:
		return
	timer += delta
	if view_mode == "2d":
		var rate: float = [0.0, 2.5, 5.0, 12.0][speed]
		pitch.clock_scale = rate / 5.0
		if rate <= 0.0 or timer < 1.0 / rate:
			return
		timer -= 1.0 / rate
		timer = minf(timer, 1.0 / rate)
		sim.step(1, 4)
		_append_events()
		_update_hud()
		return
	if speed == 0:
		return
	if speed == 3 or view_mode == "score":
		if timer < 0.08:
			return
		timer = 0.0
		sim.step(60 if view_mode == "score" else 12, 4)
		_append_events()
		_update_hud()
		return
	timer = 0.0
	if _hold > 0.0:
		_hold -= delta
		return
	for i in 6:
		sim.step(240, min_imp)
		_append_events()
		if _batch_lines > 0 or finished or not running:
			break
	_update_hud()
	if _batch_lines > 0 and running:
		_hold = _line_hold()


func _line_hold() -> float:
	var h: float = LINE_HOLD[speed]
	if min_imp <= 1:
		h *= 0.4
	if _batch_kinds.has("snitch_caught"):
		h += HOLD_CATCH
	elif _batch_kinds.has("snitch_sighted"):
		h += HOLD_SIGHTED
	elif _batch_kinds.has("goal") or _batch_kinds.has("penalty_goal"):
		h += HOLD_GOAL
	return h


func _sim_to_end() -> void:
	if finished or sim == null:
		return
	_dismiss_talk()
	talk_pending = false
	running = false
	if pitch != null:
		pitch.skip_replay()
		pitch.clear_history()
	var guard := 0
	while not sim.is_over() and guard < 400:
		sim.step(100000, MatchEvent.Importance.NEVER_STOP)
		guard += 1
	if pitch != null:
		pitch.jump_to_end()
	_silent = true
	_append_events()
	_silent = false
	_update_hud()


## Top bar button («Finish the match»).
func finish_match() -> void:
	if finished:
		_finish()


func _finish() -> void:
	if main != null and main.busy:
		return
	if main != null:
		await main.finish_match_stepped()
	else:
		Game.engine.complete_pending_match()
	Game.world_changed.emit()
	if Game.engine.pending_match != null:
		go("match")
	else:
		go("post_match")


## Development tool: advances N ticks and shows the events.
func debug_step(ticks: int) -> void:
	if sim == null:
		return
	_dismiss_talk()
	sim.step(ticks, MatchEvent.Importance.NEVER_STOP)
	_append_events()
	_update_hud()


func _update_stakes() -> void:
	if stakes_box == null:
		return
	var comp: Competition = Game.world.competitions.get(ctx.comp_id)
	if comp == null or comp.is_knockout() or comp.type == Competition.Type.FRIENDLY:
		stakes_box.visible = false
		return
	var me := my_team.id
	var rival: String = ctx.away.id if ctx.home.id == me else ctx.home.id
	var my_score: int = my_team.score
	var their_score: int = sim.away.score if ctx.home.id == me else sim.home.score
	var sig := "%d-%d-%s" % [my_score, their_score, sim.snitch_state]
	if sig == _stakes_sig:
		return
	_stakes_sig = sig
	clear(stakes_box)
	stakes_box.visible = true
	stakes_box.add_child(UI.subtitle(T("ui.match.stakes")))
	var wins_bonus := str(comp.format.get("table", "points_scored")) == "wins_bonus"
	var group_ids: Array = []
	if comp.type in Competition.Type.GROUP_STAGES:
		for g in comp.groups.keys():
			if comp.groups[g].has(me):
				group_ids = comp.groups[g]
	var rows: Array = comp.standings(group_ids)
	if wins_bonus:
		var margin := my_score - their_score
		var gp := _group_points(margin)
		stakes_box.add_child(UI.text("Body", T("ui.match.stakes_margin") % [("+" if margin > 0 else "") + str(margin), gp]))
		if not sim.is_over():
			var gp_catch := _group_points(margin + 150)
			stakes_box.add_child(UI.text("Body", T("ui.match.stakes_margin_catch") % [("+" if margin + 150 > 0 else "") + str(margin + 150), gp_catch]))
		stakes_box.add_child(UI.text("Meta", T("ui.match.stakes_bonus_rule")))
		return
	var now := _rank_with(rows, me, rival, my_score, their_score)
	stakes_box.add_child(UI.text("Body", T("ui.match.stakes_now") % [Game.ordinal(now[0]), _gap_text(now[1])]))
	if not sim.is_over():
		var caught := _rank_with(rows, me, rival, my_score + 150, their_score)
		stakes_box.add_child(UI.text("Body", T("ui.match.stakes_catch") % [Game.ordinal(caught[0]), _gap_text(caught[1])]))
		if caught[0] > 1 and caught[1] > 0:
			stakes_box.add_child(UI.text("Meta", T("ui.match.stakes_need") % (caught[1] + 10)))
		elif caught[0] == 1 and now[0] > 1:
			stakes_box.add_child(UI.text("Meta", T("ui.match.stakes_catch_top")))
	stakes_box.add_child(UI.rule())


func _rank_with(rows: Array, me: String, rival: String, my_add: int, their_add: int) -> Array:
	var pts := {}
	for r in rows:
		pts[str(r["club_id"])] = int(r["pts"])
	pts[me] = int(pts.get(me, 0)) + my_add
	if pts.has(rival):
		pts[rival] = int(pts[rival]) + their_add
	var mine: int = pts[me]
	var rank := 1
	var best_other := -1
	for k in pts.keys():
		if k == me:
			continue
		best_other = maxi(best_other, int(pts[k]))
		if int(pts[k]) > mine:
			rank += 1
	return [rank, maxi(best_other - mine, 0) if rank > 1 else 0]


func _gap_text(gap: int) -> String:
	return T("ui.match.stakes_leader") if gap == 0 else T("ui.match.stakes_gap") % gap


func _group_points(margin: int) -> int:
	if margin > 0:
		return 2 + (5 if margin > 150 else (3 if margin > 100 else (1 if margin > 50 else 0)))
	return 1 if margin == 0 else 0


func _update_counter_hint() -> void:
	if counter_label == null:
		return
	var rival: SimTeam = ctx.away if ctx.home == my_team else ctx.home
	var style := str(rival.tactics.get("chaser_formation", "free"))
	var counter := SimTactics.counter_to(style)
	var sname := T("formation." + style)
	var mine := SimTactics.defence_of(my_team.tactics)
	var their_def := SimTactics.defence_of(rival.tactics)
	var extra := ("\n" + T("ui.assistant.attack_vs_" + their_def) % rival.name) if their_def != "zone" else ""
	counter_label.text = extra.strip_edges() if counter == "" else ""
	if counter == "":
		return
	counter_label.text = extra.strip_edges() + ("\n" if extra != "" else "") + ((T("ui.assistant.counter_ok") % [T("defence." + counter), sname]) if mine == counter else (T("ui.assistant.counter") % [sname, T("defence." + counter)]))


func _rating_label(sp: SimPlayer, winning: bool) -> Label:
	var r := Progression.match_rating(sp.stats, sp.position, winning)
	var l := UI.label("%.1f" % r, "ui_bold", 12, ThemeBuilder.GREEN if r >= 7.0 else (ThemeBuilder.SEALING_WAX if r < 5.5 else ThemeBuilder.INK))
	l.custom_minimum_size = Vector2(30, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

