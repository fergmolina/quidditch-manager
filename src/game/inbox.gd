class_name Inbox
extends RefCounted
## The owl post: the manager's inbox (World.inbox) and the open questions the owls ask (World.decisions). This file
## is the only writer of both.
##
## tell() posts a notice: born closed, never blocks, carries nothing the game reads.
## ask() posts a question: a Decision in World.decisions keyed by the owl's id holds its choices, deadline, club scope,
## blocking flag and snooze. The domain's own facts live in world records named by the Decision's key; the owl is
## only text. The engine reads Decisions (find, open_of, blocking), never owls.
##
## Invariants:
##   I1  World.decisions holds exactly the open questions. An owl is open iff decisions.has(owl.id).
##   I2  close() is the one way a question ends. It erases the Decision and writes the owl's outcome once; later
##       closes are no-ops. Blocking ends with it, because blocking is a Decision field.
##   I3  At most one open Decision per (kind, key) when key != "". ask() on an open (kind, key) restates that owl in
##       place (text, choices, deadline, blocking; never snooze, id, day or read), so ask() is idempotent.
##   I4  The cap evicts the oldest closed owl, never an open one.
##   I5  One urgency gate: Decision.blocks(today) is blocking and today >= snooze_until.
##   I6  After load every id, day, deadline, snooze and choice index is an int (typed fields); text numbers are
##       int()-ed by Say. No other load pass exists.


# ---- question kinds: the one list. Each row: key meaning · record · who answers ------------------------------------
const BID := &"bid"                  ## key offer id · pending_offers entry, direction "in" · MarketActions
const COUNTER := &"counter"          ## key offer id · pending_offers entry, status countered · MarketActions
const TERMS := &"terms"              ## key offer id · pending_offers entry with terms · MarketActions
const LOAN_OPTION := &"loan_option"  ## key player id · p.loan.buy_option · MarketActions
const JOB := &"job"                  ## key club id · none (the open question is the outstanding offer) · GameEngine
const NT_JOB := &"nt_job"            ## key nt id · none · GameEngine
const SPONSOR := &"sponsor"          ## key club id · club.board.sponsor_offers · GameEngine
const CONTRACTS := &"contracts"      ## key "jan" | "mar" · club.board.contract_review · Contracts
const TRYOUTS := &"tryouts"          ## key house id · houses[hid].tryouts · Schools
const COMPLAINT := &"complaint"      ## key player id · the player · Happiness
const PRE_PRESS := &"pre_press"      ## key fixture id · settings.pre_press · built-in GO; GameEngine and Press close it
const LINEUP := &"lineup"            ## key fixture id · none · built-in GO; GameEngine.settle_owls closes it
const ACK := &"ack"                  ## key "" · none · built-in OK and GO only (debt, ultimatum, pre-contract lost)
const KINDS: Array[StringName] = [BID, COUNTER, TERMS, LOAN_OPTION, JOB, NT_JOB, SPONSOR, CONTRACTS, TRYOUTS, COMPLAINT, PRE_PRESS, LINEUP, ACK]
## Kinds whose questions survive the manager leaving a club. Every other kind is scoped to the club the manager runs
## when it is asked.
const UNSCOPED: Array[StringName] = [JOB, NT_JOB]

const OK := &"ok"                    ## closes the question
const GO := &"go"                    ## navigates; closes unless the choice keeps the question open

const MAIN := &"main"                ## primary button, top row
const PLAIN := &"plain"              ## plain button, top row
const BACK := &"back"                ## plain button, second row

const QUIET := 1                     ## tell(): born read, does not raise the unread count
const REPLACES_TODAY := 2            ## tell(): first drops today's closed owls with the same subject

const CAP := 300


## An inbox entry: text, the read flag and the frozen closing line. No engine state.
class Owl:
	extends RefCounted
	var id: int
	var day: int
	var sender: StringName
	var subject: Say.Phrase
	var body: Say.Phrase
	var read: bool = false
	var outcome: Say.Phrase = null
	var link: StringName = &""

	func to_dict() -> Dictionary:
		var d := {"id": id, "day": day, "sender": str(sender), "subject_key": subject.key, "body_key": body.key,
			"args": subject.to_dict()["args"], "read": read}
		if outcome != null:
			d["outcome"] = outcome.to_dict()
		if link != &"":
			d["link"] = str(link)
		return d

	static func from_dict(d: Dictionary) -> Owl:
		if not (d.get("id") is float or d.get("id") is int) or not (d.get("args", {}) is Dictionary):
			return null
		var o := Owl.new()
		o.id = int(d["id"])
		o.day = int(d.get("day", 0))
		o.sender = StringName(str(d.get("sender", "")))
		o.subject = Say.Phrase.from_dict({"key": str(d.get("subject_key", "")), "args": d.get("args", {})})
		o.body = o.subject.with_key(str(d.get("body_key", "")))
		o.read = bool(d.get("read", false))
		if d.get("outcome") is Dictionary:
			o.outcome = Say.Phrase.from_dict(d["outcome"])
		o.link = StringName(str(d.get("link", "")))
		return o


