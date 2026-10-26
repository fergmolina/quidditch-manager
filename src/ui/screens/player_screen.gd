extends UIScreen
## Player profile: header with KPIs, tabs, attributes in two columns with a heat map
## and key attributes highlighted, side card with broom and drawn stars.

const GROUPS := {
	"flying": ["speed", "acceleration", "agility", "broom_control", "balance", "altitude", "dive"],
	"technical": ["passing", "catching", "shooting", "dodging", "stealing", "interception", "keeping", "beating", "beat_accuracy", "snitch_catching"],
	"mental": ["aggression", "anticipation", "bravery", "composure", "concentration", "creativity", "decisions", "determination", "flair", "influence", "off_ball", "positioning", "teamwork", "work_rate"],
	"physical": ["stamina", "strength", "natural_fitness", "reflexes", "eyesight"],
}
## Toast with the player's name ("%s") for a contract result key (ContractDialog.signed).
const TOAST_KEYS := {"ui.market.signed": "ui.market.signed_toast", "ui.market.renewed": "ui.market.renewed_toast"}

var p: Player
var head: HBoxContainer
var body_box: HBoxContainer
var tab := 0
var action_menu: MenuButton


func build() -> void:
	p = Game.world.player(str(params.get("player_id", "")))
	tab = int(params.get("tab", 0))
	if p == null:
		header("?")
		return
	var pa: Dictionary = main.get("pending_player_action") if main != null and main.get("pending_player_action") != null else {}
	if str(pa.get("player_id", "")) == p.id:
		main.set("pending_player_action", {})
		_run_action.call_deferred(str(pa.get("key", "")))
	var hp := UI.panel(12)
	head = UI.hbox(14)
	hp.add_child(head)
	root.add_child(hp)
	var names := T("ui.profile.tabs").split(",")
	if p.squad == Player.Squad.SCHOOL:
		names.remove_at(3)
	root.add_child(UI.tabs(names, tab, func(i): tab = (i + 1 if p.squad == Player.Squad.SCHOOL and i >= 3 else i); refresh()))
	body_box = UI.hbox(12)
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body_box)


## Back to the profile returns to the tab that was open (e.g. History after opening a club from it).
func nav_state() -> Dictionary:
	return {"tab": tab}


func refresh() -> void:
	if p == null:
		return
	var w := Game.world
	var club: Club = w.club(p.club_id)
	clear(head)
	clear(body_box)
	head.add_child(UI.portrait(p, club, 72))
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UI.title(p.name()))
	var sub := UI.hbox(8)
	sub.add_child(UI.badge(T("pos." + p.position), ThemeBuilder.INK, ThemeBuilder.INK, true))
	var nat := T("nat." + p.nationality) if tr("nat." + p.nationality) != "nat." + p.nationality else Game.loader.country_name(p.nationality)
	sub.add_child(UI.flag(p.nationality, 14))
	sub.add_child(UI.meta("%d %s · %s · %s" % [p.age(w.today), T("ui.age_word"), nat, T("ui.squad." + p.squad)]))
	if club != null:
		sub.add_child(UI.team_link(club.id, club.name))
	elif p.squad == Player.Squad.SCHOOL:
		var sname := Game.school_name(p.school_id)
		sub.add_child(UI.link(sname, func(): go("schools", {"school_id": p.school_id})))
		var hid := Schools.house_id(p.school_id, p.house)
		if w.houses.has(hid):
			sub.add_child(UI.team_link(hid, Loc.name("house." + p.house, p.house)))
		else:
			sub.add_child(UI.meta(Loc.name("house." + p.house, p.house)))
	elif p.squad == Player.Squad.ABROAD:
		sub.add_child(UI.badge(T("ui.squad.abroad"), ThemeBuilder.INK_SOFT, ThemeBuilder.INK_SOFT, true))
	else:
		sub.add_child(UI.badge(T("ui.free_agent"), ThemeBuilder.BLUE, ThemeBuilder.BLUE, true))
	if p.is_captain:
		sub.add_child(UI.badge(T("ui.captain"), ThemeBuilder.BRASS_BUTTON))
	if p.injury_days > 0:
		sub.add_child(UI.badge(T("ui.injured_days") % p.injury_days, ThemeBuilder.SEALING_WAX, ThemeBuilder.CARD))
	elif p.on_duty():
		sub.add_child(UI.badge(T("ui.on_duty") % [Game.world.team_name(p.duty_team), p.duty_days], ThemeBuilder.SEALING_WAX, ThemeBuilder.CARD))
	if p.transfer_listed:
		sub.add_child(UI.badge(T("ui.market.listed"), ThemeBuilder.BLUE, ThemeBuilder.BLUE, true))
	if p.loan_listed:
		sub.add_child(UI.badge(T("ui.market.loan_listed"), ThemeBuilder.BLUE, ThemeBuilder.BLUE, true))
	if p.is_on_loan():
		var owner: Club = w.club(p.loan_owner_id())
		var lb := UI.badge(T("ui.on_loan_from") % (owner.name if owner else "?"), ThemeBuilder.AMBER, ThemeBuilder.AMBER, true)
		if owner != null:
			UI.make_team_clickable(lb, owner.id)
		sub.add_child(lb)
	if w.shortlist.has(p.id):
		sub.add_child(UI.badge(T("ui.market.shortlist"), ThemeBuilder.GREEN, ThemeBuilder.GREEN, true))
	tv.add_child(sub)
	head.add_child(tv)
	var lvl := Game.knowledge_level(p)
	if p.squad == Player.Squad.SCHOOL:
		var hk := UI.kpi(Game.world.team_name(Schools.house_id(p.school_id, p.house)), Game.school_name(p.school_id))
		UI.make_team_clickable(hk.get_child(0), Schools.house_id(p.school_id, p.house))
		head.add_child(hk)
		head.add_child(UI.kpi(T("ui.school.year") % Schools.school_year(p, w), T("ui.col.year").capitalize()))
	else:
		head.add_child(UI.kpi(Game.galleons(p.market_value(w.today)) if lvl >= 1 else "?", T("ui.col.value")))
		head.add_child(UI.kpi(Game.galleons(int(p.contract.get("wage_weekly", 0))), T("ui.col.wage") + "/" + T("ui.week")))
		head.add_child(UI.kpi(_short_date(int(p.contract.get("end_day", 0))), T("ui.contract")))
	head.add_child(UI.kpi("%d" % int(p.condition), T("ui.col.cond")))
	head.add_child(UI.kpi(T(UI.morale_key(p.morale)), T("ui.col.morale")))
	_actions_menu()
	match tab:
		0:
			_profile()
		1:
			_progress()
		2:
			_history()
		3:
			_contract()
		_:
			_reports()


