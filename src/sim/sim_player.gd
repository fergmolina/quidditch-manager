class_name SimPlayer
extends RefCounted
## A player inside a match: flattened attributes, broom and match state.

const POSITIONS := ["K", "C", "B", "S"]

class Gender:
	const M := "m"
	const F := "f"
	const ALL := [M, F]

class Severity:
	const MATCH := "match"
	const LONG := "long"

## out_clock_s while the player is still on the pitch.
const NOT_OUT := -1

var id: String = ""
var name: String = ""
var position: String = "C"
var gender: String = Gender.M
var attrs: Dictionary = {}
var hidden: Dictionary = {}
var broom: Dictionary = {}

var start_condition: float = 100.0
var condition: float = 100.0
var injured: bool = false
var injury_severity: String = ""
var sent_off: bool = false
var fouls_committed: int = 0
var blatching_count: int = 0
var out_clock_s: int = NOT_OUT
var match_noise: float = 1.0
var drain_factor: float = 1.0
var stats: Dictionary = {}

var _effect_floor: float = 0.55


func _init() -> void:
	for k in ["goals", "shots", "saves", "goals_conceded", "passes", "passes_failed", "steals",
			"interceptions", "bludger_hits_dealt", "bludger_hits_taken", "fouls", "snitch_sightings",
			"snitch_catch", "feints", "minutes"]:
		stats[k] = 0


func is_active() -> bool:
	return not injured and not sent_off


func reset_for_match(effect_floor: float) -> void:
	condition = start_condition
	injured = false
	injury_severity = ""
	sent_off = false
	fouls_committed = 0
	blatching_count = 0
	out_clock_s = NOT_OUT
	_effect_floor = effect_floor
	for k in stats.keys():
		stats[k] = 0


func raw(key: String) -> float:
	return float(attrs.get(key, 8.0))


func hid(key: String) -> float:
	return float(hidden.get(key, 10.0))


## Effective attribute: base × match consistency noise × condition factor.
func effective(key: String) -> float:
	var cond_factor: float = _effect_floor + (1.0 - _effect_floor) * condition / 100.0
	return raw(key) * match_noise * cond_factor


## Flying attribute `key` blended with the broom: 60% player, 40% broom. Dives use the broom's acceleration.
func fly(key: String) -> float:
	var broom_key := key
	match key:
		"agility":
			broom_key = "turning"
		"broom_control":
			broom_key = "braking"
		"balance":
			broom_key = "stability"
		"dive":  # [PoA 4]
			broom_key = "acceleration"
	var b: float = float(broom.get(broom_key, 10.0))
	var cond_factor: float = _effect_floor + (1.0 - _effect_floor) * condition / 100.0
	return (0.6 * raw(key) + 0.4 * b) * match_noise * cond_factor


func add_stat(key: String, n: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n
