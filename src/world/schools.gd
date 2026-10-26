class_name Schools
extends RefCounted
## Wizarding schools as a youth pipeline: students in houses, a House Cup simulated with the match engine, and
## graduates who join club youth squads in their region. [FILLER: every house except Hogwarts' and Ilvermorny's]

const STUDENTS_PER_HOUSE := 9
const MIN_AGE := 13
const GRAD_AGE := 18
## Last school year: its students are GRAD_AGE on the 31 August that closes the season and leave at rollover.
const FINAL_YEAR := 7
## Age on 31 August at the start of the first year.
const ENTRY_AGE := GRAD_AGE - FINAL_YEAR
# [FILLER] [HBP 11]
const TRYOUT_MIN := 3
const TRYOUT_MAX := 5
const TEAM_NEED := {"K": 2, "C": 4, "B": 2, "S": 1}


## A youngster's school: the country's if there is one, otherwise the region's.
static func school_for(loader: SimLoader, region_id: String, country_id: String) -> String:
	for sid in loader.schools.keys():
		if str(loader.schools[sid].get("country_id", "")) == country_id:
			return str(sid)
	return str(loader.regions.get(region_id, {}).get("school_id", ""))


static func house_id(school_id: String, house: String) -> String:
	return SimTeam.HOUSE_PREFIX + "%s_%s" % [school_id.trim_prefix("school_"), house.to_lower().replace(" ", "_")]


static func school_of_house(house_id: String) -> String:
	return "school_" + house_id.trim_prefix(SimTeam.HOUSE_PREFIX).get_slice("_", 0)


## School year (1 to FINAL_YEAR) from the age on 31 August of the year the school year began (does not change on birthdays).
static func school_year(p: Player, w: World) -> int:
	return clampi(p.age(WDate.from_ymd(w.season, 8, 31)) - ENTRY_AGE + 1, 1, FINAL_YEAR)


static func is_house(team_id: String) -> bool:
	return team_id.begins_with(SimTeam.HOUSE_PREFIX)


## Birth date, with the given month and day, of a youngster who finished 7th year last June, before school year
## `season`: 17 on 31 August of the year before.
static func leaver_birth_day(season: int, month: int, dom: int) -> int:
	return WDate.from_ymd(season - 19 if month >= 9 else season - 18, month, dom)


## Creates students and the first House Cup for each school that has houses.
static func setup(w: World, loader: SimLoader, rng: SimRng) -> void:
	for sid in loader.schools.keys():
		var sc: Dictionary = loader.schools[sid]
		var houses: Array = sc.get("houses", [])
		if houses.is_empty():
			continue
		var canon: Dictionary = loader.school_students.get(sid, {})
		var colors: Dictionary = canon.get("house_colors", {})
		var regs: Array = sc.get("region_ids", [])
		for h in houses:
			var hid := house_id(sid, h)
			w.houses[hid] = {"name": "%s" % h, "school_id": sid, "house": h,
				"colors": colors.get(h, {"primary": "#888888", "secondary": "#dddddd"}).duplicate(true),
				"country_id": str(sc.get("country_id", "eng")), "region_id": str(regs[0]) if not regs.is_empty() else "british_isles"}
		for d in canon.get("students", []):
			if str(d.get("joins_team", "")) != "" and WDate.from_string(str(d["joins_team"])) > w.today:  # [OotP]
				continue
			var p := _student_from_pack(d, w, loader, sid)
			if p.age(w.today) >= ENTRY_AGE and p.age(w.today) <= GRAD_AGE:
				w.add_player(p)
		var fg: Dictionary = canon.get("filler_gender", {})  # [PoA 13]
		for h in houses:
			fill_house(w, loader, rng, sid, h, str(fg.get(h, "")), false)
		create_cup(w, loader, rng, sid, w.season)


static func _student_from_pack(d: Dictionary, w: World, loader: SimLoader, sid: String) -> Player:
	var pos := str(d.get("position", "C"))
	var positions := {"K": 4, "C": 5, "B": 4, "S": 4}
	positions[pos] = 18
	for k in d.get("positions_extra", {}).keys():
		positions[k] = int(d["positions_extra"][k])
	var p := Player.from_dict({
		"id": d["id"], "first_name": d.get("first_name", ""), "last_name": d.get("last_name", ""),
		"gender": d.get("gender", SimPlayer.Gender.M), "nationality": d.get("nationality", "eng"),
		"birth_day": WDate.from_string(str(d.get("birth_date", "1978-01-01"))), "look": d.get("look", {}).duplicate(true),
		"school_id": sid, "house": d.get("house", ""), "club_id": "", "squad": Player.Squad.SCHOOL, "position": pos, "positions": positions,
	})
	var talent := int(d.get("talent", 2))
	var srng := SimRng.new(hash(p.id))
	_roll_attributes(p, talent, p.age(w.today), srng)
	p.broom = {"model_id": str(d.get("broom", "broom_shooting_star")), "condition": 100.0}
	p.is_captain = bool(d.get("captain", false))
	p.source = str(d.get("source", "canon_book"))
	p.contract = {"wage_weekly": 0, "end_day": 0, "role": "student"}
	p.snapshot_attrs()
	return p


static func _roll_attributes(p: Player, talent: int, age: int, rng: SimRng) -> void:
	var base: float = 2.0 + talent * 0.8 + maxf(age - 13, 0) * 0.5
	var keys: Array = FillerGenerator.KEY_ATTRS[p.position]
	for k in FillerGenerator.ALL_ATTRS:
		var v: float = base + (2.5 if keys.has(k) else -1.0) + rng.gauss(0.0, 1.2)
		p.attrs[k] = clampf(v, 1.0, 20.0)
	for h in FillerGenerator.HIDDEN:
		p.hidden[h] = clampf(rng.gauss(10.5, 3.0), 1.0, 20.0)
	p.pa = clampf(p.ca() + 15.0 + talent * 18.0 + rng.gauss(0.0, 8.0), p.ca(), 185.0)


