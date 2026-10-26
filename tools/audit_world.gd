extends SceneTree
## Semantic world audit: looks for inconsistencies rather than crashes (impossible stats, tables that don't
## add up, lineups with injured players, expired contracts still active, awards that don't match the numbers,
## untranslated text, result distributions that break the lore...).
## godot --headless --path . -s tools/audit_world.gd -- [--seasons 4] [--seed 3] [--human club_id]
## Simulates N-1 seasons plus half of one more, audits mid-season, finishes the season and audits the close.

var issues: Dictionary = {}
var infos: Array = []
var rng := RandomNumberGenerator.new()


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var seasons := 4
	var seed_value := 3
	var human := ""
	for i in raw.size():
		if raw[i] == "--seasons" and i + 1 < raw.size():
			seasons = int(raw[i + 1])
		if raw[i] == "--seed" and i + 1 < raw.size():
			seed_value = int(raw[i + 1])
		if raw[i] == "--human" and i + 1 < raw.size():
			human = raw[i + 1]
	rng.seed = seed_value
	var loader := SimLoader.new()
	loader.load_all("1993-94")
	var w := WorldGenerator.new(loader).generate(seed_value)
	if human != "" and w.clubs.has(human):
		w.player_club_id = human
		w.my_club().manager_is_human = true
		w.manager = {"name": "Audit", "nationality": "eng", "reputation": 1400, "career": []}
	var engine := GameEngine.new(loader, w)
	_audit_static(w, loader)
	for s in seasons - 1:
		_run_season(w, engine)
	var ca_start := {}
	for p in w.players.values():
		ca_start[p.id] = p.ca()
	var season := w.season
	for d in 200:
		_step(w, engine)
	print("\n=== Mid-season audit %d-%02d (%s) ===" % [season, (season + 1) % 100, WDate.to_iso(w.today)])
	_audit_live(w, loader, engine, season)
	_audit_results(w, season)
	while w.season == season:
		_step(w, engine)
	print("\n=== Season-end audit %d-%02d ===" % [season, (season + 1) % 100])
	_audit_season_end(w, loader, engine, season, ca_start)
	_audit_texts(w, loader)
	print("\n=== Summary ===")
	for i in infos:
		print("  i ", i)
	var total := 0
	for k in issues.keys():
		var lst: Array = issues[k]
		total += lst.size()
		print("  ! %s (%d)" % [k, lst.size()])
		for d in lst.slice(0, 6):
			print("      ", d)
	print("inconsistencies: %d in %d categories" % [total, issues.size()])
	quit(1 if total > 0 else 0)


func _flag(cat: String, detail: String) -> void:
	if not issues.has(cat):
		issues[cat] = []
	issues[cat].append(detail)


func _run_season(w: World, engine: GameEngine) -> void:
	var season := w.season
	var days := 0
	while w.season == season and days < 420:
		_step(w, engine)
		days += 1


func _step(w: World, engine: GameEngine) -> void:
	var r := engine.advance_day()
	if r["reason"] == "match":
		engine.complete_pending_match()
		while engine.pending_match != null:
			engine.complete_pending_match()
	for d in w.decisions.values():
		if w.decisions.has(d.owl_id):
			Inbox.choose(w, engine, d.owl_id, rng.randi_range(0, d.choices.size() - 1), true)
			Inbox.close(w, d)


