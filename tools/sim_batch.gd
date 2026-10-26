extends SceneTree
## Mass simulation to calibrate the match engine (docs/design/03 §4).
## godot --headless --path . -s tools/sim_batch.gd -- --mode equal --n 2000 [--attr 12]
##   --mode strength --n 2000 --delta 5        (B = A + delta on every attribute)
##   --mode clubs --home club_puddlemere_united --away club_holyhead_harpies --n 500
##   --mode league --n 1                        (full league, n double round-robins)
##   --mode one --home ... --away ... --seed 7 [--min-imp 3]  (log of a single match)
##   --json out.json                            (dumps durations and scores for plotting)

var loader := SimLoader.new()
var args := {}


func _arg(key: String, default: String) -> String:
	return str(args.get(key, default))


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var i := 0
	while i < raw.size():
		var a: String = raw[i]
		if a.begins_with("--"):
			if i + 1 < raw.size() and not raw[i + 1].begins_with("--"):
				args[a.trim_prefix("--")] = raw[i + 1]
				i += 2
				continue
			args[a.trim_prefix("--")] = "true"
		i += 1
	loader.load_all(_arg("pack", "1993-94"))
	var mode := _arg("mode", "equal")
	var t0 := Time.get_ticks_msec()
	match mode:
		"equal":
			_run_pair(SimLoader.synthetic_team("A", float(_arg("attr", "12"))), SimLoader.synthetic_team("B", float(_arg("attr", "12"))), int(_arg("n", "1000")))
		"strength":
			var base := float(_arg("attr", "12"))
			_run_pair(SimLoader.synthetic_team("A", base), SimLoader.synthetic_team("B", base + float(_arg("delta", "5"))), int(_arg("n", "1000")))
		"clubs":
			_run_pair(loader.build_team(_arg("home", "club_puddlemere_united")), loader.build_team(_arg("away", "club_holyhead_harpies")), int(_arg("n", "500")))
		"league":
			_run_league(int(_arg("n", "1")))
		"one":
			_run_one()
		_:
			print("unknown mode: ", mode)
	print("time: %.2f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


func _run_pair(a: SimTeam, b: SimTeam, n: int) -> void:
	var sim := MatchSim.new(loader.rules, loader.params)
	sim.min_log_importance = int(_arg("min-imp", "3"))
	if args.has("a-tactic"):
		var kv := _arg("a-tactic", "").split("=")
		a.tactics[kv[0]] = kv[1]
	var results: Array[MatchResult] = []
	for k in n:
		var r: MatchResult = sim.run(a, b, 1000 + k) if k % 2 == 0 else sim.run(b, a, 1000 + k)
		results.append(r)
	_report(results, a.id, b.id)
	if args.has("json"):
		_dump_json(results, _arg("json", "out.json"))


func _run_league(rounds: int) -> void:
	var ids := loader.club_ids()
	var teams := {}
	for cid in ids:
		teams[cid] = loader.build_team(cid)
	var sim := MatchSim.new(loader.rules, loader.params)
	sim.min_log_importance = int(_arg("min-imp", "3"))
	var table := {}
	for cid in ids:
		table[cid] = {"pts": 0, "against": 0, "catches": 0, "w": 0, "d": 0, "l": 0, "pj": 0}
	var results: Array[MatchResult] = []
	var seed := 5000
	for r in rounds:
		for i in ids.size():
			for j in ids.size():
				if i == j:
					continue
				seed += 1
				var res: MatchResult = sim.run(teams[ids[i]], teams[ids[j]], seed)
				results.append(res)
				for pair in [[res.home_id, res.score_home, res.score_away], [res.away_id, res.score_away, res.score_home]]:
					var row: Dictionary = table[pair[0]]
					row["pts"] += pair[1]
					row["against"] += pair[2]
					row["pj"] += 1
					if pair[1] > pair[2]:
						row["w"] += 1
					elif pair[1] == pair[2]:
						row["d"] += 1
					else:
						row["l"] += 1
				if res.snitch_team_id != "":
					table[res.snitch_team_id]["catches"] += 1
	var sorted_ids := ids.duplicate()
	sorted_ids.sort_custom(func(x, y): return table[x]["pts"] > table[y]["pts"])
	print("\n%-28s %3s %3s %3s %3s %7s %7s %5s  level" % ["Club", "P", "W", "D", "L", "POINTS", "AGAINST", "SNITCH"])
	for cid in sorted_ids:
		var row: Dictionary = table[cid]
		print("%-28s %3d %3d %3d %3d %7d %7d %5d   %d" % [teams[cid].name, row["pj"], row["w"], row["d"], row["l"], row["pts"], row["against"], row["catches"], int(loader.clubs[cid].get("level", 0))])
	_report(results, "", "")
	if args.has("json"):
		_dump_json(results, _arg("json", "out.json"))


func _run_one() -> void:
	var home := loader.build_team(_arg("home", "club_puddlemere_united"))
	var away := loader.build_team(_arg("away", "club_holyhead_harpies"))
	var sim := MatchSim.new(loader.rules, loader.params)
	var r := sim.run(home, away, int(_arg("seed", "7")))
	var min_imp := int(_arg("min-imp", "3"))
	print("\n", r.summary())
	for e in r.events:
		if e.importance >= min_imp:
			print("[%s] %-18s %-26s %s %s  (%d-%d)" % [e.clock_text(), e.type, e.team_id.trim_prefix("club_"), e.player_id, e.other_player_id, e.score_home, e.score_away])
	print("\nHome stats: ", r.home_stats)
	print("Away stats: ", r.away_stats)
	print("events: %d, rng calls: %d" % [r.events.size(), r.rng_calls])


func _percentile(sorted: Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	var idx := int(floor(q * (sorted.size() - 1)))
	return float(sorted[idx])


func _report(results: Array[MatchResult], a_id: String, b_id: String) -> void:
	var n := results.size()
	if n == 0:
		return
	var durations: Array = []
	var goals_per_hour := 0.0
	var gph_count := 0
	var score_sum := 0.0
	var catcher_wins := 0
	var catches := 0
	var b_wins := 0
	var draws := 0
	var a_catches := 0
	var b_catches := 0
	var under40 := 0
	var over4h := 0
	var over1d := 0
	var ends := {}
	var injuries := 0
	var fouls := 0
	var send_offs := 0
	var penalties := 0
	var timeouts := 0
	var feints := 0
	for r in results:
		var mins := r.duration_minutes()
		durations.append(mins)
		if mins < 40.0:
			under40 += 1
		if mins > 240.0:
			over4h += 1
		if mins > 1440.0:
			over1d += 1
		ends[r.end_reason] = int(ends.get(r.end_reason, 0)) + 1
		var goals := r.home_goals() + r.away_goals()
		if mins > 0.0:
			goals_per_hour += goals / (mins / 60.0)
			gph_count += 1
		score_sum += (r.score_home + r.score_away) / 2.0
		if r.snitch_team_id != "":
			catches += 1
			if r.winner_id() == r.snitch_team_id:
				catcher_wins += 1
			if r.snitch_team_id == a_id:
				a_catches += 1
			elif r.snitch_team_id == b_id:
				b_catches += 1
		if r.winner_id() == b_id:
			b_wins += 1
		elif r.winner_id() == "":
			draws += 1
		injuries += int(r.home_stats.get("injuries", 0)) + int(r.away_stats.get("injuries", 0))
		fouls += int(r.home_stats.get("fouls", 0)) + int(r.away_stats.get("fouls", 0))
		send_offs += int(r.home_stats.get("send_offs", 0)) + int(r.away_stats.get("send_offs", 0))
		penalties += int(r.home_stats.get("penalties_for", 0)) + int(r.away_stats.get("penalties_for", 0))
		timeouts += int(r.home_stats.get("timeouts", 0)) + int(r.away_stats.get("timeouts", 0))
	durations.sort()
	print("\n=== %d matches ===" % n)
	print("duration  median %.0f min | p10 %.0f | p25 %.0f | p75 %.0f | p90 %.0f | max %.0f" % [_percentile(durations, 0.5), _percentile(durations, 0.1), _percentile(durations, 0.25), _percentile(durations, 0.75), _percentile(durations, 0.9), durations[-1]])
	print("<40 min %.1f%% (target 10)  | >4 h %.1f%% (target 5)  | >1 day %.2f%% (target 0.5)" % [100.0 * under40 / n, 100.0 * over4h / n, 100.0 * over1d / n])
	print("goals/hour avg %.1f (target ~15, range 5-35) | avg score per team %.0f (target 150-350)" % [goals_per_hour / maxf(gph_count, 1), score_sum / n])
	print("catcher wins %.1f%% (target 85-93) | catches %d/%d | end: %s" % [100.0 * catcher_wins / maxf(catches, 1), catches, n, ends])
	if b_id != "":
		print("wins for %s: %.1f%% | draws %.1f%% | catches A %d / B %d" % [b_id, 100.0 * b_wins / n, 100.0 * draws / n, a_catches, b_catches])
	print("per match: fouls %.1f | penalties %.1f | injuries %.2f | send-offs %.2f | timeouts %.2f" % [float(fouls) / n, float(penalties) / n, float(injuries) / n, float(send_offs) / n, float(timeouts) / n])


func _dump_json(results: Array[MatchResult], path: String) -> void:
	var rows := []
	for r in results:
		rows.append({"min": r.duration_minutes(), "home": r.score_home, "away": r.score_away, "home_id": r.home_id, "away_id": r.away_id, "home_name": r.home_name, "away_name": r.away_name, "snitch": r.snitch_team_id, "end": r.end_reason, "hg": r.home_goals(), "ag": r.away_goals()})
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(rows))
	f.close()
	print("dumped to ", path)
