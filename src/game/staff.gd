class_name Staff  # [game]
extends RefCounted

const POOL_PER_ROLE := 6


static func min_reputation(level: int) -> int:
	return [0, 0, 1500, 3000, 5000, 7000][clampi(level, 1, 5)]


## Candidate pool (built if empty or on season change).
static func ensure_pool(w: World, loader: SimLoader, rng: SimRng, region_id: String) -> void:
	if not w.staff_pool.is_empty() and int(w.settings.get("staff_pool_season", 0)) == w.season:
		return
	w.staff_pool = []
	var regions: Array = loader.regions.keys()
	regions.sort()
	for role in Club.STAFF_ROLES:
		for i in POOL_PER_ROLE:
			var reg: String = region_id if i < 3 else str(rng.pick(regions))
			var countries: Array = loader.regions.get(reg, {}).get("countries", ["eng"])
			var nat := str(countries[0]) if not countries.is_empty() else "eng"
			var names: Dictionary = loader.names_for(reg, nat)
			var female := rng.chance(0.45)
			var lvl := clampi(1 + int(rng.next() * 5.0), 1, 5)
			w.staff_pool.append({"role": role, "name": "%s %s" % [rng.pick(names["first_names_f"] if female else names["first_names_m"]), FillerGenerator.female_last(names, str(rng.pick(names["last_names"])), female)],  # [FILLER]
				"level": lvl, "wage": Club.staff_wage(lvl), "age": rng.irange(32, 66), "nationality": nat})
	w.settings["staff_pool_season"] = w.season


static func candidates(w: World, role: String) -> Array:
	var out: Array = []
	for c in w.staff_pool:
		if str(c["role"]) == role:
			out.append(c)
	out.sort_custom(func(a, b): return int(a["level"]) > int(b["level"]))
	return out


## Hire: the previous holder of the role leaves (with the rest of their contract paid). Returns {ok, key}.
static func hire(w: World, club: Club, cand: Dictionary) -> Dictionary:
	if club.reputation < min_reputation(int(cand["level"])):
		return {"ok": false, "key": "ui.staff.refuses"}
	var fee := int(cand["wage"]) * 10
	var payoff := severance(w, club, str(cand["role"]))
	if club.balance < fee + payoff:
		return {"ok": false, "key": "ui.market.no_funds"}
	Economy.book(w, club, "staff", -(fee + payoff))
	club.staff[str(cand["role"])] = {"name": str(cand["name"]), "level": int(cand["level"]), "wage": int(cand["wage"]), "contract_end": Contracts.end_day_for(w, 2), "nationality": str(cand.get("nationality", ""))}
	w.staff_pool.erase(cand)
	return {"ok": true, "key": "ui.staff.hired"}


## A staff contract runs to its recorded end and then rolls on week by week until the club replaces or fires
## the holder; firing pays the weeks left, never less than this notice.
const SEVERANCE_MIN_WEEKS := 10


static func is_rolling(w: World, st: Dictionary) -> bool:
	return int(st.get("contract_end", 0)) <= w.today


## Cost of firing the role holder (weeks left × wage, at least SEVERANCE_MIN_WEEKS).
static func severance(w: World, club: Club, role: String) -> int:
	var st: Dictionary = club.staff.get(role, {})
	if st.is_empty():
		return 0
	var weeks := SEVERANCE_MIN_WEEKS if is_rolling(w, st) else maxi(SEVERANCE_MIN_WEEKS, (int(st["contract_end"]) - w.today) / 7)
	return weeks * int(st.get("wage", 0))


## Contract end to show for a role holder: the recorded date, 0 once the contract rolls.
static func contract_end_shown(w: World, st: Dictionary) -> int:
	return 0 if is_rolling(w, st) else int(st["contract_end"])


static func fire(w: World, club: Club, role: String) -> Dictionary:
	var cost := severance(w, club, role)
	if club.balance < cost:
		return {"ok": false, "key": "ui.market.no_funds"}
	Economy.book(w, club, "severance", -cost)
	var st: Dictionary = club.staff.get(role, {})
	club.staff.erase(role)
	if not st.is_empty():
		w.staff_pool.append({"role": role, "name": str(st.get("name", "")), "level": int(st.get("level", 2)), "wage": int(st.get("wage", 4)), "age": 50, "nationality": str(st.get("nationality", ""))})
	return {"ok": true, "key": "ui.staff.fired"}
