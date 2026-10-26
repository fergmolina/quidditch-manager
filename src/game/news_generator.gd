class_name NewsGenerator
extends RefCounted
## The Daily Prophet: items with a translatable key and parameters.


## The one constructor of a news item: {"key", "args"} from Say, plus plain routing fields the engine and the news
## screen read (clubs, comp_id, masthead, fee). Nothing reads the text to route an item.
static func item(key: String, importance: int, args: Dictionary[String, Say.Arg] = {}, routing: Dictionary = {}) -> Dictionary:
	var it := Say.phrase(key, args).to_dict()
	it["importance"] = importance
	it.merge(routing)
	return it


static func match_item(w: World, r: MatchResult, f: Dictionary, comp: Competition = null) -> Dictionary:
	var hc: Club = w.club(r.home_id)
	var ac: Club = w.club(r.away_id)
	var key := "news.match.result"
	if r.end_reason == MatchResult.EndReason.TIME_CAP:
		key = "news.match.time_cap"
	var mins := r.duration_minutes()
	if mins < 15.0:
		key = "news.match.lightning"
	elif mins > 480.0:
		key = "news.match.marathon"
	elif r.end_reason == MatchResult.EndReason.MUTUAL_END:
		key = "news.match.mutual_end"
	elif r.snitch_team_id != "" and r.winner_id() != r.snitch_team_id and r.winner_id() != "":
		key = "news.match.caught_and_lost" if w.today >= WDate.from_ymd(1994, 8, 22) else "news.match.caught_and_lost_neutral"  # [GoF 8]
	var catcher: Player = w.players.get(r.snitch_player_id)
	return item(key, 4, {
		"home": Say.team(w, r.home_id), "away": Say.team(w, r.away_id), "competition": Say.comp(comp.id) if comp else Say.plain(""),
		"sh": Say.num(r.score_home), "sa": Say.num(r.score_away), "venue": Say.venue(str(f.get("venue", ""))), "duration": Say.duration(r.duration_s),
		"catcher": Say.player(catcher) if catcher != null else Say.plain(""), "snitch_club": Say.team(w, r.snitch_team_id) if r.snitch_team_id != "" else Say.plain(""),
	}, {"clubs": [r.home_id, r.away_id], "comp_id": comp.id if comp else ""})


static func injury_item(w: World, p: Player, club: Club) -> Dictionary:
	return NewsGenerator.item("news.injury", 2, {"player": Say.player(p), "club": Say.club(club), "days": Say.num(p.injury_days)}, {"clubs": [club.id]})


static func table_item(w: World, comp: Competition, top_n: int = 3) -> Dictionary:
	var st := comp.standings()
	var top: Array = []
	for i in mini(top_n, st.size()):
		top.append(Say.phrase("ui.list.name_detail", {"name": Say.team(w, str(st[i]["club_id"])), "detail": Say.num(int(st[i]["pts"]))}).as_arg())
	var last_row: Dictionary = st[st.size() - 1] if not st.is_empty() else {}
	return item("news.table", 3, {"league": Say.comp(comp.id), "top": Say.list(top),
		"last": Say.team(w, str(last_row["club_id"])) if not last_row.is_empty() else Say.plain(""), "round": Say.num(matchdays_played(comp))})


## Filler items from the other wizarding papers, each signed with its own masthead.
const FILLER_MASTHEADS := {
	"news.quibbler.1": "news.masthead.quibbler", "news.quibbler.2": "news.masthead.quibbler", "news.quibbler.3": "news.masthead.witch_weekly",
	"news.quibbler.4": "news.masthead.quibbler", "news.quibbler.5": "news.masthead.which_broomstick",
}


static func quibbler_item(rng: SimRng) -> Dictionary:
	var keys := ["news.quibbler.1", "news.quibbler.2", "news.quibbler.3", "news.quibbler.4", "news.quibbler.5"]
	var key := str(rng.pick(keys))
	return NewsGenerator.item(key, 1, {}, {"masthead": str(FILLER_MASTHEADS.get(key, "news.masthead.quibbler"))})


## Filler pools: every data/shared/news_fillers/<publication>.json is an Array of {key, from, to?, months?}; an entry
## is shown while the world's calendar year is within [from, to] and, if `months` is given, only in those months (an
## entry may be repeated with other years/months to gate a span that starts or ends mid-year). The publication (the
## file name) gives the masthead news.masthead.<pub>; the Prophet's own column (prophet.json) carries none.
const FILLER_DIR := "res://data/shared/news_fillers"
## Keys printed in the last editions are skipped while other dated keys remain.
const FILLER_RECENT_EDITIONS := 20


