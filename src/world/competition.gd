class_name Competition
extends RefCounted
## Persistent competition: a league, World Cup groups, or a knockout with replays for draws.

const ROUND_NAMES := {16: "r16", 8: "qf", 4: "sf", 2: "final"}

class Type:
	const LEAGUE := "league"
	const CUP := "cup"
	const FRIENDLY := "friendly"
	const WC_GROUPS := "wc_groups"
	const WC_KNOCKOUT := "wc_knockout"
	const CONT_GROUPS := "cont_groups"
	const CONT_KNOCKOUT := "cont_knockout"
	const NATIONAL_CUP := "national_cup"
	const SCHOOL_CUP := "school_cup"
	const HOUSE_WORLD := "house_world"
	const ALL := [LEAGUE, CUP, FRIENDLY, WC_GROUPS, WC_KNOCKOUT, CONT_GROUPS, CONT_KNOCKOUT, NATIONAL_CUP, SCHOOL_CUP, HOUSE_WORLD]
	const KNOCKOUT := [CUP, WC_KNOCKOUT, NATIONAL_CUP, CONT_KNOCKOUT, HOUSE_WORLD]
	const GROUP_STAGES := [WC_GROUPS, CONT_GROUPS]
	## Friendlies and school games: no press conference and no rivalry.
	const CASUAL := [FRIENDLY, SCHOOL_CUP, HOUSE_WORLD]

var id: String = ""
var name: String = ""
var type: String = Type.LEAGUE
var region_id: String = "british_isles"
var level: int = 1
var format: Dictionary = {"rounds": 2, "table": "points_scored", "tiebreak": ["points_conceded_asc", "snitch_catches_desc"], "time_cap_minutes": null}
var club_ids: Array = []
var country_ids: Array = []
var venues: Array = []
var season: int = 1993
var fixtures: Array = []
var prizes: Dictionary = {}
var source: String = "canon_qtta"
var groups: Dictionary = {}
var bracket_done: bool = false
var champion_id: String = ""
var third_id: String = ""
var parent_id: String = ""
var filler_clubs: int = 0
var name_en: String = ""


## The series this season's edition belongs to (the World Cup, a continental cup): the id without its stage
## ("_groups", "_final") and season ("_1994") suffixes. From the id alone, since History keeps the ids of editions
## that no longer exist.
static func series_of(comp_id: String) -> String:
	var base := comp_id.trim_suffix("_final").trim_suffix("_groups")
	var n := base.length()
	if n > 5 and base[n - 5] == "_" and base.substr(n - 4).is_valid_int():
		return base.left(n - 5)
	return base


func series() -> String:
	return series_of(id)


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "name_en": name_en, "type": type, "region_id": region_id, "level": level, "format": format,
		"club_ids": club_ids, "country_ids": country_ids, "venues": venues, "season": season, "fixtures": fixtures, "prizes": prizes,
		"source": source, "groups": groups, "bracket_done": bracket_done, "champion_id": champion_id, "third_id": third_id,
		"parent_id": parent_id, "filler_clubs": filler_clubs}


static func from_dict(d: Dictionary) -> Competition:
	var c := Competition.new()
	c.id = str(d["id"])
	c.name = str(d.get("name", c.id))
	c.name_en = str(d.get("name_en", c.name))
	c.type = str(d.get("type", Type.LEAGUE))
	assert(Type.ALL.has(c.type), "unknown competition type: " + c.type)
	c.region_id = str(d.get("region_id", "british_isles"))
	c.level = int(d.get("level", 1))
	c.format = d.get("format", c.format)
	c.club_ids = d.get("club_ids", [])
	c.country_ids = d.get("country_ids", [])
	c.venues = d.get("venues", [])
	c.season = int(d.get("season", 1993))
	c.fixtures = d.get("fixtures", [])
	c.prizes = d.get("prizes", {})
	c.source = str(d.get("source", "canon_qtta"))
	c.groups = d.get("groups", {})
	c.bracket_done = bool(d.get("bracket_done", false))
	c.champion_id = str(d.get("champion_id", ""))
	c.third_id = str(d.get("third_id", ""))
	c.parent_id = str(d.get("parent_id", ""))
	c.filler_clubs = int(d.get("filler_clubs", 0))
	return c


