class_name Player
extends RefCounted
## Persistent world player, serialized to a Dictionary for saving.

const ATTR_KEYS := FillerGenerator.ALL_ATTRS
const HIDDEN_KEYS := FillerGenerator.HIDDEN

const KEY_WEIGHTS := {
	"K": {"keeping": 2.0, "reflexes": 2.0, "positioning": 2.0, "anticipation": 2.0, "agility": 1.5, "bravery": 1.5, "concentration": 1.5, "altitude": 1.5, "influence": 1.5},
	"C": {"passing": 2.0, "catching": 2.0, "shooting": 2.0, "dodging": 2.0, "speed": 2.0, "off_ball": 1.5, "creativity": 1.5, "decisions": 1.5, "teamwork": 1.5, "stealing": 1.5, "agility": 1.5},
	"B": {"beating": 2.0, "beat_accuracy": 2.0, "strength": 2.0, "balance": 2.0, "anticipation": 1.5, "aggression": 1.5, "bravery": 1.5, "positioning": 1.5, "decisions": 1.5, "broom_control": 1.5},
	"S": {"eyesight": 2.0, "snitch_catching": 2.0, "speed": 2.0, "acceleration": 2.0, "agility": 2.0, "concentration": 1.5, "bravery": 1.5, "dive": 1.5, "composure": 1.5, "decisions": 1.5, "balance": 1.5},
}

const PHYSICAL := ["stamina", "strength", "natural_fitness", "reflexes", "eyesight", "speed", "acceleration"]

class Squad:
	const FIRST := "first"
	const RESERVE := "reserve"
	const YOUTH := "youth"
	const SCHOOL := "school"
	const ABROAD := "abroad"
	const FREE := "free"
	const ALL := [FIRST, RESERVE, YOUTH, SCHOOL, ABROAD, FREE]
	const SENIOR := [FIRST, RESERVE]
	const DEVELOPING := [RESERVE, YOUTH]
	const AWAY_FROM_CLUBS := [SCHOOL, ABROAD]

var id: String = ""
var first_name: String = ""
var last_name: String = ""
var gender: String = SimPlayer.Gender.M
var nationality: String = "eng"
var birth_day: int = 0
var club_id: String = ""
var squad: String = Squad.FIRST
var position: String = "C"
var positions: Dictionary = {}
var attrs: Dictionary = {}
var hidden: Dictionary = {}
var pa: float = 100.0
var condition: float = 100.0
var sharpness: float = 50.0
var morale: float = 60.0
var form: Array = []
var injury_days: int = 0
var injury_kind: String = ""
var suspension_matches: int = 0
var duty_days: int = 0
var duty_team: String = ""
var contract: Dictionary = {"wage_weekly": 10, "end_day": 0, "role": "rotation"}
var broom: Dictionary = {"model_id": "broom_shooting_star", "condition": 100.0}
var is_captain: bool = false
var source: String = "filler"
var traits: Array = []
var prev_attrs: Dictionary = {}
var season_stats: Dictionary[String, Dictionary] = {}
var comp_stats: Dictionary[String, Dictionary] = {}
var transfer_listed: bool = false
var loan_listed: bool = false
var loan: Loan = null
var free_since: int = 0
var school_id: String = ""
var house: String = ""
var ban_until: int = 0
var awards: Array = []
var promise: Dictionary = {}
var training_focus: String = ""
var mentor_id: String = ""
var talks_blocked_until: int = 0
var happiness: Dictionary[String, float] = {}     # [game]
var last_complaint_day: int = 0
var complaints_ignored: int = 0
var pre_contract: PreContract = null
var injury_history: Array = []
var month_ratings: Array = []
var sell_on: Dictionary = {}
var loan_option_fee: int = 0
var match_log: Array[Array] = []
var look: Dictionary = {}


