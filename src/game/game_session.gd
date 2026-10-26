extends Node
## "Game" autoload: current session (loader, world, engine). The UI talks to this.

signal world_changed
signal day_advanced(info: Dictionary)
signal match_ready
signal message(text: String)
## Web: emitted once if another tab already has the game open (this one stays read-only).
signal instance_blocked_changed
## The player changed the game without a world_changed (training, line-up, an answered owl…): main arms the
## "unsaved changes" guard. Emitted by mark_dirty.
signal dirtied

var loader: SimLoader = SimLoader.new()
var world: World = null
var engine: GameEngine = null
var save_name: String = ""
var loaded: bool = false
var compare_player_id: String = ""
## Web: the game is already open in another tab of this browser, so this tab must not write.
var instance_blocked: bool = false


func _init() -> void:
	Say.session = self


func _ready() -> void:
	Settings.load_settings()
	TranslationServer.set_locale(Settings.language)
	ThemeBuilder.update_cjk()
	loader.load_all("1993-94")
	loaded = true
	Platform.claim_single_instance(_tr("ui.web.other_tab"), func():
		instance_blocked = true
		instance_blocked_changed.emit())


func set_language(code: String) -> void:
	TranslationServer.set_locale(code)
	ThemeBuilder.update_cjk()
	Settings.language = code
	Settings.save_settings()
	if world != null:
		world.settings["language"] = code


func has_game() -> bool:
	return world != null


## Called after any player action that changes the game without emitting world_changed, so leaving or loading
## another save asks first. Nothing to lose without a game (title and New Game screens).
func mark_dirty() -> void:
	if world != null:
		dirtied.emit()


## Closes the in-memory game (back to the main menu). Anything unsaved is lost.
func close_game() -> void:
	world = null
	engine = null
	_emit_changed()


func new_game(club_id: String, manager_name: String, nationality: String, seed_value: int) -> void:
	world = WorldGenerator.new(loader).generate(seed_value)
	var start_rep := 350
	if world.clubs.has(club_id):
		start_rep = Career.start_reputation(world.clubs[club_id])
	elif club_id != "":
		start_rep = 300
	world.manager = {"name": manager_name, "nationality": nationality, "reputation": start_rep, "career": [], "seasons": 0, "titles": 0}
	world.career_id = new_career_id()
	engine = GameEngine.new(loader, world)
	engine.auto_fix_lineup = false
	_autosaved_match = ""
	compare_player_id = ""
	if club_id == "":
		world.manager_unemployed = true
		save_name = _pick_slot()
		Inbox.tell(world, &"from.club_secretary", "msg.start_unemployed.subject", "msg.start_unemployed.body", {"manager": Say.plain(manager_name)})
		engine._job_offers(3, false)
	elif Schools.is_house(club_id):
		world.player_club_id = club_id
		var house: Dictionary = world.houses[club_id]
		house["human"] = true
		house["board"] = {"objective": "house_cup", "objective_min_pos": 1, "confidence": 60.0}
		house["lineup"] = Schools.best_lineup(world, club_id)
		world.manager["career"] = [{"club_id": club_id, "from": world.season}]
		save_name = _pick_slot()
		Inbox.tell(world, &"from.head_of_house", "msg.house_welcome.subject", "msg.house_welcome.body", {"manager": Say.plain(manager_name), "house": Say.club(world.my_club())})
	else:
		world.player_club_id = club_id
		world.manager["career"] = [{"club_id": club_id, "from": world.season}]
		var club := world.my_club()
		club.manager_is_human = true
		club.manager_name = manager_name
		save_name = _pick_slot()
		Inbox.tell(world, &"from.board", "msg.welcome.subject", "msg.welcome.body", {"manager": Say.plain(manager_name), "club": Say.club(club), "objective": Say.key("objective." + str(club.board.get("objective", ""))), "balance": Say.money(club.balance)})
	_tutorial(club_id)
	_emit_changed()