func _loaned_out() -> bool:
	return PlayerScreenActions.loaned_out(Game.world, p)


func _toggle_shortlist() -> void:
	MarketActions.toggle_shortlist(Game.world, p)
	Game.mark_dirty()
	main.toast((T("ui.market.shortlisted") if Game.world.shortlist.has(p.id) else T("ui.market.unshortlisted")) % p.name())
	refresh()


func _scout_report() -> void:
	var key := Scouting.request(Game.world, Game.my_club(), p)
	var ok := key == "ui.scout.requested"
	if ok:
		Game.mark_dirty()
	main.toast(T(key), "check-circle" if ok else "x-circle", "ok" if ok else "error")
	refresh()


func _recall() -> void:
	MarketActions.end_loan_early(Game.world, p)
	Game.mark_dirty()
	main.toast(T("ui.market.loan_recalled") % p.name())
	go("squad")


## Carries out an action listed by PlayerScreenActions.for_player; one no longer open to the manager is ignored.
func _run_action(key: String) -> void:
	if not PlayerScreenActions.for_player(p.id).any(func(a: Array) -> bool: return str(a[0]) == key):
		return
	var w := Game.world
	match key:
		"talk":
			_talk_dialog()
		"make_captain":
			_make_captain()
		"shortlist":
			_toggle_shortlist()
		"graduate_offer":
			_negotiate("graduate")
		"loan_end":
			MarketActions.end_loan_early(w, p)
			Game.mark_dirty()
			main.toast(T("ui.market.loan_returned_toast") % p.name())
			go("squad")
		"transfer_list":
			MarketActions.toggle_transfer_list(w, p)
			Game.mark_dirty()
			main.toast(T("ui.market.listed") if p.transfer_listed else T("ui.market.unlisted"))
			refresh()
		"loan_list":
			p.loan_option_fee = 0
			MarketActions.toggle_loan_list(w, p)
			Game.mark_dirty()
			main.toast(T("ui.market.loan_listed") if p.loan_listed else T("ui.market.loan_unlisted"))
			refresh()
		"loan_list_option":
			_loan_list_option()
		"renew":
			_renew()
		"release":
			_confirm_release()
		"mutual":
			_mutual()
		"loan_recall":
			_recall()
		"negotiate":
			_sign_free()
		"negotiate_menu":
			_negotiate_dialog()
		"scout_report":
			_scout_report()
		"compare_with":
			go("compare", {"a": Game.compare_player_id, "b": p.id})
		"compare_mark":
			Game.compare_player_id = p.id
			main.toast(T("ui.action.compare_marked") % p.name())
			refresh()
		"compare_unmark":
			Game.compare_player_id = ""
			refresh()


func _actions_menu() -> void:
	var w := Game.world
	var mb := MenuButton.new()
	mb.text = T("ui.actions") + " ▾"
	mb.custom_minimum_size = Vector2(0, 32)
	mb.flat = false
	mb.add_theme_stylebox_override("normal", ThemeBuilder.flat(Color.TRANSPARENT, ThemeBuilder.BORDER_CONTROL, 1, 4, 8))
	mb.add_theme_stylebox_override("hover", ThemeBuilder.flat(ThemeBuilder.ZEBRA, ThemeBuilder.BORDER_CONTROL, 1, 4, 8))
	mb.add_theme_stylebox_override("pressed", ThemeBuilder.flat(ThemeBuilder.HOVER, ThemeBuilder.BORDER_CONTROL, 1, 4, 8))
	mb.add_theme_color_override("font_color", ThemeBuilder.INK)
	mb.add_theme_color_override("font_hover_color", ThemeBuilder.INK)
	mb.add_theme_color_override("font_pressed_color", ThemeBuilder.INK)
	var pm := mb.get_popup()
	var actions := PlayerScreenActions.for_player(p.id)
	for i in actions.size():
		pm.add_item(str(actions[i][1]), i)
	pm.id_pressed.connect(func(id): _run_action(str(actions[id][0])))
	mb.disabled = actions.is_empty()
	var mv := UI.vbox(0)
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_child(mb)
	head.add_child(mv)


