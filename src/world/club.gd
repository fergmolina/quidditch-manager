class_name Club
extends RefCounted
## Persistent club.

var id: String = ""
var name: String = ""
var short_name: String = ""
var city: String = ""
var country_id: String = "eng"
var region_id: String = "british_isles"
var founded: int = 0
var colors: Dictionary = {"primary": "#888888", "secondary": "#dddddd"}
var emblem_key: String = ""
var identity: Dictionary = {}
var league_id: String = ""
var level: int = 3
var reputation: int = 3000
var balance: int = 5000
var wage_budget_weekly: int = 200
var transfer_budget: int = 1000
var facilities: Dictionary = {"training": 2, "medical": 2, "broom_workshop": 1}
var constraints: Dictionary = {}
var manager_name: String = ""
var manager_is_human: bool = false
var history: Dictionary = {}
var source: String = "filler"
var lineup: Dictionary = {}
var tactics: Dictionary = SimTactics.defaults()
var board: Dictionary = {"objective": "mid_table", "confidence": 60.0, "objective_min_pos": 7}
var sponsor: Dictionary = {}
var season_summary: Dictionary[String, Dictionary] = {}
var knowledge: Dictionary = {}
var scouts: Array = []
var staff: Dictionary[String, Dictionary] = {}
var tactic_sets: Array = []
var active_set: int = 0
var familiarity: Dictionary[String, float] = {}
var ledger: Dictionary[String, Dictionary] = {}
var fans: Dictionary = {}            # [game]
var scout_reports: Dictionary[String, Dictionary] = {}
var ground: Dictionary = {}          # [game]


const STAFF_ROLES := ["assistant", "mediwizard", "head_scout", "broom_master"]


## Level of a backroom staff role: 1-5, or 0 if vacant. School houses count as level 2.
func staff_level(role: String) -> int:
	if staff.has(role):
		return int(staff[role].get("level", 2))
	return 2 if source == "school" else 0


## Broom care 0-5: the better of the broom master's level and the broom workshop facility. [game]
func broom_care_level() -> int:
	return maxi(staff_level("broom_master"), int(facilities.get("broom_workshop", 1)))


static func staff_wage(level: int) -> int:
	return [0, 2, 4, 8, 14, 22][clampi(level, 1, 5)]


static var _city_names: Dictionary = {}


## City for display: as in the data in Spanish; otherwise the city's name in the current language, falling back
## to English, with the translated country.
func display_city() -> String:
	if city == "" or TranslationServer.get_locale().begins_with("es"):
		return city
	if _city_names.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/shared/city_names.json"))
		_city_names = d.get("cities", {}) if d is Dictionary else {"_": ""}
	var first := city.get_slice(",", 0).strip_edges()
	if first.contains(" ("):
		first = first.get_slice(" (", 0)
	var names = _city_names.get(first, {})
	if names is Dictionary:
		var loc := TranslationServer.get_locale()
		first = str(names.get(loc, names.get(loc.get_slice("_", 0), names.get("en", first))))
	if not city.contains(","):
		return first
	return "%s, %s" % [first, Loc.name("country." + country_id, city.get_slice(",", city.get_slice_count(",") - 1).strip_edges())]


## Titles that apply to this club, in order, as [text key, count] pairs. The European Cup only for European
## clubs; the continental cup only where the league plays one.
func trophy_counts() -> Array:
	var out: Array = [["ui.league_titles", int(history.get("league_titles", 0))], ["ui.national_cups", int(history.get("national_cups", 0))]]
	for key in GameEngine.CONTINENTAL.keys():
		if GameEngine.CONTINENTAL[key]["slots"].has(league_id):
			out.append(["ui.continental_cups", int(history.get("continental_cups", 0))])
			break
	if GameEngine.EUROPEAN_REGIONS.has(region_id):
		out.append(["ui.european_cups", int(history.get("european_cups", 0))])
	return out


