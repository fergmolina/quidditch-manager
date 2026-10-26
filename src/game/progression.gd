class_name Progression
extends RefCounted
## Attribute progression and decline, condition, injuries and morale.
## Every draw comes from the SimRng passed in, so it is reproducible.

const TRAINING := {
	"physical": ["stamina", "strength", "natural_fitness", "work_rate"],
	"flying": ["speed", "acceleration", "agility", "broom_control", "balance", "altitude", "dive"],
	"quaffle": ["passing", "catching", "shooting", "dodging", "stealing", "interception", "creativity"],
	"beating": ["beating", "beat_accuracy", "anticipation", "bravery"],
	"keeper": ["keeping", "reflexes", "positioning", "concentration"],
	"seeking": ["eyesight", "snitch_catching", "concentration", "dive", "composure"],
	"tactics": ["decisions", "off_ball", "positioning", "teamwork", "anticipation"],
}

const MENTAL := ["aggression", "anticipation", "bravery", "composure", "concentration", "creativity", "decisions", "determination", "flair", "influence", "off_ball", "positioning", "teamwork", "work_rate"]
const PHYSICAL := ["stamina", "strength", "natural_fitness", "reflexes", "eyesight", "speed", "acceleration"]
const FLYING := ["speed", "acceleration", "agility", "broom_control", "balance", "altitude", "dive"]


## One weekly development step for a player.
static func weekly(p: Player, w: World, club: Club, rng: SimRng, minutes_last_month: int) -> void:
	var age := p.age(w.today)
	var ca := p.ca()
	var headroom: float = maxf(p.pa - ca, 0.0)
	var prof: float = (p.hid("professionalism") - 10.0) / 10.0
	var det: float = (p.hid("determination_hidden") - 10.0) / 10.0 if p.hidden.has("determination_hidden") else (float(p.attrs.get("determination", 10.0)) - 10.0) / 10.0
	var facilities: float = 0.7 + 0.15 * float(club.facilities.get("training", 2))
	facilities *= 0.9 + 0.05 * club.staff_level("assistant")
	var minutes_factor: float = clampf(0.5 + minutes_last_month / 240.0, 0.5, 1.4)
	var points_per_week := 0.0
	if age <= 17:
		points_per_week = 0.04 * facilities
	elif age <= 21:
		points_per_week = 0.03 * facilities * minutes_factor
	elif age <= 24:
		points_per_week = 0.018 * facilities * minutes_factor
	elif age <= 28:
		points_per_week = 0.006 * minutes_factor
	elif age <= 30:
		points_per_week = -0.004
	elif age <= 33:
		points_per_week = -0.008
	else:
		points_per_week = -0.016 - 0.004 * (age - 34)
	if points_per_week > 0.0:
		points_per_week *= 1.0 + 0.4 * prof + 0.2 * det
	else:
		points_per_week *= clampf(1.0 - 0.3 * prof - 0.15 * det, 0.5, 1.5)
		points_per_week *= 0.8 if (p.position == "K" or p.position == "B") else 1.1
	if points_per_week > 0.0:
		points_per_week *= clampf(headroom / 15.0, 0.05, 1.0)
	points_per_week += rng.gauss(0.0, 0.012)

	var before: Dictionary = p.attrs.duplicate()
	var keys: Dictionary = Player.KEY_WEIGHTS.get(p.position, {})
	for k in Player.ATTR_KEYS:
		var g := points_per_week
		var is_phys: bool = PHYSICAL.has(k)
		var is_mental: bool = MENTAL.has(k)
		if points_per_week < 0.0:
			if is_phys:
				g *= physical_decline_mult(float(p.attrs.get("natural_fitness", 10.0)))
			elif is_mental:
				g = 0.004 if age <= 36 else g * 0.3
			else:
				g *= 0.8
		else:
			if is_mental and age >= 25:
				g *= 1.3
			if keys.has(k):
				g *= 1.25
			else:
				g *= 0.75
		var cur: float = float(p.attrs.get(k, 8.0))
		var noise: float = rng.gauss(0.0, 0.01)
		if g > 0.0:
			var taper := top_taper(cur)
			g *= taper
			noise *= taper
		p.attrs[k] = clampf(cur + g + noise, 1.0, 20.0)
	if p.ca() > p.pa:
		_trim_to_pa(p, before)
		_squash_to_pa(p)


## Growth multiplier for an attribute already near the top of the scale: full up to 16,
## then 0.78 at 17, 0.56 at 18, 0.33 at 19 and 0.11 at 20.
static func top_taper(value: float) -> float:  # [FILLER, calibrated]
	return clampf((20.5 - value) / 4.5, 0.1, 1.0)


## How much faster the physical attributes decline, from 1.12 at natural fitness 20 to 1.84 at 1.
static func physical_decline_mult(natural_fitness: float) -> float:  # [FILLER, calibrated]
	return 1.6 * clampf(1.0 - 0.3 * (natural_fitness - 10.0) / 10.0, 0.7, 1.15)


## Scales this step's gains back so CA does not pass PA. A gain of d in attribute k raises CA by
## d * weight_k * 10 / weight_sum (Player.ca), so the gains' CA rise is computed on that scale.
static func _trim_to_pa(p: Player, before: Dictionary) -> void:
	var rises := {}
	for k in Player.ATTR_KEYS:
		var d: float = float(p.attrs.get(k, 8.0)) - float(before.get(k, p.attrs.get(k, 8.0)))
		if d > 0.0:
			rises[k] = d
	var rise_ca := p.weighted_sum(rises, 0.0) * (10.0 / maxf(p.weight_total(), 1.0))
	if rise_ca > 0.0:
		var f: float = minf((p.ca() - p.pa) / rise_ca, 1.0)
		for k in rises:
			p.attrs[k] = clampf(float(p.attrs[k]) - float(rises[k]) * f, 1.0, 20.0)


