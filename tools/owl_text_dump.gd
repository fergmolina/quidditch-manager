extends SceneTree
## Renders every owl and news item of a fixed career to a text file, plain and rich, and prints the world RNG's call
## count and state, so a change to how owls and news are stored can be diffed as text with the same random draws.
## godot --headless --path . -s tools/owl_text_dump.gd -- --out <file> [--days 60] [--lang en] [--club club_id] [--seed 7]
## Blocking owls are closed unanswered each morning, as main.gd's --advance does; matches are played out.

const GameSessionScript := preload("res://src/game/game_session.gd")

var gs: GameSessionScript


func _init() -> void:
	_run()
	quit()


func _run() -> void:
	var args := {"--out": "user://owl_text_dump.txt", "--days": "60", "--lang": "en", "--club": "club_puddlemere_united", "--seed": "7"}
	var raw := OS.get_cmdline_user_args()
	for i in raw.size() - 1:
		if args.has(raw[i]):
			args[raw[i]] = raw[i + 1]
	TranslationServer.set_locale(args["--lang"])
	SaveManager.saves_dir = "user://owl_dump_saves"
	gs = GameSessionScript.new()
	gs.loader.load_all("1993-94")
	gs.new_game(args["--club"], "Manager", "eng", int(args["--seed"]))
	var w := gs.world
	gs.engine.auto_fix_lineup = true
	for d in int(args["--days"]):
		_close_blocking(w)
		var r: Dictionary = gs.engine.advance_day()
		while r["reason"] == "match" or gs.engine.pending_match != null:
			gs.engine.complete_pending_match()
			r = {"reason": ""}
	var lines: PackedStringArray = []
	lines.append_array(_owl_lines(w))
	lines.append_array(_news_lines(w))
	var f := FileAccess.open(args["--out"], FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("owl_text_dump: %d lines, day %d, rng calls %d, rng state %s -> %s" % [lines.size(), w.today, w.rng().calls, str(w.rng().get_state()), args["--out"]])
	gs.free()


func _close_blocking(w: World) -> void:
	Inbox.close_blocking(w)


func _owl_lines(w: World) -> PackedStringArray:
	var out: PackedStringArray = []
	for o in w.inbox:
		var v := Inbox.view(w, o.id, true)
		out.append("OWL %d day %d %s%s%s" % [o.id, o.day, v.from_text, " OPEN" if v.open else "", " BLOCKING" if v.blocking else ""])
		out.append("  subject: " + Say.render(o.subject))
		out.append("  body: " + Say.render(o.body))
		out.append("  rich subject: " + v.subject)
		out.append("  rich body: " + v.body)
		for ch in v.choices:
			out.append("  choice: " + str(ch["label"]))
		if v.outcome != "":
			out.append("  outcome: " + v.outcome)
		if o.link != &"":
			out.append("  link: " + str(o.link))
	return out


func _news_lines(w: World) -> PackedStringArray:
	var out: PackedStringArray = []
	for e in w.news:
		for it in e.get("items", []):
			out.append_array(_news_item(it, "NEWS edition %d day %d" % [int(e.get("edition", 0)), int(e.get("day", 0))]))
	for it in w.news_buffer:
		out.append_array(_news_item(it, "NEWS buffer"))
	return out


func _news_item(it: Dictionary, head: String) -> PackedStringArray:
	var ph := Say.Phrase.from_dict(it)
	return [head + " " + ph.key, "  text: " + Say.render(ph).replace("\n", " / "), "  rich: " + Say.render(ph, true).replace("\n", " / ")]
