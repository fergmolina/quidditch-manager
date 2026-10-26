class_name MatchResult
extends RefCounted
## Result of a simulated match.

class EndReason:
	const SNITCH := "snitch"
	const TIME_CAP := "time_cap"
	const HARD_CAP := "hard_cap"
	const MUTUAL_END := "mutual_end"

var seed_value: int = 0
var home_id: String = ""
var away_id: String = ""
var home_name: String = ""
var away_name: String = ""
var score_home: int = 0
var score_away: int = 0
var duration_ticks: int = 0
var duration_s: int = 0
var end_reason: String = ""
var snitch_team_id: String = ""
var snitch_player_id: String = ""
var weather: String = "clear"
var snitch_clock_s: int = -1
var events: Array[MatchEvent] = []
var home_stats: Dictionary = {}
var away_stats: Dictionary = {}
var player_stats: Dictionary[String, Dictionary] = {}
var rng_calls: int = 0
var final_tactics_home: Dictionary = {}
var final_tactics_away: Dictionary = {}


func duration_minutes() -> float:
	return duration_s / 60.0


func winner_id() -> String:
	if score_home > score_away:
		return home_id
	if score_away > score_home:
		return away_id
	return ""


func home_goals() -> int:
	return (score_home - (150 if snitch_team_id == home_id else 0)) / 10


func away_goals() -> int:
	return (score_away - (150 if snitch_team_id == away_id else 0)) / 10


func summary() -> String:
	var snitch := "no catch"

	if snitch_team_id != "":
		snitch = "snitch: %s (%s)" % [snitch_team_id, _clock(snitch_clock_s)]
	return "%s %d - %d %s | %s | %s | %s" % [home_name, score_home, score_away, away_name, _clock(duration_s), snitch, end_reason]


func _clock(s: int) -> String:
	if s < 0:
		return "-"
	var h := s / 3600
	var m := (s % 3600) / 60
	if h > 0:
		return "%dh%02dm" % [h, m]
	return "%dm" % m


func events_min_importance(min_imp: int) -> Array[MatchEvent]:
	var out: Array[MatchEvent] = []
	for e in events:
		if e.importance >= min_imp:
			out.append(e)
	return out
