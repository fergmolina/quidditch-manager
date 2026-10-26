class_name Say
extends RefCounted
## Owner of stored text: every owl, outcome, choice label, news item and press question that is saved now and shown
## later in whatever language the player has then. Producers build values with the typed constructors below; nothing
## outside this file reads the stored form, and `render` is the only decoder.
##
## The fixture venue datum ("ground:<club>", "school:<id>", "venue.*") stays a fixture value: Say.venue carries it and
## renders it with Game.venue_text, the one venue formatter. Game.t remains for live UI strings built from values
## that are already text.
##
## Stored form (JSON-safe, so saves stay plain JSON). A phrase is {"key": String, "args": {name: packed}}, and a
## packed arg is one of:
##   int                  num       shown as is
##   String               plain     shown verbatim, never decoded
##   ["g", n]             money     separators + " G"
##   ["k", key]           key       translated (positions, objectives, houses, awards, facilities, ui keys)
##   ["t", key, {args}]   phrase    nested phrase, translated and filled in the current language
##   ["e", id, name]      entity    player, club, house or national team; name frozen at creation, linked by id
##   ["c", comp_id]       comp      the competition's display name, live
##   ["v", venue]         venue     fixture venue datum
##   ["l", [packed...]]   list      joined with the current language's list separator
##   ["$", stored_name]   sponsor   the sponsor's name in the current language
##   ["s", year]          season    "1994-95"
##   ["d", seconds]       duration  a match length in the current language
## Every numeric slot is read through int() here, so a whole float from JSON shows as the int it was and no load pass
## is needed; signature() normalises the same way, so a loaded item and a fresh one compare equal.

## The session that renders: the Game autoload, or the GameSession a headless tool or test builds. Set by
## GameSession._init.
static var session: Object = null


## One typed value for stored text. Built only by Say's constructors.
class Arg:
	extends RefCounted
	var _packed: Variant

	func _init(packed: Variant) -> void:
		_packed = packed


## A translation key with its args, frozen in packed form when built.
class Phrase:
	extends RefCounted
	var key: String
	var _args: Dictionary = {}

	## The same args under another key: an owl's body shares its subject's args.
	func with_key(other: String) -> Phrase:
		var ph := Phrase.new()
		ph.key = other
		ph._args = _args
		return ph

	## This phrase as an arg of another phrase ("Your answer: {answer}", a list item "{name} ({detail})").
	func as_arg() -> Arg:
		return Arg.new(["t", key, _args])

	## Stable identity of the text for dedupe and variant seeds: the key and the args with numbers normalised to
	## ints and dictionary keys sorted.
	func signature() -> String:
		return key + "|" + JSON.stringify(Say._norm(_args), "", true)

	func to_dict() -> Dictionary:
		return {"key": key, "args": _args}

	## Reads "key" and "args" and ignores other fields, so a news item can be passed whole. A malformed arg becomes
	## "?" with a warning, so a hand-edited save cannot crash a screen.
	static func from_dict(d: Dictionary) -> Phrase:
		var ph := Phrase.new()
		ph.key = str(d.get("key", ""))
		var a = d.get("args", {})
		if a is Dictionary:
			for k in a.keys():
				ph._args[str(k)] = Say._checked(a[k])
		return ph


static func phrase(key: String, args: Dictionary[String, Arg] = {}) -> Phrase:
	var ph := Phrase.new()
	ph.key = key
	for k in args.keys():
		ph._args[k] = args[k]._packed
	return ph


static func num(n: int) -> Arg:
	return Arg.new(n)


static func money(galleons: int) -> Arg:
	return Arg.new(["g", galleons])


## A translation key shown in the current language (pos.K, objective.title, house.gryffindor, award.x, ui.squad.free).
static func key(k: String) -> Arg:
	return Arg.new(["k", k])


static func player(p: Player) -> Arg:
	return Arg.new(["e", p.id, p.name()])


static func club(c: Club) -> Arg:
	return Arg.new(["e", c.id, c.name])


## An entity known only by id and the name it had (a player who may have retired since the list was collected).
static func entity(id: String, name: String) -> Arg:
	return Arg.new(["e", id, name])


## A club, house or national team by id, named as World.team_name names it now.
static func team(w: World, id: String) -> Arg:
	return Arg.new(["e", id, w.team_name(id)])


static func comp(comp_id: String) -> Arg:
	return Arg.new(["c", comp_id])


## A fixture's venue datum, as the fixture stores it.
static func venue(venue_datum: String) -> Arg:
	return Arg.new(["v", venue_datum])


## A list of args. Items keep their own links, so no text is ever split to find them.
static func list(items: Array) -> Arg:
	var packed: Array = []
	for it in items:
		assert(it is Arg, "Say.list takes Say values")
		packed.append(it._packed)
	return Arg.new(["l", packed])


## Text shown verbatim: the manager's own name, a broom model, a star rating, an empty slot ("").
static func plain(s: String) -> Arg:
	return Arg.new(s)