## Tryouts: new students for the positions the team is short of, up to STUDENTS_PER_HOUSE but always enough to
## field a team. `gender` ("m"/"f") forces the new students' gender. In the manager's own house each new student
## becomes the first tryout candidate for that place instead. `record`: false for the initial squads.
static func fill_house(w: World, loader: SimLoader, rng: SimRng, sid: String, house: String, gender: String = "", record: bool = true) -> void:
	var sc: Dictionary = loader.schools[sid]
	var country := str(sc.get("country_id", "eng"))
	var region := str(sc.get("region_ids", ["british_isles"])[0]) if not sc.get("region_ids", []).is_empty() else "british_isles"
	var names: Dictionary = loader.names_for(region, country)
	var hid := house_id(sid, house)
	var tryouts := record and w.is_school_mode() and w.player_club_id == hid and w.houses.has(hid)
	var old_t: Dictionary = w.houses.get(hid, {}).get("tryouts", {})
	if not old_t.is_empty() and int(old_t.get("season", w.season)) != w.season:
		w.houses[hid].erase("tryouts")
		Inbox.close(w, Inbox.find(w, Inbox.TRYOUTS, hid))
	elif not tryouts and not old_t.is_empty():
		settle_tryouts(w, hid)
	var month := WDate.month(w.today)
	# [GoF 12] [DH] [OotP 13]
	if tryouts and month != 7 and month != 8 and not _has_cup(w, hid):
		return
	var current: Array = students_of(w, sid, house).filter(func(p): return p.ban_until < w.today)
	var count := {"K": 0, "C": 0, "B": 0, "S": 0}
	for p in current:
		count[p.position] += 1
	var places: Array = w.houses[hid].get("tryouts", {}).get("places", []) if tryouts else []
	var pending_ids := {}
	var pending_names := {}
	for pl in places:
		count[str(pl["pos"])] += 1
		for d in pl.get("candidates", []):
			pending_ids[str(d["id"])] = true
			pending_names["%s %s" % [str(d.get("first_name", "")), str(d.get("last_name", ""))]] = true
	var base := current.size() + places.size()
	var need: Dictionary = TEAM_NEED
	var minimum := {"K": 1, "C": 3, "B": 2, "S": 1}
	var idx := 0
	var fresh: Array = []
	for pos in ["K", "C", "C", "C", "B", "B", "S", "C", "K"]:
		if count[pos] >= need[pos]:
			continue
		if base + idx >= STUDENTS_PER_HOUSE and count[pos] >= minimum[pos]:
			continue
		var taken := pending_names.duplicate()
		for q in students_of(w, sid):
			taken[q.name()] = true
		var p := _new_student(w, rng, names, sid, house, pos, gender, country, idx + count[pos] * 10, taken, pending_ids)
		if tryouts:
			pending_ids[p.id] = true
			pending_names[p.name()] = true
			places.append({"pos": pos, "candidates": [p.to_dict()]})
		else:
			w.add_player(p)
			fresh.append(p)
		count[pos] += 1
		idx += 1
	if tryouts and idx > 0:
		var canon := _canon_candidates(w, loader, sid, house, places, pending_ids)
		_open_tryouts(w, hid, places, names, country, pending_ids, pending_names, canon)
	elif record and not fresh.is_empty():
		_record_intake(w, hid, fresh, "auto", 1)


static func _new_student(w: World, rng: SimRng, names: Dictionary, sid: String, house: String, pos: String, gender: String, country: String, id_offset: int, taken: Dictionary, taken_ids: Dictionary) -> Player:
	var p := Player.new()
	var female: bool = gender == SimPlayer.Gender.F if gender != "" else rng.chance(0.45)
	for attempt in 6:
		p.first_name = str(rng.pick(names["first_names_f"] if female else names["first_names_m"]))
		p.last_name = FillerGenerator.female_last(names, str(rng.pick(names["last_names"])), female)
		if not taken.has(p.name()):
			break
	p.gender = SimPlayer.Gender.F if female else SimPlayer.Gender.M
	p.id = "student_%s_%s_%d_%d" % [sid.trim_prefix("school_"), house.to_lower().left(3), w.season, id_offset + rng.irange(0, 999)]
	if w.players.has(p.id) or taken_ids.has(p.id):
		var n := 2
		while w.players.has("%s_%d" % [p.id, n]) or taken_ids.has("%s_%d" % [p.id, n]):
			n += 1
		p.id = "%s_%d" % [p.id, n]
	p.nationality = country
	var age := rng.irange(MIN_AGE, GRAD_AGE - 1)
	p.birth_day = WDate.from_ymd(w.season - age, rng.irange(1, 12), rng.irange(1, 28))
	p.school_id = sid
	p.house = house
	p.club_id = ""
	p.squad = Player.Squad.SCHOOL
	p.position = pos
	p.positions = {"K": 4, "C": 5, "B": 4, "S": 4}
	p.positions[pos] = 16
	_roll_attributes(p, rng.irange(1, 3) if rng.chance(0.85) else 4, age, rng)
	p.broom = {"model_id": str(rng.pick(["broom_shooting_star", "broom_cleansweep_five", "broom_comet_260", "broom_cleansweep_seven"])), "condition": float(rng.irange(60, 100))}
	p.source = "filler"
	p.contract = {"wage_weekly": 0, "end_day": 0, "role": "student"}
	p.snapshot_attrs()
	return p


