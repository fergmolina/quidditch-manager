class_name SimLoader
extends RefCounted
## Loads rules, parameters, brooms, clubs and players from data/ and builds SimTeams.

const PACK_DIR := "res://data/packs/%s"
const SHARED := "res://data/shared"

var rules: Dictionary = {}
var fouls: Array = []
var params: Dictionary = {}
var brooms: Dictionary[String, Dictionary] = {}
var clubs: Dictionary[String, Dictionary] = {}
var players_by_club: Dictionary[String, Array] = {}
var names_by_region: Dictionary = {}
var regions: Dictionary[String, Dictionary] = {}
var countries: Dictionary[String, Dictionary] = {}
var schools: Dictionary[String, Dictionary] = {}
var climate: Dictionary = {}
var grounds: Dictionary = {}
var school_students: Dictionary[String, Dictionary] = {}
var events: Array = []
var world_cup_history: Dictionary = {}
var national_teams: Dictionary[String, Dictionary] = {}
var competitions_pack: Dictionary[String, Dictionary] = {}
var pack: String = "1993-94"


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Could not open " + path)
		return null
	var txt := f.get_as_text()
	var data = JSON.parse_string(txt)
	if data == null:
		push_error("Invalid JSON in " + path)
	return data


static func list_files(dir_path: String, ext: String = ".json") -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if not d.current_is_dir() and fname.ends_with(ext):
			out.append(dir_path.path_join(fname))
		fname = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


func load_all(pack_name: String = "1993-94") -> void:
	pack = pack_name
	rules = load_json(SHARED + "/rules/match_rules.json")
	var fj = load_json(SHARED + "/rules/fouls.json")
	fouls = fj if fj is Array else []
	params = load_json(SHARED + "/rules/sim_params.json")
	var b = load_json(SHARED + "/brooms.json")
	var blist: Array = b["brooms"] if b is Dictionary else b
	for br in blist:
		brooms[str(br["id"])] = br
	for path in list_files(SHARED + "/names"):
		var n = load_json(path)
		if n is Dictionary:
			names_by_region[str(n.get("region_id", path.get_file().get_basename()))] = n
	var reg = load_json(SHARED + "/regions.json")
	if reg is Dictionary:
		for r in reg.get("regions", []):
			regions[str(r["id"])] = r
			for c in r.get("countries", []):
				var cd: Dictionary = c.duplicate()
				cd["region_id"] = str(r["id"])
				countries[str(c["id"])] = cd
	var gr = load_json(SHARED + "/grounds.json")
	if gr is Dictionary:
		grounds = gr
	var cl = load_json(SHARED + "/climate.json")
	if cl is Dictionary:
		climate = cl
	var sch = load_json(SHARED + "/schools.json")
	if sch is Dictionary:
		for sc in sch.get("schools", []):
			schools[str(sc["id"])] = sc
	var pdir := PACK_DIR % pack
	var sdir := DirAccess.open(pdir + "/schools")
	if sdir != null:
		for fn in sdir.get_files():
			if fn.ends_with(".json"):
				var sd = load_json(pdir + "/schools/" + fn)
				if sd is Dictionary and sd.has("school_id"):
					school_students[str(sd["school_id"])] = sd
	var wh = load_json(pdir + "/world_cup_history.json")
	world_cup_history = wh if wh is Dictionary else {}
	var ev = load_json(pdir + "/events.json")
	events = ev.get("events", []) if ev is Dictionary else []
	var nt = load_json(pdir + "/national_teams.json")
	if nt is Dictionary:
		for t in nt.get("teams", []):
			national_teams[str(t["id"])] = t
	for path in list_files(pdir + "/competitions"):
		var cd = load_json(path)
		if cd is Dictionary:
			competitions_pack[str(cd["id"])] = cd
	for path in list_files(pdir + "/clubs"):
		var c = load_json(path)
		if c is Dictionary:
			clubs[str(c["id"])] = c
			players_by_club[str(c["id"])] = []
	for path in list_files(pdir + "/players"):
		var pl = load_json(path)
		if pl is Dictionary:
			var cid := str(pl.get("club_id", ""))
			if not players_by_club.has(cid):
				players_by_club[cid] = []
			players_by_club[cid].append(pl)


func club_ids() -> Array[String]:
	var out: Array[String] = []
	for k in clubs.keys():
		out.append(str(k))
	out.sort()
	return out


func player_from_dict(d: Dictionary) -> SimPlayer:
	var p := SimPlayer.new()
	p.id = str(d["id"])
	p.name = "%s %s" % [d.get("first_name", ""), d.get("last_name", "")]
	p.position = str(d.get("main_position", "C"))
	var groups: Dictionary = d.get("attributes", {})
	for g in groups.keys():
		for k in groups[g].keys():
			p.attrs[str(k)] = float(groups[g][k])
	for k in d.get("hidden", {}).keys():
		p.hidden[str(k)] = float(d["hidden"][k])
	var bid := str(d.get("broom", {}).get("model_id", "broom_cleansweep_seven"))
	p.broom = brooms.get(bid, {"speed": 10, "acceleration": 10, "turning": 10, "braking": 10, "altitude": 10, "stability": 10}).duplicate()
	p.broom["model_id"] = bid
	return p


