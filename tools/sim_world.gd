extends SceneTree
## Simulates N seasons with no human input and reports whether the world stays healthy (docs/design/09 §8).
## godot --headless --path . -s tools/sim_world.gd -- --seasons 5 [--seed 1] [--save-test]

func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var seasons := 5
	var seed_value := 1
	var save_test := false
	for i in raw.size():
		if raw[i] == "--seasons" and i + 1 < raw.size():
			seasons = int(raw[i + 1])
		if raw[i] == "--seed" and i + 1 < raw.size():
			seed_value = int(raw[i + 1])
		if raw[i] == "--save-test":
			save_test = true
	var loader := SimLoader.new()
	loader.load_all("1993-94")
	var t0 := Time.get_ticks_msec()
	var w := WorldGenerator.new(loader).generate(seed_value)
	var nfx := 0
	for c in w.competitions.values():
		nfx += c.fixtures.size()
	print("world generated in %.1f s: %d clubs, %d players, %d leagues, %d national teams, %d scheduled matches" % [(Time.get_ticks_msec() - t0) / 1000.0, w.clubs.size(), w.players.size(), w.leagues().size(), w.national_teams.size(), nfx])
	var engine := GameEngine.new(loader, w)
	for s in seasons:
		var season := w.season
		var ts := Time.get_ticks_msec()
		var days := 0
		while w.season == season and days < 400:
			engine.advance_day()
			days += 1
		_report_season(w, season, (Time.get_ticks_msec() - ts) / 1000.0)
		if save_test and s == 0:
			_save_test(loader, w)
	print("\n%d seasons in %.1f s | profile: %s" % [seasons, (Time.get_ticks_msec() - t0) / 1000.0, engine.prof])
	_health(w, loader)
	quit()


func _report_season(w: World, season: int, secs: float) -> void:
	var champs := []
	for item in w.history:
		if int(item["season"]) == season:
			var comp: Competition = w.competitions.get(str(item["competition_id"]))
			var cname: String = comp.display_name() if comp else str(item.get("name", item["competition_id"]))
			champs.append("%s: %s" % [cname.replace("Liga ", "").replace("League", "").strip_edges(), w.team_name(str(item["champion_id"]))])
	print("%d-%02d (%.0f s)  %s" % [season, (season + 1) % 100, secs, " | ".join(champs)])


func _health(w: World, loader: SimLoader) -> void:
	print("\n=== world health ===")
	var ages := {}
	var cas := []
	var free := 0
	var abroad := 0
	var total := 0
	for p in w.players.values():
		total += 1
		if p.squad == Player.Squad.ABROAD:
			abroad += 1
			continue
		if p.club_id == "":
			free += 1
			continue
		var a: int = p.age(w.today)
		ages[a / 5 * 5] = int(ages.get(a / 5 * 5, 0)) + 1
		cas.append(p.ca())
	cas.sort()
	print("players %d (free %d, abroad %d) | CA median %.0f, p10 %.0f, p90 %.0f, max %.0f" % [total, free, abroad, cas[cas.size() / 2], cas[cas.size() / 10], cas[cas.size() * 9 / 10], cas[-1]])
	var keys := ages.keys()
	keys.sort()
	var parts := []
	for k in keys:
		parts.append("%d-%d: %d" % [k, k + 4, ages[k]])
	print("ages  ", " | ".join(parts))
	var ok := true
	for comp in w.leagues():
		var bal := 0
		var short := 0
		var cas_l := []
		for cid in comp.club_ids:
			var club: Club = w.clubs[cid]
			bal += club.balance
			var squad := w.squad_of(cid)
			var pos := {"K": 0, "C": 0, "B": 0, "S": 0}
			for p in squad:
				pos[p.position] += 1
				cas_l.append(p.ca())
			if pos["K"] < 1 or pos["C"] < 3 or pos["B"] < 2 or pos["S"] < 1:
				short += 1
				ok = false
		cas_l.sort()
		print("%-34s level %d · %2d clubs · avg balance %6d G · CA median %3.0f · short %d" % [comp.display_name(), comp.level, comp.club_ids.size(), bal / maxi(comp.club_ids.size(), 1), cas_l[cas_l.size() / 2] if not cas_l.is_empty() else 0.0, short])
	var can_field := 0
	for nt_id in w.national_teams.keys():
		if NationalTeams.sim_team(w, nt_id, loader.brooms).players.size() == 7:
			can_field += 1
	print("national teams able to field 7: %d/%d" % [can_field, w.national_teams.size()])
	print("transfers recorded: %d | news: %d editions | live competitions: %d | history: %d" % [w.transfers.size(), w.news.size(), w.competitions.size(), w.history.size()])
	print("complete squads: ", ok)


func _save_test(loader: SimLoader, w: World) -> void:
	var err := SaveManager.save(w, "_test_sim_world")
	var w2 := SaveManager.load("_test_sim_world")
	var same := w2 != null and w2.today == w.today and w2.players.size() == w.players.size() and w2.clubs.size() == w.clubs.size()
	print("save/load: %s (err %d) — %d players, day %s" % ["ok" if same else "FAILED", err, (w2.players.size() if w2 else -1), (WDate.to_iso(w2.today) if w2 else "-")])
	SaveManager.delete_save("_test_sim_world")