static func _canon_candidates(w: World, loader: SimLoader, sid: String, house: String, places: Array, taken_ids: Dictionary) -> Array[Player]:  # [OotP 13] [OotP 21] [HBP 11]
	var out: Array[Player] = []
	var open := {}
	for pl in places:
		open[str(pl["pos"])] = true
	for d in loader.school_students.get(sid, {}).get("students", []):
		var pid := str(d.get("id", ""))
		if str(d.get("house", "")) != house or str(d.get("joins_team", "")) == "" or w.players.has(pid) or taken_ids.has(pid):
			continue
		if WDate.season_of(WDate.from_string(str(d["joins_team"]))) != w.season or not open.has(str(d.get("position", "C"))):
			continue
		var p := _student_from_pack(d, w, loader, sid)
		if p.age(w.today) >= ENTRY_AGE and p.age(WDate.from_ymd(w.season, 8, 31)) < GRAD_AGE:
			taken_ids[pid] = true
			out.append(p)
	return out


static func _has_canon(place: Dictionary) -> bool:
	for d in place.get("candidates", []):
		if str(d.get("source", "")) == "canon_book":
			return true
	return false


static func students_of(w: World, sid: String, house: String = "") -> Array[Player]:
	var out: Array[Player] = []
	for p in w.players.values():
		if p.squad == Player.Squad.SCHOOL and p.school_id == sid and (house == "" or p.house == house):
			out.append(p)
	out.sort_custom(func(a, b): return a.ca() > b.ca() if a.ca() != b.ca() else a.id < b.id)
	return out


# [FILLER date] [HBP 11] [OotP]
static func _open_tryouts(w: World, hid: String, places: Array, names: Dictionary, country: String, taken_ids: Dictionary, taken_names: Dictionary, canon: Array[Player] = []) -> void:
	var hd: Dictionary = w.houses[hid]
	var prng := SimRng.derived(w.seed_value, "tryouts:%s:%d:%d" % [hid, w.season, w.today])
	for q in students_of(w, str(hd.get("school_id", ""))):
		taken_names[q.name()] = true
	for pl in places:
		var cands: Array = pl["candidates"]
		if cands.size() > 1:
			continue
		var first := Player.from_dict(cands[0])
		for j in prng.irange(TRYOUT_MIN, TRYOUT_MAX) - 1:
			var q := _new_student(w, prng, names, first.school_id, first.house, str(pl["pos"]), "", country, 0, taken_names, taken_ids)
			q.id = "%s_r%d" % [first.id, j + 1]
			while w.players.has(q.id) or taken_ids.has(q.id):
				q.id += "x"
			taken_ids[q.id] = true
			taken_names[q.name()] = true
			cands.append(q.to_dict())
	for q in canon:
		var target: Dictionary = {}
		for pl in places:
			if str(pl["pos"]) != q.position:
				continue
			if target.is_empty():
				target = pl
			if not _has_canon(pl):
				target = pl
				break
		if not target.is_empty():
			target["candidates"].append(q.to_dict())
	var t: Dictionary = hd.get("tryouts", {})
	if t.is_empty():
		t = {"season": w.season, "places": places}
		var m := WDate.month(w.today)
		if m == 7 or m == 8:
			t["announce_day"] = WDate.from_ymd(w.season, 9, 1)
			t["deadline"] = _nth_saturday(w.season, 9, 2)
		else:
			t["announce_day"] = w.today
			var nxt := _next_fixture_day(w, hid)
			t["deadline"] = mini(w.today + 7, nxt - 1) if nxt >= 0 else w.today + 7
		hd["tryouts"] = t
	else:
		t["places"] = places
	if int(t["deadline"]) < w.today:
		settle_tryouts(w, hid)
		return
	_tryouts_owl(w, hid)


static func _next_fixture_day(w: World, hid: String) -> int:
	var best := -1
	for c in w.competitions.values():
		if not c.has_team(hid):
			continue
		for f in c.fixtures:
			if bool(f.get("played", false)) or int(f["day"]) < w.today:
				continue
			if (str(f["home_id"]) == hid or str(f["away_id"]) == hid) and (best < 0 or int(f["day"]) < best):
				best = int(f["day"])
	return best


static func _tryouts_owl(w: World, hid: String) -> void:
	var hd: Dictionary = w.houses.get(hid, {})
	var t: Dictionary = hd.get("tryouts", {})
	if t.is_empty() or w.today < int(t.get("announce_day", 0)):
		return
	var n_cands := 0
	for pl in t.get("places", []):
		n_cands += pl.get("candidates", []).size()
	if bool(t.get("announced", false)) and Inbox.find(w, Inbox.TRYOUTS, hid) == null:
		return
	t["announced"] = true
	Inbox.ask(w, Inbox.Decision.new(Inbox.TRYOUTS, hid, [Inbox.Choice.new(HOLD_TRYOUTS, "ui.tryouts.hold"), Inbox.Choice.new(LEAVE_TO_CAPTAIN, "ui.tryouts.leave_to_captain", {}, Inbox.PLAIN)]).blocking(),
		&"from.head_of_house", "msg.tryouts.subject", "msg.tryouts.body",
		{"house": Say.key("house." + str(hd.get("house", ""))), "n": Say.num(t.get("places", []).size()), "cands": Say.num(n_cands)})


const HOLD_TRYOUTS := &"tryouts"
const LEAVE_TO_CAPTAIN := &"tryouts_auto"


## HOLD opens the tryouts dialog while the manager still runs the house (it settles there); otherwise, and for
## LEAVE_TO_CAPTAIN, the captain picks now.
static func answer_owl(w: World, d: Inbox.Decision, c: Inbox.Choice) -> Inbox.Reply:
	if c.verb == HOLD_TRYOUTS and w.houses.get(d.key, {}).has("tryouts") and w.player_club_id == d.key:
		return Inbox.Reply.open_dialog(&"tryouts", {"house_id": d.key})
	if c.verb != HOLD_TRYOUTS and c.verb != LEAVE_TO_CAPTAIN:
		return Inbox.Reply.unhandled(d, c)
	settle_tryouts(w, d.key)
	return Inbox.Reply.done()


