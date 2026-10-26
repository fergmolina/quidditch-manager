class_name GameEngine
extends RefCounted
## Game engine: advances the calendar and processes everything that happens each day.
## The human club's match is played separately (pending_match) so the UI can step in.

const MAX_SQUAD := 17
const SCHOOL_TRAINING_SCALE := 0.35
const MIN_PER_POSITION := {"K": 2, "C": 5, "B": 3, "S": 2}
## A club whose requirement (Career.club_requirement) exceeds the manager's reputation by more than this never answers an
## application; the Manager screen greys those vacancies out.
const APPLICATION_REACH := 1.4
## A club whose requirement is within this factor of the manager's reputation is in reach: an application is likely
## to succeed, and the club may approach the manager with an offer.
const OFFER_REACH := 1.05
## The competitions screen still shows last season's brackets after the rollover.
const FINISHED_CUP_SEASONS_KEPT := 1

var loader: SimLoader
var w: World


## The human club's match prepared for the UI to play; null while none is pending.
class PendingMatch:
	var fixture: Dictionary
	var comp_id: String
	var home: SimTeam
	var away: SimTeam
	var sim: MatchSim


## The last match the human club played, for the post-match and press screens; null before the first.
class PlayedMatch:
	var result: MatchResult
	var home: SimTeam
	var away: SimTeam
	var fixture: Dictionary
	var comp_id: String

var pending_match: PendingMatch = null
var last_match: PlayedMatch = null
var last_day_log: Array = []
var prof: Dictionary = {"matches_ms": 0, "daily_ms": 0, "weekly_ms": 0, "monthly_ms": 0, "matches": 0}
## The summer between two seasons, alive while _season_rollover runs: the human's verdict, the requirement of the
## club that sacked them after a relegation (-1 otherwise, it caps the summer offers) and the job offers held back
## until _flush_job_offers, once AI cash has settled.
class Rollover:
	var verdict := ""
	var sacked_requirement := -1
	var deferred: Array[Club] = []

var _rollover: Rollover = null


## Matches kept in each player's match_log: the manager's own players, everyone else.
const MATCH_LOG_OWN := 60
const MATCH_LOG_OTHERS := 20
## Lowest condition a player leaves a match with.
const POST_MATCH_CONDITION_FLOOR := 25.0

func _init(loader_in: SimLoader, world_in: World) -> void:
	loader = loader_in
	w = world_in


func rng() -> SimRng:
	return w.rng()


## Human lineup with injured players or gaps on match day: with `true` (tools and tests) the assistant
## picks the best one and the match goes ahead; with `false` (the game) the advance stops with reason "lineup" until
## the manager fixes it by hand.
var auto_fix_lineup := true


## Advances one day. Returns {"stopped": bool, "reason": String}. If the player has a match, it waits in pending_match.
func advance_day() -> Dictionary:
	begin_day()
	while not step_day(1 << 30):
		pass
	return day_result()


## advance_day in slices for a UI that keeps drawing between them: begins the day when none is in progress, then runs
## steps for `budget_ms`. True when the day is done (then day_result()); the next call begins the next day.
func advance_day_slice(budget_ms: int) -> bool:
	if _step_i >= _steps.size():
		begin_day()
	return step_day(budget_ms)


var _steps: Array = []
var _step_i := 0
var _insert_at := 0
var _day_result: Dictionary = {"stopped": false, "reason": ""}
var _human_fixture: Dictionary = {}
var _human_comp := ""
var _monthly_tables: Dictionary = {}
var _monthly_log: Array = []
var _transfer_ctx: Dictionary = {}
var _rng_mark := 0
var _prof_us: Dictionary = {}
## Label of the last step run (diagnostics; the slowest one of the game goes to prof["slowest_step"]).
var last_step := ""


## Prepares the day's steps. The day may already be decided here (a match waiting in pending_match).
func begin_day() -> void:
	if _step_i < _steps.size():
		push_warning("GameEngine.begin_day: a day was still in progress (last step '%s'); finishing it first" % last_step)
		while not step_day(1 << 30):
			pass
	_steps = []
	_step_i = 0
	_insert_at = 0
	_day_result = {"stopped": false, "reason": ""}
	if pending_match != null:
		_day_result = {"stopped": true, "reason": "match_pending"}
		return
	# The day closes only once every fixture of today has a result, so an unplayed one means the day is still open,
	# also after a reload or a job change that turned the held-back fixture into an AI one.
	if w.competitions.values().any(func(c: Competition) -> bool: return not c.fixtures_on(w.today).is_empty()):
		_queue("resume", _queue_resume_open_day)
		return
	_queue("open", _open_day)
	_queue("daily", _queue_daily)
	_queue("events", _events_step)
	_queue("market", _market_step)
	_queue("matches", _queue_matches)
	_queue("close", _queue_close_day)


## Runs steps until the budget (ms) is spent or the day is done; always at least one step. True when the day is done
## (also when no day is in progress).
func step_day(budget_ms: int = 12) -> bool:
	var t0 := Time.get_ticks_usec()
	while _step_i < _steps.size():
		var s: Array = _steps[_step_i]
		_step_i += 1
		_insert_at = _step_i
		last_step = s[0]
		var ts := Time.get_ticks_usec()
		(s[1] as Callable).call()
		var dt := Time.get_ticks_usec() - ts
		var bucket: String = str(s[0]).get_slice(":", 0) + "_ms"
		if prof.has(bucket):
			_prof_us[bucket] = int(_prof_us.get(bucket, 0)) + dt
			prof[bucket] = int(_prof_us[bucket]) / 1000
		if dt > int(prof.get("slowest_step_us", 0)):
			prof["slowest_step_us"] = dt
			prof["slowest_step"] = s[0]
		if Time.get_ticks_usec() - t0 >= budget_ms * 1000:
			break
	return _step_i >= _steps.size()


## The outcome of the day begun with begin_day, once step_day has returned true: {"stopped": bool, "reason": String}.
func day_result() -> Dictionary:
	return _day_result


func _queue(label: String, fn: Callable) -> void:
	_steps.insert(_insert_at, [label, fn])
	_insert_at += 1


func _finish_day(result: Dictionary) -> void:
	_day_result = result
	_steps.resize(_step_i)


func _open_day() -> void:
	w.today += 1
	w.rng_state += 1
	last_day_log.clear()


func _events_step() -> void:
	prof["rng_daily"] = rng().calls - _rng_mark
	var c0 := rng().calls
	_calendar_events()
	_book_events()
	prof["rng_events"] = rng().calls - c0


func _market_step() -> void:
	var c0 := rng().calls
	MarketActions.process_pending(w, self)
	prof["rng_market"] = rng().calls - c0


func _queue_matches() -> void:
	prof["rng_before_matches"] = rng().calls
	_human_fixture = {}
	_human_comp = ""
	var comp_ids := w.competitions.keys()
	comp_ids.sort()
	for cid in comp_ids:
		_queue("matches:comp", _queue_comp_matches.bind(cid, false))
	_queue("matches:done", _after_matches)


func _queue_comp_matches(cid: String, resume: bool) -> void:
	var comp: Competition = w.competitions[cid]
	for f in comp.fixtures_on(w.today):
		_queue("matches:fixture", _match_step.bind(comp, f, resume))


func _match_step(comp: Competition, f: Dictionary, resume: bool) -> void:
	if bool(f.get("played", false)):
		return
	if _is_human(f["home_id"]) or _is_human(f["away_id"]):
		if not resume and (_human_fixture.is_empty() or not _is_club_fixture(_human_fixture)):
			_human_fixture = f
			_human_comp = comp.id
		return
	_play_ai_match(comp, f)
	prof["matches"] += 1


func _after_matches() -> void:
	if not _human_fixture.is_empty():
		if _is_club_fixture(_human_fixture) and lineup_blocked():
			var me := w.my_club()
			Inbox.ask(w, Inbox.Decision.new(Inbox.LINEUP, str(_human_fixture.get("id", "")), [Inbox.Choice.go("ui.action.fix_lineup", &"lineup")]).blocking(),
				&"from.assistant", "msg.lineup_blocked.subject", "msg.lineup_blocked.body",
				{"rival": Say.team(w, _human_fixture["away_id"] if _human_fixture["home_id"] == me.id else _human_fixture["home_id"])})
			_finish_day({"stopped": true, "reason": "lineup"})
			return
		_prepare_human_match(_human_comp, _human_fixture)
		_finish_day({"stopped": true, "reason": "match"})
		return
	prof["rng_after_matches"] = rng().calls


func _queue_close_day() -> void:
	_queue_end_of_day()
	_queue("close:result", _close_day_result)


func _close_day_result() -> void:
	prof["rng_end"] = rng().calls
	_day_result = {"stopped": true, "reason": "message"} if Inbox.blocking(w) != null else {"stopped": false, "reason": ""}


func _queue_resume_open_day() -> void:
	var comp_ids := w.competitions.keys()
	comp_ids.sort()
	for cid in comp_ids:
		_queue("matches:comp", _queue_comp_matches.bind(cid, true))
	_queue("matches:resume", _after_resume)


func _after_resume() -> void:
	var open_fx := _open_human_fixture()
	if open_fx.is_empty():
		_queue("close", _queue_close_day)
		return
	if _is_club_fixture(open_fx["fixture"]) and lineup_blocked():
		_finish_day({"stopped": true, "reason": "lineup"})
		return
	_prepare_human_match(str(open_fx["comp_id"]), open_fx["fixture"])
	_finish_day({"stopped": true, "reason": "match"})


func _open_human_fixture() -> Dictionary:
	var nt_fx := {}
	var comp_ids := w.competitions.keys()
	comp_ids.sort()
	for cid in comp_ids:
		var comp: Competition = w.competitions[cid]
		for f in comp.fixtures_on(w.today):
			if bool(f.get("played", false)) or not (_is_human(f["home_id"]) or _is_human(f["away_id"])):
				continue
			if _is_club_fixture(f):
				return {"comp_id": cid, "fixture": f}
			if nt_fx.is_empty():
				nt_fx = {"comp_id": cid, "fixture": f}
	return nt_fx


func _is_club_fixture(f: Dictionary) -> bool:
	return w.player_club_id != "" and (str(f["home_id"]) == w.player_club_id or str(f["away_id"]) == w.player_club_id)


## Human club match today not yet built (the advance stopped over the lineup): {comp_id, fixture} or {}.
func human_fixture_today() -> Dictionary:
	var me := w.my_club()
	if me == null:
		return {}
	var comp_ids := w.competitions.keys()
	comp_ids.sort()
	for cid in comp_ids:
		var comp: Competition = w.competitions[cid]
		for f in comp.fixtures_on(w.today):
			if not bool(f.get("played", false)) and (f["home_id"] == me.id or f["away_id"] == me.id):
				return {"comp_id": cid, "fixture": f}
	return {}


## Is the human lineup unfit to play today? (injured, suspended, gaps). With auto_fix_lineup the
## assistant fixes it and it never blocks. Nor does it block when no valid seven exists at all: the best lineup
## available takes the field, short if need be.
func lineup_blocked() -> bool:
	var me := w.my_club()
	if me == null or _lineup_valid(me):
		return false
	var best: Dictionary = Schools.best_lineup(w, me.id) if Schools.is_house(me.id) else WorldGenerator.best_lineup(w, me.id)
	if auto_fix_lineup or not _lineup_dict_valid(me.id, best):
		me.lineup = best
		return false
	return true


## Advances to the next own match, pending message or `max_days`.
func advance_until_event(max_days: int = 60) -> Dictionary:
	var r := {"stopped": false, "reason": ""}
	for i in max_days:
		r = advance_day()
		if r["stopped"]:
			return r
	return r


func _is_human(club_id: String) -> bool:
	return club_id == w.player_club_id or (club_id != "" and club_id == str(w.manager.get("national_team_id", "")))


func _queue_daily() -> void:
	_rng_mark = rng().calls
	if WDate.day_of_month(w.today) == 1:
		_queue("daily:awards", _monthly_awards)
	_queue("daily:clubs", _queue_daily_clubs)
	_queue("daily:clubless", _daily_clubless)
	_queue("daily:duty", _international_duty)
	_queue("daily:tail", _daily_tail)
	if WDate.month(w.today) == 7 and WDate.day_of_month(w.today) == 1:
		_queue("daily:rollover", _season_rollover)


func _queue_daily_clubs() -> void:
	for club in w.clubs_sorted():
		_queue("daily:club", _daily_club.bind(club))


func _daily_club(club: Club) -> void:
	var medical: int = maxi(int(club.facilities.get("medical", 2)), club.staff_level("mediwizard"))
	for p in w.club_players(club.id):
		if p.injury_days <= 0 and p.condition >= 100.0:
			continue
		var was_injured: bool = p.injury_days > 0
		Progression.daily(p, rng(), medical)
		if was_injured and p.injury_days == 0 and _is_human(club.id):
			Inbox.tell(w, &"from.mediwizard", "msg.recovered.subject", "msg.recovered.body", {"player": Say.player(p)})


func _daily_clubless() -> void:
	var human_house := w.player_club_id if w.is_school_mode() else ""
	for p in w.club_players(""):
		if p.injury_days > 0 or p.condition < 100.0:
			var school: bool = p.squad == Player.Squad.SCHOOL
			var was_hurt: bool = p.injury_days > 0
			Progression.daily(p, rng(), 3 if school else 1)
			if school and was_hurt and p.injury_days == 0 and human_house != "" and Schools.house_id(p.school_id, p.house) == human_house:
				Inbox.tell(w, &"from.matron", "msg.recovered.subject", "msg.recovered.body", {"player": Say.player(p)})


## Days before a national-team match the squad is called up: the players are away on international duty from the
## call-up until the day after the match (Player.duty_days), unavailable to their club or house but fit for the
## national team.
const CALL_UP_DAYS := 3
const CALL_UP_DAYS_KNOCKOUT := 15


func _international_duty() -> void:
	for p in w.players.values():
		if p.duty_days > 0:
			p.duty_days -= 1
			if p.duty_days <= 0:
				p.duty_days = 0
				p.duty_team = ""
	_duty_owls = {}
	var ahead_of := {}
	var cids := w.competitions.keys()
	cids.sort()
	for cid in cids:
		var c: Competition = w.competitions[cid]
		var window := CALL_UP_DAYS_KNOCKOUT if c.type == Competition.Type.WC_KNOCKOUT else CALL_UP_DAYS
		for f in c.fixtures:
			if bool(f.get("played", false)):
				continue
			var ahead: int = int(f["day"]) - w.today
			if ahead < 0 or ahead > window:
				continue
			for side in ["home_id", "away_id"]:
				var tid := str(f[side])
				if not tid.begins_with("nt_") or not w.national_teams.has(tid):
					continue
				if not ahead_of.has(tid) or ahead < int(ahead_of[tid][0]):
					ahead_of[tid] = [ahead, cid]
	var tids := ahead_of.keys()
	tids.sort()
	for tid in tids:
		_queue("daily:duty:team", _call_up_team.bind(str(tid), int(ahead_of[tid][0]), str(ahead_of[tid][1])))
	_queue("daily:duty:owls", _duty_owls_post)


## Players of the manager's club called up by one national team today, told in one owl.
class CallUp:
	var players: Array = []
	var comp_id: String = ""

var _duty_owls: Dictionary[String, CallUp] = {}


func _call_up_team(tid: String, ahead: int, cid: String) -> void:
	var lineup := NationalTeams.call_up_squad(w, w.national_teams[tid])
	for pair in NationalTeams.lineup_slots(lineup):
		var p: Player = w.player(str(pair[0]))
		if p == null:
			continue
		var fresh := p.duty_days <= 0
		p.duty_days = maxi(p.duty_days, ahead + 2)
		p.duty_team = tid
		if fresh and w.player_club_id != "" and p.club_id == w.player_club_id and str(w.manager.get("national_team_id", "")) != tid:
			if not _duty_owls.has(tid):
				_duty_owls[tid] = CallUp.new()
				_duty_owls[tid].comp_id = cid
			_duty_owls[tid].players.append(Say.player(p))


func _duty_owls_post() -> void:
	for tid in _duty_owls.keys():
		Inbox.tell(w, &"from.club_secretary", "msg.duty_call.subject", "msg.duty_call.body",
			{"player": Say.list(_duty_owls[tid].players), "team": Say.team(w, tid), "competition": Say.comp(_duty_owls[tid].comp_id)})
	_duty_owls = {}


func _daily_tail() -> void:
	_process_applications()
	Schools.tryouts_daily(w)
	if int(w.settings.get("pre_press", {}).get("match_day", w.today)) < w.today:
		end_pre_press()
	Inbox.sweep(w)
	settle_owls()
	var hm := w.my_club()
	if hm != null and not w.is_school_mode():
		Scouting.daily(w, hm, rng())
		if bool(w.settings.get("press", true)):
			for cid in w.competitions.keys():
				var pc: Competition = w.competitions[cid]
				if pc.type in Competition.Type.CASUAL:
					continue
				for f in pc.fixtures_on(w.today + 1):
					if (str(f["home_id"]) == hm.id or str(f["away_id"]) == hm.id) and not bool(f.get("played", false)):
						end_pre_press()
						var rv := str(f["away_id"]) if str(f["home_id"]) == hm.id else str(f["home_id"])
						w.settings["pre_press"] = {"fixture_id": str(f["id"]), "comp_id": pc.id, "match_day": w.today + 1}
						Inbox.ask(w, Inbox.Decision.new(Inbox.PRE_PRESS, str(f["id"]), [Inbox.Choice.go("ui.press.go_pre", &"press", {"pre_fixture": str(f["id"]), "comp_id": pc.id}, true)]),
							&"from.prophet", "msg.pre_press.subject", "msg.pre_press.body", {"rival": Say.team(w, rv)})
		if bool(w.settings.get("scout_opponent", false)) and not hm.scouts.is_empty():
			var lg := w.league_of(hm.id)
			if lg != null:
				for f in lg.fixtures_on(w.today + 2):
					if str(f["home_id"]) == hm.id or str(f["away_id"]) == hm.id:
						Scouting.opponent_report(w, hm, f)


func _queue_end_of_day() -> void:
	if WDate.weekday(w.today) == Time.WEEKDAY_MONDAY:
		_queue("weekly", _queue_weekly)
	if WDate.day_of_month(w.today) == 1:
		_queue("monthly", _queue_monthly)


func _queue_weekly() -> void:
	for club in w.clubs_sorted():
		_queue("weekly:club", _weekly_club.bind(club))
	for hid in w.houses.keys():
		_queue("weekly:house", _weekly_house.bind(hid))
	_queue("weekly:clubless", _develop_clubless)
	_queue("weekly:human", _weekly_human)
	_queue("weekly:reserves", _reserve_matches)
	_queue("weekly:news", _publish_news)


func _weekly_club(club: Club) -> void:
	Economy.pay_wages(w, club)
	Fans.weekly(club)
	_train_club(club)


func _weekly_house(hid: String) -> void:
	_train_club(w.house_club_view(hid))


func _weekly_human() -> void:
	Press.check_promises(w)
	if w.my_club() != null and not w.is_school_mode():
		Happiness.weekly(w, w.my_club())
	_assistant_weekly()


func _train_club(club: Club) -> void:
	var focus: String = str(club.tactics.get("training_focus", "tactics"))
	var load: int = int(club.tactics.get("training_load", 2))
	if not club.manager_is_human or bool(w.settings.get("delegate_training", true)):
		focus = _ai_training_focus(club)
		load = 2
	elif club.tactics.has("training_plan"):
		focus = _plan_pick(club.tactics["training_plan"], focus)
	var biweek: bool = (w.today / 7) % 2 == 0
	if club.manager_is_human and w.clubs.has(club.id):
		_update_familiarity(club, focus)
	var last_month := w.minutes_last_month
	for p in w.club_players(club.id):
		var before: Dictionary = p.attrs.duplicate() if p.squad == Player.Squad.SCHOOL else {}
		Progression.weekly_state(p, club.broom_care_level())
		var minutes: int = maxi(int(last_month.get(p.id, 0)), int(w.minutes_month.get(p.id, 0)))
		if biweek:
			Progression.weekly(p, w, club, rng(), minutes)
			Progression.weekly(p, w, club, rng(), minutes)
		if p.injury_days <= 0:
			var pf := focus
			if p.position == "K":
				pf = "keeper" if rng().chance(0.5) else focus
			elif p.position == "S":
				pf = "seeking" if rng().chance(0.5) else focus
			elif p.position == "B":
				pf = "beating" if rng().chance(0.4) else focus
			if club.manager_is_human and p.training_focus != "" and not bool(w.settings.get("delegate_training", true)):
				pf = p.training_focus
			Progression.training(p, pf, load, rng(), club)
			var mentor := Progression.valid_mentor(p, w)
			if mentor != null:
				p.morale = clampf(p.morale + 1.0, 0.0, 100.0)
				if rng().chance(0.25 + 0.03 * (mentor.hid("professionalism") - 10.0)):
					var k: String = str(rng().pick(Progression.MENTAL))
					p.attrs[k] = clampf(float(p.attrs[k]) + 0.05, 1.0, 20.0)
			if p.injury_days > 0 and p.injury_kind == "training" and (p.injury_history.is_empty() or int(p.injury_history[-1].get("day", 0)) != w.today):
				_record_injury(p)
			if p.injury_days > 0 and _is_human(club.id):
				Inbox.tell(w, &"from.mediwizard", "msg.training_injury.subject", "msg.training_injury.body", {"player": Say.player(p), "days": Say.num(p.injury_days)})
		if not before.is_empty():
			for k in before.keys():
				p.attrs[k] = lerpf(float(before[k]), float(p.attrs[k]), SCHOOL_TRAINING_SCALE)


