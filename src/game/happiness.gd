class_name Happiness  # [game]
extends RefCounted

const COMPLAINT_AT := -25.0
const COMPLAINT_GAP := 45


static func total(p: Player) -> float:
	var t := 0.0
	for k in ["minutes", "contract", "listed"]:
		t += float(p.happiness.get(k, 0.0))
	return t


## Main cause of unhappiness ("" if content).
static func main_worry(p: Player) -> String:
	var worst := ""
	var low := -4.0
	for k in ["minutes", "contract", "listed"]:
		if float(p.happiness.get(k, 0.0)) < low:
			low = float(p.happiness.get(k, 0.0))
			worst = k
	return worst


static func weekly(w: World, club: Club) -> void:
	var in_season := has_official_fixture_near(w, club.id, 21)
	for p in w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
		if p.is_on_loan() or p.squad == Player.Squad.SCHOOL:
			continue
		var role := str(p.contract.get("role", "rotation"))
		var starter := Economy.lineup_has(club, p.id)
		var minutes := float(p.happiness.get("minutes", 0.0))
		if starter:
			minutes = minf(minutes + 2.0, 5.0)
		elif p.injury_days > 0 or not in_season:
			pass
		elif role == "star" or role == "first_team":
			minutes = maxf(minutes - 3.0, -20.0)
		elif role == "rotation":
			minutes = maxf(minutes - 1.0, -12.0)
		else:
			minutes = minf(minutes + 1.0, 0.0)
		if not p.promise.is_empty():
			minutes = maxf(minutes, -8.0)
		p.happiness["minutes"] = minutes
		var contract := float(p.happiness.get("contract", 0.0))
		var ends := int(p.contract.get("end_day", 0))
		var important := Contracts.deserved_role(w, p, club) in ["star", "first_team"]
		if important and ends > 0 and ends - w.today < 182 and p.pre_contract == null:
			contract = maxf(contract - 2.0, -15.0)
		else:
			contract = minf(contract + 2.0, 0.0)
		p.happiness["contract"] = contract
		var listed := float(p.happiness.get("listed", 0.0))
		if p.transfer_listed and not bool(p.happiness.get("asked_out", false)):
			listed = maxf(listed - 1.0, -8.0)
		else:
			listed = minf(listed + 2.0, 0.0)
		p.happiness["listed"] = listed
		var t := total(p)
		p.morale = clampf(p.morale + clampf(t / 20.0, -1.5, 1.0), 0.0, 100.0)
		if t <= COMPLAINT_AT and w.today - p.last_complaint_day > COMPLAINT_GAP:
			_complain(w, p)


## Does the club have an official (non-friendly) fixture, played or not, within `days` days of today?
static func has_official_fixture_near(w: World, club_id: String, days: int) -> bool:
	for c in w.competitions.values():
		if c.type == Competition.Type.FRIENDLY:
			continue
		for f in c.fixtures:
			if absi(int(f["day"]) - w.today) <= days and (str(f["home_id"]) == club_id or str(f["away_id"]) == club_id):
				return true
	return false


static func _complain(w: World, p: Player) -> void:
	p.last_complaint_day = w.today
	var worry := main_worry(p)
	if worry == "":
		worry = "minutes"
	Inbox.ask(w, Inbox.Decision.new(Inbox.COMPLAINT, p.id, [Inbox.Choice.new(PROMISE, "ui.action.complaint_promise", {}, Inbox.PLAIN),
			Inbox.Choice.go("ui.action.complaint_renew", &"player", {"player_id": p.id}),
			Inbox.Choice.new(LIST, "ui.action.complaint_list", {}, Inbox.PLAIN), Inbox.Choice.new(IGNORE, "ui.action.complaint_ignore", {}, Inbox.PLAIN)]),
		&"from.player", "msg.complaint.subject", "msg.complaint.body." + worry, {"player": Say.player(p)})


const PROMISE := &"complaint_promise"
const LIST := &"complaint_list"
const IGNORE := &"complaint_ignore"


## The manager's answer to a complaint. A player who left meanwhile makes it moot; asking out goes to the Prophet.
static func answer_owl(w: World, engine: GameEngine, d: Inbox.Decision, c: Inbox.Choice) -> Inbox.Reply:
	var p: Player = w.player(d.key)
	if p == null or p.club_id != w.player_club_id or p.is_on_loan():
		return Inbox.Reply.done().with_toast(Say.phrase("ui.complaint.stale", {"name": Say.player(p) if p != null else Say.plain(str(w.former_names.get(d.key, "")))}))
	var key := answer(w, p, str(c.verb))
	if key == "ui.complaint.wants_out":
		engine._append_news_item(NewsGenerator.item("news.wants_out", 3, {"player": Say.player(p), "club": Say.team(w, p.club_id), "day": Say.num(w.today)}, {"clubs": [p.club_id]}))
	return Inbox.Reply.done().with_toast(Say.phrase(key, {"player": Say.player(p)}))


## Reply to a complaint. Returns the result text key.
static func answer(w: World, p: Player, kind: String) -> String:
	match kind:
		"complaint_promise":
			var key := Press.talk(w, p, "promise")
			p.happiness["minutes"] = maxf(float(p.happiness.get("minutes", 0.0)), -8.0)
			p.complaints_ignored = 0
			return key
		"complaint_list":
			p.transfer_listed = true
			p.loan_listed = false
			p.happiness["asked_out"] = 1.0
			p.happiness["listed"] = 0.0
			p.morale = clampf(p.morale + 4.0, 0.0, 100.0)
			p.complaints_ignored = 0
			return "ui.complaint.listed"
		"complaint_ignore":
			p.complaints_ignored += 1
			p.morale = clampf(p.morale - 6.0, 0.0, 100.0)
			if p.complaints_ignored >= 2:
				p.transfer_listed = true
				p.happiness["asked_out"] = 1.0
				p.complaints_ignored = 0
				return "ui.complaint.wants_out"
			return "ui.complaint.ignored"
	return ""