func _profile() -> void:
	var w := Game.world
	var ap := UI.panel(16)
	ap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 0)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := UI.vbox(2)
	var right := UI.vbox(2)
	_attr_group(left, "flying")
	left.add_child(UI.gap(8))
	_attr_group(left, "technical")
	_attr_group(right, "mental")
	right.add_child(UI.gap(8))
	_attr_group(right, "physical")
	grid.add_child(left)
	grid.add_child(right)
	var av := UI.vbox(6)
	av.add_child(grid)
	av.add_child(UI.spacer(false))
	av.add_child(UI.meta(T("ui.attr.key_marker")))
	ap.add_child(av)
	body_box.add_child(ap)
	var cp := UI.panel(16)
	cp.custom_minimum_size = Vector2(312, 0)
	cp.size_flags_horizontal = Control.SIZE_SHRINK_END
	cp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card := UI.vbox(6)
	var broom: Dictionary = Game.loader.brooms.get(str(p.broom.get("model_id", "")), {})
	card.add_child(UI.subtitle(T("ui.col.broom") + " · " + str(broom.get("model", "?"))))
	var bimg := UI.image_for("brooms", str(p.broom.get("model_id", "")))
	if bimg != null:
		var btr := TextureRect.new()
		btr.texture = bimg
		btr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		btr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		btr.custom_minimum_size = Vector2(0, 70)
		card.add_child(btr)
	var bgrid := GridContainer.new()
	bgrid.columns = 2
	bgrid.add_theme_constant_override("h_separation", 16)
	bgrid.add_theme_constant_override("v_separation", 4)
	for k in ["speed", "acceleration", "turning", "braking", "altitude", "stability"]:
		var h := UI.hbox(6)
		var l := UI.text("Meta", T("broom." + k))
		l.custom_minimum_size = Vector2(70, 0)
		h.add_child(l)
		h.add_child(UI.segments(clampi(int(round(float(broom.get(k, 10)) / 4.0)), 0, 5)))
		bgrid.add_child(h)
	card.add_child(bgrid)
	var bc := UI.hbox(6)
	bc.add_child(UI.text("Meta", T("ui.broom_condition")))
	bc.add_child(UI.spacer())
	bc.add_child(UI.bar(float(p.broom.get("condition", 100.0)), 80, true))
	card.add_child(bc)
	card.add_child(UI.gap(4))
	var lvl := Game.knowledge_level(p)
	var sh := UI.hbox(10)
	var s1 := UI.vbox(2)
	s1.add_child(UI.subtitle(T("ui.ca_stars")))
	s1.add_child(UI.stars(_star_count(p.ca())) if lvl >= 1 else UI.text("MetaItalic", "?"))
	var s2 := UI.vbox(2)
	s2.add_child(UI.subtitle(T("ui.pa_stars")))
	s2.add_child(UI.stars(_star_count(p.pa)) if lvl == 2 else UI.text("MetaItalic", "?"))
	sh.add_child(s1)
	sh.add_child(s2)
	card.add_child(sh)
	if lvl < 2:
		card.add_child(UI.text("MetaItalic", T("ui.scout.unknown_region"), ThemeBuilder.SEALING_WAX))
	card.add_child(UI.gap(4))
	card.add_child(UI.subtitle(T("ui.season_stats")))
	var st := p.stats_for(w.season)
	var sg := GridContainer.new()
	sg.columns = 4
	sg.add_theme_constant_override("h_separation", 12)
	for pair in [[str(int(st["apps"])), T("ui.col.played")], [str(int(st["goals"])), T("ui.stat.goals")], [str(int(st["catches"])), T("ui.col.catches")], [("%.1f" % (float(st["rating_sum"]) / int(st["apps"]))) if int(st["apps"]) > 0 else "–", T("ui.stat.rating")]]:
		sg.add_child(UI.kpi(pair[0], pair[1]))
	card.add_child(sg)
	var mentor := Progression.valid_mentor(p, w)
	if mentor != null:
		var mh := UI.hbox(6)
		mh.add_child(UI.text("Meta", (T("ui.label_value") % [T("ui.training.mentor"), ""]).strip_edges()))
		mh.add_child(UI.player_link(mentor.id, mentor.name()))
		card.add_child(mh)
	card.add_child(UI.gap(4))
	card.add_child(UI.subtitle(T("ui.assistant")))
	var mood := ""
	if p.club_id == Game.world.player_club_id and Game.world.player_club_id != "" and p.squad != Player.Squad.SCHOOL:
		var worry := Happiness.main_worry(p)
		mood = " " + (T("ui.happiness.worried") % T("ui.happiness." + worry) if worry != "" else T("ui.happiness.content"))
	var rep := UI.text("Prose", "«%s. %s»%s" % [_personality(), T("ui.squad." + p.squad), mood])
	rep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(rep)
	for tkey in p.traits:
		var tl := UI.text("MetaItalic", "“%s”" % T(str(tkey)))
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(tl)
	cp.add_child(card)
	body_box.add_child(cp)


