extends UIScreen
## Inbox (owls): list on the left, message on the right, actions with a seal.

var list: Tree
var body: VBoxContainer
var selected_id: int = -1
var filter := ""
static var _last_selected: int = -1
var _param_done := false
var _selecting := false


func build() -> void:
	header(T("ui.menu.inbox"), Game.date_text(Game.world.today))
	var cols := UI.hbox(14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var from_w := 130
	var tf := ThemeBuilder.font("table")
	var senders := {}
	for id in Inbox.list(Game.world, &"all"):
		senders[str(Inbox.view(Game.world, id, false).sender)] = true
	var sender_keys: Array = senders.keys()
	sender_keys.sort()
	for fk in sender_keys:
		from_w = maxi(from_w, int(ceil(tf.get_string_size(T(str(fk)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)) + 20)
	from_w = mini(from_w, 230)
	list = UI.table([{"title": T("ui.inbox.date"), "width": 76}, {"title": T("ui.inbox.from"), "width": from_w}, {"title": T("ui.inbox.subject"), "width": 240, "expand": true}], 400)
	list.custom_minimum_size = Vector2(520 + maxi(0, from_w - 130), 400)
	list.item_selected.connect(_on_selected)
	var lc := UI.table_card(list)
	lc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := UI.vbox(6)
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var fb := UI.hbox(6)
	var items := [["", T("ui.inbox.all")], ["unread", T("ui.inbox.unread")], ["open", T("ui.inbox.pending")]]
	for fk in sender_keys:
		items.append([fk, T(fk)])
	fb.add_child(UI.option(items, filter, func(v): filter = str(v); refresh()))
	fb.add_child(UI.button(T("ui.inbox.mark_read"), func():
		Inbox.mark_all_read(Game.world)
		Game.world_changed.emit()))
	fb.add_child(UI.button(T("ui.inbox.delete_read"), func():
		Inbox.delete_read(Game.world)
		selected_id = -1
		Game.world_changed.emit()))
	left.add_child(fb)
	left.add_child(lc)
	cols.add_child(left)
	var panel := UI.panel(16)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = UI.vbox(10)
	panel.add_child(body)
	cols.add_child(panel)


func refresh() -> void:
	if not _param_done and params.has("selected"):
		selected_id = int(params["selected"])
	elif selected_id < 0 and _last_selected >= 0:
		selected_id = _last_selected
	_param_done = true
	if Inbox.view(Game.world, selected_id, false) == null:
		selected_id = Inbox.newest_id(Game.world)
	list.clear()
	list.create_item()
	var sel_item: TreeItem = null
	for id in Inbox.list(Game.world, StringName(filter) if filter != "" else &"all", selected_id):
		var v := Inbox.view(Game.world, id, false)
		var it := UI.row(list, [Game.short_date(v.day), v.from_text, v.subject], id)
		it.set_meta("sort_keys", {0: v.day})
		if not v.read and id != selected_id:
			for i in 3:
				it.set_custom_font(i, ThemeBuilder.font("table_bold"))
		if v.open:
			it.set_custom_color(2, ThemeBuilder.SEALING_WAX)
		if id == selected_id:
			sel_item = it
	if sel_item != null:
		_selecting = true
		sel_item.select(0)
		_selecting = false
		UI.if_alive(sel_item, func(si: TreeItem): list.scroll_to_item(si)).call_deferred()
	_show_selected()


func _on_selected() -> void:
	if _selecting:
		return
	var it := list.get_selected()
	if it == null:
		return
	selected_id = int(it.get_metadata(0))
	_show_selected()
	for i in 3:
		it.set_custom_font(i, ThemeBuilder.font("table"))
	if main != null and main.has_method("_rebuild_menu"):
		main._rebuild_menu()


func _debug_read_second() -> void:
	var root_it := list.get_root()
	if root_it != null and root_it.get_child_count() > 1:
		var it := root_it.get_child(1)
		it.select(0)
		_on_selected()


func _show_selected() -> void:
	clear(body)
	var v := Inbox.view(Game.world, selected_id, true)
	if v == null:
		body.add_child(UI.label(T("ui.inbox.empty"), "ui_italic", 15, ThemeBuilder.INK_SOFT))
		return
	_last_selected = selected_id
	Inbox.mark_read(Game.world, selected_id)
	body.add_child(UI.rich_links_styled(v.subject, "title", 20))
	body.add_child(UI.text("MetaItalic", v.meta))
	body.add_child(UI.rule())
	body.add_child(UI.rich_links(v.body))
	if v.link != &"" and Game.my_club() != null:
		var target := str(v.link)
		var th := UI.hbox(8)
		th.add_child(UI.primary(T("ui.inbox.go_to") % T("ui.menu." + target), func(): go(target)))
		body.add_child(UI.gap(4))
		body.add_child(th)
	if not v.choices.is_empty():
		var h := _action_flow()
		var no := _action_flow()
		for ch in v.choices:
			var index: int = ch["index"]
			if ch["style"] == Inbox.MAIN:
				h.add_child(UI.primary(str(ch["label"]), func(): _choose(index)))
			elif ch["style"] == Inbox.BACK:
				no.add_child(UI.button(str(ch["label"]), func(): _choose(index)))
			else:
				h.add_child(UI.button(str(ch["label"]), func(): _choose(index)))
		if h.get_child_count() > 0:
			body.add_child(h)
		if no.get_child_count() > 0:
			if h.get_child_count() > 0:
				body.add_child(UI.gap(10))
			body.add_child(no)
	elif v.outcome != "":
		body.add_child(UI.gap(4))
		var ol := UI.text("MetaItalic", v.outcome)
		ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(ol)


func _action_flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


## Answers the selected owl with choice `index` and performs what the answer asks of the screen.
func _choose(index: int, confirmed: bool = false) -> void:
	var owl_id := selected_id
	var r := Inbox.choose(Game.world, Game.engine, owl_id, index, confirmed)
	if r.confirm != null:
		_confirm(r, func(): _choose(index, true))
		return
	if r.changed:
		Game.mark_dirty()
	if r.slot_switch:
		Game.save_name = Game.manual_slot()
	if r.toast != null:
		main.toast(Say.render(r.toast))
	match r.dialog:
		&"contract":
			var np: Player = Game.world.player(str(r.dialog_args["player_id"]))
			if np != null and Game.my_club() != null:
				var dlg := ContractDialog.open(self, Game.world, np, Game.my_club(), "transfer", int(r.dialog_args["fee"]), str(r.dialog_args["swap_player_id"]), int(r.dialog_args["installments"]))
				dlg.signed.connect(func(_r): Game.world_changed.emit())
			return
		&"tryouts":
			var th := str(r.dialog_args["house_id"])
			var td = TryoutsDialog.new()
			td.done.connect(func(): Game.world_changed.emit())
			td.canceled.connect(func(): Schools.snooze_tryouts(Game.world, th); Game.mark_dirty(); Game.world_changed.emit())
			td.open_for(self, Game.world, th)
			return
	if r.go != &"":
		go(str(r.go), r.go_params)
		return
	main.refresh_current()


func _confirm(r: Inbox.Reply, then: Callable) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.cancel_button_text = T("ui.cancel")
	UI.cancel_right(dlg)
	dlg.title = Say.render(r.confirm_title)
	dlg.dialog_text = Say.render(r.confirm) + ("\n" + Say.render(r.confirm_note) if r.confirm_note != null else "")
	dlg.ok_button_text = Say.render(r.confirm_title)
	dlg.confirmed.connect(func():
		dlg.queue_free()
		then.call())
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()
