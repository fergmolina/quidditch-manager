class_name World
extends RefCounted
## Full state of a saved game. Everything that gets saved lives here.

const SCHEMA_VERSION := 6
## Save collections SaveManager type-checks before loading. from_dict set()s the untyped ones as they are and copies
## the typed ones (news, national_teams, houses, the owls through Inbox.load) element by element: set() of an untyped
## collection into a typed property leaves it empty.
const ARRAY_FIELDS := ["news", "history", "transfers", "pending_offers", "awards", "shortlist",
	"monthly_awards", "staff_pool", "pending_payments", "news_buffer"]
const DICT_FIELDS := ["manager", "settings", "minutes_month", "minutes_last_month", "national_teams", "houses",
	"former_names", "records"]
const TRANSFERS_KEPT := 600

var pack: String = "1993-94"
var seed_value: int = 0
var today: int = 0
var season: int = 1993
var player_club_id: String = ""
var manager: Dictionary = {"name": "", "nationality": "eng", "reputation": 1000, "career": []}
var clubs: Dictionary[String, Club] = {}
var players: Dictionary[String, Player] = {}
var competitions: Dictionary[String, Competition] = {}
var national_teams: Dictionary[String, Dictionary] = {}
var manager_unemployed: bool = false
var inbox: Array[Inbox.Owl] = []
## Open questions keyed by owl id. Inbox is the only writer of this and of `inbox`.
var decisions: Dictionary[int, Inbox.Decision] = {}
var news: Array[Dictionary] = []
var history: Array = []
var transfers: Array = []
var pending_offers: Array = []
var awards: Array = []
var career_id: String = ""
var former_names: Dictionary = {}
var shortlist: Array = []
var monthly_awards: Array = []
var records: Dictionary = {}
var staff_pool: Array = []
var pending_payments: Array = []
var houses: Dictionary[String, Dictionary] = {}
var settings: Dictionary = {"book_events": true, "delegate_training": true, "match_mode": "text", "match_view": "2d"}
var rng_state: int = 0
var next_msg_id: int = 1
var next_offer_id: int = 1
var minutes_month: Dictionary = {}
var minutes_last_month: Dictionary = {}
var news_buffer: Array = []
var world_rng: SimRng = null


func rng() -> SimRng:
	if world_rng == null:
		world_rng = SimRng.new(seed_value ^ rng_state)
	return world_rng


func club(cid: String) -> Club:
	return clubs.get(cid)


func player(pid: String) -> Player:
	return players.get(pid)


func my_club() -> Club:
	if player_club_id == "":
		return null
	if Schools.is_house(player_club_id):
		return house_club(player_club_id)
	return clubs.get(player_club_id)


## Club or house view for an id that may be the human team's; null for an unknown id. A rival house gets a transient view.
func team_club(id: String) -> Club:
	if Schools.is_house(id):
		return house_club_view(id) if houses.has(id) else null
	return clubs.get(id)


## Is the manager running a school house?
func is_school_mode() -> bool:
	return Schools.is_house(player_club_id)


var _house_club: Club = null


## The player's house viewed as a Club. Its lineup, tactics and board live in `houses[hid]` and are copied back
## on save. Other houses get a transient view (house_club_view).
func house_club(hid: String) -> Club:
	if _house_club != null and _house_club.id != player_club_id:
		_house_club = null
	if hid != player_club_id:
		return _house_club_build(hid)
	if _house_club != null and _house_club.id == hid:
		_house_club.league_id = "comp_school_%s_%d" % [str(houses.get(hid, {}).get("school_id", "")).trim_prefix("school_"), season]
		return _house_club
	_house_club = _house_club_build(hid)
	return _house_club


## View of any house: the player's is cached, the others are transient.
func house_club_view(hid: String) -> Club:
	if hid == player_club_id:
		return house_club(hid)
	return _house_club_build(hid)


