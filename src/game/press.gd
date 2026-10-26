class_name Press  # [game]
extends RefCounted

const TONES := ["humble", "confident", "critical", "evasive"]


## Conferences of each kind (pre-match, post-match) the club remembers: a question asked at one of them is not
## asked again until it drops out.
const RECENT_CONFERENCES := 5  # [game]
## ...and only for this many days.
const RECENT_DAYS := 90
## Match weather worth a question (MatchSim kinds).
const BAD_WEATHER := ["rain", "storm", "fog", "snow", "wind"]


## Questions for the match just played: [{key, params, player_id, won}]. Three slots: the result, a player and the
## context (derby, former club or player, cup, table, streak, board, a new manager, weather, next opponent).
static func questions(w: World, r: MatchResult, my_id: String, comp: Competition) -> Array:
	var me := w.my_club()
	if me == null:
		return []
	var mine_home := r.home_id == my_id
	var my_score := r.score_home if mine_home else r.score_away
	var their := r.score_away if mine_home else r.score_home
	var won := my_score > their
	var drawn := my_score == their
	var margin := my_score - their
	var rival_id := r.away_id if mine_home else r.home_id
	var base: Dictionary[String, Say.Arg] = {"rival": Say.team(w, rival_id), "score": Say.plain("%d–%d" % [my_score, their])}
	var res_keys: Array = []
	if won and margin >= 150:
		res_keys = ["big_win", "win"]
	elif not won and -margin >= 150:
		res_keys = ["big_loss", "loss"]
	elif my_score < their and r.snitch_team_id == my_id:
		res_keys = ["caught_lost", "loss"]
	elif drawn:
		res_keys = ["draw"]
	elif not won:
		if -margin <= 40:
			res_keys.append("narrow_loss")
		if mine_home:
			res_keys.append("loss_home")
		res_keys.append("loss")
	else:
		if r.duration_minutes() > 240:
			res_keys.append("long")
		if margin <= 40:
			res_keys.append("narrow_win")
		if not mine_home:
			res_keys.append("win_away")
		res_keys.append("win")
	var res_c: Array = []
	for k in res_keys:
		var rq := _q(str(k), base, {}, won)
		if str(k) == "narrow_loss" and margin == -10:
			rq["qkey"] = "narrow_loss_one"
		res_c.append(rq)
	var best := ""
	var best_r := 0.0
	var top_scorer := ""
	var top_goals := 0
	var injured := ""
	var rival_best_r := 0.0
	for pid in r.player_stats.keys():
		var p: Player = w.player(str(pid))
		if p == null:
			continue
		if p.club_id != my_id:
			rival_best_r = maxf(rival_best_r, Progression.match_rating(r.player_stats[pid], p.position, their > my_score))
			continue
		var st: Dictionary = r.player_stats[pid]
		var rating := Progression.match_rating(st, p.position, won)
		if rating > best_r:
			best_r = rating
			best = str(pid)
		if int(st.get("goals", 0)) > top_goals:
			top_goals = int(st.get("goals", 0))
			top_scorer = str(pid)
		if p.injury_days > 0 and injured == "":
			injured = str(pid)
	var ply_c: Array = []
	if injured != "":
		ply_c.append(_player_q(w, "player_injured", injured, base, top_goals, won))
	var catcher: Player = w.player(r.snitch_player_id)
	if won and r.snitch_team_id == my_id and catcher != null and catcher.club_id == my_id and margin <= 150:
		ply_c.append(_player_q(w, "snitch_catch", catcher.id, base, top_goals, won))
	if top_goals >= 4 and top_scorer != "":
		ply_c.append(_player_q(w, "player_scorer", top_scorer, base, top_goals, won))
	var star_key := "player_star" if best_r >= rival_best_r else "player_best"
	if best != "" and best_r >= 7.5:
		ply_c.append(_player_q(w, star_key, best, base, top_goals, won))
	elif best != "" and not won and best_r < 5.5:
		ply_c.append(_player_q(w, "player_poor", best, base, top_goals, won))
	var ctx_c: Array = []
	if _former_club(w, my_id, rival_id):
		ctx_c.append(_q("former_club", base, {}, won))
	if not drawn and Rivalries.are_rivals(w, my_id, rival_id):
		ctx_c.append(_q("derby_win" if won else "derby_loss", base, {}, won))
	var ex := _former_player(w, my_id, rival_id)
	if ex != null:
		var est: Dictionary = r.player_stats.get(ex.id, {})
		if not est.is_empty() and (int(est.get("goals", 0)) >= 3 or r.snitch_player_id == ex.id or Progression.match_rating(est, ex.position, not won and not drawn) >= 7.5):
			ctx_c.append(_q("former_player", base, {"player": Say.player(ex)}, won))
	var is_cup := comp != null and comp.is_knockout()
	if is_cup and not drawn and not _final_stage(comp, r):
		ctx_c.append(_q("cup_through" if won else "cup_out", base, {"competition": Say.comp(comp.id)}, won))
	var pos := -1
	var rival_pos := -1
	var played := 0
	if comp != null and comp.type == Competition.Type.LEAGUE:
		var table: Array = comp.standings()
		for i in table.size():
			if str(table[i]["club_id"]) == my_id:
				pos = i + 1
				played = int(table[i]["pj"])
			elif str(table[i]["club_id"]) == rival_id:
				rival_pos = i + 1
	var n := comp.club_ids.size() if comp != null else 0
	if pos > 0 and pos <= 3 and rival_pos > 0 and rival_pos <= 3 and played >= 4 and n >= 6:
		ctx_c.append(_q("top_clash", base, {}, won))
	var streak := _streak(w, my_id)
	var conf: float = float(me.board.get("confidence", 60.0))
	if streak >= 4:
		ctx_c.append(_q("streak_win", base, {"n": Say.num(streak)}, won))
	elif streak <= -3:
		ctx_c.append(_q("streak_loss", base, {"n": Say.num(-streak)}, won))
	if conf < 35.0:
		ctx_c.append(_q("board_pressure", base, {}, won))
	if _new_in_charge(w, my_id, 3):
		ctx_c.append(_q("first_weeks", base, {}, won))
	if pos == 1 and n > 0:
		ctx_c.append(_q("table_top", base, {}, won))
	elif pos > 0 and n > 0 and pos >= n - 1:
		ctx_c.append(_q("table_bottom", base, {"pos": Say.num(pos)}, won))
	if BAD_WEATHER.has(r.weather):
		ctx_c.append(_q("weather", base, {"weather": Say.key("weather." + r.weather)}, won))
	if is_cup:
		ctx_c.append(_q("cup_tie", base, {}, won))
	var nf := {}
	for c in w.competitions.values():
		var cf: Dictionary = c.next_fixture_of(my_id, w.today + 1)
		if not cf.is_empty() and (nf.is_empty() or int(cf["day"]) < int(nf["day"])):
			nf = cf
	if not nf.is_empty():
		ctx_c.append(_q("next_rival", base, {"next": Say.team(w, str(nf["away_id"]) if str(nf["home_id"]) == my_id else str(nf["home_id"]))}, won))
	var fill: Array = ctx_c + ply_c
	if best != "" and (won or best_r >= 5.5):
		fill.append(_player_q(w, star_key, best, base, top_goals, won))
	return _pick(w, my_id, false, [res_c, ply_c, ctx_c], fill)


