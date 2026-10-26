extends SceneTree
## Stress test: N seasons with per-season invariants and behaviour metrics.
## godot --headless --path . -s tools/stress_test.gd -- --seasons 50 [--seed 1] [--human club_id] [--save-every 10]
## With --human, the human club plays all its matches straight through and answers owls at random (exercises
## offers, contracts, press, promises, national team, board).

const MAX_LIVE_COMPETITIONS := 95

var anomalies: Array = []
var season_rows: Array = []
var rng := RandomNumberGenerator.new()


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var seasons := 50
	var seed_value := 1
	var human := ""
	var save_every := 0
	var watch := ""
	for i in raw.size():
		if raw[i] == "--watch" and i + 1 < raw.size():
			watch = raw[i + 1]
		if raw[i] == "--seasons" and i + 1 < raw.size():
			seasons = int(raw[i + 1])
		if raw[i] == "--seed" and i + 1 < raw.size():
			seed_value = int(raw[i + 1])
		if raw[i] == "--human" and i + 1 < raw.size():
			human = raw[i + 1]
		if raw[i] == "--save-every" and i + 1 < raw.size():
			save_every = int(raw[i + 1])
	rng.seed = seed_value
	var loader := SimLoader.new()
	loader.load_all("1993-94")
	var w := WorldGenerator.new(loader).generate(seed_value)
	if human != "" and (w.clubs.has(human) or w.houses.has(human)):
		w.player_club_id = human
		if w.houses.has(human):
			w.houses[human]["human"] = true
			w.my_club().lineup = Schools.best_lineup(w, human)
		w.my_club().manager_is_human = true
		w.manager = {"name": "Stress", "nationality": "eng", "reputation": 1400, "career": []}
	var engine := GameEngine.new(loader, w)
	var t0 := Time.get_ticks_msec()
	var base_players := w.players.size()
	for s in seasons:
		var season := w.season
		var ts := Time.get_ticks_msec()
		var days := 0
		var human_matches := 0
		var msgs_answered := 0
		var watch_n := -1
		while w.season == season and days < 420:
			var r := engine.advance_day()
			days += 1
			if watch != "":
				var ids := []
				for p in w.club_players(watch):
					ids.append("%s/%s" % [p.position, p.squad])
				if ids.size() != watch_n:
					print("      %s %s: %d players %s" % [WDate.to_iso(w.today), watch, ids.size(), str(ids)])
					watch_n = ids.size()
			if r["reason"] == "match":
				human_matches += 1
				_exercise_match(engine)
				engine.complete_pending_match()
				while engine.pending_match != null:
					engine.complete_pending_match()
			if Inbox.open_count(w) > 0:
				msgs_answered += _answer_messages(w, engine)
		if w.season == season:
			anomalies.append("%d: season did not finish within 420 days" % season)
		_check_season(w, engine, loader, season, base_players)
		var row := _metrics(w, engine, season, (Time.get_ticks_msec() - ts) / 1000.0, human_matches, msgs_answered)
		season_rows.append(row)
		print(row)
		if save_every > 0 and (s + 1) % save_every == 0:
			_save_roundtrip(w, loader, season)
	print("\n=== %d seasons in %.0f s ===" % [seasons, (Time.get_ticks_msec() - t0) / 1000.0])
	print("anomalies: %d" % anomalies.size())
	for a in anomalies:
		print("  ! ", a)
	quit(1 if not anomalies.is_empty() else 0)


func _exercise_match(engine: GameEngine) -> void:
	var ctx := engine.pending_match
	var sim := ctx.sim
	var mine := ctx.home if ctx.home.is_human else ctx.away
	sim.step(60, MatchEvent.Importance.NEVER_STOP)
	if rng.randf() < 0.5:
		sim.queue_tactics(mine, {"mentality": rng.randi_range(5, 15), "seeker_catch": ["always", "if_wins", "ahead_by"][rng.randi_range(0, 2)]})
	if rng.randf() < 0.3:
		sim.request_timeout(mine)
		TeamTalk.apply(mine, TeamTalk.TONES[rng.randi_range(0, 3)], mine.score - (ctx.away if mine == ctx.home else ctx.home).score, false, rng.randi())