func _attr_group(box: VBoxContainer, g: String) -> void:
	box.add_child(UI.subtitle(T("ui.attr_group." + g)))
	var keys: Dictionary = Player.KEY_WEIGHTS.get(p.position, {})
	var lvl := Game.knowledge_level(p)
	for k in GROUPS[g]:
		if p.position != "K" and k == "keeping":
			continue
		var val := float(p.attrs.get(k, 8.0))
		var prev := float(p.prev_attrs.get(k, val))
		var is_key: bool = float(keys.get(k, 1.0)) >= 2.0
		var h := UI.hbox(6)
		h.custom_minimum_size = Vector2(0, 22)
		var al := UI.text("Body", ("◆ " if is_key else "") + T("attr." + k), ThemeBuilder.INK if (is_key or float(keys.get(k, 1.0)) > 1.0) else ThemeBuilder.INK_FADED)
		if is_key:
			al.add_theme_font_override("font", ThemeBuilder.font("ui_medium"))
		al.clip_text = true
		al.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(al)
		var arrow := _arrow(val, prev) if lvl == 2 else ""
		var arl := UI.text("TableText", arrow, ThemeBuilder.GREEN if val > prev else ThemeBuilder.SEALING_WAX)
		arl.custom_minimum_size = Vector2(16, 0)
		h.add_child(arl)
		h.add_child(_chip(val, lvl, k))
		box.add_child(h)


func _chip(val: float, lvl: int, key: String) -> Control:
	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(34, 20)
	var txt := ""
	var fg := ThemeBuilder.INK_SOFT
	var bg := Color.TRANSPARENT
	var bold := false
	if lvl == 2:
		var st := ThemeBuilder.attr_style(val)
		txt = str(int(floor(val)))
		fg = st["fg"]
		bg = st["bg"]
		bold = st["bold"]
	else:
		txt = Game.attr_text(p, key)
	c.add_theme_stylebox_override("panel", ThemeBuilder.flat(bg, Color.TRANSPARENT, 0, 3, 0))
	var l := UI.label(txt, "table_bold" if bold else "table", 14, fg)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c


func _progress() -> void:
	var pnl := UI.panel(16)
	pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	v.add_child(UI.meta(T("ui.profile.progress_note")))
	var up := []
	var down := []
	for k in Player.ATTR_KEYS:
		var d := float(p.attrs.get(k, 8.0)) - float(p.prev_attrs.get(k, p.attrs.get(k, 8.0)))
		if d > 0.1:
			up.append("%s %s" % [T("attr." + k), "▲" if d >= 1.0 else "↗"])
		elif d < -0.1:
			down.append("%s %s" % [T("attr." + k), "▼" if d <= -1.0 else "↘"])
	v.add_child(UI.subtitle(T("ui.training.improved")))
	v.add_child(UI.text("Body", ", ".join(up) if not up.is_empty() else "—", ThemeBuilder.GREEN))
	v.add_child(UI.subtitle(T("ui.training.declined")))
	v.add_child(UI.text("Body", ", ".join(down) if not down.is_empty() else "—", ThemeBuilder.SEALING_WAX))
	v.add_child(UI.gap(8))
	var h := UI.hbox(24)
	h.add_child(UI.kpi("%d" % int(p.ca()), T("ui.ca_stars")))
	h.add_child(UI.kpi("%d" % int(p.pa) if Game.knowledge_level(p) == 2 else "?", T("ui.pa_stars")))
	h.add_child(UI.kpi("%d" % int(p.sharpness), T("ui.sharpness")))
	v.add_child(h)
	pnl.add_child(v)
	body_box.add_child(pnl)