## A loan spell: club_id is the borrower, the owner keeps the contract and gets the player back on return_day.
class Loan:
	var owner_id: String
	var return_day: int
	var owner_squad: String
	## Price the borrower may pay to keep the player, 0 when the loan carries no option.
	var buy_option: int

	func _init(owner_id_in: String = "", return_day_in: int = 0, owner_squad_in: String = Squad.RESERVE, buy_option_in: int = 0) -> void:
		owner_id = owner_id_in
		return_day = return_day_in
		owner_squad = owner_squad_in
		buy_option = buy_option_in

	func to_dict() -> Dictionary:
		var d := {"owner_id": owner_id, "return_day": return_day, "owner_squad": owner_squad}
		if buy_option > 0:
			d["buy_option"] = buy_option
		return d

	static func from_dict(d: Dictionary) -> Loan:
		return Loan.new(str(d.get("owner_id", "")), int(d.get("return_day", 0)), str(d.get("owner_squad", Squad.RESERVE)), int(d.get("buy_option", 0)))


## A contract signed with another club for next season; Contracts.execute_pre_contracts moves the player.
class PreContract:
	var club_id: String
	var terms: Dictionary
	var day: int
	## Signed while still at school: the player graduates straight into that club.
	var graduate: bool
	## Paid by the club when the player arrives, not when the pre-contract is signed.
	var signing_fee: int

	func _init(club_id_in: String = "", terms_in: Dictionary = {}, day_in: int = 0, graduate_in: bool = false, signing_fee_in: int = 0) -> void:
		club_id = club_id_in
		terms = terms_in
		day = day_in
		graduate = graduate_in
		signing_fee = signing_fee_in

	func to_dict() -> Dictionary:
		var d := {"club_id": club_id, "terms": terms, "day": day}
		if graduate:
			d["graduate"] = true
		if signing_fee > 0:
			d["signing_fee"] = signing_fee
		return d

	static func from_dict(d: Dictionary) -> PreContract:
		return PreContract.new(str(d.get("club_id", "")), d.get("terms", {}), int(d.get("day", 0)), bool(d.get("graduate", false)), int(d.get("signing_fee", 0)))


## Columns of a match_log row.
class MatchLog:
	const DAY := 0
	const COMP_ID := 1
	const OPPONENT_ID := 2
	const HOME := 3
	const SCORED := 4
	const CONCEDED := 5
	const GOALS := 6
	const SAVES := 7
	const CATCHES := 8
	const BLUDGER_HITS := 9
	const RATING_X10 := 10
	const COLUMNS := 11


func name() -> String:
	return ("%s %s" % [first_name, last_name]).strip_edges()


func age(today: int) -> int:
	return WDate.age_at(birth_day, today)


## Physically able to play: neither injured nor banned.
func is_fit() -> bool:
	return injury_days <= 0 and suspension_matches <= 0


## Available to their club or house: fit and not away on international duty.
func is_available() -> bool:
	return is_fit() and duty_days <= 0


func on_duty() -> bool:
	return duty_days > 0


## Current ability 1-200: 10 × position-weighted mean of attributes.
func ca() -> float:
	return clampf(10.0 * weighted_sum(attrs) / maxf(weight_total(), 1.0), 1.0, 200.0)


## Sum of `values` (attribute -> value, `missing` for absent keys) weighted by this position's KEY_WEIGHTS.
func weighted_sum(values: Dictionary, missing: float = 8.0) -> float:
	var w: Dictionary = KEY_WEIGHTS.get(position, {})
	var sum := 0.0
	for k in ATTR_KEYS:
		sum += float(values.get(k, missing)) * float(w.get(k, 1.0))
	return sum


static var _weight_totals: Dictionary[String, float] = {}


## Sum of this position's weights over every attribute.
func weight_total() -> float:
	if not _weight_totals.has(position):
		var w: Dictionary = KEY_WEIGHTS.get(position, {})
		var total := 0.0
		for k in ATTR_KEYS:
			total += float(w.get(k, 1.0))
		_weight_totals[position] = total
	return _weight_totals[position]


func hid(key: String) -> float:
	return float(hidden.get(key, 10.0))


func avg_form() -> float:
	if form.is_empty():
		return 6.0
	var s := 0.0
	for f in form:
		s += float(f)
	return s / form.size()