## "Decide later" in the tryouts dialog: the owl stays open but stops blocking the advance until the deadline.
## `ticked`: the manager's ticked candidate ids, kept for when the dialog opens again.
static func snooze_tryouts(w: World, hid: String, ticked: Array = []) -> void:
	var t: Dictionary = w.houses.get(hid, {}).get("tryouts", {})
	if t.is_empty():
		return
	if not ticked.is_empty():
		t["ticked"] = ticked.duplicate()
	Inbox.snooze(w, Inbox.find(w, Inbox.TRYOUTS, hid), int(t.get("deadline", w.today)))


static func _drop_tryouts(w: World, hid: String) -> void:
	var hd: Dictionary = w.houses.get(hid, {})
	hd.erase("tryouts")
	Inbox.close(w, Inbox.find(w, Inbox.TRYOUTS, hid))


static func _recount_places(w: World, hid: String) -> bool:  # [HBP 11]
	var hd: Dictionary = w.houses.get(hid, {})
	var t: Dictionary = hd.get("tryouts", {})
	var places: Array = t.get("places", [])
	var count := {"K": 0, "C": 0, "B": 0, "S": 0}
	for p in students_of(w, str(hd.get("school_id", "")), str(hd.get("house", ""))):
		if p.ban_until < w.today:
			count[p.position] += 1
	var drop := {}
	for pos in ["K", "C", "B", "S"]:
		var idx: Array = []
		for i in places.size():
			if str(places[i]["pos"]) == pos:
				idx.append(i)
		var allowed := maxi(int(TEAM_NEED[pos]) - int(count[pos]), 0)
		if idx.size() <= allowed:
			continue
		var order: Array = idx.filter(func(i): return not _has_canon(places[i])) + idx.filter(func(i): return _has_canon(places[i]))
		var n_drop: int = idx.size() - allowed
		var keep_i: Array = order.slice(n_drop)
		for i in order.slice(0, n_drop):
			drop[i] = true
			if keep_i.is_empty():
				continue
			for d in places[i].get("candidates", []):
				if str(d.get("source", "")) == "canon_book":
					places[int(keep_i[0])]["candidates"].append(d)
	if drop.is_empty():
		return true
	var left: Array = []
	for i in places.size():
		if not drop.has(i):
			left.append(places[i])
	if left.is_empty():
		_drop_tryouts(w, hid)
		return false
	t["places"] = left
	return true


## Daily: announces the manager's tryouts on their day, lets the captain pick once the deadline has passed, and
## settles tryouts in houses the manager no longer runs.
static func tryouts_daily(w: World) -> void:
	var hids: Array = w.houses.keys()
	hids.sort()
	for hid in hids:
		var t: Dictionary = w.houses[hid].get("tryouts", {})
		if t.is_empty():
			continue
		if not (w.is_school_mode() and w.player_club_id == str(hid)) or w.today > int(t.get("deadline", 0)):
			settle_tryouts(w, str(hid))
		elif w.today < int(t.get("announce_day", 0)):
			continue
		elif not _has_cup(w, str(hid)):
			# [GoF 12] [OotP 13]
			_drop_tryouts(w, str(hid))
		elif _recount_places(w, str(hid)):
			_tryouts_owl(w, str(hid))


## Body key of the head of house's 1 September owl; it announces tryouts only when the house has places open.
static func term_body_key(w: World, hid: String) -> String:
	return "msg.house_term.body" if not w.houses.get(hid, {}).get("tryouts", {}).is_empty() else "msg.house_term.body_no_tryouts"


static func _has_cup(w: World, hid: String) -> bool:
	var sid := str(w.houses.get(hid, {}).get("school_id", ""))
	return w.competitions.has("comp_school_%s_%d" % [sid.trim_prefix("school_"), w.season])


## Open tryouts by position, in K-C-B-S order: {pos: {"need": places, "candidates": Array[Player]}}.
static func tryout_groups(t: Dictionary) -> Dictionary:
	var out := {}
	for pos in ["K", "C", "B", "S"]:
		var pool: Array[Player] = []
		var n := 0
		for pl in t.get("places", []):
			if str(pl["pos"]) != pos:
				continue
			n += 1
			for d in pl.get("candidates", []):
				pool.append(Player.from_dict(d))
		if n > 0:
			out[pos] = {"need": n, "candidates": pool}
	return out


## The captain's order of preference: canon joiners first, then the best flyer now, weighing potential.
## With `w`, the books' starters come before their substitutes.
static func tryout_ranking(pool: Array[Player], w: World = null) -> Array[Player]:  # [OotP 13] [HBP 11]
	var rank := {}
	for q in pool:
		rank[q.id] = (2 if w == null or _canon_starter(w, q) else 1) if q.source == "canon_book" else 0
	var out: Array[Player] = pool.duplicate()
	out.sort_custom(func(a, b):
		var ka: int = rank[a.id]
		var kb: int = rank[b.id]
		if ka != kb:
			return ka > kb
		var sa: float = a.ca() + 0.2 * a.pa
		var sb: float = b.ca() + 0.2 * b.pa
		return sa > sb if sa != sb else a.id < b.id)
	return out


