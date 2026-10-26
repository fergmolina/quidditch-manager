extends UIScreen
## Save and load games.

var name_edit: LineEdit
var list: ItemList
var msg: Label


func build() -> void:
	header(T("ui.menu.saves"))
	var p := UI.panel()
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.label(T("ui.saves.name")))
	name_edit = LineEdit.new()
	name_edit.text = Game.save_name
	v.add_child(name_edit)
	v.add_child(UI.primary(T("ui.save"), _save))
	msg = UI.label("", "ui_italic", 14, ThemeBuilder.INK_SOFT)
	v.add_child(msg)
	v.add_child(UI.rule())
	v.add_child(UI.subtitle(T("ui.saves.existing")))
	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 200)
	v.add_child(list)
	v.add_child(main.save_file_buttons(list, func(_n): refresh()))
	v.add_child(UI.button(T("ui.new_game.load_btn"), _load))
	v.add_child(UI.button(T("ui.saves.main_menu"), func(): go("new_game")))
	root.add_child(p)


func refresh() -> void:
	list.clear()
	for m in SaveManager.list_saves():
		var idx := list.add_item(Game.save_label(m))
		list.set_item_metadata(idx, m.get("dir", ""))


func _save() -> void:
	var typed := name_edit.text.strip_edges()
	if typed == "":
		msg.text = T("ui.saves.bad_name")
		return
	msg.text = T("ui.saving")
	var saved_text := T("ui.saved")
	var unconfirmed_text := T("ui.save_unconfirmed")
	var err: Error = main.save_and_confirm(typed, UI.if_alive(msg, func(ml: Label, ok: bool): ml.text = saved_text if ok else unconfirmed_text))
	if err == OK:
		name_edit.text = Game.save_name
	elif err == ERR_INVALID_PARAMETER:
		msg.text = T("ui.saves.bad_name")
	elif err == ERR_ALREADY_EXISTS:
		msg.text = T("ui.saves.other_career")
	else:
		msg.text = T("ui.save_after_match") if err == ERR_BUSY else T("ui.save_failed")
	refresh()


func _load() -> void:
	var sel := list.get_selected_items()
	if sel.is_empty():
		return
	var sname := str(list.get_item_metadata(sel[0]))
	main.confirm_unsaved(main, T("ui.saves.load_ask"), T("ui.saves.unsaved_body"), T("ui.saves.load_discard"), func(): _load_now(sname))


func _load_now(sname: String) -> void:
	if await main.run_blocking(T("ui.loading.load"), func(): return Game.load_game(sname)):
		go("inbox")
	else:
		main.toast(T("ui.saves.load_failed"), "x-circle", "error")
