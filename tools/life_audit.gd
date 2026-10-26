extends SceneTree
## Audit of the world's "life" outside matches: transfers, loans, regens (new youth players), retirements,
## contracts and wages, long-term progression, press conferences, news, inbox, awards, manager career
## and reputations. Simulates N seasons with a human club that plays everything, answers owls at random and holds
## the press conference after every match. At the end it checks the texts used (news, owls, press) in all 10 languages.
## godot --headless --path . -s tools/life_audit.gd -- --seasons 50 [--seed 1] [--human club_id]

const GameSessionScript := preload("res://src/game/game_session.gd")
const LOCALES := ["es", "en", "de", "fr", "it", "pt_BR", "nl", "ru", "ja", "zh_CN"]

var rng := RandomNumberGenerator.new()
var issues: Dictionary = {}
var text_samples: Dictionary = {}
var snap: Dictionary = {}
var press_keys: Dictionary = {}
var press_counts: Dictionary = {}
var tones_effect: Dictionary = {}
var season_lines: Array = []
var totals: Dictionary = {}
var w: World
var engine: GameEngine
var session: GameSessionScript


func _flag(cat: String, detail: String) -> void:
	if not issues.has(cat):
		issues[cat] = []
	if issues[cat].size() < 12:
		issues[cat].append(detail)
	totals["flag:" + cat] = int(totals.get("flag:" + cat, 0)) + 1


func _sample(key: String, params: Dictionary) -> void:
	if key != "" and not text_samples.has(key):
		text_samples[key] = params.duplicate()


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var seasons := 50
	var seed_value := 1
	var human := "club_puddlemere_united"
	for i in raw.size():
		if raw[i] == "--seasons" and i + 1 < raw.size():
			seasons = int(raw[i + 1])
		if raw[i] == "--seed" and i + 1 < raw.size():
			seed_value = int(raw[i + 1])
		if raw[i] == "--human" and i + 1 < raw.size():
			human = raw[i + 1]
	rng.seed = seed_value
	TranslationServer.set_locale("es")
	var loader := SimLoader.new()
	loader.load_all("1993-94")
	w = WorldGenerator.new(loader).generate(seed_value)
	w.player_club_id = human
	w.my_club().manager_is_human = true
	w.manager = {"name": "Auditor", "nationality": "eng", "reputation": Career.start_reputation(w.my_club()), "career": []}
	engine = GameEngine.new(loader, w)
	session = GameSessionScript.new()
	session.loader = loader
	session.world = w
	var t0 := Time.get_ticks_msec()
	var rep0 := _rep_snapshot()
	_take_snap()
	for s in seasons:
		_season(s)
	print("\n=== %d seasons in %.0f s (initial human club %s, seed %d) ===" % [seasons, (Time.get_ticks_msec() - t0) / 1000.0, human, seed_value])
	_reputation_drift(rep0)
	_check_texts()
	_report()
	session.free()
	quit()