## Settles a house's tryouts: candidates in `chosen` (ids) up to the places of their position, the rest by
## tryout_ranking. `by`: "manager", "captain" or "auto".
static func settle_tryouts(w: World, hid: String, chosen: Array = [], by: String = "captain") -> Array[Player]:
	var added: Array[Player] = []
	var hd: Dictionary = w.houses.get(hid, {})
	var t: Dictionary = hd.get("tryouts", {})
	if t.is_empty() or not _recount_places(w, hid):
		return added
	hd.erase("tryouts")
	var groups := tryout_groups(t)
	var total := 0
	for pos in groups.keys():
		var g: Dictionary = groups[pos]
		var pool: Array[Player] = g["candidates"]
		total += pool.size()
		var picks: Array[Player] = []
		for q in pool:
			if chosen.has(q.id) and picks.size() < int(g["need"]):
				picks.append(q)
		for q in tryout_ranking(pool, w):
			if picks.size() >= int(g["need"]):
				break
			if not picks.has(q):
				picks.append(q)
		for q in picks:
			w.add_player(q)
			if q.source == "canon_book":
				_apply_book_broom(w, q)
			added.append(q)
	_record_intake(w, hid, added, by, total)
	_ensure_house_captain(w, str(hd.get("school_id", "")), str(hd.get("house", "")))
	var mine := w.is_school_mode() and w.player_club_id == hid
	if mine:
		var hc := w.house_club(hid)
		if not human_lineup_valid(w, hid, hc.lineup):
			hc.lineup = best_lineup(w, hid)
	var args: Dictionary[String, Say.Arg] = {"players": Say.list(added.map(func(q): return Say.player(q))), "house": Say.key("house." + str(hd.get("house", "")))}
	var key := "msg.tryouts.outcome_manager" if by == "manager" else "msg.tryouts.outcome_captain"
	var q := Inbox.find(w, Inbox.TRYOUTS, hid)
	if q != null:
		Inbox.close(w, q, Say.phrase(key, args))
	elif not bool(t.get("announced", false)) and mine and by != "auto" and not added.is_empty():
		Inbox.tell(w, &"from.head_of_house", "msg.tryouts.subject", key, args)
	return added


static func _record_intake(w: World, hid: String, players: Array, by: String, of: int) -> void:
	if not w.houses.has(hid):
		return
	var hd: Dictionary = w.houses[hid]
	var rec: Dictionary = hd.get("intake", {})
	if int(rec.get("season", -1)) != w.season:
		rec = {"season": w.season, "members": []}
	for p in players:
		rec["members"].append({"id": p.id, "pos": p.position, "by": by, "of": of})
	hd["intake"] = rec


## This season's newcomers of a house: [{id, pos, by, of}], empty if none.
static func intake_of(w: World, hid: String) -> Array:
	var rec: Dictionary = w.houses.get(hid, {}).get("intake", {})
	return rec.get("members", []) if int(rec.get("season", -1)) == w.season else []


## A house's strength for seeding the House World Cup: sum of the ability of its seven best students.
static func house_strength(w: World, hid: String) -> float:
	var hd: Dictionary = w.houses.get(hid, {})
	var total := 0.0
	var n := 0
	for p in students_of(w, str(hd.get("school_id", "")), str(hd.get("house", ""))):
		if n >= 7:
			break
		total += p.ca()
		n += 1
	return total


## House Cup: single round-robin of 4 houses from November to May [FILLER calendar].
static func create_cup(w: World, loader: SimLoader, rng: SimRng, sid: String, season: int) -> Competition:
	var sc: Dictionary = loader.schools[sid]
	var houses: Array = sc.get("houses", [])
	var c := Competition.new()
	c.id = "comp_school_%s_%d" % [sid.trim_prefix("school_"), season]
	c.name = "Copa de Quidditch de %s" % str(sc.get("short_name", sc.get("name", sid)))
	c.name_en = "%s Quidditch Cup" % str(sc.get("short_name", sc.get("name", sid)))
	c.type = Competition.Type.SCHOOL_CUP
	c.region_id = str(sc.get("region_ids", ["british_isles"])[0]) if not sc.get("region_ids", []).is_empty() else "british_isles"
	c.level = 9
	c.format = {"rounds": 1, "table": "points_scored", "tiebreak": ["points_conceded_asc", "snitch_catches_desc"], "time_cap_minutes": null}
	c.season = season
	c.source = "canon_book"
	var canon: Dictionary = loader.school_students.get(sid, {})
	c.venues = ["school:" + sid]
	for h in houses:
		c.club_ids.append(house_id(sid, h))
	var dates := [_nth_saturday(season, 11, 1), _nth_saturday(season, 11, 3), _nth_saturday(season + 1, 2, 2), _nth_saturday(season + 1, 3, 1), _nth_saturday(season + 1, 4, 2), _nth_saturday(season + 1, 5, 3)]
	var ids: Array = c.club_ids
	var pairs := [[0, 1], [2, 3], [2, 0], [3, 1], [0, 3], [1, 2]]
	for i in pairs.size():
		var pr: Array = pairs[i]
		c.fixtures.append({"id": "%s_%d_%s_%s" % [c.id, i + 1, ids[pr[0]], ids[pr[1]]], "round": i / 2 + 1, "day": int(dates[i]),
			"home_id": str(ids[pr[0]]), "away_id": str(ids[pr[1]]), "venue": str(c.venues[0]), "hour": "11:00", "played": false})
	if bool(w.settings.get("book_events", true)):
		for e in loader.events:
			if str(e.get("kind", "")) != "fixture_result" or not c.id.begins_with(str(e.get("competition_prefix", "#"))):
				continue
			var day := WDate.from_string(str(e.get("date", "1900-01-01")))
			for f in c.fixtures:
				var same := str(f["home_id"]) == str(e["home"]) and str(f["away_id"]) == str(e["away"])
				var swapped := str(f["home_id"]) == str(e["away"]) and str(f["away_id"]) == str(e["home"])
				if same or swapped:
					f["day"] = day
		var scripted_days := {}
		var last_scripted := 0
		for f in c.fixtures:
			if _is_scripted_pair(loader, c, f):
				scripted_days[int(f["day"])] = true
				last_scripted = maxi(last_scripted, int(f["day"]))
		if not scripted_days.is_empty():
			var free_days: Array = []
			for d in dates:
				if not scripted_days.has(int(d)) and int(d) < last_scripted:
					free_days.append(int(d))
			var probe := last_scripted - 7
			while free_days.size() < c.fixtures.size() - scripted_days.size() and probe > int(dates[0]) - 60:
				if not scripted_days.has(probe) and not free_days.has(probe):
					free_days.append(probe)
				probe -= 7
			free_days.sort()
			var k := 0
			for f in c.fixtures:
				if not _is_scripted_pair(loader, c, f) and k < free_days.size():
					f["day"] = free_days[k]
					k += 1
		c.fixtures.sort_custom(func(x, y): return int(x["day"]) < int(y["day"]) if x["day"] != y["day"] else str(x["id"]) < str(y["id"]))
	w.competitions[c.id] = c
	return c


