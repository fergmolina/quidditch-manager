class_name Grounds
extends RefCounted
## Each club's home ground: name and stand capacity by club level, computed once and stored in `Club.ground`.
## [game, FILLER]

static func ensure(club: Club, loader: SimLoader) -> Dictionary:
	if not club.ground.is_empty():
		return club.ground
	var data: Dictionary = loader.grounds
	var kinds: Array = data.get("kinds_by_region", {}).get(club.region_id, ["moor", "plateau"])
	var h := hash(club.id)
	var kind := str(kinds[absi(h) % kinds.size()])
	var rng := SimRng.new(h)
	var range_: Array = data.get("capacity_by_level", {}).get(str(clampi(club.level, 1, 3)), [5000, 10000])
	var lo := int(range_[0])
	var hi := int(range_[1])
	var rep_k := clampf((club.reputation - [0.0, 7000.0, 4500.0, 2500.0][clampi(club.level, 1, 3)] + 500.0) / 1000.0, 0.0, 1.0)
	var cap := int(lerpf(lo, hi, 0.3 * rep_k + 0.7 * rng.next()))
	cap = int(round(cap / 250.0) * 250)
	club.ground = {"kind": kind, "place": place_of(club), "capacity": cap}
	return club.ground


## First part of the club's city, used in the ground name ("Puddlemere (River Piddle), Dorset, England" → "Puddlemere").
static func place_of(club: Club) -> String:
	var c := club.display_city()
	var first := c.get_slice(",", 0).strip_edges()
	if first.contains(" ("):
		first = first.get_slice(" (", 0)
	return first if first != "" else club.short_name


static func name_of(club: Club) -> String:
	var g: Dictionary = club.ground
	if g.is_empty():
		return club.short_name
	var pattern := TranslationServer.translate("ground.kind." + str(g.get("kind", "moor")))
	return pattern % place_of(club) if pattern.find("%s") >= 0 else "%s %s" % [pattern, place_of(club)]


static func capacity_of(club: Club) -> int:
	return int(club.ground.get("capacity", 10000))


## Capacity of a neutral venue by competition type. [game; World Cup 100,000: GoF 8]
static func neutral_capacity(loader: SimLoader, comp_type: String) -> int:
	var n: Dictionary = loader.grounds.get("neutral", {})
	return int(n.get(comp_type, n.get("default", 20000)))


## Match attendance: the home ground's capacity times an occupancy factor. Returns {attendance, fill}. [game]
static func attendance(w: World, club: Club, rival: Club, comp: Competition, rng: SimRng) -> Dictionary:
	var cap := capacity_of(club)
	var fill := 0.48 + 0.35 * Fans.mood(club) / 100.0
	if rival != null:
		fill += clampf((rival.reputation - club.reputation) / 10000.0, -0.1, 0.15)
	if comp != null and comp.type != Competition.Type.LEAGUE:
		fill += 0.08
	fill = clampf(fill + rng.gauss(0.0, 0.04), 0.3, 1.0)
	return {"attendance": int(cap * fill), "fill": fill}