## Builds a competition from its pack JSON. Deep-copies `d_in`, so it never aliases loader data.
static func from_pack(d_in: Dictionary) -> Competition:
	var d: Dictionary = d_in.duplicate(true)
	var c := from_dict(d)
	var v: Array = []
	for item in d.get("venues", []):
		v.append(str(item.get("name", item)) if item is Dictionary else str(item))
	c.venues = v
	return c


static var _dyn_re: RegEx


func display_name() -> String:
	var fallback := name if (TranslationServer.get_locale().begins_with("es") or name_en == "") else name_en
	if _dyn_re == null:
		_dyn_re = RegEx.create_from_string("^comp_(european_cup|world_cup|nt_friendlies|friendlies|school|national_cup|cont|house_world)_(.*?)_?(\\d{4})(_groups|_final)?$")
	var m := _dyn_re.search(id)
	if m == null:
		return Loc.name("comp." + id, fallback)
	var kind := m.get_string(1)
	var key := "comp.european_cup"
	match kind:
		"nt_friendlies":
			var y := m.get_string(3).to_int()
			return Loc.name("comp.nt_friendlies", fallback).replace("{season}", "%d-%02d" % [y, (y + 1) % 100])
		"world_cup":
			key = "comp.world_cup" + m.get_string(4)
		"friendlies":
			key = "comp.friendlies"
		"school":
			key = "comp.school_cup"
		"house_world":
			key = "comp.house_world"
		"cont":
			var cup := Loc.name("comp.cont." + m.get_string(2), fallback).replace("{year}", m.get_string(3))
			return Loc.name("comp.stage" + m.get_string(4).replace("_", "."), "{cup}").replace("{cup}", cup)
		"national_cup":
			var lid := "comp_" + m.get_string(2)
			return Loc.name("comp.national_cup", fallback).replace("{league}", Loc.name("comp." + lid, lid))
	return Loc.name(key, fallback).replace("{year}", m.get_string(3)).replace("{school}", m.get_string(2).capitalize())


func is_league() -> bool:
	return type == Type.LEAGUE


func is_knockout() -> bool:
	return type in Type.KNOCKOUT


func time_cap() -> Variant:
	return format.get("time_cap_minutes", null)


## Standings. League: cumulative points scored. World Cup groups: 2 per win plus 1/3/5 for a margin of 50/100/150.
func standings(team_ids: Array = []) -> Array:
	var ids: Array = team_ids if not team_ids.is_empty() else club_ids
	var rows := {}
	for cid in ids:
		rows[cid] = {"club_id": cid, "pj": 0, "w": 0, "d": 0, "l": 0, "pts": 0, "scored": 0, "against": 0, "catches": 0, "catch_minutes": 0, "form": []}
	var wins_bonus: bool = str(format.get("table", "points_scored")) == "wins_bonus"
	for f in fixtures:
		if not bool(f.get("played", false)) or bool(f.get("replayed", false)):
			continue
		var h: String = str(f["home_id"])
		var a: String = str(f["away_id"])
		if not rows.has(h) or not rows.has(a):
			continue
		var sh: int = int(f["score_home"])
		var sa: int = int(f["score_away"])
		for pair in [[h, sh, sa], [a, sa, sh]]:
			var r: Dictionary = rows[pair[0]]
			r["pj"] += 1
			r["scored"] += pair[1]
			r["against"] += pair[2]
			var res := "d"
			var margin: int = pair[1] - pair[2]
			if margin > 0:
				r["w"] += 1
				res = "w"
			elif margin < 0:
				r["l"] += 1
				res = "l"
			else:
				r["d"] += 1
			if wins_bonus:
				if margin > 0:
					r["pts"] += 2 + (5 if margin > 150 else (3 if margin > 100 else (1 if margin > 50 else 0)))
				elif margin == 0:
					r["pts"] += 1   # [FILLER]
			else:
				r["pts"] += pair[1]
			r["form"].append(res)
			if r["form"].size() > 5:
				r["form"].pop_front()
		var snitch := str(f.get("snitch_team_id", ""))
		if snitch != "" and rows.has(snitch):
			rows[snitch]["catches"] += 1
			rows[snitch]["catch_minutes"] += int(f.get("duration_s", 0)) / 60
	var out: Array = rows.values()
	if wins_bonus:
		out.sort_custom(func(x, y):
			if x["pts"] != y["pts"]:
				return x["pts"] > y["pts"]
			if x["catches"] != y["catches"]:
				return x["catches"] > y["catches"]
			if x["catch_minutes"] != y["catch_minutes"]:
				return x["catch_minutes"] < y["catch_minutes"]
			return str(x["club_id"]) < str(y["club_id"]))
	else:
		out.sort_custom(func(x, y):
			if x["pts"] != y["pts"]:
				return x["pts"] > y["pts"]
			if x["against"] != y["against"]:
				return x["against"] < y["against"]
			if x["catches"] != y["catches"]:
				return x["catches"] > y["catches"]
			return str(x["club_id"]) < str(y["club_id"]))
	return out