func _tutorial(club_id: String) -> void:
	if not Settings.tutorial or club_id == "":
		return
	var school := Schools.is_house(club_id)
	var from := "from.head_of_house" if school else "from.club_secretary"
	var steps := ["lineup", "squad", "training", "calendar", "market"] if not school else ["lineup", "squad", "training", "calendar", "schools"]
	steps.reverse()
	for i in steps.size():
		var k: String = str(steps[i])
		var n := steps.size() - i
		var body_key := "msg.tutorial.%s.body" % k
		if school and (k == "squad" or k == "calendar"):
			body_key = "msg.tutorial.%s.school.body" % k
		Inbox.tell(world, from, "msg.tutorial.%s.subject" % k, body_key, {"n": Say.num(n)}, 0, k)


func load_game(name: String) -> bool:
	var w := SaveManager.load(name)
	if w == null:
		return false
	world = w
	if SaveManager.is_autosave_slot(name):
		save_name = manual_slot()
	else:
		save_name = name
		world.manager["save_slot"] = name
	engine = GameEngine.new(loader, world)
	engine.auto_fix_lineup = false
	_autosaved_match = ""
	compare_player_id = ""
	TranslationServer.set_locale(Settings.language)
	ThemeBuilder.update_cjk()
	_emit_changed()
	return true


## A random career id (16 hex characters). Uses the OS random source, not the world RNG, so simulations stay the same.
static func new_career_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()


## The slot of this career's manual saves (Ctrl+S, the autosave never writes here): the one it was created or last
## saved in (`manager.save_slot`), else one derived from the club and free for this career.
func manual_slot() -> String:
	var kept := str(world.manager.get("save_slot", ""))
	return kept if kept != "" else _pick_slot()


func _pick_slot() -> String:
	var mc := world.my_club()
	var base := mc.short_name.to_lower().replace(" ", "_") if mc != null else _career_slot(str(world.manager.get("name", "")))
	var slot := SaveManager.free_slot_for(base, world.career_id)
	world.manager["save_slot"] = slot
	return slot


func _career_slot(manager_name: String) -> String:
	return ("career_" + manager_name.to_lower().replace(" ", "_")).left(SaveManager.SLOT_NAME_MAX_CHARS)


## Saves as `name` ("" = the current save). A name the save list could not show or that the autosave would overwrite
## ("_…", "autosave_…", a name Windows refuses) is refused with ERR_INVALID_PARAMETER (SaveManager.clean_save_name);
## one that holds another career's save, with ERR_ALREADY_EXISTS (never overwritten). Saving to the current slot when
## another career has taken it since (two games started with the same club) moves this one to a free slot instead.
func save_game(name: String = "") -> Error:
	if world == null:
		return ERR_UNCONFIGURED
	if name != "":
		var clean := SaveManager.clean_save_name(name)
		if clean == "":
			return ERR_INVALID_PARAMETER
		if _other_career_in(clean):
			return ERR_ALREADY_EXISTS
		save_name = clean
	else:
		if save_name == "":
			save_name = manual_slot()
		if _other_career_in(save_name):
			save_name = SaveManager.free_slot_for(save_name, world.career_id)
	world.manager["save_slot"] = save_name
	return SaveManager.save(world, save_name)


func _other_career_in(slot: String) -> bool:
	var other := SaveManager.slot_career_id(slot)
	return other != "" and other != world.career_id


func _emit_changed() -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		world_changed.emit.call_deferred()
	else:
		world_changed.emit()


## Wrap-up of a day-by-day advance driven from the UI (main._continue): same signals as continue_game.
func after_advance(r: Dictionary) -> void:
	autosave()
	day_advanced.emit(r)
	if r["reason"] == "match":
		match_ready.emit()
	_emit_changed()


## Advances to the next own match or a message that requires an answer.
func continue_game() -> Dictionary:
	if engine == null:
		return {"stopped": true, "reason": "no_game"}
	var r := engine.advance_until_event(90)
	day_advanced.emit(r)
	if r["reason"] == "match":
		match_ready.emit()
	_emit_changed()
	return r