func _audit_static(w: World, loader: SimLoader) -> void:
	for c in w.clubs.values():
		var names := {}
		for p in w.club_players(c.id):
			var full: String = p.name()
			if names.has(full):
				_flag("duplicate name in club", "%s: %s" % [c.id, full])
			names[full] = true
			if c.is_women_only() and p.gender != SimPlayer.Gender.F:
				_flag("man in women-only club", "%s in %s" % [p.name(), c.id])
			if not loader.countries.has(p.nationality):
				_flag("unknown nationality", "%s: %s" % [p.id, p.nationality])
		if c.league_id == "" or not w.competitions.has(c.league_id):
			_flag("club without league", c.id)
		elif not w.competitions[c.league_id].club_ids.has(c.id):
			_flag("club not listed in its league", c.id)
	for comp in w.leagues():
		var n := comp.club_ids.size()
		var expected := n * (n - 1)
		if comp.fixtures.size() != expected:
			_flag("incomplete league schedule", "%s: %d matches, expected %d" % [comp.id, comp.fixtures.size(), expected])
		var pairs := {}
		for f in comp.fixtures:
			var key := "%s>%s" % [f["home_id"], f["away_id"]]
			if pairs.has(key):
				_flag("repeated pairing", "%s %s" % [comp.id, key])
			pairs[key] = true
			if f["home_id"] == f["away_id"]:
				_flag("club playing itself", comp.id)
	var canon := 0
	for p in w.players.values():
		if p.source != "filler":
			canon += 1
	infos.append("canon players: %d of %d" % [canon, w.players.size()])
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	var header := f.get_csv_line()
	var row_n := 1
	while not f.eof_reached():
		var row := f.get_csv_line()
		row_n += 1
		if row.size() < 3 or row[0] == "":
			continue
		if row[1].strip_edges() == "" or row[2].strip_edges() == "":
			_flag("empty translation", "row %d %s" % [row_n, row[0]])
			continue
		var ph_es := _placeholders(row[1])
		var ph_en := _placeholders(row[2])
		if ph_es != ph_en:
			_flag("placeholder mismatch ES/EN", "%s: %s vs %s" % [row[0], str(ph_es), str(ph_en)])
	f.close()


func _placeholders(s: String) -> Array:
	var out := []
	var re := RegEx.new()
	re.compile("\\{([a-z_0-9]+)\\}")
	for m in re.search_all(s):
		if not out.has(m.get_string(1)):
			out.append(m.get_string(1))
	out.sort()
	return out


