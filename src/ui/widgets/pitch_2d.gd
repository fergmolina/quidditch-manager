class_name Pitch2D
extends Control
## 2D match viewer: a replay of the simulator's abstract state. It has no physics and
## decides nothing: it reads the event log and moves interpolated tokens. The home team attacks to the right.
## Drawn with _draw(); no assets.

const GRASS := Color("#5B7A3C")
const GRASS_DARK := Color("#54713A")
const LINE := Color(0.97, 0.95, 0.88, 0.8)

var sim: MatchSim = null
var home_club: Club = null
var away_club: Club = null
var _pos: Dictionary[String, Vector2] = {}
var _target: Dictionary[String, Vector2] = {}
var _team_of: Dictionary = {}
var _slot: Dictionary = {}
var _quaffle := Vector2(0.5, 0.5)
var _bludgers: Array = [Vector2(0.35, 0.3), Vector2(0.65, 0.7)]
var _bludger_t: Array = [Vector2(0.35, 0.3), Vector2(0.65, 0.7)]
var _snitch := Vector2(0.5, 0.2)
var _snitch_visible := false
var _caption := ""
var _caption_color := Color.WHITE
var _caption_ttl := 0.0
var _flash := 0.0
var _seed_phase: Dictionary = {}
var _t := 0.0
var _last_event_idx := 0
var _facing: Dictionary = {}
var _history: Array[Dictionary] = []
var _replay: Array = []
var _replay_i := 0.0
var _replay_label := ""
## Match paused or in a time-out: tokens and bludgers stay still (replays, goal animations and the lead-up to a
## key play that is already queued still finish).
var frozen := false
## Visual clock: 1.0 at the normal playback speed (5 ticks a second); the screen scales it with the speed box so
## passes, flights and tokens all speed up together.
var clock_scale := 1.0
signal replay_started
signal replay_finished


func _ready() -> void:
	custom_minimum_size = Vector2(0, 300)
	set_process(is_visible_in_tree())
	_stands = Stands.new()
	_stands.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stands)
	move_child(_stands, 0)
	resized.connect(_refresh_stands)


func setup(s: MatchSim, hc: Club, ac: Club) -> void:
	sim = s
	home_club = hc
	away_club = ac
	_pos.clear()
	_target.clear()
	_team_of.clear()
	_slot.clear()
	for pair in [[sim.home, "home"], [sim.away, "away"]]:
		var t: SimTeam = pair[0]
		for sp in t.players:
			_team_of[sp.id] = pair[1]
			_slot[sp.id] = sp
			_seed_phase[sp.id] = float(hash(sp.id) % 1000) / 1000.0 * TAU
			_pos[sp.id] = _base_spot(sp, pair[1])
			_target[sp.id] = _pos[sp.id]
	_last_event_idx = sim.result.events.size()
	_catch_hand = ""
	_refresh_stands()
	_qa = Vector2(0.5, 0.5)
	_quaffle = Vector2(0.5, 0.5)
	_bludgers = [Vector2(0.35, 0.3), Vector2(0.65, 0.7)]
	_bludger_t = _bludgers.duplicate()
	_bl_victim = ["", ""]
	_bl_boost = [0.0, 0.0]
	_bludger_timer = [0.0, 1.0]
	_anim = {}
	_particles.clear()
	_queue.clear()
	_act = {}
	_hold_target.clear()
	_recv = ""
	_history.clear()
	_hist_acc = 0.0
	_last_play.clear()
	_last_play_label = ""
	_replay.clear()
	_pending_replay = {}
	_facing.clear()
	_snitch_visible = false
	_snitch_vel = Vector2.ZERO
	_caption_ttl = 0.0
	_flash = 0.0
	_sync_vis_from_sim()
	_place_ball(0.0)
	_update_busy()
	queue_redraw()


func _base_spot(sp: SimPlayer, side: String) -> Vector2:
	var v := Vector2(0.5, 0.5)
	match sp.position:
		"K":
			v = Vector2(0.09, 0.5)
		"C":
			var cy: float = [0.5, 0.32, 0.68][clampi(_chaser_index(sp), 0, 2)]
			v = Vector2(0.38, cy)
		"B":
			var by: float = [0.24, 0.76][clampi(_beater_index(sp), 0, 1)]
			v = Vector2(0.3, by)
		"S":
			v = Vector2(0.45, 0.2)
	if side == "away":
		v.x = 1.0 - v.x
	return v


func _mirror(side: String, v: Vector2) -> Vector2:
	return v if side == "home" else Vector2(1.0 - v.x, v.y)


func is_replaying() -> bool:
	return not _replay.is_empty()


var _last_play: Array = []
var _hist_acc := 0.0
var _redraw_acc := 0.0
var _anim: Dictionary = {}
class Particle:
	var p: Vector2
	var v: Vector2
	var life: float
	var max_life: float
	var c: Color
	var r: float

	func _init(p_in: Vector2, v_in: Vector2, life_in: float, c_in: Color, r_in: float) -> void:
		p = p_in
		v = v_in
		life = life_in
		max_life = life_in
		c = c_in
		r = r_in


var _particles: Array[Particle] = []
var _pending_replay: Dictionary = {}
var _busy := false
var _bludger_timer: Array = [0.0, 1.0]
var _catch_hand := ""
var _qa := Vector2(0.5, 0.5)
var _bl_victim: Array = ["", ""]
var _bl_boost: Array = [0.0, 0.0]
var _snitch_vel := Vector2.ZERO
var _wx: Array = []
var _lightning := 0.0
var _lightning_next := 5.0
var capacity := 20000            # stands: ground capacity (the width of the stands depends on it)
var fill := 0.7                  # attendance (0-1): how many people are drawn in the stands
var _stands: Stands = null
## Plays waiting to be shown, one per event (_enqueue_event): {"kind": a KIND_* value, ...}, played by _step_queue.
var _queue: Array[Dictionary] = []
var _act: Dictionary = {}
var _vis_carrier := ""
var _vis_side := ""
var _vis_zone := 1
var _recv := ""
var _hold_target: Dictionary = {}
var _play_start := 0

const SPEED := {"K": 0.22, "C": 0.42, "B": 0.42, "S": 0.3, "S_chase": 0.62}
const BLUDGER_SPEED := 0.4
const ANCHOR_SPEED := 0.6
const PASS_SPEED := 1.2
const SHOT_SPEED := 1.6
const LOOSE_SPEED := 1.0
const QUEUE_MAX_S := 1.0
const REPLAY_PREROLL := 90
const REPLAY_RATE := 0.7
## What a queued play does: INSTANT applies its effect at once; PASS, INTERCEPT, LOOSE and RESTART fly the Quaffle
## to a player; SHOT flies it at a hoop; GOAL and CATCH are the key plays, animated and never dropped to catch up.
const KIND_INSTANT := "instant"
const KIND_PASS := "pass"
const KIND_INTERCEPT := "intercept"
const KIND_LOOSE := "loose"
const KIND_RESTART := "restart"
const KIND_SHOT := "shot"
const KIND_GOAL := "goal"
const KIND_CATCH := "catch"
const KEY_PLAYS := [KIND_GOAL, KIND_CATCH]


## Busy = key play queued or animating, or a replay: the match stays paused (a single signal per period).
func is_busy() -> bool:
	return not _anim.is_empty() or is_replaying() or not _pending_replay.is_empty() or _key_play_pending()


func _key_play_pending() -> bool:
	for a in _queue:
		if KEY_PLAYS.has(str(a["kind"])):
			return true
	return false


func _update_busy() -> void:
	var b := is_busy()
	if b and not _busy:
		_busy = true
		replay_started.emit()
	elif not b and _busy:
		_busy = false
		replay_finished.emit()
var _last_play_label := ""


## Is there a stored play to watch again (last goal or catch)?
func has_last_play() -> bool:
	return not _last_play.is_empty()


