class_name WorldGenerator
extends RefCounted
## Creates a new world from a data pack: canon clubs, canon players and generated filler.

const RESERVE_PLAN := {"K": 1, "C": 2, "B": 1, "S": 1}
const YOUTH_PER_CLUB := 2
const WORLD_SEED := 19930801
const MOOR_VENUES := ["venue.bodmin", "venue.exmoor", "venue.ilkley_moor", "venue.yorkshire_moors", "venue.ellis_moor"]
const YOUTH_MEAN_PA := [0.0, 118.0, 105.0, 92.0]  # [game]

var loader: SimLoader


func _init(loader_in: SimLoader) -> void:
	loader = loader_in


const PALETTE := ["#7F0909", "#1A472A", "#0E1A40", "#ECB939", "#1B2A4A", "#4B1F6F", "#009B4D", "#F07F13", "#8FB3D9", "#7A0A0A", "#4A4F55", "#1F4D2B", "#F2C200", "#8E1F1C", "#2E4A6B", "#6E4E1E", "#C8102E", "#1B1B1B", "#F4F4F0", "#D4A017", "#946B2D", "#2F5A2A"]

const WC_GROUP_DATES := [[10, 16], [3, 12], [5, 21]]   # [FILLER]
const FIRST_WORLD_CUP := 1994


static func is_world_cup_year(y: int) -> bool:
	return y >= FIRST_WORLD_CUP and (y - FIRST_WORLD_CUP) % 4 == 0


func generate(seed_value: int, start_day: int = -1) -> World:
	var w := World.new()
	w.pack = loader.pack
	w.seed_value = seed_value
	w.today = start_day if start_day >= 0 else WDate.from_ymd(1993, 8, 1)
	w.season = WDate.season_of(w.today)
	_build_leagues(w)

	var contracts := SimRng.derived(WORLD_SEED, "contracts")
	for cid in loader.club_ids():
		for d in loader.players_by_club.get(cid, []):
			w.add_player(_player_from_pack(d, w.today, contracts))

	for club in w.clubs_sorted():
		_fill_squad(w, club, SimRng.derived(WORLD_SEED, "squad:" + club.id))
		_assign_board_objective(club)
		_assign_default_lineup(w, club)
		var club_rng := SimRng.derived(WORLD_SEED, "club:" + club.id)
		_assign_sponsor(club, club_rng)
		if club.manager_name == "":
			club.manager_name = _manager_name(club, club_rng)
		club.knowledge = {club.region_id: 100.0}

	for club in w.clubs_sorted():
		if club.league_id != "":
			club.board["objective"] = initial_objective(w, club)
			club.board["objective_min_pos"] = Economy.objective_pos(w, club)

	_build_national_teams(w, SimRng.derived(WORLD_SEED, "national_teams"))

	_build_world_cup_groups(w, SimRng.derived(WORLD_SEED, "world_cup"), FIRST_WORLD_CUP, true)
	Schools.setup(w, loader, SimRng.derived(WORLD_SEED, "schools"))
	for c in w.clubs_sorted():
		if c.staff.is_empty():
			c.staff = default_staff(c, loader)
	var listed := {}  # [PM-2014]
	for h in loader.world_cup_history.get("past", []):
		if str(h.get("champion", "")) == "":
			continue
		var champ := "nt_" + str(h["champion"])
		w.history.append({"season": int(h["year"]), "competition_id": "comp_world_cup_%d_final" % int(h["year"]), "champion_id": champ, "runner_up_id": ("nt_" + str(h["runner_up"])) if str(h.get("runner_up", "")) != "" else "", "score": str(h.get("score", "")), "table": [], "name": "Mundial de Quidditch %d" % int(h["year"]), "canon": true})
		listed[champ] = int(listed.get(champ, 0)) + 1
	for champ in listed.keys():
		if w.national_teams.has(champ):
			w.national_teams[champ]["world_cup_titles"] = maxi(int(w.national_teams[champ].get("world_cup_titles", 0)), int(listed[champ]))
	for c in w.clubs_sorted():
		Grounds.ensure(c, loader)
	return w


