class_name TryoutsDialog
extends AcceptDialog
## House tryouts (Schools._open_tryouts), as in the books: the house's open places, each with its candidates, by
## position, with their school year, age, ability, potential, broom and the position's key attributes. The captain's
## picks come ticked; the manager changes them and confirms (Schools.settle_tryouts). "Decide later" closes the
## dialog and leaves the owl open until the deadline, when the captain picks.
## Opened with open_for(host, world, house_id).

signal done

const KEY_ATTRS := {
	"K": ["keeping", "reflexes", "positioning", "anticipation"],
	"C": ["passing", "catching", "shooting", "dodging", "speed"],
	"B": ["beating", "beat_accuracy", "strength", "balance"],
	"S": ["eyesight", "snitch_catching", "speed", "acceleration", "agility"],
}

var w: World
var hid := ""
var _groups: Dictionary = {}
var _checked: Dictionary[String, Array] = {}
var _tables: Dictionary[String, Tree] = {}


## Builds the tryouts of house `house_id` over `host` and shows them.
func open_for(host: Node, world: World, house_id: String) -> void:
	w = world
	hid = house_id
	host.add_child(self)
	_build()
	reset_size()
	popup_centered()


func _build() -> void:
	var hd: Dictionary = w.houses.get(hid, {})
	var t: Dictionary = hd.get("tryouts", {})
	title = Game.t("ui.tryouts.title", {"house": tr("house." + str(hd.get("house", "")))})
	ok_button_text = Game.t("ui.tryouts.confirm")
	add_cancel_button(Game.t("ui.tryouts.later"))
	_groups = Schools.tryout_groups(t)
	var places := 0
	for pos in _groups.keys():
		places += int(_groups[pos]["need"])
	var v := UI.vbox(8)
	v.custom_minimum_size = Vector2(840, 0)
	var intro := UI.label(Game.t("ui.tryouts.intro", {"n": places, "date": Game.date_text(int(t.get("deadline", w.today)))}), "ui", 14, ThemeBuilder.INK)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 820
	v.add_child(intro)
	var body := UI.vbox(10)
	var rows := 0
	for pos in _groups.keys():
		var g: Dictionary = _groups[pos]
		var pool: Array[Player] = g["candidates"]
		var need := int(g["need"])
		rows += pool.size()
		body.add_child(UI.subtitle(Game.t("ui.tryouts.group", {"pos": tr("pos." + pos), "n": need, "total": pool.size()})))
		var cols := [{"title": "", "width": 30, "align": "center"}, {"title": Game.t("ui.col.name"), "width": 170, "expand": true},
			{"title": Game.t("ui.col.year"), "width": 80}, {"title": Game.t("ui.col.age"), "width": 40, "align": "right"},
			{"title": Game.t("ui.ca_stars"), "width": 76}, {"title": Game.t("ui.pa_stars"), "width": 76}, {"title": Game.t("ui.col.broom"), "width": 100}]
		var keys: Array = KEY_ATTRS[pos]
		for k in keys:
			cols.append({"title": Game.t("attr.short." + str(k)), "width": 34, "align": "center", "tooltip": Game.t("attr." + str(k))})
		var tbl := UI.table(cols, 40 + 32 * pool.size())
		for c in tbl.column_title_clicked.get_connections():
			tbl.column_title_clicked.disconnect(c["callable"])
		var ticked: Array = []
		var ranked := Schools.tryout_ranking(pool, Game.world)
		for i in mini(need, ranked.size()):
			ticked.append(ranked[i].id)
		_checked[pos] = ticked
		for q in pool:
			var bname := str(Game.loader.brooms.get(str(q.broom.get("model_id", "")), {}).get("model", "?"))
			var it := UI.row(tbl, ["", q.name(), Game.t("ui.school.year") % Schools.school_year(q, w), q.age(w.today), _stars(q.ca()), _stars(q.pa), bname], q.id)
			it.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			it.set_editable(0, true)
			it.set_checked(0, ticked.has(q.id))
			for j in keys.size():
				UI.attr_cell(it, 7 + j, float(q.attrs.get(keys[j], 0.0)))
		tbl.item_edited.connect(_on_edited.bind(pos, need))
		_tables[pos] = tbl
		body.add_child(tbl)
	var sc := UI.scroll(body)
	sc.custom_minimum_size = Vector2(820, mini(480, 60 * _groups.size() + 34 * rows + 40))
	v.add_child(sc)
	var hint := UI.label(Game.t("ui.tryouts.hint"), "ui_italic", 12, ThemeBuilder.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 820
	v.add_child(hint)
	add_child(v)
	confirmed.connect(_on_confirm)
	canceled.connect(queue_free)


func _on_edited(pos: String, need: int) -> void:
	var tbl: Tree = _tables[pos]
	var it := tbl.get_edited()
	if it == null or tbl.get_edited_column() != 0:
		return
	var id := str(it.get_metadata(0))
	var list: Array = _checked[pos]
	if it.is_checked(0):
		if not list.has(id):
			list.append(id)
		while list.size() > need:
			var drop := str(list.pop_front())
			for row in tbl.get_root().get_children():
				if str(row.get_metadata(0)) == drop:
					row.set_checked(0, false)
	else:
		list.erase(id)


func _on_confirm() -> void:
	var ids: Array = []
	for pos in _checked.keys():
		ids.append_array(_checked[pos])
	if w.houses.get(hid, {}).has("tryouts"):
		Schools.settle_tryouts(w, hid, ids, "manager")
	done.emit()
	queue_free()


func _stars(ca: float) -> String:
	var n := clampi(int(round(ca / 36.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)