func _history() -> void:
	var pnl := UI.panel(8)
	pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var t := UI.table([{"title": T("ui.col.season"), "width": 100}, {"title": T("ui.col.played"), "width": 50, "align": "right"}, {"title": T("ui.stat.goals"), "width": 70, "align": "right"}, {"title": T("ui.col.catches"), "width": 80, "align": "right"}, {"title": T("ui.stat.saves"), "width": 80, "align": "right"}, {"title": T("ui.stat.rating"), "width": 70, "align": "right"}, {"title": "", "width": 100, "expand": true}], 200)
	var keys := p.season_stats.keys()
	keys.sort()
	keys.reverse()
	for k in keys:
		var st: Dictionary = p.season_stats[k]
		UI.row(t, ["%s-%02d" % [k, (int(k) + 1) % 100], int(st["apps"]), int(st["goals"]), int(st["catches"]), int(st["saves"]), ("%.1f" % (float(st["rating_sum"]) / int(st["apps"]))) if int(st["apps"]) > 0 else "–", ""], k)
	var hv := UI.vbox(8)
	hv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not p.match_log.is_empty():
		hv.add_child(UI.subtitle(T("ui.profile.matches")))
		hv.add_child(_match_table())
		hv.add_child(UI.subtitle(T("ui.profile.by_season")))
	if keys.is_empty():
		hv.add_child(UI.meta(T("ui.profile.no_history")))
	else:
		t.custom_minimum_size.y = 60
		t.size_flags_vertical = Control.SIZE_FILL
		UI.fit_rows(t)
		hv.add_child(t)
	if not p.awards.is_empty():
		hv.add_child(UI.subtitle(T("ui.profile.awards")))
		for a in p.awards:
			hv.add_child(UI.text("Body", "%d-%02d · %s" % [int(a["season"]), (int(a["season"]) + 1) % 100, T("award." + str(a["kind"]))]))
	var moves: Array = Game.world.transfers.filter(func(tr_): return str(tr_.get("player_id", "")) == p.id and not World.is_release(tr_))
	if not moves.is_empty():
		hv.add_child(UI.subtitle(T("ui.profile.transfers")))
		for tr_ in moves:
			var mh := UI.hbox(6)
			mh.add_child(UI.text("Body", Game.date_text(int(tr_.get("day", 0))) + " ·"))
			mh.add_child(_team_ref(str(tr_.get("from_id", ""))))
			mh.add_child(UI.text("Body", "→"))
			mh.add_child(_team_ref(str(tr_.get("to_id", ""))))
			mh.add_child(UI.text("Meta", "· " + (T("ui.loan_badge") if bool(tr_.get("loan", false)) else Game.galleons(int(tr_.get("fee", 0))))))
			hv.add_child(mh)
	if not p.injury_history.is_empty():
		hv.add_child(UI.subtitle(T("ui.profile.injuries")))
		for i in range(p.injury_history.size() - 1, -1, -1):
			var inj: Dictionary = p.injury_history[i]
			var kind := str(inj.get("kind", ""))
			var kt := T("injury." + kind) if tr("injury." + kind) != "injury." + kind else kind
			hv.add_child(UI.text("Body", "%s · %s · %s" % [Game.date_text(int(inj.get("day", 0))), kt, T("ui.profile.days_out") % int(inj.get("days", 0))]))
	pnl.add_child(UI.scroll(hv))
	body_box.add_child(pnl)


func _match_table() -> Tree:
	var w := Game.world
	var t := UI.table([{"title": T("ui.col.date"), "width": 64}, {"title": T("ui.col.competition"), "width": 170, "expand": true},
		{"title": T("ui.col.opponent"), "width": 150, "expand": true}, {"title": T("ui.col.result"), "width": 96, "align": "right"},
		{"title": T("ui.stat.goals"), "width": 50, "align": "right"}, {"title": T("ui.stat.saves"), "width": 56, "align": "right"},
		{"title": T("ui.col.catches"), "width": 56, "align": "right"}, {"title": T("ui.stat.bludger_hits"), "width": 70, "align": "right"},
		{"title": T("ui.stat.rating"), "width": 56, "align": "right"}], 60)
	t.size_flags_vertical = Control.SIZE_FILL
	for i in range(p.match_log.size() - 1, -1, -1):
		var m: Array = p.match_log[i]
		if m.size() < Player.MatchLog.COLUMNS:
			continue
		var opp := str(m[Player.MatchLog.OPPONENT_ID])
		var gf := int(m[Player.MatchLog.SCORED])
		var ga := int(m[Player.MatchLog.CONCEDED])
		var rating := int(m[Player.MatchLog.RATING_X10]) / 10.0
		var venue := "" if int(m[Player.MatchLog.HOME]) == 1 else " (%s)" % T("ui.away_short")
		var it := UI.row(t, [Game.short_date(int(m[Player.MatchLog.DAY])), Say.text(Say.comp(str(m[Player.MatchLog.COMP_ID]))), w.team_name(opp) + venue, "%d – %d" % [gf, ga],
			int(m[Player.MatchLog.GOALS]), int(m[Player.MatchLog.SAVES]), int(m[Player.MatchLog.CATCHES]), int(m[Player.MatchLog.BLUDGER_HITS]), "%.1f" % rating])
		UI.team_cell(it, 2, opp)
		it.set_custom_color(3, ThemeBuilder.GREEN if gf > ga else (ThemeBuilder.SEALING_WAX if gf < ga else ThemeBuilder.AMBER))
		it.set_custom_color(8, ThemeBuilder.GREEN if rating >= 7.0 else (ThemeBuilder.SEALING_WAX if rating < 5.5 else ThemeBuilder.INK))
		it.set_custom_font(8, ThemeBuilder.font("table_bold"))
	UI.fit_rows(t)
	return t


