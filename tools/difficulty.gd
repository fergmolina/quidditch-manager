extends SceneTree
## Measures difficulty: the same club over N seasons, run by a "neutral" human (plays the best lineup, touches
## nothing else) versus the same club run by the AI. If the neutral human consistently finishes higher, the AI is
## weak; if they finish level, the player's edge will come only from their own decisions.
## (Modes are labelled "ia" = AI and "humano" = neutral human.)
## godot --headless --path . -s tools/difficulty.gd -- [--club club_wigtown_wanderers] [--seasons 4] [--seed 3]


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var club := "club_wigtown_wanderers"
	var seasons := 4
	var seed_value := 3
	for i in raw.size():
		if raw[i] == "--club" and i + 1 < raw.size():
			club = raw[i + 1]
		if raw[i] == "--seasons" and i + 1 < raw.size():
			seasons = int(raw[i + 1])
		if raw[i] == "--seed" and i + 1 < raw.size():
			seed_value = int(raw[i + 1])
	var loader := SimLoader.new()
	loader.load_all("1993-94")
	for mode in ["ia", "humano"]:
		var w := WorldGenerator.new(loader).generate(seed_value)
		if mode == "humano":
			w.player_club_id = club
			w.my_club().manager_is_human = true
		var engine := GameEngine.new(loader, w)
		var positions := []
		var ranks := []
		for s in seasons:
			var season := w.season
			ranks.append(_ca_rank(w, club))
			var last_month := -1
			while w.season == season:
				var r := engine.advance_day()
				if r["reason"] == "match":
					engine.complete_pending_match()
					while engine.pending_match != null:
						engine.complete_pending_match()
				for d in w.decisions.values():
					Inbox.close(w, d)
				if mode == "humano" and w.player_club_id == club and WDate.month(w.today) != last_month:
					last_month = WDate.month(w.today)
					_housekeeping(w, engine, club)
				if w.player_club_id == "" and mode == "humano":
					break
			var c: Club = w.clubs[club]
			positions.append(int(c.season_summary.get(str(season), {}).get("pos", -1)))
			if mode == "humano" and w.player_club_id == "":
				print("   (sacked in %d)" % season)
				break
		var c: Club = w.clubs[club]
		var sq := w.squad_of(club, [Player.Squad.FIRST, Player.Squad.RESERVE])
		var ca := 0.0
		for p in sq.slice(0, 7):
			ca += p.ca()
		print("%-7s %s: positions %s | CA rank at the start of each season %s | final top-7 CA %.0f | balance %d" % [mode, club, str(positions), str(ranks), ca / 7.0, c.balance])
	quit()


func _housekeeping(w: World, engine: GameEngine, club_id: String) -> void:
	var me: Club = w.clubs[club_id]
	var squad := w.squad_of(club_id, [Player.Squad.FIRST, Player.Squad.RESERVE])
	if WDate.month(w.today) == 6:
		for i in mini(14, squad.size()):
			var p: Player = squad[i]
			if int(p.contract.get("end_day", 0)) <= WDate.from_ymd(w.season + 1, 6, 30) and not p.is_on_loan():
				p.contract["end_day"] = WDate.from_ymd(w.season + 3, 6, 30)
	var count := {"K": 0, "C": 0, "B": 0, "S": 0}
	for p in squad:
		count[p.position] += 1
	var need := {"K": 2, "C": 5, "B": 3, "S": 2}
	for pos in ["K", "C", "B", "S"]:
		while count[pos] < need[pos] and squad.size() < 16:
			var best: Player = null
			for p in w.free_agents():
				if p.position == pos and (me.is_women_only() == false or p.gender == SimPlayer.Gender.F) and (best == null or p.ca() > best.ca()):
					best = p
			if best == null:
				break
			Economy.execute_transfer(w, best, club_id, 0, int(maxf(int(best.contract.get("wage_weekly", 10)), 6)), 2)
			count[pos] += 1
			squad = w.squad_of(club_id, [Player.Squad.FIRST, Player.Squad.RESERVE])
	me.lineup = WorldGenerator.best_lineup(w, club_id)


func _ca_rank(w: World, club_id: String) -> int:
	var comp := w.league_of(club_id)
	var rows := []
	for cid in comp.club_ids:
		var sq := w.squad_of(str(cid), [Player.Squad.FIRST, Player.Squad.RESERVE])
		var ca := 0.0
		for p in sq.slice(0, 7):
			ca += p.ca()
		rows.append([ca, cid])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for i in rows.size():
		if rows[i][1] == club_id:
			return i + 1
	return -1