func _build_leagues(w: World) -> void:
	var rng := SimRng.derived(WORLD_SEED, "leagues")
	for cid in loader.club_ids():
		w.clubs[cid] = Club.from_pack(loader.clubs[cid])

	var comp_ids := loader.competitions_pack.keys()
	comp_ids.sort()
	var stagger := 0
	for comp_id in comp_ids:
		var d: Dictionary = loader.competitions_pack[comp_id]
		if str(d.get("type", Competition.Type.LEAGUE)) != Competition.Type.LEAGUE:
			continue
		var comp := Competition.from_pack(d)
		if comp.venues.is_empty():
			comp.venues = MOOR_VENUES.duplicate()
		var ids: Array = []
		for cid in comp.club_ids:
			if w.clubs.has(cid):
				ids.append(cid)
		for i in comp.filler_clubs:
			var fc := _make_filler_club(w, comp, i + 1, rng)
			w.clubs[fc.id] = fc
			ids.append(fc.id)
		comp.club_ids = ids
		comp.build_fixtures(rng, w.season, stagger)
		stagger += 1
		w.competitions[comp.id] = comp
		for cid in ids:
			w.clubs[cid].league_id = comp.id


## Cheap preview for New Game: only clubs and leagues (no players), identical to the game with that seed.
func preview_clubs(seed_value: int) -> World:
	var w := World.new()
	w.pack = loader.pack
	w.seed_value = seed_value
	w.today = WDate.from_ymd(1993, 8, 1)
	w.season = WDate.season_of(w.today)
	_build_leagues(w)
	return w


func _make_filler_club(w: World, comp: Competition, idx: int, rng: SimRng) -> Club:
	var c := Club.new()
	var countries: Array = comp.country_ids if not comp.country_ids.is_empty() else ["eng"]
	var weights := PackedFloat32Array()
	for i in countries.size():
		weights.append(3.0 if i == 0 else 1.0)
	var ci := rng.pick_weighted(weights)
	var country := str(countries[maxi(ci, 0)])
	var names := loader.names_for(comp.region_id, country)
	var city := str(rng.pick(names["cities"]))
	var noun := str(rng.pick(names["club_nouns"]))
	var tries := 0
	while tries < 20 and _city_used(w, city):
		city = str(rng.pick(names["cities"]))
		tries += 1
	tries = 0
	while tries < 20 and _noun_used(w, comp, noun):
		noun = str(rng.pick(names["club_nouns"]))
		tries += 1
	c.id = "club_%s_%d" % [comp.id.trim_prefix("comp_"), idx]
	c.name = "%s %s" % [city, noun]
	c.short_name = noun
	c.city = city
	c.country_id = country
	c.region_id = comp.region_id
	c.league_id = comp.id
	c.founded = rng.irange(1650, 1950)
	var p1: String = str(rng.pick(PALETTE))
	var p2: String = str(rng.pick(PALETTE))
	while p2 == p1:
		p2 = str(rng.pick(PALETTE))
	c.colors = {"primary": p1, "secondary": p2}
	c.level = clampi(comp.level + (1 if rng.chance(0.5) else 0), 1, 3)
	c.reputation = [0, 7000, 4500, 2500][c.level] + rng.irange(-500, 500)
	c.balance = [0, 12000, 6000, 2500][c.level]
	c.wage_budget_weekly = [0, 400, 250, 150][c.level]
	c.transfer_budget = [0, 3000, 1500, 600][c.level]
	c.facilities = {"training": 4 - c.level + 1, "medical": 4 - c.level, "broom_workshop": maxi(3 - c.level, 1)}
	c.staff = default_staff(c, loader)
	c.identity = {"style_tags": [str(rng.pick(["balanced", "attacking", "defensive", "hard", "showmanship"]))], "motto": "", "rivalries": [], "fan_traits": [], "mascot": ""}
	c.source = "filler"
	c.history = {"league_titles": 0, "european_cups": 0}
	return c


func _noun_used(w: World, comp: Competition, noun: String) -> bool:
	for c in w.clubs.values():
		if c.league_id == comp.id and c.short_name == noun:
			return true
	return false


func _city_used(w: World, city: String) -> bool:
	for c in w.clubs.values():
		if c.city == city:
			return true
	return false