static func sponsor(stored_name: String) -> Arg:
	return Arg.new(["$", stored_name])


static func season(year: int) -> Arg:
	return Arg.new(["s", year])


static func duration(seconds: int) -> Arg:
	return Arg.new(["d", seconds])


## Stored text in the current language. One template syntax, {name}. `rich` gives BBCode for UI.rich_links: entity
## args link by id ([url=player:<id>], club:<id>, nt:<id>) and other names of the world link where they appear as
## whole words; every other "[" is escaped except [i] and [b]. `seed` >= 0 picks a text variant (key, key.v2, ...)
## without touching the world RNG.
static func render(ph: Phrase, rich: bool = false, seed: int = -1) -> String:
	var txt := _fill(_variant_key(ph.key, seed), ph._args)
	return link(txt, ph) if rich else txt


## One value as text, for a screen that shows a stored value outside a phrase (a record's competition).
static func text(a: Arg) -> String:
	return _decode(a._packed)


## BBCode for a piece of `ph`'s rendered text (a headline or a paragraph the news screen splits off): the links of
## render(ph, true) applied to that piece.
static func link(txt: String, ph: Phrase) -> String:
	var targets := {}
	_entity_targets(ph._args, targets)
	return _link_entities(txt, targets)


static func _fill(key: String, args: Dictionary) -> String:
	var s := _tr(key)
	for k in args.keys():
		s = s.replace("{%s}" % k, _decode(args[k]))
	return s


## The only place a packed arg becomes text.
static func _decode(v: Variant) -> String:
	if v is int or v is float:
		return str(int(v))
	if v is String:
		return v
	if not (v is Array) or v.is_empty():
		return "?"
	match str(v[0]):
		"g":
			return session.galleons(int(v[1]))
		"k":
			return _tr(str(v[1]))
		"t":
			return _fill(str(v[1]), v[2] if v.size() > 2 and v[2] is Dictionary else {})
		"e":
			return str(v[2])
		"c":
			return _comp_name(str(v[1]))
		"v":
			return session.venue_text({"venue": str(v[1])})
		"l":
			var parts: PackedStringArray = []
			for it in v[1]:
				parts.append(_decode(it))
			return NewsGenerator.list_sep().join(parts)
		"$":
			return session.sponsor_name(str(v[1]))
		"s":
			var y := int(v[1])
			return "%d-%02d" % [y, (y + 1) % 100]
		"d":
			return NewsGenerator.duration_text(int(v[1]))
	return "?"


const _TAG_SIZES := {"g": 2, "k": 2, "t": 3, "e": 3, "c": 2, "v": 2, "l": 2, "$": 2, "s": 2, "d": 2}


## A packed arg read from a save, or "?" if its shape is not one Say writes.
static func _checked(v: Variant) -> Variant:
	if v is int or v is float or v is String:
		return v
	if v is Array and not v.is_empty() and _TAG_SIZES.has(str(v[0])) and v.size() == int(_TAG_SIZES[str(v[0])]):
		match str(v[0]):
			"l":
				if v[1] is Array:
					return ["l", v[1].map(func(x): return _checked(x))]
			"t":
				if v[2] is Dictionary:
					var inner := {}
					for k in v[2].keys():
						inner[str(k)] = _checked(v[2][k])
					return ["t", str(v[1]), inner]
			_:
				return v
	push_warning("Say: unreadable stored value %s" % str(v))
	return "?"


static func _norm(v: Variant) -> Variant:
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Array:
		return v.map(func(x): return _norm(x))
	if v is Dictionary:
		var out := {}
		for k in v.keys():
			out[str(k)] = _norm(v[k])
		return out
	return v


static func _tr(k: String) -> String:
	return str(TranslationServer.translate(k))


static func _comp_name(id: String) -> String:
	var w: World = session.world if session != null else null
	var c: Competition = w.competitions.get(id) if w != null else null
	if c == null:
		c = Competition.new()
		c.id = id
	return c.display_name()


static var _variant_counts: Dictionary = {}


static func _variant_key(key: String, seed: int) -> String:
	if seed < 0:
		return key
	if not _variant_counts.has(key):
		var n := 1
		while _tr("%s.v%d" % [key, n + 1]) != "%s.v%d" % [key, n + 1]:
			n += 1
		_variant_counts[key] = n
	var n: int = _variant_counts[key]
	var idx: int = absi(seed) % n
	return key if idx == 0 else "%s.v%d" % [key, idx + 1]


## name -> link target for every entity arg, at any depth, whose entity is still in the world.
static func _entity_targets(args: Dictionary, targets: Dictionary) -> void:
	var stack: Array = args.values()
	while not stack.is_empty():
		var v = stack.pop_back()
		if not (v is Array) or v.is_empty():
			continue
		match str(v[0]):
			"e":
				var target := _link_target(str(v[1]))
				if target != "" and str(v[2]) != "":
					targets[str(v[2])] = target
			"l":
				stack.append_array(v[1])
			"t":
				if v[2] is Dictionary:
					stack.append_array(v[2].values())