func advance_one_day() -> Dictionary:
	var r := engine.advance_day()
	day_advanced.emit(r)
	if r["reason"] == "match":
		match_ready.emit()
	_emit_changed()
	return r


func my_club() -> Club:
	return world.my_club() if world else null


func league() -> Competition:
	return world.league_of(world.player_club_id) if (world and world.player_club_id != "") else null


## Translation with {key} parameters, for live UI text whose values are already text (stored text renders through
## Say.render). A whole float from a save shows as the int it was.
func t(key: String, params: Dictionary = {}) -> String:
	var s := _tr(key)
	for k in params.keys():
		var v: Variant = params[k]
		s = s.replace("{%s}" % k, str(int(v)) if v is float and v == floorf(v) and absf(v) < 1e15 else str(v))
	return s


## "%d" text with a singular form: `key.one` when n is 1 and the language has one (else `key`).
func tn(key: String, n: int) -> String:
	var one := key + ".one"
	return (_tr(one) if n == 1 and _tr(one) != one else _tr(key)) % n


## Name of a match venue: the home side's ground ("ground:<club>") or a competition venue.
func venue_text(f: Dictionary) -> String:
	var v := str(f.get("venue", ""))
	if v.begins_with("ground:"):
		var gc: Club = world.club(v.substr(7)) if world != null else null
		return Grounds.name_of(gc) if gc != null else ""
	if v.begins_with("school:"):
		return _school_venue(v)
	return _tr(v)


func _school_venue(v: String) -> String:
	var sid := v.substr(7)
	var sname := school_name(sid) if loader else sid
	return _tr("venue.school").replace("{school}", sname)


func club_name(id: String) -> String:
	var c: Club = world.club(id) if world else null
	return c.name if c else (world.team_name(id) if world else id)


## Real club or a transient one (national team, school house) with name and colours, for the UI.
func team_as_club(id: String) -> Club:
	var c: Club = world.club(id) if world else null
	if c != null:
		return c
	var t := Club.new()
	t.id = id
	t.name = world.team_name(id) if world else id
	t.short_name = t.name
	if world != null and world.national_teams.has(id):
		t.colors = world.national_teams[id].get("colors", t.colors)
	elif world != null and world.houses.has(id):
		t.colors = world.houses[id].get("colors", t.colors)
	return t


func player_name(id: String) -> String:
	var p: Player = world.player(id) if world else null
	if p != null:
		return p.name()
	if world != null and world.former_names.has(id):
		return str(world.former_names[id])
	return ""


func date_text(day: int) -> String:
	var d := WDate.to_dict(day)
	var months := _tr("ui.months").split(",")
	var days := _tr("ui.weekdays").split(",")
	return t("ui.date_format", {"wd": days[int(d["weekday"])], "d": int(d["day"]), "m": int(d["month"]), "month": months[int(d["month"]) - 1], "y": int(d["year"])})


func galleons(n: int) -> String:
	return "%s G" % _thousands(n)


## One line for a save in the load lists: its name, then the in-game date, "saved 5 min ago", club and manager.
func save_label(m: Dictionary) -> String:
	var parts := PackedStringArray()
	var today := str(m.get("today", ""))
	if today.get_slice_count("-") == 3:
		parts.append(_numeric_date(WDate.from_string(today)))
	var ago := saved_ago(m)
	if ago != "":
		parts.append(ago)
	for k in ["club_name", "manager"]:
		if str(m.get(k, "")) != "":
			parts.append(str(m[k]))
	return "%s — %s" % [str(m.get("name", m.get("dir", ""))), " · ".join(parts)]


func _numeric_date(day: int) -> String:
	var loc := TranslationServer.get_locale()
	var y := WDate.year(day)
	if loc.begins_with("ja") or loc.begins_with("zh"):
		return "%d/%s" % [y, short_date(day)]
	if loc.begins_with("de"):
		return "%s%d" % [short_date(day), y]
	if loc.begins_with("nl"):
		return "%s-%d" % [short_date(day), y]
	return "%s/%d" % [short_date(day), y]