func _build_national_teams(w: World, rng: SimRng) -> void:
	for nt_id in loader.national_teams.keys():
		var d: Dictionary = loader.national_teams[nt_id]
		w.national_teams[nt_id] = {"id": nt_id, "name": loader.country_name(str(d["country_id"])), "country_id": str(d["country_id"]), "tier": str(d.get("tier", "mid")),
			"colors": d.get("colors", {"primary": "#888888", "secondary": "#DDDDDD"}).duplicate(true), "mascot": str(d.get("mascot", "")),
			"world_cup_titles": int(d.get("world_cup_titles", 0)), "qualified_1994": bool(d.get("qualified_1994", false)), "source": str(d.get("source", "filler")), "tactics": {}}
		var seven: Array = []
		for r in d.get("canon_roster_1994", []):
			var p := _national_canon_player(w, r, str(d["country_id"]), rng)
			w.add_player(p)
			seven.append(p.id)
		# [GoF 8]
		if str(d.get("canon_seven_until", "")) != "":
			w.national_teams[nt_id]["canon_seven"] = seven
			w.national_teams[nt_id]["canon_seven_until"] = str(d["canon_seven_until"])
	for cid in loader.countries.keys():
		var nt_id := NationalTeams.nt_id_for_country(cid)
		if not w.national_teams.has(nt_id):
			w.national_teams[nt_id] = {"id": nt_id, "name": loader.country_name(cid), "country_id": cid, "tier": "weak", "colors": {"primary": str(rng.pick(PALETTE)), "secondary": "#F4F4F0"},
				"mascot": "", "world_cup_titles": 0, "qualified_1994": false, "source": "filler", "tactics": {}}
	for nt_id in w.national_team_ids_sorted():
		refill_abroad_pool(w, w.national_teams[nt_id], rng, loader)


func _national_canon_player(w: World, r: Dictionary, country: String, rng: SimRng) -> Player:
	var first := str(r.get("first_name", ""))
	var last := str(r.get("last_name", ""))
	var pos := str(r.get("position", "C"))
	var positions := {"K": 4, "C": 4, "B": 4, "S": 4}
	positions[pos] = 18
	var p := Player.from_dict({
		"id": "player_nt_%s_%s" % [country, (first + "_" + last).to_lower().replace(" ", "_")], "first_name": first, "last_name": last,
		"gender": r.get("gender", SimPlayer.Gender.M), "nationality": country,
		"birth_day": WDate.from_string(str(r.get("birth_date", "1968-06-01"))), "look": r.get("look", {}).duplicate(true),
		"club_id": "", "squad": Player.Squad.ABROAD, "position": pos, "positions": positions,
	})
	var names := loader.names_for(loader.region_of_country(country), country)
	var gen := FillerGenerator.new(names, loader.brooms)
	var sp := gen.make_player(rng, p.position, 1, "nt_" + country, 0, false, false)
	p.attrs = sp.attrs
	# [GoF 8]
	var bonus: float = 4.5 if last == "Krum" else 2.0
	for k in p.attrs.keys():
		p.attrs[k] = clampf(float(p.attrs[k]) + bonus, 1.0, 20.0)
	p.hidden = sp.hidden
	p.pa = clampf(p.ca() + rng.gauss(10.0, 6.0), p.ca(), 196.0)
	p.broom = {"model_id": "broom_firebolt", "condition": 100.0}
	p.source = str(r.get("source", "canon_book"))
	p.contract = {"wage_weekly": 0, "end_day": 0, "role": "abroad"}
	p.snapshot_attrs()
	return p


## Keeps ~10 "abroad" players per national team, replacing retirements. Deterministic with the world rng.
static func refill_abroad_pool(w: World, nt: Dictionary, rng: SimRng, loader_in: SimLoader = null) -> void:
	var country := str(nt["country_id"])
	var count := {"K": 0, "C": 0, "B": 0, "S": 0}
	for p in w.players_of_nationality(country):
		if p.squad == Player.Squad.ABROAD:
			count[p.position] += 1
	var ld: SimLoader = loader_in
	for pos in ["K", "C", "B", "S"]:
		while count[pos] < int(NationalTeams.POOL_PLAN[pos]):
			count[pos] += 1
			var p := _make_abroad_player(w, nt, pos, rng, ld)
			w.add_player(p)


