class_name Rivalries  # [game]
extends RefCounted
## Canon derbies: Appleby–Wimbourne [QTTA c7], Harpies–Puddlemere [DP], Thundelarra–Woollongong [QTTA c8]; the
## rest [FILLER].

const GATE_BONUS := 1.25          # [FILLER]
const MORALE_SWING := 3.0         # [FILLER]
const FANS_SWING := 2.0           # [FILLER]
const BOARD_SWING := 5.0          # [FILLER]
const FORMER_STAR_RATING := 8.0
const PREVIEW_DAYS := 7


## Are the two clubs rivals? Symmetric even if only one side lists the other. National teams, school houses and
## unknown ids have no rivals.
static func are_rivals(w: World, a: String, b: String) -> bool:
	if w == null or a == "" or b == "" or a == b:
		return false
	var ca: Club = w.club(a)
	var cb: Club = w.club(b)
	if ca == null or cb == null:
		return false
	var ra: Array = ca.identity.get("rivalries", [])
	var rb: Array = cb.identity.get("rivalries", [])
	return ra.has(b) or rb.has(a)


## The club's rivals (club ids of existing clubs, sorted), both directions.
static func rivals_of(w: World, club_id: String) -> Array:
	var out: Array = []
	var c: Club = w.club(club_id) if w != null else null
	if c == null:
		return out
	for r in c.identity.get("rivalries", []):
		if w.clubs.has(str(r)) and not out.has(str(r)) and str(r) != club_id:
			out.append(str(r))
	for o in w.clubs.values():
		if o.id != club_id and not out.has(o.id) and (o.identity.get("rivalries", []) as Array).has(club_id):
			out.append(o.id)
	out.sort()
	return out


## The rival the board measures the club against: the first rival (by id) playing in the same league, or "".
static func board_rival(w: World, club: Club) -> String:
	if club == null or club.league_id == "":
		return ""
	for r in rivals_of(w, club.id):
		if w.club(r).league_id == club.league_id:
			return r
	return ""


## Fan mood after a derby: on top of Fans.after_match, the winners' fans are happier and the losers' angrier.
static func derby_fans(hc: Club, ac: Club, sh: int, sa: int) -> void:
	if sh == sa:
		return
	var d: float = FANS_SWING if sh > sa else -FANS_SWING
	hc.fans["mood"] = clampf(Fans.mood(hc) + d, 0.0, 100.0)
	ac.fans["mood"] = clampf(Fans.mood(ac) - d, 0.0, 100.0)


## Extra morale for a player of `team_id` after a derby won by `winner_id` ("" = a draw: nothing extra).
static func morale_swing(team_id: String, winner_id: String) -> float:
	if winner_id == "":
		return 0.0
	return MORALE_SWING if winner_id == team_id else -MORALE_SWING


## Monday edition: previews of the derbies of the coming week and of the manager's return to a club they
## managed before. Derbies of the manager's club lead (importance 5), those of the manager's league follow (3); from
## the rest of the world only the biggest top-flight derby (by the two clubs' reputation) gets in. No RNG.
static func preview_items(w: World) -> Array:  # [game]
	var out: Array = []
	var me := w.my_club()
	if me != null and w.is_school_mode():
		return out
	var my_id: String = me.id if me != null else ""
	var my_league: String = me.league_id if me != null else "comp_british_irish_league"
	var former := _former_clubs(w, my_id)
	var best_foreign := {}
	var best_rep := -1
	var comp_ids := w.competitions.keys()
	comp_ids.sort()
	for cid in comp_ids:
		var comp: Competition = w.competitions[cid]
		if comp.type in Competition.Type.CASUAL:
			continue
		for f in comp.fixtures:
			var day := int(f.get("day", 0))
			if day <= w.today or day > w.today + PREVIEW_DAYS or bool(f.get("played", false)):
				continue
			var h := str(f["home_id"])
			var a := str(f["away_id"])
			var mine := my_id != "" and (h == my_id or a == my_id)
			if mine and former.has(a if h == my_id else h):
				out.append(_return_item(w, comp, my_id, a if h == my_id else h))
			if not are_rivals(w, h, a):
				continue
			var item := _derby_item(w, comp, h, a)
			if mine:
				item["importance"] = 5
				out.append(item)
			elif w.club(h).league_id == my_league or w.club(a).league_id == my_league:
				item["importance"] = 3
				out.append(item)
			elif comp.type == Competition.Type.LEAGUE and comp.level <= 1:
				var rep: int = w.club(h).reputation + w.club(a).reputation
				if rep > best_rep:
					best_rep = rep
					best_foreign = item
	if not best_foreign.is_empty():
		best_foreign["importance"] = 2
		out.append(best_foreign)
	return out