func _season(_s: int) -> void:
	var season := w.season
	var start_ids := {}
	for pid in w.players.keys():
		start_ids[pid] = true
	var st := {"transfers": 0, "loans": 0, "free_signings": 0, "fees": [], "cross_league": 0, "cross_region": 0,
		"human_in": 0, "human_out": 0, "press_matches": 0, "news_items": 0, "news_editions": 0, "msgs": 0,
		"job_offers": 0, "jobs_taken": 0, "multi_moves": 0, "manager_changes": 0}
	var moves_by_player := {}
	var top_fee := {"fee": 0}
	var msg_kinds := {}
	var news_kinds := {}
	var managers := {}
	for c in w.clubs.values():
		managers[c.id] = c.manager_name
	var last_transfer: Variant = w.transfers[0] if not w.transfers.is_empty() else null
	var last_news: Variant = w.news[0] if not w.news.is_empty() else null
	var seen_msgs := {}
	for o in w.inbox:
		seen_msgs[o.id] = true
	var days := 0
	var mid_checked := false
	while w.season == season and days < 420:
		var r := engine.advance_day()
		days += 1
		if r["reason"] == "match":
			_play_human_match(st)
		var fresh: Array = []
		for t in w.transfers:
			if last_transfer != null and is_same(t, last_transfer):
				break
			fresh.append(t)
		if not w.transfers.is_empty():
			last_transfer = w.transfers[0]
		for t in fresh:
			if not World.is_release(t):
				_on_transfer(t, st, moves_by_player, top_fee)
		var eds: Array = []
		for ed in w.news:
			if last_news != null and is_same(ed, last_news):
				break
			eds.append(ed)
		if not w.news.is_empty():
			last_news = w.news[0]
		for ed in eds:
			_on_edition(ed, st, news_kinds)
		for o in w.inbox:
			if seen_msgs.has(o.id):
				continue
			seen_msgs[o.id] = true
			st["msgs"] += 1
			var sk := o.subject.key
			msg_kinds[sk] = int(msg_kinds.get(sk, 0)) + 1
			_sample(sk, o.subject.to_dict()["args"])
			_sample(o.body.key, o.subject.to_dict()["args"])
			_sample(str(o.sender), {})
			var od: Inbox.Decision = w.decisions.get(o.id)
			if od != null and (od.kind == Inbox.JOB or od.kind == Inbox.NT_JOB):
				st["job_offers"] += 1
		if Inbox.open_count(w) > 0:
			_answer_messages(st)
		if days % 7 == 0:
			_take_snap()
		if not mid_checked and WDate.month(w.today) == 1:
			mid_checked = true
			_mid_season_checks()
	for c in w.clubs.values():
		if managers.has(c.id) and managers[c.id] != c.manager_name:
			st["manager_changes"] += 1
	for pid in moves_by_player.keys():
		if int(moves_by_player[pid]) > 2:
			st["multi_moves"] += 1
			var p: Player = w.player(pid)
			_flag("player transferred 3+ times in a season", "%d: %s (%d moves)" % [season, p.name() if p else pid, moves_by_player[pid]])
	_season_end_checks(season, start_ids, st, top_fee, msg_kinds, news_kinds)
	_take_snap()


func _play_human_match(st: Dictionary) -> void:
	var r: MatchResult = engine.complete_pending_match()
	_press(r)
	st["press_matches"] += 1
	while engine.pending_match != null:
		var r2: MatchResult = engine.complete_pending_match()
		_press(r2)
		st["press_matches"] += 1


func _press(r: MatchResult) -> void:
	if r == null or engine.last_match == null:
		return
	var comp: Competition = w.competitions.get(engine.last_match.comp_id)
	if comp == null or comp.type == Competition.Type.FRIENDLY:
		return
	var my_id: String = r.home_id if engine._is_human(r.home_id) else r.away_id
	if my_id.begins_with("nt_"):
		return
	var qs := Press.questions(w, r, my_id, comp)
	press_counts[qs.size()] = int(press_counts.get(qs.size(), 0)) + 1
	if qs.size() < 2:
		_flag("press conference with fewer than 2 questions", "%s: %d question(s) after %s" % [WDate.to_iso(w.today), qs.size(), comp.id])
	var morale0 := _squad_morale(w.player_club_id)
	for q in qs:
		var key := str(q["key"])
		press_keys[key] = int(press_keys.get(key, 0)) + 1
		_sample("press.q." + key, q["args"])
		for tone in Press.TONES:
			_sample("press.a.%s.%s" % [key, tone], q["args"])
		var tone: String = Press.TONES[rng.randi_range(0, 3)]
		var eff := Press.apply(w, q, tone)
		_sample(eff, q["args"])
		if str(q.get("player_id", "")) != "" and w.player(str(q["player_id"])) == null:
			_flag("press question about nonexistent player", key)
	var dm := _squad_morale(w.player_club_id) - morale0
	if absf(dm) > 15.0:
		_flag("press moves morale too much", "%s: %.1f points in one conference" % [WDate.to_iso(w.today), dm])


func _squad_morale(cid: String) -> float:
	var sq := w.squad_of(cid)
	var t := 0.0
	for p in sq:
		t += p.morale
	return t / maxf(sq.size(), 1)