## How long ago a save was written ("saved 5 min ago"), from its meta; "" if it has no time.
func saved_ago(m: Dictionary) -> String:
	if not (m.get("saved_unix") is float or m.get("saved_unix") is int):
		return ""
	var secs := int(Time.get_unix_time_from_system()) - int(m["saved_unix"])
	if secs < 60:
		return _tr("ui.saves.ago_now")
	if secs < 3600:
		return tn("ui.saves.ago_min", secs / 60)
	if secs < 86400:
		return tn("ui.saves.ago_hours", secs / 3600)
	return tn("ui.saves.ago_days", secs / 86400)


## Day and month for lists (inbox): 21/10, 21.10., 21-10, 10/21 (Japanese and Chinese put the month first).
func short_date(day: int) -> String:
	var d := WDate.to_dict(day)
	var loc := TranslationServer.get_locale()
	if loc.begins_with("ja") or loc.begins_with("zh"):
		return "%d/%d" % [int(d["month"]), int(d["day"])]
	if loc.begins_with("de"):
		return "%02d.%02d." % [int(d["day"]), int(d["month"])]
	if loc.begins_with("nl"):
		return "%02d-%02d" % [int(d["day"]), int(d["month"])]
	return "%02d/%02d" % [int(d["day"]), int(d["month"])]


## A school's name in the UI language (school.<id>.name / .short, the books' official translations), else the
## pack's own name.
func school_name(sid: String, short: bool = true) -> String:
	var key := "school.%s.%s" % [sid, "short" if short else "name"]
	var t := _tr(key)
	if t != key:
		return t
	var sc: Dictionary = loader.schools.get(sid, {}) if loader != null else {}
	return str(sc.get("short_name" if short else "name", sid))


## A sponsor's name in the UI language, else as stored.
func sponsor_name(stored: String) -> String:
	var key := str(SPONSOR_KEYS.get(stored, ""))
	if key == "":
		return stored
	var t := _tr(key)
	return t if t != key else stored


const SPONSOR_KEYS := {"Nimbus Racing Broom Company": "sponsor.nimbus", "Cleansweep Broom Company": "sponsor.cleansweep",
	"Comet Trading Company": "sponsor.comet", "Butterbeer": "sponsor.butterbeer", "Gringotts": "sponsor.gringotts",
	"Gladrags Wizardwear": "sponsor.gladrags", "Mrs Skower's All-Purpose Magical Mess Remover": "sponsor.mrs_skower",
	"Bluebottle": "sponsor.bluebottle", "Quality Quidditch Supplies": "sponsor.quality_quidditch", "Honeydukes": "sponsor.honeydukes"}


## Position as each language writes it (1st, 1.º, 1., 1er, 1-е, 1位…).
func ordinal(n: int) -> String:
	var loc := TranslationServer.get_locale()
	if loc.begins_with("en"):
		var suffix := "th"
		if n % 100 < 11 or n % 100 > 13:
			suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]
		return "%d%s" % [n, suffix]
	if loc.begins_with("de"):
		return "%d." % n
	if loc.begins_with("fr"):
		return "1er" if n == 1 else "%de" % n
	if loc.begins_with("nl"):
		return "%de" % n
	if loc.begins_with("ru"):
		return "%d-е" % n
	if loc.begins_with("ja"):
		return "%d位" % n
	if loc.begins_with("zh"):
		return "第%d名" % n
	# Spanish writes 8.º (RAE); Portuguese and Italian 8º.
	if loc.begins_with("es"):
		return "%d.º" % n
	return "%dº" % n


