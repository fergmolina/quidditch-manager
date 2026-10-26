extends SceneTree
## Replays on the real engine the paths that the model of .claude/skills/formal-match-day checks with a match pending
## since 2026-10-25: a save and reload (before kickoff, after the final whistle), a club change, a resignation and a
## national-team change. The last three scenarios run on a day when the manager's club and national team both play
## (a World Cup fixture is moved onto the club's match day). Each scenario passes when every fixture of the day is played, the day
## closes exactly once, and the manager never plays a match of a team they no longer manage. Exit code 0 when all
## pass, 1 otherwise.
## Run: HOME=/tmp/qm-probe godot --headless --path . -s .claude/skills/formal-match-day/probe-pending-match.gd
## (HOME redirected so the probe's temporary save `_formal_probe_pending` never touches your own saves.)

class CountingEngine extends GameEngine:
	var closes: Dictionary = {}
	func _init(l: SimLoader, wi: World) -> void:
		super(l, wi)
	func _queue_end_of_day() -> void:
		closes[w.today] = int(closes.get(w.today, 0)) + 1
		super()

var loader := SimLoader.new()
var problems := 0


func _init() -> void:
	loader.load_all("1993-94")
	scenario("save + reload with the club match pending", "reload", false)
	scenario("save + reload after the final whistle, before Finish", "reload_after_whistle", false)
	scenario("accept another club with the club match pending", "accept_job", false)
	scenario("resign with the club match pending", "resign", false)
	scenario("club and national match on one day: save + reload with the club match pending", "reload", true)
	scenario("club and national match on one day: take another national team with the club match pending", "accept_nt", true)
	scenario("club and national match on one day: accept another club with the club match pending", "accept_job", true)
	print("\nPROBLEMS: ", problems)
	quit(1 if problems > 0 else 0)


func _fixture(w: World, fid: String) -> Dictionary:
	for c in w.competitions.values():
		for f in c.fixtures:
			if str(f["id"]) == fid:
				return f
	return {}


func _resolve(w: World) -> void:
	Inbox.close_blocking(w)


func scenario(label: String, action: String, with_nt: bool) -> void:
	print("\n== ", label)
	var w := WorldGenerator.new(loader).generate(7)
	w.player_club_id = "club_puddlemere_united"
	w.my_club().manager_is_human = true
	var e := CountingEngine.new(loader, w)
	var club_fx := {}
	var nt_fx := {}
	var r := {"reason": ""}
	var guard := 0
	while r["reason"] != "match" and guard < 90:
		if club_fx.is_empty():
			for c in w.competitions.values():
				for f in c.fixtures_on(w.today + 1):
					if f["home_id"] == w.player_club_id or f["away_id"] == w.player_club_id:
						club_fx = f
			if with_nt and not club_fx.is_empty():
				for f in w.competitions["comp_world_cup_1994_groups"].fixtures:
					if not bool(f.get("played", false)):
						nt_fx = f
						break
				nt_fx["day"] = w.today + 1
				e.accept_national_job(str(nt_fx["home_id"]))
		r = e.advance_day()
		_resolve(w)
		guard += 1
	var day := w.today
	var pending_id := str(e.pending_match.fixture["id"]) if e.pending_match != null else "NONE"
	print("stop: reason=", r["reason"], " day=", WDate.to_iso(day), " pending=", pending_id, " club fixture=", club_fx["id"], (" nt fixture=" + str(nt_fx["id"])) if with_nt else "")
	var fids := [str(club_fx["id"])] + ([str(nt_fx["id"])] if with_nt else [])
	var e2 := e
	var w2 := w
	match action:
		"reload", "reload_after_whistle":
			if action == "reload_after_whistle":
				while not e.pending_match.sim.is_over():
					e.pending_match.sim.step(1 << 30, 99)
			var err := SaveManager.save(w, "_formal_probe_pending")
			w2 = SaveManager.load("_formal_probe_pending")
			SaveManager.delete_save("_formal_probe_pending")
			e2 = CountingEngine.new(loader, w2)
			e2.closes = e.closes.duplicate()
			print("save=", error_string(err), " reloaded today=", WDate.to_iso(w2.today), " pending after reload=", e2.pending_match != null)
		"accept_job":
			e.accept_job("club_montrose_magpies")
		"resign":
			e.resign()
		"accept_nt":
			var other := ""
			for ntid in w.national_teams.keys():
				if ntid != str(nt_fx["home_id"]) and ntid != str(nt_fx["away_id"]):
					other = ntid
					break
			e.accept_national_job(other)
	print("after ", action, ": club=", w2.player_club_id, " nt=", w2.manager.get("national_team_id", ""), " pending=", (str(e2.pending_match.fixture["id"]) if e2.pending_match != null else "none"))
	var human_played: Array = []
	var r2 := e2.advance_day() if e2.pending_match == null else {"reason": "match"}
	guard = 0
	while (r2["reason"] == "match" or e2.pending_match != null) and guard < 5:
		if e2.pending_match != null:
			human_played.append(str(e2.pending_match.fixture["id"]))
			e2.complete_pending_match()
		r2 = e2.day_result()
		guard += 1
	print("after the first Continue: today=", WDate.to_iso(w2.today), " closes of ", WDate.to_iso(day), "=", e2.closes.get(day, 0), " human played=", human_played, " unplayed of the day=", fids.filter(func(id): return not bool(_fixture(w2, id).get("played", false))))
	for i in 3:
		var rr := e2.advance_day()
		while rr["reason"] == "match" or e2.pending_match != null:
			e2.complete_pending_match()
			rr = e2.day_result()
		_resolve(w2)
	var closes := int(e2.closes.get(day, 0))
	var unplayed := fids.filter(func(id): return not bool(_fixture(w2, id).get("played", false)))
	var foreign := human_played.filter(func(id): var f := _fixture(w2, id); return f["home_id"] != w2.player_club_id and f["away_id"] != w2.player_club_id and f["home_id"] != str(w2.manager.get("national_team_id", "")) and f["away_id"] != str(w2.manager.get("national_team_id", "")))
	var ok := closes == 1 and unplayed.is_empty() and w2.today > day
	print("3 days later: today=", WDate.to_iso(w2.today), " closes of ", WDate.to_iso(day), "=", closes, " unplayed=", unplayed, " played by the human for a team they no longer manage=", foreign, " -> ", "OK" if ok and foreign.is_empty() else "PROBLEM")
	if not ok or not foreign.is_empty():
		problems += 1