func _on_transfer(t: Dictionary, st: Dictionary, moves: Dictionary, top_fee: Dictionary) -> void:
	var pid := str(t["player_id"])
	moves[pid] = int(moves.get(pid, 0)) + 1
	var p: Player = w.player(pid)
	var from_id := str(t.get("from_id", ""))
	var to_id := str(t.get("to_id", ""))
	var fee := int(t.get("fee", 0))
	if bool(t.get("loan", false)):
		st["loans"] += 1
	elif from_id == "":
		st["free_signings"] += 1
		if fee > 0:
			_flag("free signing with a paid fee", "%s → %s for %d" % [p.name() if p else pid, to_id, fee])
	else:
		st["transfers"] += 1
		st["fees"].append(fee)
		if fee > int(top_fee["fee"]):
			top_fee.merge({"fee": fee, "player": p.name() if p else pid, "ca": p.ca() if p else 0.0, "age": p.age(w.today) if p else 0, "from": w.team_name(from_id), "to": w.team_name(to_id)}, true)
	var fc: Club = w.club(from_id)
	var tc: Club = w.club(to_id)
	if fc != null and tc != null:
		if fc.league_id != tc.league_id:
			st["cross_league"] += 1
		if fc.region_id != tc.region_id:
			st["cross_region"] += 1
	if to_id == w.player_club_id:
		st["human_in"] += 1
	if from_id == w.player_club_id:
		st["human_out"] += 1
	if tc != null and tc.is_women_only() and p != null and p.gender != SimPlayer.Gender.F:
		_flag("man signed by women-only club", "%s → %s" % [p.name(), tc.name])
	if tc != null and tc.balance < -30000 and not tc.manager_is_human:
		_flag("AI club buys while in debt", "%s left at %d G after signing %s" % [tc.name, tc.balance, p.name() if p else pid])
	if p != null and p.age(w.today) >= 37:
		_flag("signing of a 37+ player", "%s (%d) → %s" % [p.name(), p.age(w.today), w.team_name(to_id)])


func _on_edition(ed: Dictionary, st: Dictionary, kinds: Dictionary) -> void:
	st["news_editions"] += 1
	var texts := {}
	for it in ed.get("items", []):
		st["news_items"] += 1
		var key := str(it.get("key", ""))
		kinds[key] = int(kinds.get(key, 0)) + 1
		_sample(key, it.get("args", {}))
		var txt := Say.render(Say.Phrase.from_dict(it))
		if texts.has(txt):
			_flag("repeated news item in the same edition", "%s: %s" % [WDate.to_iso(int(ed["day"])), txt.left(80)])
		texts[txt] = true
	if ed.get("items", []).size() > 24:
		_flag("overloaded Daily Prophet edition", "%s: %d items" % [WDate.to_iso(int(ed["day"])), ed["items"].size()])


func _answer_messages(st: Dictionary) -> void:
	for d in w.decisions.values():
		if not w.decisions.has(d.owl_id):
			continue
		var c: Inbox.Choice = d.choices[rng.randi_range(0, d.choices.size() - 1)]
		var odds := 0.35 if c.verb == GameEngine.ACCEPT_JOB else (0.5 if c.verb == GameEngine.ACCEPT_NT_JOB else 1.0)
		if rng.randf() < odds:
			Inbox.choose(w, engine, d.owl_id, d.choices.find(c), true)
			if odds < 1.0:
				st["jobs_taken"] += 1
		Inbox.close(w, d)


func _take_snap() -> void:
	snap.clear()
	for p in w.players.values():
		snap[p.id] = {"club_id": p.club_id, "squad": p.squad, "age": p.age(w.today), "ca": p.ca(), "name": p.name()}


