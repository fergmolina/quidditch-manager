class_name MatchSim
extends RefCounted
## Deterministic, headless match simulator that advances in 5 s ticks and logs MatchEvents.
## Usage: var r := MatchSim.new(rules, params).run(home, away, seed, interventions)

const Imp := MatchEvent.Importance
const Zone := MatchEvent.Zone
const EndReason := MatchResult.EndReason

class SnitchState:
	const FREE := "free"
	const CHASE := "chase"

## `restart` param of a stoppage event: who takes the Quaffle next.
class Restart:
	const KEEPER := "keeper"
	const NO_CHASERS := "no_chasers"
	const ATTACK := "attack"

var rules: Dictionary
var P: Dictionary

var rng: SimRng
var home: SimTeam
var away: SimTeam
var result: MatchResult

var tick: int = 0
var clock_s: int = 0
var tick_s: int = 5
var ended: bool = false
var stoppage: bool = false
var long_match: bool = false
var next_night_pause_h: float = 16.0

var poss: SimTeam = null
var carrier: SimPlayer = null
var zone: int = Zone.MIDFIELD

var snitch_state: String = SnitchState.FREE
var chaser: SimPlayer = null
var chaser_team: SimTeam = null
var rival_in_chase: bool = false
var chase_ticks: int = 0
var snitch_evasiveness: float = 1.0
var weather: String = "clear"
var _w_sight: float = 1.0
var _w_pass: float = 1.0
var _w_tempo: float = 1.0
var _w_injury: float = 1.0
# [game]
var school_match: bool = false
var _school_tempo: float = 1.0
var _school_sight: float = 1.0

var interventions: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _base_tactics_home: Dictionary = {}
## Events with importance below this threshold are not logged.
var min_log_importance: int = Imp.FLOW
var _base_tactics_away: Dictionary = {}
var _hard_cap_s: int = 0
var _finished: bool = false

var _drain_base: float
var _stamina_relief: float
var _effect_floor: float

## How far a side's mentality slider scales each contest. [game]
const MENT_PUSH := 0.10
const MENT_ADVANCE_VS_DEFENCE := 0.08
const MENT_PASS_RISK := 0.04
const MENT_PASS_GAIN := 0.10
const MENT_SHOT_VS_DEFENCE := 0.04


func _init(rules_in: Dictionary, params_in: Dictionary) -> void:
	rules = rules_in
	P = params_in
	tick_s = int(rules.get("tick_seconds", 5))
	_drain_base = float(P["condition"]["drain_per_tick_base"])
	_stamina_relief = float(P["condition"]["stamina_relief"])
	_effect_floor = float(P["condition"]["effect_floor"])


## Full match in one go. Equivalent to begin() + step() until the end + finish().
func run(home_in: SimTeam, away_in: SimTeam, seed_value: int, interventions_in: Array = [], weather_in: String = "") -> MatchResult:
	begin(home_in, away_in, seed_value, weather_in)
	interventions.assign(interventions_in)
	interventions.sort_custom(func(a, b): return int(a["clock_s"]) < int(b["clock_s"]))
	while not ended:
		step(1 << 30, Imp.NEVER_STOP)
	return finish()


## Prepares the match. Then advance with step() and close with finish(). An empty `weather_in` draws the weather.
func begin(home_in: SimTeam, away_in: SimTeam, seed_value: int, weather_in: String = "") -> void:
	home = home_in
	away = away_in
	rng = SimRng.new(seed_value)
	interventions = []
	result = MatchResult.new()
	result.seed_value = seed_value
	result.home_id = home.id
	result.away_id = away.id
	result.home_name = home.name
	result.away_name = away.name
	_finished = false
	school_match = home.is_school() and away.is_school()
	var SC: Dictionary = P.get("school", {})
	_school_tempo = float(SC.get("quaffle_tempo_mult", 1.0)) if school_match else 1.0
	_school_sight = float(SC.get("snitch_sight_mult", 1.0)) if school_match else 1.0

	_base_tactics_home = home.tactics
	_base_tactics_away = away.tactics
	home.tactics = home.tactics.duplicate(true)
	away.tactics = away.tactics.duplicate(true)
	home.reset_for_match(_effect_floor)
	away.reset_for_match(_effect_floor)
	for t in [home, away]:
		for p in t.players:
			p.drain_factor = 1.0 - _stamina_relief * (p.raw("stamina") - 1.0) / 19.0
	_assign_match_noise(home)
	_assign_match_noise(away)
	if weather_in != "":
		weather = weather_in
	else:
		var kinds := ["clear", "cloudy", "wind", "rain", "storm", "fog"]
		weather = kinds[maxi(rng.pick_weighted(PackedFloat32Array([55.0, 22.0, 10.0, 9.0, 3.0, 1.0])), 0)]  # [PoA 9]
	_w_tempo = 1.0
	match weather:
		"rain":
			_w_sight = 0.75; _w_pass = 0.94; _w_injury = 1.15; _w_tempo = 0.95
		"storm":
			_w_sight = 0.5; _w_pass = 0.88; _w_injury = 1.4; _w_tempo = 0.88
		"snow":
			# [game]
			_w_sight = 0.6; _w_pass = 0.9; _w_injury = 1.25; _w_tempo = 0.85
		"fog":
			_w_sight = 0.35; _w_pass = 0.96; _w_injury = 1.1; _w_tempo = 0.97
		"wind":
			_w_sight = 0.9; _w_pass = 0.92; _w_injury = 1.1
		_:
			_w_sight = 1.0; _w_pass = 1.0; _w_injury = 1.0
	result.weather = weather
	snitch_evasiveness = clampf(exp(rng.gauss(0.0, float(P["snitch"].get("match_evasiveness_sd", 0.0)))), 0.1, 4.0)
	if rng.chance(float(P["snitch"].get("wild_snitch_chance", 0.0))):
		snitch_evasiveness *= 5.0 + rng.next() * 7.0

	tick = 0
	clock_s = 0
	ended = false
	long_match = false
	next_night_pause_h = float(rules.get("night_pause_after_hours", 16))
	snitch_state = SnitchState.FREE
	chaser = null
	chaser_team = null
	rival_in_chase = false
	_pending.clear()
	_hard_cap_s = int(float(P.get("hard_cap_hours", 720)) * 3600.0)
	_kickoff()