static func _q(key: String, base: Dictionary[String, Say.Arg], extra: Dictionary[String, Say.Arg], won: bool) -> Dictionary:
	return {"key": key, "args": _args(base, extra), "player_id": "", "won": won}


static func _player_q(w: World, key: String, pid: String, base: Dictionary[String, Say.Arg], goals: int, won: bool) -> Dictionary:
	var pp: Player = w.player(pid)
	return {"key": key, "args": _args(base, {"player": Say.player(pp), "goals": Say.num(goals), "days": Say.num(pp.injury_days)}), "player_id": pid, "won": won}


## The stored args of a question: the conference's shared args plus the question's own.
static func _args(base: Dictionary[String, Say.Arg], extra: Dictionary[String, Say.Arg]) -> Dictionary:
	var all: Dictionary[String, Say.Arg] = {}
	all.assign(base)
	all.merge(extra, true)
	return Say.phrase("", all).to_dict()["args"]


## A question's text under `key`: "press.q.<qkey>" for the question, "press.a.<key>.<tone>" for an answer.
static func text(q: Dictionary, key: String) -> String:
	return Say.render(Say.Phrase.from_dict({"key": key, "args": q.get("args", {})}))


static func _pick(w: World, my_id: String, pre: bool, slots: Array, fill: Array) -> Array:
	var ages := recent_ages(w, my_id, pre)
	var out: Array = []
	var used := {}
	var first_slot_used := false
	for si in slots.size():
		for q in slots[si]:
			if not ages.has(str(q["key"])) and not used.has(str(q["key"])):
				out.append(q)
				used[str(q["key"])] = true
				first_slot_used = first_slot_used or si == 0
				break
	for q in fill:
		if out.size() >= 2:
			break
		if not ages.has(str(q["key"])) and not used.has(str(q["key"])):
			out.append(q)
			used[str(q["key"])] = true
	var pool: Array = fill.duplicate()
	if not first_slot_used and not slots.is_empty():
		pool = (slots[0] as Array) + pool
	for si in range(1, slots.size()):
		pool.append_array(slots[si])
	while out.size() < 2:
		var pick: Dictionary = {}
		var pick_age := -1
		for q in pool:
			var k := str(q["key"])
			if used.has(k):
				continue
			var age := int(ages.get(k, 1000))
			if age > pick_age:
				pick_age = age
				pick = q
		if pick.is_empty():
			break
		out.append(pick)
		used[str(pick["key"])] = true
		if not first_slot_used and slots.size() > 0 and (slots[0] as Array).has(pick):
			first_slot_used = true
			for q in slots[0]:
				used[str(q["key"])] = true
	return out