func _mid_season_checks() -> void:
	for c in w.clubs.values():
		var l: Dictionary = c.lineup
		if l.is_empty():
			continue
		var ids: Array = [l.get("K", "")] + l.get("C", []) + l.get("B", []) + [l.get("S", "")]
		var seen := {}
		for pid in ids:
			var q: Player = w.player(str(pid))
			if q == null or q.club_id != c.id:
				_flag("lineup with foreign or nonexistent player", "%s: %s" % [c.name, str(pid)])
			if seen.has(pid):
				_flag("player repeated in the lineup", "%s: %s" % [c.name, str(pid)])
			seen[pid] = true
	for p in w.players.values():
		if p.club_id != "" and p.squad not in [Player.Squad.SCHOOL, Player.Squad.ABROAD]:
			if int(p.contract.get("wage_weekly", 0)) <= 0:
				_flag("zero or negative wage", "%s (%s)" % [p.name(), w.team_name(p.club_id)])
			if int(p.contract.get("end_day", 0)) == 0:
				_flag("contract without end date", "%s (%s)" % [p.name(), w.team_name(p.club_id)])
		if p.is_on_loan() and p.loan.return_day < w.today - 30:
			_flag("expired loan still active", "%s at %s" % [p.name(), w.team_name(p.club_id)])
		if p.club_id == "" and p.squad not in [Player.Squad.FREE, Player.Squad.ABROAD, Player.Squad.SCHOOL]:
			_flag("no club but in a squad", "%s squad=%s" % [p.name(), p.squad])
		if p.injury_days < 0 or p.morale < 0.0 or p.morale > 100.0 or p.condition < 0.0 or p.condition > 100.0:
			_flag("state out of range", "%s inj %d morale %.0f cond %.0f" % [p.name(), p.injury_days, p.morale, p.condition])
	for t in w.transfers:
		if int(t.get("fee", 0)) < 0:
			_flag("transfer with negative fee", str(t))
	for p in w.players.values():
		if p.club_id != "" and p.squad not in [Player.Squad.SCHOOL, Player.Squad.ABROAD] and int(p.contract.get("end_day", 0)) < w.today:
			_flag("contract expired but still at the club", "%s (%s) expired %s" % [p.name(), w.team_name(p.club_id), WDate.to_iso(int(p.contract.get("end_day", 0)))])
		if p.is_on_loan() and p.loan.owner_id == p.club_id:
			_flag("loaned to own club", p.name())
	for c in w.clubs.values():
		var caps := 0
		for q in w.squad_of(c.id):
			if q.is_captain:
				caps += 1
		if caps != 1:
			_flag("clubs with no captain or several", "%s: %d captains" % [c.name, caps])
		if c.is_women_only():
			for q in w.club_players(c.id):
				if q.gender != SimPlayer.Gender.F:
					_flag("man in women-only club", "%s at %s" % [q.name(), c.name])


