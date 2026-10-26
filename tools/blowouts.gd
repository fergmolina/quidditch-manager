extends SceneTree
## Measures blowouts: simulates every league in the initial world (home and away, each match with its own seed) and
## reports point margins, duration and who catches the Snitch.
## godot --headless --path . -s tools/blowouts.gd


func _init() -> void:
	var loader := SimLoader.new()
	loader.load_all("1993-94")
	var w := WorldGenerator.new(loader).generate(1)
	var engine := GameEngine.new(loader, w)
	var sim := MatchSim.new(loader.rules, loader.params)
	sim.min_log_importance = MatchEvent.Importance.LOG_NONE
	var n := 0
	var big := {100: 0, 200: 0, 300: 0, 500: 0, 1000: 0}
	var max_diff := 0
	var max_txt := ""
	var dur := 0.0
	var caught := 0
	var catcher_wins := 0
	var margins: Array = []
	var seed_v := 1
	for comp in w.leagues():
		var teams := {}
		for cid in comp.club_ids:
			teams[cid] = engine.sim_team_for(cid)
		for a in comp.club_ids:
			for b in comp.club_ids:
				if a == b:
					continue
				seed_v += 1
				var r: MatchResult = sim.run(teams[a], teams[b], seed_v)
				var d := absi(r.score_home - r.score_away)
				margins.append(d)
				n += 1
				for k in big.keys():
					if d >= k:
						big[k] += 1
				dur += r.duration_s / 60.0
				if r.snitch_team_id != "":
					caught += 1
					if r.winner_id() == r.snitch_team_id:
						catcher_wins += 1
				if d > max_diff:
					max_diff = d
					max_txt = "%s %d-%d %s (%d min)" % [w.team_name(a), r.score_home, r.score_away, w.team_name(b), int(r.duration_s / 60.0)]
	margins.sort()
	var pct := func(k): return 100.0 * big[k] / n
	print("BLOW matches=%d | median margin=%d p90=%d p99=%d max=%d" % [n, margins[n / 2], margins[int(n * 0.9)], margins[int(n * 0.99)], max_diff])
	print("BLOW +100: %.1f%%  +200: %.1f%%  +300: %.1f%%  +500: %.1f%%  +1000: %.1f%%" % [pct.call(100), pct.call(200), pct.call(300), pct.call(500), pct.call(1000)])
	print("BLOW avg duration %.0f min | snitch caught %.0f%% | catcher's team wins %.0f%%" % [dur / n, 100.0 * caught / n, 100.0 * catcher_wins / max(caught, 1)])
	print("BLOW biggest blowout: ", max_txt)
	quit()