static func _make_abroad_player(w: World, nt: Dictionary, pos: String, rng: SimRng, ld: SimLoader) -> Player:
	var country := str(nt["country_id"])
	var tier := str(nt.get("tier", "weak"))
	var names: Dictionary = ld.names_for(ld.region_of_country(country), country) if ld != null else {"first_names_m": ["Alaric"], "first_names_f": ["Elspeth"], "last_names": ["Fenwick"], "cities": ["X"], "club_nouns": ["X"]}
	var brooms: Dictionary = ld.brooms if ld != null else {}
	var gen := FillerGenerator.new(names, brooms)
	var sp := gen.make_player(rng, pos, 1, "nt_" + country, rng.irange(1000, 9999), false, false)
	var p := Player.new()
	p.id = "abroad_%s_%s_%d_%d" % [country, pos.to_lower(), w.season, rng.irange(100000, 999999)]
	var parts := sp.name.split(" ", false, 1)
	p.first_name = parts[0]
	p.last_name = parts[1] if parts.size() > 1 else ""
	p.gender = sp.gender
	p.nationality = country
	p.club_id = ""
	p.squad = Player.Squad.ABROAD
	p.position = pos
	p.positions = {"K": 4, "C": 4, "B": 4, "S": 4}
	p.positions[pos] = 18
	var age: int = rng.irange(20, 31)
	p.birth_day = WDate.from_ymd(WDate.year(w.today) - age, rng.irange(1, 12), rng.irange(1, 28))
	var rangev: Array = NationalTeams.TIER_CA.get(tier, NationalTeams.TIER_CA["weak"])
	var target: float = rng.gauss((rangev[0] + rangev[1]) / 2.0, (rangev[1] - rangev[0]) / 4.0)
	for k in sp.attrs.keys():
		p.attrs[k] = clampf(float(sp.attrs[k]), 1.0, 20.0)
	for _pass in 3:
		var delta: float = (target - p.ca()) / 10.0
		if absf(delta) < 0.01:
			break
		for k in p.attrs.keys():
			p.attrs[k] = clampf(float(p.attrs[k]) + delta, 1.0, 20.0)
	p.hidden = sp.hidden
	p.pa = clampf(p.ca() + rng.gauss(6.0, 5.0), p.ca(), 195.0)
	p.broom = {"model_id": str(sp.broom.get("model_id", "broom_cleansweep_seven")), "condition": 100.0}
	p.source = "filler"
	p.contract = {"wage_weekly": 0, "end_day": 0, "role": "abroad"}
	p.snapshot_attrs()
	return p


## National-team dates for a season, three per season [FILLER].
static func national_dates(season_year: int) -> Array:
	var out := []
	for md in WC_GROUP_DATES:
		var y: int = season_year if int(md[0]) >= 7 else season_year + 1
		out.append(WDate.from_ymd(y, int(md[0]), int(md[1])))
	return out


## The days of a season when called-up squads are away: from GameEngine.CALL_UP_DAYS before each national date to
## the day after it (Player.duty_days). Club competitions schedule no match on them.
static func national_window(season_year: int) -> Dictionary[int, bool]:
	var out: Dictionary[int, bool] = {}
	for d in national_dates(season_year):
		for day in range(int(d) - GameEngine.CALL_UP_DAYS, int(d) + 2):
			out[day] = true
	return out