## Advances up to `max_ticks` ticks or until an event with importance >= `stop_importance` occurs
## (whichever comes first). Returns the new events. With Imp.NEVER_STOP it never stops on an event.
func step(max_ticks: int, stop_importance: int = Imp.MAJOR) -> Array[MatchEvent]:
	var first_new: int = result.events.size()
	var done := 0
	while not ended and done < max_ticks:
		done += 1
		tick += 1
		clock_s += tick_s
		stoppage = false
		_drain()
		_bludgers()
		if not ended:
			_quaffle()
		if not ended:
			_snitch()
		if not ended:
			_timeouts_ai()
			_interventions()
			_long_match_checks()
			if not ended and clock_s >= _hard_cap_s:
				_end(EndReason.HARD_CAP)
		if stop_importance < Imp.NEVER_STOP:
			var hit := false
			for i in range(first_new, result.events.size()):
				if result.events[i].importance >= stop_importance:
					hit = true
					break
			if hit:
				break
	var out: Array[MatchEvent] = []
	for i in range(first_new, result.events.size()):
		out.append(result.events[i])
	return out


func is_over() -> bool:
	return ended


## Queues a manager tactics change; it takes effect at the next stoppage.
func queue_tactics(team: SimTeam, tactics: Dictionary) -> void:
	_pending.append({"clock_s": clock_s, "team_id": team.id, "tactics": tactics.duplicate(true)})


## Calls a time-out for `team`, granted at once unless can_timeout() refuses it; a refused request changes nothing.
func request_timeout(team: SimTeam) -> void:
	if can_timeout(team):
		_timeout(team)
		_apply_pending()
		_ai_counter_defence(_other(team), 0.75)


## Match minutes a team must wait between two of its own time-outs. [game] [QTTA c6]
func timeout_cooldown_minutes() -> float:
	var T: Dictionary = P["timeouts"]
	return float(T.get("human_cooldown_minutes", T["ai_cooldown_minutes"]))


## Match minutes until `team` may call its next time-out (0 = now).
func timeout_wait_minutes(team: SimTeam) -> int:
	var since: float = (tick - team.last_timeout_tick) * tick_s / 60.0
	return maxi(0, ceili(timeout_cooldown_minutes() - since))


func can_timeout(team: SimTeam) -> bool:
	return not ended and timeout_wait_minutes(team) == 0


## Closes the match (restores the base tactics) and returns the result.
func finish() -> MatchResult:
	if not _finished:
		_finish()
		_finished = true
	return result


func _other(t: SimTeam) -> SimTeam:
	return away if t == home else home


func _assign_match_noise(t: SimTeam) -> void:
	var sd1: float = float(P["consistency"]["match_noise_sd_at_1"])
	var sd20: float = float(P["consistency"]["match_noise_sd_at_20"])
	for p in t.players:
		var c: float = clampf(p.hid("consistency"), 1.0, 20.0)
		var sd: float = sd1 + (sd20 - sd1) * (c - 1.0) / 19.0
		p.match_noise = clampf(rng.gauss(1.0, sd), 0.7, 1.3)


func _ev(type: String, imp: int, team: SimTeam, p: SimPlayer = null, p2: SimPlayer = null, key: String = "", params: Dictionary = {}) -> MatchEvent:
	if imp < min_log_importance:
		return null
	var e := MatchEvent.new()
	e.tick = tick
	e.clock_s = clock_s
	e.type = type
	e.importance = imp
	e.team_id = team.id if team != null else ""
	e.player_id = p.id if p != null else ""
	e.other_player_id = p2.id if p2 != null else ""
	e.zone = zone
	e.score_home = home.score
	e.score_away = away.score
	e.text_key = key if key != "" else "match." + type
	e.params = params
	result.events.append(e)
	return e


func _end(reason: String, team: SimTeam = null, key: String = "") -> void:
	ended = true
	result.end_reason = reason
	_ev("match_end", Imp.KEY, team, null, null, key if key != "" else "match.end." + reason)


func _finish() -> void:
	result.score_home = home.score
	result.score_away = away.score
	result.duration_ticks = tick
	result.duration_s = clock_s
	result.home_stats = home.stats.duplicate()
	result.away_stats = away.stats.duplicate()
	for t in [home, away]:
		for p in t.players:
			p.stats["minutes"] = (clock_s if p.out_clock_s == SimPlayer.NOT_OUT else mini(clock_s, p.out_clock_s)) / 60
			result.player_stats[p.id] = p.stats.duplicate()
	result.rng_calls = rng.calls
	result.final_tactics_home = home.tactics
	result.final_tactics_away = away.tactics
	home.tactics = _base_tactics_home
	away.tactics = _base_tactics_away


func _hours() -> float:
	return clock_s / 3600.0


func _drain() -> void:
	var mult := 1.0
	if long_match:
		mult *= float(P["condition"]["long_match_drain_multiplier"])
	for t in [home, away]:
		var press := SimTactics.slider(t.tactics, "pressing", 0.3)
		var tempo := SimTactics.slider(t.tactics, "tempo", 0.2)
		for p in t.active_players():
			var d: float = _drain_base * p.drain_factor * mult
			if p.position == "C":
				d *= press * tempo
			elif p.position == "B":
				d *= 1.1
			elif p.position == "K":
				d *= 0.7
			p.condition = maxf(0.0, p.condition - d)


func _kickoff() -> void:
	poss = home if rng.chance(0.5) else away
	zone = Zone.MIDFIELD
	carrier = rng.pick(poss.chasers())
	if carrier == null:
		poss = _other(poss)
		carrier = rng.pick(poss.chasers())
	poss.add_stat("possessions")
	_ev("kickoff", Imp.MAJOR, poss, carrier)
	if weather != "clear":
		_ev("weather", Imp.NOTABLE, poss, null, null, "match.weather." + weather)