## Question keys asked at the club's last RECENT_CONFERENCES conferences of one kind (pre-match or post-match).
static func recent_keys(w: World, my_id: String, pre: bool) -> Dictionary:
	var out := {}
	for k in recent_ages(w, my_id, pre).keys():
		out[k] = true
	return out


## The same keys with how many conferences ago each was last asked (0 = the last one). Conferences older than
## RECENT_DAYS are forgotten.
static func recent_ages(w: World, my_id: String, pre: bool) -> Dictionary:
	var out := {}
	var rec: Variant = w.manager.get("press_recent", {})
	if not (rec is Dictionary) or str(rec.get("club_id", "")) != my_id:
		return out
	var hist: Array = rec.get("pre" if pre else "post", [])
	for i in range(hist.size() - 1, -1, -1):
		var conf: Dictionary = hist[i]
		if w.today - int(conf["day"]) > RECENT_DAYS:
			continue
		for k in conf["keys"]:
			if not out.has(str(k)):
				out[str(k)] = hist.size() - 1 - i
	return out


## Notes the questions of a conference just put to the manager, for recent_keys: w.manager.press_recent =
## {club_id, pre: [{day, keys}…], post: [{day, keys}…]}, the last RECENT_CONFERENCES of each kind. A new club starts
## afresh.
static func remember(w: World, my_id: String, qs: Array, pre: bool) -> void:
	var rec: Variant = w.manager.get("press_recent", {})
	if not (rec is Dictionary) or str(rec.get("club_id", "")) != my_id:
		rec = {"club_id": my_id, "pre": [], "post": []}
	var kind := "pre" if pre else "post"
	var hist: Array = rec.get(kind, [])
	var keys: Array = []
	for q in qs:
		keys.append(str(q.get("key", "")))
	hist.append({"day": w.today, "keys": keys})
	while hist.size() > RECENT_CONFERENCES:
		hist.pop_front()
	rec[kind] = hist
	w.manager["press_recent"] = rec


static func _former_club(w: World, my_id: String, club_id: String) -> bool:
	if club_id == my_id:
		return false
	for e in w.manager.get("career", []):
		if e is Dictionary and str(e.get("club_id", "")) == club_id and e.has("to"):
			return true
	return false


static func _former_player(w: World, my_id: String, rival_id: String) -> Player:
	var best: Player = null
	for t in w.transfers:
		if str(t.get("from_id", "")) != my_id or bool(t.get("loan", false)) or World.is_release(t):
			continue
		var p: Player = w.player(str(t.get("player_id", "")))
		if p == null or p.loan_owner_id() == my_id:
			continue
		if p.club_id == rival_id and p.squad == Player.Squad.FIRST and (best == null or p.ca() > best.ca()):
			best = p
	return best