func _build_world_cup_groups(w: World, rng: SimRng, wc_year: int, simulate_past: bool) -> void:
	var comp := Competition.new()
	comp.id = "comp_world_cup_%d_groups" % wc_year
	comp.name = "Mundial de Quidditch %d — Fase de grupos" % wc_year
	comp.name_en = "Quidditch World Cup %d — Group stage" % wc_year
	comp.type = Competition.Type.WC_GROUPS
	comp.region_id = "world"
	comp.level = 0
	comp.format = {"rounds": 2, "table": "wins_bonus", "tiebreak": ["snitch_catches_desc", "fastest_catch"], "time_cap_minutes": 240}
	comp.season = wc_year - 2
	comp.venues = ["venue.neutral_moor", "venue.desert", "venue.desert_island", "venue.steppe", "venue.remote_coast"]
	comp.source = "canon_pottermore"
	var ids := w.national_teams.keys()
	ids.sort()
	var strengths := {}
	for nt_id in ids:
		strengths[nt_id] = NationalTeams.strength(w, nt_id) + (40.0 if (wc_year == 1994 and bool(w.national_teams[nt_id].get("qualified_1994", false))) else 0.0)
	ids.sort_custom(func(a, b): return strengths[a] > strengths[b] if strengths[a] != strengths[b] else a < b)
	ids = ids.slice(0, 64)
	var letters := []
	for i in 16:
		letters.append(char(65 + i))
	var groups := {}
	for i in 16:
		groups[letters[i]] = [ids[i]] if i < ids.size() else []
	var rest: Array = ids.slice(16)
	for i in range(rest.size() - 1, 0, -1):
		var j := rng.irange(0, i)
		var tmp = rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	var gi := 0
	for nt_id in rest:
		while groups[letters[gi % 16]].size() >= 4:
			gi += 1
		groups[letters[gi % 16]].append(nt_id)
		gi += 1
	_separate_canon_finalists(w, wc_year, groups, letters)
	comp.groups = groups
	var all_ids := []
	for g in groups.values():
		all_ids += g
	comp.club_ids = all_ids
	var dates := national_dates(wc_year - 2) + national_dates(wc_year - 1)
	comp.build_group_fixtures(rng, dates)
	comp.season = wc_year - 1
	w.competitions[comp.id] = comp
	if simulate_past:
		var sim := MatchSim.new(loader.rules, loader.params)
		sim.min_log_importance = MatchEvent.Importance.KEY
		var rules := loader.rules.duplicate(true)
		rules["time_cap_minutes"] = 240
		var sim_capped := MatchSim.new(rules, loader.params)
		sim_capped.min_log_importance = MatchEvent.Importance.KEY
		for f in comp.fixtures:
			if int(f["day"]) < w.today:
				var home := NationalTeams.sim_team(w, str(f["home_id"]), loader.brooms)
				var away := NationalTeams.sim_team(w, str(f["away_id"]), loader.brooms)
				var r := sim_capped.run(home, away, hash("%d:%s" % [w.seed_value, f["id"]]))
				var canon := canon_wc_winner(w, comp.id, str(f["home_id"]), str(f["away_id"]))
				var tries := 0
				while canon != "" and tries < CANON_RETRIES and not canon_won_outright(r, canon, str(f["home_id"])):
					tries += 1
					home = NationalTeams.sim_team(w, str(f["home_id"]), loader.brooms)
					away = NationalTeams.sim_team(w, str(f["away_id"]), loader.brooms)
					r = sim_capped.run(home, away, hash("%d:%s" % [w.seed_value, f["id"]]) + CANON_RETRY_SEED_STEP * tries)
				f["played"] = true
				f["score_home"] = r.score_home
				f["score_away"] = r.score_away
				f["snitch_team_id"] = r.snitch_team_id
				f["duration_s"] = r.duration_s
				f["end_reason"] = r.end_reason
				for t in [home, away]:
					for sp in t.players:
						var p: Player = w.player(sp.id)
						if p != null:
							p.condition = 100.0


func _separate_canon_finalists(w: World, wc_year: int, groups: Dictionary, letters: Array) -> void:
	if not bool(w.settings.get("book_events", true)):
		return
	var fin: Array = []
	for e in loader.events:
		if str(e.get("kind", "")) == "wc_final" and str(e.get("competition_id", "")) == "comp_world_cup_%d_final" % wc_year:
			fin = [str(e["home"]), str(e["away"])]
	if fin.is_empty():
		return
	for li in letters.size():
		var g: Array = groups[letters[li]]
		if not (g.has(fin[0]) and g.has(fin[1])):
			continue
		var mover: String = fin[1] if g.find(fin[0]) == 0 else fin[0]
		var idx := g.find(mover)
		for step in range(1, letters.size()):
			var other: Array = groups[letters[(li + step) % letters.size()]]
			if idx < other.size() and not other.has(fin[0]) and not other.has(fin[1]):
				g[idx] = other[idx]
				other[idx] = mover
				return
		return


# [GoF 5]
const CANON_1994_WINS := {"nt_eng": "nt_tra", "nt_wal": "nt_uga", "nt_sco": "nt_lux", "nt_per": "nt_irl"}
## A match the books decide is replayed with its seed + k * CANON_RETRY_SEED_STEP (k = 1..CANON_RETRIES) until
## the books' winner wins it outright.
const CANON_RETRIES := 30
const CANON_RETRY_SEED_STEP := 7919


static func canon_won_outright(r: MatchResult, canon: String, home_id: String) -> bool:
	return r.score_home != r.score_away and (r.score_home > r.score_away) == (canon == home_id)