## One dated entry of a filler pool. `months` empty means any month.
class Filler:
	var key: String
	var pub: String
	var from_year: int
	var to_year: int
	var months: Array[int]

static var _filler_pool: Array[Filler] = []
static var _filler_loaded := false


## This edition's filler from the pools, dated by the world's calendar. One draw.
static func filler_item(w: World, rng: SimRng) -> Dictionary:
	var y := WDate.year(w.today)
	var m := WDate.month(w.today)
	var dated: Array = []
	var pubs: Dictionary[String, String] = {}
	for e in _fillers():
		if y < e.from_year or y > e.to_year:
			continue
		if not e.months.is_empty() and not e.months.has(m):
			continue
		if not pubs.has(e.key):
			pubs[e.key] = e.pub
			dated.append(e.key)
	if dated.is_empty():
		return quibbler_item(rng)
	var recent := {}
	for i in mini(FILLER_RECENT_EDITIONS, w.news.size()):
		for it in w.news[i].get("items", []):
			recent[str(it.get("key", ""))] = true
	var fresh: Array = dated.filter(func(dk): return not recent.has(dk))
	var key := str(rng.pick(fresh if not fresh.is_empty() else dated))
	var item := NewsGenerator.item(key, 1)
	var pub := pubs[key]
	if pub != "prophet":
		item["masthead"] = "news.masthead." + pub
	return item


static func _fillers() -> Array[Filler]:
	if _filler_loaded:
		return _filler_pool
	_filler_loaded = true
	for path in SimLoader.list_files(FILLER_DIR):
		var pub := str(path).get_file().get_basename()
		var data = SimLoader.load_json(path)
		if not (data is Array):
			continue
		for e in data:
			if not (e is Dictionary) or str(e.get("key", "")) == "":
				continue
			var f := Filler.new()
			f.key = str(e["key"])
			f.pub = pub
			f.from_year = int(e.get("from", 0))
			f.to_year = int(e.get("to", 9999))
			# JSON numbers arrive as floats: months are stored as ints so has() matches WDate.month().
			for mm in e.get("months", []):
				f.months.append(int(mm))
			_filler_pool.append(f)
	return _filler_pool


## A league's champion in the Daily Prophet, with the runner-up and the champion's points. `importance` 6 makes
## it the lead story (the manager's own league), 5 front-page news (the top-flight leagues, `front`).
static func league_champion_item(w: World, comp: Competition, st: Array, season: int, front: bool, importance: int = 3) -> Dictionary:  # [game]
	var champ := str(st[0]["club_id"])
	var runner := str(st[1]["club_id"]) if st.size() > 1 else ""
	var routing := {} if front else {"clubs": [champ]}
	return NewsGenerator.item("news.league_champion", importance, {"team": Say.team(w, champ), "league": Say.comp(comp.id), "season": Say.season(season), "pts": Say.num(int(st[0]["pts"])), "runner": (Say.team(w, runner) if runner != "" else Say.plain("—"))}, routing)


## Matchdays played so far: the most matches any one team has played, not the highest round number.
static func matchdays_played(comp: Competition) -> int:
	var played := {}
	var r := 0
	for f in comp.fixtures:
		if bool(f.get("played", false)):
			for side in ["home_id", "away_id"]:
				var cid := str(f[side])
				played[cid] = int(played.get(cid, 0)) + 1
				r = maxi(r, int(played[cid]))
	return r


static func _dur(s: int) -> String:
	return duration_text(s)


## A match length in the current language ("2 h 05 min", "2時間05分"). Falls back to the plain form where no
## translation is loaded.
static func duration_text(s: int) -> String:
	var h := s / 3600
	var m := (s % 3600) / 60
	var key := "ui.duration_hm" if h > 0 else "ui.duration_m"
	var pattern := str(TranslationServer.translate(key))
	if pattern == key:
		return "%dh %02dm" % [h, m] if h > 0 else "%d min" % m
	return pattern.format({"h": h, "m": "%02d" % m if h > 0 else str(m)})


## Separator for a list of names in an owl or a Prophet item: ", ", or "、" in Japanese and Chinese (ui.list_sep).
static func list_sep() -> String:
	var s := str(TranslationServer.translate("ui.list_sep"))
	if s == "ui.list_sep" or s.strip_edges() == "," or s.strip_edges() == "":
		return ", "
	return s