## One answer the manager can give: a verb and at most a small index, never a deal payload.
class Choice:
	extends RefCounted
	var verb: StringName
	var label: Say.Phrase
	var style: StringName = MAIN
	var arg: int = 0
	var screen: StringName = &""
	var screen_params: Dictionary = {}
	var keep: bool = false

	func _init(v: StringName = &"", label_key: String = "", label_args: Dictionary[String, Say.Arg] = {}, row: StringName = MAIN, index: int = 0) -> void:
		verb = v
		label = Say.phrase(label_key, label_args)
		style = row
		arg = index

	## Navigates to `to_screen`; `keep_open` leaves the question open (the manager still has to decide).
	static func go(label_key: String, to_screen: StringName, params: Dictionary = {}, keep_open: bool = false) -> Choice:
		var c := Choice.new(GO, label_key, {}, PLAIN)
		c.screen = to_screen
		c.screen_params = params
		c.keep = keep_open
		return c

	static func ok(label_key: String = "ui.ok") -> Choice:
		return Choice.new(OK, label_key, {}, BACK)

	func to_dict() -> Dictionary:
		var d := {"verb": str(verb), "label": label.to_dict(), "style": str(style)}
		if arg != 0:
			d["arg"] = arg
		if screen != &"":
			d["screen"] = str(screen)
			d["screen_params"] = screen_params
		if keep:
			d["keep"] = true
		return d

	static func from_dict(d: Dictionary) -> Choice:
		if not (d.get("label") is Dictionary):
			return null
		var c := Choice.new(StringName(str(d.get("verb", ""))))
		c.label = Say.Phrase.from_dict(d["label"])
		c.style = StringName(str(d.get("style", MAIN)))
		c.arg = int(d.get("arg", 0))
		c.screen = StringName(str(d.get("screen", "")))
		c.screen_params = d.get("screen_params", {}) if d.get("screen_params", {}) is Dictionary else {}
		c.keep = bool(d.get("keep", false))
		return c


## An open question. Lives in World.decisions[owl_id] while open; erased when answered, expired, superseded or scoped
## out. Domains read `kind` and `key`; only Inbox writes the rest after ask().
class Decision:
	extends RefCounted
	var kind: StringName
	var key: String
	var owl_id: int = 0
	var opened: int = 0
	var deadline: int = -1             ## last day it can be answered; sweep() closes it the day after (-1: none)
	var scope: String = ""             ## the club or house it belongs to; close_scope() closes it
	var is_blocking: bool = false      ## stops the day and routes Continue to the inbox
	var snooze_until: int = -1         ## blocks again from this day (tryouts "decide later")
	var choices: Array[Choice] = []

	func _init(k: StringName = &"", dedupe_key: String = "", answers: Array[Choice] = []) -> void:
		kind = k
		key = dedupe_key
		choices = answers

	func until(last_day: int) -> Decision:
		deadline = last_day
		return self

	func blocking(on: bool = true) -> Decision:
		is_blocking = on
		return self

	func blocks(today: int) -> bool:
		return is_blocking and today >= snooze_until

	func to_dict() -> Dictionary:
		return {"kind": str(kind), "key": key, "owl_id": owl_id, "opened": opened, "deadline": deadline, "scope": scope,
			"blocking": is_blocking, "snooze_until": snooze_until, "choices": choices.map(func(c): return c.to_dict())}

	static func from_dict(d: Dictionary) -> Decision:
		if not KINDS.has(StringName(str(d.get("kind", "")))) or not (d.get("choices", []) is Array):
			return null
		var q := Decision.new(StringName(str(d["kind"])), str(d.get("key", "")))
		q.owl_id = int(d.get("owl_id", 0))
		q.opened = int(d.get("opened", 0))
		q.deadline = int(d.get("deadline", -1))
		q.scope = str(d.get("scope", ""))
		q.is_blocking = bool(d.get("blocking", false))
		q.snooze_until = int(d.get("snooze_until", -1))
		for cd in d["choices"]:
			var c: Choice = Choice.from_dict(cd) if cd is Dictionary else null
			if c == null:
				return null
			q.choices.append(c)
		return q