## The team that must win this 1994 World Cup match (groups or final stage), or "" if the books leave it open.
static func canon_wc_winner(w: World, comp_id: String, home: String, away: String) -> String:
	if not comp_id.begins_with("comp_world_cup_1994_") or not bool(w.settings.get("book_events", true)):
		return ""
	if str(CANON_1994_WINS.get(home, "")) == away:
		return away
	if str(CANON_1994_WINS.get(away, "")) == home:
		return home
	var qh := bool(w.national_teams.get(home, {}).get("qualified_1994", false))
	var qa := bool(w.national_teams.get(away, {}).get("qualified_1994", false))
	if qh != qa:
		return home if qh else away
	return ""


func _player_from_pack(d: Dictionary, today: int, rng: SimRng) -> Player:
	var nats: Array = d.get("nationality_ids", ["eng"])
	var attrs := {}
	for g in d.get("attributes", {}).keys():
		for k in d["attributes"][g].keys():
			attrs[str(k)] = float(d["attributes"][g][k])
	var hidden := {}
	for k in d.get("hidden", {}).keys():
		hidden[str(k)] = float(d["hidden"][k])
	var p := Player.from_dict({
		"id": d["id"], "first_name": d.get("first_name", ""), "last_name": d.get("last_name", ""),
		"gender": d.get("gender", SimPlayer.Gender.M), "nationality": nats[0] if not nats.is_empty() else "eng",
		"birth_day": WDate.from_string(str(d.get("birth_date", "1968-01-01"))), "look": d.get("look", {}).duplicate(true),
		"club_id": d.get("club_id", ""), "squad": d.get("squad", Player.Squad.FIRST), "position": d.get("main_position", "C"),
		"positions": d.get("positions", {}).duplicate(true), "attrs": attrs, "hidden": hidden,
		"broom": {"model_id": str(d.get("broom", {}).get("model_id", "broom_cleansweep_seven")), "condition": 100.0},
		"is_captain": d.get("is_captain", false), "source": d.get("source", "canon_book"),
		"traits": d.get("traits_text_keys", []).duplicate(true),
	})
	p.pa = float(d.get("pa", maxf(p.ca(), 100.0)))
	p.contract = _contract_for(p, today, rng)
	p.snapshot_attrs()
	return p


func _contract_for(p: Player, today: int, rng: SimRng) -> Dictionary:
	var ca := p.ca()
	var wage: int = int(clampf(pow(maxf(ca - 60.0, 5.0) / 10.0, 1.6) * 0.9, 3.0, 90.0))
	var years: int = rng.irange(1, 4)
	var end_day := WDate.from_ymd(WDate.season_of(today) + years, 6, 30)
	var role := "rotation"
	if p.squad == Player.Squad.YOUTH:
		role = "youth"
	elif ca >= 135:
		role = "star"
	elif ca >= 110:
		role = "first_team"
	return {"wage_weekly": wage, "end_day": end_day, "role": role}


func _make_filler(w: World, club: Club, pos: String, squad: String, rng: SimRng, idx: int) -> Player:
	var names: Dictionary = loader.names_for(club.region_id, club.country_id)
	var gen := FillerGenerator.new(names, loader.brooms)
	var reserve := squad != Player.Squad.FIRST
	var sp := gen.make_player(rng, pos, club.level, club.id, idx, club.is_women_only(), reserve)
	var taken := {}
	for q in w.club_players(club.id):
		taken[q.name()] = true
	var tries := 0
	while taken.has(sp.name) and tries < 6:
		sp = gen.make_player(rng, pos, club.level, club.id, idx, club.is_women_only(), reserve)
		tries += 1
	var p := Player.new()
	p.id = "%s_%d" % [sp.id, w.season]
	var parts := sp.name.split(" ", false, 1)
	p.first_name = parts[0]
	p.last_name = parts[1] if parts.size() > 1 else ""
	p.gender = sp.gender
	p.nationality = club.country_id
	var age: int
	if squad == Player.Squad.YOUTH:
		age = 17
		p.school_id = Schools.school_for(loader, club.region_id, club.country_id)
		for k in sp.attrs.keys():
			sp.attrs[k] = clampf(float(sp.attrs[k]) - 5.5 + rng.gauss(0.0, 0.8), 1.0, 20.0)
	else:
		age = rng.irange(19, 34)
	var bm := rng.irange(1, 12)
	var bd := rng.irange(1, 28)
	p.birth_day = Schools.leaver_birth_day(WDate.season_of(w.today), bm, bd) if squad == Player.Squad.YOUTH else WDate.from_ymd(WDate.year(w.today) - age, bm, bd)
	p.club_id = club.id
	p.squad = squad
	p.position = pos
	p.positions = {"K": 4, "C": 4, "B": 4, "S": 4}
	p.positions[pos] = 18
	p.attrs = sp.attrs
	p.hidden = sp.hidden
	var ca := p.ca()
	var headroom: float
	if age <= 21:
		headroom = rng.gauss(28.0, 12.0)
	elif age <= 26:
		headroom = rng.gauss(9.0, 6.0)
	else:
		headroom = rng.gauss(2.0, 2.0)
	p.pa = clampf(ca + maxf(headroom, 0.0), ca, 195.0)
	if squad == Player.Squad.YOUTH:
		var mean_pa: float = YOUTH_MEAN_PA[clampi(club.level, 1, 3)]
		# [game]
		mean_pa += 4.0 * (club.academy_level() - Club.base_academy(club.level))
		var pa := rng.gauss(mean_pa, 24.0)
		if rng.chance(0.03):
			pa += 35.0
		p.pa = clampf(pa, ca + 10.0, 195.0)
	p.broom = {"model_id": str(sp.broom.get("model_id", "broom_shooting_star")), "condition": float(rng.irange(70, 100))}
	p.source = "filler"
	p.contract = _contract_for(p, w.today, rng)
	p.snapshot_attrs()
	return p