static func _new_in_charge(w: World, my_id: String, n: int) -> bool:
	var career: Array = w.manager.get("career", [])
	for i in range(career.size() - 1, -1, -1):
		var e: Variant = career[i]
		if e is Dictionary and str(e.get("club_id", "")) == my_id and not e.has("to"):
			var since := int(e.get("from_day", WDate.from_ymd(int(e.get("from", w.season)), 7, 1)))
			# A spell begun before June of this season is not new after the rollover, however few its matches.
			return since >= WDate.from_ymd(w.season, 6, 1) and int(e.get("official_matches", 0)) < n
	return false


static func _final_stage(comp: Competition, r: MatchResult) -> bool:
	var stage := ""
	var day := -1
	for f in comp.fixtures:
		var h := str(f["home_id"])
		var a := str(f["away_id"])
		if bool(f.get("played", false)) and int(f["day"]) >= day and ((h == r.home_id and a == r.away_id) or (h == r.away_id and a == r.home_id)):
			day = int(f["day"])
			stage = str(f.get("stage", ""))
	return stage == "final" or stage == "third"


static func _streak(w: World, my_id: String) -> int:
	var since := WDate.from_ymd(w.season, 7, 1)
	var results: Array = []
	for c in w.competitions.values():
		if c.type == Competition.Type.FRIENDLY:
			continue
		for f in c.fixtures:
			if bool(f.get("played", false)) and int(f["day"]) >= since and (f["home_id"] == my_id or f["away_id"] == my_id):
				var mine: int = int(f["score_home"]) if f["home_id"] == my_id else int(f["score_away"])
				var theirs: int = int(f["score_away"]) if f["home_id"] == my_id else int(f["score_home"])
				results.append([int(f["day"]), signi(mine - theirs)])
	results.sort_custom(func(a, b): return a[0] > b[0])
	var s := 0
	for rr in results:
		if rr[1] == 0:
			break
		if s == 0 or signi(s) == rr[1]:
			s += rr[1]
		else:
			break
	return s


## Applies an answer: returns the effect text key.
static func apply(w: World, q: Dictionary, tone: String) -> String:
	var me := w.my_club()
	if me == null:
		return ""
	var won := bool(q.get("won", false))
	var about_player := str(q.get("player_id", "")) != ""
	var morale := 0.0
	var conf := 0.0
	var rep := 0
	var player_morale := 0.0
	match tone:
		"humble":
			morale = 2.0
			conf = 0.5
			player_morale = 5.0
		"confident":
			morale = 4.0 if won else -2.0
			conf = 1.0 if won else -1.5
			rep = 5 if won else -6
			player_morale = 7.0
		"critical":
			morale = -4.0
			conf = 1.5
			rep = 2
			player_morale = -9.0
		"evasive":
			morale = 0.0
			conf = -0.5
			rep = -1
			player_morale = 0.0
	if str(q.get("key", "")) == "player_injured" and tone == "critical":
		player_morale = -4.0
	for p in w.squad_of(me.id):
		p.morale = clampf(p.morale + morale, 0.0, 100.0)
	if about_player:
		var pp: Player = w.player(str(q["player_id"]))
		if pp != null:
			pp.morale = clampf(pp.morale + player_morale, 0.0, 100.0)
	me.board["confidence"] = clampf(float(me.board.get("confidence", 60.0)) + conf, 0.0, 100.0)
	Career.add_reputation(w, rep)
	return "press.effect." + tone + ("_player" if about_player and tone != "evasive" else "")