static func _derby_item(w: World, comp: Competition, h: String, a: String) -> Dictionary:
	return NewsGenerator.item("news.derby_preview", 3, {"home": Say.team(w, h), "away": Say.team(w, a), "competition": Say.comp(comp.id)}, {"clubs": [h, a]})


static func _former_clubs(w: World, current_id: String) -> Dictionary:
	var out := {}
	for e in w.manager.get("career", []):
		if not (e is Dictionary):
			continue
		var cid := str(e.get("club_id", ""))
		if e.has("to") and cid != current_id and w.clubs.has(cid):
			out[cid] = true
	return out


static func _return_item(w: World, comp: Competition, my_id: String, old_id: String) -> Dictionary:
	return NewsGenerator.item("news.return_to_former", 4, {"manager": Say.plain(str(w.manager.get("name", ""))), "club": Say.team(w, my_id), "former": Say.team(w, old_id), "competition": Say.comp(comp.id)}, {"clubs": [my_id, old_id]})


## A player the manager's club sold who starred against it: the best-rated such player of the match, from
## FORMER_STAR_RATING up. {} if none.
static func former_star_item(w: World, my_id: String, opp: SimTeam, r: MatchResult) -> Dictionary:
	var left := {}
	for tr_ in w.transfers:
		if str(tr_.get("from_id", "")) == my_id and not bool(tr_.get("loan", false)) and not World.is_release(tr_):
			left[str(tr_.get("player_id", ""))] = true
	if left.is_empty():
		return {}
	var won := r.winner_id() == opp.id
	var best_id := ""
	var best := FORMER_STAR_RATING
	for sp in opp.players:
		if not left.has(sp.id):
			continue
		var p: Player = w.player(sp.id)
		if p == null or p.loan_owner_id() == my_id:
			continue
		var rating := Progression.match_rating(sp.stats, sp.position, won)
		if rating >= best:
			best = rating
			best_id = sp.id
	if best_id == "":
		return {}
	var star: Player = w.player(best_id)
	return NewsGenerator.item("news.former_star", 4, {
		"player": Say.player(star), "club": Say.team(w, my_id), "team": Say.team(w, opp.id), "rating": Say.plain("%.1f" % best),
	}, {"clubs": [my_id, opp.id]})


## Season end, the human club's board: the secondary objective of finishing above the league rival (`st` is the
## final table, `final_pos` the club's place). A light bonus or malus on top of the season verdict, none when
## `verdict` is "sacked".
static func season_rival_verdict(w: World, club: Club, st: Array, final_pos: int, verdict: String) -> void:
	var rival := board_rival(w, club)
	if rival == "" or verdict == "sacked":
		return
	var rpos := -1
	for j in st.size():
		if str(st[j]["club_id"]) == rival:
			rpos = j + 1
	if rpos < 0:
		return
	var above := final_pos < rpos
	var conf: float = float(club.board.get("confidence", 60.0))
	if above:
		club.board["confidence"] = minf(100.0, conf + BOARD_SWING)
	else:
		club.board["confidence"] = maxf(minf(conf, Career.ULTIMATUM_CONFIDENCE), conf - BOARD_SWING)
	Inbox.tell(w, &"from.board", "msg.rival_objective.subject", "msg.rival_objective.body." + ("met" if above else "missed"), {"rival": Say.team(w, rival), "position": Say.num(final_pos), "rival_position": Say.num(rpos)})