## Market value in Galleons [FILLER].
func market_value(today: int) -> int:
	var c := ca()
	var a := age(today)
	var v: float = pow(maxf(c - 60.0, 5.0) / 10.0, 2.2) * 12.0
	if a < 24:
		v *= 1.0 + (pa - c) / 80.0
	elif a > 30:
		v *= maxf(0.35, 1.0 - (a - 30) * 0.12)
	return int(maxf(20.0, v / 10.0) * 10.0)


func snapshot_attrs() -> void:
	prev_attrs = attrs.duplicate()


## Appends a match to match_log, keeping the last `keep` matches.
func log_match(entry: Array, keep: int) -> void:
	match_log.append(entry)
	if match_log.size() > keep:
		match_log = match_log.slice(match_log.size() - keep)


func stats_for(season: int) -> Dictionary:
	var key := str(season)
	if not season_stats.has(key):
		season_stats[key] = {"apps": 0, "goals": 0, "catches": 0, "saves": 0, "rating_sum": 0.0, "minutes": 0, "fouls": 0, "hits": 0, "feints": 0, "injuries": 0}
	return season_stats[key]


static func comp_key(season: int, comp_id: String) -> String:
	return "%d|%s" % [season, comp_id]


## Stats for a specific competition (creates the entry if missing).
func stats_for_comp(season: int, comp_id: String) -> Dictionary:
	var key := comp_key(season, comp_id)
	if not comp_stats.has(key):
		comp_stats[key] = {"apps": 0, "goals": 0, "catches": 0, "saves": 0, "rating_sum": 0.0, "minutes": 0, "fouls": 0, "hits": 0, "feints": 0, "injuries": 0}
	return comp_stats[key]


func to_sim_player(brooms: Dictionary) -> SimPlayer:
	var sp := SimPlayer.new()
	sp.id = id
	sp.name = name()
	sp.position = position
	sp.attrs = attrs.duplicate()
	sp.hidden = hidden.duplicate()
	var bid := str(broom.get("model_id", "broom_shooting_star"))
	var b: Dictionary = brooms.get(bid, {"speed": 10, "acceleration": 10, "turning": 10, "braking": 10, "altitude": 10, "stability": 10}).duplicate()
	var bc: float = float(broom.get("condition", 100.0)) / 100.0
	for k in ["speed", "acceleration", "turning", "braking", "altitude", "stability"]:
		b[k] = float(b.get(k, 10)) * (0.8 + 0.2 * bc)
	b["model_id"] = bid
	sp.broom = b
	sp.start_condition = clampf(condition, 0.0, 100.0)
	sp.condition = sp.start_condition
	var mod: float = 0.94 + 0.06 * sharpness / 100.0 + 0.04 * (morale - 50.0) / 50.0
	for k in sp.attrs.keys():
		sp.attrs[k] = float(sp.attrs[k]) * mod
	return sp


func is_on_loan() -> bool:
	return loan != null


## The club that owns a loanee's contract, or "" when the player is not on loan.
func loan_owner_id() -> String:
	return loan.owner_id if loan != null else ""


## Independent copy; to_dict shares its dictionaries with the player.
func clone() -> Player:
	return Player.from_dict(to_dict().duplicate(true))


func to_dict() -> Dictionary:
	return {
		"id": id, "first_name": first_name, "last_name": last_name, "gender": gender, "nationality": nationality,
		"birth_day": birth_day, "club_id": club_id, "squad": squad, "position": position, "positions": positions,
		"attrs": attrs, "hidden": hidden, "pa": pa, "condition": condition, "sharpness": sharpness, "morale": morale,
		"form": form, "injury_days": injury_days, "injury_kind": injury_kind, "suspension_matches": suspension_matches,
		"duty_days": duty_days, "duty_team": duty_team,
		"contract": contract, "broom": broom, "is_captain": is_captain, "source": source, "traits": traits, "look": look,
		"prev_attrs": prev_attrs, "season_stats": season_stats, "comp_stats": comp_stats, "transfer_listed": transfer_listed, "loan_listed": loan_listed, "loan": loan.to_dict() if loan != null else {}, "free_since": free_since, "school_id": school_id, "house": house, "ban_until": ban_until, "awards": awards, "promise": promise, "training_focus": training_focus, "mentor_id": mentor_id,
		"talks_blocked_until": talks_blocked_until, "happiness": happiness, "last_complaint_day": last_complaint_day, "complaints_ignored": complaints_ignored,
		"pre_contract": pre_contract.to_dict() if pre_contract != null else {}, "injury_history": injury_history, "month_ratings": month_ratings,
		"sell_on": sell_on, "loan_option_fee": loan_option_fee, "match_log": match_log,
	}


