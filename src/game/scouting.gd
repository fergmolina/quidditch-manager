class_name Scouting  # [game]
extends RefCounted

const MAX_QUALITY := 4


static func wage(quality: int) -> int:
	return 40 + 20 * quality


## Hiring fee for a scout of `quality`: three months of wages.
static func hire_fee(quality: int) -> int:
	return 3 * wage(quality)


## The most a hire can cost (the quality is drawn only once the club can pay): checked before the draw.
static func max_hire_fee() -> int:
	return hire_fee(MAX_QUALITY)


static func request(w: World, club: Club, p: Player) -> String:
	if club.scouts.is_empty():
		return "ui.scout.no_scouts"
	var cur: Dictionary = club.scout_reports.get(p.id, {})
	if bool(cur.get("pending", false)):
		return "ui.scout.already"
	var q := best_quality(club)
	club.scout_reports[p.id] = {"pending": true, "due": w.today + maxi(5, 12 - 2 * q)}
	return "ui.scout.requested"


static func best_quality(club: Club) -> int:
	var q := 1
	for sc in club.scouts:
		q = maxi(q, int(sc.get("quality", 1)))
	return q


static func stars(v: float) -> int:
	return clampi(int(round(v / 36.0)), 1, 5)


## Reports due today: they are completed and arrive by owl.
static func daily(w: World, club: Club, rng: SimRng) -> void:
	for pid in club.scout_reports.keys():
		var r: Dictionary = club.scout_reports[pid]
		if not bool(r.get("pending", false)) or int(r.get("due", 0)) > w.today:
			continue
		var p: Player = w.player(str(pid))
		if p == null:
			club.scout_reports.erase(pid)
			continue
		var err := 18.0 - 3.0 * best_quality(club) - 1.5 * club.staff_level("head_scout")
		var ca_est := stars(p.ca() + rng.gauss(0.0, maxf(err, 2.0)))
		var pa_est := stars(p.pa + rng.gauss(0.0, maxf(err * 1.3, 3.0)))
		var verdict := "ui.scout.verdict.skip"
		var my_best := 0.0
		for q in w.squad_of(club.id, [Player.Squad.FIRST]):
			if q.position == p.position:
				my_best = maxf(my_best, q.ca())
		if ca_est >= stars(my_best) or pa_est >= 4:
			verdict = "ui.scout.verdict.sign"
		elif pa_est >= 3 and p.age(w.today) <= 22:
			verdict = "ui.scout.verdict.watch"
		club.scout_reports[pid] = {"day": w.today, "ca_est": ca_est, "pa_est": pa_est, "verdict": verdict, "value": p.market_value(w.today)}
		Inbox.tell(w, &"from.head_scout", "msg.scout_report.subject", "msg.scout_report.body", {"player": Say.player(p), "club": (Say.team(w, p.club_id) if p.club_id != "" else Say.key("ui.squad.free")), "ca": Say.plain("★".repeat(ca_est) + "☆".repeat(5 - ca_est)), "pa": Say.plain("★".repeat(pa_est) + "☆".repeat(5 - pa_est)), "verdict": Say.key(verdict), "value": Say.money(p.market_value(w.today))})


## Next-opponent report: probable seven, style and their star player (two days before each league match).
static func opponent_report(w: World, club: Club, f: Dictionary) -> void:
	var rival_id := str(f["away_id"]) if str(f["home_id"]) == club.id else str(f["home_id"])
	var rival: Club = w.club(rival_id)
	if rival == null:
		return
	var l := WorldGenerator.best_lineup(w, rival.id)
	var seven: Array = []
	var star: Player = null
	for pid in [l.get("K", "")] + l.get("C", []) + l.get("B", []) + [l.get("S", "")]:
		var q: Player = w.player(str(pid))
		if q == null:
			continue
		seven.append(Say.phrase("{pos} {name}", {"pos": Say.plain(q.position), "name": Say.player(q)}).as_arg())
		if star == null or q.ca() > star.ca():
			star = q
	var lg := w.league_of(rival.id)
	var pos := lg.position_of(rival.id) if lg != null else 0
	Inbox.tell(w, &"from.head_scout", "msg.opponent_report.subject", "msg.opponent_report.body",
		{"club": Say.club(rival), "pos": Say.num(pos), "lineup": Say.list(seven), "star": Say.player(star) if star != null else Say.plain(""),
		 "style": Say.key("defence." + SimTactics.defence_of(rival.tactics))})