func _house_club_build(hid: String) -> Club:
	var hd: Dictionary = houses.get(hid, {})
	var sid := str(hd.get("school_id", ""))
	var c := Club.new()
	c.id = hid
	c.name = str(hd.get("name", hid))
	c.short_name = c.name
	c.city = sid.trim_prefix("school_").capitalize()
	var geo := house_geo(hid)
	c.country_id = str(geo.get("country_id", c.country_id))
	c.region_id = str(geo.get("region_id", c.region_id))
	c.league_id = "comp_school_%s_%d" % [sid.trim_prefix("school_"), season]
	c.colors = hd.get("colors", c.colors)
	c.level = 3
	c.reputation = 1500
	c.balance = 0
	c.wage_budget_weekly = 0
	c.transfer_budget = 0
	c.facilities = {"training": 3, "medical": 3, "broom_workshop": 1}
	c.manager_is_human = bool(hd.get("human", false)) and hid == player_club_id
	c.manager_name = str(manager.get("name", "")) if c.manager_is_human else ""
	if c.manager_is_human:
		c.lineup = hd.get("lineup", {})
		c.tactics = hd.get("tactics", SimTactics.defaults())
		c.board = hd.get("board", {"objective": "house_cup", "objective_min_pos": 1, "confidence": 60.0})
	else:
		c.lineup = {}
		c.tactics = SimTactics.defaults()
		c.board = {"objective": "house_cup", "objective_min_pos": 1, "confidence": 60.0}
	c.staff = {}
	c.history = {"league_titles": int(hd.get("cups", 0))}
	c.source = "school"
	return c


static var _school_geo: Dictionary = {}


## {country_id, region_id} of a house's school.
func house_geo(hid: String) -> Dictionary:
	var hd: Dictionary = houses.get(hid, {})
	if hd.has("region_id") and hd.has("country_id"):
		return {"country_id": str(hd["country_id"]), "region_id": str(hd["region_id"])}
	if _school_geo.is_empty():
		_school_geo = {"_": {}}
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/shared/schools.json"))
		if d is Dictionary:
			for sc in d.get("schools", []):
				var regs: Array = sc.get("region_ids", [])
				_school_geo[str(sc.get("id", ""))] = {"country_id": str(sc.get("country_id", "eng")),
					"region_id": str(regs[0]) if not regs.is_empty() else "british_isles"}
	return _school_geo.get(str(hd.get("school_id", "")), {})


## Copies what the player changed in the house view back to `houses`, only while the player still runs that house.
func sync_house_club() -> void:
	if _house_club == null or _house_club.id != player_club_id or not houses.has(_house_club.id):
		return
	var hd: Dictionary = houses[_house_club.id]
	hd["lineup"] = _house_club.lineup
	hd["tactics"] = _house_club.tactics
	hd["board"] = _house_club.board
	hd["human"] = _house_club.manager_is_human


func league_of(club_id: String) -> Competition:
	if Schools.is_house(club_id):
		var hd: Dictionary = houses.get(club_id, {})
		return competitions.get("comp_school_%s_%d" % [str(hd.get("school_id", "")).trim_prefix("school_"), season])
	var c: Club = clubs.get(club_id)
	if c == null:
		return null
	return competitions.get(c.league_id)


var _by_club: Dictionary = {}


func rebuild_index() -> void:
	_by_club.clear()
	for p in players.values():
		_index_add(p)


func _index_add(p: Player) -> void:
	if not _by_club.has(p.club_id):
		_by_club[p.club_id] = [] as Array[Player]
	var arr: Array[Player] = _by_club[p.club_id]
	var i := 0
	while i < arr.size() and arr[i].id < p.id:
		i += 1
	arr.insert(i, p)


func _index_remove(p: Player) -> void:
	if _by_club.has(p.club_id):
		_by_club[p.club_id].erase(p)


## Adds a player to the world. An id already in use replaces the old player.
func add_player(p: Player) -> void:
	var old: Player = players.get(p.id)
	if old != null:
		if old != p:
			push_warning("World.add_player: duplicate id %s replaces an existing player" % p.id)
		_index_remove(old)
	players[p.id] = p
	_index_add(p)


## Permanent removal (retirement).
func remove_player(pid: String) -> void:
	var p: Player = players.get(pid)
	if p == null:
		return
	var old_club := p.club_id
	former_names[pid] = p.name()
	_index_remove(p)
	players.erase(pid)
	_refresh_ai_lineup(old_club, pid)


## Club change ("" makes a free agent). The only place where club_id changes.
## Rows of `transfers`, newest first: {day, player_id, from_id, to_id, fee}, plus "loan": true on a loan.
func log_transfer(player_id: String, from_id: String, to_id: String, fee: int, loan: bool = false) -> void:
	var row := {"day": today, "player_id": player_id, "from_id": from_id, "to_id": to_id, "fee": fee}
	if loan:
		row["loan"] = true
	_push_transfer(row)