func _season_end_checks(season: int, start_ids: Dictionary, st: Dictionary, top_fee: Dictionary, msg_kinds: Dictionary, news_kinds: Dictionary) -> void:
	var regen := {"youth": 0, "first": 0, "reserve": 0, "abroad": 0, "school": 0, "free": 0}
	var regen_pa: Array = []
	var regen_ca: Array = []
	var foreign_youth := 0
	var youth_total := 0
	for p in w.players.values():
		if start_ids.has(p.id):
			continue
		regen[p.squad] = int(regen.get(p.squad, 0)) + 1
		if p.squad == Player.Squad.YOUTH:
			youth_total += 1
			regen_pa.append(p.pa)
			regen_ca.append(p.ca())
			var c: Club = w.club(p.club_id)
			if c != null and p.nationality != c.country_id:
				foreign_youth += 1
			if c != null and c.is_women_only() and p.gender != SimPlayer.Gender.F:
				_flag("male youth player in women-only club", "%s at %s" % [p.name(), c.name])
	regen_pa.sort()
	regen_ca.sort()
	var retired_ages: Array = []
	var retired_stars := []
	var left_free := 0
	var young_retired := []
	for pid in start_ids.keys():
		if w.players.has(pid) or not snap.has(pid):
			continue
		var s: Dictionary = snap[pid]
		if str(s["squad"]) == "school" or str(s["squad"]) == "abroad":
			continue
		if str(s["club_id"]) == "":
			left_free += 1
			continue
		retired_ages.append(int(s["age"]))
		if float(s["ca"]) >= 140.0:
			retired_stars.append("%s age %d CA %.0f" % [s["name"], s["age"], s["ca"]])
		if int(s["age"]) < 30:
			young_retired.append("%s age %d" % [s["name"], s["age"]])
	for y in young_retired:
		_flag("retirement before 30", "%d: %s" % [season, y])
	var ret_avg := 0.0
	for a in retired_ages:
		ret_avg += a
	ret_avg /= maxf(retired_ages.size(), 1)
	var cas: Array = []
	var wages: Array = []
	var by_age := {"<21": [], "21-25": [], "26-30": [], "31+": []}
	var free_agents := 0
	var elite := 0
	var foreign := 0
	var pro := 0
	var names := {}
	for p in w.players.values():
		if p.squad in [Player.Squad.SCHOOL, Player.Squad.ABROAD]:
			continue
		if p.club_id == "":
			free_agents += 1
			continue
		pro += 1
		var ca: float = p.ca()
		cas.append(ca)
		wages.append(int(p.contract.get("wage_weekly", 0)))
		if ca >= 150.0:
			elite += 1
		var a: int = p.age(w.today)
		var b := "<21" if a < 21 else ("21-25" if a <= 25 else ("26-30" if a <= 30 else "31+"))
		by_age[b].append(ca)
		var c: Club = w.club(p.club_id)
		if c != null and p.nationality != c.country_id:
			foreign += 1
		var full: String = p.name()
		names[full] = int(names.get(full, 0)) + 1
	cas.sort()
	wages.sort()
	var dup := 0
	for n in names.keys():
		if int(names[n]) > 1:
			dup += int(names[n]) - 1
	var age_txt := []
	for b in ["<21", "21-25", "26-30", "31+"]:
		var arr: Array = by_age[b]
		var tot := 0.0
		for v in arr:
			tot += v
		age_txt.append("%s %.0f" % [b, tot / maxf(arr.size(), 1)])
	var fees: Array = st["fees"]
	fees.sort()
	var fee_sum := 0
	for f in fees:
		fee_sum += int(f)
	var awards := 0
	for a in w.awards:
		if int(a["season"]) == season:
			awards += 1
	var me := w.my_club()
	var who := (me.name if me != null else "no club")
	var line := "%d-%02d | transfers %3d (free %3d, loans %3d) total %7d med %5d max %6d (%s, age %d, CA %.0f) | cross-league %3d, cross-region %3d | regens: youth %d (PA med %.0f, max %.0f, foreign %d), filler %d, NT pool %d, students %d | retired %d (avg age %.1f, stars %d), free agents leaving %d | free agents now %d | CA med %.0f p90 %.0f max %.0f elite %d | age→CA %s | wage med %d max %d | foreigners %.0f%% | duplicate names %d | press %d matches | Prophet %d editions / %d items | owls %d | job offers %d, accepted %d, AI manager changes %d | awards %d | manager: %s rep %d" % [
		season, (season + 1) % 100, st["transfers"], st["free_signings"], st["loans"], fee_sum, fees[fees.size() / 2] if not fees.is_empty() else 0, int(top_fee["fee"]),
		str(top_fee.get("player", "-")), int(top_fee.get("age", 0)), float(top_fee.get("ca", 0.0)), st["cross_league"], st["cross_region"],
		youth_total, regen_pa[regen_pa.size() / 2] if not regen_pa.is_empty() else 0.0, regen_pa[-1] if not regen_pa.is_empty() else 0.0, foreign_youth,
		int(regen["first"]) + int(regen["reserve"]), regen["abroad"], regen["school"], retired_ages.size(), ret_avg, retired_stars.size(), left_free, free_agents,
		cas[cas.size() / 2], cas[cas.size() * 9 / 10], cas[-1], elite, ", ".join(age_txt), wages[wages.size() / 2], wages[-1], 100.0 * foreign / maxf(pro, 1), dup,
		st["press_matches"], st["news_editions"], st["news_items"], st["msgs"], st["job_offers"], st["jobs_taken"], st["manager_changes"], awards, who, int(w.manager.get("reputation", 0))]
	print(line)
	season_lines.append(line)
	if not retired_stars.is_empty():
		print("      retired stars: ", ", ".join(retired_stars.slice(0, 6)))
	for k in ["transfers", "loans", "free_signings", "press_matches", "news_items", "msgs", "job_offers", "jobs_taken", "manager_changes"]:
		totals[k] = int(totals.get(k, 0)) + int(st[k])
	totals["seasons"] = int(totals.get("seasons", 0)) + 1
	totals["retired"] = int(totals.get("retired", 0)) + retired_ages.size()
	totals["retired_age_sum"] = float(totals.get("retired_age_sum", 0.0)) + ret_avg * retired_ages.size()
	totals["youth"] = int(totals.get("youth", 0)) + youth_total
	for k in msg_kinds.keys():
		totals["msg:" + k] = int(totals.get("msg:" + k, 0)) + int(msg_kinds[k])
	for k in news_kinds.keys():
		totals["news:" + k] = int(totals.get("news:" + k, 0)) + int(news_kinds[k])
	totals["series:ca_med"] = totals.get("series:ca_med", []) + [cas[cas.size() / 2]]
	totals["series:ca_max"] = totals.get("series:ca_max", []) + [cas[-1]]
	totals["series:elite"] = totals.get("series:elite", []) + [elite]
	totals["series:wage_med"] = totals.get("series:wage_med", []) + [wages[wages.size() / 2]]
	totals["series:fee_max"] = totals.get("series:fee_max", []) + [int(top_fee["fee"])]
	totals["series:foreign"] = totals.get("series:foreign", []) + [100.0 * foreign / maxf(pro, 1)]
	totals["series:free"] = totals.get("series:free", []) + [free_agents]
	totals["series:transfers"] = totals.get("series:transfers", []) + [st["transfers"]]
	totals["series:dup"] = totals.get("series:dup", []) + [dup]
	if st["transfers"] == 0:
		_flag("season without transfers", str(season))
	var champs := {}
	for h in w.history:
		if int(h["season"]) != season:
			continue
		var k := str(h["competition_id"])
		if champs.has(k):
			_flag("competition with two champions", "%d: %s" % [season, k])
		champs[k] = true
		if str(h.get("champion_id", "")) == "":
			_flag("competition finished without a champion", "%d: %s" % [season, k])
	var aw := {}
	for a in w.awards:
		if int(a["season"]) != season:
			continue
		var k2 := "%s|%s" % [str(a.get("competition_id", "")), str(a.get("kind", ""))]
		if aw.has(k2) and not str(a.get("kind", "")).begins_with("team"):
			_flag("duplicate award", "%d: %s" % [season, k2])
		aw[k2] = true
	for c in w.clubs.values():
		if c.balance < -50000 or c.balance > 2000000:
			_flag("extreme cash balance", "%d: %s %d G" % [season, c.name, c.balance])
	if st["news_editions"] < 30:
		_flag("too few Daily Prophet editions", "%d: %d" % [season, st["news_editions"]])
	if fees.size() > 10:
		pass