func group_standings(letter: String) -> Array:
	return standings(groups.get(letter, []))


func position_of(club_id: String) -> int:
	var st := standings()
	for i in st.size():
		if st[i]["club_id"] == club_id:
			return i + 1
	return -1


func fixtures_on(day: int) -> Array:
	var out := []
	for f in fixtures:
		if int(f["day"]) == day and not bool(f.get("played", false)):
			out.append(f)
	return out


func next_fixture_of(team_id: String, from_day: int) -> Dictionary:
	for f in fixtures:
		if int(f["day"]) >= from_day and not bool(f.get("played", false)) and (f["home_id"] == team_id or f["away_id"] == team_id):
			return f
	return {}


func is_finished() -> bool:
	if is_knockout():
		return bracket_done
	for f in fixtures:
		if not bool(f.get("played", false)):
			return false
	return true


func has_team(team_id: String) -> bool:
	return club_ids.has(team_id)


func _new_fixture(round_n: int, day: int, home: String, away: String, rng: SimRng, extra: Dictionary = {}) -> Dictionary:
	var f := {
		"id": "%s_%d_%d_%s_%s" % [id, season, round_n, home, away], "round": round_n, "day": day,
		"home_id": home, "away_id": away,
		"venue": str(rng.pick(venues)) if not venues.is_empty() else "",
		"hour": str(rng.pick(["11:00", "14:00", "16:00", "19:00", "00:00"])), "played": false,
	}
	# [game]
	if home.begins_with("club_") and str(extra.get("stage", "")) != "final" and type != "cup":
		f["venue"] = "ground:" + home
	for k in extra.keys():
		f[k] = extra[k]
	return f