## Pre-match conference: two or three questions the day before an official match, in three slots: the
## occasion, a player and the context. `weather` is the match's (GameEngine._weather_for).
static func pre_questions(w: World, my_id: String, f: Dictionary, comp: Competition, weather: String = "") -> Array:  # [game]
	var me := w.club(my_id)
	var rival_id := str(f["away_id"]) if str(f["home_id"]) == my_id else str(f["home_id"])
	var rival: Club = w.club(rival_id)
	if me == null or rival == null:
		return []
	var base: Dictionary[String, Say.Arg] = {"rival": Say.club(rival), "competition": (Say.comp(comp.id) if comp != null else Say.plain(""))}
	var lg := w.league_of(my_id)
	var pos := -1
	var rival_pos := -1
	var played := 0
	var n := 0
	if lg != null:
		var table: Array = lg.standings()
		for i in table.size():
			if str(table[i]["club_id"]) == my_id:
				pos = i + 1
				played = int(table[i]["pj"])
			elif str(table[i]["club_id"]) == rival_id:
				rival_pos = i + 1
		n = lg.club_ids.size()
	var occ_c: Array = []
	if Rivalries.are_rivals(w, my_id, rival_id):
		occ_c.append(_pre_q("pre_derby", base, {}, rival_id, ""))
	if comp != null and comp == lg and pos > 0 and pos <= 3 and rival_pos > 0 and rival_pos <= 3 and played >= 4 and n >= 6:
		occ_c.append(_pre_q("pre_top_clash", base, {}, rival_id, ""))
	if comp != null and comp.is_knockout() and lg != null and not lg.is_finished():
		occ_c.append(_pre_q("pre_cup_tie", base, {}, rival_id, ""))
	var k := "pre_even"
	if me.reputation > rival.reputation * 1.12:
		k = "pre_favourite"
	elif rival.reputation > me.reputation * 1.12:
		k = "pre_underdog"
	occ_c.append(_pre_q(k, base, {}, rival_id, ""))
	var ply_c: Array = []
	var my_star: Player = null
	for p in w.squad_of(my_id, [Player.Squad.FIRST]):
		if my_star == null or p.ca() > my_star.ca():
			my_star = p
	if my_star != null and my_star.injury_days > 0:
		ply_c.append(_pre_q("pre_injured_star", base, {"player": Say.player(my_star)}, rival_id, my_star.id))
	var ex := _former_player(w, my_id, rival_id)
	if ex != null:
		ply_c.append(_pre_q("pre_former_player", base, {"player": Say.player(ex)}, rival_id, ex.id))
	var star: Player = null
	for q in w.squad_of(rival_id, [Player.Squad.FIRST]):
		var better := star == null
		if not better:
			var q_c := q.position == "C"
			var star_c := star.position == "C"
			better = (q_c and not star_c) or (q_c == star_c and q.ca() > star.ca())
		if better:
			star = q
	if star != null:
		ply_c.append(_pre_q("pre_rival_star", base, {"player": Say.player(star)}, rival_id, star.id))
	var ctx_c: Array = []
	if _former_club(w, my_id, rival_id):
		ctx_c.append(_pre_q("pre_former_club", base, {}, rival_id, ""))
	var streak := _streak(w, my_id)
	if streak >= 3:
		ctx_c.append(_pre_q("pre_streak_win", base, {"n": Say.num(streak)}, rival_id, ""))
	elif streak <= -3:
		ctx_c.append(_pre_q("pre_streak_loss", base, {"n": Say.num(-streak)}, rival_id, ""))
	var last := _last_result(w, my_id)
	if not last.is_empty() and w.today - int(last["day"]) <= 21 and int(last["theirs"]) - int(last["mine"]) >= 150:
		ctx_c.append(_pre_q("pre_heavy_defeat", base, {"score": Say.plain("%d–%d" % [int(last["mine"]), int(last["theirs"])]), "last": Say.team(w, str(last["rival_id"]))}, rival_id, ""))
	if float(me.board.get("confidence", 60.0)) < 35.0:
		ctx_c.append(_pre_q("pre_board_pressure", base, {}, rival_id, ""))
	if _new_in_charge(w, my_id, 2):
		ctx_c.append(_pre_q("pre_new_manager", base, {}, rival_id, ""))
	if not rival.manager_is_human and rival.manager_name != "" and w.today - int(rival.board.get("manager_since", -9999)) <= 45:
		ctx_c.append(_pre_q("pre_rival_new_manager", base, {"manager": Say.plain(rival.manager_name)}, rival_id, ""))
	var y := WDate.year(w.today)
	if WorldGenerator.is_world_cup_year(y) and WDate.month(w.today) <= 6:
		ctx_c.append(_pre_q("pre_world_cup", base, {"year": Say.num(y)}, rival_id, ""))
	if BAD_WEATHER.has(weather):
		ctx_c.append(_pre_q("pre_weather", base, {"weather": Say.key("weather." + weather)}, rival_id, ""))
	if pos > 0 and n >= 6 and pos >= n - 1 and played >= 3:
		ctx_c.append(_pre_q("pre_table_bottom", base, {"pos": Say.num(pos)}, rival_id, ""))
	return _pick(w, my_id, true, [occ_c, ply_c, ctx_c], ctx_c + ply_c)


