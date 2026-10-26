class_name Commentary
extends RefCounted

const VOICED_LINE_CHANCE := 0.6
const REACTION_LINE_CHANCE := 0.35
const BLUDGER_HIT_LINE_CHANCE := 0.08
const SAVE_OR_MISS_LINE_CHANCE := 0.3
const MCGONAGALL_INTERJECTION_CHANCE := 0.35

## Event types that have their own commentator lines.
const TYPES := ["kickoff", "goal", "penalty_goal", "save", "miss", "foul", "snitch_sighted", "snitch_caught", "wronski_feint", "bludger_hit", "injury", "match_end"]
## For these the neutral text carries its own info (foul name, injury, whether the feint worked):
## the commentator adds a line after it instead of replacing it.
const REACTIONS := ["foul", "wronski_feint", "bludger_hit", "injury"]


static func is_reaction(type: String) -> bool:
	return REACTIONS.has(type)


## Match commentator ("" = neutral voice).
static func for_match(comp_id: String, f: Dictionary) -> String:  # [game]
	var day := int(f.get("day", 0))
	if comp_id.begins_with("comp_school_"):
		return "lee_jordan" if day <= WDate.from_ymd(1996, 6, 30) else ""  # [PS 11] [OotP 29]
	return "bagman" if day <= WDate.from_ymd(1995, 6, 30) else ""  # [GoF 8] [GoF 37]


## Text key for an event voiced by the commentator (or "" for the neutral voice). Deterministic per match and tick.
static func key_for(who: String, e: MatchEvent, seed_value: int) -> String:
	if who == "" or not TYPES.has(e.type):
		return ""
	var important: bool = e.type in ["kickoff", "snitch_caught", "match_end"]
	var chance := REACTION_LINE_CHANCE if is_reaction(e.type) else VOICED_LINE_CHANCE
	if e.type == "bludger_hit":
		chance = BLUDGER_HIT_LINE_CHANCE
	elif e.type == "save" or e.type == "miss":
		chance = SAVE_OR_MISS_LINE_CHANCE
	if not important and float(absi(seed_value) % 1000) / 1000.0 >= chance:
		return ""
	var base := "commentary.%s.%s" % [who, e.type]
	var team := e.team_id
	for suffix in [_team_suffix(team)]:
		if suffix != "" and TranslationServer.translate(base + suffix) != base + suffix:
			return base + suffix
	return base if TranslationServer.translate(base) != base else ""


## Interruption after a commentator line: McGonagall to Jordan when he is partisan. "" if not applicable.
static func interjection_for(who: String, key: String, seed_value: int) -> String:
	if who == "lee_jordan" and (key.ends_with(".gry") or key.ends_with(".sly")) and float(absi(seed_value / 7) % 1000) / 1000.0 < MCGONAGALL_INTERJECTION_CHANCE:
		return "commentary.lee_jordan.mcgonagall"
	return ""


static func _team_suffix(team_id: String) -> String:
	if team_id.ends_with("_gryffindor"):
		return ".gry"
	if team_id.ends_with("_slytherin"):
		return ".sly"
	return ""


## Commentator name to show in the match header.
static func display_name(who: String) -> String:
	return TranslationServer.translate("commentary.name." + who) if who != "" else ""
