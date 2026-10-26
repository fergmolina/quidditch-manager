class_name MatchEvent
extends RefCounted
## One event in the match log.

## How much of the match a reader sees: a log filtered at KEY keeps goals, injuries, the catch and the end.
class Importance:
	const FLOW := 1
	const MINOR := 2
	const NOTABLE := 3
	const MAJOR := 4
	const KEY := 5
	## As stop_importance: no event stops MatchSim.step.
	const NEVER_STOP := 99
	## As min_log_importance: no event is logged.
	const LOG_NONE := 9

## Pitch third the possession is in, from the carrying team's side.
class Zone:
	const OWN := 0
	const MIDFIELD := 1
	const ATTACK := 2

var tick: int = 0
var clock_s: int = 0
var type: String = ""
var importance: int = Importance.FLOW
var team_id: String = ""
var player_id: String = ""
var other_player_id: String = ""
var zone: int = Zone.MIDFIELD

var score_home: int = 0
var score_away: int = 0
var text_key: String = ""
var params: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"t": tick, "s": clock_s, "type": type, "imp": importance, "team": team_id,
		"p": player_id, "p2": other_player_id, "zone": zone,
		"score": [score_home, score_away], "key": text_key, "params": params,
	}


func clock_text() -> String:
	return clock_of(clock_s)


## Formats `secs` as a match clock in the current language, or in English when no translations are loaded.
static func clock_of(secs: int) -> String:
	var h := secs / 3600
	var m := "%02d" % ((secs % 3600) / 60)
	var s := "%02d" % (secs % 60)
	var key := "ui.clock_hms" if h > 0 else "ui.clock_ms"
	var tmpl := str(TranslationServer.translate(key))
	if tmpl == key:
		return ("%dh %sm %ss" % [h, m, s]) if h > 0 else ("%sm %ss" % [m, s])
	return tmpl.replace("{h}", str(h)).replace("{m}", m).replace("{s}", s)
