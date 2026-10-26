extends SceneTree
## Replays on the real engine the path that broke PastDaysClosed in .claude/skills/formal-match-day before
## 2026-10-25: a match day whose advance stopped over the lineup, then the manager leaves the club (resigns or takes
## another job), saves and reloads, and continues. begin_day must resume the open day from the world's unplayed
## fixture, so the AI plays the old club's held-back fixture and the day closes. Exit code 0 while that holds, 1 if
## any reload scenario skips the fixture again.
## Run: HOME=/tmp/qm-probe godot --headless --path . -s .claude/skills/formal-match-day/probe-known-finding.gd
## (HOME redirected so the probe's temporary save `_formal_probe` never touches your own saves.)

var loader := SimLoader.new()
var violations := 0


func _init() -> void:
	loader.load_all("1993-94")
	run("control: resign, same session (no reload)", false, false)
	run("resign, then save + reload", true, false)
	run("accept another job, then save + reload", true, true)
	print("\n", "VIOLATIONS: ", violations, " of 2 reload scenarios (the control is expected to pass)")
	quit(1 if violations > 0 else 0)


func run(label: String, reload: bool, take_job: bool) -> void:
	print("\n== ", label)
	var w := WorldGenerator.new(loader).generate(7)
	w.player_club_id = "club_puddlemere_united"
	var me := w.my_club()
	me.manager_is_human = true
	var e := GameEngine.new(loader, w)
	# The game's setting: the manager fixes the lineup by hand, so an injured starter blocks the match day.
	e.auto_fix_lineup = false
	var k: Player = w.player(str(me.lineup.get("K", "")))
	k.injury_days = 60
	var r := {"reason": ""}
	var days := 0
	while r["reason"] != "lineup" and days < 60:
		r = e.advance_day()
		Inbox.close_blocking(w)
		days += 1
	var fx := e.human_fixture_today()
	var f: Dictionary = fx.get("fixture", {})
	var fday := w.today
	print("advance stopped: reason=", r["reason"], " today=", WDate.to_iso(w.today), " held-back fixture=", f.get("id", "NONE"), " played=", f.get("played", false))
	if r["reason"] != "lineup":
		print("could not reach a lineup-blocked day; probe inconclusive")
		return
	if take_job:
		e.accept_job("club_montrose_magpies")
	else:
		e.resign()
	print("job change: club=", w.player_club_id, " unemployed=", w.manager_unemployed)
	var w2 := w
	var e2 := e
	if reload:
		var err := SaveManager.save(w, "_formal_probe")
		w2 = SaveManager.load("_formal_probe")
		SaveManager.delete_save("_formal_probe")
		print("save+reload: save=", error_string(err), " loaded=", w2 != null, " today=", WDate.to_iso(w2.today))
		e2 = GameEngine.new(loader, w2)
		e2.auto_fix_lineup = false
	var r2 := e2.advance_day()
	while e2.pending_match != null:
		e2.complete_pending_match()
	Inbox.close_blocking(w2)
	var f2 := _fixture(w2, str(f["id"]))
	print("Continue: reason=", r2["reason"], " today=", WDate.to_iso(w2.today), " old fixture played=", f2.get("played", false))
	for i in 5:
		e2.advance_day()
		while e2.pending_match != null:
			e2.complete_pending_match()
		Inbox.close_blocking(w2)
	f2 = _fixture(w2, str(f["id"]))
	var ok := bool(f2.get("played", false))
	print("5 days later: today=", WDate.to_iso(w2.today), " old fixture played=", ok, " -> ", "OK" if ok else "VIOLATION: the fixture of %s was skipped (and that day never closed)" % WDate.to_iso(fday))
	if not ok:
		violations += 1


func _fixture(w: World, fid: String) -> Dictionary:
	for c in w.competitions.values():
		for f in c.fixtures:
			if str(f["id"]) == fid:
				return f
	return {}