static func _link_target(id: String) -> String:
	var w: World = session.world if session != null else null
	if w == null:
		return ""
	if w.players.has(id):
		return "player:" + id
	if w.clubs.has(id) or w.houses.has(id):
		return "club:" + id
	if w.national_teams.has(id):
		return "nt:" + id
	return ""


static var _entity_cache: Dictionary = {}
static var _entity_cache_key := ""
static var _comp_names_cache: Array = []


## `text` as BBCode: every name of the world found as a whole word becomes a link, and the names in `by_id` link to
## their own entity whatever the name scan found.
static func _link_entities(text: String, by_id: Dictionary) -> String:
	var targets := {}
	var masks: Array = []
	var w: World = session.world if session != null else null
	if w != null:
		var index := _entity_index(w)
		for name in index.keys():
			if name.length() >= 4 and text.contains(name) and _whole_word(text, name):
				targets[name] = index[name]
		if text.contains("'s") or text.contains("’s"):
			for name in index.keys():
				if name.length() < 5 or not name.ends_with("s"):
					continue
				for ap in ["'s", "’s"]:
					var variant: String = name.left(-1) + ap
					if text.contains(variant) and _whole_word(text, variant):
						targets[variant] = index[name]
	for name in by_id.keys():
		if text.contains(name):
			targets[name] = by_id[name]
	if w != null:
		for cn in _comp_names_cache:
			if text.contains(cn) and not targets.has(cn):
				masks.append(cn)
	var out := text.replace("[", "[lb]")
	for tag in ["i", "/i", "b", "/b"]:
		out = out.replace("[lb]%s]" % tag, "[%s]" % tag)
	if targets.is_empty():
		return out
	for i in masks.size():
		out = out.replace(masks[i], "\u0003%d\u0004" % i)
	var names: Array = targets.keys()
	names.sort_custom(func(a, b): return a.length() > b.length())
	for i in names.size():
		out = _replace_whole(out, names[i], "\u0001%d\u0002" % i)
	for i in names.size():
		out = out.replace("\u0001%d\u0002" % i, "[url=%s][color=#%s]%s[/color][/url]" % [targets[names[i]], ThemeBuilder.BLUE.to_html(false), names[i]])
	for i in masks.size():
		out = out.replace("\u0003%d\u0004" % i, masks[i])
	return out


static func _replace_whole(s: String, name: String, repl: String) -> String:
	var out := ""
	var from := 0
	while true:
		var i := s.find(name, from)
		if i < 0:
			break
		var j := i + name.length()
		var before := s[i - 1] if i > 0 else " "
		var after := s[j] if j < s.length() else " "
		if _is_word_char(before) or _is_word_char(after):
			out += s.substr(from, j - from)
		else:
			out += s.substr(from, i - from) + repl
		from = j
	return out + s.substr(from)


static func _whole_word(text: String, name: String) -> bool:
	var from := 0
	while true:
		var i := text.find(name, from)
		if i < 0:
			return false
		var before := text[i - 1] if i > 0 else " "
		var j := i + name.length()
		var after := text[j] if j < text.length() else " "
		if not _is_word_char(before) and not _is_word_char(after):
			return true
		from = i + 1
	return false


static func _is_word_char(c: String) -> bool:
	return c.to_upper() != c.to_lower() or c.is_valid_int()


static func _entity_index(w: World) -> Dictionary:
	var key := "%d:%d:%d:%d:%s" % [w.get_instance_id(), w.today, w.players.size(), w.clubs.size(), TranslationServer.get_locale()]
	if key == _entity_cache_key:
		return _entity_cache
	var comps := {}
	for c in w.competitions.values():
		var cn: String = c.display_name()
		if cn.length() >= 4:
			comps[cn] = true
	_comp_names_cache = comps.keys()
	_comp_names_cache.sort_custom(func(a, b): return a.length() > b.length())
	var idx := {}
	var dup := {}
	for p in w.players.values():
		var n: String = p.name()
		if idx.has(n):
			dup[n] = true
		idx[n] = "player:" + p.id
	for n in dup.keys():
		idx.erase(n)
	var shorts := {}
	for c in w.clubs.values():
		idx[c.name] = "club:" + c.id
		if c.short_name != "" and c.short_name != c.name:
			shorts[c.short_name] = ("" if shorts.has(c.short_name) else "club:" + c.id)
	for sn in shorts.keys():
		if shorts[sn] != "" and not idx.has(sn) and not dup.has(sn):
			idx[sn] = shorts[sn]
	for hid in w.houses.keys():
		idx[w.team_name(hid)] = "club:" + hid
	for ntid in w.national_teams.keys():
		idx[w.team_name(ntid)] = "nt:" + ntid
	_entity_cache = idx
	_entity_cache_key = key
	return idx