## Builds a club's starting team: 1 K, 3 C, 2 B, 1 S. Canon players first (by CA), filler after.
func build_team(club_id: String, tactics: Dictionary = {}) -> SimTeam:
	var c: Dictionary = clubs[club_id]
	var team := SimTeam.new()
	team.id = club_id
	team.name = str(c.get("name", club_id))
	team.tactics = SimTactics.merge(tactics)
	var level := int(c.get("level", 3))
	var women_only := bool(c.get("constraints", {}).get("women_only", false))
	var names: Dictionary = names_for(str(c.get("region_id", "british_isles")), str(c.get("country_id", "eng")))
	var gen := FillerGenerator.new(names, brooms)
	var rng := SimRng.new(hash(club_id + ":" + pack))

	var needed := {"K": 1, "C": 3, "B": 2, "S": 1}
	var canon: Array = players_by_club.get(club_id, []).duplicate()
	canon.sort_custom(func(a, b): return int(a.get("ca", 0)) > int(b.get("ca", 0)))
	var chosen: Array[SimPlayer] = []
	var captain_id := ""
	for d in canon:
		if str(d.get("squad", Player.Squad.FIRST)) != Player.Squad.FIRST:
			continue
		var pos := str(d.get("main_position", "C"))
		if int(needed.get(pos, 0)) > 0:
			var p := player_from_dict(d)
			chosen.append(p)
			needed[pos] -= 1
			if bool(d.get("is_captain", false)):
				captain_id = p.id
	var idx := 0
	for pos in ["K", "C", "B", "S"]:
		while int(needed[pos]) > 0:
			idx += 1
			chosen.append(gen.make_player(rng, pos, level, club_id, idx, women_only))
			needed[pos] -= 1
	var order := {"K": 0, "C": 1, "B": 2, "S": 3}
	chosen.sort_custom(func(a, b): return order[a.position] < order[b.position] if a.position != b.position else a.id < b.id)
	team.players = chosen
	for p in chosen:
		if p.id == captain_id:
			team.captain = p
	if team.captain == null:
		var best: SimPlayer = null
		for p in chosen:
			if best == null or p.raw("influence") > best.raw("influence"):
				best = p
		team.captain = best
	return team


## Synthetic test team with every attribute equal to `level_attr`.
static func synthetic_team(id: String, level_attr: float, tactics: Dictionary = {}, broom_level: float = 12.0) -> SimTeam:
	var team := SimTeam.new()
	team.id = id
	team.name = id
	team.tactics = SimTactics.merge(tactics)
	var i := 0
	for pos in ["K", "C", "C", "C", "B", "B", "S"]:
		i += 1
		var p := SimPlayer.new()
		p.id = "%s_%s%d" % [id, pos, i]
		p.name = p.id
		p.position = pos
		for k in FillerGenerator.ALL_ATTRS:
			p.attrs[k] = level_attr
		for h in FillerGenerator.HIDDEN:
			p.hidden[h] = 10.0
		p.broom = {"model_id": "synthetic", "speed": broom_level, "acceleration": broom_level, "turning": broom_level, "braking": broom_level, "altitude": broom_level, "stability": broom_level}
		team.players.append(p)
	team.captain = team.players[0]
	return team


## Name tables for a country: the country's own if present, otherwise the region's, otherwise the British one.
func names_for(region_id: String, country_id: String) -> Dictionary:
	var reg: Dictionary = names_by_region.get(region_id, {})
	var out := {}
	if reg.has("by_country") and reg["by_country"].has(country_id):
		out = reg["by_country"][country_id].duplicate()
	elif reg.has("first_names_m"):
		out = reg.duplicate()
	else:
		var any_country := {}
		if reg.has("by_country") and not reg["by_country"].is_empty():
			any_country = reg["by_country"].values()[0]
		out = any_country.duplicate() if not any_country.is_empty() else names_by_region.get("british_isles", {}).duplicate()
	if not out.has("club_nouns") or out["club_nouns"].is_empty():
		out["club_nouns"] = reg.get("club_nouns", names_by_region.get("british_isles", {}).get("club_nouns", ["Wanderers"]))
	for k in ["first_names_m", "first_names_f", "last_names", "cities"]:
		if not out.has(k) or out[k].is_empty():
			out[k] = names_by_region.get("british_isles", {}).get(k, ["Smith"])
	return out


func region_of_country(country_id: String) -> String:
	return str(countries.get(country_id, {}).get("region_id", "british_isles"))


func country_name(country_id: String) -> String:
	var c: Dictionary = countries.get(country_id, {})
	if c.is_empty():
		return country_id.to_upper()
	return Loc.name("country." + country_id, str(c.get("name_es", country_id)))
