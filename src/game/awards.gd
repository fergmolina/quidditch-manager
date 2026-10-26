class_name Awards
extends RefCounted

const MIN_APPS := 8
const AWARD_HISTORY_MAX_ENTRIES := 5000


## Computes and records a league's awards at season end. Returns the list of awards given.
static func season_awards(w: World, comp: Competition, season: int) -> Array:
	var given: Array = []
	var candidates: Array[Player] = []
	var stats := {}
	var key := Player.comp_key(season, comp.id)
	for p in w.players_sorted():
		var st: Dictionary = p.comp_stats.get(key, {})
		if int(st.get("apps", 0)) >= MIN_APPS:
			candidates.append(p)
			stats[p.id] = st
	if candidates.is_empty():
		return given
	candidates.sort_custom(func(a, b): return a.id < b.id)
	var best := _best(candidates, stats, avg_rating)
	if best != null:
		given.append(_give(w, comp, season, "wronski", best, "%.2f" % avg_rating(stats[best.id])))  # [film]
	var scorer := _best(candidates, stats, func(st): return float(int(st.get("goals", 0))))
	if scorer != null and int(stats[scorer.id].get("goals", 0)) > 0:
		given.append(_give(w, comp, season, "top_scorer", scorer, str(int(stats[scorer.id]["goals"]))))  # [FILLER]
	var catcher := _best(candidates, stats, func(st): return float(int(st.get("catches", 0))))
	if catcher != null and int(stats[catcher.id].get("catches", 0)) > 0:
		given.append(_give(w, comp, season, "top_catcher", catcher, str(int(stats[catcher.id]["catches"]))))  # [FILLER]
	var keeper := _best(candidates.filter(func(p): return p.position == "K"), stats, avg_rating)
	if keeper != null and int(stats[keeper.id].get("saves", 0)) > 0:
		given.append(_give(w, comp, season, "best_keeper", keeper, "%.2f" % avg_rating(stats[keeper.id])))  # [FILLER]
	if comp.id == "comp_british_irish_league":  # [QTTA c7]
		var dai := _best(candidates, stats, func(st): return float(int(st.get("hits", 0)) + 3 * int(st.get("feints", 0)) + 2 * int(st.get("fouls", 0)) + 2 * int(st.get("injuries", 0))))
		if dai != null:
			given.append(_give(w, comp, season, "dangerous_dai", dai, ""))
	var team := {"K": [], "C": [], "B": [], "S": []}  # [FILLER]
	var need := {"K": 1, "C": 3, "B": 2, "S": 1}
	var by_rating := candidates.duplicate()
	by_rating.sort_custom(func(a, b):
		var ra := avg_rating(stats[a.id])
		var rb := avg_rating(stats[b.id])
		return ra > rb if ra != rb else a.id < b.id)
	for p in by_rating:
		if team[p.position].size() < need[p.position]:
			team[p.position].append(p.id)
	w.awards.push_front({"season": season, "competition_id": comp.id, "kind": "team_of_season", "player_ids": team["K"] + team["C"] + team["B"] + team["S"]})
	while w.awards.size() > AWARD_HISTORY_MAX_ENTRIES:
		w.awards.pop_back()
	return given


static func avg_rating(st: Dictionary) -> float:
	return float(st.get("rating_sum", 0.0)) / maxf(int(st.get("apps", 1)), 1.0)


static func _best(list: Array, stats: Dictionary, score: Callable) -> Player:
	var best: Player = null
	var best_v := -1.0
	for p in list:
		var v: float = score.call(stats.get(p.id, {}))
		if v > best_v:
			best_v = v
			best = p
	return best


static func _give(w: World, comp: Competition, season: int, kind: String, p: Player, value: String) -> Dictionary:
	var a := {"season": season, "competition_id": comp.id, "kind": kind, "player_id": p.id, "club_id": _league_club(w, comp, p, season), "value": value}
	w.awards.push_front(a)
	p.awards.append({"season": season, "kind": kind, "competition_id": comp.id})
	return a


## The league club the player won the award with: their club, or the league club of their latest move this season
## (a sale or release from it, or a loan into it that ended early).
static func _league_club(w: World, comp: Competition, p: Player, season: int) -> String:
	if comp.club_ids.has(p.club_id):
		return p.club_id
	var since := WDate.from_ymd(season, 7, 1)
	for t in w.transfers:
		if int(t.get("day", 0)) < since:
			break
		if str(t.get("player_id", "")) != p.id:
			continue
		for side in ["from_id", "to_id"]:
			if comp.club_ids.has(str(t[side])):
				return str(t[side])
	return ""


static func kind_key(kind: String) -> String:
	return "award." + kind