## Shows the last key play again ("Replay" button).
func replay_last_play() -> void:
	if has_last_play() and not is_replaying():
		start_replay(_last_play, _last_play_label)


func start_replay(frames: Array, label: String) -> void:
	_replay = frames.duplicate()
	_replay_i = 0.0
	_replay_label = label
	set_process(is_visible_in_tree())
	_update_busy()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_on_visibility()


func _on_visibility() -> void:
	if not is_inside_tree():
		return
	if not is_visible_in_tree():
		set_process(false)
		if is_busy():
			skip_replay()
		return
	if sim != null and (_last_event_idx < sim.result.events.size() or not _queue.is_empty() or not _act.is_empty()):
		catch_up()
	set_process(sim != null)
	queue_redraw()


## Jumps to the match as it is now (after "Next moment", "Simulate to the end" or a view switch): events seen,
## queued actions, animations and stale replay frames dropped, tokens, balls and the Snitch at their places.
func catch_up() -> void:
	if sim == null:
		return
	_last_event_idx = sim.result.events.size()
	_anim = {}
	_replay.clear()
	_pending_replay = {}
	_queue.clear()
	_act = {}
	_hold_target.clear()
	_recv = ""
	_history.clear()
	_hist_acc = 0.0
	_particles.clear()
	_caption_ttl = 0.0
	_flash = 0.0
	_sync_vis_from_sim()
	_qa = _quaffle_anchor()
	if sim.ended and sim.result.snitch_player_id != "" and _pos.has(sim.result.snitch_player_id):
		_catch_hand = sim.result.snitch_player_id
	_snitch_visible = sim.snitch_state == MatchSim.SnitchState.CHASE or _catch_hand != ""
	if _catch_hand == "" and sim.snitch_state == MatchSim.SnitchState.CHASE and sim.chaser != null and _pos.has(sim.chaser.id):
		var cp: Vector2 = _pos[sim.chaser.id]
		_snitch = (cp + Vector2(0.08 if cp.x < 0.5 else -0.08, -0.06)).clamp(Vector2(0.1, 0.12), Vector2(0.9, 0.88))
	_retarget()
	for pid in _target.keys():
		_pos[pid] = _target[pid]
	_retarget()
	for pid in _target.keys():
		_pos[pid] = _target[pid]
	_place_ball(0.0)
	_bl_victim = ["", ""]
	_bludgers = [_inside(_qa + Vector2(-0.1, -0.16)), _inside(_qa + Vector2(0.1, 0.16))]
	_bludger_t = _bludgers.duplicate()
	if sim.ended:
		_caption_set(tr("match.caption.end"), Color.WHITE, 6.0)
	_redraw_acc = 0.0
	_update_busy()
	set_process(is_visible_in_tree())
	queue_redraw()


func _sync_vis_from_sim() -> void:
	_vis_side = "" if sim.poss == null else ("home" if sim.poss == sim.home else "away")
	_vis_zone = clampi(sim.zone, MatchEvent.Zone.OWN, MatchEvent.Zone.ATTACK)
	_vis_carrier = sim.carrier.id if sim.carrier != null and _pos.has(sim.carrier.id) else ""


## After a big clock jump (max speed, "next event") the old frames are no longer useful.
func clear_history() -> void:
	_history.clear()


## Skips the replay in progress (and a key play still queued or animating: it is resolved at once).
func skip_replay() -> void:
	_replay.clear()
	if not _anim.is_empty():
		_finish_anim()
	_pending_replay.clear()
	if _key_play_pending():
		if not _act.is_empty():
			_finish_action()
		while _key_play_pending():
			var a: Dictionary = _queue.pop_front()
			_resolve_instant(a)
	_update_busy()