static func _is_scripted_pair(loader: SimLoader, c: Competition, f: Dictionary) -> bool:
	for e in loader.events:
		if str(e.get("kind", "")) != "fixture_result" or not c.id.begins_with(str(e.get("competition_prefix", "#"))):
			continue
		if (str(f["home_id"]) == str(e["home"]) and str(f["away_id"]) == str(e["away"])) or (str(f["home_id"]) == str(e["away"]) and str(f["away_id"]) == str(e["home"])):
			return true
	return false


static func _nth_saturday(year: int, month: int, n: int) -> int:
	var d := WDate.from_ymd(year, month, 1)
	while WDate.weekday(d) != Time.WEEKDAY_SATURDAY:
		d += 1
	return d + 7 * (n - 1)


## A house's simulation team: the seven best available players by position, the books' starters first.
static func sim_team(w: World, hid: String, brooms: Dictionary) -> SimTeam:
	var t := SimTeam.new()
	var hd: Dictionary = w.houses.get(hid, {})
	t.id = hid
	t.name = str(hd.get("name", hid))
	t.tactics = SimTactics.defaults()
	if hd.is_empty():
		return t
	if hd.has("tryouts") and (w.today > int(hd["tryouts"].get("deadline", 0)) or not (w.is_school_mode() and w.player_club_id == hid)):
		settle_tryouts(w, hid)
	var pool := _pick_order(w, students_of(w, str(hd["school_id"]), str(hd["house"])))
	var lineup: Array[Player] = []
	var need := {"K": 1, "C": 3, "B": 2, "S": 1}
	if bool(hd.get("human", false)) and w.player_club_id == hid:
		var hc := w.house_club(hid)
		t.is_human = true
		t.tactics = SimTactics.merge(hc.tactics)
		if human_lineup_valid(w, hid, hc.lineup):
			var ids: Array = [hc.lineup["K"]] + hc.lineup["C"] + hc.lineup["B"] + [hc.lineup["S"]]
			var slots := ["K", "C", "C", "C", "B", "B", "S"]
			for i in ids.size():
				var p: Player = w.player(str(ids[i]))
				var sp := p.to_sim_player(brooms)
				sp.position = slots[i]
				if p.position != slots[i]:
					var fam: float = float(p.positions.get(slots[i], 4.0))
					var pen: float = 0.75 + 0.25 * (fam - 1.0) / 19.0
					for k in sp.attrs.keys():
						sp.attrs[k] = float(sp.attrs[k]) * pen
				if p.is_captain:
					t.captain = sp
				t.players.append(sp)
			if t.captain == null and not t.players.is_empty():
				t.captain = t.players[0]
			return t
	var slot_of := {}
	for p in pool:
		if not p.is_available() or p.age(w.today) < 11 or p.ban_until >= w.today:
			continue
		if need[p.position] > 0:
			lineup.append(p)
			slot_of[p.id] = p.position
			need[p.position] -= 1
	for pos in ["K", "S", "C", "B"]:
		while need[pos] > 0:
			var found: Player = null
			for p in pool:
				if p.is_available() and p.age(w.today) >= ENTRY_AGE and p.ban_until < w.today and not lineup.has(p):
					found = p
					break
			if found == null:
				break
			lineup.append(found)
			slot_of[found.id] = pos
			need[pos] -= 1
	var slots := ["K", "C", "C", "C", "B", "B", "S"]
	lineup.sort_custom(func(a, b): return slots.find(slot_of[a.id]) < slots.find(slot_of[b.id]) if slot_of[a.id] != slot_of[b.id] else a.id < b.id)
	for i in lineup.size():
		var p: Player = lineup[i]
		var slot: String = slot_of[p.id]
		var sp := p.to_sim_player(brooms)
		sp.position = slot
		if p.position != slot:
			var fam: float = float(p.positions.get(slot, 4.0))
			var pen: float = 0.75 + 0.25 * (fam - 1.0) / 19.0
			for k in sp.attrs.keys():
				sp.attrs[k] = float(sp.attrs[k]) * pen
		if p.is_captain:
			t.captain = sp
		t.players.append(sp)
	if t.captain == null and not t.players.is_empty():
		t.captain = t.players[0]
	return t


## Valid human lineup for a house: seven distinct students from that house, available and not in detention.
static func human_lineup_valid(w: World, hid: String, l: Dictionary) -> bool:
	if l.is_empty() or str(l.get("K", "")) == "" or str(l.get("S", "")) == "":
		return false
	if l.get("C", []).size() != 3 or l.get("B", []).size() != 2:
		return false
	var hd: Dictionary = w.houses.get(hid, {})
	var ids: Array = [l["K"]] + l["C"] + l["B"] + [l["S"]]
	var seen := {}
	for pid in ids:
		var p: Player = w.player(str(pid))
		if p == null or seen.has(pid) or p.squad != Player.Squad.SCHOOL or p.house != str(hd.get("house", "")) or p.school_id != str(hd.get("school_id", "")):
			return false
		if not p.is_available() or p.ban_until >= w.today:
			return false
		seen[pid] = true
	return true