func _bludgers() -> void:
	var B: Dictionary = P["bludgers"]
	if not rng.chance(float(B["event_chance_per_tick"])):
		return
	var hb := home.beaters()
	var ab := away.beaters()
	var h_skill := SimTeam.avg_attr(hb, "beating")
	var a_skill := SimTeam.avg_attr(ab, "beating")
	var controller: SimTeam = null
	if h_skill > 0.0 or a_skill > 0.0:
		if h_skill <= 0.0:
			controller = away
		elif a_skill <= 0.0:
			controller = home
		else:
			controller = home if rng.contest(h_skill, a_skill, float(B["control_contest_sharpness"])) else away
	if controller == null:
		var everyone: Array[SimPlayer] = home.active_players() + away.active_players()
		var tgt: SimPlayer = rng.pick(everyone)
		if tgt != null:
			_bludger_strike(null, null, tgt, 10.0, 1.0)
		return

	var beater: SimPlayer = rng.pick(controller.beaters())
	var victim_team := _other(controller)
	var instr: String = str(controller.tactics.get("beater_instruction", "nearest"))
	var dmg_mult := 1.0
	var hit_mult := 1.0
	var target: SimPlayer = null
	match instr:
		"hunt_seeker":
			target = victim_team.seeker()
			if target == null:
				target = _weighted_rival_target(victim_team)
		"protect_seeker", "protect_chasers":
			# [game]
			hit_mult = float(B.get("protect_attack_mult", 0.85))
			target = _weighted_rival_target(victim_team)
		"punish_carrier":
			target = carrier if (poss == victim_team and carrier != null and carrier.is_active()) else _weighted_rival_target(victim_team)
		"mark_beaters":
			target = rng.pick(victim_team.beaters())
			if target == null:
				target = _weighted_rival_target(victim_team)
		"backbeat":
			# [QTTA c10] [game]
			hit_mult = 1.5 if rng.chance(0.35) else 0.7
			target = _weighted_rival_target(victim_team)
		"dopplebeater":
			if controller.beaters().size() >= 2:
				hit_mult = 1.3
				dmg_mult = 1.4
			target = _weighted_rival_target(victim_team)
		_:
			target = _weighted_rival_target(victim_team)
	if target == null:
		return

	if target.position == "K" and bool(rules.get("keeper_protected_from_bludgers_outside_area", true)):
		var legal := (poss == controller and zone == Zone.ATTACK)
		if not legal:
			if rng.chance(float(B["keeper_attack_foul_chance"])):
				_bludger_strike(beater, controller, target, beater.effective("beat_accuracy") * 0.6 + beater.effective("beating") * 0.4, hit_mult, dmg_mult)
				if not ended:
					_foul(beater, controller, target, victim_team, "keeper_attack")
				return
			target = _weighted_rival_target(victim_team, true)
			if target == null:
				return

	var att: float = beater.effective("beat_accuracy") * 0.6 + beater.effective("beating") * 0.4
	# [CS 10] [game]
	var v_instr: String = str(victim_team.tactics.get("beater_instruction", "nearest"))
	if (v_instr == "protect_seeker" and target.position == "S") or (v_instr == "protect_chasers" and target.position == "C"):
		var protector: SimPlayer = rng.pick(victim_team.beaters())
		if protector != null:
			var guard: float = protector.effective("beating") * 0.4 + protector.effective("anticipation") * 0.3 + protector.fly("agility") * 0.3
			if rng.chance(float(B.get("protect_deflect_max", 0.5)) * 2.0 * guard / (guard + maxf(att, 1.0))):
				_ev("bludger_deflect", Imp.FLOW, victim_team, protector, target)
				return
	_bludger_strike(beater, controller, target, att, hit_mult, dmg_mult)

	if instr == "backbeat" and rng.chance(0.1):
		var mate: SimPlayer = rng.pick(controller.active_players())
		if mate != null and mate != beater:
			_bludger_strike(null, null, mate, 10.0, 1.0)
	if instr == "dopplebeater" and rng.chance(0.3):
		var own: SimPlayer = rng.pick(controller.active_players())
		if own != null and own != beater:
			_bludger_strike(null, null, own, 10.0, 1.0)


func _weighted_rival_target(victim_team: SimTeam, exclude_keeper: bool = false) -> SimPlayer:
	var act := victim_team.active_players()
	if act.is_empty():
		return null
	var weights := PackedFloat32Array()
	weights.resize(act.size())
	for i in act.size():
		var p := act[i]
		var w := 1.0
		match p.position:
			"C":
				w = 3.0 if (p == carrier) else 2.0
			"S":
				w = 3.0 if (snitch_state == SnitchState.CHASE and (p == chaser or rival_in_chase)) else 1.2
			"B":
				w = 1.0
			"K":
				w = 0.0 if exclude_keeper else 0.3
		weights[i] = w
	var idx := rng.pick_weighted(weights)
	return act[idx] if idx >= 0 else null