func _rep_snapshot() -> Dictionary:
	var d := {}
	for c in w.clubs.values():
		d[c.id] = c.reputation
	return d


func _reputation_drift(rep0: Dictionary) -> void:
	var diffs: Array = []
	for cid in rep0.keys():
		var c: Club = w.club(cid)
		if c != null:
			diffs.append([c.reputation - int(rep0[cid]), c.name, int(rep0[cid]), c.reputation])
	diffs.sort_custom(func(a, b): return a[0] > b[0])
	print("\n-- Club reputation (start → end) --")
	print("   biggest risers: ", ", ".join(diffs.slice(0, 5).map(func(x): return "%s %d→%d" % [x[1], x[2], x[3]])))
	print("   biggest fallers: ", ", ".join(diffs.slice(diffs.size() - 5).map(func(x): return "%s %d→%d" % [x[1], x[2], x[3]])))
	var unchanged := 0
	for x in diffs:
		if x[0] == 0:
			unchanged += 1
	if unchanged > diffs.size() / 2:
		_flag("frozen reputations", "%d of %d clubs with the same reputation after the whole simulation" % [unchanged, diffs.size()])


func _check_texts() -> void:
	var keys := text_samples.keys()
	keys.sort()
	var missing := {}
	var leftovers := {}
	for loc in LOCALES:
		TranslationServer.set_locale(loc)
		for key in keys:
			var variants := [key]
			var n := 2
			while TranslationServer.translate("%s.v%d" % [key, n]) != "%s.v%d" % [key, n]:
				variants.append("%s.v%d" % [key, n])
				n += 1
			for k in variants:
				var txt := Say.render(Say.Phrase.from_dict({"key": k, "args": text_samples[key]}))
				if txt == k:
					missing[k] = missing.get(k, []) + [loc]
				elif txt.find("{") >= 0 and txt.find("}") > txt.find("{"):
					leftovers[k] = leftovers.get(k, []) + [loc]
			for pv in _key_values(text_samples[key].values()):
				if TranslationServer.translate(pv) == pv and not missing.get(pv, []).has(loc):
					missing[pv] = missing.get(pv, []) + [loc]
	TranslationServer.set_locale("es")
	for k in missing.keys():
		_flag("untranslated text", "%s (%s)" % [k, ",".join(missing[k])])
	for k in leftovers.keys():
		_flag("unreplaced {…} placeholder", "%s (%s): %s" % [k, ",".join(leftovers[k]), Say.render(Say.Phrase.from_dict({"key": k, "args": text_samples.get(k, text_samples.get(k.get_slice(".v", 0), {}))})).left(90)])
	print("\n-- Texts checked: %d keys × %d languages --" % [keys.size(), LOCALES.size()])