## What a choice did, for choose() and the screen. Transient, never saved.
class Reply:
	extends RefCounted
	var settles: bool = true             ## close the question; the outcome defaults to "Your answer: <label>"
	var outcome: Say.Phrase = null       ## the domain's closing line, wins over the default
	var changed: bool = true             ## the world changed: the screen marks the save dirty
	var confirm: Say.Phrase = null       ## ask the manager first, then choose(..., confirmed = true)
	var confirm_title: Say.Phrase = null
	var confirm_note: Say.Phrase = null  ## a second line under the question, or null
	var go: StringName = &""
	var go_params: Dictionary = {}
	var dialog: StringName = &""         ## &"contract" | &"tryouts": the screen opens it with dialog_args
	var dialog_args: Dictionary = {}
	var toast: Say.Phrase = null
	var slot_switch: bool = false        ## accepting a job moves the career to its manual save slot

	static func done(closing: Say.Phrase = null) -> Reply:
		var r := Reply.new()
		r.outcome = closing
		return r

	## The answer did not settle the question (a passing refusal: embargo, funds, budget). The owl stays open.
	static func stay() -> Reply:
		var r := Reply.new()
		r.settles = false
		return r

	static func open_dialog(name: StringName, args: Dictionary) -> Reply:
		var r := Reply.new()
		r.settles = false
		r.changed = false
		r.dialog = name
		r.dialog_args = args
		return r

	static func ask_first(title: Say.Phrase, question: Say.Phrase, note: Say.Phrase = null) -> Reply:
		var r := Reply.new()
		r.settles = false
		r.changed = false
		r.confirm_title = title
		r.confirm = question
		r.confirm_note = note
		return r

	## The owl was closed meanwhile, or the index is out of range: nothing happens, the screen refreshes.
	static func stale() -> Reply:
		var r := Reply.new()
		r.settles = false
		r.changed = false
		return r

	## A domain got a verb it does not own: push_error (the KINDS test fails on it) and leave the owl open.
	static func unhandled(d: Decision, c: Choice) -> Reply:
		push_error("Inbox: %s does not answer %s" % [d.kind, c.verb])
		return stale()

	func with_toast(t: Say.Phrase) -> Reply:
		toast = t
		return self


## Render-ready owl for the inbox screen.
class View:
	extends RefCounted
	var id: int
	var day: int
	var sender: StringName
	var read: bool
	var open: bool
	var blocking: bool
	var from_text: String
	var subject: String                   ## BBCode when detail, plain otherwise
	var meta: String                      ## "<from> · <date>"; detail only
	var body: String                      ## BBCode; detail only
	var choices: Array[Dictionary] = []   ## [{index, label, style}]; open owls, detail only
	var outcome: String = ""              ## closing line of a closed owl; detail only
	var link: StringName = &""


# ---- producers -------------------------------------------------------------------------------------------------------

## Posts a notice. One call per owl.
static func tell(w: World, sender: StringName, subject_key: String, body_key: String, args: Dictionary[String, Say.Arg] = {}, flags: int = 0, link: StringName = &"") -> Owl:
	if flags & REPLACES_TODAY:
		w.inbox = w.inbox.filter(func(o: Owl): return w.decisions.has(o.id) or not (o.day == w.today and o.subject.key == subject_key))
	var o := _new_owl(w, sender, Say.phrase(subject_key, args), body_key)
	o.read = flags & QUIET != 0
	o.link = link
	_push(w, o)
	return o


## Asks a question. If (q.kind, q.key) is already open, restates that owl and returns its Decision (I3); otherwise
## posts an owl and stores q under its id, with q.scope set to the club the manager runs unless the kind is UNSCOPED.
static func ask(w: World, q: Decision, sender: StringName, subject_key: String, body_key: String, args: Dictionary[String, Say.Arg] = {}) -> Decision:
	var subject := Say.phrase(subject_key, args)
	var old: Decision = find(w, q.kind, q.key) if q.key != "" else null
	if old != null:
		var o := _owl(w, old.owl_id)
		o.sender = sender
		o.subject = subject
		o.body = subject.with_key(body_key)
		old.choices = q.choices
		old.deadline = q.deadline
		old.is_blocking = q.is_blocking
		return old
	var owl := _new_owl(w, sender, subject, body_key)
	q.owl_id = owl.id
	q.opened = w.today
	q.scope = "" if UNSCOPED.has(q.kind) else w.player_club_id
	w.decisions[owl.id] = q
	_push(w, owl)
	return q