func _process(delta: float) -> void:
	if sim == null:
		return
	_t += delta
	_step_particles(delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	if is_replaying():
		_replay_i += delta * REPLAY_RATE * 30.0
		if int(_replay_i) >= _replay.size():
			_replay.clear()
			_update_busy()
		queue_redraw()
		return
	var vd := delta * clock_scale
	if not _anim.is_empty():
		_qa = _approach(_qa, _quaffle_anchor(), ANCHOR_SPEED, vd)
		_step_bludgers(vd)
		_retarget()
		_move_players(vd, str(_anim.get("pid", "")))
		_place_ball(vd)
		_step_anim(delta)
		_record_frame(delta, true)
		queue_redraw()
		return
	if not _pending_replay.is_empty():
		_pending_replay["delay"] = float(_pending_replay["delay"]) - delta
		if float(_pending_replay["delay"]) <= 0.0:
			var pr := _pending_replay
			_pending_replay = {}
			start_replay(pr["frames"], str(pr["label"]))
		queue_redraw()
		return
	if frozen and not _key_play_pending():
		if _caption_ttl > 0.0:
			_caption_ttl -= delta
		var moving := _caption_ttl > 0.0 or _flash > 0.0 or not _particles.is_empty()
		_redraw_acc += delta
		if moving or _redraw_acc >= 1.0 / 12.0:
			_redraw_acc = 0.0
			queue_redraw()
		return
	_step_weather(delta)
	_consume_events()
	_step_queue(vd)
	if not _anim.is_empty():
		queue_redraw()
		return
	if sim.ended and _queue.is_empty() and _act.is_empty():
		if _caption_ttl > 0.0:
			_caption_ttl -= delta
		var moving := _caption_ttl > 0.0 or _flash > 0.0 or not _particles.is_empty() or not _wx.is_empty() or _lightning > 0.0
		_redraw_acc += delta
		if moving or _redraw_acc >= 1.0 / 12.0:
			_redraw_acc = 0.0
			queue_redraw()
		if not moving and _last_event_idx >= sim.result.events.size():
			queue_redraw()
			set_process(false)
		return
	_qa = _approach(_qa, _quaffle_anchor(), ANCHOR_SPEED, vd)
	_step_bludgers(vd)
	_retarget()
	_move_players(vd)
	_place_ball(vd)
	_step_snitch(vd)
	if _caption_ttl > 0.0:
		_caption_ttl -= delta
	_record_frame(delta, false)
	queue_redraw()


func _record_frame(delta: float, in_anim: bool) -> void:
	_hist_acc += delta
	if _hist_acc < 1.0 / 30.0:
		return
	_hist_acc = 0.0
	var f := {"pos": _pos.duplicate(), "quaffle": _quaffle, "holder": _vis_carrier, "bludgers": _bludgers.duplicate(),
		"facing": _facing.duplicate(), "snitch": _snitch, "snitch_on": _snitch_visible, "hand": _catch_hand}
	if in_anim and str(_anim.get("kind", "")) == KIND_GOAL and bool(_anim.get("burst", false)):
		f["hoop"] = _hoop_norm(str(_anim["side"]), int(_anim["hoop"]))
		f["since"] = float(_anim["t"]) - float(_anim["dur"])
	_history.append(f)
	if not in_anim and _history.size() > 180:
		_history.pop_front()


func _consume_events() -> void:
	var evs: Array = sim.result.events
	while _last_event_idx < evs.size():
		var e: MatchEvent = evs[_last_event_idx]
		_last_event_idx += 1
		_enqueue_event(e)
	_update_busy()


func _side_of(team_id: String) -> String:
	return "home" if team_id == sim.home.id else "away"


func _other_side(side: String) -> String:
	return "away" if side == "home" else "home"


func _after(side: String, zone: int, carrier: String) -> Dictionary:
	return {"side": side, "zone": clampi(zone, 0, 2), "carrier": carrier if _pos.has(carrier) else ""}


func _push(a: Dictionary) -> void:
	a["est"] = _estimate(a)
	_queue.append(a)


func _push_restart(e: MatchEvent, conceding: String, keeper: String) -> void:
	var to := str(e.params.get("restart_to", ""))
	var kind := str(e.params.get("restart", MatchSim.Restart.KEEPER))
	var after := _after(_other_side(conceding), MatchEvent.Zone.ATTACK, to) if kind == MatchSim.Restart.NO_CHASERS else _after(conceding, MatchEvent.Zone.OWN, to)
	if to == "" or not _pos.has(to):
		_push({"kind": KIND_INSTANT, "after": after})
		return
	if _pos.has(keeper) and _slot.has(keeper) and _slot[keeper].is_active():
		_push({"kind": KIND_LOOSE, "to_pid": keeper, "after": _after(conceding, MatchEvent.Zone.OWN, keeper), "skip_if_held": true})
		_push({"kind": KIND_RESTART, "to_pid": to, "lead": 0.05, "after": after})
	else:
		_push({"kind": KIND_LOOSE, "to_pid": to, "after": after})


func _enqueue_event(e: MatchEvent) -> void:
	var side := _side_of(e.team_id)
	var other := _other_side(side)
	var p := e.player_id
	var p2 := e.other_player_id
	match e.type:
		"kickoff":
			_push({"kind": KIND_INSTANT, "after": _after(side, MatchEvent.Zone.MIDFIELD, p)})
		"pass":
			if _pos.has(p2):
				_push({"kind": KIND_PASS, "to_pid": p2, "lead": 0.04, "after": _after(side, e.zone, p2)})
			else:
				_push({"kind": KIND_INSTANT, "after": _after(side, e.zone, p)})
		"advance":
			_push({"kind": KIND_INSTANT, "after": _after(side, e.zone, p)})
		"turnover":
			var reason := e.text_key.get_slice(".", 2)
			if p == "" or not _pos.has(p):
				_push({"kind": KIND_INSTANT, "after": _after(side, e.zone, p)})
			elif reason == "interception":
				_push({"kind": KIND_INTERCEPT, "to_pid": p, "lead": 0.02, "after": _after(side, e.zone, p)})
			else:
				_push({"kind": KIND_LOOSE, "to_pid": p, "lead": 0.03, "after": _after(side, e.zone, p)})
		"goal", "penalty_goal":
			var keeper := p2
			if e.type == "penalty_goal":
				_push({"kind": KIND_LOOSE, "to_pid": p, "after": _after(side, MatchEvent.Zone.ATTACK, p), "skip_if_held": true})
			_push({"kind": KIND_GOAL, "pid": p, "side": side, "hoop": e.tick % 3, "after": _after(other, MatchEvent.Zone.OWN, ""),
				"caption": [tr("match.caption.goal") % _name(p), ThemeBuilder.BRASS_BUTTON, 2.6],
				"label": tr("match.caption.replay") % _name(p)})
			_push_restart(e, other, keeper)
		"save", "penalty_saved":
			if e.type == "penalty_saved" and _pos.has(p2):
				_push({"kind": KIND_LOOSE, "to_pid": p2, "after": _after(other, MatchEvent.Zone.ATTACK, p2), "skip_if_held": true})
			_push({"kind": KIND_SHOT, "outcome": "save", "pid": p2, "keeper": p, "att": other, "hoop": e.tick % 3,
				"after": _after(side, MatchEvent.Zone.OWN, p), "caption": [tr("match.caption.save") % _name(p), Color.WHITE, 1.6], "caption_at": "end"})
			_push_restart(e, side, p)
		"miss":
			_push({"kind": KIND_SHOT, "outcome": "miss", "pid": p, "att": side, "hoop": e.tick % 3, "after": _after(side, e.zone, "")})
			var to := str(e.params.get("restart_to", ""))
			var kind := str(e.params.get("restart", MatchSim.Restart.ATTACK))
			var after := _after(side, e.zone, to)
			if kind == MatchSim.Restart.KEEPER:
				after = _after(other, MatchEvent.Zone.OWN, to)
			elif kind == MatchSim.Restart.NO_CHASERS:
				after = _after(side, MatchEvent.Zone.ATTACK, to)
			if _pos.has(to):
				_push({"kind": KIND_LOOSE, "to_pid": to, "lead": 0.03, "after": after})
			else:
				_push({"kind": KIND_INSTANT, "after": after})
		"goal_annulled":
			_push({"kind": KIND_SHOT, "outcome": "annulled", "pid": p, "att": side, "hoop": e.tick % 3, "after": _after(other, MatchEvent.Zone.OWN, ""),
				"caption": [tr("match.caption.foul") % _name(p), Color("#F0C9B8"), 1.8], "caption_at": "end"})
			_push_restart(e, other, p2)
		"bludger_hit", "bludger_dodge":
			_push({"kind": KIND_INSTANT, "effect": "bludger", "tgt": p, "hit": e.type == "bludger_hit"})
		"bludger_deflect":
			_push({"kind": KIND_INSTANT, "effect": "bludger", "tgt": p2 if p2 != "" else p, "hit": false})
		"snitch_sighted":
			_push({"kind": KIND_INSTANT, "effect": "snitch_sighted", "pid": p,
				"caption": [tr("match.caption.sighted") % _name(p), ThemeBuilder.GOLD, 2.0]})
		"snitch_lost":
			_push({"kind": KIND_INSTANT, "effect": "snitch_lost"})
		"snitch_caught":
			_push({"kind": KIND_CATCH, "pid": p, "side": side,
				"caption": [tr("match.caption.caught") % _name(p), ThemeBuilder.GOLD, 4.5],
				"label": tr("match.caption.replay_catch") % _name(p)})
		"foul", "foul_unseen":
			_push({"kind": KIND_INSTANT, "caption": [tr("match.caption.foul") % _name(p), Color("#F0C9B8"), 1.6]})
		"injury":
			_push({"kind": KIND_INSTANT, "caption": [tr("match.caption.injury") % _name(p), ThemeBuilder.SEALING_WAX.lightened(0.4), 2.5]})
		"send_off":
			_push({"kind": KIND_INSTANT, "caption": [tr("match.caption.send_off") % _name(p), ThemeBuilder.SEALING_WAX.lightened(0.4), 2.5]})
		"timeout":
			_push({"kind": KIND_INSTANT, "caption": [tr("match.caption.timeout") % Game.club_name(e.team_id), Color.WHITE, 2.0]})
		"wronski_feint":
			_push({"kind": KIND_INSTANT, "caption": [tr("match.caption.feint") % _name(p), ThemeBuilder.GOLD, 2.0]})
		"match_end":
			_push({"kind": KIND_INSTANT, "caption": [tr("match.caption.end"), Color.WHITE, 6.0]})


func _queued_seconds() -> float:
	var s := 0.0
	for a in _queue:
		s += float(a.get("est", 0.0))
	if not _act.is_empty():
		s += maxf(0.0, float(_act.get("dur", 0.0)) - float(_act.get("t", 0.0)))
	return s


func _step_queue(vd: float) -> void:
	while not _queue.is_empty() and _queued_seconds() > QUEUE_MAX_S and not KEY_PLAYS.has(str(_queue[0]["kind"])):
		var old: Dictionary = _queue.pop_front()
		_resolve_instant(old, not _act.is_empty())
	if _act.is_empty():
		while _act.is_empty() and _anim.is_empty() and not _queue.is_empty():
			_act = _queue.pop_front()
			_start_action()
		if _act.is_empty():
			if _queue.is_empty() and _anim.is_empty():
				_reconcile()
			return
	_act["t"] = float(_act["t"]) + vd
	if float(_act["t"]) >= float(_act["dur"]):
		_finish_action()


func _estimate(a: Dictionary) -> float:
	match str(a["kind"]):
		KIND_PASS, KIND_INTERCEPT:
			return 0.35
		KIND_SHOT:
			return 0.3
		KIND_LOOSE, KIND_RESTART:
			return 0.3
	return 0.0


func _start_action() -> void:
	var a := _act
	var kind := str(a["kind"])
	var to_pid := str(a.get("to_pid", ""))
	if kind == KIND_INSTANT or (bool(a.get("skip_if_held", false)) and to_pid == _vis_carrier):
		_resolve_instant(a)
		_act = {}
		return
	if kind == KIND_GOAL or kind == KIND_CATCH:
		_start_key_play(a)
		_act = {}
		return
	if to_pid != "" and not _pos.has(to_pid):
		_resolve_instant(a)
		_act = {}
		return
	a["t"] = 0.0
	a["from"] = _quaffle
	var from: Vector2 = _quaffle
	var to := from
	var speed := PASS_SPEED
	var lo := 0.2
	var hi := 0.5
	match kind:
		KIND_PASS, KIND_INTERCEPT, KIND_LOOSE, KIND_RESTART:
			var rp: Vector2 = _pos[to_pid]
			var lead := float(a.get("lead", 0.0))
			if kind == KIND_LOOSE or kind == KIND_INTERCEPT:
				to = _inside(rp + (from - rp).normalized() * lead) if rp.distance_to(from) > 0.001 else rp
			else:
				var dir := 1.0 if _team_of[to_pid] == "home" else -1.0
				to = _inside(rp + Vector2(dir * lead, 0.0))
			_hold_target[to_pid] = to
			_recv = to_pid
			if kind == KIND_LOOSE:
				speed = LOOSE_SPEED
				lo = 0.15
				hi = 0.4
			elif kind == KIND_RESTART:
				speed = LOOSE_SPEED
				lo = 0.25
				hi = 0.5
		KIND_SHOT:
			speed = SHOT_SPEED
			lo = 0.2
			hi = 0.45
			var att := str(a["att"])
			var hoop := _hoop_norm(att, int(a["hoop"]))
			var keeper := str(a.get("keeper", ""))
			match str(a["outcome"]):
				"save":
					if _pos.has(keeper):
						var kp: Vector2 = _pos[keeper]
						to = _inside(kp + (from - kp).normalized() * 0.03) if kp.distance_to(from) > 0.001 else kp
						_hold_target[keeper] = to
						a["to_pid"] = keeper
					else:
						to = hoop
				"miss":
					to = _inside(_mirror(att, Vector2(0.95, 0.3 if int(a["hoop"]) % 2 == 0 else 0.7)))
				_:
					to = hoop
			var shooter := str(a.get("pid", ""))
			if _pos.has(shooter):
				_hold_target[shooter] = _inside(_pos[shooter].lerp(hoop, 0.1))
	a["to"] = to
	a["dur"] = clampf(from.distance_to(to) / speed, lo, hi)
	_vis_carrier = ""
	if a.has("caption") and str(a.get("caption_at", "start")) == "start":
		_caption_from(a)


func _caption_from(a: Dictionary) -> void:
	var c: Array = a["caption"]
	_caption_set(str(c[0]), c[1], float(c[2]))


func _finish_action() -> void:
	var a := _act
	_act = {}
	_hold_target.clear()
	_recv = ""
	if a.has("after"):
		_apply_after(a["after"])
	if a.has("caption") and str(a.get("caption_at", "start")) == "end":
		_caption_from(a)
	_place_ball(0.0)


func _apply_after(af: Dictionary) -> void:
	if str(af.get("side", "")) != "":
		_vis_side = str(af["side"])
	_vis_zone = int(af.get("zone", _vis_zone))
	_vis_carrier = str(af.get("carrier", ""))


func _resolve_instant(a: Dictionary, defer: bool = false) -> void:
	match str(a.get("effect", "")):
		"bludger":
			var tgt := str(a["tgt"])
			if _pos.has(tgt):
				var bi := 0 if _bludgers[0].distance_to(_pos[tgt]) <= _bludgers[1].distance_to(_pos[tgt]) else 1
				_bl_victim[bi] = tgt
				_bl_boost[bi] = 0.8
				_bludger_timer[bi] = 2.5
			if bool(a.get("hit", false)):
				_caption_set(tr("match.caption.bludger") % _name(tgt), Color("#F0C9B8"), 1.4)
				if _pos.has(tgt):
					_burst(_pos[tgt], [Color("#2A2A2A"), Color("#F0C9B8")], 8, 0.25)
		"snitch_sighted":
			var seer: Vector2 = _pos.get(str(a["pid"]), Vector2(0.5, 0.5))
			_snitch = (seer + Vector2(randf_range(-0.12, 0.12), randf_range(-0.1, 0.1))).clamp(Vector2(0.1, 0.12), Vector2(0.9, 0.88))
			_snitch_vel = Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
			_snitch_visible = true
		"snitch_lost":
			_snitch_visible = false
	match str(a["kind"]):
		KIND_CATCH:
			_snitch_visible = true
			_catch_hand = str(a["pid"])
	if a.has("caption"):
		_caption_from(a)
	if a.has("after"):
		if defer:
			_act["after"] = a["after"]
		else:
			_apply_after(a["after"])
			_hold_target.clear()
			_recv = ""
			_place_ball(0.0)


func _start_key_play(a: Dictionary) -> void:
	var pid := str(a["pid"])
	var side := str(a["side"])
	_play_start = maxi(0, _history.size() - REPLAY_PREROLL)
	_hist_acc = 0.0
	if str(a["kind"]) == KIND_GOAL:
		_anim = {"kind": KIND_GOAL, "t": 0.0, "dur": 1.0, "hold": 1.1, "from": _quaffle, "side": side, "hoop": int(a["hoop"]), "pid": pid, "burst": false,
			"after": a["after"], "label": str(a["label"])}
		_vis_carrier = ""
	else:
		_snitch_visible = true
		var from_c: Vector2 = _pos.get(pid, Vector2(0.5, 0.5))
		if _snitch.distance_to(from_c) < 0.15:
			_snitch = _inside(from_c + Vector2(0.18 if from_c.x < 0.5 else -0.18, -0.12))
		_anim = {"kind": KIND_CATCH, "t": 0.0, "dur": 1.1, "hold": 1.8, "from": from_c, "pid": pid, "side": side, "burst": false, "label": str(a["label"])}
	_caption_from(a)
	_update_busy()


func _reconcile() -> void:
	var want := sim.carrier.id if sim.carrier != null and _pos.has(sim.carrier.id) else ""
	var side := "" if sim.poss == null else ("home" if sim.poss == sim.home else "away")
	if want != _vis_carrier and want != "":
		_push({"kind": KIND_LOOSE, "to_pid": want, "lead": 0.03, "after": _after(side, sim.zone, want)})
		return
	if side != _vis_side or clampi(sim.zone, MatchEvent.Zone.OWN, MatchEvent.Zone.ATTACK) != _vis_zone:
		_vis_side = side
		_vis_zone = clampi(sim.zone, MatchEvent.Zone.OWN, MatchEvent.Zone.ATTACK)
	if want == "" and _vis_carrier != "":
		_vis_carrier = ""


func _place_ball(vd: float) -> void:
	if str(_anim.get("kind", "")) == KIND_GOAL:
		return
	if not _act.is_empty() and _act.has("to"):
		var u := clampf(float(_act["t"]) / maxf(float(_act["dur"]), 0.001), 0.0, 1.0)
		var p: Vector2 = (_act["from"] as Vector2).lerp(_act["to"], u)
		var to_pid := str(_act.get("to_pid", ""))
		if _pos.has(to_pid):
			var blend := smoothstep(0.65, 1.0, u)
			p = p.lerp(_hand(to_pid), blend)
		_quaffle = p
	elif _pos.has(_vis_carrier):
		_quaffle = _hand(_vis_carrier)
	else:
		_quaffle = _quaffle.move_toward(_qa, 0.3 * vd)


func _hand(pid: String) -> Vector2:
	var p: Vector2 = _pos[pid]
	var r := _rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return p
	var sc := _s()
	var f := float(_facing.get(pid, 1 if _team_of[pid] == "home" else -1))
	return p + Vector2(8.5 * f * sc / r.size.x, -2.0 * sc / r.size.y)


func _move_players(delta: float, skip: String = "") -> void:
	for pid in _pos.keys():
		if pid == skip:
			continue
		var sp: SimPlayer = _slot[pid]
		var key: String = "S_chase" if sp.position == "S" and sim.snitch_state == MatchSim.SnitchState.CHASE else sp.position
		var spd: float = float(SPEED.get(key, 0.4))
		if _vis_carrier == pid:
			spd *= 0.9
		var before: Vector2 = _pos[pid]
		_pos[pid] = _approach(before, _target[pid], spd, delta)
		var dx: float = _pos[pid].x - before.x
		if absf(dx) > 0.0004:
			_facing[pid] = 1 if dx > 0 else -1


func _approach(from: Vector2, to: Vector2, speed: float, delta: float) -> Vector2:
	var d := from.distance_to(to)
	if d < 0.0005:
		return to
	var v := minf(speed, d * 5.0)
	return from.move_toward(to, v * delta)


func _quaffle_anchor() -> Vector2:
	if sim == null or _vis_side == "":
		return Vector2(0.5, 0.5)
	var x: float = [0.28, 0.5, 0.72][clampi(_vis_zone, 0, 2)]
	var y := 0.5
	var lane_pid := _vis_carrier
	if lane_pid == "":
		var tp := str(_act.get("to_pid", ""))
		if _slot.has(tp) and _team_of[tp] == _vis_side and _slot[tp].position == "C":
			lane_pid = tp
	if _slot.has(lane_pid):
		var sp: SimPlayer = _slot[lane_pid]
		if sp.position == "C":
			y += [0.0, -0.14, 0.14][_chaser_index(sp)]
		elif sp.position == "K":
			x = 0.12
	return _mirror(_vis_side, Vector2(x, y))


func _retarget() -> void:
	var qa := _qa
	var poss_side: String = _vis_side
	for pid in _pos.keys():
		var sp: SimPlayer = _slot[pid]
		var side: String = _team_of[pid]
		var ph: float = _seed_phase[pid]
		var wob := Vector2(sin(_t * 0.9 + ph), cos(_t * 0.7 + ph * 1.3)) * 0.015
		if not sp.is_active():
			_target[pid] = _inside(_mirror(side, Vector2(0.04, 0.92 if sp.position != "K" else 0.5)))
			continue
		if _hold_target.has(pid):
			_target[pid] = _hold_target[pid]
			continue
		var q: Vector2 = _mirror(side, qa)
		var t := Vector2.ZERO
		match sp.position:
			"K":
				var near := clampf(1.0 - (q.x - 0.1) / 0.5, 0.0, 1.0)
				t = Vector2(0.08 + 0.05 * near * (1.0 if _vis_carrier != pid else 0.0), 0.5 + (q.y - 0.5) * 0.6 * near)
				if _vis_carrier == pid:
					t = Vector2(0.12, 0.5)
				t += wob * 0.3
			"C":
				var idx := _chaser_index(sp)
				if side == poss_side:
					if _vis_carrier == pid:
						t = q
					else:
						var order := _support_order(sp)
						t = [Vector2(q.x + 0.05, q.y - 0.19), Vector2(q.x - 0.03, q.y + 0.19)][order]
						t.y = clampf(t.y, 0.12, 0.88)
				else:
					t = [Vector2(q.x - 0.05, q.y), Vector2(q.x - 0.1, q.y - 0.16), Vector2(q.x - 0.1, q.y + 0.16)][idx]
				t += wob
			"B":
				var bidx := _beater_index(sp)
				var bt: Vector2 = _mirror(side, _bludgers[bidx])
				t = bt + Vector2(-0.05, -0.04 if side == "home" else 0.04) + wob * 0.6
			"S":
				if sim.snitch_state == MatchSim.SnitchState.CHASE and _snitch_visible:
					t = _mirror(side, _snitch) + wob * 0.2
				else:
					var band := 0.16 if side == "home" else 0.84
					t = Vector2(0.5 + 0.22 * sin(_t * 0.18 + ph), band + 0.05 * cos(_t * 0.3 + ph))
		_target[pid] = _inside(_mirror(side, t))
	if sim.snitch_state != MatchSim.SnitchState.CHASE and not sim.ended and _anim.is_empty():
		_snitch_visible = false


func _step_bludgers(delta: float) -> void:
	for i in 2:
		_bludger_timer[i] -= delta
		_bl_boost[i] = maxf(0.0, float(_bl_boost[i]) - delta)
		var victim: String = _bl_victim[i]
		if _bludger_timer[i] <= 0.0 or victim == "" or not _pos.has(victim):
			var near: Array = []
			for pid in _pos.keys():
				var sp: SimPlayer = _slot[pid]
				if sp.is_active() and sp.position != "B" and _pos[pid].distance_to(_qa) < 0.3:
					near.append(pid)
			if near.is_empty():
				near = _pos.keys()
			_bl_victim[i] = near[randi() % near.size()]
			_bludger_timer[i] = randf_range(2.0, 4.0)
		var tgt: Vector2 = _inside(_pos[_bl_victim[i]] + Vector2(sin(_t * 1.7 + i), cos(_t * 1.3 + i)) * 0.03)
		_bludger_t[i] = tgt
		var spd := BLUDGER_SPEED * (2.2 if float(_bl_boost[i]) > 0.0 else 1.0)
		_bludgers[i] = _approach(_bludgers[i], tgt, spd, delta)


func _step_snitch(delta: float) -> void:
	if not _snitch_visible or _catch_hand != "" or not _anim.is_empty():
		return
	_snitch_vel += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.9 * delta
	_snitch_vel = _snitch_vel.limit_length(0.32)
	_snitch += _snitch_vel * delta
	if _snitch.x < 0.08 or _snitch.x > 0.92:
		_snitch_vel.x *= -1.0
	if _snitch.y < 0.1 or _snitch.y > 0.9:
		_snitch_vel.y *= -1.0
	_snitch = _inside(_snitch.clamp(Vector2(0.08, 0.1), Vector2(0.92, 0.9)))


func _support_order(sp: SimPlayer) -> int:
	var t: SimTeam = sim.home if _team_of[sp.id] == "home" else sim.away
	var i := 0
	for q in t.players:
		if q.position == "C" and q.id != _vis_carrier and q.id != _recv:
			if q == sp:
				return mini(i, 1)
			i += 1
	return 0


func _chaser_index(sp: SimPlayer) -> int:
	var t: SimTeam = sim.home if _team_of[sp.id] == "home" else sim.away
	var i := 0
	for q in t.players:
		if q.position == "C":
			if q == sp:
				return i
			i += 1
	return 0


func _beater_index(sp: SimPlayer) -> int:
	var t: SimTeam = sim.home if _team_of[sp.id] == "home" else sim.away
	var i := 0
	for q in t.players:
		if q.position == "B":
			if q == sp:
				return i
			i += 1
	return 0


## Skip to the end (simulate to the end): discards pending animations and replays, marks every event as seen (the
## pitch does not replay what already happened) and shows the final picture (catch_up).
func jump_to_end() -> void:
	_caption = ""
	catch_up()


func _step_anim(delta: float) -> void:
	_anim["t"] = float(_anim["t"]) + delta
	var t: float = float(_anim["t"])
	var dur: float = float(_anim["dur"])
	var pid := str(_anim.get("pid", ""))
	var k := 1.0 - exp(-delta * 5.0)
	match str(_anim["kind"]):
		KIND_GOAL:
			var hoop := _hoop_norm(str(_anim["side"]), int(_anim["hoop"]))
			var u := clampf(t / dur, 0.0, 1.0)
			var a: Vector2 = _anim["from"]
			var ctrl := a.lerp(hoop, 0.5) + Vector2(0, -0.22)
			_quaffle = a.lerp(ctrl, u).lerp(ctrl.lerp(hoop, u), u)
			if _pos.has(pid):
				_pos[pid] = _pos[pid].lerp(a.lerp(hoop, 0.35), k)
			if u >= 1.0 and not bool(_anim["burst"]):
				_anim["burst"] = true
				_flash = 0.8
				var club: Club = home_club if str(_anim["side"]) == "home" else away_club
				var cols := [ThemeBuilder.GOLD, Color.WHITE]
				if club != null:
					cols = [ThemeBuilder.hex(str(club.colors.get("primary", "#D4AF37"))), ThemeBuilder.hex(str(club.colors.get("secondary", "#FFFFFF"))), ThemeBuilder.GOLD]
				_burst(hoop, cols, 46, 0.55)
		KIND_CATCH:
			var u := clampf(t / dur, 0.0, 1.0)
			if _pos.has(pid):
				_pos[pid] = (_anim["from"] as Vector2).lerp(_snitch, u * u)
			_snitch += Vector2(sin(_t * 9.0), cos(_t * 7.0)) * 0.002 * (1.0 - u)
			if u >= 1.0 and not bool(_anim["burst"]):
				_anim["burst"] = true
				_flash = 1.2
				_catch_hand = pid
				_burst(_snitch, [ThemeBuilder.GOLD, Color("#FFF3B0"), Color.WHITE], 70, 0.7)
	if t >= dur + float(_anim["hold"]):
		_finish_anim()


func _finish_anim() -> void:
	var a := _anim
	_anim = {}
	if str(a.get("kind", "")) == KIND_CATCH:
		_catch_hand = str(a.get("pid", ""))
		_snitch_visible = true
	if a.has("after"):
		_apply_after(a["after"])
	if _history.size() - _play_start > 30:
		_last_play = _history.slice(_play_start)
		_last_play_label = str(a.get("label", ""))
		if bool(Game.world.settings.get("match_replays", true)):
			_pending_replay = {"frames": _last_play, "label": _last_play_label, "delay": 0.2}
	_history.clear()
	_update_busy()


func _stand_w() -> float:
	var t := clampf((log(maxf(capacity, 2500.0)) - log(2500.0)) / (log(100000.0) - log(2500.0)), 0.0, 1.0)
	return lerpf(14.0, 50.0, t) * minf(_k(), 1.6)


func _rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-4 - _stand_w())


