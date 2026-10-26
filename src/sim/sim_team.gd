class_name SimTeam
extends RefCounted
## A team inside a match: 7 starters, tactics, score and stats.

const HOUSE_PREFIX := "hs_"
var id: String = ""
var name: String = ""
var players: Array[SimPlayer] = []
var tactics: Dictionary = SimTactics.defaults()
var captain: SimPlayer = null
var is_human: bool = false

var score: int = 0
var timeouts_taken: int = 0
var last_timeout_tick: int = -100000
var conceded_streak: int = 0
var stats: Dictionary = {}
## Combined attribute multiplier of this match's team talks per player id (TeamTalk.cap_effect).
var talk_mult: Dictionary[String, float] = {}


func _init() -> void:
	for k in ["goals", "shots", "saves", "possessions", "steals", "interceptions", "fouls", "penalties_for",
			"penalties_scored", "bludger_hits_dealt", "bludger_hits_taken", "injuries", "send_offs",
			"snitch_sightings", "snitch_catch", "timeouts", "goals_annulled"]:
		stats[k] = 0


func reset_for_match(effect_floor: float) -> void:
	score = 0
	timeouts_taken = 0
	last_timeout_tick = -100000
	conceded_streak = 0
	for k in stats.keys():
		stats[k] = 0
	for p in players:
		p.reset_for_match(effect_floor)
	invalidate()


func add_stat(key: String, n: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + n


func is_school() -> bool:
	return id.begins_with(HOUSE_PREFIX)


var _cache_valid: bool = false
var _active: Array[SimPlayer] = []
var _by_pos: Dictionary = {}


func injure(p: SimPlayer) -> void:
	p.injured = true
	_cache_valid = false


func send_off(p: SimPlayer) -> void:
	p.sent_off = true
	_cache_valid = false


## Drops the active-player cache after `players` itself was edited; injure() and send_off() do it on their own.
func invalidate() -> void:
	_cache_valid = false


func _rebuild_cache() -> void:
	_active = []
	_by_pos = {"K": [] as Array[SimPlayer], "C": [] as Array[SimPlayer], "B": [] as Array[SimPlayer], "S": [] as Array[SimPlayer]}
	for p in players:
		if p.is_active():
			_active.append(p)
			_by_pos[p.position].append(p)
	_cache_valid = true


func active_players() -> Array[SimPlayer]:
	if not _cache_valid:
		_rebuild_cache()
	return _active


func by_position(pos: String, only_active: bool = true) -> Array[SimPlayer]:
	if not only_active:
		var out: Array[SimPlayer] = []
		for p in players:
			if p.position == pos:
				out.append(p)
		return out
	if not _cache_valid:
		_rebuild_cache()
	return _by_pos.get(pos, [] as Array[SimPlayer])


func keeper() -> SimPlayer:
	var ks := by_position("K")
	return ks[0] if not ks.is_empty() else null


func seeker() -> SimPlayer:
	var ss := by_position("S")
	return ss[0] if not ss.is_empty() else null


func chasers() -> Array[SimPlayer]:
	return by_position("C")


func beaters() -> Array[SimPlayer]:
	return by_position("B")


func active_count() -> int:
	return active_players().size()


func avg_condition() -> float:
	var act := active_players()
	if act.is_empty():
		return 0.0
	var s := 0.0
	for p in act:
		s += p.condition
	return s / act.size()


## Mean of an attribute across a group of players (0 if the group is empty).
static func avg_attr(group: Array[SimPlayer], key: String, flying: bool = false) -> float:
	if group.is_empty():
		return 0.0
	var s := 0.0
	for p in group:
		s += p.fly(key) if flying else p.effective(key)
	return s / group.size()