# ---- the one resolve path ---------------------------------------------------------------------------------------------

## Closes a question: erases it and, if its owl has no closing line yet, writes `outcome` (null: none). Idempotent (I2).
static func close(w: World, d: Decision, outcome: Say.Phrase = null) -> void:
	if d == null or not w.decisions.has(d.owl_id):
		return
	w.decisions.erase(d.owl_id)
	var o := _owl(w, d.owl_id)
	if o != null and o.outcome == null:
		o.outcome = outcome


## The manager answers an open owl: OK and GO here, every other verb through its domain (_answer). A settling reply
## closes the question; the owl's line is the domain's outcome, else "Your answer: <label>", unless the domain already
## closed the question with its own line.
static func choose(w: World, engine: GameEngine, owl_id: int, index: int, confirmed: bool = false) -> Reply:
	var d: Decision = w.decisions.get(owl_id)
	if d == null or index < 0 or index >= d.choices.size():
		return Reply.stale()
	var c := d.choices[index]
	var r: Reply
	match c.verb:
		OK:
			r = Reply.done()
		GO:
			r = Reply.stay() if c.keep else Reply.done()
			r.changed = not c.keep
			r.go = c.screen
			r.go_params = c.screen_params
		_:
			r = _answer(w, engine, d, c, confirmed)
	if r.settles:
		close(w, d)
		var o := _owl(w, owl_id)
		if o != null and o.outcome == null:
			o.outcome = r.outcome if r.outcome != null else Say.phrase("ui.inbox.outcome", {"answer": c.label.as_arg()})
	return r


## The one routing table from kind to answering domain. A new kind is a KINDS row plus an arm here.
static func _answer(w: World, engine: GameEngine, d: Decision, c: Choice, confirmed: bool) -> Reply:
	match d.kind:
		BID, COUNTER, TERMS, LOAN_OPTION:
			return MarketActions.answer_owl(w, engine, d, c)
		JOB, NT_JOB, SPONSOR:
			return engine.answer_owl(d, c, confirmed)
		CONTRACTS:
			return Contracts.answer_owl(w, d, c)
		TRYOUTS:
			return Schools.answer_owl(w, d, c)
		COMPLAINT:
			return Happiness.answer_owl(w, engine, d, c)
	return Reply.unhandled(d, c)


# ---- queries and sweeps -----------------------------------------------------------------------------------------------

## The open question of `kind` with `key`, or null.
static func find(w: World, kind: StringName, key: String) -> Decision:
	for d in w.decisions.values():
		if d.kind == kind and d.key == key:
			return d
	return null


## Every open question of `kind`, oldest first. A snapshot: closing while iterating is safe.
static func open_of(w: World, kind: StringName) -> Array[Decision]:
	var out: Array[Decision] = []
	for d in w.decisions.values():
		if d.kind == kind:
			out.append(d)
	out.sort_custom(func(a, b): return a.owl_id < b.owl_id)
	return out


## Stops blocking until `day`, when it blocks again (I5).
static func snooze(w: World, d: Decision, day: int) -> void:
	if d != null and w.decisions.has(d.owl_id):
		d.snooze_until = day


## Daily: closes every question whose deadline has passed. Draws nothing.
static func sweep(w: World) -> void:
	for d in w.decisions.values():
		if d.deadline >= 0 and d.deadline < w.today:
			close(w, d, Say.phrase("msg.offer.outcome_expired"))


## The manager left `club_id`: closes its scoped questions without a closing line.
static func close_scope(w: World, club_id: String) -> void:
	for d in w.decisions.values():
		if d.scope == club_id and not UNSCOPED.has(d.kind):
			close(w, d)


## The newest owl whose question blocks today, or null. The day stop and Continue both read this.
static func blocking(w: World) -> Owl:
	for o in w.inbox:
		var d: Decision = w.decisions.get(o.id)
		if d != null and d.blocks(w.today):
			return o
	return null


## How many owls block today (the Continue button's "answer N owls").
static func blocking_count(w: World) -> int:
	var n := 0
	for d in w.decisions.values():
		if d.blocks(w.today):
			n += 1
	return n


## Closes every blocking question unanswered (headless --advance, the UI tour, tests).
static func close_blocking(w: World) -> void:
	var o := blocking(w)
	while o != null:
		close(w, w.decisions[o.id])
		o = blocking(w)