func _bludger_strike(beater: SimPlayer, controller: SimTeam, target: SimPlayer, att: float, hit_mult: float, dmg_mult: float = 1.0) -> void:
	var B: Dictionary = P["bludgers"]
	var dodge: float = (target.fly("agility") + target.effective("anticipation") + 0.5 * target.fly("broom_control")) / 2.5
	var p_hit: float = clampf(float(B["hit_chance_base"]) * (att / maxf(dodge, 1.0)) * hit_mult, 0.04, 0.85)
	var victim_team := home if home.players.has(target) else away
	if not rng.chance(p_hit):
		_ev("bludger_dodge", Imp.FLOW, victim_team, target, beater)
		return
	var dmg: float = float(B["hit_damage"]) * dmg_mult * (1.0 - target.effective("strength") / 40.0)
	target.condition = maxf(0.0, target.condition - dmg)
	target.add_stat("bludger_hits_taken")
	victim_team.add_stat("bludger_hits_taken")
	if beater != null:
		beater.add_stat("bludger_hits_dealt")
		controller.add_stat("bludger_hits_dealt")
	_ev("bludger_hit", Imp.NOTABLE, controller if controller != null else victim_team, target, beater)

	if target == carrier and poss == victim_team and rng.chance(float(B["hit_drops_quaffle"])):
		_turnover(_other(victim_team), null, "quaffle_dropped")
	if snitch_state == SnitchState.CHASE and (target == chaser) and rng.chance(float(B["hit_breaks_chase"])):
		_snitch_lost("hit")
	elif snitch_state == SnitchState.CHASE and rival_in_chase and target.position == "S" and target != chaser and rng.chance(float(B["hit_breaks_chase"])):
		rival_in_chase = false

	var p_inj: float = float(B["injury_chance_base"]) * (target.hid("injury_proneness") / 10.0) * (1.0 + (100.0 - target.condition) / 100.0) * _w_injury
	if rng.chance(p_inj):
		_injure(target, victim_team, "bludger")


func _injure(p: SimPlayer, t: SimTeam, cause: String) -> void:
	t.injure(p)
	p.out_clock_s = clock_s
	p.injury_severity = SimPlayer.Severity.LONG if rng.chance(float(P["bludgers"]["injury_long_share"])) else SimPlayer.Severity.MATCH
	t.add_stat("injuries")
	_ev("injury", Imp.KEY, t, p, null, "match.injury." + cause, {"severity": p.injury_severity})
	stoppage = true
	if p == carrier:
		_turnover(_other(t), null, "carrier_injured")
	if p == chaser:
		_snitch_lost("injury")
	if p.position == "S" and rival_in_chase and p != chaser:
		rival_in_chase = false


func _turnover(to_team: SimTeam, new_carrier: SimPlayer, reason: String) -> void:
	var from_team := poss
	var old_carrier := carrier
	poss = to_team
	zone = 2 - zone
	carrier = new_carrier if (new_carrier != null and new_carrier.is_active()) else rng.pick(to_team.chasers())
	to_team.add_stat("possessions")
	if carrier == null:
		if from_team != null and not from_team.chasers().is_empty():
			poss = from_team
			zone = 2 - zone
			carrier = rng.pick(from_team.chasers())
	_ev("turnover", Imp.MINOR, to_team, carrier, old_carrier, "match.turnover." + reason)


func _mark_restart(e: MatchEvent, conceding: SimTeam, kind: String = "") -> void:
	if e == null:
		return
	var p := e.params.duplicate()
	if kind == "":
		kind = Restart.KEEPER if poss == conceding else Restart.NO_CHASERS
	p["restart"] = kind
	p["restart_to"] = carrier.id if carrier != null else ""
	e.params = p


func _restart_from_keeper(conceding: SimTeam) -> void:
	poss = conceding
	zone = Zone.OWN
	carrier = rng.pick(conceding.chasers())
	conceding.add_stat("possessions")
	if carrier == null:
		poss = _other(conceding)
		zone = Zone.ATTACK
		carrier = rng.pick(poss.chasers())


func _quaffle() -> void:
	var Q: Dictionary = P["quaffle"]
	if poss == null or carrier == null or not carrier.is_active():
		var team := poss if poss != null else home
		carrier = rng.pick(team.chasers())
		if carrier == null:
			_turnover(_other(team), null, "no_chasers")
			return
	var action_p: float = float(Q["action_chance_per_tick"]) * SimTactics.slider(poss.tactics, "tempo", 0.4)
	action_p *= lerpf(0.55, 1.0, clampf(poss.avg_condition() / 100.0, 0.0, 1.0))
	if float(poss.tactics.get("time_wasting", 10)) > 10.0:
		action_p *= 1.0 - (float(poss.tactics["time_wasting"]) - 10.0) / 10.0 * 0.5
	action_p *= _comfort(Q, poss) * _w_tempo
	action_p *= _school_tempo
	if not rng.chance(action_p):
		return

	var defence := _other(poss)
	var formation: String = str(poss.tactics.get("chaser_formation", "free"))
	var def_formation: String = str(defence.tactics.get("chaser_formation", "free"))

	if zone == Zone.ATTACK:
		if formation == "porskoff" and poss.chasers().size() >= 2 and rng.chance(0.35):
			_pass(Q, defence, formation, 1.12)
			return
		_shoot(Q, defence, false)
		return

	var long_shot_bias: float = (float(poss.tactics.get("long_shots", 10)) - 10.0) / 10.0
	if zone == Zone.MIDFIELD and rng.chance(clampf(0.06 + 0.25 * long_shot_bias, 0.0, 0.4)):
		_shoot(Q, defence, true)
		return

	var p_pass: float = float(Q["pass_preference_base"]) + 0.15 * (carrier.effective("teamwork") - 10.0) / 10.0
	if formation == "hawkshead":
		p_pass -= 0.15
	elif formation == "porskoff" or formation == "reverse_pass" or formation == "looping":
		p_pass += 0.15
	if poss.chasers().size() < 2:
		p_pass = 0.0
	if rng.chance(p_pass):
		_pass(Q, defence, formation, 1.0)
	else:
		_advance(Q, defence, formation, def_formation)


func _pick_defender(defence: SimTeam) -> SimPlayer:
	var d: SimPlayer = rng.pick(defence.chasers())
	return d


