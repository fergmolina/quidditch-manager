class_name Records  # [game]
extends RefCounted

static func seed_canon(w: World) -> void:  # [QTTA c7]
	if not w.records.is_empty():
		return
	w.records = {
		"fastest_catch": {"value": 3.5, "canon": true, "text": "Roderick Plumpton (Tutshill Tornados)", "season": 1921},
		"longest_match": {"value": 16.0 * 24.0 * 3600.0, "canon": true, "text": "Appleby Arrows – Vratsa Vultures", "season": 1932},
	}


static func after_match(w: World, comp: Competition, r: MatchResult) -> void:
	if comp.type == Competition.Type.FRIENDLY:
		return
	seed_canon(w)
	var label := "%s %d – %d %s" % [w.team_name(r.home_id), r.score_home, r.score_away, w.team_name(r.away_id)]
	var info := {"text": label, "season": w.season, "competition_id": comp.id, "day": w.today,
		"home_id": r.home_id, "away_id": r.away_id, "score_home": r.score_home, "score_away": r.score_away}
	var top := maxi(r.score_home, r.score_away)
	_try(w, "highest_score", float(top), true, info)
	_try(w, "biggest_margin", float(absi(r.score_home - r.score_away)), true, info)
	_try(w, "longest_match", float(r.duration_s), true, info)
	if r.snitch_team_id != "" and r.snitch_player_id != "":
		var catcher: String = w.players[r.snitch_player_id].name() if w.players.has(r.snitch_player_id) else ""
		var info2 := info.duplicate()
		info2["text"] = "%s (%s) · %s" % [catcher, w.team_name(r.snitch_team_id), label]
		info2["player_name"] = catcher
		info2["team_id"] = r.snitch_team_id
		_try(w, "fastest_catch", float(r.duration_s), false, info2)


## At season close: single-season top scorer. Season stats never count friendlies (GameEngine.apply_result).
static func season_end(w: World, season: int) -> void:
	seed_canon(w)
	var best: Player = null
	var goals := 0
	for p in w.players.values():
		var g := int(p.season_stats.get(str(season), {}).get("goals", 0))
		if g > goals:
			goals = g
			best = p
	if best != null:
		_try(w, "season_goals", float(goals), true, {"text": "%s (%s)" % [best.name(), w.team_name(best.club_id)], "season": season,
			"player_name": best.name(), "team_id": best.club_id})


static func _try(w: World, key: String, value: float, higher: bool, info: Dictionary) -> void:
	var cur: Dictionary = w.records.get(key, {})
	if cur.is_empty() or (higher and value > float(cur["value"])) or (not higher and value < float(cur["value"])):
		var rec := info.duplicate()
		rec["value"] = value
		w.records[key] = rec


static func format_value(key: String, v: float) -> String:
	match key:
		"fastest_catch", "longest_match":
			if v < 60.0:
				return "%.1f s" % v
			if v < 3600.0 * 24.0:
				return NewsGenerator.duration_text(int(v))
			return TranslationServer.translate("ui.records.days") % int(round(v / 86400.0))
	return str(int(v))