static func _pre_q(key: String, base: Dictionary[String, Say.Arg], extra: Dictionary[String, Say.Arg], rival_id: String, player_id: String) -> Dictionary:
	return {"key": key, "args": _args(base, extra), "rival_id": rival_id, "player_id": player_id}


static func _last_result(w: World, my_id: String) -> Dictionary:
	var out := {}
	for c in w.competitions.values():
		if c.type == Competition.Type.FRIENDLY:
			continue
		for f in c.fixtures:
			if not bool(f.get("played", false)) or (str(f["home_id"]) != my_id and str(f["away_id"]) != my_id):
				continue
			if out.is_empty() or int(f["day"]) > int(out["day"]):
				var home := str(f["home_id"]) == my_id
				out = {"day": int(f["day"]), "mine": int(f["score_home"]) if home else int(f["score_away"]),
					"theirs": int(f["score_away"]) if home else int(f["score_home"]), "rival_id": str(f["away_id"]) if home else str(f["home_id"])}
	return out


## Applies a pre-match answer: returns the effect text key. The player a question names takes the answer
## personally: the rival's star (or our former player) only bristles at criticism; our own injured star also
## hears the encouragement ("_own" effect texts). Criticism that names no one is taken by the whole rival side ("_team").
static func apply_pre(w: World, q: Dictionary, tone: String) -> String:
	var me := w.my_club()
	var rival: Club = w.club(str(q.get("rival_id", "")))
	if me == null or rival == null:
		return ""
	var key := str(q.get("key", ""))
	var sp: Player = w.player(str(q.get("player_id", "")))
	var own_player := sp != null and sp.club_id == me.id
	var own := 0.0
	var their := 0.0
	var star_d := 0.0
	var conf := 0.0
	match tone:
		"humble":
			own = 1.0
			star_d = 3.0 if own_player else 0.0
		"confident":
			own = 3.0 if key == "pre_favourite" else 2.0
			their = -2.0 if key == "pre_favourite" else (2.0 if key == "pre_underdog" or key == "pre_derby" else 1.0)
			star_d = 4.0 if own_player else 0.0
			w.settings["pre_stance"] = {"rival_id": rival.id, "day": w.today, "tone": "confident"}
		"critical":
			own = 1.0
			their = 0.0 if own_player else -1.0
			star_d = -4.0
			conf = -0.5
		"evasive":
			pass
	for p in w.squad_of(me.id):
		p.morale = clampf(p.morale + own, 0.0, 100.0)
	for p in w.squad_of(rival.id):
		p.morale = clampf(p.morale + their, 0.0, 100.0)
	if sp != null and star_d != 0.0:
		sp.morale = clampf(sp.morale + star_d, 0.0, 100.0)
	me.board["confidence"] = clampf(float(me.board.get("confidence", 60.0)) + conf, 0.0, 100.0)
	if own_player and tone != "evasive":
		return "press.effect.pre_" + tone + "_own"
	if tone == "critical" and sp == null:
		return "press.effect.pre_critical_team"
	return "press.effect.pre_" + tone


## After the human's match: if the manager talked big before it ("confident") and lost, the boast backfires as it
## does after the match (dressing room, board and reputation). Applied once per stance.
static func pre_match_backfire(w: World, r: MatchResult, my_id: String) -> void:
	var st: Dictionary = w.settings.get("pre_stance", {})
	if st.is_empty():
		return
	var rival_id := r.away_id if r.home_id == my_id else r.home_id
	if w.today - int(st.get("day", 0)) > 3:
		w.settings.erase("pre_stance")
		return
	if str(st.get("rival_id", "")) != rival_id:
		return
	w.settings.erase("pre_stance")
	var my_score := r.score_home if r.home_id == my_id else r.score_away
	var their := r.score_away if r.home_id == my_id else r.score_home
	var me := w.club(my_id)
	if me == null or my_score >= their:
		return
	for p in w.squad_of(me.id):
		p.morale = clampf(p.morale - 3.0, 0.0, 100.0)
	me.board["confidence"] = clampf(float(me.board.get("confidence", 60.0)) - 1.0, 0.0, 100.0)
	Career.add_reputation(w, -4)