func _advance(Q: Dictionary, defence: SimTeam, formation: String, def_formation: String) -> void:
	var defender := _pick_defender(defence)
	var att: float = carrier.effective("dodging") * 0.5 + carrier.fly("speed") * 0.3 + carrier.fly("agility") * 0.2
	match formation:
		"shimmy":
			att *= 1.15
		"hawkshead":
			att *= 1.10
	var def: float
	if defender == null:
		def = 6.0
	else:
		def = defender.effective("stealing") * 0.5 + defender.effective("anticipation") * 0.3 + defender.fly("speed") * 0.2
		def *= SimTactics.slider(defence.tactics, "pressing", 0.25)
	var p: float = clampf(float(Q["advance_success_base"]) * pow(att / maxf(def, 1.0), float(Q["contest_sharpness"])), 0.08, 0.92)
	match SimTactics.defence_of(defence.tactics):
		"pincer":
			p *= float(Q.get("pincer_vs_carry", 0.7))
		"mark":
			p *= float(Q.get("mark_vs_carry", 1.3))
	p *= SimTactics.slider(poss.tactics, "mentality", MENT_PUSH) * SimTactics.slider(defence.tactics, "mentality", MENT_ADVANCE_VS_DEFENCE)
	if rng.chance(p):
		zone = mini(zone + 1, Zone.ATTACK)
		_ev("advance", Imp.FLOW, poss, carrier, defender)
		return
	if defender != null and rng.chance(float(Q["steal_contact_chance"])):
		if _foul(defender, defence, carrier, poss, "contact"):
			return
		defender.add_stat("steals")
		defence.add_stat("steals")
		_turnover(defence, defender, "steal")
	else:
		_ev("advance_blocked", Imp.FLOW, poss, carrier, defender)


func _pass(Q: Dictionary, defence: SimTeam, formation: String, bonus: float) -> void:
	var mates: Array[SimPlayer] = []
	for c in poss.chasers():
		if c != carrier:
			mates.append(c)
	if mates.is_empty():
		_advance(Q, defence, formation, str(defence.tactics.get("chaser_formation", "free")))
		return
	var target: SimPlayer = rng.pick(mates)
	var defender := _pick_defender(defence)
	var long_pass: float = (float(poss.tactics.get("pass_style", 10)) - 10.0) / 10.0
	var att: float = carrier.effective("passing") * 0.5 + carrier.effective("teamwork") * 0.2 + target.effective("catching") * 0.3
	att *= bonus * _w_pass
	if formation == "reverse_pass":
		att *= 1.05
	elif formation == "porskoff":
		att *= 1.15
	var def: float = 6.0
	if defender != null:
		def = defender.effective("interception") * 0.6 + defender.effective("anticipation") * 0.4

	var p: float = float(Q["pass_success_base"]) * pow(att / maxf(def, 1.0), float(Q["contest_sharpness"]))
	p *= 1.0 - 0.15 * maxf(long_pass, 0.0)
	p *= SimTactics.slider(poss.tactics, "mentality", -MENT_PASS_RISK) * SimTactics.slider(defence.tactics, "mentality", MENT_ADVANCE_VS_DEFENCE * 0.5)
	match SimTactics.defence_of(defence.tactics):
		"mark":
			p *= float(Q.get("mark_vs_pass", 0.8))
		"pincer":
			p *= float(Q.get("pincer_vs_pass", 1.2))
	p = clampf(p, 0.1, 0.95)
	carrier.add_stat("passes")
	if rng.chance(p):
		var passer := carrier
		carrier = target
		var gain_p: float = 0.45 + 0.25 * maxf(long_pass, 0.0)
		gain_p += MENT_PASS_GAIN * (float(poss.tactics.get("mentality", 10)) - 10.0) / 10.0
		if formation == "looping":
			gain_p += 0.1
		elif formation == "porskoff":
			gain_p += 0.15
		if SimTactics.defence_of(defence.tactics) == "pincer":
			gain_p += float(Q.get("pincer_pass_gain", 0.2))
		if rng.chance(gain_p):
			zone = mini(zone + 1, Zone.ATTACK)
		_ev("pass", Imp.FLOW, poss, passer, target)
	else:
		carrier.add_stat("passes_failed")
		if defender != null:
			defender.add_stat("interceptions")
			defence.add_stat("interceptions")
		_turnover(defence, defender, "interception")


# [game]
func _comfort(Q: Dictionary, team: SimTeam) -> float:
	var lead := float(team.score - _other(team).score) - float(Q.get("comfort_lead", 1e9))
	if lead <= 0.0:
		return 1.0
	return lerpf(1.0, float(Q.get("comfort_min", 1.0)), clampf(lead / float(Q.get("comfort_span", 1.0)), 0.0, 1.0))


func _shoot(Q: Dictionary, defence: SimTeam, long_shot: bool) -> void:
	var shooter := carrier
	var keeper := defence.keeper()
	shooter.add_stat("shots")
	poss.add_stat("shots")

	var formation: String = str(poss.tactics.get("chaser_formation", "free"))
	var stooging_p: float = float(Q["stooging_chance_hawkshead"]) if formation == "hawkshead" else float(Q["stooging_chance_other"])
	if not long_shot and bool(rules.get("stooging_annuls_goal", true)) and rng.chance(stooging_p):
		poss.add_stat("goals_annulled")
		var ea := _ev("goal_annulled", Imp.MAJOR, poss, shooter, keeper, "match.foul.stooging")
		stoppage = true
		_restart_from_keeper(defence)
		_mark_restart(ea, defence)
		return
	if not long_shot and rng.chance(float(Q["haversacking_chance"])):
		poss.add_stat("goals_annulled")
		var eh := _ev("goal_annulled", Imp.MAJOR, poss, shooter, keeper, "match.foul.haversacking")
		stoppage = true
		_restart_from_keeper(defence)
		_mark_restart(eh, defence)
		return

	var att: float = shooter.effective("shooting") * 0.6 + shooter.effective("composure") * 0.25 + shooter.effective("flair") * 0.15
	var def: float = 5.0
	if keeper != null:
		def = keeper.effective("keeping") * 0.5 + keeper.effective("reflexes") * 0.3 + keeper.effective("positioning") * 0.2
		match str(defence.tactics.get("keeper_position", "stay")):
			"rush":
				def *= 0.92 if long_shot else 1.06
			# [QTTA c10] [game]
			"starfish":
				def *= 1.07 if long_shot else 0.96
			# [QTTA c10] [game]
			"double_eight":
				def *= 0.97
	var p: float = float(Q["shot_success_base"]) * pow(att / maxf(def, 1.0), float(Q["contest_sharpness"]))
	if long_shot:
		p *= float(Q["long_shot_penalty"])
	p *= lerpf(1.0, _comfort(Q, poss), 0.5)
	if keeper != null:
		p *= SimTactics.slider(defence.tactics, "mentality", MENT_SHOT_VS_DEFENCE)
	p = clampf(p, 0.04, 0.85)
	if rng.chance(p):
		_goal(shooter, poss, defence, "long_shot" if long_shot else "shot")
		return
	if keeper != null and rng.chance(0.75):
		keeper.add_stat("saves")
		defence.add_stat("saves")
		var es := _ev("save", Imp.NOTABLE, defence, keeper, shooter)
		stoppage = true
		_restart_from_keeper(defence)
		_mark_restart(es, defence)
	else:
		var em := _ev("miss", Imp.MINOR, poss, shooter, keeper)
		if rng.chance(float(Q["miss_rebound_to_defence"])):
			_restart_from_keeper(defence)
			_mark_restart(em, defence)
		else:
			_mark_restart(em, defence, Restart.ATTACK)