## League calendar: double round-robin, one matchday every ~11-12 days from September to June [FILLER].
## `stagger` shifts the weekdays so the leagues do not all play on the same day.
func build_fixtures(rng: SimRng, season_year: int, stagger: int = 0) -> void:
	season = season_year
	fixtures.clear()
	bracket_done = false
	champion_id = ""
	var ids: Array = club_ids.duplicate()
	var n := ids.size()
	if n < 2:
		return
	var order_rng := SimRng.new(hash("%s:%d" % [id, season_year]))
	for i in range(n - 1, 0, -1):
		var j := order_rng.irange(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	if n % 2 == 1:
		ids.append("")
	var m := ids.size()
	var legs: int = int(format.get("rounds", 2))
	var rounds_per_leg := m - 1
	var total_rounds := rounds_per_leg * legs
	var start_day := WDate.from_ymd(season_year, 9, 4) + stagger
	var end_day := WDate.from_ymd(season_year + 1, 6, 12)
	var span := end_day - start_day
	var weekdays := [Time.WEEKDAY_SATURDAY, Time.WEEKDAY_MONDAY, Time.WEEKDAY_FRIDAY, Time.WEEKDAY_SATURDAY, Time.WEEKDAY_SATURDAY, Time.WEEKDAY_MONDAY]
	var blocked := WorldGenerator.national_window(season_year)
	var rot: Array = ids.duplicate()
	var prev_day := -1000000
	for r in total_rounds:
		var leg := r / rounds_per_leg
		var target := start_day + int(float(span) * r / maxf(total_rounds - 1, 1))
		var wd: int = weekdays[(r + stagger) % weekdays.size()]
		while WDate.weekday(target) != wd:
			target += 1
		while blocked.has(target) or target <= prev_day or not [Time.WEEKDAY_MONDAY, Time.WEEKDAY_FRIDAY, Time.WEEKDAY_SATURDAY].has(WDate.weekday(target)):
			target += 1
		prev_day = target
		for i in m / 2:
			var a: String = str(rot[i])
			var b: String = str(rot[m - 1 - i])
			if a == "" or b == "":
				continue
			var home := a if _circle_home_first(r, leg, i) else b
			var away := b if home == a else a
			fixtures.append(_new_fixture(r + 1, target, home, away, rng))
		var last = rot.pop_back()
		rot.insert(1, last)
	fixtures.sort_custom(func(x, y): return int(x["day"]) < int(y["day"]) if x["day"] != y["day"] else str(x["id"]) < str(y["id"]))


## Circle-method venue: the pivot pair (i == 0) swaps home every round, every other pair swaps once per leg, offset
## by its place in the ring, so home and away games alternate for each team.
static func _circle_home_first(r: int, leg: int, i: int) -> bool:
	if i == 0:
		return r % 2 == 0
	return (leg + i) % 2 == 0


## Double round-robin groups of 4 spread over `dates` [FILLER: group size].
func build_group_fixtures(rng: SimRng, dates: Array) -> void:
	fixtures.clear()
	var letters := groups.keys()
	letters.sort()
	for letter in letters:
		var ids: Array = groups[letter]
		if ids.size() < 2:
			continue
		var pairs := []
		var rot: Array = ids.duplicate()
		while rot.size() < 4:
			rot.append("")
		var m := rot.size()
		for r in (m - 1) * 2:
			var leg := r / (m - 1)
			var day_pairs := []
			for i in m / 2:
				var a: String = str(rot[i])
				var b: String = str(rot[m - 1 - i])
				if a == "" or b == "":
					continue
				var home := a if _circle_home_first(r, leg, i) else b
				var away := b if home == a else a
				day_pairs.append([home, away])
			pairs.append(day_pairs)
			var last = rot.pop_back()
			rot.insert(1, last)
		for r in pairs.size():
			var day: int = int(dates[r % dates.size()]) if r < dates.size() else int(dates[-1]) + 7 * (r - dates.size() + 1)
			for pr in pairs[r]:
				fixtures.append(_new_fixture(r + 1, day, pr[0], pr[1], rng, {"group": letter}))
	fixtures.sort_custom(func(x, y): return int(x["day"]) < int(y["day"]) if x["day"] != y["day"] else str(x["id"]) < str(y["id"]))


## Group winners sorted by points, then by more catches, then by faster catches.
func group_winners() -> Array:
	var winners := []
	var letters := groups.keys()
	letters.sort()
	for letter in letters:
		var st := group_standings(letter)
		if not st.is_empty():
			winners.append(st[0])
	winners.sort_custom(func(x, y):
		if x["pts"] != y["pts"]:
			return x["pts"] > y["pts"]
		if x["catches"] != y["catches"]:
			return x["catches"] > y["catches"]
		if x["catch_minutes"] != y["catch_minutes"]:
			return x["catch_minutes"] < y["catch_minutes"]
		return str(x["club_id"]) < str(y["club_id"]))
	var ids := []
	for w in winners:
		ids.append(w["club_id"])
	return ids


## Single-match bracket of 16, 8, 4 or 2. `seeded_ids` pairs 1st vs last. `round_days`: [R16, QF, SF, final];
## the third-place match is played five days before the final.
func build_bracket(rng: SimRng, season_year: int, seeded_ids: Array, round_days: Array, with_third_place: bool) -> void:
	season = season_year
	fixtures.clear()
	bracket_done = false
	champion_id = ""
	third_id = ""
	club_ids = seeded_ids.duplicate()
	format["round_days"] = round_days
	format["third_place"] = with_third_place
	var n := seeded_ids.size()
	var p := 2
	while p < n:
		p *= 2
	var byes := {}
	var round_n := 1
	for i in p / 2:
		var j := p - 1 - i
		if j >= n:
			byes[str(i)] = str(seeded_ids[i])
			continue
		fixtures.append(_new_fixture(round_n, int(round_days[0]), str(seeded_ids[i]), str(seeded_ids[j]), rng, {"stage": ROUND_NAMES.get(p, "r%d" % p), "slot": i}))
	format["byes"] = byes


## Call after every played match of this knockout. Generates replays and the next round.
func advance_bracket(rng: SimRng, today: int) -> Dictionary:
	var info := {"new_round": false, "replay": false, "finished": false}
	if bracket_done:
		_advance_third_place(rng)
		return info
	var current_round := 0
	for f in fixtures:
		current_round = maxi(current_round, int(f["round"]))
	var round_fx := []
	for f in fixtures:
		if int(f["round"]) == current_round:
			round_fx.append(f)
	for f in round_fx:
		if bool(f.get("played", false)) and not bool(f.get("replayed", false)) and int(f["score_home"]) == int(f["score_away"]) and not bool(f.get("has_replay", false)):
			fixtures.append(_replay_fixture(f, rng))
			info["replay"] = true
			return info
	var winners := {}
	for f in fixtures:
		if int(f["round"]) != current_round or bool(f.get("replayed", false)):
			continue
		if str(f.get("stage", "")) == "third":
			if bool(f.get("played", false)) and int(f["score_home"]) != int(f["score_away"]):
				third_id = str(f["home_id"]) if int(f["score_home"]) > int(f["score_away"]) else str(f["away_id"])
			continue
		if not bool(f.get("played", false)):
			return info
		if int(f["score_home"]) == int(f["score_away"]):
			return info
		var wnr: String = str(f["home_id"]) if int(f["score_home"]) > int(f["score_away"]) else str(f["away_id"])
		var lsr: String = str(f["away_id"]) if wnr == f["home_id"] else str(f["home_id"])
		winners[int(f.get("slot", 0))] = {"w": wnr, "l": lsr, "stage": str(f.get("stage", ""))}
	if winners.is_empty():
		return info
	if current_round == 1:
		var stage1: String = str(winners.values()[0]["stage"])
		var byes: Dictionary = format.get("byes", {})
		for s in byes.keys():
			winners[int(s)] = {"w": str(byes[s]), "l": "", "stage": stage1}
	var stage: String = str(winners.values()[0]["stage"])
	if stage == "final":
		champion_id = str(winners[0]["w"])
		bracket_done = true
		info["finished"] = true
		return info
	var slots := winners.keys()
	slots.sort()
	var n := slots.size()
	var next_n := n
	var round_days: Array = format.get("round_days", [])
	var day_idx := mini(current_round, round_days.size() - 1)
	var next_day: int = int(round_days[day_idx]) if not round_days.is_empty() else today + 14
	if next_day <= today:
		next_day = today + 7
	var next_round := current_round + 1
	var next_stage: String = ROUND_NAMES.get(next_n, "r%d" % next_n)
	for i in n / 2:
		var a: String = str(winners[slots[i]]["w"])
		var b: String = str(winners[slots[n - 1 - i]]["w"])
		fixtures.append(_new_fixture(next_round, next_day, a, b, rng, {"stage": next_stage, "slot": i}))
	if next_stage == "final" and bool(format.get("third_place", false)):
		var la: String = str(winners[slots[0]]["l"])
		var lb: String = str(winners[slots[1]]["l"])
		fixtures.append(_new_fixture(next_round, maxi(next_day - 5, today + 1), la, lb, rng, {"stage": "third", "slot": 99}))
	info["new_round"] = true
	return info


## The replay of a drawn tie `f`: the same tie with the venue swapped `replay_offset` days later. Its id appends
## _r<n>, n counting the replays of the tie, so a replayed replay never reuses an id.
func _replay_fixture(f: Dictionary, rng: SimRng) -> Dictionary:
	f["has_replay"] = true
	f["replayed"] = true
	var n := int(f.get("replay_n", 0)) + 1
	var rep := _new_fixture(int(f["round"]), int(f["day"]) + int(format.get("replay_offset", 3)), str(f["away_id"]), str(f["home_id"]), rng,
		{"stage": f.get("stage", ""), "slot": f.get("slot", 0), "is_replay": true, "replay_n": n})
	rep["id"] = "%s_r%d" % [rep["id"], n]
	return rep


func _advance_third_place(rng: SimRng) -> void:
	if third_id != "":
		return
	for f in fixtures:
		if str(f.get("stage", "")) != "third" or not bool(f.get("played", false)) or bool(f.get("replayed", false)):
			continue
		if int(f["score_home"]) != int(f["score_away"]):
			third_id = str(f["home_id"]) if int(f["score_home"]) > int(f["score_away"]) else str(f["away_id"])
		elif not bool(f.get("has_replay", false)):
			fixtures.append(_replay_fixture(f, rng))
		return