## A club letting a player go to free agency: to_id "", fee 0 and "release": true. Awards reads these to credit the
## club the player left; readers that list moves or departures skip them with is_release.
func log_release(player_id: String, from_id: String) -> void:
	assert(from_id != "", "a release needs the club the player leaves")
	_push_transfer({"day": today, "player_id": player_id, "from_id": from_id, "to_id": "", "fee": 0, "release": true})


static func is_release(row: Dictionary) -> bool:
	return bool(row.get("release", false))


## Keeps the newest TRANSFERS_KEPT moves plus this season's releases, which Awards needs until the rollover. Releases
## stay out of the count: a season has about as many as moves and would halve how far back the log reaches.
func _push_transfer(row: Dictionary) -> void:
	transfers.push_front(row)
	if transfers.size() <= TRANSFERS_KEPT:
		return
	var since := WDate.from_ymd(season, 7, 1)
	var kept: Array = []
	var moves := 0
	for t in transfers:
		if is_release(t):
			if int(t["day"]) >= since:
				kept.append(t)
		elif moves < TRANSFERS_KEPT:
			moves += 1
			kept.append(t)
	transfers = kept


func move_player(p: Player, new_club_id: String, new_squad: String) -> void:
	var old_club := p.club_id
	_index_remove(p)
	p.club_id = new_club_id
	p.squad = new_squad
	if new_club_id == "":
		p.loan_listed = false
		p.transfer_listed = false
		p.is_captain = false
	_index_add(p)
	if old_club != new_club_id:
		_refresh_ai_lineup(old_club, p.id)


func _refresh_ai_lineup(club_id: String, pid: String) -> void:
	var c: Club = clubs.get(club_id)
	if c == null or c.manager_is_human or c.lineup.is_empty():
		return
	var l := c.lineup
	var ids: Array = [l.get("K", "")] + l.get("C", []) + l.get("B", []) + [l.get("S", "")]
	if ids.has(pid):
		c.lineup = WorldGenerator.best_lineup(self, club_id)


## A club's players, unsorted.
func club_players(club_id: String) -> Array:
	if Schools.is_house(club_id):
		return Array(squad_of(club_id))
	return _by_club.get(club_id, [])


func squad_of(club_id: String, squads: Array = [Player.Squad.FIRST, Player.Squad.RESERVE, Player.Squad.YOUTH]) -> Array[Player]:
	if Schools.is_house(club_id):
		var hd: Dictionary = houses.get(club_id, {})
		return Schools.students_of(self, str(hd.get("school_id", "")), str(hd.get("house", "")))
	var out: Array[Player] = []
	for p in _by_club.get(club_id, []):
		if squads.has(p.squad):
			out.append(p)
	out.sort_custom(func(a, b): return a.ca() > b.ca() if a.ca() != b.ca() else a.id < b.id)
	return out


## Free agents: no club and not "abroad" players (national-team pool).
func free_agents() -> Array[Player]:
	var out: Array[Player] = []
	for p in _by_club.get("", []):
		if p.squad == Player.Squad.FREE:
			out.append(p)
	return out


## Players of a nationality (for national teams), sorted by CA.
func players_of_nationality(nat: String) -> Array[Player]:
	var out: Array[Player] = []
	for p in players.values():
		if p.nationality == nat and p.squad != Player.Squad.SCHOOL:
			out.append(p)
	out.sort_custom(func(a, b): return a.ca() > b.ca() if a.ca() != b.ca() else a.id < b.id)
	return out


func to_dict() -> Dictionary:
	sync_house_club()
	var cl := {}
	for k in clubs.keys():
		cl[k] = clubs[k].to_dict()
	var pl := {}
	for k in players.keys():
		pl[k] = players[k].to_dict()
	var co := {}
	for k in competitions.keys():
		co[k] = competitions[k].to_dict()
	return {
		"schema": SCHEMA_VERSION, "pack": pack, "seed": str(seed_value), "today": today, "season": season,
		"player_club_id": player_club_id, "manager": manager, "clubs": cl, "players": pl, "competitions": co,
		"owls": Inbox.dump(self), "news": news, "history": history, "transfers": transfers, "pending_offers": pending_offers,
		"settings": settings, "rng_state": rng_state, "next_msg_id": next_msg_id, "next_offer_id": next_offer_id, "minutes_month": minutes_month, "minutes_last_month": minutes_last_month, "news_buffer": news_buffer,
		"national_teams": national_teams, "manager_unemployed": manager_unemployed, "houses": houses, "awards": awards, "former_names": former_names, "career_id": career_id, "shortlist": shortlist,
		"monthly_awards": monthly_awards, "records": records, "staff_pool": staff_pool, "pending_payments": pending_payments,
		"rng_internal": (str(world_rng.get_state()) if world_rng != null else ""),
	}