func _hoop_norm(side: String, idx: int) -> Vector2:
	var r := _rect()
	var rad := r.size.y / 2.0
	var gx_px := r.size.x / 2.0 + (r.size.x / 2.0 - rad * 0.55)
	var v := Vector2(gx_px / r.size.x, (rad + (idx - 1) * rad * 0.5) / r.size.y)
	return v if side == "home" else Vector2(1.0 - v.x, v.y)


func _burst(at: Vector2, cols: Array, n: int, speed: float) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(0.2, 1.0) * speed
		var life := randf_range(0.6, 1.3)
		_particles.append(Particle.new(at, Vector2(cos(a), sin(a) * 1.6) * sp, life, cols[i % cols.size()], randf_range(1.5, 3.5)))


func _step_particles(delta: float) -> void:
	var keep: Array[Particle] = []
	for pt in _particles:
		pt.life -= delta
		if pt.life <= 0.0:
			continue
		pt.v = pt.v * (1.0 - delta * 1.8) + Vector2(0, 0.25 * delta)
		pt.p += pt.v * delta
		keep.append(pt)
	_particles = keep


func _name(pid: String) -> String:
	if _slot.has(pid):
		var parts: PackedStringArray = str(_slot[pid].name).split(" ")
		return parts[parts.size() - 1]
	return ""