## Best automatic lineup for a house, the books' starters first.
static func best_lineup(w: World, hid: String) -> Dictionary:
	var hd: Dictionary = w.houses.get(hid, {})
	var pool := _pick_order(w, students_of(w, str(hd.get("school_id", "")), str(hd.get("house", ""))))
	var lineup := {"K": "", "C": [], "B": [], "S": ""}
	var need := {"K": 1, "C": 3, "B": 2, "S": 1}
	for p in pool:
		if not p.is_available() or p.ban_until >= w.today or need[p.position] <= 0:
			continue
		if p.position == "C" or p.position == "B":
			lineup[p.position].append(p.id)
		else:
			lineup[p.position] = p.id
		need[p.position] -= 1
	for pos in ["K", "S", "C", "B"]:
		while need[pos] > 0:
			var found: Player = null
			for p in pool:
				if p.is_available() and p.ban_until < w.today and not (lineup["K"] == p.id or lineup["S"] == p.id or lineup["C"].has(p.id) or lineup["B"].has(p.id)):
					found = p
					break
			if found == null:
				break
			if pos == "C" or pos == "B":
				lineup[pos].append(found.id)
			else:
				lineup[pos] = found.id
			need[pos] -= 1
	return lineup


static var _book_grads: Dictionary = {}


## Club the books send this final-year student to on leaving school this summer; "" if none or book events are off.
static func book_destination(w: World, p: Player) -> String:  # [GoF 7]
	if not bool(w.settings.get("book_events", true)):
		return ""
	if not _book_grads.has(w.pack):
		var by_key := {}
		var ev = SimLoader.load_json((SimLoader.PACK_DIR % w.pack) + "/events.json")
		if ev is Dictionary:
			for e in ev.get("events", []):
				if str(e.get("kind", "")) == "graduate_to":
					by_key["%s|%d" % [str(e.get("player_id", "")), int(e.get("season", -1))]] = str(e.get("club_id", ""))
		_book_grads[w.pack] = by_key
	return str(_book_grads[w.pack].get("%s|%d" % [p.id, w.season], ""))


static var _book_brooms: Dictionary = {}


static func _apply_book_broom(w: World, p: Player) -> void:  # [OotP 9]
	if not bool(w.settings.get("book_events", true)):
		return
	if not _book_brooms.has(w.pack):
		var by_id := {}
		var ev = SimLoader.load_json((SimLoader.PACK_DIR % w.pack) + "/events.json")
		if ev is Dictionary:
			for e in ev.get("events", []):
				if str(e.get("kind", "")) == "broom":
					var pid := str(e.get("player_id", ""))
					if not by_id.has(pid):
						by_id[pid] = []
					by_id[pid].append([WDate.from_string(str(e.get("date", "1900-01-01"))), str(e.get("model_id", ""))])
		_book_brooms[w.pack] = by_id
	var best := -1
	for pair in _book_brooms[w.pack].get(p.id, []):
		if int(pair[0]) <= w.today and int(pair[0]) > best and str(pair[1]) != "":
			best = int(pair[0])
			p.broom = {"model_id": str(pair[1]), "condition": 100.0}


static var _canon_bench: Dictionary = {}


static func _canon_starter(w: World, p: Player) -> bool:  # [HBP 14, 19]
	if p.source != "canon_book":
		return false
	var key := "%s|%s" % [w.pack, p.school_id]
	if not _canon_bench.has(key):
		var bench := {}
		var path := "%s/schools/%s.json" % [SimLoader.PACK_DIR % w.pack, p.school_id]
		if FileAccess.file_exists(path):
			var sd = SimLoader.load_json(path)
			if sd is Dictionary:
				for d in sd.get("students", []):
					if bool(d.get("reserve", false)):
						bench[str(d.get("id", ""))] = true
		_canon_bench[key] = bench
	return not _canon_bench[key].has(p.id)


static func _pick_order(w: World, pool: Array[Player]) -> Array[Player]:  # [OotP 19]
	var first: Array[Player] = []
	var rest: Array[Player] = []
	for p in pool:
		if _canon_starter(w, p):
			first.append(p)
		else:
			rest.append(p)
	first.append_array(rest)
	return first


## The house a book `cup_champion` event crowns in this school cup, or "". With book events on, rollover() crowns it
## whatever the table says.
static func canon_cup_champion(events: Array, comp_id: String) -> String:
	for e in events:
		if str(e.get("kind", "")) == "cup_champion" and "comp_school_%s_%d" % [str(e["school_id"]).trim_prefix("school_"), int(e["season"])] == comp_id:
			return str(e["champion"])
	return ""


## Season rollover: cup history, graduates to youth squads, yearly growth, new students and a new cup.
static func rollover(w: World, loader: SimLoader, rng: SimRng, ended_season: int, skip_cup: Dictionary = {}, forced: Dictionary = {}, champions: Dictionary = {}) -> Array:
	var graduated: Array = []
	for sid in loader.schools.keys():
		var sc: Dictionary = loader.schools[sid]
		if sc.get("houses", []).is_empty():
			continue
		var cid := "comp_school_%s_%d" % [sid.trim_prefix("school_"), ended_season]
		if w.competitions.has(cid):
			var comp: Competition = w.competitions[cid]
			var st := comp.standings()
			if not st.is_empty():
				var champ := str(st[0]["club_id"])
				var scripted := false
				var human_school: bool = w.is_school_mode() and str(w.houses.get(w.player_club_id, {}).get("school_id", "")) == sid
				if champions.has(sid) and w.houses.has(str(champions[sid])) and not human_school:
					scripted = champ != str(champions[sid])
					champ = str(champions[sid])
				w.history.push_front({"season": ended_season, "competition_id": comp.id, "champion_id": champ, "table": st.slice(0, 4), "scripted": scripted})
				var hd: Dictionary = w.houses.get(champ, {})
				hd["cups"] = int(hd.get("cups", 0)) + 1
			w.competitions.erase(cid)
		var cutoff := WDate.from_ymd(ended_season + 1, 8, 31)
		for p in students_of(w, sid):
			if p.age(cutoff) >= GRAD_AGE or forced.has(p.id):
				var pc: Player.PreContract = p.pre_contract
				var force: Dictionary = forced.get(p.id, {}).duplicate()
				if not force.is_empty():
					force["book"] = true
				var signed_club := pc.club_id if pc != null and pc.graduate else ""
				if force.is_empty() and signed_club != "" and w.clubs.has(signed_club):
					force = {"club_id": signed_club, "squad": Player.Squad.RESERVE}
				p.pre_contract = null
				var g := _graduate(w, loader, rng, p, force)
				if signed_club != "" and str(g.get("club_id", "")) == signed_club:
					Contracts.apply_terms(w, p, pc.terms)
					Economy.book(w, w.clubs[signed_club], "signing_fees", -pc.signing_fee)
				elif signed_club != "" and w.clubs.has(signed_club) and w.clubs[signed_club].manager_is_human:
					var dest := str(g.get("club_id", ""))
					Inbox.tell(w, &"from.club_secretary", "msg.graduate_void.subject", "msg.graduate_void.body", {"player": Say.player(p), "club": (Say.team(w, dest) if dest != "" else Say.key("ui.free_agent"))})
				graduated.append(g)
				continue
			if not sc.get("houses", []).is_empty():
				p.snapshot_attrs()
				continue
			_grow(p, rng)
		_canon_joiners(w, loader, sid, ended_season + 1)
		for h in sc.get("houses", []):
			fill_house(w, loader, rng, sid, str(h))
			_ensure_house_captain(w, sid, str(h))
		if not bool(skip_cup.get(sid, false)):
			create_cup(w, loader, rng, sid, ended_season + 1)
	return graduated