func _goal(scorer: SimPlayer, team: SimTeam, conceding: SimTeam, kind: String) -> void:
	team.score += int(rules.get("goal_points", 10))
	scorer.add_stat("goals")
	team.add_stat("goals")
	var e := _ev("goal", Imp.KEY, team, scorer, conceding.keeper(), "match.goal." + kind)
	stoppage = true
	_conceded(team, conceding)
	_restart_from_keeper(conceding)
	_mark_restart(e, conceding)


func _conceded(team: SimTeam, conceding: SimTeam) -> void:
	team.conceded_streak = 0
	conceding.conceded_streak += 1
	var k := conceding.keeper()
	if k != null:
		k.add_stat("goals_conceded")
	if conceding.conceded_streak == 3:
		_ai_counter_defence(conceding, 0.5)


func _foul(offender: SimPlayer, off_team: SimTeam, victim: SimPlayer, victim_team: SimTeam, context: String) -> bool:
	var F: Dictionary = P["fouls"]
	var p: float = float(F["base_chance_on_contact"])
	p *= 1.0 + float(F["aggression_weight"]) * (offender.effective("aggression") - 10.0) / 10.0
	p *= 1.0 + float(F["dirtiness_weight"]) * (offender.hid("dirtiness") - 10.0) / 10.0
	p *= 1.0 + float(F["hard_play_weight"]) * (float(off_team.tactics.get("hard_play", 10)) - 10.0) / 10.0
	if context != "keeper_attack" and not rng.chance(clampf(p, 0.0, 0.9)):
		return false

	var foul_id := "cobbing"
	if context == "keeper_attack":
		foul_id = "keeper_attack"
	else:
		var r: float = rng.next()
		if r < 0.35:
			foul_id = "cobbing"
		elif r < 0.6:
			foul_id = "blagging"
		elif r < 0.8:
			foul_id = "blatching"
		elif r < 0.92:
			foul_id = "grabbing"
		else:
			foul_id = "blurting"
	offender.fouls_committed += 1
	offender.add_stat("fouls")
	off_team.add_stat("fouls")

	var seen_p: float = float(F["referee_sees_base"])
	if not rng.chance(seen_p):
		_ev("foul_unseen", Imp.MINOR, off_team, offender, victim, "match.foul.unseen." + foul_id)
		if context == "contact":
			_turnover(off_team, offender, "steal")
		return true

	_ev("foul", Imp.NOTABLE, off_team, offender, victim, "match.foul." + foul_id)
	stoppage = true
	if foul_id == "blatching":
		offender.blatching_count += 1
	if foul_id == "blatching" and (offender.blatching_count >= int(F["send_off_on_repeat_blatching"]) or rng.chance(float(F["blatching_send_off_chance"]))):
		off_team.send_off(offender)
		offender.out_clock_s = clock_s
		off_team.add_stat("send_offs")
		_ev("send_off", Imp.MAJOR, off_team, offender, victim)
		if offender == carrier:
			carrier = null
		if offender == chaser:
			_snitch_lost("send_off")
	_penalty(victim_team, off_team)
	return true


func _penalty(for_team: SimTeam, against: SimTeam) -> void:
	var F: Dictionary = P["fouls"]
	for_team.add_stat("penalties_for")
	var taker: SimPlayer = null
	var best := -1.0
	for c in for_team.chasers():
		var s := c.effective("shooting") + c.effective("composure") * 0.5
		if s > best:
			best = s
			taker = c
	if taker == null:
		_restart_from_keeper(against)
		return
	var keeper := against.keeper()
	var att: float = taker.effective("shooting") * 0.6 + taker.effective("composure") * 0.4
	var def: float = 5.0
	if keeper != null:
		def = keeper.effective("keeping") * 0.5 + keeper.effective("reflexes") * 0.3 + keeper.effective("positioning") * 0.2
		match str(against.tactics.get("keeper_position", "stay")):
			"double_eight":
				def *= 1.25
			"starfish":
				def *= 1.08
	var p: float = clampf(float(F["penalty_success_base"]) * pow(att / maxf(def, 1.0), 1.2), 0.1, 0.9)
	if rng.chance(p):
		for_team.score += int(rules.get("goal_points", 10))
		for_team.add_stat("penalties_scored")
		for_team.add_stat("goals")
		taker.add_stat("goals")
		var eg := _ev("penalty_goal", Imp.MAJOR, for_team, taker, keeper)
		_conceded(for_team, against)
		_restart_from_keeper(against)
		_mark_restart(eg, against)
	else:
		if keeper != null:
			keeper.add_stat("saves")
			against.add_stat("saves")
		var es := _ev("penalty_saved", Imp.NOTABLE, against, keeper, taker)
		_restart_from_keeper(against)
		_mark_restart(es, against)