static func from_dict(d: Dictionary) -> World:
	var w := World.new()
	w.pack = str(d.get("pack", "1993-94"))
	# JSON numbers are doubles: integers above 2^53 lose precision.
	var sd = d.get("seed", 0)
	w.seed_value = str(sd).to_int() if sd is String else int(sd)
	w.today = int(d.get("today", 0))
	w.season = int(d.get("season", 1993))
	w.player_club_id = str(d.get("player_club_id", ""))
	for k in d.get("clubs", {}).keys():
		w.clubs[k] = Club.from_dict(d["clubs"][k])
	for k in d.get("players", {}).keys():
		w.players[k] = Player.from_dict(d["players"][k])
	for k in d.get("competitions", {}).keys():
		w.competitions[k] = Competition.from_dict(d["competitions"][k])
	for k in ARRAY_FIELDS + DICT_FIELDS:
		if w.get(k).is_typed():
			continue
		w.set(k, d.get(k, w.get(k)))
	w.news.assign(d.get("news", []))
	w.national_teams.assign(d.get("national_teams", {}))
	w.houses.assign(d.get("houses", {}))
	w.rng_state = int(d.get("rng_state", 0))
	w.next_msg_id = int(d.get("next_msg_id", 1))
	w.next_offer_id = int(d.get("next_offer_id", 1))
	Inbox.load(w, d.get("owls", {}) if d.get("owls", {}) is Dictionary else {})
	w.career_id = str(d.get("career_id", ""))
	w.manager_unemployed = bool(d.get("manager_unemployed", false))
	if d.has("rng_internal") and str(d["rng_internal"]) != "":
		w.rng().set_state(int(str(d["rng_internal"])))
	w.rebuild_index()
	return w


## Rounds the world's floats to 4 decimals in memory, so the saved state and the in-play state are identical.
func normalize_floats() -> void:
	for p in players.values():
		for k in p.attrs.keys():
			p.attrs[k] = snappedf(float(p.attrs[k]), 0.0001)
		for k in p.hidden.keys():
			p.hidden[k] = snappedf(float(p.hidden[k]), 0.0001)
		for k in p.prev_attrs.keys():
			p.prev_attrs[k] = snappedf(float(p.prev_attrs[k]), 0.0001)
		for k in p.positions.keys():
			p.positions[k] = snappedf(float(p.positions[k]), 0.0001)
		for k in p.happiness.keys():
			p.happiness[k] = snappedf(float(p.happiness[k]), 0.0001)
		p.pa = snappedf(p.pa, 0.0001)
		p.condition = snappedf(p.condition, 0.0001)
		p.sharpness = snappedf(p.sharpness, 0.0001)
		p.morale = snappedf(p.morale, 0.0001)
		p.broom["condition"] = snappedf(float(p.broom.get("condition", 100.0)), 0.0001)
		for i in p.form.size():
			p.form[i] = snappedf(float(p.form[i]), 0.0001)
		for stats in [p.season_stats, p.comp_stats]:
			for key in stats.keys():
				var st: Dictionary = stats[key]
				for f in ["rating_sum", "reserve_rating_sum"]:
					if st.has(f):
						st[f] = snappedf(float(st[f]), 0.0001)
	for c in clubs.values():
		c.board["confidence"] = snappedf(float(c.board.get("confidence", 60.0)), 0.0001)
		if c.fans.has("mood"):
			c.fans["mood"] = snappedf(float(c.fans["mood"]), 0.0001)
		for k in c.knowledge.keys():
			c.knowledge[k] = snappedf(float(c.knowledge[k]), 0.0001)
		for k in c.familiarity.keys():
			c.familiarity[k] = snappedf(float(c.familiarity[k]), 0.0001)
	for hid in houses.keys():
		var hb = houses[hid].get("board", null)
		if hb is Dictionary and hb.has("confidence"):
			hb["confidence"] = snappedf(float(hb["confidence"]), 0.0001)
	if _house_club != null and _house_club.board.has("confidence"):
		_house_club.board["confidence"] = snappedf(float(_house_club.board["confidence"]), 0.0001)