func _team_ref(team_id: String) -> Control:
	var w := Game.world
	if team_id == "":
		return UI.text("Body", T("ui.free_agent"))
	if w.clubs.has(team_id) or w.houses.has(team_id) or w.national_teams.has(team_id):
		return UI.team_link(team_id, w.team_name(team_id) if team_id.begins_with("nt_") else Game.club_name(team_id))
	return UI.text("Body", Game.club_name(team_id))


func _contract() -> void:
	var pnl := UI.panel(16)
	pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(8)
	var h := UI.hbox(24)
	h.add_child(UI.kpi(Game.galleons(int(p.contract.get("wage_weekly", 0))), T("ui.col.wage") + " / " + T("ui.week")))
	h.add_child(UI.kpi(_short_date(int(p.contract.get("end_day", 0))), T("ui.contract_until")))
	h.add_child(UI.kpi(T("role." + str(p.contract.get("role", "rotation"))) if tr("role." + str(p.contract.get("role", "rotation"))) != "role." + str(p.contract.get("role", "rotation")) else str(p.contract.get("role", "")), T("ui.contract_role")))
	h.add_child(UI.kpi(Game.galleons(p.market_value(Game.world.today)) if Game.knowledge_level(p) >= 1 else "?", T("ui.col.value")))
	v.add_child(h)
	var extras := []
	for pair in [["bonus_goal", "ui.contract.bonus_goal"], ["bonus_catch", "ui.contract.bonus_catch"], ["bonus_title", "ui.contract.bonus_title"], ["yearly_rise_pct", "ui.contract.yearly_rise"], ["release_clause", "ui.contract.release_clause"]]:
		var val := int(p.contract.get(pair[0], 0))
		if val > 0:
			extras.append(T("ui.label_value") % [T(pair[1]), str(val) if pair[0] == "yearly_rise_pct" else Game.galleons(val)])
	if not extras.is_empty():
		var el := UI.text("Meta", " · ".join(extras))
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(el)
	if p.pre_contract != null:
		var pc_id := p.pre_contract.club_id
		var pl := UI.text("Meta", T("ui.contract.pre_with") % Game.club_name(pc_id))
		pl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		UI.make_team_clickable(pl, pc_id)
		v.add_child(pl)
	var own := p.club_id == Game.world.player_club_id and Game.world.player_club_id != "" and not p.is_on_loan()
	if own or _loaned_out():
		v.add_child(UI.gap(8))
		var bh := UI.hbox(8)
		var rb := UI.primary(T("ui.action.renew"), _renew)
		if p.pre_contract != null:
			rb.disabled = true
			rb.tooltip_text = T("ui.contract.has_pre_contract")
		bh.add_child(rb)
		if own:
			bh.add_child(UI.button(T("ui.action.transfer_list_off") if p.transfer_listed else T("ui.action.transfer_list_on"), func(): MarketActions.toggle_transfer_list(Game.world, p); Game.mark_dirty(); refresh()))
			bh.add_child(UI.button(T("ui.action.mutual"), _mutual))
			bh.add_child(UI.seal_button(T("ui.action.release"), _confirm_release))
		else:
			bh.add_child(UI.button(T("ui.action.loan_recall"), _recall))
		v.add_child(bh)
	pnl.add_child(v)
	body_box.add_child(pnl)


func _reports() -> void:
	var pnl := UI.panel(16)
	pnl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	v.add_child(UI.subtitle(T("ui.assistant")))
	var lines := [_personality()]
	if p.hid("consistency") >= 15:
		lines.append(T("report.consistent"))
	elif p.hid("consistency") <= 6:
		lines.append(T("report.inconsistent"))
	if p.hid("big_matches") >= 15:
		lines.append(T("report.big_matches"))
	if p.hid("injury_proneness") >= 15:
		lines.append(T("report.injury_prone"))
	if p.hid("dirtiness") >= 15:
		lines.append(T("report.dirty"))
	if p.hid("versatility") >= 14:
		lines.append(T("report.versatile"))
	var rl := UI.text("Prose", ". ".join(lines) + ".")
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rl)
	var me := Game.my_club()
	var srep: Dictionary = me.scout_reports.get(p.id, {}) if me != null else {}
	if srep.has("day"):
		v.add_child(UI.rule())
		v.add_child(UI.subtitle(T("ui.scout.report_title") % Game.date_text(int(srep["day"]))))
		v.add_child(UI.text("Body", "%s %s · %s %s" % [T("ui.col.ability"), "★".repeat(int(srep["ca_est"])) + "☆".repeat(5 - int(srep["ca_est"])), T("ui.col.potential"), "★".repeat(int(srep["pa_est"])) + "☆".repeat(5 - int(srep["pa_est"]))]))
		v.add_child(UI.text("BodyMedium", T(str(srep["verdict"])) + " · " + T("ui.scout.value") % Game.galleons(int(srep.get("value", 0)))))
	elif bool(srep.get("pending", false)):
		v.add_child(UI.text("MetaItalic", T("ui.scout.pending") % Game.date_text(int(srep["due"]))))
	pnl.add_child(v)
	body_box.add_child(pnl)


func _embargo() -> bool:
	var me := Game.my_club()
	return me != null and bool(me.board.get("embargo", false))