func _audit_live(w: World, loader: SimLoader, engine: GameEngine, season: int) -> void:
	var same_day := 0
	var busy := {}
	for comp in w.competitions.values():
		for f in comp.fixtures:
			if not bool(f.get("played", false)):
				continue
			for side in ["home_id", "away_id"]:
				var key := "%s@%d" % [f[side], int(f["day"])]
				if busy.has(key):
					same_day += 1
					if same_day <= 3:
						_flag("two matches on the same day", "%s %s and %s" % [key, busy[key], comp.id])
				busy[key] = comp.id
	if same_day > 3:
		_flag("two matches on the same day", "... %d in total" % same_day)
	for comp in w.leagues():
		var played := {}
		for f in comp.fixtures:
			if bool(f.get("played", false)):
				played[f["home_id"]] = int(played.get(f["home_id"], 0)) + 1
				played[f["away_id"]] = int(played.get(f["away_id"], 0)) + 1
		for row in comp.standings():
			if int(row["pj"]) != int(played.get(row["club_id"], 0)):
				_flag("table doesn't match the matches", "%s %s pj %d vs %d" % [comp.id, row["club_id"], row["pj"], played.get(row["club_id"], 0)])
			if int(row["w"]) + int(row["d"]) + int(row["l"]) != int(row["pj"]):
				_flag("table doesn't match the matches", "%s %s w+d+l != pj" % [comp.id, row["club_id"]])
	for comp in w.competitions.values():
		for f in comp.fixtures:
			if not bool(f.get("played", false)):
				continue
			var sh := int(f.get("score_home", 0))
			var sa := int(f.get("score_away", 0))
			if sh < 0 or sa < 0 or sh % 10 != 0 or sa % 10 != 0:
				_flag("impossible score", "%s %d-%d" % [comp.id, sh, sa])
			var st := str(f.get("snitch_team_id", ""))
			if st != "":
				if st != str(f["home_id"]) and st != str(f["away_id"]):
					_flag("snitch for a team that wasn't playing", comp.id)
				var catcher_score := sh if st == str(f["home_id"]) else sa
				if catcher_score < 150:
					_flag("snitch without its 150 points", "%s %d-%d snitch %s" % [comp.id, sh, sa, st])
				if str(f.get("end_reason", "")) != MatchResult.EndReason.SNITCH:
					_flag("snitch caught but match ended for another reason", "%s %s" % [comp.id, f.get("end_reason", "")])
			var dur := int(f.get("duration_s", 0))
			if dur <= 0 or dur > 48 * 3600:
				_flag("duration out of range", "%s %d s" % [comp.id, dur])
	for c in w.clubs_sorted():
		if c.manager_is_human:
			continue
		if not engine._lineup_valid(c):
			continue
		var ids: Array = [c.lineup["K"]] + c.lineup["C"] + c.lineup["B"] + [c.lineup["S"]]
		for pid in ids:
			var p: Player = w.player(str(pid))
			if p.squad == Player.Squad.YOUTH and p.age(w.today) < 16:
				_flag("under-16 in the lineup", "%s %s (%d)" % [c.id, p.name(), p.age(w.today)])
	for c in w.clubs_sorted():
		var caps := 0
		for p in w.squad_of(c.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
			if p.is_captain:
				caps += 1
		if caps != 1:
			_flag("captains per club != 1", "%s: %d" % [c.id, caps])
	_audit_players(w, loader, season)


func _audit_players(w: World, loader: SimLoader, season: int) -> void:
	var expiry_past := 0
	var out_of_pos := 0
	for p in w.players.values():
		if p.squad == Player.Squad.SCHOOL:
			var a: int = p.age(w.today)
			if a < 11 or a > 18:
				_flag("student with impossible age", "%s %d" % [p.name(), a])
			continue
		if p.pa < p.ca() - 0.5:
			_flag("CA greater than PA", "%s CA %.0f PA %.0f" % [p.name(), p.ca(), p.pa])
		for k in Player.ATTR_KEYS:
			var v := float(p.attrs.get(k, 1.0))
			if v < 1.0 or v > 20.0 or is_nan(v):
				_flag("attribute outside 1-20", "%s %s=%.2f" % [p.name(), k, v])
				break
		if p.club_id != "":
			var a: int = p.age(w.today)
			if p.squad == Player.Squad.YOUTH and a >= 20:
				_flag("youth player aged 20+", "%s %d" % [p.name(), a])
			if p.squad in [Player.Squad.FIRST, Player.Squad.RESERVE] and a < 16:
				_flag("professional under 16", "%s %d (%s)" % [p.name(), a, p.club_id])
			if int(p.contract.get("end_day", 0)) < w.today and not p.is_on_loan():
				expiry_past += 1
			if int(p.contract.get("wage_weekly", 0)) <= 0:
				_flag("zero wage", "%s" % p.name())
			if p.is_on_loan():
				if p.loan.owner_id == p.club_id:
					_flag("loan to own club", p.name())
				if p.loan.return_day < w.today:
					_flag("expired loan not returned", "%s returns %s" % [p.name(), WDate.to_iso(p.loan.return_day)])
		var st: Dictionary = p.season_stats.get(str(season), {})
		if p.position != "S" and int(st.get("catches", 0)) > 0:
			infos.append("catch by a player fielded out of position: %s (%s) %d" % [p.name(), p.position, st["catches"]])
		if p.position != "K" and int(st.get("saves", 0)) > 0:
			infos.append("saves by a player fielded out of position: %s (%s) %d" % [p.name(), p.position, st["saves"]])
		if p.position != "C" and int(st.get("goals", 0)) > 0:
			out_of_pos += 1
		if int(st.get("apps", 0)) > 0 and int(st.get("minutes", 0)) <= 0:
			_flag("appearances without minutes", p.name())
		if p.injury_days > 0 and p.injury_kind == "":
			_flag("injury without a kind", p.name())
		if p.injury_days > 400:
			_flag("injury longer than 400 days", "%s %d" % [p.name(), p.injury_days])
		if p.morale < 0.0 or p.morale > 100.0 or p.condition < 0.0 or p.condition > 100.0:
			_flag("morale/condition outside 0-100", p.name())
	if expiry_past > 0:
		_flag("contract expired but still at the club", "%d players" % expiry_past)
	infos.append("players with goals out of position: %d" % out_of_pos)
	for nt_id in w.national_team_ids_sorted():
		var nt: Dictionary = w.national_teams[nt_id]
		var l: Dictionary = nt.get("lineup", {})
		if l.is_empty():
			continue
		var ids: Array = [l.get("K", "")] + l.get("C", []) + l.get("B", []) + [l.get("S", "")]
		for pid in ids:
			var p: Player = w.player(str(pid))
			if p != null and p.nationality != str(nt["country_id"]):
				_flag("foreigner in a national team", "%s (%s) in %s" % [p.name(), p.nationality, nt_id])


func _audit_season_end(w: World, loader: SimLoader, engine: GameEngine, season: int, ca_start: Dictionary) -> void:
	for h in w.history:
		if int(h["season"]) != season:
			continue
		var table: Array = h.get("table", [])
		if table.is_empty():
			continue
		var canon := Schools.canon_cup_champion(loader.events, str(h["competition_id"])) if bool(w.settings.get("book_events", true)) else ""
		if str(table[0]["club_id"]) != str(h["champion_id"]) and str(h["champion_id"]) != canon:
			_flag("champion differs from top of the table", str(h["competition_id"]))
		for i in table.size():
			var c: Club = w.club(str(table[i]["club_id"]))
			if c == null:
				continue
			var ss: Dictionary = c.season_summary.get(str(season), {})
			if int(ss.get("pos", -1)) != i + 1:
				_flag("club position doesn't match history", "%s %s pos %s vs %d" % [h["competition_id"], c.id, str(ss.get("pos", "-")), i + 1])
		var n := table.size()
		var rounds := 2 if w.competitions.has(str(h["competition_id"])) and w.competitions[str(h["competition_id"])].type == "league" else 1
		for row in table:
			var pj := int(row.get("w", 0)) + int(row.get("d", 0)) + int(row.get("l", 0))
			if pj != rounds * (n - 1):
				_flag("season with unplayed matches", "%s %s pj %d of %d" % [h["competition_id"], row["club_id"], pj, rounds * (n - 1)])
	for a in w.awards:
		if int(a["season"]) != season:
			continue
		var p: Player = w.player(str(a.get("player_id", "")))
		if p == null:
			continue
		var comp: Competition = w.competitions.get(str(a.get("competition_id", "")))
		if comp == null:
			continue
		var mine := false
		for pa in p.awards:
			if int(pa["season"]) == season and str(pa["kind"]) == str(a["kind"]):
				mine = true
		if not mine:
			_flag("award not recorded on player profile", "%s %s" % [p.name(), a["kind"]])
		if str(a["kind"]) == "top_scorer":
			var key := Player.comp_key(season, comp.id)
			var best := 0
			for cid in comp.club_ids:
				for q in w.club_players(str(cid)):
					best = maxi(best, int(q.comp_stats.get(key, {}).get("goals", 0)))
			var his := int(p.comp_stats.get(key, {}).get("goals", 0))
			if his < best:
				_flag("top scorer with fewer goals than another player", "%s %d vs %d in %s" % [p.name(), his, best, comp.id])
	for comp in w.leagues():
		var max_apps := 2 * (comp.club_ids.size() - 1)
		for cid in comp.club_ids:
			for p in w.club_players(str(cid)):
				var apps := int(p.comp_stats.get(Player.comp_key(season, comp.id), {}).get("apps", 0))
				if apps > max_apps + 4:
					_flag("more appearances than matchdays", "%s %d in %s (%d matchdays)" % [p.name(), apps, comp.id, max_apps])
	var buckets := {"16-21": [], "22-27": [], "28-31": [], "32+": []}
	for p in w.players.values():
		if not ca_start.has(p.id) or p.squad == Player.Squad.SCHOOL or p.club_id == "":
			continue
		var a: int = p.age(w.today)
		var d: float = p.ca() - float(ca_start[p.id])
		if a <= 21:
			buckets["16-21"].append(d)
		elif a <= 27:
			buckets["22-27"].append(d)
		elif a <= 31:
			buckets["28-31"].append(d)
		else:
			buckets["32+"].append(d)
	var txt := []
	for k in ["16-21", "22-27", "28-31", "32+"]:
		var arr: Array = buckets[k]
		var s := 0.0
		for v in arr:
			s += v
		txt.append("%s %+.1f (n=%d)" % [k, s / maxf(arr.size(), 1), arr.size()])
	infos.append("season ΔCA by age: " + ", ".join(txt))
	var young: Array = buckets["16-21"]
	var old: Array = buckets["32+"]
	var ys := 0.0
	for v in young:
		ys += v
	var os := 0.0
	for v in old:
		os += v
	if young.size() > 0 and ys / young.size() <= 0.0:
		_flag("young players don't progress", "mean ΔCA %+.2f" % (ys / young.size()))
	if old.size() > 0 and os / old.size() >= 0.0:
		_flag("veterans don't decline", "mean ΔCA %+.2f" % (os / old.size()))
	var fees := 0
	var count := 0
	for t in w.transfers:
		if str(t.get("from_id", "")) == str(t.get("to_id", "")):
			_flag("transfer to the same club", str(t))
		if int(t.get("fee", 0)) < 0:
			_flag("transfer with negative fee", str(t))
		if int(t.get("fee", 0)) > 0 and not bool(t.get("loan", false)):
			fees += int(t["fee"])
			count += 1
	infos.append("transfers with a fee: %d (avg %d G)" % [count, fees / maxi(count, 1)])
	var over := 0
	for c in w.clubs.values():
		var bill := 0
		for p in w.squad_of(c.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
			bill += int(p.contract.get("wage_weekly", 0))
		if bill > c.wage_budget_weekly * 1.5:
			over += 1
	if over > w.clubs.size() / 4:
		_flag("wage bill far above budget", "%d clubs at 150 %%+" % over)
	infos.append("clubs with wage bill > 150 %% of budget: %d" % over)
	for sid in ["school_hogwarts", "school_ilvermorny"]:
		var by_house := {}
		for p in Schools.students_of(w, sid):
			by_house[p.house] = int(by_house.get(p.house, 0)) + 1
		for h in by_house.keys():
			if by_house[h] < 7:
				_flag("house without a full team", "%s %s: %d" % [sid, h, by_house[h]])
		var found := false
		for h in w.history:
			if int(h["season"]) == season and str(h["competition_id"]).begins_with("comp_school_" + sid.trim_prefix("school_")):
				found = true
		var skipped := false
		for e in loader.events:
			if str(e.get("kind", "")) == "no_school_cup" and int(e.get("season", -1)) == season and str(e.get("school_id", "")) == sid:
				skipped = true
		if not found and not skipped:
			_flag("school cup without a champion", "%s %d" % [sid, season])
	for e in loader.events:
		if str(e.get("kind", "")) == "wc_final":
			var year := int(str(e["date"]).substr(0, 4))
			if year > season:
				continue
			var winner: String = str(e["home"]) if int(e["score_home"]) > int(e["score_away"]) else str(e["away"])
			var ok := false
			var seen := false
			for h in w.history:
				if str(h["competition_id"]) == str(e["competition_id"]):
					seen = true
					ok = str(h["champion_id"]) == winner
			if seen and not ok and bool(w.settings.get("book_events", true)):
				_flag("World Cup champion differs from canon", "%d" % year)


func _audit_results(w: World, season: int) -> void:
	var n := 0
	var snitch := 0
	var snitch_won := 0
	var draws := 0
	var home_w := 0
	var pts := 0
	var dur := 0
	var max_pts := 0
	var max_dur := 0
	var cap := 0
	var big_margin := 0
	for comp in w.competitions.values():
		if comp.type != Competition.Type.LEAGUE:
			continue
		for f in comp.fixtures:
			if not bool(f.get("played", false)):
				continue
			n += 1
			var sh := int(f["score_home"])
			var sa := int(f["score_away"])
			pts += sh + sa
			max_pts = maxi(max_pts, maxi(sh, sa))
			var d := int(f.get("duration_s", 0))
			dur += d
			max_dur = maxi(max_dur, d)
			if sh == sa:
				draws += 1
			elif sh > sa:
				home_w += 1
			if absi(sh - sa) >= 300:
				big_margin += 1
			var st := str(f.get("snitch_team_id", ""))
			if st != "":
				snitch += 1
				var cs := sh if st == str(f["home_id"]) else sa
				var os := sa if st == str(f["home_id"]) else sh
				if cs > os:
					snitch_won += 1
			else:
				cap += 1
	if n == 0:
		return
	infos.append("leagues (current season): %d matches | points/match %.0f (max %d) | avg duration %.0f min (max %.0f) | snitch caught %.0f %% | catcher wins %.0f %% | draws %.1f %% | home wins %.0f %% | 300+ blowouts %.1f %% | ended by cap %d" % [
		n, pts / float(n), max_pts, dur / 60.0 / n, max_dur / 60.0, 100.0 * snitch / n, 100.0 * snitch_won / maxi(snitch, 1), 100.0 * draws / n, 100.0 * home_w / n, 100.0 * big_margin / n, cap])
	if 100.0 * snitch_won / maxi(snitch, 1) < 80.0:
		_flag("snitch decides too little", "%.0f %% wins for the catcher (lore: almost always)" % (100.0 * snitch_won / maxi(snitch, 1)))
	if 100.0 * draws / n > 5.0:
		_flag("too many draws", "%.1f %%" % (100.0 * draws / n))
	if home_w / float(n) < 0.45 or home_w / float(n) > 0.65:
		_flag("odd home advantage", "%.0f %%" % (100.0 * home_w / n))
	for comp in w.leagues():
		var champs := {}
		var total := 0
		for h in w.history:
			if str(h["competition_id"]) == comp.id:
				champs[h["champion_id"]] = int(champs.get(h["champion_id"], 0)) + 1
				total += 1
		for cid in champs.keys():
			if total >= 4 and champs[cid] == total:
				_flag("one club won every league title", "%s: %s %d/%d" % [comp.id, cid, champs[cid], total])


func _audit_texts(w: World, loader: SimLoader) -> void:
	for locale in ["es", "en"]:
		TranslationServer.set_locale(locale)
		var missing := {}
		for o in w.inbox:
			for key in [str(o.sender), o.subject.key, o.body.key]:
				if key != "" and TranslationServer.translate(key) == key:
					missing[key] = true
			var body := TranslationServer.translate(o.body.key)
			for ph in _placeholders(body):
				if not o.body.to_dict()["args"].has(ph):
					_flag("message placeholder without data", "%s missing {%s}" % [o.body.key, ph])
		for e in w.news:
			for it in e["items"]:
				var key := str(it["key"])
				if TranslationServer.translate(key) == key and TranslationServer.translate(key + ".v2") == key + ".v2":
					missing[key] = true
				var txt := TranslationServer.translate(key)
				for ph in _placeholders(txt):
					if not it.get("args", {}).has(ph):
						_flag("news placeholder without data", "%s missing {%s}" % [key, ph])
		for k in missing.keys():
			_flag("untranslated key (%s)" % locale, k)
	TranslationServer.set_locale("es")