func leagues() -> Array[Competition]:
	var out: Array[Competition] = []
	for c in competitions.values():
		if c.type == Competition.Type.LEAGUE:
			out.append(c)
	out.sort_custom(func(a, b): return a.level < b.level if a.level != b.level else a.id < b.id)
	return out


func competition_of_team(team_id: String, type: String = Competition.Type.LEAGUE) -> Competition:
	for c in competitions.values():
		if c.type == type and c.has_team(team_id):
			return c
	return null


## Short name: the nickname ("the Cannons"); national teams and houses use their name.
func team_short(team_id: String) -> String:
	if clubs.has(team_id) and clubs[team_id].short_name != "":
		return clubs[team_id].short_name
	return team_name(team_id)


var _abbr: Dictionary = {}


## Unique 3-letter abbreviation. National teams use the country code; houses the first 3 letters.
func team_abbr(team_id: String) -> String:
	if _abbr.is_empty():
		_build_abbr()
	if _abbr.has(team_id):
		return _abbr[team_id]
	if national_teams.has(team_id):
		return str(national_teams[team_id].get("country_id", "")).to_upper()
	return _letters(team_name(team_id)).left(3)


static func _letters(s: String) -> String:
	var out := ""
	for ch in s.to_upper():
		var a := ch.unicode_at(0)
		if (a >= 65 and a <= 90):
			out += ch
		elif "ÁÀÄÂÃÅĄ".contains(ch):
			out += "A"
		elif "ÉÈËÊĘĚ".contains(ch):
			out += "E"
		elif "ÍÌÏÎ".contains(ch):
			out += "I"
		elif "ÓÒÖÔÕØŐ".contains(ch):
			out += "O"
		elif "ÚÙÜÛŮŰ".contains(ch):
			out += "U"
		elif ch == "Ñ" or ch == "Ň":
			out += "N"
		elif ch == "Ç" or ch == "Č":
			out += "C"
		elif ch == "Ș" or ch == "Š" or ch == "Ś":
			out += "S"
		elif ch == "Ł":
			out += "L"
		elif ch == "Ř":
			out += "R"
		elif ch == "Ž" or ch == "Ź" or ch == "Ż":
			out += "Z"
		elif ch == " " or ch == "-":
			out += " "
	return out


func _build_abbr() -> void:
	var used := {}
	for c in clubs_sorted():
		var words := _letters(c.name).split(" ", false)
		var tries: Array = []
		if words.size() >= 3:
			tries.append(words[0].left(1) + words[1].left(1) + words[2].left(1))
		if not words.is_empty():
			tries.append(words[0].left(3))
		if words.size() >= 2:
			tries.append(words[0].left(2) + words[words.size() - 1].left(1))
			tries.append(words[0].left(1) + words[1].left(2))
		if not words.is_empty():
			for i in range(3, words[0].length()):
				tries.append(words[0].left(2) + words[0][i])
		var pick := ""
		for t in tries:
			if t.length() == 3 and not used.has(t):
				pick = t
				break
		if pick == "":
			var base: String = (words[0] if not words.is_empty() else "XXX").left(2)
			for l in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
				if not used.has(base + l):
					pick = base + l
					break
		used[pick] = true
		_abbr[c.id] = pick


func team_name(team_id: String) -> String:
	if clubs.has(team_id):
		return clubs[team_id].name
	if national_teams.has(team_id):
		return Loc.name("country." + str(national_teams[team_id].get("country_id", "")), str(national_teams[team_id].get("name", team_id)))
	if houses.has(team_id):
		return Loc.name("house." + str(houses[team_id].get("house", "")), str(houses[team_id].get("name", team_id)))
	return team_id


## Clubs in id order, so loops that consume randomness iterate the same in a loaded world.
func clubs_sorted() -> Array:
	var ids := clubs.keys()
	ids.sort()
	var out := []
	for k in ids:
		out.append(clubs[k])
	return out


func players_sorted() -> Array:
	var ids := players.keys()
	ids.sort()
	var out := []
	for k in ids:
		out.append(players[k])
	return out


func national_team_ids_sorted() -> Array:
	var ids := national_teams.keys()
	ids.sort()
	return ids