func _budget_text() -> String:
	var me := Game.my_club()
	if me == null:
		return ""
	var bill := 0
	for q in Game.world.squad_of(me.id):
		bill += int(q.contract.get("wage_weekly", 0))
	return T("ui.market.budgets") % [Game.galleons(me.transfer_budget), Game.galleons(bill), Game.galleons(me.wage_budget_weekly)]


func _offer(fee: int, installments: int = 1) -> void:
	if _embargo():
		main.toast(T("ui.market.embargo"), "x-circle", "error")
		return
	var r := MarketActions.make_offer(Game.world, p, fee, "", installments)
	if r["ok"]:
		Game.mark_dirty()
	main.toast(T(str(r["key"])), "check-circle" if r["ok"] else "x-circle", "ok" if r["ok"] else "error")
	refresh()


func _talk_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = T("ui.talk.player_title") % p.name()
	dlg.ok_button_text = T("ui.close")
	var v := UI.vbox(8)
	v.custom_minimum_size = Vector2(420, 0)
	var note := UI.text("Meta", T("ui.label_value") % [T("ui.col.morale"), T(UI.morale_key(p.morale))])
	v.add_child(note)
	for kind in ["praise", "demand", "promise"]:
		var b := UI.button(T("talk.player." + kind), func():
			var key := Press.talk(Game.world, p, kind)
			Game.mark_dirty()
			note.text = T(key)
			refresh())
		b.tooltip_text = T("talk.player." + kind + ".tip")
		v.add_child(b)
	dlg.add_child(v)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _swap_dialog() -> void:
	var w := Game.world
	if _embargo():
		main.toast(T("ui.market.embargo"), "x-circle", "error")
		return
	var items := []
	for q in w.squad_of(w.player_club_id):
		if not q.is_on_loan():
			items.append([q.id, "%s (%s, %d) · %s" % [q.name(), UI.pos_short(q.position), q.age(w.today), Game.galleons(q.market_value(w.today))]])
	if items.is_empty():
		main.toast(T("ui.swap.none"), "x-circle", "error")
		return
	var dlg := ConfirmationDialog.new()
	dlg.cancel_button_text = T("ui.cancel")
	UI.cancel_right(dlg)
	dlg.title = T("ui.swap.title") % p.name()
	dlg.ok_button_text = T("ui.swap.send")
	var v := UI.vbox(8)
	v.custom_minimum_size = Vector2(420, 0)
	v.add_child(UI.text("Body", T("ui.swap.player")))
	var chosen: Array = [str(items[0][0])]
	var opt := UI.option(items, chosen[0], func(val): chosen[0] = str(val))
	opt.fit_to_longest_item = false
	v.add_child(opt)
	v.add_child(UI.text("Body", T("ui.swap.cash")))
	var cash := SpinBox.new()
	cash.min_value = 0
	cash.max_value = 1000000
	cash.step = 10
	cash.value = 0
	cash.custom_minimum_size = Vector2(160, 0)
	v.add_child(cash)
	dlg.add_child(v)
	dlg.confirmed.connect(func():
		var r := MarketActions.make_swap_offer(w, p, w.player(chosen[0]), maxi(0, int(cash.value)))
		if r["ok"]:
			Game.mark_dirty()
		main.toast(T(str(r["key"])), "check-circle" if r["ok"] else "x-circle", "ok" if r["ok"] else "error")
		dlg.queue_free()
		refresh())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _loan_list_option() -> void:
	p.loan_option_fee = Economy.asking_price(Game.world, p)
	if not p.loan_listed:
		MarketActions.toggle_loan_list(Game.world, p)
	Game.mark_dirty()
	main.toast(T("ui.market.loan_listed_option"))
	refresh()


func _request_loan(buy_option: int = 0) -> void:
	if _embargo():
		main.toast(T("ui.market.embargo"), "x-circle", "error")
		return
	var r := MarketActions.request_loan(Game.world, p, buy_option)
	main.toast(T(str(r["key"])), "check-circle" if r["ok"] else "x-circle", "ok" if r["ok"] else "error")
	if r["ok"]:
		Game.mark_dirty()
		go("squad")
	else:
		refresh()