func is_women_only() -> bool:
	return bool(constraints.get("women_only", false))


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "short_name": short_name, "city": city, "country_id": country_id, "region_id": region_id,
		"founded": founded, "colors": colors, "emblem_key": emblem_key, "identity": identity, "league_id": league_id,
		"level": level, "reputation": reputation, "balance": balance, "wage_budget_weekly": wage_budget_weekly,
		"transfer_budget": transfer_budget, "facilities": facilities, "constraints": constraints, "manager_name": manager_name,
		"manager_is_human": manager_is_human, "history": history, "source": source, "lineup": lineup, "tactics": tactics,
		"board": board, "sponsor": sponsor, "season_summary": season_summary, "knowledge": knowledge, "scouts": scouts, "staff": staff,
		"tactic_sets": tactic_sets, "active_set": active_set, "familiarity": familiarity, "ledger": ledger, "fans": fans, "scout_reports": scout_reports, "ground": ground,
	}


static func from_dict(d: Dictionary) -> Club:
	var c := Club.new()
	c.id = str(d["id"])
	c.name = str(d.get("name", c.id))
	c.short_name = str(d.get("short_name", c.name))
	c.city = str(d.get("city", ""))
	c.country_id = str(d.get("country_id", "eng"))
	c.region_id = str(d.get("region_id", "british_isles"))
	c.founded = int(d.get("founded", 0)) if d.get("founded") != null else 0
	c.colors = d.get("colors", c.colors)
	c.emblem_key = str(d.get("emblem_key", ""))
	c.identity = d.get("identity", {})
	c.league_id = str(d.get("league_id", ""))
	c.level = int(d.get("level", 3))
	c.reputation = int(d.get("reputation", 3000))
	c.balance = int(d.get("balance", 5000))
	c.wage_budget_weekly = int(d.get("wage_budget_weekly", 200))
	c.transfer_budget = int(d.get("transfer_budget", 1000))
	c.facilities = d.get("facilities", c.facilities)
	c.constraints = d.get("constraints", {})
	c.manager_name = str(d.get("manager_name", ""))
	c.manager_is_human = bool(d.get("manager_is_human", false))
	c.history = d.get("history", {})
	c.source = str(d.get("source", "filler"))
	c.lineup = d.get("lineup", {})
	c.tactics = SimTactics.merge(d.get("tactics", {}))
	c.board = d.get("board", c.board)
	c.sponsor = d.get("sponsor", {})
	c.season_summary.assign(d.get("season_summary", {}))
	c.knowledge = d.get("knowledge", {})
	c.scouts = d.get("scouts", [])
	c.staff.assign(d.get("staff", {}))
	c.tactic_sets = d.get("tactic_sets", [])
	c.active_set = int(d.get("active_set", 0))
	c.familiarity.assign(d.get("familiarity", {}))
	c.ledger.assign(d.get("ledger", {}))
	c.fans = d.get("fans", {})
	c.scout_reports.assign(d.get("scout_reports", {}))
	c.ground = d.get("ground", {})
	return c


## Builds a club from its pack JSON. Deep-copies `d_in`, so the result never aliases loader data.
static func from_pack(d_in: Dictionary) -> Club:
	var d: Dictionary = d_in.duplicate(true)
	var c := from_dict(d)
	var fin: Dictionary = d.get("finances", {})
	c.balance = int(fin.get("balance", c.balance))
	c.wage_budget_weekly = int(fin.get("wage_budget_weekly", c.wage_budget_weekly))
	c.transfer_budget = int(fin.get("transfer_budget", c.transfer_budget))
	return c


## Familiarity with a formation, 0-100. "free" is always 100; without data, the current formation counts as rehearsed.
func familiarity_of(formation: String) -> float:
	if formation == "free" or formation == "":
		return 100.0
	if familiarity.has(formation):
		return float(familiarity[formation])
	return 80.0 if str(tactics.get("chaser_formation", "free")) == formation else 40.0


## The three saved tactics (created from the current one the first time).
func ensure_tactic_sets() -> void:
	if tactic_sets.size() == 3:
		return
	tactic_sets = []
	for k in ["main", "attack", "defend"]:
		var t: Dictionary = tactics.duplicate(true)
		if k == "attack":
			t["mentality"] = mini(int(t.get("mentality", 10)) + 4, 20)
		elif k == "defend":
			t["mentality"] = maxi(int(t.get("mentality", 10)) - 4, 1)
		tactic_sets.append({"name": k, "tactics": t})
	active_set = 0


## Default youth academy level (1-5) for a club level. [game]
static func base_academy(lvl: int) -> int:
	return [0, 3, 2, 1][clampi(lvl, 1, 3)]


func academy_level() -> int:
	return int(facilities.get("academy", base_academy(level)))