static func open_count(w: World) -> int:
	return w.decisions.size()


static func unread_count(w: World) -> int:
	var n := 0
	for o in w.inbox:
		if not o.read:
			n += 1
	return n


## Id of the newest owl, or -1.
static func newest_id(w: World) -> int:
	return w.inbox[0].id if not w.inbox.is_empty() else -1


# ---- screen -----------------------------------------------------------------------------------------------------------

## Everything the inbox screen shows for one owl; null if the id is gone. `detail` adds meta, body, choices and the
## closing line.
static func view(w: World, owl_id: int, detail: bool) -> View:
	var o := _owl(w, owl_id)
	if o == null:
		return null
	var d: Decision = w.decisions.get(owl_id)
	var v := View.new()
	v.id = o.id
	v.day = o.day
	v.sender = o.sender
	v.read = o.read
	v.open = d != null
	v.blocking = d != null and d.blocks(w.today)
	v.from_text = Say._tr(str(o.sender))
	v.link = o.link
	if not detail:
		v.subject = Say.render(o.subject)
		return v
	v.subject = Say.render(o.subject, true)
	v.meta = "%s · %s" % [v.from_text, Say.session.date_text(o.day)]
	v.body = Say.render(o.body, true)
	if d != null:
		for i in d.choices.size():
			v.choices.append({"index": i, "label": Say.render(d.choices[i].label), "style": d.choices[i].style})
	elif o.outcome != null:
		v.outcome = Say.render(o.outcome)
	return v


## Owl ids newest first, filtered: &"all", &"unread", &"open" or a sender key. `always` is listed whatever the filter.
static func list(w: World, filter: StringName, always: int = -1) -> Array[int]:
	var out: Array[int] = []
	for o in w.inbox:
		var keep := true
		match filter:
			&"all":
				pass
			&"unread":
				keep = not o.read
			&"open":
				keep = w.decisions.has(o.id)
			_:
				keep = o.sender == filter
		if keep or o.id == always:
			out.append(o.id)
	return out


static func mark_read(w: World, owl_id: int) -> void:
	var o := _owl(w, owl_id)
	if o != null:
		o.read = true


static func mark_all_read(w: World) -> void:
	for o in w.inbox:
		o.read = true


## Drops read, closed owls. Safe: no game state lives in an owl.
static func delete_read(w: World) -> void:
	w.inbox = w.inbox.filter(func(o: Owl): return not o.read or w.decisions.has(o.id))


# ---- persistence (World.to_dict / World.from_dict only) -----------------------------------------------------------------

static func dump(w: World) -> Dictionary:
	return {"inbox": w.inbox.map(func(o): return o.to_dict()), "decisions": w.decisions.values().map(func(d): return d.to_dict())}


## Rebuilds World.inbox and World.decisions from a save, dropping malformed entries and any decision whose owl is
## missing (it would block invisibly), each with a warning.
static func load(w: World, d: Dictionary) -> void:
	var owls: Array[Owl] = []
	var ids := {}
	for od in d.get("inbox", []):
		var o: Owl = Owl.from_dict(od) if od is Dictionary else null
		if o == null:
			push_warning("Inbox.load: dropped a malformed owl")
			continue
		owls.append(o)
		ids[o.id] = true
	w.inbox = owls
	w.decisions.clear()
	for qd in d.get("decisions", []):
		var q: Decision = Decision.from_dict(qd) if qd is Dictionary else null
		if q == null or not ids.has(q.owl_id):
			push_warning("Inbox.load: dropped a question with no owl")
			continue
		w.decisions[q.owl_id] = q


# ---- private ------------------------------------------------------------------------------------------------------------

static func _new_owl(w: World, sender: StringName, subject: Say.Phrase, body_key: String) -> Owl:
	var o := Owl.new()
	o.id = w.next_msg_id
	w.next_msg_id += 1
	o.day = w.today
	o.sender = sender
	o.subject = subject
	o.body = subject.with_key(body_key)
	return o


## push_front, then evict the oldest closed owls past CAP (I4).
static func _push(w: World, o: Owl) -> void:
	w.inbox.push_front(o)
	var i := w.inbox.size() - 1
	while w.inbox.size() > CAP and i >= 0:
		if not w.decisions.has(w.inbox[i].id):
			w.inbox.remove_at(i)
		i -= 1


static func _owl(w: World, owl_id: int) -> Owl:
	for o in w.inbox:
		if o.id == owl_id:
			return o
	return null
