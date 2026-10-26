class_name TeamTalk  # [game]
extends RefCounted

const TONES := ["calm", "encourage", "demand", "angry"]


## Applies the talk. Returns {"good": [names], "bad": [names], "neutral": [names], "summary_key": ...}.
static func apply(team: SimTeam, tone: String, score_diff: int, pre_match: bool, seed_value: int) -> Dictionary:
	var rng := SimRng.new(seed_value)
	var good: Array = []
	var bad: Array = []
	var neutral: Array = []
	for sp in team.players:
		var prof := (sp.hid("professionalism") - 10.0) / 10.0
		var temp := (sp.hid("temperament") - 10.0) / 10.0
		var pres := (sp.hid("pressure") - 10.0) / 10.0
		var det := (sp.raw("determination") - 10.0) / 10.0
		var delta := 0.0
		match tone:
			"calm":
				delta = 0.015 - 0.02 * pres + (0.01 if score_diff > 0 else -0.005)
			"encourage":
				delta = 0.02 + 0.01 * temp - 0.005 * prof + (0.015 if score_diff < 0 else 0.0)
			"demand":
				delta = 0.01 + 0.025 * prof + 0.015 * det - 0.03 * maxf(temp, 0.0) - (0.02 if score_diff < -100 else 0.0)
			"angry":
				if score_diff < -50 or (not pre_match and score_diff < 0):
					delta = 0.02 * prof + 0.015 * det - 0.025 * maxf(temp, 0.0) - 0.01 * pres
				else:
					delta = -0.03 - 0.01 * maxf(temp, 0.0)
		delta += rng.gauss(0.0, 0.008)
		delta = clampf(delta, -0.04, 0.04)
		for k in sp.attrs.keys():
			sp.attrs[k] = float(sp.attrs[k]) * (1.0 + delta)
		if delta > 0.01:
			good.append(sp.name)
		elif delta < -0.01:
			bad.append(sp.name)
		else:
			neutral.append(sp.name)
	var key := "talk.result.mixed"
	if good.size() >= 5:
		key = "talk.result.great"
	elif bad.size() >= 4:
		key = "talk.result.bad"
	elif good.size() > bad.size():
		key = "talk.result.good"
	return {"good": good, "bad": bad, "neutral": neutral, "summary_key": key}


## Post-match talk: moves squad morale based on tone, result and personality.
## One per match. Returns {"summary_key", "good", "bad"}.
static func post_match(w: World, club: Club, tone: String, my_score: int, their_score: int, seed_value: int) -> Dictionary:
	var rng := SimRng.new(seed_value)
	var diff := my_score - their_score
	var good: Array = []
	var bad: Array = []
	for p in w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
		var prof := (p.hid("professionalism") - 10.0) / 10.0
		var temp := (p.hid("temperament") - 10.0) / 10.0
		var d := 0.0
		match tone:
			"calm":
				d = 1.5 if diff < 0 else 0.5
			"encourage":
				d = (4.0 if diff > 0 else (2.0 if diff > -100 else -1.0)) + 1.5 * temp
			"demand":
				d = (-1.0 if diff > 100 else 2.0) + 3.0 * prof - 3.0 * maxf(temp, 0.0)
			"angry":
				d = (-5.0 if diff >= 0 else (2.0 * prof + 1.0 - 3.0 * maxf(temp, 0.0))) if diff > -150 or prof > 0.2 else -2.0
		d += rng.gauss(0.0, 1.0)
		p.morale = clampf(p.morale + d, 0.0, 100.0)
		if d > 1.5:
			good.append(p.name())
		elif d < -1.5:
			bad.append(p.name())
	var key := "talk.result.mixed"
	if good.size() >= 7:
		key = "talk.result.great"
	elif bad.size() >= 5:
		key = "talk.result.bad"
	elif good.size() > bad.size():
		key = "talk.result.good"
	return {"summary_key": key, "good": good, "bad": bad}


## The most all the talks of one match together can move a player's attributes.
const MATCH_CAP := 0.04


## Keeps the combined effect of every talk of the match within ±MATCH_CAP per player: `before` holds each player's
## attributes just before this talk (player id -> attrs).
static func cap_effect(team: SimTeam, before: Dictionary) -> void:
	for sp in team.players:
		if not before.has(sp.id):
			continue
		var prev: Dictionary = before[sp.id]
		var factor := 1.0
		for k in prev.keys():
			if float(prev[k]) > 0.0:
				factor = float(sp.attrs[k]) / float(prev[k])
				break
		var old_m: float = team.talk_mult.get(sp.id, 1.0)
		var new_m := clampf(old_m * factor, 1.0 - MATCH_CAP, 1.0 + MATCH_CAP)
		for k in prev.keys():
			sp.attrs[k] = float(prev[k]) * new_m / old_m
		team.talk_mult[sp.id] = new_m