## Minutes a month credited to "abroad" players (national-team pool), who play for clubs outside the simulated
## leagues.
const ABROAD_MINUTES_MONTH := 180  # [game]


func _develop_clubless() -> void:
	var biweek: bool = (w.today / 7) % 2 == 0
	var neutral := Club.new()
	neutral.staff = {"assistant": {"level": 2}}
	var r := SimRng.derived(w.seed_value, "clubless:%d" % w.today)
	var focus := _ai_training_focus(neutral)
	var pool: Array = w.club_players("").duplicate()
	pool.sort_custom(func(a, b): return a.id < b.id)
	for p in pool:
		if p.squad == Player.Squad.SCHOOL:
			continue
		var abroad: bool = p.squad == Player.Squad.ABROAD
		var sharp: float = p.sharpness
		Progression.weekly_state(p)
		if abroad:
			p.sharpness = sharp
		if biweek:
			var minutes: int = ABROAD_MINUTES_MONTH if abroad else 0
			Progression.weekly(p, w, neutral, r, minutes)
			Progression.weekly(p, w, neutral, r, minutes)
		if abroad and p.injury_days <= 0:
			Progression.training(p, focus, 2, r, neutral)


const RESERVE_MINUTES_WEEK := 45


func _reserve_matches() -> void:
	var me := w.my_club()
	var reserve_football := WDate.month(w.today) != 7
	for p in w.players.values():
		if p.club_id == "" or p.injury_days > 0:
			continue
		if p.sharpness < 70.0:
			p.sharpness = minf(70.0, p.sharpness + 5.0)
		if reserve_football and p.squad in Player.Squad.DEVELOPING:
			w.minutes_month[p.id] = int(w.minutes_month.get(p.id, 0)) + RESERVE_MINUTES_WEEK
	if me == null or WDate.month(w.today) == 7 or w.is_school_mode():
		return
	var mine := _reserve_lineup(me)
	if mine.is_empty():
		return
	var rivals: Array = []
	var lg := w.league_of(me.id)
	if lg == null:
		return
	for cid in lg.club_ids:
		if cid != me.id and w.clubs.has(cid):
			rivals.append(cid)
	if rivals.is_empty():
		return
	var rival: Club = w.club(str(rng().pick(rivals)))
	var theirs := _reserve_lineup(rival)
	if theirs.is_empty():
		return
	var home := _sim_team_from_lineup(me, mine)
	var away := _sim_team_from_lineup(rival, theirs)
	var r := loader.rules.duplicate(true)
	r["time_cap_minutes"] = 120
	var sim := MatchSim.new(r, loader.params)
	sim.min_log_importance = MatchEvent.Importance.KEY
	var res := sim.run(home, away, SimRng.derived_seed(w.seed_value, "reserves:%d" % w.today))
	for t in [home, away]:
		var won: bool = (t == home and res.score_home > res.score_away) or (t == away and res.score_away > res.score_home)
		for sp in t.players:
			var p: Player = w.player(sp.id)
			if p == null:
				continue
			var rating := Progression.match_rating(sp.stats, sp.position, won)
			var st: Dictionary = p.stats_for(w.season)
			st["reserve_apps"] = int(st.get("reserve_apps", 0)) + 1
			st["reserve_rating_sum"] = float(st.get("reserve_rating_sum", 0.0)) + rating
			p.sharpness = minf(100.0, p.sharpness + 10.0)
			p.condition = clampf(p.condition - 8.0, 20.0, 100.0)
			if p.squad == Player.Squad.FIRST:
				w.minutes_month[p.id] = int(w.minutes_month.get(p.id, 0)) + res.duration_s / 60
			if sp.injured:
				Progression.apply_match_injury(p, SimPlayer.Severity.MATCH, rng())
				_record_injury(p)
				if t == home:
					Inbox.tell(w, &"from.mediwizard", "msg.injury.subject", "msg.injury.body", {"player": Say.player(p), "days": Say.num(p.injury_days)})
	Inbox.tell(w, &"from.assistant", "msg.reserves.subject", "msg.reserves.body", {"home": Say.plain(me.short_name), "away": Say.plain(rival.short_name), "sh": Say.num(res.score_home), "sa": Say.num(res.score_away), "best": Say.plain(_best_of(home))}, Inbox.QUIET)


func _starter_ids(club: Club) -> Dictionary:
	var l: Dictionary = club.lineup if (club.manager_is_human and _lineup_valid(club)) else WorldGenerator.best_lineup(w, club.id)
	var out := {}
	for pid in [l.get("K", "")] + l.get("C", []) + l.get("B", []) + [l.get("S", "")]:
		if str(pid) != "":
			out[str(pid)] = true
	return out


func _reserve_lineup(club: Club) -> Array:
	var starters := _starter_ids(club)
	var pool: Array = []
	for p in w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE, Player.Squad.YOUTH]):
		if not starters.has(p.id) and p.is_available() and p.condition >= 60.0:
			pool.append(p)
	var need := {"K": 1, "C": 3, "B": 2, "S": 1}
	var chosen: Array = []
	for pos in ["K", "C", "C", "C", "B", "B", "S"]:
		var best: Player = null
		for p in pool:
			if chosen.has(p):
				continue
			if p.position == pos and (best == null or p.ca() > best.ca()):
				best = p
		if best == null:
			for p in pool:
				if not chosen.has(p) and (best == null or p.ca() > best.ca()):
					best = p
		if best == null:
			return []
		chosen.append(best)
	return chosen


func _sim_team_from_lineup(club: Club, players: Array) -> SimTeam:
	var t := SimTeam.new()
	t.id = club.id
	t.name = club.name
	t.tactics = SimTactics.merge(club.tactics)
	t.is_human = false
	var slots := ["K", "C", "C", "C", "B", "B", "S"]
	for i in players.size():
		var p: Player = players[i]
		var sp := p.to_sim_player(loader.brooms)
		sp.position = slots[i]
		if p.position != slots[i]:
			var fam: float = float(p.positions.get(slots[i], 4.0))
			var pen: float = 0.75 + 0.25 * (fam - 1.0) / 19.0
			for k in sp.attrs.keys():
				sp.attrs[k] = float(sp.attrs[k]) * pen
		t.players.append(sp)
	if not t.players.is_empty():
		t.captain = t.players[0]
	return t


func _best_of(t: SimTeam) -> String:
	var best: SimPlayer = null
	var best_r := -1.0
	for sp in t.players:
		var r := Progression.match_rating(sp.stats, sp.position, true)
		if r > best_r:
			best_r = r
			best = sp
	return best.name if best != null else ""


func _plan_pick(plan: Dictionary, fallback: String) -> String:
	var total := 0.0
	for k in plan.keys():
		total += maxf(float(plan[k]), 0.0)
	if total <= 0.0:
		return fallback
	var x := rng().next() * total
	for k in Progression.TRAINING.keys():
		x -= maxf(float(plan.get(k, 0)), 0.0)
		if x <= 0.0:
			return str(k)
	return fallback


func _ai_training_focus(club: Club) -> String:
	var m := WDate.month(w.today)
	if m == 8:
		return "physical"
	return str(["flying", "quaffle", "tactics"][w.rng_state % 3])


func _record_injury(p: Player) -> void:
	p.injury_history.append({"day": w.today, "kind": p.injury_kind, "days": p.injury_days})
	if p.injury_history.size() > 12:
		p.injury_history.pop_front()


func _monthly_awards() -> void:
	var prev_month := WDate.month(w.today - 1)
	var month_start := w.today - WDate.day_of_month(w.today - 1)
	var my_league: String = w.my_club().league_id if w.my_club() != null else ""
	for comp in w.leagues():
		var best: Player = null
		var best_avg := 0.0
		var young: Player = null
		var young_avg := 0.0
		for cid in comp.club_ids:
			for p in w.club_players(str(cid)):
				if p.month_ratings.size() < 2:
					continue
				var avg := 0.0
				for r in p.month_ratings:
					avg += float(r)
				avg /= p.month_ratings.size()
				if avg > best_avg:
					best_avg = avg
					best = p
				if p.age(w.today) <= 21 and avg > young_avg:
					young_avg = avg
					young = p
		var wins := {}
		var diff := {}
		var played := {}
		for f in comp.fixtures:
			if not bool(f.get("played", false)) or int(f["day"]) >= w.today or int(f["day"]) < month_start:
				continue
			var hs := int(f.get("score_home", 0))
			var as_ := int(f.get("score_away", 0))
			var winner := str(f["home_id"]) if hs > as_ else (str(f["away_id"]) if as_ > hs else "")
			if winner != "":
				wins[winner] = int(wins.get(winner, 0)) + 1
			diff[str(f["home_id"])] = int(diff.get(str(f["home_id"]), 0)) + hs - as_
			diff[str(f["away_id"])] = int(diff.get(str(f["away_id"]), 0)) + as_ - hs
			played[str(f["home_id"])] = int(played.get(str(f["home_id"]), 0)) + 1
			played[str(f["away_id"])] = int(played.get(str(f["away_id"]), 0)) + 1
		var mgr := ""
		for cid in wins.keys():
			if int(played.get(cid, 0)) < MOTM_MIN_MATCHES or int(wins[cid]) * 2 <= int(played.get(cid, 0)):
				continue
			if mgr == "" or int(wins[cid]) > int(wins[mgr]) or (int(wins[cid]) == int(wins[mgr]) and int(diff.get(cid, 0)) > int(diff.get(mgr, 0))):
				mgr = cid
		if best == null and mgr == "":
			continue
		for pair in [["player_month", best, best_avg], ["young_month", young, young_avg]]:
			var ap: Player = pair[1]
			if ap == null:
				continue
			w.monthly_awards.push_front({"season": w.season, "month": prev_month, "competition_id": comp.id, "kind": pair[0], "player_id": ap.id, "club_id": ap.club_id, "value": "%.1f" % float(pair[2])})
			if comp.id == my_league:
				_append_news_item(NewsGenerator.item("news.monthly_award", 2, {"award": Say.key("award." + str(pair[0])), "player": Say.player(ap), "club": Say.team(w, ap.club_id), "league": Say.comp(comp.id), "value": Say.plain("%.1f" % float(pair[2]))}, {"clubs": [ap.club_id]}))
			if ap.club_id == w.player_club_id and w.player_club_id != "":
				ap.morale = clampf(ap.morale + 5.0, 0.0, 100.0)
				Inbox.tell(w, &"from.club_secretary", "msg.monthly_award.subject", "msg.monthly_award.body", {"award": Say.key("award." + str(pair[0])), "player": Say.player(ap)})
		if mgr != "":
			var mc: Club = w.club(mgr)
			w.monthly_awards.push_front({"season": w.season, "month": prev_month, "competition_id": comp.id, "kind": "manager_month", "player_id": "", "club_id": mgr, "manager": mc.manager_name if not mc.manager_is_human else str(w.manager.get("name", "")), "human": mc.manager_is_human, "value": str(wins[mgr])})
			if mc.manager_is_human:
				w.manager["motm_count"] = int(w.manager.get("motm_count", 0)) + 1
				Career.add_reputation(w, 15)
				Inbox.tell(w, &"from.board", "msg.manager_month.subject", "msg.manager_month.body", {"league": Say.comp(comp.id)})
	while w.monthly_awards.size() > 400:
		w.monthly_awards.pop_back()
	for p in w.players.values():
		p.month_ratings.clear()


## League matches a club must play in the month for its manager to be Manager of the Month.
const MOTM_MIN_MATCHES := 2


func _queue_monthly() -> void:
	_queue("monthly:installments", func(): MarketActions.process_installments(w))
	_queue("monthly:transfers", _monthly_transfers)
	_queue("monthly:offers", _monthly_offers)
	_queue("monthly:scouts", _scout_recommendations)
	_queue("monthly:contracts", _monthly_contracts)
	_queue("monthly:clubs", _queue_monthly_clubs)
	_queue("monthly:snapshot", _monthly_snapshot)
	_queue("monthly:board", _monthly_board)


func _monthly_transfers() -> void:
	_monthly_log = []
	_transfer_ctx = Economy.ai_transfer_begin(w)
	for club in w.clubs_sorted():
		_queue("monthly:transfer", _monthly_transfer_club.bind(club))


func _monthly_transfer_club(club: Club) -> void:
	Economy.ai_transfer_club(w, rng(), _monthly_log, _transfer_ctx, club)


func _monthly_offers() -> void:
	if w.manager_unemployed and w.player_club_id == "" and WDate.month(w.today) != 7 and rng().chance(0.6):
		_job_offers(1, false)


func _monthly_contracts() -> void:
	Contracts.ai_pre_contract_tick(w, rng())
	_contracts_review()
	_contracts_spring_owl()
	_rumours(_monthly_log)
	for item in _monthly_log:
		_append_news_item(item)
	_monthly_log = []
	_transfer_ctx = {}


func _queue_monthly_clubs() -> void:
	_monthly_tables = {}
	for comp in w.leagues():
		_monthly_tables[comp.id] = comp.standings()
	for club in w.clubs_sorted():
		_queue("monthly:club", _monthly_club.bind(club))


func _monthly_club(club: Club) -> void:
	Economy.monthly_sponsor(w, club)
	Economy.monthly_merch(w, club)
	var comp := w.league_of(club.id)
	if comp != null:
		Economy.board_review(w, club, comp, _monthly_tables[comp.id])
		if not club.manager_is_human and [11, 12, 1, 2, 3, 4].has(WDate.month(w.today)) \
				and float(club.board.get("confidence", 60.0)) < 22.0 and w.today - int(club.board.get("manager_since", 0)) > 120 \
				and rng().chance(0.3):
			_ai_sack(club)
	for sc in club.scouts:
		var reg := str(sc.get("region_id", ""))
		if reg != "":
			club.knowledge[reg] = minf(100.0, float(club.knowledge.get(reg, 0.0)) + 6.0 + 2.0 * float(sc.get("quality", 2)) + 1.5 * club.staff_level("head_scout"))
			Economy.book(w, club, "scouts", -int(sc.get("wage_monthly", 60)))


func _monthly_snapshot() -> void:
	if "minutes_last_month" in w:
		w.set("minutes_last_month", w.minutes_month.duplicate())
	w.minutes_month.clear()
	for p in w.players_sorted():
		p.snapshot_attrs()


func _monthly_board() -> void:
	var tables := _monthly_tables
	var me := w.my_club()
	if me != null and not w.is_school_mode():
		me.transfer_budget = clampi(me.transfer_budget, 0, maxi(me.balance, 0))
		if me.balance < 0 and not bool(me.board.get("debt_warned", false)):
			me.board["debt_warned"] = true
			Inbox.tell(w, &"from.board", "msg.in_debt.subject", "msg.in_debt.body", {"balance": Say.money(me.balance)})
		elif me.balance >= 0:
			me.board.erase("debt_warned")
		_debt_check(me)
		me = w.my_club()
	var my_row: Array = tables.get(w.league_of(me.id).id, []).filter(func(r): return r["club_id"] == me.id) if me != null and w.league_of(me.id) != null else []
	if me != null and not w.is_school_mode() and not my_row.is_empty() and int(my_row[0]["pj"]) > 0:
		Inbox.tell(w, &"from.board", "msg.board_monthly.subject", "msg.board_monthly.body", {"confidence": Say.num(int(me.board.get("confidence", 60.0))), "balance": Say.money(me.balance), "position": Say.num(w.league_of(me.id).position_of(me.id))})


## Debt deeper than DEBT_WEEKS weeks of wages: an urgent warning from the board; two months on, a transfer
## embargo; five months on, an ultimatum; and a club still that deep in the red a year after the warning sacks the
## manager. Climbing back above the line lifts all of it. Checked monthly for the human club.
const DEBT_WEEKS := 8  # [game]
const DEBT_EMBARGO_DAYS := 60
const DEBT_ULTIMATUM_DAYS := 150
const DEBT_SACK_DAYS := 365


func _debt_check(me: Club) -> void:
	var line := -DEBT_WEEKS * maxi(_weekly_bill(me), 50)
	var stage := int(me.board.get("debt_stage", 0))
	if me.balance >= line:
		if stage > 0:
			_clear_debt_flags(me)
			Inbox.tell(w, &"from.board", "msg.debt_cleared.subject", "msg.debt_cleared.body", {"club": Say.club(me)})
		return
	var since := int(me.board.get("debt_since", w.today))
	var params: Dictionary[String, Say.Arg] = {"club": Say.club(me), "balance": Say.money(me.balance), "limit": Say.money(line), "weeks": Say.num(DEBT_WEEKS)}
	var key := ""
	if stage == 0:
		me.board["debt_stage"] = 1
		me.board["debt_since"] = w.today
		key = "msg.debt_warning"
	elif stage == 1 and w.today - since >= DEBT_EMBARGO_DAYS:
		me.board["debt_stage"] = 2
		me.board["embargo"] = true
		key = "msg.debt_embargo"
	elif stage == 2 and w.today - since >= DEBT_ULTIMATUM_DAYS:
		me.board["debt_stage"] = 3
		key = "msg.debt_ultimatum"
	elif stage == 3 and w.today - since >= DEBT_SACK_DAYS:
		Inbox.tell(w, &"from.board", "msg.debt_sacked.subject", "msg.debt_sacked.body", params)
		Career.add_reputation(w, -150)
		_sack_human(me)
		return
	if key != "":
		Inbox.ask(w, Inbox.Decision.new(Inbox.ACK, "", [Inbox.Choice.ok()]).blocking(), &"from.board", key + ".subject", key + ".body", params)


func _weekly_bill(club: Club) -> int:
	var total := 0
	for p in w.squad_of(club.id):
		total += int(p.contract.get("wage_weekly", 10))
	for role in club.staff.keys():
		total += int(club.staff[role].get("wage", 0))
	return total


func _clear_debt_flags(club: Club) -> void:
	for k in ["debt_stage", "debt_since", "embargo"]:
		club.board.erase(k)


func sim_team_for(club_id: String) -> SimTeam:
	var club: Club = w.club(club_id)
	var lineup: Dictionary = club.lineup if (club.manager_is_human and _lineup_valid(club)) else WorldGenerator.best_lineup(w, club_id)
	var t := SimTeam.new()
	t.id = club.id
	t.name = club.name
	t.tactics = SimTactics.merge(club.tactics)
	if not club.manager_is_human:
		var style := _ai_style(club)
		for k in style.keys():
			t.tactics[k] = style[k]
	t.is_human = club.manager_is_human
	for pair in NationalTeams.lineup_slots(lineup):
		var pid: String = pair[0]
		var slot: String = pair[1]
		if pid == "" or not w.players.has(pid):
			continue
		var p: Player = w.players[pid]
		var sp := p.to_sim_player(loader.brooms)
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
	if club.manager_is_human:
		var fam := club.familiarity_of(str(t.tactics.get("chaser_formation", "free"))) / 100.0
		var mult := lerpf(0.92, 1.0, clampf(fam, 0.0, 1.0))
		if mult < 1.0:
			for sp in t.players:
				if sp.position == "C":
					for k in ["passing", "teamwork", "decisions"]:
						if sp.attrs.has(k):
							sp.attrs[k] = float(sp.attrs[k]) * mult
	return t


func _update_familiarity(club: Club, focus: String) -> void:
	var current := str(club.tactics.get("chaser_formation", "free"))
	for f in ["hawkshead", "porskoff", "shimmy", "reverse_pass", "looping"]:
		var v := club.familiarity_of(f)
		if f == current:
			v = minf(100.0, v + (4.0 if focus == "tactics" else 2.0))
		else:
			v = maxf(30.0, v - 1.0)
		club.familiarity[f] = v


func _ai_style(club: Club) -> Dictionary:
	var tags: Array = club.identity.get("style_tags", [])
	var st := {}
	for tag in tags:
		match str(tag):
			"shimmy":
				st["chaser_formation"] = "shimmy"
			"reverse_pass":
				st["chaser_formation"] = "reverse_pass"
			"formation_looping":
				st["chaser_formation"] = "looping"
			"attacking", "flamboyant", "showmanship", "daring", "flair", "top_scorers":
				if not st.has("chaser_formation"):
					st["chaser_formation"] = "hawkshead"
				st["mentality"] = 13
			"clever", "experienced", "innovative_seekers":
				if not st.has("chaser_formation"):
					st["chaser_formation"] = "porskoff"
			"physical", "aggressive", "fierce", "violent", "hard":
				st["chaser_defence"] = "pincer"
				st["hard_play"] = 14
				st["beater_instruction"] = "punish_carrier"
			"defensive", "solid", "resilient":
				st["chaser_defence"] = "mark"
				st["mentality"] = 8
			"beater_marking":
				st["beater_instruction"] = "mark_beaters"
	if not st.has("chaser_formation"):
		st["chaser_formation"] = ["free", "porskoff", "hawkshead", "free"][absi(hash(club.id)) % 4]
	return st


func _lineup_valid(club: Club) -> bool:
	return _lineup_dict_valid(club.id, club.lineup)


