class_name FillerGenerator
extends RefCounted
## Generates filler players to complete squads. Deterministic for a given SimRng.

const KEY_ATTRS := {
	"K": ["keeping", "reflexes", "positioning", "anticipation", "agility", "bravery", "concentration", "altitude"],
	"C": ["passing", "catching", "shooting", "dodging", "speed", "off_ball", "creativity", "decisions", "teamwork", "stealing", "agility"],
	"B": ["beating", "beat_accuracy", "strength", "balance", "anticipation", "aggression", "bravery", "positioning", "decisions", "broom_control"],
	"S": ["eyesight", "snitch_catching", "speed", "acceleration", "agility", "concentration", "bravery", "dive", "composure", "decisions", "balance"],
}

const ALL_ATTRS := [
	"speed", "acceleration", "agility", "broom_control", "balance", "altitude", "dive",
	"passing", "catching", "shooting", "dodging", "stealing", "interception", "keeping", "beating", "beat_accuracy", "snitch_catching",
	"aggression", "anticipation", "bravery", "composure", "concentration", "creativity", "decisions", "determination", "flair", "influence", "off_ball", "positioning", "teamwork", "work_rate",
	"stamina", "strength", "natural_fitness", "reflexes", "eyesight",
]

const HIDDEN := ["consistency", "big_matches", "injury_proneness", "dirtiness", "versatility", "adaptability", "ambition", "controversy", "loyalty", "pressure", "professionalism", "sportsmanship", "temperament"]

const CA_BY_LEVEL := {1: [125.0, 150.0], 2: [105.0, 130.0], 3: [88.0, 112.0], 4: [70.0, 95.0]}

const BROOM_BY_LEVEL := {
	1: ["broom_nimbus_1700", "broom_nimbus_2000", "broom_nimbus_1500"],
	2: ["broom_cleansweep_seven", "broom_comet_260", "broom_nimbus_1500"],
	3: ["broom_comet_220", "broom_cleansweep_six", "broom_shooting_star"],
	4: ["broom_shooting_star", "broom_cleansweep_five", "broom_comet_220"],
}

var names: Dictionary
var brooms: Dictionary


func _init(names_table: Dictionary, brooms_by_id: Dictionary) -> void:
	names = names_table
	brooms = brooms_by_id


func make_player(rng: SimRng, position: String, level: int, club_id: String, index: int, women_only: bool = false, reserve: bool = false) -> SimPlayer:
	var p := SimPlayer.new()
	var female := women_only or rng.chance(0.42)
	var first: String = str(rng.pick(names["first_names_f"] if female else names["first_names_m"]))
	var last: String = female_last(names, str(rng.pick(names["last_names"])), female)
	p.name = "%s %s" % [first, last]
	p.gender = SimPlayer.Gender.F if female else SimPlayer.Gender.M
	p.id = "filler_%s_%s_%d" % [club_id.trim_prefix("club_"), position.to_lower(), index]
	p.position = position
	var rangev: Array = CA_BY_LEVEL.get(clampi(level, 1, 4), CA_BY_LEVEL[3])
	var ca: float = rng.gauss((rangev[0] + rangev[1]) / 2.0, (rangev[1] - rangev[0]) / 4.0)
	if reserve:
		ca -= 18.0
	ca = clampf(ca, 50.0, 185.0)
	var base: float = ca / 10.0
	var keys: Array = KEY_ATTRS[position]
	for k in ALL_ATTRS:
		var v: float = base
		if keys.has(k):
			v += 3.0
		else:
			v -= 1.5
		v += rng.gauss(0.0, 1.6)
		p.attrs[k] = clampf(v, 1.0, 20.0)
	for h in HIDDEN:
		p.hidden[h] = clampf(rng.gauss(10.5, 3.5), 1.0, 20.0)
	var broom_id: String = str(rng.pick(BROOM_BY_LEVEL.get(clampi(level, 1, 4), BROOM_BY_LEVEL[3])))
	p.broom = brooms.get(broom_id, {"speed": 10, "acceleration": 10, "turning": 10, "braking": 10, "altitude": 10, "stability": 10}).duplicate()
	p.broom["model_id"] = broom_id
	return p


## Feminine form of `last` when the name table pairs `last_names_f` with `last_names`.
static func female_last(names: Dictionary, last: String, female: bool) -> String:
	if female and names.has("last_names_f"):
		var i: int = names["last_names"].find(last)
		if i >= 0 and i < names["last_names_f"].size():
			return str(names["last_names_f"][i])
	return last