static func _canon_joiners(w: World, loader: SimLoader, sid: String, season: int) -> void:  # [OotP 13] [OotP 21]
	for d in loader.school_students.get(sid, {}).get("students", []):
		if str(d.get("joins_team", "")) == "" or w.players.has(str(d["id"])):
			continue
		if w.is_school_mode() and w.player_club_id == house_id(sid, str(d.get("house", ""))):
			continue
		if WDate.season_of(WDate.from_string(str(d["joins_team"]))) != season:
			continue
		var p := _student_from_pack(d, w, loader, sid)
		if p.age(w.today) >= ENTRY_AGE and p.age(w.today) <= GRAD_AGE:
			w.add_player(p)


static func _ensure_house_captain(w: World, sid: String, house: String) -> void:
	var st := students_of(w, sid, house)
	for p in st:
		if p.is_captain:
			return
	var best: Player = null
	for p in st:
		if best == null or p.age(w.today) > best.age(w.today) or (p.age(w.today) == best.age(w.today) and p.ca() > best.ca()):
			best = p
	if best != null:
		best.is_captain = true


static func _grow(p: Player, rng: SimRng) -> void:
	var headroom: float = maxf(p.pa - p.ca(), 0.0)
	var keys: Array = FillerGenerator.KEY_ATTRS[p.position]
	for k in FillerGenerator.ALL_ATTRS:
		var step: float = clampf(headroom / 60.0, 0.2, 1.4) * (1.3 if keys.has(k) else 0.8) + rng.gauss(0.0, 0.25)
		p.attrs[k] = clampf(float(p.attrs[k]) + maxf(step, -0.2), 1.0, 20.0)
	p.snapshot_attrs()


static func _graduate(w: World, loader: SimLoader, rng: SimRng, p: Player, force: Dictionary = {}) -> Dictionary:
	var house := p.house
	var out := _graduate_core(w, loader, rng, p, force)
	out["house"] = house
	return out


static func _graduate_core(w: World, loader: SimLoader, rng: SimRng, p: Player, force: Dictionary) -> Dictionary:
	p.house = ""
	p.is_captain = false
	if not force.is_empty() and w.clubs.has(str(force.get("club_id", ""))):
		var cid := str(force["club_id"])  # [GoF 7] [JKR]
		var squad := str(force.get("squad", Player.Squad.RESERVE))
		if p.age(w.today) < 19 and not (bool(force.get("book", false)) and squad == Player.Squad.FIRST):
			squad = Player.Squad.YOUTH
		w.move_player(p, cid, squad)
		var wage := int(maxf(p.ca() / 15.0, 4.0))
		if squad == Player.Squad.FIRST:
			wage = maxi(wage, int(Contracts.demand(w, p, w.clubs[cid], "free").get("wage", 0)))
		p.contract = {"wage_weekly": wage, "end_day": WDate.from_ymd(w.season + 2, 6, 30), "role": "first_team" if squad == Player.Squad.FIRST else "rotation"}
		return {"player_id": p.id, "club_id": cid}
	var sc: Dictionary = loader.schools.get(p.school_id, {})
	var regions: Array = sc.get("region_ids", []).duplicate()
	for rid in loader.regions.keys():
		if str(loader.regions[rid].get("school_id", "")) == p.school_id and not regions.has(rid):
			regions.append(rid)
	var candidates: Array = []
	for c in w.clubs_sorted():
		if regions.has(c.region_id) and w.club_players(c.id).size() < 17 and not (c.is_women_only() and p.gender != SimPlayer.Gender.F):
			candidates.append(c)
	var dest: Club = null
	if not candidates.is_empty():
		var ca := p.ca()
		if ca >= 95.0:
			var top: Array = candidates.filter(func(c): return c.level == 1)
			dest = rng.pick(top if not top.is_empty() else candidates)
		elif ca >= 70.0 or rng.chance(0.5):
			dest = rng.pick(candidates)
	if dest != null:
		w.move_player(p, dest.id, "youth" if p.ca() < 95.0 else "reserve")
		p.contract = {"wage_weekly": int(maxf(p.ca() / 20.0, 3.0)), "end_day": WDate.from_ymd(w.season + 2, 6, 30), "role": "youth"}
		return {"player_id": p.id, "club_id": dest.id}
	w.move_player(p, "", "free")
	p.free_since = w.season
	p.contract = {"wage_weekly": 3, "end_day": 0, "role": "youth"}
	return {"player_id": p.id, "club_id": ""}