func _lineup_dict_valid(club_id: String, l: Dictionary) -> bool:
	if Schools.is_house(club_id):
		return Schools.human_lineup_valid(w, club_id, l)
	if l.is_empty() or str(l.get("K", "")) == "" or str(l.get("S", "")) == "":
		return false
	if l.get("C", []).size() != 3 or l.get("B", []).size() != 2:
		return false
	var ids: Array = [l["K"]] + l["C"] + l["B"] + [l["S"]]
	var seen := {}
	for pid in ids:
		if seen.has(pid) or not w.players.has(pid):
			return false
		var p: Player = w.players[pid]
		if p.club_id != club_id or not p.is_available():
			return false
		seen[pid] = true
	return true


func match_seed(f: Dictionary) -> int:
	return SimRng.derived_seed(w.seed_value, str(f["id"]))


## Simulator team for a club or a national team (nt_*).
func team_for(team_id: String) -> SimTeam:
	if team_id.begins_with("nt_"):
		return NationalTeams.sim_team(w, team_id, loader.brooms)
	if Schools.is_house(team_id):
		return Schools.sim_team(w, team_id, loader.brooms)
	return sim_team_for(team_id)


func _rules_for(comp: Competition) -> Dictionary:
	var cap = comp.time_cap()
	if cap == null:
		return loader.rules
	var r := loader.rules.duplicate(true)
	r["time_cap_minutes"] = int(cap)
	return r


func _weather_for(f: Dictionary) -> String:
	var r := SimRng.derived(w.seed_value, "weather:%s" % str(f["id"]))
	var m := WDate.month(int(f["day"]))
	var hc: Club = w.team_club(str(f.get("home_id", "")))
	var region := hc.region_id if hc != null else ""
	var regs: Dictionary = loader.climate.get("regions", {})
	var cl: Dictionary = regs.get(region, loader.climate.get("default", {"hemisphere": "N", "rain": 0.12, "snow": 0.05}))
	var hemi := str(cl.get("hemisphere", "N"))
	var winter := 0.0
	if hemi == "N":
		winter = {12: 1.0, 1: 1.0, 2: 0.9, 11: 0.5, 3: 0.4}.get(m, 0.0)
	elif hemi == "S":
		winter = {6: 1.0, 7: 1.0, 8: 0.9, 5: 0.5, 9: 0.4}.get(m, 0.0)
	var rain := float(cl.get("rain", 0.12)) * (1.0 + 0.5 * winter)
	var snow := float(cl.get("snow", 0.0)) * winter
	var storm := rain * 0.25
	var fog := 0.02 + 0.03 * winter
	var wind := 0.1
	var cloudy := 0.25
	var clear := maxf(0.05, 1.0 - rain - snow - storm - fog - wind - cloudy)
	var kinds := ["clear", "cloudy", "wind", "rain", "storm", "fog", "snow"]
	var weights := PackedFloat32Array([clear, cloudy, wind, rain, storm, fog, snow])
	return kinds[maxi(r.pick_weighted(weights), 0)]


func _play_ai_match(comp: Competition, f: Dictionary) -> void:
	var home := team_for(f["home_id"])
	var away := team_for(f["away_id"])
	var sim := MatchSim.new(_rules_for(comp), loader.params)
	sim.min_log_importance = MatchEvent.Importance.MAJOR
	var r := sim.run(home, away, match_seed(f), [], _weather_for(f))
	var canon := _canon_finalist(comp, f)
	if canon == "" and str(f.get("stage", "")) != "final":
		canon = WorldGenerator.canon_wc_winner(w, comp.id, str(f["home_id"]), str(f["away_id"]))
	var tries := 0
	while canon != "" and tries < WorldGenerator.CANON_RETRIES and not WorldGenerator.canon_won_outright(r, canon, str(f["home_id"])):
		tries += 1
		sim = MatchSim.new(_rules_for(comp), loader.params)
		sim.min_log_importance = MatchEvent.Importance.MAJOR
		home = team_for(f["home_id"])
		away = team_for(f["away_id"])
		r = sim.run(home, away, match_seed(f) + WorldGenerator.CANON_RETRY_SEED_STEP * tries, [], _weather_for(f))
	apply_result(comp, f, r, home, away)


func _canon_finalist(comp: Competition, f: Dictionary) -> String:
	if not bool(w.settings.get("book_events", true)) or not comp.id.begins_with("comp_world_cup_") or str(f.get("stage", "")) == "final":
		return ""
	for e in loader.events:
		if str(e.get("kind", "")) != "wc_final" or not comp.id.begins_with(str(e.get("competition_id", "")).trim_suffix("_final")):
			continue
		var fin := [str(e["home"]), str(e["away"])]
		var h := str(f["home_id"])
		var a := str(f["away_id"])
		if fin.has(h) and fin.has(a):
			return ""
		if fin.has(h):
			return h
		if fin.has(a):
			return a
	return ""


func _prepare_human_match(comp_id: String, f: Dictionary) -> void:
	var comp: Competition = w.competitions[comp_id]
	var home := team_for(f["home_id"])
	var away := team_for(f["away_id"])
	var sim := MatchSim.new(_rules_for(comp), loader.params)
	sim.min_log_importance = MatchEvent.Importance.FLOW
	sim.begin(home, away, match_seed(f), _weather_for(f))
	pending_match = PendingMatch.new()
	pending_match.fixture = f
	pending_match.comp_id = comp_id
	pending_match.home = home
	pending_match.away = away
	pending_match.sim = sim


## A job change can leave the pending match with no team of the manager's in it. The AI plays it when the day
## resumes, as it plays a fixture held back over the lineup after a job change.
func _release_foreign_pending_match() -> void:
	if pending_match != null and not (_is_human(pending_match.fixture["home_id"]) or _is_human(pending_match.fixture["away_id"])):
		pending_match = null


## The UI finished the pending match: record it and run the rest of the day (at once; tools and tests).
func complete_pending_match() -> MatchResult:
	var r := complete_pending_match_begin()
	while not step_day(1 << 30):
		pass
	return r


## complete_pending_match in slices, like advance_day_slice: a call with a match pending records it and queues the rest
## of the day, then each call runs steps for `budget_ms`. True when the day is done (then day_result()).
func complete_pending_match_slice(budget_ms: int) -> bool:
	if pending_match != null:
		complete_pending_match_begin()
	return step_day(budget_ms)


## Records the pending match and queues the rest of the day without running it: the UI drives step_day() until it
## returns true, then day_result() (an urgent owl, or "match" when another human match of the day is left pending).
## The rest is the resume of an open day, not the close alone: a job change since the matches step can have turned
## another held-back fixture of today into an AI one, and closing over it would leave it unplayed and close the day
## twice once begin_day resumes it.
func complete_pending_match_begin() -> MatchResult:
	if pending_match == null:
		return null
	var sim := pending_match.sim
	while not sim.is_over():
		sim.step(1 << 30, MatchEvent.Importance.NEVER_STOP)
	var r := sim.finish()
	apply_result(w.competitions[pending_match.comp_id], pending_match.fixture, r, pending_match.home, pending_match.away)
	last_match = PlayedMatch.new()
	last_match.result = r
	last_match.home = pending_match.home
	last_match.away = pending_match.away
	last_match.fixture = pending_match.fixture
	last_match.comp_id = pending_match.comp_id
	pending_match = null
	_steps = []
	_step_i = 0
	_insert_at = 0
	_day_result = {"stopped": false, "reason": ""}
	_queue("resume", _queue_resume_open_day)
	return r


func apply_result(comp: Competition, f: Dictionary, r: MatchResult, home: SimTeam, away: SimTeam) -> void:
	f["played"] = true
	f["score_home"] = r.score_home
	f["score_away"] = r.score_away
	f["snitch_team_id"] = r.snitch_team_id
	f["snitch_player_id"] = r.snitch_player_id
	f["duration_s"] = r.duration_s
	f["end_reason"] = r.end_reason
	f["weather"] = r.weather
	var hc: Club = w.club(r.home_id)
	var ac: Club = w.club(r.away_id)
	var is_national := hc == null or ac == null
	var friendly := comp.type == Competition.Type.FRIENDLY
	var derby := not is_national and not friendly and Rivalries.are_rivals(w, r.home_id, r.away_id)
	if not is_national and not friendly:
		var att := Grounds.attendance(w, hc, ac, comp, rng())
		f["attendance"] = int(att["attendance"])
		Economy.match_income(w, hc, ac, rng(), float(att["fill"]))
		Economy.match_income(w, ac, hc, rng(), float(att["fill"]))
		Fans.after_match(hc, r.score_home, r.score_away)
		Fans.after_match(ac, r.score_away, r.score_home)
		if derby:
			Rivalries.derby_fans(hc, ac, r.score_home, r.score_away)
	if not friendly:
		for tid in [r.home_id, r.away_id]:
			if _is_human(tid):
				var spell := _open_spell(tid)
				if not spell.is_empty():
					spell["official_matches"] = int(spell.get("official_matches", 0)) + 1
	_serve_suspensions(r.home_id, home)
	_serve_suspensions(r.away_id, away)
	var called_up: Dictionary[String, Array] = {}
	for pair in [[home, hc, r.score_home > r.score_away], [away, ac, r.score_away > r.score_home]]:
		var t: SimTeam = pair[0]
		var club: Club = pair[1]
		var won: bool = pair[2]
		for sp in t.players:
			var p: Player = w.player(sp.id)
			if p == null:
				continue
			var rating := Progression.match_rating(sp.stats, sp.position, won)
			if comp.type == Competition.Type.LEAGUE:
				p.month_ratings.append(snappedf(rating, 0.1))
			for st in ([] if friendly else [p.stats_for(w.season), p.stats_for_comp(w.season, comp.id)]):
				st["apps"] += 1
				st["goals"] += int(sp.stats.get("goals", 0))
				st["catches"] += int(sp.stats.get("snitch_catch", 0))
				st["saves"] += int(sp.stats.get("saves", 0))
				st["fouls"] += int(sp.stats.get("fouls", 0))
				st["hits"] = int(st.get("hits", 0)) + int(sp.stats.get("bludger_hits_dealt", 0))
				st["feints"] = int(st.get("feints", 0)) + int(sp.stats.get("feints", 0))
				st["injuries"] = int(st.get("injuries", 0)) + (1 if sp.injured else 0)
				st["minutes"] += int(sp.stats.get("minutes", r.duration_s / 60))
				st["rating_sum"] += rating
			p.form.append(snappedf(rating, 0.1))
			if p.form.size() > 5:
				p.form.pop_front()
			var at_home := t == home
			var row := []
			row.resize(Player.MatchLog.COLUMNS)
			row[Player.MatchLog.DAY] = w.today
			row[Player.MatchLog.COMP_ID] = comp.id
			row[Player.MatchLog.OPPONENT_ID] = r.away_id if at_home else r.home_id
			row[Player.MatchLog.HOME] = 1 if at_home else 0
			row[Player.MatchLog.SCORED] = r.score_home if at_home else r.score_away
			row[Player.MatchLog.CONCEDED] = r.score_away if at_home else r.score_home
			row[Player.MatchLog.GOALS] = int(sp.stats.get("goals", 0))
			row[Player.MatchLog.SAVES] = int(sp.stats.get("saves", 0))
			row[Player.MatchLog.CATCHES] = int(sp.stats.get("snitch_catch", 0))
			row[Player.MatchLog.BLUDGER_HITS] = int(sp.stats.get("bludger_hits_dealt", 0))
			row[Player.MatchLog.RATING_X10] = int(round(rating * 10.0))
			p.log_match(row, MATCH_LOG_OWN if (p.club_id == w.player_club_id and w.player_club_id != "") else MATCH_LOG_OTHERS)
			p.condition = clampf(sp.condition, POST_MATCH_CONDITION_FLOOR, 100.0)
			p.sharpness = minf(100.0, p.sharpness + 8.0)
			var derby_morale: float = Rivalries.morale_swing(t.id, r.winner_id()) if derby else 0.0
			p.morale = clampf(p.morale + (6.0 if won else -5.0) + (rating - 6.0) * 2.0 + derby_morale, 0.0, 100.0)
			w.minutes_month[p.id] = int(w.minutes_month.get(p.id, 0)) + int(sp.stats.get("minutes", r.duration_s / 60))
			if sp.injured:
				Progression.apply_match_injury(p, sp.injury_severity, rng())
				_record_injury(p)
				var pclub: Club = w.club(p.club_id)
				if pclub != null:
					var my_lg: String = w.my_club().league_id if w.my_club() != null else "comp_british_irish_league"
					if pclub.league_id == my_lg or p.injury_days >= 60 or comp.type != Competition.Type.LEAGUE:
						_append_news_item(NewsGenerator.injury_item(w, p, pclub))
					if pclub.manager_is_human:
						Inbox.tell(w, &"from.mediwizard", "msg.injury.subject", "msg.injury.body", {"player": Say.player(p), "days": Say.num(p.injury_days)})
				elif w.is_school_mode() and p.squad == Player.Squad.SCHOOL and Schools.house_id(p.school_id, p.house) == w.player_club_id:
					Inbox.tell(w, &"from.matron", "msg.injury.subject", "msg.injury.body", {"player": Say.player(p), "days": Say.num(p.injury_days)})
			if is_national and p.club_id == w.player_club_id and w.player_club_id != "" and str(w.manager.get("national_team_id", "")) != t.id:
				if not called_up.has(t.id):
					called_up[t.id] = []
				called_up[t.id].append(Say.player(p))
			if sp.sent_off:
				p.suspension_matches = 1
	for ntid in called_up.keys():
		Inbox.tell(w, &"from.club_secretary", "msg.call_up.subject", "msg.call_up.body", {"player": Say.list(called_up[ntid]), "team": Say.team(w, ntid), "competition": Say.comp(comp.id)})
	var my_league: String = w.my_club().league_id if w.my_club() != null else ""
	var my_region: String = w.my_club().region_id if w.my_club() != null else "british_isles"
	if comp.type == Competition.Type.SCHOOL_CUP:
		if comp.id == my_league or (my_league == "" and comp.region_id == my_region):
			_append_news_item(NewsGenerator.match_item(w, r, f, comp))
	elif comp.type == Competition.Type.FRIENDLY:
		pass
	elif comp.type != Competition.Type.LEAGUE or comp.id == my_league:
		_append_news_item(NewsGenerator.match_item(w, r, f, comp))
	last_day_log.append({"type": "match", "fixture": f, "summary": r.summary()})
	Records.after_match(w, comp, r)
	for cid in [r.home_id, r.away_id]:
		var bc: Club = w.club(cid)
		if bc != null and bc.manager_is_human:
			if not friendly:
				Contracts.match_bonuses(w, bc, r.player_stats)
				Press.pre_match_backfire(w, r, cid)
			if comp.type == Competition.Type.LEAGUE and not w.is_school_mode():
				_board_ultimatum_check(bc)
	var me_club := w.my_club()
	if me_club != null and not friendly and (r.home_id == me_club.id or r.away_id == me_club.id):
		var me := me_club
		var won := r.winner_id() == me.id
		var drew := r.winner_id() == ""
		var conf: float = float(me.board.get("confidence", 60.0))
		me.board["confidence"] = clampf(conf + (1.0 if won else (-1.5 if not drew else 0.0)), 0.0, 100.0)
		if not is_national:
			var fs := Rivalries.former_star_item(w, me.id, away if r.home_id == me.id else home, r)
			if not fs.is_empty():
				_append_news_item(fs)
	if comp.is_knockout():
		var info := comp.advance_bracket(rng(), w.today)
		if info["finished"]:
			_on_cup_finished(comp)


func _serve_suspensions(team_id: String, t: SimTeam) -> void:
	var played := {}
	for sp in t.players:
		played[sp.id] = true
	var pool: Array = []
	if team_id.begins_with("nt_"):
		var country := str(w.national_teams.get(team_id, {}).get("country_id", ""))
		for p in w.club_players(""):
			if p.squad == Player.Squad.ABROAD and p.nationality == country:
				pool.append(p)
	else:
		pool = w.club_players(team_id)
	for p in pool:
		if p.suspension_matches > 0 and not played.has(p.id):
			p.suspension_matches -= 1


func _on_cup_finished(comp: Competition) -> void:
	var champ := comp.champion_id
	var runner := ""
	var score := ""
	var scripted := false
	var final_year := comp.season
	for f in comp.fixtures:
		if str(f.get("stage", "")) == "final" and bool(f.get("played", false)):
			runner = str(f["away_id"]) if str(f["home_id"]) == champ else str(f["home_id"])
			score = "%d–%d" % [int(f.get("score_home", 0)), int(f.get("score_away", 0))] if str(f["home_id"]) == champ else "%d–%d" % [int(f.get("score_away", 0)), int(f.get("score_home", 0))]
			scripted = bool(f.get("scripted", false))
			final_year = WDate.year(int(f["day"]))
	if w.club(champ) != null and not Schools.is_house(champ):
		Contracts.title_bonuses(w, w.club(champ))
		Fans.title(w.club(champ), 10.0)
	w.history.push_front({"season": w.season, "competition_id": comp.id, "champion_id": champ, "runner_up_id": runner, "score": score, "third_id": comp.third_id, "table": [], "name": comp.display_name(), "canon": scripted})
	if champ != "" and champ == w.player_club_id and w.my_club() != null:
		var bonus := Career.cup_bonus(comp.type, w.my_club())
		if bonus > 0:
			Career.add_reputation(w, bonus)
			_add_manager_title(comp.id, champ, "club")
	elif comp.type == Competition.Type.WC_KNOCKOUT and champ != "" and champ == str(w.manager.get("national_team_id", "")):
		_add_manager_title(comp.id, champ, "national")
		_trophy_owl("from.federation", comp.id, champ, str(final_year))
	if comp.type == Competition.Type.WC_KNOCKOUT:
		if w.national_teams.has(champ):
			w.national_teams[champ]["world_cup_titles"] = int(w.national_teams[champ].get("world_cup_titles", 0)) + 1
		_append_news_item(NewsGenerator.item("news.world_cup_champion", 5, {"team": Say.team(w, champ), "year": Say.num(final_year)}))
		if w.my_club() != null:
			Inbox.tell(w, &"from.club_secretary", "msg.world_cup_over.subject", "msg.world_cup_over.body", {"team": Say.team(w, champ), "year": Say.num(final_year)})
	elif comp.type == Competition.Type.CONT_KNOCKOUT:
		var cc: Club = w.club(champ)
		if cc != null:
			cc.history["continental_cups"] = int(cc.history.get("continental_cups", 0)) + 1
			_cup_reputation(cc, 0.05)
			Economy.book(w, cc, "prizes", int(comp.prizes.get("champion", 4000)))
		_append_news_item(NewsGenerator.item("news.continental_champion", 4, {"team": Say.team(w, champ), "cup": Say.comp(comp.id)}))
		if w.my_club() != null and champ == w.player_club_id:
			Inbox.tell(w, &"from.board", "msg.continental_won.subject", "msg.continental_won.body", {"cup": Say.comp(comp.id)})
	elif comp.type == Competition.Type.NATIONAL_CUP:
		var nc: Club = w.club(champ)
		if nc != null:
			nc.history["national_cups"] = int(nc.history.get("national_cups", 0)) + 1
			_cup_reputation(nc, 0.02)
			Economy.book(w, nc, "prizes", int(comp.prizes.get("champion", 2000)))
		_append_news_item(NewsGenerator.item("news.national_cup_champion", 3, {"team": Say.team(w, champ), "cup": Say.comp(comp.id)}, {"clubs": [champ]}))
		if w.my_club() != null and champ == w.player_club_id:
			Inbox.tell(w, &"from.board", "msg.national_cup_won.subject", "msg.national_cup_won.body", {"cup": Say.comp(comp.id)})
	elif comp.type == Competition.Type.HOUSE_WORLD:
		if w.houses.has(champ):
			w.houses[champ]["world_cups"] = int(w.houses[champ].get("world_cups", 0)) + 1
			var sname := str(loader.schools.get(str(w.houses[champ].get("school_id", "")), {}).get("short_name", ""))
			_append_news_item(NewsGenerator.item("news.house_world_champion", 4, {"team": Say.team(w, champ), "school": Say.plain(sname), "year": Say.num(final_year)}))
			if w.is_school_mode() and comp.has_team(w.player_club_id):
				var won := champ == w.player_club_id
				Inbox.tell(w, &"from.head_of_house", "msg.house_world_won.subject" if won else "msg.house_world_over.subject", "msg.house_world_won.body" if won else "msg.house_world_over.body", {"team": Say.team(w, champ), "school": Say.plain(sname)})
	elif comp.type == Competition.Type.CUP:
		var c: Club = w.club(champ)
		if c != null:
			c.history["european_cups"] = int(c.history.get("european_cups", 0)) + 1
			_cup_reputation(c, 0.06)
			Economy.book(w, c, "prizes", int(comp.prizes.get("champion", 6000)))
		_append_news_item(NewsGenerator.item("news.european_cup_champion", 5, {"team": Say.team(w, champ), "year": Say.num(final_year)}))
		if w.my_club() != null and champ == w.player_club_id:
			Inbox.tell(w, &"from.board", "msg.european_cup_won.subject", "msg.european_cup_won.body", {"year": Say.num(final_year)})


## The season's dated events as [month, day, handler(year)] in date order; handlers that share a date run in the
## order listed.
func _calendar() -> Array:
	return [
		[8, 2, _preseason_friendlies],  # [game]
		[8, 15, _offer_national_job],
		[9, 1, _open_season_cups],
		[9, 1, _create_nt_friendlies],
		[9, 1, _house_term_owl],
		[9, 2, _review_national_job],
		[9, 2, _drop_old_cups],
		[2, 1, _create_continental_knockouts],
		[5, 28, _create_house_world_cup],
		[6, 1, _loan_options],
		[6, 20, _open_world_cup_final],
	]