func _fill_squad(w: World, club: Club, rng: SimRng, with_youth: bool = true, minimum_only: bool = false) -> void:
	var needed_first := {"K": 1, "C": 3, "B": 2, "S": 1}
	var needed_res: Dictionary = {"K": 0, "C": 0, "B": 0, "S": 0} if minimum_only else RESERVE_PLAN.duplicate()
	for p in w.squad_of(club.id):
		if p.squad == Player.Squad.FIRST and needed_first.get(p.position, 0) > 0:
			needed_first[p.position] -= 1
	for p in w.squad_of(club.id):
		if p.squad == Player.Squad.RESERVE and needed_first.get(p.position, 0) > 0:
			p.squad = Player.Squad.FIRST
			needed_first[p.position] -= 1
	for p in w.squad_of(club.id):
		if p.squad == Player.Squad.RESERVE and needed_res.get(p.position, 0) > 0:
			needed_res[p.position] -= 1
	var idx := 100
	for pos in ["K", "C", "B", "S"]:
		while needed_first[pos] > 0:
			idx += 1
			var p := _make_filler(w, club, pos, "first", rng, idx)
			w.add_player(p)
			needed_first[pos] -= 1
		while needed_res[pos] > 0:
			idx += 1
			var p := _make_filler(w, club, pos, "reserve", rng, idx)
			w.add_player(p)
			needed_res[pos] -= 1
	if not with_youth:
		return
	for i in YOUTH_PER_CLUB:
		idx += 1
		var pos: String = str(rng.pick(["C", "C", "C", "B", "B", "K", "S"]))
		var p := _make_filler(w, club, pos, "youth", rng, idx)
		w.add_player(p)


func _assign_board_objective(club: Club) -> void:
	match club.level:
		1:
			club.board = {"objective": "title", "objective_min_pos": 3, "confidence": 60.0}
		2:
			club.board = {"objective": "top_half", "objective_min_pos": 7, "confidence": 60.0}
		_:
			club.board = {"objective": "avoid_last", "objective_min_pos": 12, "confidence": 60.0}


## The first season's objective from the club's reputation rank in its league. Works on the preview world too.
static func initial_objective(w: World, club: Club) -> String:
	var rank := 1
	var n := 0
	for c in w.clubs.values():
		if c.league_id != club.league_id or club.league_id == "":
			continue
		n += 1
		if c.id != club.id and (c.reputation > club.reputation or (c.reputation == club.reputation and c.id < club.id)):
			rank += 1
	return Economy.objective_for_rank(rank, maxi(n, 1))


## Initial backroom staff by club level, with names from the region [FILLER].
static func default_staff(c: Club, ld: SimLoader) -> Dictionary[String, Dictionary]:
	var rng := SimRng.derived(WORLD_SEED, "staff:" + c.id)
	var names: Dictionary = ld.names_for(c.region_id, c.country_id)
	var out: Dictionary[String, Dictionary] = {}
	for role in Club.STAFF_ROLES:
		var lvl: int = clampi(4 - c.level + (1 if rng.chance(0.3) else 0), 1, 5)
		var female := rng.chance(0.4)
		var first: String = str(rng.pick(names["first_names_f"] if female else names["first_names_m"]))
		out[role] = {"name": "%s %s" % [first, FillerGenerator.female_last(names, str(rng.pick(names["last_names"])), female)], "level": lvl, "wage": Club.staff_wage(lvl)}
	return out