## Lowers every attribute a little when CA still sits above PA after the trim (the 1-20 clamps can leave it there).
static func _squash_to_pa(p: Player) -> void:
	if p.ca() > p.pa + 0.001:
		var excess: float = (p.ca() - p.pa) / 10.0
		for k in Player.ATTR_KEYS:
			p.attrs[k] = clampf(float(p.attrs[k]) - excess * 0.5, 1.0, 20.0)


## Weekly training: category focus with load (1 light, 2 medium, 3 intense). Injury risk with high load.
static func training(p: Player, focus: String, load: int, rng: SimRng, club: Club) -> void:
	var attrs_list: Array = TRAINING.get(focus, [])
	if attrs_list.is_empty():
		return
	var coach: float = 0.8 + 0.1 * float(club.facilities.get("training", 2))
	coach *= 0.9 + 0.05 * club.staff_level("assistant")
	var gain: float = 0.006 * load * coach
	var room: float = clampf((p.pa - p.ca()) / 4.0, 0.0, 1.0)
	if room > 0.0:
		var before := {}
		for k in attrs_list:
			var cur: float = float(p.attrs.get(k, 8.0))
			before[k] = cur
			p.attrs[k] = clampf(cur + (gain + rng.gauss(0.0, 0.005)) * room * top_taper(cur), 1.0, 20.0)
		if p.ca() > p.pa:
			_trim_to_pa(p, before)
	if load >= 3 and rng.chance(0.012 * p.hid("injury_proneness") / 10.0):
		p.injury_days = rng.irange(3, 12)
		p.injury_kind = "training"


## The player's mentor while the mentorship still works (both at the same club, the youngster up to 23), else
## null. A mentorship that has ended is cleared.
static func valid_mentor(p: Player, w: World) -> Player:
	if p.mentor_id == "":
		return null
	var m: Player = w.players.get(p.mentor_id)
	if m == null or m.club_id == "" or m.club_id != p.club_id or p.age(w.today) > 23:
		p.mentor_id = ""
		return null
	return m


## Daily recovery of condition and injuries. Only needs calling if the player is injured or below 100.
## `medical_level` (1-5) is the club's medical level: every level shortens injuries and speeds up recovery.
static func daily(p: Player, rng: SimRng, medical_level: int) -> void:
	var med: int = clampi(medical_level, 1, 5)
	if p.injury_days > 0:
		p.injury_days -= 1
		if rng.chance(0.05 * med):
			p.injury_days -= 1
		if p.injury_days <= 0:
			p.injury_days = 0
			p.injury_kind = ""
			p.sharpness = maxf(p.sharpness - 15.0, 10.0)
	if p.condition < 100.0:
		var rec: float = 6.0 + 0.4 * float(p.attrs.get("natural_fitness", 10.0))
		rec *= 0.9 + 0.05 * med
		p.condition = minf(100.0, p.condition + rec)


## Weekly state: morale trends to the middle, match sharpness drops if not playing, brooms wear out.
static func weekly_state(p: Player, broom_master: int = 2) -> void:
	p.morale += (55.0 - p.morale) * 0.13
	p.sharpness = maxf(0.0, p.sharpness - 2.8)
	p.broom["condition"] = maxf(30.0, float(p.broom.get("condition", 100.0)) - 0.14 * (1.2 - 0.14 * broom_master))


## Summer broom service: the club's broom workshop restores part of the wear; it never makes an old broom as good
## as new. `workshop_level` 0-5 (0: no workshop).
static func service_broom(p: Player, workshop_level: int) -> void:  # [game] [PoA 1]
	if p.broom.is_empty():
		return
	var c: float = float(p.broom.get("condition", 100.0))
	p.broom["condition"] = maxf(c, minf(95.0, c + 10.0 + 12.0 * clampi(workshop_level, 0, 5)))


## Injury from a match.
static func apply_match_injury(p: Player, severity: String, rng: SimRng) -> void:
	assert(severity == SimPlayer.Severity.MATCH or severity == SimPlayer.Severity.LONG, "unknown injury severity: " + severity)
	p.injury_days = rng.irange(18, 70) if severity == SimPlayer.Severity.LONG else rng.irange(2, 9)
	p.injury_kind = "match"


## Match rating 1-10 from simulator stats.
static func match_rating(stats: Dictionary, position: String, team_won: bool) -> float:
	var r := 6.0
	r += 1.6 * (1.0 - exp(-int(stats.get("goals", 0)) / 4.0))
	r += 1.2 * (1.0 - exp(-int(stats.get("saves", 0)) / 8.0)) - 0.03 * int(stats.get("goals_conceded", 0))
	r += 1.4 * (1.0 - exp(-int(stats.get("bludger_hits_dealt", 0)) / 8.0))
	r += 0.6 * (1.0 - exp(-(int(stats.get("steals", 0)) + int(stats.get("interceptions", 0))) / 5.0))
	r -= 0.25 * int(stats.get("fouls", 0)) + 0.03 * int(stats.get("passes_failed", 0))
	r += 1.6 * int(stats.get("snitch_catch", 0)) + 0.3 * mini(int(stats.get("snitch_sightings", 0)), 2)
	if position == "S" and int(stats.get("snitch_catch", 0)) == 0:
		r -= 0.6
	r += 0.4 if team_won else -0.3
	return clampf(r, 1.0, 10.0)