func _calendar_events() -> void:
	var m := WDate.month(w.today)
	var d := WDate.day_of_month(w.today)
	var y := WDate.year(w.today)
	for e in _calendar():
		if int(e[0]) == m and int(e[1]) == d:
			e[2].call(y)
	if d == 10 and m % 2 == 0 and w.my_club() != null and not w.is_school_mode() and not w.my_club().board.has("request"):
		_board_request()
	if WDate.weekday(w.today) == Time.WEEKDAY_MONDAY:
		_board_request_check()


func _open_season_cups(y: int) -> void:
	var ce_year := y + 1
	if (ce_year - 1995) % 3 == 0 and ce_year >= 1995 and not w.competitions.has("comp_european_cup_%d" % ce_year):
		_create_european_cup(ce_year)
	_create_national_cups(y)
	_create_continental_cups(y)
	var next_wc := y + 4
	if WorldGenerator.is_world_cup_year(y) and not w.competitions.has("comp_world_cup_%d_groups" % next_wc):
		var gen: WorldGenerator = WorldGenerator.new(loader)
		gen._build_world_cup_groups(w, rng(), next_wc, false)


func _loan_options(_y: int) -> void:
	MarketActions.loan_options_tick(w)


func _preseason_friendlies(y: int) -> void:
	if w.my_club() != null and not w.is_school_mode():
		_create_friendlies(y)


func _house_term_owl(_y: int) -> void:
	if not w.is_school_mode():
		return
	if w.league_of(w.player_club_id) == null:
		Inbox.tell(w, &"from.head_of_house", "msg.house_no_cup.subject", "msg.house_no_cup.body", {"season": Say.season(w.season)})
	else:
		Inbox.tell(w, &"from.head_of_house", "msg.house_term.subject", Schools.term_body_key(w, w.player_club_id), {"season": Say.season(w.season)})


func _offer_national_job(_y: int) -> void:
	if str(w.manager.get("national_team_id", "")) == "" and w.my_club() != null and not w.is_school_mode():
		_national_job_offer()


func _review_national_job(y: int) -> void:
	if WorldGenerator.is_world_cup_year(y) and str(w.manager.get("national_team_id", "")) != "":
		_national_review(y)


func _open_world_cup_final(y: int) -> void:
	if WorldGenerator.is_world_cup_year(y) and w.competitions.has("comp_world_cup_%d_groups" % y) and not w.competitions.has("comp_world_cup_%d_final" % y):
		_create_world_cup_final(y)


func _drop_old_cups(_y: int) -> void:
	for cid in w.competitions.keys().duplicate():
		var c: Competition = w.competitions[cid]
		if c.type != Competition.Type.LEAGUE and c.is_finished() and c.season < w.season - FINISHED_CUP_SEASONS_KEPT:
			w.competitions.erase(cid)


func _create_national_cups(year: int) -> void:  # [FILLER]
	for lg in w.leagues():
		var cid := "comp_national_cup_%s_%d" % [lg.id.trim_prefix("comp_"), year]
		if w.competitions.has(cid) or lg.club_ids.size() < 4:
			continue
		var ids: Array = lg.club_ids.duplicate()
		ids.sort_custom(func(a, b): return w.club(a).reputation > w.club(b).reputation if w.club(a).reputation != w.club(b).reputation else a < b)
		var p := 2
		while p < ids.size():
			p *= 2
		var rounds := 0
		while (1 << rounds) < p:
			rounds += 1
		var all_days := [_thursday(year, 10, 14), _thursday(year, 12, 2), _thursday(year + 1, 2, 3), _thursday(year + 1, 4, 21)].map(_clear_of_national_windows)
		var comp := Competition.new()
		comp.id = cid
		comp.name = "Copa de la %s" % lg.name
		comp.name_en = "%s Cup" % lg.display_name()
		comp.type = Competition.Type.NATIONAL_CUP
		comp.region_id = lg.region_id
		comp.level = lg.level
		comp.parent_id = lg.id
		comp.format = {"table": "knockout", "time_cap_minutes": null}
		comp.venues = lg.venues.duplicate()
		comp.prizes = {"champion": 2000 if lg.level <= 1 else 1200}
		comp.source = "filler"
		comp.build_bracket(rng(), year, ids, all_days.slice(maxi(all_days.size() - rounds, 0)), false)
		w.competitions[cid] = comp
	if w.my_club() != null and not w.is_school_mode():
		for c in w.competitions.values():
			if c.type == Competition.Type.NATIONAL_CUP and c.season == year and c.has_team(w.player_club_id):
				Inbox.tell(w, &"from.club_secretary", "msg.national_cup_draw.subject", "msg.national_cup_draw.body", {"cup": Say.comp(c.id)}, Inbox.QUIET)


const EUROPEAN_REGIONS := ["british_isles", "eastern_europe", "france", "germany", "iberia_lux", "nordic", "italy", "low_countries", "central_europe"]  # [FILLER]
const CONTINENTAL := {
	"bowman_wright": {"slots": {"comp_british_irish_league": 2, "comp_eastern_europe_league": 2, "comp_france_league": 2, "comp_germany_league": 2, "comp_iberia_lux_league": 2, "comp_nordic_league": 2, "comp_italy_league": 2, "comp_low_countries_league": 1, "comp_central_europe_league": 1}, "prize": 5000},
	"castelobruxo": {"slots": {"comp_argentina_league": 3, "comp_brazil_league": 3, "comp_andes_league": 2}, "prize": 3500},
	"thunderbird": {"slots": {"comp_usa_league": 4, "comp_canada_league": 2, "comp_mexico_caribbean_league": 2}, "prize": 3500},
	"mahoutokoro": {"slots": {"comp_japan_league": 3, "comp_east_asia_league": 3, "comp_india_league": 2}, "prize": 3500},
}


func _create_continental_cups(year: int) -> void:
	for key in CONTINENTAL.keys():
		var gid := "comp_cont_%s_%d_groups" % [key, year + 1]
		if w.competitions.has(gid):
			continue
		var cfg: Dictionary = CONTINENTAL[key]
		var ids: Array = []
		for lid in cfg["slots"].keys():
			if w.competitions.has(lid):
				var top := _league_top(w.competitions[lid], int(cfg["slots"][lid]))
				var cup_champ := _national_cup_champion(lid)
				if cup_champ != "" and not top.has(cup_champ) and not top.is_empty():
					top[top.size() - 1] = cup_champ
				ids += top
		var n_groups := ids.size() / 4
		if n_groups < 2:
			continue
		ids = ids.slice(0, n_groups * 4)
		ids.sort_custom(func(a, b): return w.club(a).reputation > w.club(b).reputation if w.club(a).reputation != w.club(b).reputation else a < b)
		var groups := {}
		for g in n_groups:
			groups[char(65 + g)] = [ids[g]]
		for pot_i in range(1, 4):
			var pot: Array = ids.slice(pot_i * n_groups, (pot_i + 1) * n_groups)
			for i in range(pot.size() - 1, 0, -1):
				var j := rng().irange(0, i)
				var tmp = pot[i]
				pot[i] = pot[j]
				pot[j] = tmp
			for cid in pot:
				var best := ""
				for g in groups.keys():
					if groups[g].size() > pot_i:
						continue
					if best == "" or (not _group_has_clash(groups[g], str(cid)) and _group_has_clash(groups[best], str(cid))):
						best = g
				groups[best].append(str(cid))
		var comp := Competition.new()
		comp.id = gid
		comp.name = "%s %d" % [key.capitalize(), year + 1]
		comp.name_en = comp.name
		comp.type = Competition.Type.CONT_GROUPS
		comp.region_id = "continental"
		comp.level = 0
		comp.format = {"rounds": 2, "table": "points_scored", "tiebreak": ["points_conceded_asc", "snitch_catches_desc"], "time_cap_minutes": null}
		comp.season = year
		comp.groups = groups
		var all_ids: Array = []
		for g in groups.values():
			all_ids += g
		comp.club_ids = all_ids
		var venues: Array = []
		for lid in cfg["slots"].keys():
			if w.competitions.has(lid):
				venues += w.competitions[lid].venues
		comp.venues = venues
		comp.prizes = {"champion": int(cfg["prize"]), "participation": 500}
		comp.source = "filler"
		var dates: Array = []
		var first := _weekday_on_or_after(year, 9, 15, Time.WEEKDAY_WEDNESDAY)
		for k in 6:
			dates.append(_clear_of_national_windows(first + 14 * k))
		comp.build_group_fixtures(rng(), dates)
		w.competitions[gid] = comp
		for cid in all_ids:
			Economy.book(w, w.club(cid), "prizes", 500)
		if w.my_club() != null and not w.is_school_mode() and all_ids.has(w.player_club_id):
			Inbox.tell(w, &"from.board", "msg.continental_qualified.subject", "msg.continental_qualified.body", {"cup": Say.comp(comp.id)})


func _group_has_clash(group: Array, cid: String) -> bool:
	for other in group:
		if w.club(other).league_id == w.club(cid).league_id:
			return true
	return false


func _national_cup_champion(league_id: String) -> String:
	var prefix := "comp_national_cup_%s_" % league_id.trim_prefix("comp_")
	for h in w.history:
		if str(h["competition_id"]).begins_with(prefix) and int(h["season"]) == w.season - 1:
			var c := str(h.get("champion_id", ""))
			return c if w.clubs.has(c) else ""
	return ""


func _league_top(lg: Competition, n: int) -> Array:
	var out: Array = []
	for h in w.history:
		if str(h["competition_id"]) == lg.id and int(h["season"]) == w.season - 1:
			for row in h.get("table", []):
				if w.clubs.has(str(row["club_id"])) and out.size() < n:
					out.append(str(row["club_id"]))
			return out
	var ids: Array = lg.club_ids.duplicate()
	ids.sort_custom(func(a, b): return w.club(a).reputation > w.club(b).reputation if w.club(a).reputation != w.club(b).reputation else a < b)
	return ids.slice(0, n)


func _create_continental_knockouts(year: int) -> void:
	for key in CONTINENTAL.keys():
		var gid := "comp_cont_%s_%d_groups" % [key, year]
		var kid := "comp_cont_%s_%d_final" % [key, year]
		if not w.competitions.has(gid) or w.competitions.has(kid):
			continue
		var g: Competition = w.competitions[gid]
		var letters := g.groups.keys()
		letters.sort()
		var firsts: Array = []
		var seconds: Array = []
		for letter in letters:
			var st := g.group_standings(letter)
			if st.size() >= 2:
				firsts.append(str(st[0]["club_id"]))
				seconds.append(str(st[1]["club_id"]))
		var seeded: Array = firsts + seconds
		var n := seeded.size()
		if n < 4:
			continue
		var comp := Competition.new()
		comp.id = kid
		comp.name = g.name
		comp.name_en = g.name_en
		comp.type = Competition.Type.CONT_KNOCKOUT
		comp.region_id = "continental"
		comp.level = 0
		comp.parent_id = gid
		comp.format = {"table": "knockout", "time_cap_minutes": null, "replay_offset": 4}
		comp.venues = g.venues.duplicate()
		comp.prizes = g.prizes.duplicate()
		comp.source = "filler"
		var days := [_weekday_on_or_after(year, 3, 1, Time.WEEKDAY_WEDNESDAY), _weekday_on_or_after(year, 4, 1, Time.WEEKDAY_WEDNESDAY), _weekday_on_or_after(year, 5, 20, Time.WEEKDAY_WEDNESDAY)].map(_clear_of_national_windows)
		comp.build_bracket(rng(), year - 1, seeded, days.slice(3 - (2 if n == 4 else 3)), false)
		w.competitions[kid] = comp
		if w.my_club() != null and not w.is_school_mode() and seeded.has(w.player_club_id):
			Inbox.tell(w, &"from.board", "msg.continental_qualified.subject", "msg.continental_ko.body", {"cup": Say.comp(comp.id)})


func _weekday_on_or_after(y: int, m: int, d: int, wd: int) -> int:
	var day := WDate.from_ymd(y, m, d)
	while WDate.weekday(day) != wd:
		day += 1
	return day


func _thursday(y: int, m: int, d: int) -> int:
	var day := WDate.from_ymd(y, m, d)
	while WDate.weekday(day) != Time.WEEKDAY_THURSDAY:
		day += 1
	return day


## A club cup date moved on a week at a time, so it keeps its weekday, until no national squad is away that day.
func _clear_of_national_windows(day: int) -> int:
	var window := WorldGenerator.national_window(WDate.year(day) if WDate.month(day) >= 7 else WDate.year(day) - 1)
	while window.has(day):
		day += 7
	return day


func _create_european_cup(year: int) -> void:
	var european := EUROPEAN_REGIONS  # [FILLER]
	var qualified := []
	var runners := []
	var thirds := []
	for comp in w.leagues():
		if not european.has(comp.region_id):
			continue
		var table: Array = []
		for h in w.history:
			if h["competition_id"] == comp.id and int(h["season"]) == w.season - 1:
				table = h["table"]
				break
		if table.is_empty():
			table = comp.standings()
		if table.size() >= 2:
			qualified.append(str(table[0]["club_id"]))
			runners.append({"id": str(table[1]["club_id"]), "level": comp.level})
		if table.size() >= 3:
			thirds.append({"id": str(table[2]["club_id"]), "pts": int(table[2]["pts"])})
	var by_rep := func(a, b): return w.club(a).reputation > w.club(b).reputation if w.club(a).reputation != w.club(b).reputation else a < b
	if qualified.size() > 16:
		qualified.sort_custom(by_rep)
		qualified = qualified.slice(0, 16)
	runners.sort_custom(func(a, b): return a["level"] < b["level"] if a["level"] != b["level"] else by_rep.call(a["id"], b["id"]))
	for t in runners:
		if qualified.size() >= 16:
			break
		qualified.append(str(t["id"]))
	thirds.sort_custom(func(a, b): return a["pts"] > b["pts"] if a["pts"] != b["pts"] else str(a["id"]) < str(b["id"]))
	for t in thirds:
		if qualified.size() >= 16:
			break
		qualified.append(str(t["id"]))
	if qualified.size() < 4:
		return
	qualified.sort_custom(by_rep)
	var n := 16 if qualified.size() >= 16 else (8 if qualified.size() >= 8 else 4)
	qualified = qualified.slice(0, n)
	var comp := Competition.new()
	comp.id = "comp_european_cup_%d" % year
	comp.name = "Copa de Europa %d" % year
	comp.name_en = "European Cup %d" % year
	comp.type = Competition.Type.CUP
	comp.region_id = "europe"
	comp.level = 0
	comp.format = {"table": "knockout", "time_cap_minutes": null, "replay_offset": 7}
	comp.venues = ["venue.bodmin", "venue.vratsa", "venue.quiberon", "venue.heidelberg", "venue.braga", "venue.karasjok"]
	comp.prizes = {"champion": 6000, "participation": 800}
	comp.source = "filler"
	var days := [_weekday_on_or_after(year, 2, 19, Time.WEEKDAY_TUESDAY), _weekday_on_or_after(year, 3, 19, Time.WEEKDAY_TUESDAY), _weekday_on_or_after(year, 4, 16, Time.WEEKDAY_TUESDAY), _weekday_on_or_after(year, 5, 14, Time.WEEKDAY_TUESDAY)].map(_clear_of_national_windows)  # [game]
	if n == 8:
		days = days.slice(1)
	elif n == 4:
		days = days.slice(2)
	comp.build_bracket(rng(), year - 1, qualified, days, false)
	w.competitions[comp.id] = comp
	if w.my_club() != null and comp.has_team(w.player_club_id):
		Inbox.tell(w, &"from.board", "msg.european_cup_qualified.subject", "msg.european_cup_qualified.body", {"year": Say.num(year), "n": Say.num(comp.club_ids.size())})
	elif w.my_club() != null and not w.is_school_mode():
		Inbox.tell(w, &"from.club_secretary", "msg.european_cup_draw.subject", "msg.european_cup_draw.body", {"year": Say.num(year), "n": Say.num(comp.club_ids.size())}, Inbox.QUIET)
	var teams: Array = []
	for cid in qualified:
		Economy.book(w, w.club(cid), "prizes", int(comp.prizes.get("participation", 800)))
		teams.append(Say.team(w, cid))
	_append_news_item(NewsGenerator.item("news.european_cup_draw", 4, {"year": Say.num(year), "teams": Say.list(teams)}))


func _create_world_cup_final(year: int) -> void:
	var groups: Competition = w.competitions["comp_world_cup_%d_groups" % year]
	var winners := groups.group_winners()
	if winners.size() < 2:
		return
	var comp := Competition.new()
	comp.id = "comp_world_cup_%d_final" % year
	comp.name = "Mundial de Quidditch %d — Fase final" % year
	comp.name_en = "Quidditch World Cup %d — Final stage" % year
	comp.type = Competition.Type.WC_KNOCKOUT
	comp.region_id = "world"
	comp.level = 0
	comp.format = {"table": "knockout", "time_cap_minutes": null}
	comp.venues = [str(CANON_WC_VENUES[year]) if CANON_WC_VENUES.has(year) else str(rng().pick(["venue.patagonia", "venue.kazakh", "venue.mongolia", "venue.pacific", "venue.tanzania", "venue.altiplano"]))]
	comp.prizes = {}
	comp.source = "canon_pottermore"
	comp.parent_id = groups.id
	var days: Array = WC_FINAL_STAGE_DATES.map(func(md): return WDate.from_ymd(year, md[0], md[1]))
	var n := 16 if winners.size() >= 16 else (8 if winners.size() >= 8 else 4)
	var rounds_needed := 4 if n == 16 else (3 if n == 8 else 2)
	var seeded: Array = winners.slice(0, n)
	var fin := _canon_wc_finalists(comp.id)
	if fin.size() == 2 and seeded.has(fin[0]) and seeded.has(fin[1]):
		seeded.erase(fin[0])
		seeded.erase(fin[1])
		seeded = [fin[0], fin[1]] + seeded
		if year == 1994 and n == 16:
			seeded = _canon_1994_seeds(seeded)
	comp.build_bracket(rng(), year, seeded, days.slice(4 - rounds_needed), true)
	w.competitions[comp.id] = comp
	_append_news_item(NewsGenerator.item("news.world_cup_draw", 5, {"year": Say.num(year), "venue": Say.venue(str(comp.venues[0])), "teams": Say.list(seeded.map(func(t): return Say.team(w, str(t))))}))


## Bracket places, not RNG seeds. They rely on Competition.build_bracket pairing place i with 15 - i, then each
## slot with its mirror: England, Wales and Scotland meet their book conquerors first, Peru meets Ireland in the
## semi-final, and Ireland and Bulgaria only meet in the final.
const CANON_1994_SEEDS := {"nt_irl": 0, "nt_bul": 1, "nt_tra": 2, "nt_per": 3, "nt_uga": 5, "nt_lux": 6, "nt_sco": 9, "nt_wal": 10, "nt_eng": 13}  # [GoF 5]


func _canon_1994_seeds(seeded: Array) -> Array:
	var out: Array = []
	out.resize(seeded.size())
	var rest: Array = []
	for t in seeded:
		if CANON_1994_SEEDS.has(str(t)) and int(CANON_1994_SEEDS[str(t)]) < out.size():
			out[int(CANON_1994_SEEDS[str(t)])] = t
		else:
			rest.append(t)
	for i in out.size():
		if out[i] == null:
			out[i] = rest.pop_front()
	return out


const CANON_WC_VENUES := {
	1994: "venue.dartmoor",
	2014: "venue.patagonia",  # [PM-2014]
}


func _canon_wc_finalists(final_id: String) -> Array:
	if not bool(w.settings.get("book_events", true)):
		return []
	for e in loader.events:
		if str(e.get("kind", "")) == "wc_final" and str(e.get("competition_id", "")) == final_id:
			return [str(e["home"]), str(e["away"])]
	return []


func _create_house_world_cup(year: int) -> void:  # [FILLER]
	var cid := "comp_house_world_%d" % year
	if w.competitions.has(cid):
		return
	var champs := _school_cup_champions(year - 1)
	var ids: Array = champs.values()
	if ids.size() < 2:
		return
	var strength := {}
	for hid in ids:
		strength[hid] = Schools.house_strength(w, str(hid))
	ids.sort_custom(func(a, b): return strength[a] > strength[b] if strength[a] != strength[b] else str(a) < str(b))
	var school_ids: Array = loader.schools.keys()
	school_ids.sort()
	var host := str(school_ids[year % school_ids.size()])
	var comp := Competition.new()
	comp.id = cid
	comp.name = "Copa Mundial de las Casas %d" % year
	comp.name_en = "World Inter-House Cup %d" % year
	comp.type = Competition.Type.HOUSE_WORLD
	comp.region_id = "world"
	comp.level = 9
	comp.format = {"table": "knockout", "time_cap_minutes": null, "host_school_id": host}
	comp.venues = ["school:" + host]
	comp.source = "filler"
	var rounds := 0
	while (1 << rounds) < ids.size():
		rounds += 1
	var first := _weekday_on_or_after(year, 5, 29, 6)
	var days: Array = []
	for r in rounds:
		days.append(first + 7 * r)
	comp.build_bracket(rng(), year - 1, ids, days, false)
	w.competitions[cid] = comp
	var teams: Array = []
	for hid in ids:
		teams.append(Say.phrase("ui.list.name_detail", {"name": Say.team(w, str(hid)), "detail": Say.plain(str(loader.schools.get(str(w.houses[hid]["school_id"]), {}).get("short_name", "")))}).as_arg())
	_append_news_item(NewsGenerator.item("news.house_world_draw", 3, {"year": Say.num(year), "school": Say.plain(str(loader.schools[host].get("short_name", host))), "teams": Say.list(teams)}))
	if w.is_school_mode() and ids.has(w.player_club_id):
		Inbox.tell(w, &"from.head_of_house", "msg.house_world_qualified.subject", "msg.house_world_qualified.body", {"year": Say.num(year), "school": Say.plain(str(loader.schools[host].get("short_name", host)))})