func _can_catch(team: SimTeam) -> bool:
	var other := _other(team)
	var instr: String = str(team.tactics.get("seeker_catch", "always"))
	var snitch_pts := int(rules.get("snitch_points", 150))
	match instr:
		"if_wins":
			return team.score + snitch_pts > other.score
		"ahead_by":
			return team.score - other.score >= int(team.tactics.get("seeker_ahead_by", 50))
		_:
			return true


func _snitch() -> void:
	var S: Dictionary = P["snitch"]
	if clock_s < int(S["min_sighting_minutes"]) * 60:
		return
	if snitch_state == SnitchState.FREE:
		var hours := _hours()
		var base: float = float(S["sight_base_per_tick"]) * pow(1.0 + float(S["sight_ramp_per_hour"]) * hours, float(S.get("sight_ramp_power", 1.0))) / snitch_evasiveness
		base *= _school_sight
		var order: Array[SimTeam] = []
		if rng.chance(0.5):
			order.assign([home, away])
		else:
			order.assign([away, home])
		for t in order:
			var s := t.seeker()
			if s == null:
				continue
			var p: float = base
			p *= _w_sight
			p *= 1.0 + float(S["sight_eyesight_weight"]) * (s.effective("eyesight") - 10.0) / 10.0
			p *= 1.0 + float(S["sight_concentration_weight"]) * (s.effective("concentration") - 10.0) / 10.0
			if str(t.tactics.get("seeker_search", "free")) == "mark_rival":
				p *= 0.6
			var rival := _other(t)
			if str(rival.tactics.get("seeker_search", "free")) == "mark_rival":
				p *= 0.75
			if rng.chance(maxf(p, 0.0)):
				snitch_state = SnitchState.CHASE
				chaser = s
				chaser_team = t
				rival_in_chase = false
				chase_ticks = 0
				s.add_stat("snitch_sightings")
				t.add_stat("snitch_sightings")
				_ev("snitch_sighted", Imp.MAJOR, t, s)
				return
		return

	chase_ticks += 1
	var rival_team := _other(chaser_team)
	var rival_seeker := rival_team.seeker()
	if rival_seeker == null:
		rival_in_chase = false
	elif not rival_in_chase:
		var pj: float = float(S["rival_join_chance_per_tick"]) * (1.0 + (rival_seeker.effective("eyesight") - 10.0) / 20.0)
		if str(rival_team.tactics.get("seeker_search", "free")) == "mark_rival":
			pj *= 1.5
		if rng.chance(pj):
			rival_in_chase = true
			rival_seeker.add_stat("snitch_sightings")
			rival_team.add_stat("snitch_sightings")
			_ev("snitch_chase_contest", Imp.NOTABLE, rival_team, rival_seeker, chaser)

	if rival_in_chase and rival_seeker != null:
		if not _try_feint(chaser, chaser_team, rival_seeker, rival_team):
			_try_feint(rival_seeker, rival_team, chaser, chaser_team)
		if ended or snitch_state != SnitchState.CHASE or chaser == null:
			return
		rival_team = _other(chaser_team)
		rival_seeker = rival_team.seeker()

	var chaser_can := _can_catch(chaser_team)
	var rival_can := rival_in_chase and rival_seeker != null and _can_catch(rival_team)

	var seekers: Array = [[chaser, chaser_team, chaser_can, rival_in_chase]]
	if rival_in_chase and rival_seeker != null:
		seekers.append([rival_seeker, rival_team, rival_can, true])
	for entry in seekers:
		var s: SimPlayer = entry[0]
		var t: SimTeam = entry[1]
		var can: bool = entry[2]
		var contested: bool = entry[3]
		if not can:
			continue
		var skill: float = (s.effective("snitch_catching") * 0.4 + s.fly("speed") * 0.2 + s.fly("acceleration") * 0.1 + s.fly("agility") * 0.15 + s.fly("dive") * 0.15) / 12.0
		var p: float = float(S["catch_base_per_tick"]) * pow(skill, float(S["catch_skill_weight"])) / float(S["evasiveness"])
		if contested:
			p *= 1.0 - float(S["rival_interference"]) * 0.5
			var other_entry = seekers[1] if entry == seekers[0] else seekers[0]
			if not bool(other_entry[2]):
				p *= 0.7
		if rng.chance(clampf(p, 0.0, 0.6)):
			_catch(s, t)
			return

	var p_lose: float = float(S["lose_base_per_tick"]) * float(S["evasiveness"]) / (1.0 + (chaser.effective("concentration") - 10.0) / 20.0)
	if not chaser_can:
		p_lose *= float(S["stall_lose_multiplier"])
	if rng.chance(clampf(p_lose, 0.0, 0.5)):
		_snitch_lost("escaped")


func _try_feint(feinter: SimPlayer, f_team: SimTeam, victim: SimPlayer, v_team: SimTeam) -> bool:
	var S: Dictionary = P["snitch"]
	var setting: String = str(f_team.tactics.get("seeker_feint", "if_chance"))
	if setting == "never":
		return false
	var p_try: float = float(S["feint_attempt_chance"]) * (2.0 if setting == "seek" else 1.0)
	if not rng.chance(p_try):
		return false
	feinter.add_stat("feints")
	var att: float = feinter.fly("dive") * 0.5 + feinter.effective("flair") * 0.3 + feinter.effective("bravery") * 0.2
	var def: float = victim.effective("decisions") * 0.6 + victim.effective("anticipation") * 0.4
	if rng.contest(att * float(S["feint_success_base"]) / 0.5, def, 1.3):
		victim.condition = maxf(0.0, victim.condition - float(S["feint_crash_damage"]))
		_ev("wronski_feint", Imp.MAJOR, f_team, feinter, victim, "match.feint.success")
		if rng.chance(float(S["feint_crash_injury_chance"])):
			_injure(victim, v_team, "feint")
		else:
			if victim == chaser:
				chaser = feinter
				chaser_team = f_team
				rival_in_chase = false
			else:
				rival_in_chase = false
		return true
	_ev("wronski_feint", Imp.NOTABLE, f_team, feinter, victim, "match.feint.failed")
	if feinter == chaser and rng.chance(0.2):
		_snitch_lost("feint")
	return true


