extends UIScreen
## Post-match press conference: two or three questions from the Daily Prophet, four answers each (modest,
## confident, critical, evasive) with an effect on squad morale, board confidence and reputation. The assistant
## can take the rest of the questions instead (no effect).

var qs: Array = []
var idx := 0
var body: VBoxContainer
var fixture_id := ""
var last_effect := ""
var delegated := false


func build() -> void:
	header(T("press.subject"), T("ui.press.from"))
	if params.has("pre_fixture"):
		_build_pre()
		return
	var lm := Game.engine.last_match
	fixture_id = str(params.get("fixture_id", ""))
	if str(Game.world.settings.get("press_done", "")) == fixture_id:
		_missed()
		return
	if not _resume():
		if lm == null or str(lm.fixture["id"]) != fixture_id:
			_missed()
			return
		var r := lm.result
		var comp: Competition = Game.world.competitions.get(lm.comp_id)
		var my_id: String = r.home_id if Game.engine._is_human(r.home_id) else r.away_id
		qs = Press.questions(Game.world, r, my_id, comp)
		Press.remember(Game.world, my_id, qs, false)
		_save_progress()
	var p := UI.panel(18)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body = UI.vbox(10)
	body.custom_minimum_size = Vector2(760, 0)
	p.add_child(body)
	var c := CenterContainer.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(p)
	root.add_child(c)


var pre := false


func _missed() -> void:
	if pre:
		Game.engine.end_pre_press(fixture_id)
	root.add_child(UI.text("Body", T("ui.press.missed")))
	root.add_child(UI.button(T("ui.back"), func(): go("inbox")))


func _build_pre() -> void:
	pre = true
	fixture_id = str(params["pre_fixture"])
	var comp: Competition = Game.world.competitions.get(str(params.get("comp_id", "")))
	var f: Dictionary = {}
	if comp != null:
		for x in comp.fixtures:
			if str(x["id"]) == fixture_id:
				f = x
	if f.is_empty() or bool(f.get("played", false)) or str(Game.world.settings.get("pre_press_done", "")) == fixture_id or Game.my_club() == null:
		_missed()
		return
	if not _resume():
		qs = Press.pre_questions(Game.world, Game.my_club().id, f, comp, Game.engine._weather_for(f))
		Press.remember(Game.world, Game.my_club().id, qs, true)
		_save_progress()
	var p := UI.panel(18)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body = UI.vbox(10)
	body.custom_minimum_size = Vector2(760, 0)
	p.add_child(body)
	var c := CenterContainer.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(p)
	root.add_child(c)


func refresh() -> void:
	if body == null:
		return
	clear(body)
	if idx >= qs.size():
		_finish()
		body.add_child(UI.subtitle(T("ui.press.done_title")))
		if last_effect != "":
			var lfx := UI.text("Body", T(last_effect), ThemeBuilder.BLUE)
			lfx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(lfx)
		if not delegated:
			var t := UI.text("Prose", T("ui.press.done_body"))
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(t)
		var bh := UI.hbox()
		bh.add_child(UI.spacer())
		bh.add_child(UI.primary(T("ui.post.continue"), func(): go("match" if pre and Game.engine.pending_match != null else "inbox")))
		body.add_child(bh)
		return
	var q: Dictionary = qs[idx]
	body.add_child(UI.text("Caption", T("ui.press.question_n") % [idx + 1, qs.size()]))
	var ql := UI.label(Press.text(q, "press.q." + str(q.get("qkey", q["key"]))), "title", 21, ThemeBuilder.INK)
	ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(ql)
	body.add_child(UI.text("MetaItalic", T("ui.press.reporter")))
	body.add_child(UI.gap(4))
	if last_effect != "":
		var fx := UI.text("Body", T(last_effect), ThemeBuilder.BLUE)
		fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(fx)
		body.add_child(UI.gap(4))
	for tone in Press.TONES:
		var b := UI.button(Press.text(q, "press.a.%s.%s" % [str(q["key"]), tone]), func(): _answer(tone))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.tooltip_text = T("press.tone." + tone)
		body.add_child(b)
	body.add_child(UI.gap(4))
	var ab := UI.button(T("ui.press.assistant"), _delegate)
	ab.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ab.tooltip_text = T("ui.press.assistant_tip")
	body.add_child(ab)


func _answer(tone: String) -> void:
	if idx >= qs.size():
		return
	var q: Dictionary = qs[idx]
	last_effect = Press.apply_pre(Game.world, q, tone) if pre else Press.apply(Game.world, q, tone)
	idx += 1
	_save_progress()
	Game.world_changed.emit()
	refresh()


func _delegate() -> void:
	if idx >= qs.size():
		return
	idx = qs.size()
	delegated = true
	last_effect = "press.effect.assistant"
	_save_progress()
	Game.world_changed.emit()
	refresh()


func _save_progress() -> void:
	Game.world.settings["press_progress"] = {"fixture": fixture_id, "pre": pre, "idx": idx, "qs": qs, "effect": last_effect}


func _resume() -> bool:
	var pr: Variant = Game.world.settings.get("press_progress", {})
	if not (pr is Dictionary) or str(pr.get("fixture", "")) != fixture_id or bool(pr.get("pre", false)) != pre:
		return false
	var stored: Variant = pr.get("qs", [])
	if not (stored is Array) or (stored as Array).is_empty():
		return false
	qs = []
	for q in stored:
		qs.append(_from_json(q))
	idx = int(pr.get("idx", 0))
	last_effect = str(pr.get("effect", ""))
	return true


## Saves are JSON: whole numbers come back as floats ("4.0 goals"); turn them back into ints.
func _from_json(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	if v is Dictionary:
		var d := {}
		for k in v.keys():
			d[k] = _from_json(v[k])
		return d
	if v is Array:
		var a := []
		for x in v:
			a.append(_from_json(x))
		return a
	return v


func _finish() -> void:
	if str(Game.world.settings.get("press_progress", {}).get("fixture", "")) == fixture_id:
		Game.world.settings.erase("press_progress")
	Game.world.settings["pre_press_done" if pre else "press_done"] = fixture_id
	if pre:
		Game.engine.end_pre_press(fixture_id)
