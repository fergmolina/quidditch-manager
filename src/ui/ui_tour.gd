class_name UITour
extends RefCounted
## "Robot player" that finds UI bugs without playing by hand. It walks through every screen of the game at
## several points of a save (start, preseason, mid-season, season end), takes a screenshot of each one and checks
## for what usually goes wrong in play:
## - untranslated text (the raw key, "ui.some.thing") and unreplaced placeholders ({x}, %s, %d);
## - screens wider than the window (something pushing the page to the right);
## - short tables that hide rows (they need more height than they have and are not in a useful scroll of their own);
## - clipped table headers and tables whose columns add up to more than their box;
## - screens that fail to open (script error) and empty buttons.
## It starts with a self-test (a fake screen with planted problems) so an empty report can be trusted.
## Usage: godot --path . -- --tour /output/path [--lang de] [--autostart club_x]
## With TOUR_ONLY=market,squad in the environment it visits only those screens; a folder ending in _selftest
## runs only the self-test.
## Leaves the screenshots (<phase>_<screen>.png) and a report (report.txt) in the folder.

const SCREENS := ["inbox", "news", "squad", "lineup", "training", "table", "calendar", "competitions", "players", "national_teams",
	"market", "scouting", "schools", "finances", "staff", "board", "manager", "club", "history", "encyclopedia", "settings"]
const PHASES := [["start", 0], ["preseason", 14], ["season", 100], ["season_end", 330]]

var main: Node
var out_dir := ""
var report: Array = []
var counts := {}
var checked := 0
var _key_re := RegEx.new()
var _ph_re := RegEx.new()


func _init(m: Node, dir: String) -> void:
	main = m
	out_dir = dir
	_key_re.compile("^[a-z][a-z0-9_]*(\\.[a-z0-9_]+){1,}$")
	_ph_re.compile("\\{[a-z_]+\\}|%[sd]")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _self_test()
	if out_dir.ends_with("_selftest"):
		_write_report()
		return
	var e := Game.engine
	e.auto_fix_lineup = true
	var day0 := Game.world.today
	for ph in PHASES:
		while Game.world.today - day0 < int(ph[1]):
			var r := e.advance_day()
			while e.pending_match != null:
				e.complete_pending_match()
			Inbox.close_blocking(Game.world)
			if r["reason"] == "message":
				continue
		await _visit_all(str(ph[0]))
	e.auto_fix_lineup = false
	_write_report()


func _visit_all(phase: String) -> void:
	var list: Array = SCREENS.duplicate() if not OS.has_environment("TOUR_ONLY") else OS.get_environment("TOUR_ONLY").split(",")
	for sid in list:
		await _visit(phase, sid, {})
	var me := Game.my_club()
	if me != null:
		var mine := Game.world.squad_of(me.id)
		if not mine.is_empty():
			await _visit(phase, "player", {"player_id": mine[0].id}, "player_own")
		var lg := Game.world.league_of(me.id)
		if lg != null:
			for cid in lg.club_ids:
				if cid != me.id:
					var other := Game.world.squad_of(str(cid))
					if not other.is_empty():
						await _visit(phase, "player", {"player_id": other[0].id}, "player_other")
						if not mine.is_empty():
							await _visit(phase, "compare", {"a": mine[0].id, "b": other[0].id})
					break
	if Game.engine.last_match != null:
		await _visit(phase, "post_match", {}, "post_match")


func _visit(phase: String, sid: String, params: Dictionary, label: String = "") -> void:
	main.go(sid, params)
	for i in 6:
		await main.get_tree().process_frame
	var name := label if label != "" else sid
	var img: Image = main.get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [out_dir, phase, name])
	var cur: Control = main.current
	if cur == null or str(main.current_id) != sid:
		_add(phase, name, "screen does not open: stayed on \"%s\" (script error or blocked screen)" % str(main.current_id))
		return
	var issues := _audit(cur)
	for iss in issues:
		_add(phase, name, iss)


func _add(phase: String, screen: String, issue: String) -> void:
	var cat := issue.get_slice(":", 0)
	counts[cat] = int(counts.get(cat, 0)) + 1
	var line := "[%s] %s — %s" % [phase, screen, issue]
	if not report.has(line):
		report.append(line)