func _snitch_lost(reason: String) -> void:
	if snitch_state != SnitchState.CHASE:
		return
	_ev("snitch_lost", Imp.NOTABLE, chaser_team, chaser, null, "match.snitch_lost." + reason)
	snitch_state = SnitchState.FREE
	chaser = null
	chaser_team = null
	rival_in_chase = false


func _catch(s: SimPlayer, t: SimTeam) -> void:
	t.score += int(rules.get("snitch_points", 150))
	s.add_stat("snitch_catch")
	t.add_stat("snitch_catch")
	result.snitch_team_id = t.id
	result.snitch_player_id = s.id
	result.snitch_clock_s = clock_s
	_ev("snitch_caught", Imp.KEY, t, s)
	snitch_state = SnitchState.FREE
	chaser = null
	if not bool(rules.get("snitch_ends_match", true)):
		return
	chaser_team = null
	rival_in_chase = false
	_end(EndReason.SNITCH)


func _timeouts_ai() -> void:
	var T: Dictionary = P["timeouts"]
	for t in [home, away]:
		if t.is_human:
			continue
		var minutes_since: float = (tick - t.last_timeout_tick) * tick_s / 60.0
		if t.conceded_streak >= int(T["ai_conceded_streak"]) and minutes_since >= float(T["ai_cooldown_minutes"]):
			_timeout(t)
			var other := _other(t)
			var behind: int = other.score - t.score
			if behind >= int(T["ai_switch_seeker_to_always_when_behind_by"]) and t.avg_condition() < 40.0:
				t.tactics["seeker_catch"] = "always"
			elif behind >= 150:
				t.tactics["seeker_catch"] = "if_wins"
			t.tactics["mentality"] = mini(int(t.tactics.get("mentality", 10)) + 3, 20)
			_ai_counter_defence(t, 0.75)


func _ai_counter_defence(t: SimTeam, p: float) -> void:
	if t.is_human:
		return
	var rival_style := str(_other(t).tactics.get("chaser_formation", "free"))
	var counter := SimTactics.counter_to(rival_style)
	if counter != "" and SimTactics.defence_of(t.tactics) != counter and rng.chance(p):
		t.tactics["chaser_defence"] = counter
		_ev("tactics_change", Imp.MINOR, t, t.captain, null, "match.ai_defence." + counter)


func _timeout(t: SimTeam) -> void:
	t.timeouts_taken += 1
	t.last_timeout_tick = tick
	t.conceded_streak = 0
	t.add_stat("timeouts")
	var rec: float = float(P["condition"]["timeout_recovery"])
	for team in [home, away]:
		for p in team.players:
			if p.is_active():
				p.condition = minf(100.0, p.condition + rec)
	_ev("timeout", Imp.MAJOR, t, t.captain)
	stoppage = true


func _interventions() -> void:
	while not interventions.is_empty() and int(interventions[0]["clock_s"]) <= clock_s:
		_pending.append(interventions.pop_front())
	if _pending.is_empty():
		return
	var timed_out: SimTeam = null
	for it in _pending:
		if bool(it.get("timeout", false)):
			timed_out = home if str(it["team_id"]) == home.id else away
			_timeout(timed_out)
			break
	if stoppage:
		_apply_pending()
	if timed_out != null:
		_ai_counter_defence(_other(timed_out), 0.75)


func _apply_pending() -> void:
	for it in _pending:
		var t := home if str(it["team_id"]) == home.id else away
		for k in it.get("tactics", {}).keys():
			t.tactics[k] = it["tactics"][k]
		if not it.get("tactics", {}).is_empty():
			_ev("tactics_change", Imp.MINOR, t, null, null, "", it.get("tactics", {}).duplicate())
	_pending.clear()


func _long_match_checks() -> void:
	var hours := _hours()
	var cap = rules.get("time_cap_minutes", null)
	if cap != null and clock_s >= int(cap) * 60:
		_end(EndReason.TIME_CAP)
		return
	if not long_match and hours >= float(rules.get("long_match_hours", 12)):
		long_match = true
		_ev("long_match_regime", Imp.MAJOR, null)
	if hours >= next_night_pause_h:
		next_night_pause_h += float(rules.get("night_pause_after_hours", 16))
		var rec: float = float(P["condition"]["night_pause_recovery"])
		for team in [home, away]:
			for p in team.players:
				if p.is_active():
					p.condition = minf(100.0, p.condition + rec)
		_ev("night_pause", Imp.MAJOR, null)
		stoppage = true
		_apply_pending()
		if snitch_state == SnitchState.CHASE:
			_snitch_lost("night")
	var M: Dictionary = P["mutual_end"]
	if bool(rules.get("mutual_end_allowed", true)) and home.seeker() == null and away.seeker() == null and clock_s >= int(M["no_seekers_end_minutes"]) * 60:
		_end(EndReason.MUTUAL_END)
		return
	if bool(rules.get("mutual_end_allowed", true)) and clock_s >= int(M["no_seekers_end_minutes"]) * 60:
		for t in [home, away]:
			if t.seeker() == null and t.chasers().is_empty() and t.score < _other(t).score:
				_end(EndReason.MUTUAL_END, t, "match.end.mutual_end.depleted")
				return
	if bool(rules.get("mutual_end_allowed", true)) and hours >= float(M["min_hours"]):
		var diff: int = absi(home.score - away.score)
		if home.avg_condition() < float(M["avg_condition_below"]) and away.avg_condition() < float(M["avg_condition_below"]) \
				and diff > int(rules.get("snitch_points", 150)) + int(M["lead_beyond_snitch_margin"]):
			_end(EndReason.MUTUAL_END)
