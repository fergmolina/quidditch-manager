class_name NationalTeams
extends RefCounted
## National teams call up the best players of their nationality, including the "abroad" pool [FILLER].

const TIER_CA := {"elite": [128.0, 158.0], "strong": [115.0, 145.0], "mid": [100.0, 130.0], "weak": [85.0, 115.0]}
const POOL_PLAN := {"K": 2, "C": 4, "B": 2, "S": 2}


static func nt_id_for_country(country_id: String) -> String:
	return "nt_" + country_id


## The best 7 available players of the nationality, by position. Empty slots take anyone out of position,
## Keeper and Seeker first.
static func pick_squad(w: World, nt: Dictionary) -> Dictionary:
	var country := str(nt["country_id"])
	var pool := w.players_of_nationality(country)
	# [GoF 8]
	var until := str(nt.get("canon_seven_until", ""))
	if until != "" and w.today <= WDate.from_string(until):
		var canon: Array = nt.get("canon_seven", [])
		var first: Array[Player] = []
		var rest: Array[Player] = []
		for p in pool:
			if canon.has(p.id):
				first.append(p)
			else:
				rest.append(p)
		first.append_array(rest)
		pool = first
	var lineup := {"K": "", "C": [], "B": [], "S": ""}
	var need := {"K": 1, "C": 3, "B": 2, "S": 1}
	for p in pool:
		if not p.is_fit():
			continue
		if need[p.position] > 0:
			if p.position == "C" or p.position == "B":
				lineup[p.position].append(p.id)
			else:
				lineup[p.position] = p.id
			need[p.position] -= 1
	for pos in ["K", "S", "C", "B"]:
		while need[pos] > 0:
			var found := false
			for p in pool:
				if not p.is_fit():
					continue
				if lineup["K"] == p.id or lineup["S"] == p.id or lineup["C"].has(p.id) or lineup["B"].has(p.id):
					continue
				if pos == "C" or pos == "B":
					lineup[pos].append(p.id)
				else:
					lineup[pos] = p.id
				need[pos] -= 1
				found = true
				break
			if not found:
				break
	return lineup


static func sim_team(w: World, nt_id: String, brooms: Dictionary) -> SimTeam:
	var nt: Dictionary = w.national_teams.get(nt_id, {})
	var t := SimTeam.new()
	t.id = nt_id
	t.name = w.team_name(nt_id)
	t.tactics = SimTactics.merge(nt.get("tactics", {}))
	if nt.is_empty():
		return t
	var mine := human_seven(w, nt)
	var lineup := mine if not mine.is_empty() else pick_squad(w, nt)
	t.is_human = not mine.is_empty()
	var best_inf := -1.0
	for pair in lineup_slots(lineup):
		var pid: String = str(pair[0])
		var slot: String = str(pair[1])
		if pid == "" or not w.players.has(pid):
			continue
		var p: Player = w.players[pid]
		var sp := p.to_sim_player(brooms)
		sp.position = slot
		if p.position != slot:
			for k in sp.attrs.keys():
				sp.attrs[k] = float(sp.attrs[k]) * 0.8
		t.players.append(sp)
		if float(p.attrs.get("influence", 8.0)) > best_inf:
			best_inf = float(p.attrs.get("influence", 8.0))
			t.captain = sp
	return t


## The seven the national team fields: the federation's pick, or the manager's own seven when they run the team,
## with anyone injured or banned since replaced by the federation's choice for that position.
static func call_up_squad(w: World, nt: Dictionary) -> Dictionary:
	var mine := human_seven(w, nt)
	return mine if not mine.is_empty() else pick_squad(w, nt)


## The manager's own seven when they run this national team and it is still valid once patched; {} otherwise.
static func human_seven(w: World, nt: Dictionary) -> Dictionary:
	if not bool(nt.get("human", false)) or nt.get("lineup", {}).is_empty():
		return {}
	var mine := _patched_lineup(w, nt, nt["lineup"], pick_squad(w, nt))
	return mine if lineup_valid(w, nt, mine) else {}


static func _patched_lineup(w: World, nt: Dictionary, l: Dictionary, fallback: Dictionary) -> Dictionary:
	var ok := func(pid) -> bool:
		var p: Player = w.players.get(str(pid))
		return p != null and p.nationality == str(nt.get("country_id", "")) and p.is_fit()
	var out := {"K": l.get("K", ""), "C": l.get("C", []).duplicate(), "B": l.get("B", []).duplicate(), "S": l.get("S", "")}
	var used := {}
	for pid in [out["K"]] + out["C"] + out["B"] + [out["S"]]:
		if ok.call(pid):
			used[str(pid)] = true
	var spare := func(pos: String) -> String:
		var cands: Array = [fallback.get(pos, "")] if pos == "K" or pos == "S" else fallback.get(pos, []).duplicate()
		for c in cands:
			if ok.call(c) and not used.has(str(c)):
				used[str(c)] = true
				return str(c)
		return ""
	for pos in ["K", "S"]:
		if not ok.call(out[pos]):
			out[pos] = spare.call(pos)
	for pos in ["C", "B"]:
		for i in out[pos].size():
			if not ok.call(out[pos][i]):
				out[pos][i] = spare.call(pos)
	return out


static func lineup_valid(w: World, nt: Dictionary, l: Dictionary) -> bool:
	if l.is_empty() or str(l.get("K", "")) == "" or str(l.get("S", "")) == "" or l.get("C", []).size() != 3 or l.get("B", []).size() != 2:
		return false
	var seen := {}
	for pid in [l["K"]] + l["C"] + l["B"] + [l["S"]]:
		var p: Player = w.players.get(str(pid))
		if p == null or seen.has(pid) or p.nationality != str(nt.get("country_id", "")) or not p.is_fit():
			return false
		seen[pid] = true
	return true


## [player id, slot] pairs of a lineup {K, C: [], B: [], S}, keyed by position. Missing players are left to the caller.
static func lineup_slots(lineup: Dictionary) -> Array:
	var out: Array = [[str(lineup.get("K", "")), "K"]]
	for pid in lineup.get("C", []):
		out.append([str(pid), "C"])
	for pid in lineup.get("B", []):
		out.append([str(pid), "B"])
	out.append([str(lineup.get("S", "")), "S"])
	return out


## Relative strength (mean CA of the 7) for seeding groups and brackets.
static func strength(w: World, nt_id: String) -> float:
	var nt: Dictionary = w.national_teams.get(nt_id, {})
	if nt.is_empty():
		return 0.0
	var lineup := pick_squad(w, nt)
	var ids: Array = [lineup["K"]] + lineup["C"] + lineup["B"] + [lineup["S"]]
	var s := 0.0
	var n := 0
	for pid in ids:
		var p: Player = w.players.get(str(pid))
		if p != null:
			s += p.ca()
			n += 1
	return s / maxf(n, 1)