static func from_dict(d: Dictionary) -> Player:
	var p := Player.new()
	p.id = str(d["id"])
	p.first_name = str(d.get("first_name", ""))
	p.last_name = str(d.get("last_name", ""))
	p.gender = str(d.get("gender", SimPlayer.Gender.M))
	assert(SimPlayer.Gender.ALL.has(p.gender), "unknown gender: " + p.gender)
	p.nationality = str(d.get("nationality", "eng"))
	p.birth_day = int(d.get("birth_day", 0))
	p.club_id = str(d.get("club_id", ""))
	p.squad = str(d.get("squad", Squad.FIRST))
	assert(Squad.ALL.has(p.squad), "unknown squad: " + p.squad)
	p.position = str(d.get("position", "C"))
	p.positions = d.get("positions", {})
	p.attrs = d.get("attrs", {})
	p.hidden = d.get("hidden", {})
	p.pa = float(d.get("pa", 100.0))
	p.condition = float(d.get("condition", 100.0))
	p.sharpness = float(d.get("sharpness", 50.0))
	p.morale = float(d.get("morale", 60.0))
	p.form = d.get("form", [])
	p.injury_days = int(d.get("injury_days", 0))
	p.injury_kind = str(d.get("injury_kind", ""))
	p.suspension_matches = int(d.get("suspension_matches", 0))
	p.duty_days = int(d.get("duty_days", 0))
	p.duty_team = str(d.get("duty_team", ""))
	p.contract = d.get("contract", {"wage_weekly": 10, "end_day": 0, "role": "rotation"})
	p.broom = d.get("broom", {"model_id": "broom_shooting_star", "condition": 100.0})
	p.is_captain = bool(d.get("is_captain", false))
	p.source = str(d.get("source", "filler"))
	p.traits = d.get("traits", [])
	p.prev_attrs = d.get("prev_attrs", {})
	p.season_stats.assign(d.get("season_stats", {}))
	p.comp_stats.assign(d.get("comp_stats", {}))
	p.match_log.assign(d.get("match_log", []))
	p.look = d.get("look", {})
	p.transfer_listed = bool(d.get("transfer_listed", false))
	p.loan_listed = bool(d.get("loan_listed", false))
	var loan_d: Dictionary = d.get("loan", {})
	p.loan = Loan.from_dict(loan_d) if not loan_d.is_empty() else null
	p.free_since = int(d.get("free_since", 0))
	p.school_id = str(d.get("school_id", ""))
	p.house = str(d.get("house", ""))
	p.ban_until = int(d.get("ban_until", 0))
	p.awards = d.get("awards", [])
	p.promise = d.get("promise", {})
	p.training_focus = str(d.get("training_focus", ""))
	p.mentor_id = str(d.get("mentor_id", ""))
	p.talks_blocked_until = int(d.get("talks_blocked_until", 0))
	p.happiness.assign(d.get("happiness", {}))
	p.last_complaint_day = int(d.get("last_complaint_day", 0))
	p.complaints_ignored = int(d.get("complaints_ignored", 0))
	var pre_d: Dictionary = d.get("pre_contract", {})
	p.pre_contract = PreContract.from_dict(pre_d) if not pre_d.is_empty() else null
	p.injury_history = d.get("injury_history", [])
	p.month_ratings = d.get("month_ratings", [])
	p.sell_on = d.get("sell_on", {})
	p.loan_option_fee = int(d.get("loan_option_fee", 0))
	return p
