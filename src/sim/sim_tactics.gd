class_name SimTactics
extends RefCounted
## Tactics consumed by the engine: one TABLE entry per key.

const SLIDER_MIN := 1
const SLIDER_MAX := 20
const SLIDER_MID := 10

## A slider entry runs SLIDER_MIN..SLIDER_MAX and names what its two ends mean; an option entry lists the legal
## values; `seeker_ahead_by` is the points margin the "ahead_by" catch instruction waits for.
const TABLE := {
	"mentality": {"default": SLIDER_MID, "ends": ["defensive", "attacking"]},
	"tempo": {"default": SLIDER_MID, "ends": ["slow", "fast"]},
	"pass_style": {"default": SLIDER_MID, "ends": ["short", "long"]},
	"long_shots": {"default": SLIDER_MID, "ends": ["close only", "from range"]},
	"pressing": {"default": SLIDER_MID, "ends": ["rarely", "often"]},
	"hard_play": {"default": SLIDER_MID, "ends": ["soft", "hard"]},
	"time_wasting": {"default": SLIDER_MID, "ends": ["low", "high"]},
	"chaser_formation": {"default": "free", "options": ["free", "hawkshead", "porskoff", "shimmy", "reverse_pass", "looping"]},
	"chaser_defence": {"default": "zone", "options": ["zone", "pincer", "mark"]},  # [game]
	"beater_instruction": {"default": "nearest", "options": ["nearest", "hunt_seeker", "protect_seeker", "protect_chasers", "punish_carrier", "mark_beaters", "dopplebeater", "backbeat"]},
	"seeker_catch": {"default": "always", "options": ["always", "if_wins", "ahead_by"]},
	"seeker_ahead_by": {"default": 50},
	"seeker_search": {"default": "free", "options": ["free", "mark_rival"]},
	"seeker_feint": {"default": "if_chance", "options": ["never", "if_chance", "seek"]},
	"keeper_position": {"default": "stay", "options": ["stay", "rush", "starfish", "double_eight"]},
}


static func defaults() -> Dictionary:
	var t := {}
	for k in TABLE:
		t[k] = TABLE[k]["default"]
	return t


## The defaults overlaid with `overrides` (a saved, pack or partial tactics dict). A value outside TABLE fails
## in a debug build.
static func merge(overrides: Dictionary) -> Dictionary:
	var t := defaults()
	for k in overrides.keys():
		t[k] = overrides[k]
	validate(t)
	return t


static func validate(t: Dictionary) -> void:
	for k in TABLE:
		var spec: Dictionary = TABLE[k]
		var v = t.get(k)
		if spec.has("options"):
			assert(spec["options"].has(v), "tactic %s has no option %s" % [k, v])
		elif spec.has("ends"):
			assert(int(v) >= SLIDER_MIN and int(v) <= SLIDER_MAX, "slider %s out of range: %s" % [k, v])


## Converts a slider into a multiplier around 1.0 (SLIDER_MID → 1.0; SLIDER_MIN → 1-span; SLIDER_MAX → 1+span).
static func slider(t: Dictionary, key: String, span: float = 0.3) -> float:
	var v: float = float(t.get(key, SLIDER_MID))
	return 1.0 + (v - 10.0) / 10.0 * span


const CARRY_STYLES := ["hawkshead", "shimmy"]
const PASS_STYLES := ["porskoff", "reverse_pass", "looping"]


static func defence_of(t: Dictionary) -> String:
	return str(t.get("chaser_defence", TABLE["chaser_defence"]["default"]))


## The defence that best counters an attacking style ("" if there is no clear one).
static func counter_to(formation: String) -> String:
	if CARRY_STYLES.has(formation):
		return "pincer"
	if PASS_STYLES.has(formation):
		return "mark"
	return ""