func _school_cup_champions(season: int) -> Dictionary:
	var out := {}
	var book_on := bool(w.settings.get("book_events", true))
	var human_school := str(w.houses.get(w.player_club_id, {}).get("school_id", "")) if w.is_school_mode() else ""
	for sid in loader.schools.keys():
		var cid := "comp_school_%s_%d" % [str(sid).trim_prefix("school_"), season]
		var comp: Competition = w.competitions.get(cid)
		if comp == null:
			continue
		var st := comp.standings()
		if st.is_empty():
			continue
		var champ := str(st[0]["club_id"])
		var book := Schools.canon_cup_champion(loader.events, cid) if book_on else ""
		if w.houses.has(book) and sid != human_school:
			champ = book
		if w.houses.has(champ):
			out[sid] = champ
	return out


func _career_ladder(club: Club, verdict: String, final_pos: int) -> void:
	var rep: int = int(w.manager.get("reputation", 1000))
	var delta := Career.season_delta(w, club, final_pos, verdict)
	var from_day := int(_open_spell(club.id).get("from_day", -1))
	var season_start := WDate.from_ymd(w.season, 8, 1)
	var season_end := WDate.from_ymd(w.season + 1, 6, 1)
	if from_day > season_start:
		delta = int(round(delta * clampf(float(season_end - from_day) / float(season_end - season_start), 0.0, 1.0)))
	rep += delta
	Career.set_reputation(w, rep)
	_count_season()
	if final_pos == 1:
		_add_manager_title(club.league_id, club.id, "club")
		_trophy_owl("from.board", club.league_id, club.id)
	Inbox.tell(w, &"from.assistant", "msg.career.subject", "msg.career.body", {"delta": Say.plain(("+" if delta >= 0 else "") + str(delta)), "rep": Say.num(w.manager["reputation"]), "rank": Say.key(Career.rank_key(int(w.manager["reputation"]))), "expected": Say.num(Career.expected_position(w, club)), "pos": Say.num(final_pos)})
	_rollover.verdict = verdict
	if verdict == "sacked":
		var lg := w.league_of(club.id)
		if lg != null and final_pos >= lg.club_ids.size():
			_rollover.sacked_requirement = Career.club_requirement(club)
		_sack_human(club)
	elif verdict == "met":
		_job_offers(2, true)


func _add_manager_title(competition_id: String, team_id: String, role: String) -> void:
	w.manager["titles"] = int(w.manager.get("titles", 0)) + 1
	var trophies: Array = w.manager.get("trophies", [])
	trophies.append({"season": w.season, "competition_id": competition_id, "team_id": team_id, "role": role})
	w.manager["trophies"] = trophies


func _trophy_owl(from_key: String, competition_id: String, team_id: String, season_label: String = "") -> void:
	Inbox.tell(w, from_key, "msg.trophy.subject", "msg.trophy.body", {"cup": Say.comp(competition_id), "team": Say.team(w, team_id), "season": (Say.plain(season_label) if season_label != "" else Say.season(w.season))})


func _open_spell(club_id: String) -> Dictionary:
	var career: Array = w.manager.get("career", [])
	for i in range(career.size() - 1, -1, -1):
		var e: Dictionary = career[i]
		if str(e.get("club_id", "")) == club_id and not e.has("to"):
			return e
	return {}


func _close_spell(club_id: String, reason: String) -> void:
	var career: Array = w.manager.get("career", [])
	for i in range(career.size() - 1, -1, -1):
		var e: Dictionary = career[i]
		if str(e.get("club_id", "")) == club_id and not e.has("to"):
			e["to"] = w.season - 1 if w.today < WDate.from_ymd(w.season, 8, 1) else w.season
			e["to_day"] = w.today
			e["reason"] = reason
			if w.clubs.has(club_id) and not w.houses.has(club_id):
				var season_start := WDate.from_ymd(w.season, 8, 1)
				var season_end := WDate.from_ymd(w.season + 1, 6, 1)
				var from_day := maxi(int(e.get("from_day", season_start)), season_start)
				if mini(w.today, season_end) - from_day >= (season_end - season_start) / 2:
					_count_season()
			break
	w.manager["career"] = career


func _count_season() -> void:
	if int(w.manager.get("last_counted_season", -1)) == w.season:
		return
	w.manager["last_counted_season"] = w.season
	w.manager["seasons"] = int(w.manager.get("seasons", 0)) + 1


## Resign: the manager leaves the club; −5 % reputation and modest offers arrive.
func resign() -> void:
	var club := w.my_club()
	if club == null or w.is_school_mode():
		return
	_close_spell(club.id, "resigned")
	_leave_club(club.id)
	Career.set_reputation(w, int(int(w.manager.get("reputation", 1000)) * 0.95))
	_hand_club_to_ai(club)
	w.player_club_id = ""
	w.manager_unemployed = true
	Inbox.tell(w, &"from.board", "msg.resigned.subject", "msg.resigned.body", {"club": Say.club(club)})
	_job_offers(2, false)
	_release_foreign_pending_match()


## Vacancies: AI clubs that sacked their manager in the last 60 days.
func vacancies() -> Array:
	var out: Array = []
	for c in w.clubs_sorted():
		if c.manager_is_human or c.id == w.player_club_id or _left_recently(c.id):
			continue
		var past: Array = c.history.get("managers", [])
		if not past.is_empty() and w.today - int(past[-1].get("until", -999)) <= 60:
			out.append(c)
	return out


## Apply for a vacancy: the board replies in 3 to 7 days (yes if reputation is enough; sometimes anyway).
func apply_for(club_id: String) -> bool:
	var apps: Array = w.manager.get("applications", [])
	for a in apps:
		if str(a["club_id"]) == club_id:
			return false
	apps.append({"club_id": club_id, "day": w.today + rng().irange(3, 7)})
	w.manager["applications"] = apps
	return true


func _process_applications() -> void:
	var apps: Array = w.manager.get("applications", [])
	if apps.is_empty():
		return
	var keep: Array = []
	var rep: int = int(w.manager.get("reputation", 1000))
	for a in apps:
		if int(a["day"]) > w.today:
			keep.append(a)
			continue
		var c: Club = w.club(str(a["club_id"]))
		if c == null or c.manager_is_human:
			continue
		var req := Career.club_requirement(c)
		var chance := 0.75 if req <= rep * OFFER_REACH else (0.15 if req <= rep * APPLICATION_REACH else 0.0)
		if _left_recently(c.id):
			chance = 0.0
		if rng().chance(chance):
			_post_job_offer(c)
		else:
			Inbox.tell(w, &"from.board", "msg.application_rejected.subject", "msg.application_rejected.body", {"club": Say.club(c)})
	w.manager["applications"] = keep


## The pre-match conference of `fixture_id` (the pending one when "") is over: held, missed or its day passed. Its
## settings.pre_press record and its owl go.
func end_pre_press(fixture_id: String = "") -> void:
	var pp: Dictionary = w.settings.get("pre_press", {})
	var fid := fixture_id if fixture_id != "" else str(pp.get("fixture_id", ""))
	if str(pp.get("fixture_id", "")) == fid:
		w.settings.erase("pre_press")
	Inbox.close(w, Inbox.find(w, Inbox.PRE_PRESS, fid))


## What ends with the manager's time at `club_id`: its open deals, the records its questions were about, and the
## questions themselves.
func _leave_club(club_id: String) -> void:
	MarketActions.void_open_offers(w, club_id)
	var c: Club = w.club(club_id)
	if c != null:
		c.board.erase("sponsor_offers")
		c.board.erase("contract_review")
	w.settings.erase("pre_press")
	Inbox.close_scope(w, club_id)


func _sack_human(club: Club) -> void:
	_close_spell(club.id, "sacked")
	_leave_club(club.id)
	Inbox.tell(w, &"from.board", "msg.sacked.subject", "msg.sacked.body", {"club": Say.club(club)})
	_hand_club_to_ai(club)
	w.player_club_id = ""
	w.manager_unemployed = true
	_job_offers(3, false)


## Days during which the club the manager has just left makes no offer and takes no application from them.
const LEFT_CLUB_COOLDOWN := 365


func _hand_club_to_ai(club: Club) -> void:
	club.manager_is_human = false
	club.manager_name = _manager_name_for(club)
	club.lineup = WorldGenerator.best_lineup(w, club.id)
	club.board.erase("ultimatum")
	_clear_debt_flags(club)
	club.board["confidence"] = 55.0
	club.board["missed_streak"] = 0
	club.board["last_streak"] = 0
	club.board["manager_since"] = w.today
	w.manager["left_club"] = {"id": club.id, "day": w.today}


func _left_recently(club_id: String) -> bool:
	var lc: Dictionary = w.manager.get("left_club", {})
	return str(lc.get("id", "")) == club_id and w.today - int(lc.get("day", -999999)) < LEFT_CLUB_COOLDOWN


## The manager turned a job offer down: that club does not call again for LEFT_CLUB_COOLDOWN days.
func reject_job(club_id: String) -> void:
	var rj: Dictionary = w.manager.get("rejected_clubs", {})
	rj[club_id] = w.today
	for k in rj.keys():
		if w.today - int(rj[k]) >= LEFT_CLUB_COOLDOWN:
			rj.erase(k)
	w.manager["rejected_clubs"] = rj


func _rejected_recently(club_id: String) -> bool:
	var rj: Dictionary = w.manager.get("rejected_clubs", {})
	return rj.has(club_id) and w.today - int(rj[club_id]) < LEFT_CLUB_COOLDOWN


func _shunned(club_id: String) -> bool:
	return _left_recently(club_id) or _rejected_recently(club_id)


func _board_ultimatum_check(club: Club) -> void:  # [game]
	var lg := w.league_of(club.id)
	if lg == null:
		return
	var row := {}
	for r in lg.standings():
		if str(r["club_id"]) == club.id:
			row = r
	if row.is_empty():
		return
	if not club.board.has("ultimatum"):
		if float(club.board.get("confidence", 60.0)) < Career.ULTIMATUM_CONFIDENCE and [11, 12, 1, 2, 3, 4].has(WDate.month(w.today)) and int(club.board.get("ultimatum_season", 0)) != w.season \
				and _league_matches_left(lg, club.id) >= 5:
			club.board["ultimatum"] = {"played": int(row["pj"]), "wins": int(row["w"])}
			club.board["ultimatum_season"] = w.season
			Inbox.ask(w, Inbox.Decision.new(Inbox.ACK, "", [Inbox.Choice.ok()]).blocking(), &"from.board", "msg.ultimatum.subject", "msg.ultimatum.body", {"club": Say.club(club)})
		return
	var u: Dictionary = club.board["ultimatum"]
	if int(row["pj"]) < int(u["played"]):
		club.board.erase("ultimatum")
		return
	if int(row["pj"]) - int(u["played"]) < 5:
		return
	club.board.erase("ultimatum")
	if int(row["w"]) - int(u["wins"]) >= 3:
		club.board["confidence"] = maxf(float(club.board.get("confidence", 60.0)), 45.0)
		Inbox.tell(w, &"from.board", "msg.ultimatum_met.subject", "msg.ultimatum_met.body")
	else:
		Career.add_reputation(w, -150)
		_sack_human(club)


func _league_matches_left(lg: Competition, club_id: String) -> int:
	var n := 0
	for f in lg.fixtures:
		if not bool(f.get("played", false)) and (str(f["home_id"]) == club_id or str(f["away_id"]) == club_id):
			n += 1
	return n


func _manager_name_for(club: Club) -> String:
	var names := loader.names_for(club.region_id, club.country_id)
	return "%s %s" % [rng().pick(names["first_names_f"] if club.is_women_only() else names["first_names_m"]), FillerGenerator.female_last(names, str(rng().pick(names["last_names"])), club.is_women_only())]


func _job_offers(max_offers: int, step_up: bool) -> void:
	var rep: int = int(w.manager.get("reputation", 1000))
	var home_region := loader.region_of_country(str(w.manager.get("nationality", "eng")))
	var me := w.my_club()
	var my_req := 0
	if me != null and w.is_school_mode():
		var sid := str(w.houses.get(me.id, {}).get("school_id", ""))
		var regs: Array = loader.schools.get(sid, {}).get("region_ids", [])
		if not regs.is_empty():
			home_region = str(regs[0])
	elif me != null:
		home_region = me.region_id
		my_req = Career.club_requirement(me)
	var candidates: Array = []
	var same_level: Array = []
	for c in w.clubs_sorted():
		if c.manager_is_human or c.id == w.player_club_id or _shunned(c.id):
			continue
		var req := Career.club_requirement(c)
		if req > rep * OFFER_REACH:
			continue
		if step_up and req <= my_req * 1.1:
			if req >= my_req * 0.85:
				same_level.append(c)
			continue
		candidates.append(c)
	if candidates.is_empty() and step_up:
		candidates = same_level
	if candidates.is_empty() and w.manager_unemployed:
		var easiest: Array = w.clubs_sorted().filter(func(c): return not c.manager_is_human and not _shunned(c.id))
		easiest.sort_custom(func(a, b): return Career.club_requirement(a) < Career.club_requirement(b) if Career.club_requirement(a) != Career.club_requirement(b) else a.id < b.id)
		candidates = easiest.slice(0, maxi(max_offers * 3, 4))
	if candidates.is_empty():
		return
	var local := candidates.filter(func(c): return c.region_id == home_region)
	var pool: Array = local if local.size() >= max_offers else candidates
	pool.sort_custom(func(a, b): return a.reputation > b.reputation if a.reputation != b.reputation else a.id < b.id)
	pool = pool.slice(0, maxi(max_offers * 3, 4))
	var chosen := []
	while chosen.size() < max_offers and not pool.is_empty():
		var c: Club = rng().pick(pool)
		pool.erase(c)
		chosen.append(c)
	for c in chosen:
		_post_job_offer(c)


const ACCEPT_JOB := &"accept_job"
const REJECT_JOB := &"reject_job"
const ACCEPT_NT_JOB := &"accept_nt_job"
const REJECT_NT_JOB := &"reject_nt_job"
const ACCEPT_SPONSOR := &"accept_sponsor"


## Offers `c`'s job; the open JOB question is the outstanding offer. Returns whether an owl was posted.
func _post_job_offer(c: Club) -> bool:
	if _shunned(c.id):
		return false
	if _rollover != null:
		if not _rollover.deferred.has(c):
			_rollover.deferred.append(c)
		return false
	if Inbox.find(w, Inbox.JOB, c.id) != null:
		return false
	var comp := w.league_of(c.id)
	Inbox.ask(w, Inbox.Decision.new(Inbox.JOB, c.id, [Inbox.Choice.new(ACCEPT_JOB, "ui.action.accept_job"), Inbox.Choice.new(REJECT_JOB, "ui.action.reject", {}, Inbox.BACK)]).blocking(w.manager_unemployed),
		&"from.board", "msg.job_offer.subject", "msg.job_offer.body",
		{"club": Say.club(c), "league": Say.comp(comp.id) if comp else Say.plain(""), "objective": Say.key("objective." + str(c.board.get("objective", ""))), "balance": Say.money(c.balance)})
	return true


func _flush_job_offers() -> void:
	var summer := _rollover
	_rollover = null
	var reach := -1
	if summer.sacked_requirement >= 0:
		reach = mini(int(w.manager.get("reputation", 1000)), summer.sacked_requirement)
	var cap := _summer_offer_cap(summer)
	var posted := 0
	var fallback: Club = null
	for c in summer.deferred:
		if posted >= cap:
			break
		if c.manager_is_human or c.id == w.player_club_id:
			continue
		if reach >= 0 and Career.club_requirement(c) > reach:
			if fallback == null or Career.club_requirement(c) < Career.club_requirement(fallback):
				fallback = c
			continue
		if _post_job_offer(c):
			posted += 1
	if posted == 0 and fallback != null and w.manager_unemployed:
		_post_job_offer(fallback)


func _summer_offer_cap(summer: Rollover) -> int:  # [game]
	var rep := int(w.manager.get("reputation", 1000))
	var cap := 1 if rep < 1500 else (2 if rep < 3000 else 3)
	match summer.verdict:
		"met":
			cap += 1
		"sacked":
			cap = 1 if summer.sacked_requirement >= 0 else mini(cap, 2)
	return clampi(cap, 1, 3)


func _sponsor_offer(c: Club) -> Dictionary:  # [FILLER]
	var base: float = c.reputation * 0.06 * Fans.merch_factor(c)
	return {"name": str(rng().pick(WorldGenerator.SPONSORS)), "monthly": int(base * (0.85 + 0.3 * rng().next())), "ends_season": w.season + rng().irange(1, 3)}


## The sponsor's contract ran out: the candidates wait in club.board.sponsor_offers until the manager picks one.
func _sponsor_offers(c: Club) -> void:
	var offers: Array = []
	var choices: Array[Inbox.Choice] = []
	var seen := {}
	for k in 3:
		var o := _sponsor_offer(c)
		if seen.has(o["name"]):
			continue
		seen[o["name"]] = true
		choices.append(Inbox.Choice.new(ACCEPT_SPONSOR, "ui.action.accept_sponsor",
			{"name": Say.sponsor(str(o["name"])), "monthly": Say.money(int(o["monthly"])), "until": Say.season(int(o["ends_season"]))}, Inbox.MAIN, offers.size()))
		offers.append(o)
	c.board["sponsor_offers"] = offers
	Inbox.ask(w, Inbox.Decision.new(Inbox.SPONSOR, c.id, choices).blocking(), &"from.board", "msg.sponsor_offers.subject", "msg.sponsor_offers.body", {"club": Say.club(c)})
	c.sponsor = {"name": "", "monthly": 0, "ends_season": w.season}


func _ai_sack(club: Club) -> void:  # [game]
	var old := club.manager_name
	var managers: Array = club.history.get("managers", [])
	managers.append({"name": old, "until": w.today})
	club.history["managers"] = managers.slice(maxi(0, managers.size() - 20))
	club.manager_name = _manager_name_for(club)
	club.board["confidence"] = 55.0
	club.board["missed_streak"] = 0
	club.board["last_streak"] = 0
	club.board["manager_since"] = w.today
	_append_news_item(NewsGenerator.item("news.manager_sacked", 3, {"club": Say.club(club), "old": Say.plain(old), "new": Say.plain(club.manager_name)}, {"clubs": [club.id]}))
	if w.is_school_mode() or w.player_club_id == club.id:
		return
	var rep: int = int(w.manager.get("reputation", 1000))
	var req := Career.club_requirement(club)
	var me := w.my_club()
	var step_up: bool = me == null or req > Career.club_requirement(me) * 1.1
	if req <= rep * OFFER_REACH and step_up and rng().chance(0.6) and not _shunned(club.id):
		_post_job_offer(club)


func _house_season_review(ended_season: int) -> void:  # [game]
	var me := w.my_club()
	var hd: Dictionary = w.houses.get(me.id, {})
	var cid := "comp_school_%s_%d" % [str(hd.get("school_id", "")).trim_prefix("school_"), ended_season]
	var pos := -1
	var champion := ""
	for h in w.history:
		if str(h.get("competition_id", "")) == cid:
			champion = str(h.get("champion_id", ""))
			var table: Array = h.get("table", [])
			for i in table.size():
				if str(table[i]["club_id"]) == me.id:
					pos = i + 1
			break
	if pos < 0:
		return
	var won := champion == me.id
	var conf: float = float(me.board.get("confidence", 60.0))
	var rep: int = int(w.manager.get("reputation", 1000))
	var verdict := "met" if won else ("missed" if pos >= 3 else "ok")
	match verdict:
		"met":
			conf = minf(100.0, conf + 20.0)
			rep += 150
		"ok":
			conf = clampf(conf + 2.0, 0.0, 100.0)
			rep += 30
		"missed":
			conf = maxf(15.0, conf - 15.0)
			rep -= 30
	me.board["confidence"] = conf
	Career.set_reputation(w, rep)
	Inbox.tell(w, &"from.head_of_house", "msg.house_season_end.subject", "msg.house_season_end.body." + verdict, {"position": Say.num(pos), "champion": Say.team(w, champion), "house": Say.club(me)})
	if won:
		_job_offers(2, false)