func _caption_set(s: String, c: Color, ttl: float) -> void:
	_caption = s
	_caption_color = c
	_caption_ttl = ttl


func _k() -> float:
	return clampf(size.y / 300.0, 1.0, 2.2)


func _refresh_stands() -> void:
	if _stands != null and size.x > 0.0:
		_stands.configure(capacity, fill, home_club, away_club, _rect(), _stand_w())


func _draw() -> void:
	var r := _rect()
	var rad := r.size.y / 2.0
	var k := _k()
	var sc := _s()
	var wx := _weather()
	var grass := Color("#5F7E40")
	var grass_dark := Color("#587740")
	var line := Color(1, 1, 1, 0.55)
	match wx:
		"snow":
			grass = Color("#EEF2F4")
			grass_dark = Color("#E4EAEE")
			line = Color("#8FA3B5", 0.8)
		"rain", "storm":
			grass = Color("#50693A")
			grass_dark = Color("#4A6236")
	_draw_oval_rect(r, grass)
	var stripes := 12
	var straight := r.size.x - 2.0 * rad
	for i in stripes:
		if i % 2 == 1:
			var x0 := r.position.x + rad + straight * i / stripes
			draw_rect(Rect2(x0, r.position.y, straight / stripes, r.size.y), grass_dark)
	var cx := r.position.x + r.size.x / 2.0
	var cy := r.position.y + rad
	draw_line(Vector2(cx, r.position.y), Vector2(cx, r.end.y), line, 1.2, true)
	draw_arc(Vector2(cx, cy), rad * 0.32, 0, TAU, 64, line, 1.2, true)
	draw_circle(Vector2(cx, cy), 2.0, line)
	for sidef: float in [-1.0, 1.0]:
		var gx: float = cx + sidef * (r.size.x / 2.0 - rad * 0.55)
		var a0 := -PI / 2.0 if sidef < 0.0 else PI / 2.0
		draw_arc(Vector2(gx, cy), rad * 0.62, a0, a0 + PI, 48, line, 1.2, true)
		for i in 3:
			var hy := cy + (i - 1) * rad * 0.5
			var hr := (5.0 if i == 1 else 4.2) * sc
			var hp := Vector2(gx, hy)
			draw_circle(hp + Vector2(2.0, 3.0) * sc, hr * 0.55, Color(0, 0, 0, 0.22))
			draw_arc(hp, hr, 0, TAU, 24, Color("#B8922E"), 2.2 * sc, true)
			draw_arc(hp, hr, 0, TAU, 24, ThemeBuilder.GOLD, 1.2 * sc, true)
			draw_circle(hp, 1.3 * sc, Color("#6B5218"))
	if sim == null:
		return
	var frame: Dictionary = {}
	if is_replaying():
		frame = _replay[clampi(int(_replay_i), 0, _replay.size() - 1)]
	var pos_src: Dictionary = frame.get("pos", _pos)
	var facing_src: Dictionary = frame.get("facing", _facing)
	var q_src: Vector2 = frame.get("quaffle", _quaffle)
	var b_src: Array = frame.get("bludgers", _bludgers)
	var holder: String = str(frame.get("holder", _vis_carrier))
	var lit := Vector2(-1.0, -1.0)
	var since := 0.0
	if is_replaying():
		if frame.has("hoop"):
			lit = frame["hoop"]
			since = float(frame.get("since", 0.0))
	elif str(_anim.get("kind", "")) == KIND_GOAL and bool(_anim.get("burst", false)):
		lit = _hoop_norm(str(_anim["side"]), int(_anim["hoop"]))
		since = float(_anim["t"]) - float(_anim["dur"])
	if lit.x >= 0.0:
		var hp := _to_px(r, lit)
		for ring in 3:
			var rr := (8.0 + since * 60.0 + ring * 12.0) * sc
			var al := clampf(1.0 - since * 0.9 - ring * 0.2, 0.0, 1.0)
			draw_arc(hp, rr, 0, TAU, 40, Color(ThemeBuilder.GOLD, al), 2.5 * sc, true)
		draw_circle(hp, 7.0 * sc, Color(1, 0.95, 0.6, clampf(1.0 - since, 0.0, 1.0)))
	for pid in pos_src.keys():
		var sp: SimPlayer = _slot[pid]
		var p := _to_px(r, pos_src[pid])
		var alt := 1.6 if sp.position == "S" else 1.0
		draw_circle(p + Vector2(4.0, 6.0) * sc * alt, 7.5 * sc, Color(0, 0, 0, 0.22 / alt))
	for pid in pos_src.keys():
		var sp: SimPlayer = _slot[pid]
		var club: Club = home_club if _team_of[pid] == "home" else away_club
		var pc := ThemeBuilder.hex(str(club.colors.get("primary", "#888"))) if club else ThemeBuilder.BORDER_CONTROL
		var scol := ThemeBuilder.hex(str(club.colors.get("secondary", "#ddd"))) if club else ThemeBuilder.BRASS
		var p := _to_px(r, pos_src[pid])
		var dir: int = int(facing_src.get(pid, 1 if _team_of[pid] == "home" else -1))
		var active := sp.is_active()
		if not is_replaying() and _recv == pid and holder == "":
			draw_arc(p, 11.5 * sc, 0, TAU, 32, Color(ThemeBuilder.GOLD, 0.45), 1.2 * sc, true)
		_draw_token(p, dir, pc, scol, sp.position, active, holder == pid, sc)
	for b in b_src:
		var bp := _to_px(r, b)
		draw_circle(bp + Vector2(2.0, 3.0) * sc, 3.4 * sc, Color(0, 0, 0, 0.25))
		draw_circle(bp, 3.6 * sc, Color("#1B1B1B"))
		draw_arc(bp, 3.6 * sc, 0, TAU, 16, Color("#555555"), 1.0, true)
		draw_circle(bp + Vector2(-1.2, -1.2) * sc, 1.0 * sc, Color("#8A8A8A"))
	_draw_quaffle(_to_px(r, q_src), sc)
	var sn_on := _snitch_visible
	var sn_at := _snitch
	var hand := _catch_hand
	if is_replaying():
		sn_on = bool(frame.get("snitch_on", false))
		sn_at = frame.get("snitch", _snitch)
		hand = str(frame.get("hand", ""))
	if sn_on:
		var spx := _to_px(r, sn_at)
		if hand != "" and pos_src.has(hand):
			spx = _to_px(r, pos_src[hand]) + Vector2(7.0, -7.0) * sc
		draw_circle(spx, 6.0 * sc, Color(1, 0.9, 0.4, 0.16 + 0.08 * sin(_t * 6.0)))
		var wing := (3.0 + 1.2 * sin(_t * 30.0)) * sc
		draw_line(spx + Vector2(-2.0 * sc, 0), spx + Vector2(-2.0 * sc - wing, -2.0 * sc), Color(1, 1, 0.9, 0.9), 1.2, true)
		draw_line(spx + Vector2(2.0 * sc, 0), spx + Vector2(2.0 * sc + wing, -2.0 * sc), Color(1, 1, 0.9, 0.9), 1.2, true)
		draw_circle(spx, 2.4 * sc, ThemeBuilder.GOLD)
		draw_circle(spx + Vector2(-0.7, -0.7) * sc, 0.8 * sc, Color(1, 1, 0.85))
	for pt in _particles:
		var al: float = clampf(pt.life / pt.max_life, 0.0, 1.0)
		draw_circle(_to_px(r, pt.p), pt.r, Color(pt.c, al))
	_draw_weather(r)
	if _flash > 0.0:
		_draw_oval_rect(r, Color(1, 0.95, 0.6, 0.22 * minf(_flash, 1.0)))
	if not _anim.is_empty():
		var big := tr("match.caption.big_goal") if str(_anim["kind"]) == KIND_GOAL else tr("match.caption.big_catch")
		var fb := ThemeBuilder.font("title")
		var bs := int(40 * minf(k, 1.5))
		var bw := fb.get_string_size(big, HORIZONTAL_ALIGNMENT_CENTER, -1, bs).x
		var club: Club = home_club if str(_anim.get("side", "home")) == "home" else away_club
		var bc := ThemeBuilder.hex(str(club.colors.get("primary", "#3A2A1C"))) if club else ThemeBuilder.WOOD
		var ap: float = clampf(float(_anim["t"]) * 3.0, 0.0, 1.0)
		var cy2 := r.position.y + r.size.y * 0.2
		var br := Rect2(cx - bw / 2.0 - 26, cy2 - bs + 2, bw + 52, bs + 18)
		draw_rect(Rect2(br.position + Vector2(3, 4), br.size), Color(0, 0, 0, 0.25 * ap))
		draw_rect(br, Color(ThemeBuilder.CARD, 0.96 * ap))
		draw_rect(br.grow(-4.0), Color(ThemeBuilder.BORDER_CONTROL, ap), false, 1.0)
		draw_rect(br, Color(ThemeBuilder.GOLD, ap), false, 2.0)
		draw_rect(Rect2(br.position.x, br.position.y - 5, br.size.x, 5), Color(bc, ap))
		draw_rect(Rect2(br.position.x, br.end.y, br.size.x, 5), Color(bc, ap))
		var ink := ThemeBuilder.BRONZE_TEXT if str(_anim["kind"]) == KIND_CATCH else ThemeBuilder.INK
		draw_string(fb, Vector2(cx - bw / 2.0, cy2 + 6), big, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(ink, ap))
	if is_replaying():
		var f3 := ThemeBuilder.font("label")
		draw_rect(Rect2(r.position + Vector2(10, 10), Vector2(f3.get_string_size(_replay_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16, 22)), Color(ThemeBuilder.SEALING_WAX, 0.85))
		draw_string(f3, r.position + Vector2(18, 26), _replay_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if _caption_ttl > 0.0 and _caption != "":
		var f2 := ThemeBuilder.font("title")
		var fs := int(22 * minf(k, 1.5))
		var w := f2.get_string_size(_caption, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var y := r.end.y - 14
		var a := clampf(_caption_ttl * 2.0, 0.0, 1.0)
		draw_rect(Rect2(cx - w / 2.0 - 12, y - fs - 4, w + 24, fs + 12), Color(ThemeBuilder.WOOD, 0.75 * a))
		draw_string(f2, Vector2(cx - w / 2.0, y), _caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(_caption_color, a))


func _s() -> float:
	return clampf(size.y / 450.0, 0.75, 1.4)


func _draw_token(p: Vector2, dir: int, pc: Color, scol: Color, pos: String, active: bool, has_quaffle: bool, sc: float) -> void:
	var d := float(dir)
	var R := 8.5 * sc
	if not active:
		pc = pc.darkened(0.45).lerp(Color.GRAY, 0.4)
		scol = scol.darkened(0.3)
	var tail := p + Vector2(-R - 8.0 * sc, 1.5 * sc) * Vector2(d, 1.0)
	draw_line(p + Vector2(-R * 0.6 * d, 1.5 * sc), tail, Color("#6B4A1E"), 2.0 * sc, true)
	for i in 3:
		draw_line(tail, tail + Vector2(-4.0 * sc * d, (i - 1) * 2.2 * sc), Color("#C9A24A"), 1.2 * sc, true)
	if has_quaffle:
		draw_circle(p, R + 3.5 * sc, Color(ThemeBuilder.GOLD, 0.35 + 0.15 * sin(_t * 8.0)))
		draw_arc(p, R + 3.0 * sc, 0, TAU, 32, ThemeBuilder.GOLD, 1.5 * sc, true)
	draw_circle(p, R, scol)
	draw_circle(p, R - 1.6 * sc, pc)
	var f := ThemeBuilder.font("ui_bold")
	var letter := UI.pos_short(pos)
	var fs := int(round((10.0 if letter.length() < 2 else 8.0) * sc))
	var ts := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(f, p + Vector2(-ts.x / 2.0, ts.y * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ThemeBuilder.text_on(pc))
	if not active:
		draw_line(p + Vector2(-R, -R) * 0.7, p + Vector2(R, R) * 0.7, Color("#C62828"), 1.8 * sc, true)
		draw_line(p + Vector2(-R, R) * 0.7, p + Vector2(R, -R) * 0.7, Color("#C62828"), 1.8 * sc, true)


func _draw_quaffle(p: Vector2, sc: float) -> void:
	draw_circle(p + Vector2(1.5, 2.5) * sc, 4.0 * sc, Color(0, 0, 0, 0.25))
	draw_circle(p, 4.2 * sc, Color("#C0262B"))
	draw_arc(p, 4.2 * sc, 0, TAU, 20, Color("#7A1418"), 1.0, true)
	draw_arc(p, 2.6 * sc, -0.6, 1.2, 8, Color("#7A1418"), 0.8, true)
	draw_circle(p + Vector2(-1.4, -1.4) * sc, 1.1 * sc, Color("#F08A8A"))


func _to_px(r: Rect2, v: Vector2) -> Vector2:
	return r.position + Vector2(v.x * r.size.x, v.y * r.size.y)


func _weather() -> String:
	return sim.weather if sim != null else "clear"


func _step_weather(delta: float) -> void:
	var wx := _weather()
	var want: int = int({"rain": 160, "storm": 260, "snow": 210, "wind": 36}.get(wx, 0))
	while _wx.size() < want:
		_wx.append({"p": Vector2(randf(), randf()), "s": randf_range(0.7, 1.3), "ph": randf() * TAU})
	if _wx.size() > want:
		_wx.resize(want)
	for d in _wx:
		var p: Vector2 = d["p"]
		var sp: float = float(d["s"])
		match wx:
			"rain":
				p += Vector2(-0.12, 1.1) * sp * delta
			"storm":
				p += Vector2(-0.3, 1.5) * sp * delta
			"snow":
				p += Vector2(0.03 * sin(_t * 1.5 + float(d["ph"])), 0.12 * sp) * delta
			"wind":
				p += Vector2(0.9 * sp, 0.05 * sin(_t + float(d["ph"]))) * delta
		if p.y > 1.02:
			p = Vector2(randf(), -0.02)
		if p.x < -0.02:
			p.x = 1.02
		elif p.x > 1.02:
			p.x = -0.02
		d["p"] = p
	if wx == "storm":
		_lightning = maxf(0.0, _lightning - delta * 2.5)
		_lightning_next -= delta
		if _lightning_next <= 0.0:
			_lightning = 1.0
			_lightning_next = randf_range(4.0, 9.0)


func _draw_weather(_pitch: Rect2) -> void:
	var r := Rect2(Vector2.ZERO, size)
	var wx := _weather()
	match wx:
		"rain", "storm":
			var c := Color(0.82, 0.88, 0.95, 0.45 if wx == "rain" else 0.55)
			var dirv := Vector2(-0.12, 1.1).normalized() if wx == "rain" else Vector2(-0.3, 1.5).normalized()
			for d in _wx:
				var p := _to_px(r, d["p"])
				draw_line(p, p + dirv * (9.0 if wx == "rain" else 13.0) * float(d["s"]), c, 1.2)
			draw_rect(r, Color(0.1, 0.12, 0.18, 0.12 if wx == "rain" else 0.2))
			if _lightning > 0.0:
				draw_rect(r, Color(0.92, 0.95, 1.0, 0.45 * _lightning))
		"snow":
			for d in _wx:
				draw_circle(_to_px(r, d["p"]), 1.6 + 1.2 * float(d["s"]), Color(1, 1, 1, 0.85))
		"fog":
			draw_rect(r, Color(0.92, 0.93, 0.9, 0.34))
			for i in 5:
				var x := fmod(_t * 0.012 * (1.0 + 0.3 * i) + i * 0.23, 1.4) - 0.2
				var c := _to_px(r, Vector2(x, 0.15 + 0.18 * i))
				for k in 6:
					var f := 1.0 - k / 6.0
					var rad := Vector2(r.size.x * 0.28, r.size.y * 0.12) * f
					draw_set_transform(c, 0.0, Vector2(rad.x / maxf(rad.y, 1.0), 1.0))
					draw_circle(Vector2.ZERO, rad.y, Color(0.96, 0.96, 0.94, 0.035))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"wind":
			for d in _wx:
				var p := _to_px(r, d["p"])
				draw_line(p, p + Vector2(26.0 * float(d["s"]), 0), Color(1, 1, 1, 0.22), 1.0)


func _draw_oval(r: Rect2, c: Color) -> void:
	_draw_oval_rect(r, c)


func _in_oval(r: Rect2, v: Vector2) -> bool:
	var p := _to_px(r, v)
	var rad := r.size.y / 2.0
	if p.x >= r.position.x + rad and p.x <= r.end.x - rad:
		return p.y >= r.position.y and p.y <= r.end.y
	var c := Vector2(r.position.x + rad, r.position.y + rad) if p.x < r.position.x + rad else Vector2(r.end.x - rad, r.position.y + rad)
	return p.distance_to(c) <= rad


func _inside(v: Vector2) -> Vector2:
	v = v.clamp(Vector2(0.03, 0.06), Vector2(0.97, 0.94))
	var r := _rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return v
	var rad := r.size.y / 2.0
	var p := _to_px(r, v)
	var c := Vector2.ZERO
	if p.x < r.position.x + rad:
		c = Vector2(r.position.x + rad, r.position.y + rad)
	elif p.x > r.end.x - rad:
		c = Vector2(r.end.x - rad, r.position.y + rad)
	else:
		return v
	var lim := maxf(rad - 12.0 * _s(), rad * 0.5)
	var d := p - c
	if d.length() <= lim:
		return v
	p = c + d.normalized() * lim
	return Vector2((p.x - r.position.x) / r.size.x, (p.y - r.position.y) / r.size.y)


func _oval_pts(r: Rect2) -> PackedVector2Array:
	var rad := r.size.y / 2.0
	var pts := PackedVector2Array()
	for i in 25:
		var a := PI / 2.0 + PI * i / 24.0
		pts.append(r.position + Vector2(rad, rad) + Vector2(cos(a), sin(a)) * rad)
	for i in 25:
		var a := -PI / 2.0 + PI * i / 24.0
		pts.append(r.position + Vector2(r.size.x - rad, rad) + Vector2(cos(a), sin(a)) * rad)
	return pts


func _draw_oval_rect(r: Rect2, c: Color) -> void:
	draw_colored_polygon(_oval_pts(r), c)


func _draw_oval_outline(r: Rect2, c: Color, width: float) -> void:
	var pts := _oval_pts(r)
	pts.append(pts[0])
	draw_polyline(pts, c, width, true)


func _oval_point(r: Rect2, u: float, off: float) -> Vector2:
	var rad := r.size.y / 2.0
	var straight := r.size.x - 2.0 * rad
	var arc := PI * rad
	var total := 2.0 * straight + 2.0 * arc
	var d := u * total
	if d < straight:
		return Vector2(r.position.x + rad + d, r.position.y - off)
	d -= straight
	if d < arc:
		var a := -PI / 2.0 + d / rad
		return Vector2(r.end.x - rad, r.position.y + rad) + Vector2(cos(a), sin(a)) * (rad + off)
	d -= arc
	if d < straight:
		return Vector2(r.end.x - rad - d, r.end.y + off)
	d -= straight
	var a2 := PI / 2.0 + d / rad
	return Vector2(r.position.x + rad, r.position.y + rad) + Vector2(cos(a2), sin(a2)) * (rad + off)