func _thousands(n: int) -> String:
	var loc := TranslationServer.get_locale()
	var sep := "."
	if loc.begins_with("en") or loc.begins_with("ja") or loc.begins_with("zh"):
		sep = ","
	elif loc.begins_with("fr") or loc.begins_with("ru"):
		sep = "\u00a0"
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = sep + out
	return ("-" if n < 0 else "") + out


## Human club's knowledge level of a player's region: 0 = none, 1 = ranges, 2 = exact.
func knowledge_level(p: Player) -> int:
	var me := my_club()
	if me == null:
		return 2
	if p.club_id == me.id or p.loan_owner_id() == me.id:
		return 2
	if world.is_school_mode() and p.squad == Player.Squad.SCHOOL:
		return 2 if Schools.house_id(p.school_id, p.house) == me.id else 1
	if world.is_school_mode():
		return 1
	var rep: Dictionary = me.scout_reports.get(p.id, {})
	if rep.has("day") and world.today - int(rep["day"]) < 365:
		return 2
	var region := loader.region_of_country(p.nationality)
	if p.club_id != "" and world.clubs.has(p.club_id):
		region = world.clubs[p.club_id].region_id
	var k: float = float(me.knowledge.get(region, 0.0))
	if k >= 80.0:
		return 2
	if k >= 40.0:
		return 1
	return 0


## Attribute text depending on knowledge: exact, range or "?".
func attr_text(p: Player, key: String) -> String:
	var v := float(p.attrs.get(key, 8.0))
	match knowledge_level(p):
		2:
			return str(int(floor(v)))
		1:
			var lo := maxi(int(floor(v)) - 2, 1)
			return "%d-%d" % [lo, mini(lo + 4, 20)]
		_:
			return "?"


## Translation that also works from the loading thread (Node.tr can only be used on the main thread).
func _tr(key: String) -> String:
	return str(TranslationServer.translate(key))


## Web: once per finished season, the career summary for the ranking (Platform.report_season).
func report_finished_season() -> void:
	if world == null or not Platform.is_web() or world.career_id == "":
		return
	var finished := world.season - 1
	if finished < int(Career.RULES["first_season"]) or int(world.manager.get("reported_season", 0)) >= finished:
		return
	world.manager["reported_season"] = finished
	Platform.report_season(season_report(finished))


## The summary of a finished season sent for the ranking.
func season_report(finished: int) -> Dictionary:
	var club := my_club()
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	return {
		"career_id": world.career_id, "season": finished, "reported_on": WDate.to_iso(world.today),
		"reputation": int(world.manager.get("reputation", 0)), "mode": "school" if world.is_school_mode() else "club",
		"club_id": club.id if club != null else null, "club_name": club.name if club != null else null,
		"titles": int(world.manager.get("titles", 0)), "seasons": int(world.manager.get("seasons", 0)),
		"game_version": version if version != "" else null,
	}


## Autosave: once a month and after every match the manager plays, in two alternating slots. `after_match` saves
## whatever the month.
func autosave(after_match: bool = false) -> void:
	report_finished_season()
	if world == null or not bool(world.settings.get("autosave", true)):
		return
	var last := int(world.settings.get("last_autosave", -1))
	if not after_match and last >= 0 and WDate.month(last) == WDate.month(world.today) and WDate.year(last) == WDate.year(world.today):
		return
	world.settings["last_autosave"] = world.today
	var slot := int(world.settings.get("autosave_slot", 0)) % 2 + 1
	world.settings["autosave_slot"] = slot
	SaveManager.save(world, SaveManager.AUTOSAVE_SLOTS[slot - 1])


var _autosaved_match := ""


## Autosave after a match of the manager's, once per match, when it is over and no other match of the day is
## waiting. `skip` only notes the match (the holiday, whose loop autosaves).
func autosave_after_match(skip: bool = false) -> void:
	if engine == null or engine.pending_match != null or engine.last_match == null:
		return
	var fid := str(engine.last_match.fixture.get("id", ""))
	if fid == "" or fid == _autosaved_match:
		return
	_autosaved_match = fid
	if not skip:
		autosave(true)