## Accept a job: the previous club goes to the AI; the new one goes to the human.
func accept_job(club_id: String) -> void:
	var old_club := w.my_club()
	if old_club != null:
		_close_spell(old_club.id, "left")
		_leave_club(old_club.id)
	if old_club != null and w.is_school_mode():
		var hd: Dictionary = w.houses.get(old_club.id, {})
		hd["human"] = false
		hd.erase("lineup")
		old_club.manager_is_human = false
	elif old_club != null:
		_hand_club_to_ai(old_club)
	var c: Club = w.club(club_id)
	if c == null:
		return
	c.manager_is_human = true
	c.manager_name = str(w.manager.get("name", "Mánager"))
	c.lineup = WorldGenerator.best_lineup(w, c.id)
	c.board["confidence"] = 60.0
	c.board["missed_streak"] = 0
	c.board["last_streak"] = 0
	c.board["manager_since"] = w.today
	c.board.erase("ultimatum")
	w.player_club_id = club_id
	w.manager_unemployed = false
	var career: Array = w.manager.get("career", [])
	career.append({"club_id": club_id, "from": w.season + (1 if w.today >= WDate.from_ymd(w.season + 1, 6, 1) else 0), "from_day": w.today})
	w.manager["career"] = career
	_mid_season_objective(c)
	Inbox.tell(w, &"from.board", "msg.welcome.subject", "msg.welcome.body", {"manager": Say.plain(str(w.manager.get("name", ""))), "club": Say.club(c), "objective": Say.key("objective." + str(c.board.get("objective", ""))), "balance": Say.money(c.balance)})
	for d in Inbox.open_of(w, Inbox.JOB):
		Inbox.close(w, d, Say.phrase("msg.job_offer.outcome_accepted") if d.key == club_id else Say.phrase("msg.job_offer.outcome_closed", {"club": Say.club(c)}))
	_release_foreign_pending_match()


## The manager watched the pending match to the final whistle and has not pressed Finish yet. Its result is recorded
## only at Finish, so a job change now would drop the match and let the AI replay the fixture.
func match_awaits_finish() -> bool:
	return pending_match != null and pending_match.sim.is_over()


## The engine's answers: jobs, national jobs and sponsors. Accepting a job asks the manager to confirm first.
func answer_owl(d: Inbox.Decision, c: Inbox.Choice, confirmed: bool) -> Inbox.Reply:
	if (c.verb == ACCEPT_JOB or c.verb == ACCEPT_NT_JOB) and match_awaits_finish():
		var wait := Inbox.Reply.stay()
		wait.changed = false
		wait.toast = Say.phrase("ui.match.finish_first")
		return wait
	match c.verb:
		ACCEPT_JOB:
			if not confirmed:
				var cur := w.my_club()
				return Inbox.Reply.ask_first(c.label, Say.phrase("ui.inbox.confirm_job", {"club": Say.team(w, d.key)}),
					Say.phrase("ui.inbox.confirm_job_leave", {"club": Say.club(cur)}) if cur != null and cur.id != d.key else null)
			accept_job(d.key)
			var r := Inbox.Reply.done()
			r.slot_switch = true
			return r
		REJECT_JOB:
			reject_job(d.key)
			return Inbox.Reply.done(Say.phrase("msg.job_offer.outcome_rejected"))
		ACCEPT_NT_JOB:
			accept_national_job(d.key)
			return Inbox.Reply.done()
		REJECT_NT_JOB:
			return Inbox.Reply.done()
		ACCEPT_SPONSOR:
			var me := w.my_club()
			var offers: Array = me.board.get("sponsor_offers", []) if me != null else []
			if c.arg < offers.size():
				me.sponsor = offers[c.arg].duplicate()
				me.board.erase("sponsor_offers")
			return Inbox.Reply.done()
	return Inbox.Reply.unhandled(d, c)


const OBJECTIVE_LADDER := ["title", "top_half", "mid_table", "avoid_last"]


func _mid_season_objective(c: Club) -> void:
	var lg := w.league_of(c.id)
	if lg == null or w.is_school_mode() or w.houses.has(c.id) or w.today >= WDate.from_ymd(w.season + 1, 6, 1):
		return
	var st := lg.standings()
	var pos := 0
	for i_row in st.size():
		if str(st[i_row]["club_id"]) == c.id and int(st[i_row]["pj"]) > 0:
			pos = i_row + 1
	if pos == 0 or pos <= Economy.objective_pos(w, c):
		return
	var chosen := "avoid_last"
	for o in OBJECTIVE_LADDER:
		c.board["objective"] = o
		if Economy.objective_pos(w, c) >= pos:
			chosen = o
			break
	c.board["objective"] = chosen
	c.board["objective_min_pos"] = Economy.objective_pos(w, c)


func _append_news_item(item: Dictionary) -> void:
	w.news_buffer.append(item)


func _publish_news() -> void:
	var buffer := w.news_buffer
	var items := _relevant_news(buffer)
	buffer.clear()
	items.append_array(Rivalries.preview_items(w))
	var my_league: String = w.my_club().league_id if w.my_club() != null else "comp_british_irish_league"
	if w.competitions.has(my_league) and NewsGenerator.matchdays_played(w.competitions[my_league]) > 0:
		items.append(NewsGenerator.table_item(w, w.competitions[my_league]))
	items.append(NewsGenerator.filler_item(w, rng()))
	items.sort_custom(func(a, b): return int(a["importance"]) > int(b["importance"]))
	var edition: int = (int(w.news[0].get("edition", 0)) + 1) if not w.news.is_empty() else 1
	w.news.push_front({"day": w.today, "edition": edition, "items": items})
	if w.news.size() > 60:
		w.news.pop_back()


const NEWS_FOREIGN_MAX := 4


func _relevant_news(buffer: Array) -> Array:
	var me := w.my_club()
	var my_league: String = me.league_id if me != null else "comp_british_irish_league"
	var my_country: String = me.country_id if me != null else str(w.manager.get("nationality", "eng"))
	var my_nt := str(w.manager.get("national_team_id", ""))
	var local: Array = []
	var foreign: Array = []
	var seen := {}
	for it in buffer:
		var sig := Say.Phrase.from_dict(it).signature()
		if seen.has(sig):
			continue
		seen[sig] = true
		var ids: Array = it.get("clubs", [])
		if ids.is_empty():
			local.append(it)
			continue
		var near := false
		for cid in ids:
			var c: Club = w.club(str(cid))
			if c != null and (c.league_id == my_league or c.manager_is_human):
				near = true
			elif w.national_teams.has(str(cid)) and (str(cid) == my_nt or str(w.national_teams[str(cid)].get("country_id", "")) == my_country):
				near = true
		var cid := str(it.get("comp_id", ""))
		if cid.begins_with("comp_world_cup_") and cid.ends_with("_final"):
			near = true
		if near:
			local.append(it)
		elif str(it.get("key", "")) == "news.transfer":
			foreign.append(it)
	foreign.sort_custom(func(a, b): return int(a.get("fee", 0)) > int(b.get("fee", 0)))
	return local + foreign.slice(0, NEWS_FOREIGN_MAX)


func _update_reputations(st: Array) -> void:  # [game]
	var ids: Array = []
	for row in st:
		ids.append(str(row["club_id"]))
	var by_rep := ids.duplicate()
	by_rep.sort_custom(func(a, b): return w.club(a).reputation > w.club(b).reputation if w.club(a).reputation != w.club(b).reputation else a < b)
	var n := ids.size()
	for i in n:
		var c: Club = w.club(ids[i])
		if not c.history.has("base_reputation"):
			c.history["base_reputation"] = c.reputation
		var expected := by_rep.find(c.id)
		var rep := float(c.reputation)
		var delta := rep * 0.012 * float(expected - i)
		if i == 0:
			delta += rep * 0.04
		elif i == n - 1:
			delta -= rep * 0.02
		delta += (float(c.history["base_reputation"]) - rep) * 0.08
		c.reputation = clampi(int(rep + delta), 800, 9800)


func _cup_reputation(club: Club, pct: float) -> void:
	if club == null:
		return
	if not club.history.has("base_reputation"):
		club.history["base_reputation"] = club.reputation
	club.reputation = clampi(int(club.reputation * (1.0 + pct)), 800, 9800)


func _book_events() -> void:
	if not bool(w.settings.get("book_events", true)):
		return
	for e in loader.events:
		if WDate.from_string(str(e.get("date", "1900-01-01"))) != w.today:
			continue
		match str(e.get("kind", "")):
			"fixture_result":
				_scripted_fixture(e)
			"wc_final":
				_scripted_wc_final(e)
			"broom":
				var p: Player = w.player(str(e.get("player_id", "")))
				if p != null:
					p.broom = {"model_id": str(e["model_id"]), "condition": 100.0}
					_book_news(e, [p])
			"position":
				var p: Player = w.player(str(e.get("player_id", "")))
				if p != null:
					p.position = str(e.get("position", p.position))  # [HBP 11]
					p.positions[p.position] = maxf(float(p.positions.get(p.position, 0)), 18.0)
					if p.squad == Player.Squad.SCHOOL and w.player_club_id == Schools.house_id(p.school_id, p.house) and w.my_club() != null:
						w.my_club().lineup = Schools.best_lineup(w, w.player_club_id)
			"captain":
				var p: Player = w.player(str(e.get("player_id", "")))
				if p != null:
					for q in Schools.students_of(w, p.school_id, p.house):
						q.is_captain = (q.id == p.id)
					_book_news(e, [p])
			"ban":
				var until := WDate.from_string(str(e.get("until", "1900-01-01")))
				var banned: Array = []
				var banned_houses := {}
				for pid in e.get("player_ids", []):
					var p: Player = w.player(str(pid))
					if p != null:
						p.ban_until = until
						banned.append(p)
						if p.squad == Player.Squad.SCHOOL:
							banned_houses["%s|%s" % [p.school_id, p.house]] = true
				_book_news(e, banned)
				_house_tryouts(banned_houses)  # [OotP]
			"retire":
				var gone: Array = []
				for pid in e.get("player_ids", []):
					if w.players.has(str(pid)):
						gone.append(w.players[str(pid)])
				_book_news(e, gone)
				var houses := {}
				for p in gone:
					if p.squad == Player.Squad.SCHOOL:
						houses["%s|%s" % [p.school_id, p.house]] = true
					w.remove_player(p.id)
				_house_tryouts(houses)


func _house_tryouts(houses: Dictionary) -> void:
	for k in houses.keys():
		var parts: PackedStringArray = str(k).split("|")
		Schools.fill_house(w, loader, rng(), parts[0], parts[1])
		Schools._ensure_house_captain(w, parts[0], parts[1])
		var hid := Schools.house_id(parts[0], parts[1])
		if w.player_club_id == hid and w.my_club() != null:
			w.my_club().lineup = Schools.best_lineup(w, hid)


func _book_news(e: Dictionary, players: Array) -> void:
	var key := str(e.get("news_key", ""))
	if key == "" or players.is_empty():
		return
	var p0: Player = players[0]
	var args: Dictionary[String, Say.Arg] = {"player": Say.list(players.map(func(p): return Say.player(p))), "house": Say.key("house." + p0.house) if p0.house != "" else Say.team(w, p0.club_id)}
	_append_news_item(NewsGenerator.item(key, 4, args))
	var mine := false
	for p in players:
		if p.squad == Player.Squad.SCHOOL and w.player_club_id == Schools.house_id(p.school_id, p.house):
			mine = true
	if mine:
		Inbox.tell(w, &"from.head_of_house", "msg.book_event.subject", key, args)


func _scripted_fixture(e: Dictionary) -> void:
	var prefix := str(e.get("competition_prefix", ""))
	var comp: Competition = null
	for cid in w.competitions.keys():
		if str(cid).begins_with(prefix):
			comp = w.competitions[cid]
			break
	if comp == null:
		return
	var home := str(e["home"])
	var away := str(e["away"])
	for f in comp.fixtures:
		if bool(f.get("played", false)):
			continue
		var same := str(f["home_id"]) == home and str(f["away_id"]) == away
		var swapped := str(f["home_id"]) == away and str(f["away_id"]) == home
		if not (same or swapped):
			continue
		if _is_human(str(f["home_id"])) or _is_human(str(f["away_id"])):
			return
		f["day"] = w.today
		var sh := int(e.get("score_home", 0))
		var sa := int(e.get("score_away", 0))
		if swapped:
			var tmp := sh
			sh = sa
			sa = tmp
		_apply_scripted(comp, f, sh, sa, str(e.get("snitch_team", "")), str(e.get("catcher", "")), str(e.get("catcher_last_name", "")), int(e.get("duration_min", 30)))
		return


func _scripted_wc_final(e: Dictionary) -> void:
	var comp: Competition = w.competitions.get(str(e.get("competition_id", "")))
	if comp == null:
		return
	for f in comp.fixtures:
		if str(f.get("stage", "")) != "final" or bool(f.get("played", false)):
			continue
		if _is_human(str(f["home_id"])) or _is_human(str(f["away_id"])) or _is_human(str(e["home"])) or _is_human(str(e["away"])):  # [game]
			return
		f["home_id"] = str(e["home"])
		f["away_id"] = str(e["away"])
		f["day"] = w.today
		_apply_scripted(comp, f, int(e.get("score_home", 0)), int(e.get("score_away", 0)), str(e.get("snitch_team", "")), str(e.get("catcher", "")), str(e.get("catcher_last_name", "")), int(e.get("duration_min", 30)))
		return


func _apply_scripted(comp: Competition, f: Dictionary, sh: int, sa: int, snitch_team: String, catcher: String, catcher_last: String, minutes: int) -> void:
	var home := team_for(str(f["home_id"]))
	var away := team_for(str(f["away_id"]))
	var cp: Player = w.player(catcher)
	if cp == null and catcher_last != "" and w.national_teams.has(snitch_team):
		var ctry := str(w.national_teams[snitch_team].get("country_id", ""))
		for q in w.players_sorted():
			if q.squad != Player.Squad.SCHOOL and q.nationality == ctry and q.last_name == catcher_last and (cp == null or (q.position == "S" and cp.position != "S")):
				cp = q
	if cp != null:
		var t: SimTeam = home if home.id == snitch_team else away
		var present := false
		for sp in t.players:
			if sp.id == cp.id:
				present = true
		if not present:
			var csp := cp.to_sim_player(loader.brooms)
			csp.position = cp.position
			var replaced := false
			for i in t.players.size():
				if t.players[i].position == cp.position:
					t.players[i] = csp
					replaced = true
					break
			if not replaced:
				t.players.append(csp)
	var r := MatchResult.new()
	r.home_id = home.id
	r.away_id = away.id
	r.score_home = sh
	r.score_away = sa
	r.snitch_team_id = snitch_team
	r.duration_s = minutes * 60
	r.end_reason = MatchResult.EndReason.SNITCH if snitch_team != "" else MatchResult.EndReason.TIME_CAP
	for pair in [[home, sh], [away, sa]]:
		var t: SimTeam = pair[0]
		var goals: int = int(pair[1]) / 10
		if t.id == snitch_team:
			goals -= 15
		var chasers: Array = []
		for sp in t.players:
			sp.stats = {"goals": 0, "saves": 0, "snitch_catch": 0, "fouls": 0}
			if sp.position == "C":
				chasers.append(sp)
		for i in maxi(goals, 0):
			if not chasers.is_empty():
				chasers[i % chasers.size()].stats["goals"] += 1
		if t.id == snitch_team:
			var sp_catcher: SimPlayer = null
			for sp in t.players:
				if sp.id == catcher or (cp != null and sp.id == cp.id) or (catcher_last != "" and str(sp.name).ends_with(catcher_last)):
					sp_catcher = sp
			if sp_catcher == null:
				for sp in t.players:
					if sp.position == "S":
						sp_catcher = sp
			if sp_catcher != null:
				sp_catcher.stats["snitch_catch"] = 1
				r.snitch_player_id = sp_catcher.id
	home.score = sh
	away.score = sa
	apply_result(comp, f, r, home, away)
	f["scripted"] = true


func _scout_recommendations() -> void:
	var me := w.my_club()
	if me == null or w.is_school_mode():
		return
	var weak := _weakest_position(me)
	var budget := me.transfer_budget
	var cands: Array = []
	for p in w.players_sorted():
		if p.club_id == me.id or p.squad == Player.Squad.SCHOOL or p.squad == Player.Squad.ABROAD or p.is_on_loan() or p.position != weak:
			continue
		if me.is_women_only() and p.gender != SimPlayer.Gender.F:
			continue
		var cost := 0 if p.club_id == "" else Economy.asking_price(w, p)
		var region := loader.region_of_country(p.nationality)
		if p.club_id != "" and w.clubs.has(p.club_id):
			region = w.clubs[p.club_id].region_id
		if cost <= budget and float(me.knowledge.get(region, 0.0)) >= 40.0:
			cands.append(p)
	cands.sort_custom(func(a, b): return a.ca() > b.ca())
	var picks: Array = cands.slice(0, 3)
	if picks.is_empty():
		return
	var args: Dictionary[String, Say.Arg] = {"pos": Say.key("pos." + weak)}
	for i in picks.size():
		var p: Player = picks[i]
		var k := str(i + 1)
		args["n" + k] = Say.player(p)
		args["c" + k] = Say.team(w, p.club_id) if p.club_id != "" else Say.key("ui.free_agent")
		args["a" + k] = Say.num(p.age(w.today))
		args["g" + k] = Say.money(0 if p.club_id == "" else Economy.asking_price(w, p))
	Inbox.tell(w, &"from.scout", "msg.scout_recs.subject", "msg.scout_recs.body.%d" % picks.size(), args, Inbox.QUIET)
	for pid in w.shortlist:
		var p: Player = w.player(str(pid))
		if p == null:
			continue
		if p.transfer_listed or p.loan_listed:
			Inbox.tell(w, &"from.scout", "msg.shortlist.subject", "msg.shortlist.listed", {"player": Say.player(p), "club": Say.team(w, p.club_id)})
		elif int(p.contract.get("end_day", 0)) > 0 and int(p.contract.get("end_day", 0)) - w.today < 120:
			Inbox.tell(w, &"from.scout", "msg.shortlist.subject", "msg.shortlist.expiring", {"player": Say.player(p), "club": Say.team(w, p.club_id)})


func _weakest_position(club: Club) -> String:
	var need := {"K": 2, "C": 5, "B": 3, "S": 2}
	var by_pos := {"K": [], "C": [], "B": [], "S": []}
	for p in w.squad_of(club.id):
		if by_pos.has(p.position):
			by_pos[p.position].append(p.ca())
	var weak := "C"
	var worst := INF
	for pos in ["K", "C", "B", "S"]:
		var total := 0.0
		for v in by_pos[pos].slice(0, int(need[pos])):
			total += float(v)
		var mean := total / float(need[pos])
		if mean < worst:
			worst = mean
			weak = pos
	return weak


func _rumours(log: Array) -> void:
	var my_league: String = w.my_club().league_id if w.my_club() != null else ""
	var listed: Array = []
	for cid in (w.competitions[my_league].club_ids if w.competitions.has(my_league) else []):
		for p in w.club_players(str(cid)):
			if p.transfer_listed and p.ca() >= 95.0:
				listed.append(Say.phrase("ui.list.name_detail", {"name": Say.player(p), "detail": Say.team(w, p.club_id)}).as_arg())
	if not listed.is_empty():
		_append_news_item(NewsGenerator.item("news.rumours", 2, {"names": Say.list(listed.slice(0, 4))}))