## Best available lineup: the assistant proposes it and AI clubs use it. A slot no specialist can fill goes to the
## free player most familiar with that position, the stronger one on a tie.
static func best_lineup(w: World, club_id: String) -> Dictionary:
	var pool := w.squad_of(club_id, [Player.Squad.FIRST, Player.Squad.RESERVE, Player.Squad.YOUTH])
	pool.sort_custom(func(a, b):
		var ka: float = a.ca() + (6.0 if a.squad == Player.Squad.FIRST else 0.0)
		var kb: float = b.ca() + (6.0 if b.squad == Player.Squad.FIRST else 0.0)
		return ka > kb if ka != kb else a.id < b.id)
	var lineup := {"K": "", "C": [], "B": [], "S": ""}
	var need := {"K": 1, "C": 3, "B": 2, "S": 1}
	for p in pool:
		if not p.is_available():
			continue
		if need[p.position] > 0:
			if p.position == "C" or p.position == "B":
				lineup[p.position].append(p.id)
			else:
				lineup[p.position] = p.id
			need[p.position] -= 1
	for pos in ["K", "S", "C", "B"]:
		while need[pos] > 0:
			var best: Player = null
			for p in pool:
				if not p.is_available():
					continue
				if lineup["K"] == p.id or lineup["S"] == p.id or lineup["C"].has(p.id) or lineup["B"].has(p.id):
					continue
				if best == null or float(p.positions.get(pos, 0)) > float(best.positions.get(pos, 0)):
					best = p
			if best == null:
				break
			if pos == "C" or pos == "B":
				lineup[pos].append(best.id)
			else:
				lineup[pos] = best.id
			need[pos] -= 1
	return lineup


## Ensures one captain per club (the first-team player with the highest Influence if none). Returns true if it changed.
static func ensure_captain(w: World, club: Club) -> bool:
	var caps := 0
	for p in w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
		if p.is_captain:
			caps += 1
	if caps == 1:
		return false
	var best: Player = null
	for p in w.squad_of(club.id, [Player.Squad.FIRST]):
		if best == null or float(p.attrs.get("influence", 8.0)) > float(best.attrs.get("influence", 8.0)):
			best = p
	if best == null:
		for p in w.squad_of(club.id, [Player.Squad.RESERVE]):
			if best == null or float(p.attrs.get("influence", 8.0)) > float(best.attrs.get("influence", 8.0)):
				best = p
	for p in w.club_players(club.id):
		p.is_captain = (best != null and p.id == best.id)
	return best != null


func _assign_default_lineup(w: World, club: Club) -> void:
	club.lineup = best_lineup(w, club.id)
	var best: Player = null
	for p in w.squad_of(club.id, [Player.Squad.FIRST]):
		if p.is_captain:
			best = p
			break
		if best == null or float(p.attrs.get("influence", 8.0)) > float(best.attrs.get("influence", 8.0)):
			best = p
	for p in w.squad_of(club.id):
		p.is_captain = (best != null and p.id == best.id)


const SPONSORS := ["Nimbus Racing Broom Company", "Cleansweep Broom Company", "Comet Trading Company", "Butterbeer", "Gringotts", "Gladrags Wizardwear", "Mrs Skower's All-Purpose Magical Mess Remover", "Bluebottle", "Quality Quidditch Supplies", "Honeydukes"]


func _assign_sponsor(club: Club, rng: SimRng) -> void:
	var base: int = [0, 450, 320, 220][clampi(club.level, 1, 3)]
	club.sponsor = {"name": str(rng.pick(SPONSORS)), "monthly": base + rng.irange(-30, 60), "ends_season": club.level + 1993 + rng.irange(0, 2)}


func _manager_name(club: Club, rng: SimRng) -> String:
	var names: Dictionary = loader.names_for(club.region_id, club.country_id)
	var first: String = str(rng.pick(names["first_names_f"] if club.is_women_only() else names["first_names_m"]))
	return "%s %s" % [first, FillerGenerator.female_last(names, str(rng.pick(names["last_names"])), club.is_women_only())]