func _negotiate_dialog() -> void:
	var w := Game.world
	var ask := Economy.asking_price(w, p)
	var dlg := AcceptDialog.new()
	dlg.title = T("ui.action.negotiate_menu").trim_suffix("…")
	dlg.ok_button_text = T("ui.cancel")
	var v := UI.vbox(6)
	v.custom_minimum_size = Vector2(420, 0)
	var head := UI.text("Body", T("ui.negotiate.head") % [p.name(), Game.club_name(p.club_id), Game.galleons(ask)])
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(400, 0)
	v.add_child(head)
	var budget := UI.text("Meta", _budget_text())
	budget.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	budget.custom_minimum_size = Vector2(400, 0)
	v.add_child(budget)
	var embargo := _embargo()
	if embargo:
		var el := UI.text("BodyMedium", T("ui.market.embargo"))
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.custom_minimum_size = Vector2(400, 0)
		el.add_theme_color_override("font_color", ThemeBuilder.SEALING_WAX)
		v.add_child(el)
	v.add_child(UI.rule())
	var opts: Array = [
		[T("ui.action.offer") % Game.galleons(ask), func(): _offer(ask)],
		[T("ui.action.offer_low") % Game.galleons(int(ask * 0.8)), func(): _offer(int(ask * 0.8))],
		[T("ui.action.offer_installments") % Game.galleons(ask), func(): _offer(ask, 3)],
		[T("ui.action.swap"), _swap_dialog],
		[T("ui.action.loan_request"), _request_loan],
		[T("ui.action.loan_request_option") % Game.galleons(ask), func(): _request_loan(ask)],
	]
	var n_bids := opts.size()
	if Contracts.pre_contract_allowed(w, p, Game.my_club()):
		opts.append([T("ui.action.pre_contract"), _pre_contract])
	for i in opts.size():
		var cb: Callable = opts[i][1]
		var b := UI.button(str(opts[i][0]), func(): dlg.hide(); dlg.queue_free(); cb.call())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = embargo and i < n_bids
		v.add_child(b)
	dlg.add_child(v)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.reset_size()
	dlg.popup_centered()


func _sign_free() -> void:
	if _embargo():
		main.toast(T("ui.market.embargo_free"), "x-circle", "error")
		return
	_negotiate("free")


func _renew() -> void:
	_negotiate("renew")


func _pre_contract() -> void:
	_negotiate("pre")


func _negotiate(context: String) -> void:
	var me := Game.my_club()
	if me == null:
		return
	var dlg := ContractDialog.open(self, Game.world, p, me, context)
	dlg.signed.connect(func(r):
		var ok := bool(r["ok"])
		var key := str(r["key"])
		main.toast(T(str(TOAST_KEYS[key])) % p.name() if TOAST_KEYS.has(key) else T(key), "check-circle" if ok else "x-circle", "ok" if ok else "error")
		if ok and Game.engine != null:
			Game.engine.settle_owls()
		Game.world_changed.emit()
		refresh())


func _make_captain() -> void:
	var team_id: String = Schools.house_id(p.school_id, p.house) if p.squad == Player.Squad.SCHOOL else p.club_id
	for q in Game.world.squad_of(team_id):
		q.is_captain = (q.id == p.id)
	Game.mark_dirty()
	main.toast(T("ui.label_value") % [T("ui.captain"), p.name()])
	refresh()


func _confirm_release() -> void:
	var cost := MarketActions.remaining_wages(Game.world, p)
	_terminate_dialog(T("ui.action.release"), T("ui.confirm_release_paid") % [p.name(), Game.galleons(cost)], cost)


func _mutual() -> void:
	var terms := MarketActions.mutual_terms(Game.world, p)
	if not bool(terms["ok"]):
		main.toast(T(str(terms["key"])) % p.name() if str(terms["key"]) == "ui.mutual.refused" else T(str(terms["key"])), "x-circle", "error")
		return
	_terminate_dialog(T("ui.action.mutual"), T("ui.mutual.offer") % [p.name(), Game.galleons(int(terms["cost"])), Game.galleons(int(terms["remaining"]))], int(terms["cost"]))


func _terminate_dialog(title: String, text: String, cost: int) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.cancel_button_text = T("ui.cancel")
	UI.cancel_right(dlg)
	dlg.title = title
	dlg.dialog_text = text
	dlg.ok_button_text = title
	dlg.confirmed.connect(func():
		dlg.queue_free()
		if MarketActions.terminate_contract(Game.world, p, cost):
			main.toast(T("ui.label_value") % [title, p.name()])
			Game.world_changed.emit()
			go("squad")
		else:
			main.toast(T("ui.mutual.no_money") % Game.galleons(cost)))
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _arrow(val: float, prev: float) -> String:
	var d := val - prev
	if absf(d) < 0.02:
		return ""
	if d >= 1.0:
		return "▲"
	if d > 0.0:
		return "↗"
	if d <= -1.0:
		return "▼"
	return "↘"


func _star_count(ca: float) -> int:
	return clampi(int(round(ca / 36.0)), 1, 5)


func _short_date(day: int) -> String:
	if day <= 0:
		return "—"
	var months := T("ui.months_short").split(",")
	var mi := WDate.month(day) - 1
	return T("ui.date_month_year", {"mon": months[mi] if mi < months.size() else str(mi + 1), "m": WDate.month(day), "y": WDate.year(day)})


func _personality() -> String:
	var prof := p.hid("professionalism")
	var amb := p.hid("ambition")
	var temp := p.hid("temperament")
	var loy := p.hid("loyalty")
	var contr := p.hid("controversy")
	if prof >= 16:
		return T("personality.model_professional")
	if contr >= 16:
		return T("personality.controversial")
	if temp >= 16:
		return T("personality.temperamental")
	if amb >= 16:
		return T("personality.ambitious")
	if loy >= 16:
		return T("personality.loyal")
	if prof <= 5:
		return T("personality.casual")
	return T("personality.balanced")