## The translation keys inside stored args (Say.key values, at any depth).
func _key_values(packed: Array) -> Array:
	var out: Array = []
	for v in packed:
		if v is Array and not v.is_empty():
			match str(v[0]):
				"k":
					out.append(str(v[1]))
				"l":
					out.append_array(_key_values(v[1]))
				"t":
					out.append_array(_key_values(v[2].values()))
	return out


func _series(name: String) -> String:
	var arr: Array = totals.get("series:" + name, [])
	if arr.is_empty():
		return "-"
	var step := maxi(1, arr.size() / 10)
	var out := []
	for i in range(0, arr.size(), step):
		out.append(str(snappedf(float(arr[i]), 0.1)))
	out.append(str(snappedf(float(arr[-1]), 0.1)))
	return " → ".join(out)


func _report() -> void:
	var n := maxi(int(totals.get("seasons", 1)), 1)
	print("\n-- Per-season averages --")
	print("   transfers %.0f, free %.0f, loans %.0f, new youth %.0f, retirements %.0f (avg age %.1f)" % [
		totals.get("transfers", 0) / float(n), totals.get("free_signings", 0) / float(n), totals.get("loans", 0) / float(n),
		totals.get("youth", 0) / float(n), totals.get("retired", 0) / float(n), float(totals.get("retired_age_sum", 0.0)) / maxf(totals.get("retired", 1), 1)])
	print("   press conferences %.0f, Daily Prophet items %.0f, owls %.0f, job offers %.1f, AI manager changes %.1f" % [
		totals.get("press_matches", 0) / float(n), totals.get("news_items", 0) / float(n), totals.get("msgs", 0) / float(n), totals.get("job_offers", 0) / float(n), totals.get("manager_changes", 0) / float(n)])
	print("\n-- Trends (every ~10%% of the simulation) --")
	for s in [["median CA", "ca_med"], ["max CA", "ca_max"], ["elite players (CA 150+)", "elite"], ["median wage", "wage_med"], ["record transfer of the year", "fee_max"], ["% foreigners", "foreign"], ["unattached free agents", "free"], ["transfers", "transfers"], ["duplicate names", "dup"]]:
		print("   %s: %s" % [s[0], _series(s[1])])
	print("\n-- Press --")
	print("   questions per conference: ", press_counts)
	var pk := press_keys.keys()
	pk.sort_custom(func(a, b): return press_keys[a] > press_keys[b])
	print("   questions: ", ", ".join(pk.map(func(k): return "%s %d" % [k, press_keys[k]])))
	print("\n-- Most frequent owls (total) --")
	var mk: Array = []
	var nk: Array = []
	for k in totals.keys():
		if str(k).begins_with("msg:"):
			mk.append(k)
		elif str(k).begins_with("news:"):
			nk.append(k)
	mk.sort_custom(func(a, b): return totals[a] > totals[b])
	nk.sort_custom(func(a, b): return totals[a] > totals[b])
	print("   ", ", ".join(mk.slice(0, 25).map(func(k): return "%s %d" % [str(k).substr(4), totals[k]])))
	print("\n-- Daily Prophet items by type (total) --")
	print("   ", ", ".join(nk.slice(0, 25).map(func(k): return "%s %d" % [str(k).substr(5), totals[k]])))
	print("\n-- Findings (%d categories) --" % issues.size())
	for cat in issues.keys():
		print("  ! %s: %d" % [cat, totals.get("flag:" + cat, 0)])
		for d in issues[cat]:
			print("      - ", d)