## Days between two talks (praise or demand) with the same player.
const TALK_GAP := 7  # [game]


## One-to-one talk: praise, demand or promise of a starting place. Praise and demand once a week per player (the
## last one is kept in p.happiness["last_talk_day"]); a promise has its own limit (one at a time).
static func talk(w: World, p: Player, kind: String) -> String:
	var prof := (p.hid("professionalism") - 10.0) / 10.0
	var temp := (p.hid("temperament") - 10.0) / 10.0
	if kind == "praise" or kind == "demand":
		if p.happiness.has("last_talk_day") and w.today - int(p.happiness["last_talk_day"]) < TALK_GAP:
			return "talk.player.too_soon"
		p.happiness["last_talk_day"] = w.today
	match kind:
		"praise":
			if p.morale >= 85.0:
				p.morale = clampf(p.morale - 1.0, 0.0, 100.0)
				return "talk.player.praise_empty"
			p.morale = clampf(p.morale + 7.0, 0.0, 100.0)
			return "talk.player.praise_ok"
		"demand":
			if prof > 0.2:
				p.morale = clampf(p.morale + 4.0, 0.0, 100.0)
				return "talk.player.demand_ok"
			p.morale = clampf(p.morale - (6.0 + 4.0 * maxf(temp, 0.0)), 0.0, 100.0)
			return "talk.player.demand_bad"
		"promise":
			if not p.promise.is_empty():
				return "talk.player.promise_exists"
			p.promise = {"kind": "starter", "made": w.today, "until": w.today + 60, "season": w.season, "apps_at": int(p.season_stats.get(str(w.season), {}).get("apps", 0))}
			p.morale = clampf(p.morale + 5.0, 0.0, 100.0)
			return "talk.player.promise_ok"
	return ""


## Checks expired promises (weekly, human club): three matches in 60 days or the player gets angry. Appearances
## are counted across the 1 July rollover. If the club itself hasn't played three official matches since the promise
## (the summer break), the verdict waits, up to 150 days.
static func check_promises(w: World) -> void:
	var me := w.my_club()
	if me == null:
		return
	for p in w.squad_of(me.id):
		if p.promise.is_empty() or w.today < int(p.promise.get("until", 0)):
			continue
		var made := int(p.promise.get("made", w.today))
		var played := _apps_since_promise(w, p)
		var kept := played >= 3
		if not kept and w.today < made + 150 and _club_official_played_since(w, me.id, made) < 3:
			continue
		p.promise = {}
		if kept:
			p.morale = clampf(p.morale + 8.0, 0.0, 100.0)
			Inbox.tell(w, &"from.player", "msg.promise_kept.subject", "msg.promise_kept.body", {"player": Say.player(p)})
		else:
			p.morale = clampf(p.morale - 14.0, 0.0, 100.0)
			Inbox.tell(w, &"from.player", "msg.promise_broken.subject", "msg.promise_broken.body", {"player": Say.player(p)})
			if p.hid("ambition") >= 14.0 and p.squad != Player.Squad.SCHOOL and not w.is_school_mode():
				p.transfer_listed = true
				p.loan_listed = false
				p.happiness["asked_out"] = 1.0
				p.happiness["listed"] = 0.0


static func _apps_since_promise(w: World, p: Player) -> int:
	var total := -int(p.promise["apps_at"])
	for s in range(int(p.promise["season"]), w.season + 1):
		total += int(p.season_stats.get(str(s), {}).get("apps", 0))
	return total


static func _club_official_played_since(w: World, club_id: String, day: int) -> int:
	var n := 0
	for c in w.competitions.values():
		if c.type == Competition.Type.FRIENDLY:
			continue
		for f in c.fixtures:
			if bool(f.get("played", false)) and int(f["day"]) >= day and (str(f["home_id"]) == club_id or str(f["away_id"]) == club_id):
				n += 1
	return n