func _audit(root: Control) -> Array:
	var out: Array = []
	var vw: float = main.get_viewport().get_visible_rect().size.x
	var worst_over := 0.0
	var worst_path := ""
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null or not c.is_visible_in_tree():
			continue
		checked += 1
		var over := c.get_global_rect().end.x - vw
		if over > 4.0 and over > worst_over and not _inside_hscroll(c):
			worst_over = over
			worst_path = _short_path(c)
		var texts: Array = []
		if c is Label:
			texts.append((c as Label).text)
		elif c is Button:
			texts.append((c as Button).text)
			if (c as Button).text.strip_edges() == "" and (c as Button).icon == null and not (c is OptionButton) and not (c is CheckBox):
				out.append("empty button: %s" % _short_path(c))
		elif c is RichTextLabel:
			texts.append((c as RichTextLabel).get_parsed_text())
		if c is OptionButton:
			var ob := c as OptionButton
			for i in ob.item_count:
				texts.append(ob.get_item_text(i))
		if c is Tree:
			_audit_tree(c as Tree, out)
		for t in texts:
			_check_text(str(t), c, out)
	if worst_over > 0.0:
		out.append("screen wider than the window: %d px too wide (%s)" % [int(worst_over), worst_path])
	return out


func _audit_tree(t: Tree, out: Array) -> void:
	var hf: Font = t.get_theme_font("title_button_font")
	var hs: int = t.get_theme_font_size("title_button_font_size")
	var sb: StyleBox = t.get_theme_stylebox("title_button_normal")
	var pad := sb.get_minimum_size().x if sb != null else 0.0
	var total := 0
	for col in t.columns:
		var title := t.get_column_title(col)
		_check_text(title, t, out)
		total += t.get_column_width(col)
		if hf != null and title != "" and t.column_titles_visible:
			var tw := hf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x + pad
			if tw > t.get_column_width(col):
				out.append("clipped header: \"%s\" (%d px in %d) (%s)" % [title, int(tw), t.get_column_width(col), _short_path(t)])
	if total > t.size.x + 2 and t.size.x > 0:
		out.append("table wider than its box: %d px in %d (%s)" % [total, int(t.size.x), _short_path(t)])
	var root := t.get_root()
	if root == null:
		return
	var n := 0
	var it := root.get_first_child()
	while it != null and n < 400:
		if n < 60:
			for col in t.columns:
				_check_text(it.get_text(col), t, out)
		n += 1
		var child := it.get_first_child()
		if child != null:
			it = child
		elif it.get_next() != null:
			it = it.get_next()
		else:
			var up := it.get_parent()
			it = null
			while up != null and up != root:
				if up.get_next() != null:
					it = up.get_next()
					break
				up = up.get_parent()
	var need := 34.0 + 30.0 * n
	if t.size.y < 260.0 and need > t.size.y * 1.6 and n > 4:
		out.append("table with hidden rows: %d rows in %d px (%s)" % [n, int(t.size.y), _short_path(t)])


func _check_text(s: String, c: Control, out: Array) -> void:
	var t := s.strip_edges()
	if t == "":
		return
	if _key_re.search(t) != null and not t.contains(" "):
		out.append("untranslated text: \"%s\" (%s)" % [t, _short_path(c)])
	elif _ph_re.search(t) != null:
		out.append("unreplaced placeholder: \"%s\" (%s)" % [t.left(70), _short_path(c)])


func _inside_hscroll(c: Control) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer and (p as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return true
		if p is Tree:
			return true
		p = p.get_parent()
	return false


func _short_path(c: Node) -> String:
	var parts: Array = []
	var n := c
	for i in 4:
		if n == null:
			break
		parts.push_front(n.get_class() if str(n.name).begins_with("@") else str(n.name))
		n = n.get_parent()
	return "/".join(parts)


func _write_report() -> void:
	var f := FileAccess.open(out_dir + "/report.txt", FileAccess.WRITE)
	f.store_line("UI tour — language %s — %d findings (%d controls checked)" % [TranslationServer.get_locale(), report.size(), checked])
	for k in counts.keys():
		f.store_line("  %s: %d" % [k, counts[k]])
	f.store_line("")
	for l in report:
		f.store_line(l)
	f.close()
	print("tour finished: %d findings → %s/report.txt" % [report.size(), out_dir])
	# The browser build keeps user:// in IndexedDB: the report also goes to the console there.
	if Platform.is_web():
		for l in report:
			print("TOUR: ", l)


func _self_test() -> void:
	var box := VBoxContainer.new()
	main.add_child(box)
	var l1 := Label.new()
	l1.text = "ui.test.raw_key"
	box.add_child(l1)
	var l2 := Label.new()
	l2.text = "Hello {player}"
	box.add_child(l2)
	var t := Tree.new()
	t.custom_minimum_size = Vector2(200, 60)
	t.create_item()
	for i in 12:
		t.create_item(t.get_root()).set_text(0, "row")
	box.add_child(t)
	var t2 := UI.table([{"title": "PLAYER SKILL RATING", "width": 40}], 100)
	t2.custom_minimum_size = Vector2(60, 100)
	t2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(t2)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var found := _audit(box)
	var n := found.size()
	box.queue_free()
	report.append("selftest: %d of 4 planted problems detected%s %s" % [n, "" if n >= 4 else " — SOME CHECK IS NOT WORKING!", str(found)])

