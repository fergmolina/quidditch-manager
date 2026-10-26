class_name Career  # [game]
extends RefCounted

const LEVEL_FACTOR := {1: 1.0, 2: 0.7, 3: 0.5}
const NT_THRESHOLD := {"weak": 1500, "mid": 1900, "strong": 2400, "elite": 3000}
const NT_SEASONS := {"weak": 2, "mid": 2, "strong": 3, "elite": 3}
const RANKS := [[0, "ui.career.rank0"], [700, "ui.career.rank1"], [1300, "ui.career.rank2"], [2000, "ui.career.rank3"], [2800, "ui.career.rank4"]]
const ULTIMATUM_CONFIDENCE := 25.0
## Numbers the accounts server also enforces (data/shared/career_rules.json).
static var RULES: Dictionary = SimLoader.load_json(SimLoader.SHARED + "/career_rules.json")
static var REP_MIN: int = int(RULES["reputation"]["min"])
static var REP_MAX: int = int(RULES["reputation"]["max"])
static var START_REP_MIN: int = int(RULES["start_reputation"]["min"])
static var START_REP_MAX: int = int(RULES["start_reputation"]["max"])


static func set_reputation(w: World, rep: int) -> void:
	w.manager["reputation"] = clampi(rep, REP_MIN, REP_MAX)


static func add_reputation(w: World, delta: int) -> void:
	set_reputation(w, int(w.manager.get("reputation", 1000)) + delta)


static func start_reputation(club: Club) -> int:
	return clampi(int(club.reputation * 0.18), START_REP_MIN, START_REP_MAX)


## Reputation a club requires to offer the job.
static func club_requirement(club: Club) -> int:
	return int(club.reputation * 0.2)


static func level_factor(level: int) -> float:
	return float(LEVEL_FACTOR.get(clampi(level, 1, 3), 0.5))


## Expected position of the club in its league by reputation (1 = most prestigious).
static func expected_position(w: World, club: Club) -> int:
	var lg := w.league_of(club.id)
	if lg == null:
		return 1
	var pos := 1
	for cid in lg.club_ids:
		if cid != club.id and w.club(cid).reputation > club.reputation:
			pos += 1
	return pos


## Reputation change at season close.
static func season_delta(w: World, club: Club, final_pos: int, verdict: String) -> int:
	var f := level_factor(club.level)
	var delta := (expected_position(w, club) - final_pos) * 45.0 * f
	if final_pos == 1:
		delta += 220.0 * f
	match verdict:
		"met":
			delta += 60.0
		"missed":
			delta -= 60.0
		"sacked":
			delta -= 220.0
	return int(delta)


static func cup_bonus(kind: String, club: Club) -> int:
	match kind:
		"national_cup":
			return int(100 * level_factor(club.level))
		"cont_knockout":
			return 220
		"cup":
			return 350
		"house_world":
			return 150
	return 0


static func rank_key(rep: int) -> String:
	var key := str(RANKS[0][1])
	for r in RANKS:
		if rep >= int(r[0]):
			key = str(r[1])
	return key


## Next rank: [reputation still needed, rank key] or [] if already at the top.
static func next_rank(rep: int) -> Array:
	for r in RANKS:
		if rep < int(r[0]):
			return [int(r[0]) - rep, str(r[1])]
	return []


static func nt_eligible(w: World, ntid: String) -> bool:
	var nt: Dictionary = w.national_teams.get(ntid, {})
	var tier := str(nt.get("tier", "mid"))
	var rep: int = int(w.manager.get("reputation", 0))
	return rep >= int(NT_THRESHOLD.get(tier, NT_THRESHOLD["mid"])) and int(w.manager.get("seasons", 0)) >= int(NT_SEASONS.get(tier, 2))