func _answer_messages(w: World, engine: GameEngine) -> int:
	var n := 0
	for d in w.decisions.values():
		if not w.decisions.has(d.owl_id):
			continue
		Inbox.choose(w, engine, d.owl_id, rng.randi_range(0, d.choices.size() - 1), true)
		Inbox.close(w, d)
		n += 1
	return n


func _check_season(w: World, engine: GameEngine, loader: SimLoader, season: int, base_players: int) -> void:
	for comp in w.leagues():
		var unplayed := 0
		for f in comp.fixtures:
			if int(f.get("season", comp.season)) == season and not bool(f.get("played", false)):
				unplayed += 1
	var hist_this := 0
	for h in w.history:
		if int(h["season"]) == season and str(h["competition_id"]).begins_with("comp_") and w.competitions.has(str(h["competition_id"])) and w.competitions[str(h["competition_id"])].type == "league":
			hist_this += 1
			if int(h.get("table", []).size()) != w.competitions[str(h["competition_id"])].club_ids.size():
				anomalies.append("%d: incomplete table in %s" % [season, h["competition_id"]])
	if hist_this != w.leagues().size():
		anomalies.append("%d: %d leagues with a champion out of %d" % [season, hist_this, w.leagues().size()])
	for c in w.clubs_sorted():
		var squad := w.squad_of(c.id)
		var pos := {"K": 0, "C": 0, "B": 0, "S": 0}
		for p in squad:
			pos[p.position] += 1
			if p.club_id != c.id:
				anomalies.append("%d: inconsistent index %s in %s" % [season, p.id, c.id])
		if pos["K"] < 1 or pos["C"] < 3 or pos["B"] < 2 or pos["S"] < 1:
			anomalies.append("%d: %s short of players %s" % [season, c.id, str(pos)])
			for p in w.club_players(c.id):
				print("      %s %s %s age %d loan=%s end=%s" % [p.id, p.position, p.squad, p.age(w.today), str(p.is_on_loan()), WDate.to_iso(int(p.contract.get("end_day", 0)))])
			var last_t := []
			for t in w.transfers.slice(0, 40):
				if str(t.get("from_id", "")) == c.id or str(t.get("to_id", "")) == c.id:
					last_t.append(t)
			print("      recent transfers: ", last_t)
		if squad.size() > GameEngine.MAX_SQUAD + 2 and not c.manager_is_human:
			anomalies.append("%d: %s has %d players" % [season, c.id, squad.size()])
		if c.balance < -40000:
			anomalies.append("%d: %s bankrupt (%d G)" % [season, c.id, c.balance])
	for p in w.players.values():
		var a: int = p.age(w.today)
		if a < 11 or a > 45:
			anomalies.append("%d: impossible age %d (%s, %s)" % [season, a, p.id, p.squad])
		if p.ca() < 1.0 or p.ca() > 200.0 or is_nan(p.ca()):
			anomalies.append("%d: CA out of range %.1f (%s)" % [season, p.ca(), p.id])
		if p.club_id != "" and not w.clubs.has(p.club_id):
			anomalies.append("%d: nonexistent club %s (%s)" % [season, p.club_id, p.id])
		if p.squad == Player.Squad.SCHOOL and (a > 18 or p.house == ""):
			anomalies.append("%d: student out of range %s age %d house '%s'" % [season, p.id, a, p.house])
		if p.is_on_loan() and not w.clubs.has(p.loan.owner_id):
			anomalies.append("%d: orphan loan %s" % [season, p.id])
	for sid in ["school_hogwarts", "school_ilvermorny"]:
		var n := Schools.students_of(w, sid).size()
		if n < 20 or n > 60:
			anomalies.append("%d: %s has %d students" % [season, sid, n])
	if w.competitions.size() > MAX_LIVE_COMPETITIONS:
		anomalies.append("%d: %d live competitions (leak)" % [season, w.competitions.size()])
	if w.inbox.size() > 300 or w.news.size() > 60:
		anomalies.append("%d: inbox %d / news %d" % [season, w.inbox.size(), w.news.size()])
	if w.players.size() > base_players * 1.6:
		anomalies.append("%d: players %d (base %d): leak" % [season, w.players.size(), base_players])
	var y := season + 1
	if WorldGenerator.is_world_cup_year(season):
		var found := false
		for h in w.history:
			if str(h["competition_id"]) == "comp_world_cup_%d_final" % season:
				found = true
		if not found:
			anomalies.append("%d: no World Cup champion for %d" % [season, season])
	if (y - 1995) % 3 == 0 and y >= 1995:
		var found_ec := false
		for h in w.history:
			if str(h["competition_id"]) == "comp_european_cup_%d" % y:
				found_ec = true
		if not found_ec:
			anomalies.append("%d: no European Cup champion for %d" % [season, y])