func _board_request() -> void:
	var me := w.my_club()
	if me == null:
		return
	var r := rng()
	var kind: String = str(r.pick(["facility", "sell_surplus", "wages"]))
	match kind:
		"facility":
			var worst := "training"
			for k in ["training", "medical", "broom_workshop"]:
				if int(me.facilities.get(k, 1)) < int(me.facilities.get(worst, 1)):
					worst = k
			if int(me.facilities.get(worst, 1)) >= 5 or me.balance < 1500 * int(me.facilities.get(worst, 1)) * 1.5:
				return
			me.board["request"] = {"kind": "facility", "key": worst, "until": w.today + 90, "level": int(me.facilities.get(worst, 1)) + 1}
			Inbox.tell(w, &"from.board", "msg.board_request.subject", "msg.board_request.facility", {"facility": Say.key("facility." + worst)})
		"sell_surplus":
			var counts := {"K": 0, "C": 0, "B": 0, "S": 0}
			for p in w.squad_of(me.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
				counts[p.position] += 1
			var need := {"K": 2, "C": 5, "B": 3, "S": 2}
			for pos in ["C", "B", "K", "S"]:
				if counts[pos] > need[pos] + 1:
					me.board["request"] = {"kind": "sell_surplus", "key": pos, "until": w.today + 90, "count": counts[pos] - 1}
					Inbox.tell(w, &"from.board", "msg.board_request.subject", "msg.board_request.sell", {"pos": Say.key("pos." + pos)})
					return
		"wages":
			var wages := 0
			for p in w.squad_of(me.id):
				wages += int(p.contract.get("wage_weekly", 0))
			if wages > me.wage_budget_weekly:
				me.board["request"] = {"kind": "wages", "until": w.today + 90, "limit": me.wage_budget_weekly}
				Inbox.tell(w, &"from.board", "msg.board_request.subject", "msg.board_request.wages", {"wages": Say.money(wages), "budget": Say.money(me.wage_budget_weekly)})


func _board_request_check() -> void:
	var me := w.my_club()
	if me == null or not me.board.has("request"):
		return
	var rq: Dictionary = me.board["request"]
	var done := false
	match str(rq["kind"]):
		"facility":
			done = int(me.facilities.get(str(rq["key"]), 1)) >= int(rq["level"])
		"sell_surplus":
			var n := 0
			for p in w.squad_of(me.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
				if p.position == str(rq["key"]):
					n += 1
			done = n <= int(rq["count"])
		"wages":
			var wages := 0
			for p in w.squad_of(me.id):
				wages += int(p.contract.get("wage_weekly", 0))
			done = wages <= int(rq["limit"])
	if done:
		me.board["confidence"] = clampf(float(me.board.get("confidence", 60.0)) + 6.0, 0.0, 100.0)
		Inbox.tell(w, &"from.board", "msg.board_request_done.subject", "msg.board_request_done.body")
		me.board.erase("request")
	elif w.today >= int(rq["until"]):
		me.board["confidence"] = clampf(float(me.board.get("confidence", 60.0)) - 6.0, 0.0, 100.0)
		Inbox.tell(w, &"from.board", "msg.board_request_failed.subject", "msg.board_request_failed.body")
		me.board.erase("request")


func _assistant_weekly() -> void:
	var me := w.my_club()
	if me == null:
		return
	var groups := {"expiring": [], "unhappy": [], "injured": [], "hot": [], "cold": []}
	for p in w.squad_of(me.id):
		var end_day := int(p.contract.get("end_day", 0))
		if end_day > 0 and end_day - w.today <= 120 and end_day - w.today > 0 and not p.is_on_loan():
			groups["expiring"].append(Say.player(p))
		if p.morale < 35.0:
			groups["unhappy"].append(Say.player(p))
		if p.injury_days >= 14:
			groups["injured"].append(Say.phrase("ui.list.name_detail", {"name": Say.player(p), "detail": Say.num(p.injury_days)}).as_arg())
		if p.form.size() >= 3:
			var avg := 0.0
			for v in p.form.slice(p.form.size() - 3):
				avg += float(v)
			avg /= 3.0
			if avg >= 7.5:
				groups["hot"].append(Say.player(p))
			elif avg <= 5.0:
				groups["cold"].append(Say.player(p))
	var args: Dictionary[String, Say.Arg] = {}
	var n := 0
	for kind in ["expiring", "unhappy", "injured", "hot", "cold"]:
		if groups[kind].is_empty():
			continue
		n += 1
		args["lab%d" % n] = Say.key("msg.assistant.lab." + kind)
		args["names%d" % n] = Say.list(groups[kind])
	if n == 0:
		return
	var text := Say.phrase("msg.assistant.body.%d" % n, args).signature()
	if str(w.settings.get("last_assistant_report", "")) == text:
		return
	w.settings["last_assistant_report"] = text
	Inbox.tell(w, &"from.assistant", "msg.assistant.subject", "msg.assistant.body.%d" % n, args, Inbox.QUIET)


## [month, day] of the World Cup final-stage rounds and of the two pre-season friendlies, which fall between them
## so the club's internationals can play both (tests/run_tests.gd checks they stay disjoint).
const WC_FINAL_STAGE_DATES := [[7, 9], [7, 23], [8, 6], [8, 22]]
const PRESEASON_FRIENDLY_DATES := [[8, 12], [8, 27]]


func _create_friendlies(year: int) -> void:
	var me := w.my_club()
	var cid := "comp_friendlies_%s_%d" % [me.id, year]
	if w.competitions.has(cid):
		return
	var lg := w.league_of(me.id)
	if lg == null:
		return
	var rivals: Array = []
	for c in lg.club_ids:
		if c != me.id:
			rivals.append(c)
	if rivals.size() < 2:
		return
	var comp := Competition.new()
	comp.id = cid
	comp.name = "Amistosos de pretemporada"
	comp.name_en = "Pre-season friendlies"
	comp.type = Competition.Type.FRIENDLY
	comp.region_id = lg.region_id
	comp.level = 9
	comp.season = year
	comp.format = {"table": "points_scored", "time_cap_minutes": 120}
	comp.club_ids = [me.id]
	comp.venues = lg.venues
	comp.source = "filler"
	var r1: String = str(rng().pick(rivals))
	rivals.erase(r1)
	var r2: String = str(rng().pick(rivals))
	var days: Array = PRESEASON_FRIENDLY_DATES.map(func(md): return WDate.from_ymd(year, md[0], md[1]))
	comp.fixtures = [
		{"id": "%s_1" % cid, "round": 1, "day": days[0], "home_id": me.id, "away_id": r1, "venue": "ground:" + me.id, "hour": "16:00", "played": false, "friendly": true},
		{"id": "%s_2" % cid, "round": 2, "day": days[1], "home_id": r2, "away_id": me.id, "venue": "ground:" + r2, "hour": "16:00", "played": false, "friendly": true},
	]
	w.competitions[cid] = comp
	Inbox.tell(w, &"from.assistant", "msg.friendlies.subject", "msg.friendlies.body", {"a": Say.team(w, r1), "b": Say.team(w, r2)})


func _create_nt_friendlies(year: int) -> void:  # [game]
	var ntid := str(w.manager.get("national_team_id", ""))
	if ntid == "" or not w.national_teams.has(ntid):
		return
	var cid := "comp_nt_friendlies_%s_%d" % [ntid, year]
	if w.competitions.has(cid):
		return
	var dates := WorldGenerator.national_dates(year)
	for c in w.competitions.values():
		if c.type == Competition.Type.WC_GROUPS and c.club_ids.has(ntid):
			for f in c.fixtures:
				if int(f["day"]) >= dates[0] and int(f["day"]) <= dates[-1] and (str(f["home_id"]) == ntid or str(f["away_id"]) == ntid):
					return
	var mine := NationalTeams.strength(w, ntid)
	var others: Array = []
	for k in w.national_team_ids_sorted():
		if k != ntid:
			others.append([absf(NationalTeams.strength(w, k) - mine), k])
	others.sort_custom(func(a, b): return a[0] < b[0])
	var pool: Array = others.slice(0, 10).map(func(x): return x[1])
	var comp := Competition.new()
	comp.id = cid
	comp.name = "Amistosos internacionales %d-%02d" % [year, (year + 1) % 100]
	comp.name_en = "International friendlies %d-%02d" % [year, (year + 1) % 100]
	comp.type = Competition.Type.FRIENDLY
	comp.region_id = "world"
	comp.level = 9
	comp.season = year
	comp.format = {"table": "points_scored", "time_cap_minutes": 180}
	comp.club_ids = [ntid]
	comp.venues = ["venue.neutral_moor"]
	comp.source = "filler"
	var rivals: Array = []
	for i in dates.size():
		var rv: String = str(rng().pick(pool))
		pool.erase(rv)
		rivals.append(Say.team(w, rv))
		comp.fixtures.append({"id": "%s_%d" % [cid, i + 1], "round": i + 1, "day": int(dates[i]), "home_id": ntid if i % 2 == 0 else rv, "away_id": rv if i % 2 == 0 else ntid, "venue": "venue.neutral_moor", "hour": "17:00", "played": false, "friendly": true})
	w.competitions[cid] = comp
	Inbox.tell(w, &"from.federation", "msg.nt_friendlies.subject", "msg.nt_friendlies.body", {"team": Say.team(w, ntid), "rivals": Say.list(rivals)})


## Days an offer with a deadline stays open (owl field `expires_day`): the national-team job here, incoming
## transfer bids in MarketActions.
const OFFER_DAYS := 14


func _national_job_offer() -> void:
	var own := "nt_" + str(w.manager.get("nationality", "eng"))
	var candidates: Array = []
	if w.national_teams.has(own) and Career.nt_eligible(w, own):
		candidates.append(own)
	else:
		for ntid in w.national_team_ids_sorted():
			var nt: Dictionary = w.national_teams[ntid]
			if not bool(nt.get("human", false)) and Career.nt_eligible(w, ntid) and rng().chance(0.3):
				candidates.append(ntid)
	if candidates.is_empty():
		return
	var ntid: String = str(rng().pick(candidates))
	Inbox.ask(w, Inbox.Decision.new(Inbox.NT_JOB, ntid, [Inbox.Choice.new(ACCEPT_NT_JOB, "ui.action.accept_nt"), Inbox.Choice.new(REJECT_NT_JOB, "ui.action.reject", {}, Inbox.BACK)]).until(w.today + OFFER_DAYS).blocking(),
		&"from.federation", "msg.nt_offer.subject", "msg.nt_offer.body", {"team": Say.team(w, ntid)})


func accept_national_job(ntid: String) -> void:
	var current := str(w.manager.get("national_team_id", ""))
	if not w.national_teams.has(ntid) or ntid == current:
		return
	if current != "" and w.national_teams.has(current):
		var old_nt: Dictionary = w.national_teams[current]
		old_nt["human"] = false
		old_nt.erase("lineup")
		_close_spell(current, "left")
	var nt: Dictionary = w.national_teams[ntid]
	nt["human"] = true
	nt["lineup"] = NationalTeams.pick_squad(w, nt)
	if not nt.has("tactics"):
		nt["tactics"] = SimTactics.defaults()
	w.manager["national_team_id"] = ntid
	w.manager["nt_hired_day"] = w.today
	w.manager["career"] = w.manager.get("career", []) + [{"season": w.season, "club_id": ntid, "role": "national"}]
	Inbox.tell(w, &"from.federation", "msg.nt_welcome.subject", "msg.nt_welcome.body", {"team": Say.team(w, ntid)})
	for d in Inbox.open_of(w, Inbox.NT_JOB):
		Inbox.close(w, d)
	_release_foreign_pending_match()


func _national_review(year: int) -> void:
	var ntid := str(w.manager["national_team_id"])
	var nt: Dictionary = w.national_teams.get(ntid, {})
	var final_comp: Competition = w.competitions.get("comp_world_cup_%d_final" % year)
	var reached_final_stage := final_comp != null and final_comp.has_team(ntid)
	var champion := final_comp != null and final_comp.champion_id == ntid
	var hired := int(w.manager.get("nt_hired_day", -1))
	var team_end := WDate.from_ymd(year, 6, 20)
	if final_comp != null:
		for f in final_comp.fixtures:
			if str(f["home_id"]) == ntid or str(f["away_id"]) == ntid:
				team_end = maxi(team_end, int(f["day"]))
	if hired > team_end:
		return
	if champion:
		Career.add_reputation(w, 400)
		Inbox.tell(w, &"from.federation", "msg.nt_champion.subject", "msg.nt_champion.body", {"team": Say.team(w, ntid), "year": Say.num(year)})
	elif reached_final_stage:
		Career.add_reputation(w, 120)
		Inbox.tell(w, &"from.federation", "msg.nt_kept.subject", "msg.nt_kept.body", {"team": Say.team(w, ntid), "year": Say.num(year)})
	else:
		_close_spell(ntid, "sacked")
		nt["human"] = false
		w.manager["national_team_id"] = ""
		w.manager.erase("nt_hired_day")
		Inbox.tell(w, &"from.federation", "msg.nt_sacked.subject", "msg.nt_sacked.body", {"team": Say.team(w, ntid), "year": Say.num(year)})


func _book_event_players() -> Dictionary:
	var out := {}
	if not bool(w.settings.get("book_events", true)):
		return out
	var by_last := {}
	for e in loader.events:
		if WDate.from_string(str(e.get("date", "1900-01-01"))) <= w.today:
			continue
		if str(e.get("catcher", "")) != "":
			out[str(e["catcher"])] = true
		for pid in e.get("player_ids", []):
			out[str(pid)] = true
		if str(e.get("player_id", "")) != "":
			out[str(e["player_id"])] = true
		var team := str(e.get("snitch_team", ""))
		if str(e.get("catcher_last_name", "")) != "" and w.national_teams.has(team):
			by_last["%s|%s" % [str(w.national_teams[team].get("country_id", "")), str(e["catcher_last_name"])]] = true
	if not by_last.is_empty():
		for p in w.players.values():
			if p.squad != Player.Squad.SCHOOL and by_last.has("%s|%s" % [p.nationality, p.last_name]):
				out[p.id] = true
	return out


func _school_cup_skips(season: int) -> Dictionary:  # [GoF 12]
	var out := {}
	if not bool(w.settings.get("book_events", true)):
		return out
	for e in loader.events:
		if str(e.get("kind", "")) == "no_school_cup" and int(e.get("season", -1)) == season:
			out[str(e.get("school_id", ""))] = true
	return out


func _contracts_review() -> void:
	var me := w.my_club()
	if me == null or w.is_school_mode() or WDate.month(w.today) != 1:
		return
	var expiring := _expiring_contracts(me)
	if expiring.is_empty():
		return
	if auto_fix_lineup:
		var renewed: Array = []
		var leaving: Array = []
		var bill := 0
		for q in w.squad_of(me.id):
			bill += int(q.contract.get("wage_weekly", 10))
		var staying := {"K": 0, "C": 0, "B": 0, "S": 0}
		for q in w.squad_of(me.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
			if not expiring.has(q) and staying.has(q.position):
				staying[q.position] += 1
		for p in expiring:
			var ok := false
			var t := Contracts.default_terms(w, p, me, "renew")
			var rise := int(t["wage_weekly"]) - (int(p.contract.get("wage_weekly", 10)) if p.club_id == me.id else 0)
			if bill + rise <= me.wage_budget_weekly or rise <= 0 or int(staying.get(p.position, 0)) < int(MIN_PER_POSITION.get(p.position, 0)):
				ok = bool(Contracts.sign(w, p, me, t, "renew")["ok"])
				if ok:
					bill += rise
			if ok:
				renewed.append(_with_wage(p))
				if p.squad != Player.Squad.YOUTH and staying.has(p.position):
					staying[p.position] += 1
			else:
				leaving.append(Say.player(p))
		Inbox.tell(w, &"from.assistant", "msg.contracts_auto.subject", "msg.contracts_auto.body_budget",
			{"renewed": Say.list(renewed) if not renewed.is_empty() else Say.plain("—"),
			 "leaving": Say.list(leaving) if not leaving.is_empty() else Say.plain("—"),
			 "bill": Say.money(bill), "budget": Say.money(me.wage_budget_weekly)})
		return
	_ask_contract_review(me, expiring, "jan")


## "Name (wage)" for a list of contracts.
static func _with_wage(p: Player) -> Say.Arg:
	return Say.phrase("ui.list.name_detail", {"name": Say.player(p), "detail": Say.money(int(p.contract.get("wage_weekly", 0)))}).as_arg()


## The contract review of `phase` ("jan" or "mar"): the players still to decide on live in
## club.board.contract_review, and the owl blocks the day until the manager reviews the squad or lets them go.
## Asking again while it is open restates the same owl (a shrinking list keeps its id and read flag).
func _ask_contract_review(me: Club, players: Array, phase: String) -> void:
	var ids: Array = players.map(func(p): return p.id)
	me.board["contract_review"] = {"season": w.season, "phase": phase, "player_ids": ids}
	var base := "msg.contracts_due" if phase == "jan" else "msg.contracts_spring"
	Inbox.ask(w, Inbox.Decision.new(Inbox.CONTRACTS, phase, [Inbox.Choice.go("ui.action.review_contracts", &"squad", {}, true),
			Inbox.Choice.new(Contracts.LET_GO, "ui.action.let_them_go", {}, Inbox.BACK)]).blocking(),
		&"from.assistant", base + ".subject", base + (".body.one" if ids.size() == 1 else ".body"), {"players": Say.list(players.map(_with_wage))})


func _expiring_contracts(me: Club) -> Array:
	var season_end := WDate.from_ymd(w.season + 1, 6, 30)
	var out: Array = []
	var pool: Array[Player] = w.squad_of(me.id)
	pool.append_array(_loaned_out(me))
	for p in pool:
		if (p.is_on_loan() and p.loan.owner_id != me.id) or p.pre_contract != null or int(p.contract.get("end_day", 0)) > season_end:
			continue
		var squad: String = p.loan.owner_squad if p.is_on_loan() else p.squad
		if squad == Player.Squad.YOUTH and p.age(season_end + 1) < 19:
			continue
		out.append(p)
	out.sort_custom(func(a, b): return a.ca() > b.ca() if a.ca() != b.ca() else a.id < b.id)
	return out


func _loaned_out(me: Club) -> Array[Player]:
	var out: Array[Player] = []
	for p in w.players.values():
		if p.is_on_loan() and p.loan.owner_id == me.id:
			out.append(p)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


func _contracts_spring_owl() -> void:  # [game]
	var me := w.my_club()
	if me == null or w.is_school_mode() or WDate.month(w.today) != 3:
		return
	var expiring := _expiring_contracts(me)
	if expiring.is_empty():
		return
	Inbox.close(w, Inbox.find(w, Inbox.CONTRACTS, "jan"))
	_ask_contract_review(me, expiring, "mar")


## Settles the questions that close when the world changes: the contract review once nobody on it is left to renew
## (or its season is over), else its list shrinks to the players still to decide on, so "Let them go" only concerns
## those; and the blocked-lineup owl once the lineup is valid. Run by the day tail and by Main before Continue.
func settle_owls() -> void:
	var me := w.my_club()
	var open := Inbox.open_of(w, Inbox.CONTRACTS)
	if not open.is_empty():
		var review: Dictionary = me.board.get("contract_review", {}) if me != null else {}
		var listed: Array = review.get("player_ids", [])
		var expiring: Array = [] if me == null or w.is_school_mode() else _expiring_contracts(me)
		var still: Array = expiring.filter(func(p): return listed.has(p.id))
		for d in open:
			if still.is_empty() or int(review.get("season", -1)) != w.season:
				Inbox.close(w, d, Say.phrase("msg.contracts.outcome_settled"))
				if me != null:
					me.board.erase("contract_review")
			elif still.size() < listed.size():
				_ask_contract_review(me, still, d.key)
	for d in Inbox.open_of(w, Inbox.LINEUP):
		if me == null or not lineup_blocked():
			Inbox.close(w, d, Say.phrase("ui.inbox.outcome.lineup_ready"))


func _ai_wants_renewal(club: Club, p: Player) -> bool:
	var age := p.age(w.today)
	if age <= 21 and p.pa >= float(WorldGenerator.YOUTH_MEAN_PA[clampi(club.level, 1, 3)]):
		return true
	var squad := w.squad_of(club.id, [Player.Squad.FIRST, Player.Squad.RESERVE])
	var rank := squad.size()
	for i in squad.size():
		if squad[i].id == p.id:
			rank = i
			break
	if age >= 34:
		return rng().chance(0.25)
	if rank < 3:
		return rng().chance(0.95)
	if rank < 14:
		return rng().chance(0.85)
	return p.ca() >= 85.0 and rng().chance(0.4)


func _brooms_on_sale() -> Array:
	var on_sale: Array = loader.brooms.values().filter(func(b): return int(b.get("available_from", b.get("year", 1900))) <= w.season and bool(b.get("professional", true)))
	on_sale.sort_custom(func(a, b): return float(a.get("speed", 0)) > float(b.get("speed", 0)) if float(a.get("speed", 0)) != float(b.get("speed", 0)) else str(a["id"]) < str(b["id"]))
	return on_sale


func _ai_broom_upgrade(club: Club, on_sale: Array) -> void:  # [game]
	if club.manager_is_human or club.balance <= 0:
		return
	var budget := int(club.balance * 0.04)
	for p in w.squad_of(club.id, [Player.Squad.FIRST]):
		if not rng().chance(0.3):
			continue
		var cur := float(loader.brooms.get(str(p.broom.get("model_id", "")), {}).get("speed", 0))
		for b in on_sale:
			if float(b.get("speed", 0)) <= cur:
				break
			var price := int(b.get("price", 500))
			if price <= budget:
				p.broom = {"model_id": str(b["id"]), "condition": 100.0}
				Economy.book(w, club, "brooms", -price)
				budget -= price
				break


func _intake_choices(have: Dictionary) -> Array:
	var share := {"K": 2, "C": 5, "B": 3, "S": 2}
	var total := 0
	for pos in have.keys():
		total += int(have[pos])
	var out: Array = []
	for pos in ["K", "C", "B", "S"]:
		var want := int(ceil(float(share[pos]) * float(total + 1) / 12.0))
		for i in maxi(want - int(have.get(pos, 0)), 0):
			out.append(pos)
	return out if not out.is_empty() else ["C", "C", "C", "B", "B", "K", "S"]  # [FILLER]


func _new_season_boards(ended_season: int) -> void:  # [game]
	for comp in w.leagues():
		var ids: Array = comp.club_ids.filter(func(cid): return w.clubs.has(str(cid)))
		ids.sort_custom(func(a, b): return w.club(a).reputation > w.club(b).reputation if w.club(a).reputation != w.club(b).reputation else str(a) < str(b))
		var n := ids.size()
		for i in n:
			var c: Club = w.club(str(ids[i]))
			var last_pos := int(c.season_summary.get(str(ended_season), {}).get("pos", 0))
			var obj := Economy.objective_for_rank(i + 1, n, last_pos)
			c.board["objective"] = obj
			c.board["objective_min_pos"] = Economy.objective_pos(w, c)
			c.board.erase("negotiated")
			c.wage_budget_weekly = Economy.wage_budget_for(c, last_pos, n)


func _season_rollover() -> void:
	var ended_season := w.season
	_rollover = Rollover.new()
	var review := {"season": ended_season, "club_id": w.player_club_id, "awards": [[], []], "departures": [[], []], "arrivals": [[], []]}
	var my_league_id: String = w.my_club().league_id if w.my_club() != null else ""
	var stagger := 0
	for comp in w.leagues():
		var st: Array = comp.standings()
		if st.is_empty():
			continue
		var champion: String = str(st[0]["club_id"])
		var table := []
		for row in st:
			table.append({"club_id": row["club_id"], "pts": row["pts"], "w": row["w"], "d": row["d"], "l": row["l"]})
		w.history.push_front({"season": ended_season, "competition_id": comp.id, "champion_id": champion, "table": table})
		var front: bool = comp.id == my_league_id or comp.level <= 1
		_append_news_item(NewsGenerator.league_champion_item(w, comp, st, ended_season, front, 6 if comp.id == my_league_id else (5 if front else 3)))
		for i in st.size():
			var club: Club = w.club(st[i]["club_id"])
			club.season_summary[str(ended_season)] = {"pos": i + 1, "pts": st[i]["pts"], "w": st[i]["w"], "d": st[i]["d"], "l": st[i]["l"]}
			var late_arrival: bool = club.manager_is_human and int(_open_spell(club.id).get("from", ended_season)) > ended_season
			if not late_arrival:
				var verdict := Economy.season_verdict(w, club, i + 1)
				if club.manager_is_human:
					Inbox.tell(w, &"from.board", "msg.season_end.subject", "msg.season_end.body." + verdict, {"position": Say.num(i + 1), "pts": Say.num(st[i]["pts"]), "champion": Say.club(w.club(champion)), "objective": Say.key("objective." + str(club.board.get("objective", "")))})
					review["pos"] = i + 1
					review["league"] = comp.id
					review["objective"] = str(club.board.get("objective", ""))
					review["verdict"] = verdict
					Rivalries.season_rival_verdict(w, club, st, i + 1, verdict)
					_career_ladder(club, verdict, i + 1)
				elif verdict == "sacked":
					_ai_sack(club)
			if i == 0:
				Contracts.title_bonuses(w, club)
				Fans.title(club)
				club.history["league_titles"] = int(club.history.get("league_titles", 0)) + 1
				club.history["last_title"] = ended_season
			var champ_prize := int(comp.prizes.get("galleons_champion", 3000))  # [FILLER]
			var base_prize := int(comp.prizes.get("galleons_per_position_step", 300))
			var prize := champ_prize
			if i > 0:
				prize = base_prize + int((champ_prize * 0.5 - base_prize) * float(st.size() - 1 - i) / float(maxi(st.size() - 2, 1)))
			Economy.book(w, club, "prizes", maxi(prize, base_prize))
		_update_reputations(st)
		for a in Awards.season_awards(w, comp, ended_season):
			var ap: Player = w.player(str(a["player_id"]))
			if ap == null:
				continue
			var award_club := str(a["club_id"])
			if comp.id == (w.my_club().league_id if w.my_club() != null else ""):
				var args: Dictionary[String, Say.Arg] = {"award": Say.key(Awards.kind_key(str(a["kind"]))), "player": Say.player(ap), "league": Say.comp(comp.id)}
				if award_club == "":
					_append_news_item(NewsGenerator.item("news.award_no_club", 3, args))
				else:
					args["club"] = Say.team(w, award_club)
					_append_news_item(NewsGenerator.item("news.award", 3, args))
			if ap.club_id == w.player_club_id and w.player_club_id != "":
				var kind := str(a["kind"])
				var body := "msg.award.body." + kind if AWARD_STAT_BODIES.has(kind) and str(a.get("value", "")) != "" else "msg.award.body"
				Inbox.tell(w, &"from.club_secretary", "msg.award.subject", body, {"award": Say.key(Awards.kind_key(kind)), "player": Say.player(ap), "value": Say.plain(str(a.get("value", "")))})
				ap.morale = clampf(ap.morale + 10.0, 0.0, 100.0)
				review["awards"][0].append(ap.name())
				review["awards"][1].append(ap.id)
		comp.build_fixtures(rng(), ended_season + 1, stagger)
		stagger += 1
	Records.season_end(w, ended_season)
	w.season = ended_season + 1
	for c in w.clubs.values():
		c.board.erase("negotiated")
		c.board.erase("ultimatum")
		if c.balance < 0 and rng().chance(0.03):  # [game]
			var cash := int(c.reputation * 1.5)
			Economy.book(w, c, "investment", cash)
			c.transfer_budget += int(cash * 0.4)
			_append_news_item(NewsGenerator.item("news.takeover", 3, {"club": Say.club(c), "amount": Say.money(cash)}, {"clubs": [c.id]}))
			if c.manager_is_human:
				Inbox.tell(w, &"from.board", "msg.takeover.subject", "msg.takeover.body", {"club": Say.club(c), "amount": Say.money(cash)})
		if int(c.sponsor.get("ends_season", 9999)) < w.season:  # [game]
			if c.manager_is_human:
				_sponsor_offers(c)
			else:
				c.sponsor = _sponsor_offer(c)
		if not c.manager_is_human:  # [game]
			var bill := 0
			for p in w.squad_of(c.id):
				bill += int(p.contract.get("wage_weekly", 10))
			c.balance += int((30 * bill - c.balance) * 0.25)
	_new_season_boards(ended_season)
	_flush_job_offers()
	var forced := {}
	var champs := {}
	if bool(w.settings.get("book_events", true)):
		for e in loader.events:
			if str(e.get("kind", "")) == "graduate_to" and int(e.get("season", -1)) == ended_season:
				forced[str(e["player_id"])] = {"club_id": str(e["club_id"]), "squad": str(e.get("squad", Player.Squad.RESERVE))}
		for sid in loader.schools.keys():
			var champ := Schools.canon_cup_champion(loader.events, "comp_school_%s_%d" % [str(sid).trim_prefix("school_"), ended_season])
			if champ != "":
				champs[sid] = champ
	var grads := Schools.rollover(w, loader, rng(), ended_season, _school_cup_skips(ended_season + 1), forced, champs)
	for g in grads:
		if str(g["club_id"]) == w.player_club_id and w.player_club_id != "":
			var gp: Player = w.player(str(g["player_id"]))
			Inbox.tell(w, &"from.club_secretary", "msg.graduate.subject", "msg.graduate.body", {"player": Say.player(gp), "school": Say.plain(str(loader.schools.get(gp.school_id, {}).get("short_name", gp.school_id))), "pos": Say.key("pos." + gp.position)})
			if not w.is_school_mode():
				review["arrivals"][0].append(gp.name())
				review["arrivals"][1].append(gp.id)
	for pc in Contracts.execute_pre_contracts(w):
		var pcp: Player = w.player(str(pc["player_id"]))
		for tr_entry in w.transfers:
			if int(tr_entry.get("day", -1)) != w.today:
				break
			if str(tr_entry.get("player_id", "")) == str(pc["player_id"]):
				tr_entry["rollover"] = true
				break
		if str(pc["from_id"]) == w.player_club_id and w.player_club_id != "":
			Inbox.tell(w, &"from.club_secretary", "msg.pre_contract_gone.subject", "msg.pre_contract_gone.body", {"player": Say.player(pcp), "club": Say.team(w, str(pc["to_id"]))})
			review["departures"][0].append(pcp.name())
			review["departures"][1].append(pcp.id)
		elif str(pc["to_id"]) == w.player_club_id and w.player_club_id != "":
			Inbox.tell(w, &"from.club_secretary", "msg.pre_contract_arrived.subject", "msg.pre_contract_arrived.body", {"player": Say.player(pcp)})
			review["arrivals"][0].append(pcp.name())
			review["arrivals"][1].append(pcp.id)
	Contracts.yearly_rises(w)
	var retired := []
	var canon_future := _book_event_players()
	for p in w.players_sorted():
		if p.squad == Player.Squad.SCHOOL:
			continue
		var age: int = p.age(w.today)
		var retire: bool = not canon_future.has(p.id) and (age >= 38  # [PM-2014]
				or (age >= 34 and rng().chance(0.25 + 0.1 * (age - 34)))
				or (age >= 31 and p.ca() < 70.0 and rng().chance(0.5)))
		if retire:
			if p.is_on_loan():
				Economy.return_loan(w, p)
			var mine: bool = p.club_id != "" and p.club_id == w.player_club_id
			retired.append({"name": p.name(), "id": p.id, "ca": p.ca(), "mine": mine, "abroad": p.squad == Player.Squad.ABROAD})
			if p.club_id != "" and w.clubs.has(p.club_id) and w.clubs[p.club_id].manager_is_human:
				Inbox.tell(w, &"from.player", "msg.retirement.subject", "msg.retirement.body", {"player": Say.player(p), "age": Say.num(age)})
			if mine and not w.is_school_mode():
				review["departures"][0].append(p.name())
				review["departures"][1].append(p.id)
			w.remove_player(p.id)
			continue
		var back_to_me := false
		if p.is_on_loan():
			var borrower: Club = w.club(p.club_id)
			var owner: Club = w.club(p.loan_owner_id())
			Economy.return_loan(w, p)
			if borrower != null and borrower.manager_is_human:
				Inbox.tell(w, &"from.club_secretary", "msg.loan_ended.subject", "msg.loan_ended.body", {"player": Say.player(p), "club": (Say.club(owner) if owner else Say.plain(""))})
				if not _lineup_valid(borrower):
					borrower.lineup = WorldGenerator.best_lineup(w, borrower.id)
			elif owner != null and owner.manager_is_human:
				back_to_me = true
				if int(p.contract.get("end_day", 0)) > w.today or (p.squad == Player.Squad.YOUTH and age < 19):
					Inbox.tell(w, &"from.club_secretary", "msg.loan_returned.subject", "msg.loan_returned.body", {"player": Say.player(p)})
		for k in Player.ATTR_KEYS:
			p.attrs[k] = clampf(float(p.attrs[k]) - 0.15, 1.0, 20.0)
		if int(p.contract.get("end_day", 0)) <= w.today and p.club_id != "":
			var club: Club = w.club(p.club_id)
			if p.squad == Player.Squad.YOUTH and age < 19:
				p.contract["end_day"] = WDate.from_ymd(w.season + 19 - age, 6, 30)
			elif club.manager_is_human:
				Inbox.tell(w, &"from.club_secretary", "msg.contract_expired.subject", "msg.contract_expired.body_loan" if back_to_me else "msg.contract_expired.body", {"player": Say.player(p)})
				w.move_player(p, "", "free")
				w.log_release(p.id, club.id)
				p.is_captain = false
				p.free_since = w.season
				if not w.is_school_mode():
					review["departures"][0].append(p.name())
					review["departures"][1].append(p.id)
			elif _ai_wants_renewal(club, p):
				p.contract["end_day"] = WDate.from_ymd(w.season + rng().irange(1, 3), 6, 30)
			else:
				w.move_player(p, "", "free")
				w.log_release(p.id, club.id)
				p.is_captain = false
				p.free_since = w.season
		if p.squad == Player.Squad.YOUTH and age >= 19:
			p.squad = Player.Squad.RESERVE
		p.snapshot_attrs()
	var gen: WorldGenerator = WorldGenerator.new(loader)  # [FILLER, simplified]
	var on_sale := _brooms_on_sale()
	for club in w.clubs_sorted():
		var intake: Array = []
		var have := {"K": 0, "C": 0, "B": 0, "S": 0}
		for q in w.squad_of(club.id):
			if have.has(q.position):
				have[q.position] += 1
		for i in WorldGenerator.YOUTH_PER_CLUB:
			var pos: String = str(rng().pick(_intake_choices(have)))
			have[pos] += 1
			var p: Player = gen._make_filler(w, club, pos, "youth", rng(), 500 + i + w.season)
			w.add_player(p)
			intake.append(p)
		if club.manager_is_human and not w.is_school_mode():
			var args: Dictionary[String, Say.Arg] = {}
			var shown: Array = intake.slice(0, 3)
			for i in shown.size():
				var p: Player = shown[i]
				var verdict := "youth.verdict.squad"
				if p.pa >= 150.0:
					verdict = "youth.verdict.star"
				elif p.pa >= 120.0:
					verdict = "youth.verdict.good"
				elif p.pa < 85.0:
					verdict = "youth.verdict.weak"
				args["n%d" % (i + 1)] = Say.player(p)
				args["p%d" % (i + 1)] = Say.key("pos." + p.position)
				args["v%d" % (i + 1)] = Say.key(verdict)
			for p in intake:
				review["arrivals"][0].append(p.name())
				review["arrivals"][1].append(p.id)
			if not shown.is_empty():
				Inbox.tell(w, &"from.assistant", "msg.youth_intake.subject", "msg.youth_intake.body.%d" % shown.size(), args)
		if not club.manager_is_human:
			gen._fill_squad(w, club, rng(), false)
			var squad := w.squad_of(club.id)
			var counts := {"K": 0, "C": 0, "B": 0, "S": 0}
			for q in squad:
				counts[q.position] += 1
			var candidates: Array[Player] = []
			for q in squad:
				if (q.squad == Player.Squad.YOUTH and q.age(w.today) < 19) or q.source == "canon_book":
					continue
				candidates.append(q)
			candidates.reverse()
			for cand in candidates:
				if squad.size() <= MAX_SQUAD:
					break
				if counts[cand.position] <= MIN_PER_POSITION[cand.position]:
					continue
				w.move_player(cand, "", "free")
				w.log_release(cand.id, club.id)
				cand.is_captain = false
				cand.free_since = w.season
				counts[cand.position] -= 1
				squad.erase(cand)
			if squad.size() > MAX_SQUAD + 1:
				var youths: Array = []
				for q in squad:
					if q.squad == Player.Squad.YOUTH and q.source != "canon_book":
						youths.append(q)
				youths.sort_custom(func(a, b): return a.pa < b.pa)
				for q in youths:
					if squad.size() <= MAX_SQUAD + 1:
						break
					w.move_player(q, "", "free")
					w.log_release(q.id, club.id)
					q.is_captain = false
					q.free_since = w.season
					squad.erase(q)
			club.lineup = WorldGenerator.best_lineup(w, club.id)
			_ai_broom_upgrade(club, on_sale)
		for bp in w.club_players(club.id):
			Progression.service_broom(bp, club.broom_care_level())
		club.transfer_budget = clampi(maxi(club.transfer_budget, int(club.balance * 0.3)), 0, maxi(club.balance, 0))
		if WorldGenerator.ensure_captain(w, club) and club.manager_is_human:
			Economy.notify_new_captain(w, club.id)
	for nt_id in w.national_team_ids_sorted():
		WorldGenerator.refill_abroad_pool(w, w.national_teams[nt_id], rng(), loader)
	for p in w.players_sorted():
		if p.club_id == "" and p.squad == Player.Squad.FREE:
			if p.free_since == 0:
				p.free_since = w.season
			elif (p.free_since < w.season or p.age(w.today) >= 34) and not canon_future.has(p.id):
				w.remove_player(p.id)
	var me := w.my_club()
	if me != null and w.is_school_mode():
		_house_season_review(ended_season)
		var hd: Dictionary = w.houses.get(me.id, {})
		var gone := [[], []]
		var gone_free := [[], []]
		for g in grads:
			var gp: Player = w.player(str(g["player_id"]))
			if gp != null and gp.school_id == str(hd.get("school_id", "")) and Schools.house_id(gp.school_id, str(g.get("house", gp.house))) == me.id:
				if gp.club_id != "":
					gone[0].append("%s (%s)" % [gp.name(), w.team_name(gp.club_id)])
					gone[1].append(gp.id)
				else:
					gone_free[0].append(gp.name())
					gone_free[1].append(gp.id)
		var fresh := [[], []]
		for p in w.squad_of(me.id):
			if p.id.find("_%d_" % w.season) >= 0:
				fresh[0].append(p.name())
				fresh[1].append(p.id)
		if not gone[0].is_empty() or not gone_free[0].is_empty() or not fresh[0].is_empty():
			Inbox.tell(w, &"from.head_of_house", "msg.house_roster.subject", "msg.house_roster.body_split",
				{"gone": _named_list(gone), "gone_free": _named_list(gone_free),
				 "fresh": _named_list(fresh) if not fresh[0].is_empty() else (Say.key("msg.house_roster.tryouts_pending") if not hd.get("tryouts", {}).is_empty() else Say.plain("—"))})
		if not _lineup_valid(me):
			me.lineup = Schools.best_lineup(w, me.id)
		Inbox.tell(w, &"from.head_of_house", "msg.new_year_house.subject", "msg.new_year_house.body", {"season": Say.season(w.season)})
	elif me != null:
		var counts := {"K": 0, "C": 0, "B": 0, "S": 0}  # [game]
		for q in w.squad_of(me.id, [Player.Squad.FIRST, Player.Squad.RESERVE]):
			counts[q.position] += 1
		var minimum := {"K": 1, "C": 3, "B": 2, "S": 1}
		var short := false
		for pos in minimum.keys():
			if counts[pos] < minimum[pos]:
				short = true
		if short:
			var before := w.squad_of(me.id).size()
			gen._fill_squad(w, me, rng(), false, true)
			var signed: Array = []
			for q in w.squad_of(me.id):
				if q.id.ends_with("_%d" % w.season) and q.squad != Player.Squad.YOUTH:
					signed.append(Say.player(q))
					review["arrivals"][0].append(q.name())
					review["arrivals"][1].append(q.id)
			if w.squad_of(me.id).size() > before:
				Inbox.tell(w, &"from.club_secretary", "msg.emergency_signing.subject", "msg.emergency_signing.body", {"players": Say.list(signed)})
		if not _lineup_valid(me):
			me.lineup = WorldGenerator.best_lineup(w, me.id)
		retired.sort_custom(func(a, b):
			if a["mine"] != b["mine"]:
				return a["mine"]
			if a["abroad"] != b["abroad"]:
				return b["abroad"]
			return a["ca"] > b["ca"] if a["ca"] != b["ca"] else str(a["name"]) < str(b["name"]))
		Inbox.tell(w, &"from.club_secretary", "msg.new_season.subject", "msg.new_season.body" if not retired.is_empty() else "msg.new_season.body_none",
			{"season": Say.season(w.season), "retired": Say.list(retired.slice(0, 5).map(func(r): return Say.entity(str(r["id"]), str(r["name"]))))})
	if not w.is_school_mode():
		_post_season_review(review)


## Awards whose stat gets its own sentence in the owl (msg.award.body.<kind>): rating, goals, catches, keeper rating.
const AWARD_STAT_BODIES := ["wronski", "top_scorer", "top_catcher", "best_keeper"]


func _post_season_review(review: Dictionary) -> void:  # [game]
	var me := w.my_club()
	var judged := review.has("verdict")
	if not judged and me == null:
		return
	var season := int(review["season"])
	var args: Dictionary[String, Say.Arg] = {"season": Say.season(season)}
	var old: Club = w.club(str(review.get("club_id", "")))
	args["club"] = Say.club(old) if old != null else (Say.club(me) if me != null else Say.plain(""))
	if judged:
		args["position"] = Say.num(int(review["pos"]))
		args["league"] = Say.comp(str(review["league"]))
		args["objective"] = Say.key("objective." + str(review["objective"]))
		args["verdict"] = Say.key("msg.season_review.verdict." + str(review["verdict"]))
	var cups: Array = []
	for t in w.manager.get("trophies", []):
		if int(t.get("season", -1)) == season and cups.size() < 4:
			cups.append(str(t.get("competition_id", "")))
	for i in 4:
		args["t%d" % (i + 1)] = Say.comp(str(cups[i])) if i < cups.size() else Say.plain("—" if i == 0 else "")
		if i > 0:
			args["ts%d" % (i + 1)] = Say.plain(NewsGenerator.list_sep() if i < cups.size() else "")
	var cid := str(review.get("club_id", ""))
	var from_day := WDate.from_ymd(season, 7, 1)
	var to_day := WDate.from_ymd(season + 1, 7, 1)
	var moves := {"departures": [[], []], "arrivals": [[], []]}
	for i in range(w.transfers.size() - 1, -1, -1):
		var tr_: Dictionary = w.transfers[i]
		var day := int(tr_.get("day", 0))
		if cid == "" or bool(tr_.get("loan", false)) or bool(tr_.get("rollover", false)) or World.is_release(tr_) or day < from_day or day >= to_day:
			continue
		var pid := str(tr_.get("player_id", ""))
		var pname: String = w.players[pid].name() if w.players.has(pid) else str(w.former_names.get(pid, ""))
		if pname == "":
			continue
		var side := "departures" if str(tr_.get("from_id", "")) == cid else ("arrivals" if str(tr_.get("to_id", "")) == cid else "")
		if side != "":
			moves[side][0].append(pname)
			moves[side][1].append(pid)
	for k in moves.keys():
		review[k] = [moves[k][0] + review[k][0], moves[k][1] + review[k][1]]
	for k in ["awards", "departures", "arrivals"]:
		var unique := [[], []]
		for j in review[k][0].size():
			if not unique[1].has(review[k][1][j]):
				unique[0].append(review[k][0][j])
				unique[1].append(review[k][1][j])
		args[k] = _named_list(unique)
	var body := "msg.season_review.body"
	if me == null:
		body = "msg.season_review.body_left"
	elif not judged:
		body = "msg.season_review.body_new"
	if me != null:
		args["next_season"] = Say.season(w.season)
		args["next_objective"] = Say.key("objective." + str(me.board.get("objective", "")))
		args["budget"] = Say.money(me.wage_budget_weekly)
	Inbox.tell(w, &"from.assistant", "msg.season_review.subject", body, args)


## A list of [names, ids] collected over a rollover as linked names, or "—" when it is empty.
static func _named_list(pair: Array) -> Say.Arg:
	if pair[1].is_empty():
		return Say.plain("—")
	var items: Array = []
	for i in pair[1].size():
		items.append(Say.entity(str(pair[1][i]), str(pair[0][i])))
	return Say.list(items)
