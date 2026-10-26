class_name Fans  # [game]
extends RefCounted

const BASE := 60.0


static func mood(club: Club) -> float:
	return float(club.fans.get("mood", BASE))


static func _set_mood(club: Club, v: float) -> void:
	club.fans["mood"] = clampf(v, 0.0, 100.0)


static func gate_factor(club: Club) -> float:
	return lerpf(0.85, 1.15, mood(club) / 100.0)


static func merch_factor(club: Club) -> float:
	return lerpf(0.85, 1.15, mood(club) / 100.0)


## After each official match.
static func after_match(club: Club, my_score: int, their_score: int) -> void:
	var d := 0.0
	if my_score > their_score:
		d = 3.0 + (2.0 if my_score - their_score >= 150 else 0.0)
	elif my_score < their_score:
		d = -3.0 - (2.0 if their_score - my_score >= 150 else 0.0)
	_set_mood(club, mood(club) + d)


static func title(club: Club, amount: float = 15.0) -> void:
	_set_mood(club, mood(club) + amount)


## The club sold its idol (the player with the most appearances this season).
static func idol_sold(club: Club) -> void:
	_set_mood(club, mood(club) - 8.0)


static func weekly(club: Club) -> void:
	_set_mood(club, mood(club) + (BASE - mood(club)) * 0.05)


static func mood_key(v: float) -> String:
	if v >= 80.0:
		return "ui.fans.euphoric"
	if v >= 62.0:
		return "ui.fans.happy"
	if v >= 45.0:
		return "ui.fans.calm"
	if v >= 28.0:
		return "ui.fans.restless"
	return "ui.fans.angry"