func _metrics(w: World, engine: GameEngine, season: int, secs: float, hm: int, msgs: int) -> String:
	var cas := []
	var ages := 0.0
	var n := 0
	var injured := 0
	var loans := 0
	var free := 0
	for p in w.players.values():
		if p.squad in [Player.Squad.ABROAD, Player.Squad.SCHOOL]:
			continue
		if p.club_id == "":
			free += 1
			continue
		cas.append(p.ca())
		ages += p.age(w.today)
		n += 1
		if p.injury_days > 0:
			injured += 1
		if p.is_on_loan():
			loans += 1
	cas.sort()
	var bal := 0
	var worst := 0
	for c in w.clubs.values():
		bal += c.balance
		worst = mini(worst, c.balance)
	var awards_season := 0
	for a in w.awards:
		if int(a["season"]) == season:
			awards_season += 1
	var me := w.my_club()
	var me_txt := ""
	if me != null and w.is_school_mode():
		var pos := "-"
		for h in w.history:
			if int(h["season"]) == season and str(h["competition_id"]).begins_with("comp_school_"):
				var table: Array = h.get("table", [])
				for i in table.size():
					if str(table[i]["club_id"]) == me.id:
						pos = str(i + 1)
		me_txt = " | human (%s): conf %.0f pos %s matches %d" % [me.name, float(me.board.get("confidence", 0.0)), pos, hm]
	elif me != null:
		me_txt = " | human: cash %d conf %.0f pos %s" % [me.balance, float(me.board.get("confidence", 0.0)), str(me.season_summary.get(str(season), {}).get("pos", "-"))]
	elif w.manager_unemployed:
		me_txt = " | human: no club"
	return "%d-%02d %3.0fs | players %4d (free %3d, inj %3d, loan %3d) age %.1f | CA med %3.0f p90 %3.0f max %3.0f | avg cash %6d worst %7d | awards %2d obj %d%s" % [
		season, (season + 1) % 100, secs, n, free, injured, loans, ages / maxf(n, 1), cas[cas.size() / 2], cas[cas.size() * 9 / 10], cas[-1], bal / maxi(w.clubs.size(), 1), worst, awards_season, Performance.get_monitor(Performance.OBJECT_COUNT), me_txt]


func _save_roundtrip(w: World, loader: SimLoader, season: int) -> void:
	var err := SaveManager.save(w, "_stress")
	var w2 := SaveManager.load("_stress")
	var ok := w2 != null and w2.players.size() == w.players.size() and w2.clubs.size() == w.clubs.size() and w2.today == w.today
	if not ok:
		anomalies.append("%d: save/load failed (err %d)" % [season, err])
	else:
		print("   save/load ok (%d KB)" % (FileAccess.get_file_as_bytes(SaveManager.save_dir("_stress").path_join("world.json.gz")).size() / 1024))
	SaveManager.delete_save("_stress")
