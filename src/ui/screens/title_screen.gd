extends UIScreen
## Title screen: background illustration, logo and four buttons (New game, Load game, Settings,
## About). With no game in memory it is the first screen of the game.


func build() -> void:
	var bg := UI.image_for("art", "title_bg")
	if bg != null:
		var tr := TextureRect.new()
		tr.texture = bg
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.show_behind_parent = true
		add_child(tr)
		move_child(tr, 0)
	var veil := ColorRect.new()
	veil.color = Color(0.09, 0.06, 0.04, 0.72)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.show_behind_parent = true
	add_child(veil)
	move_child(veil, 1)
	root.add_child(UI.spacer(false))
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var logo := UI.image_for("art", "logo")
	if logo != null:
		var lr := TextureRect.new()
		lr.texture = logo
		lr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lr.custom_minimum_size = Vector2(620, 310)
		v.add_child(lr)
	else:
		v.add_child(UI.title(T("ui.app_title")))
	v.add_child(UI.gap(6))
	var entries := [[T("ui.title.new"), func(): go("new_game")], [T("ui.title.load"), _load_dialog], [T("ui.menu.settings"), func(): go("settings")], [T("ui.title.about"), _about]]
	var saves := SaveManager.list_saves()
	if Game.has_game():
		saves = []
		entries.push_front([T("ui.title.continue"), func(): go("inbox")])
	elif not saves.is_empty():
		var newest: Dictionary = saves[0]
		entries.push_front([T("ui.title.continue"), func(): _continue_save(str(newest.get("dir", "")))])
	for i in entries.size():
		var b: Array = entries[i]
		var btn := UI.primary(str(b[0]), b[1]) if i == 0 else UI.button(str(b[0]), b[1], true)
		btn.custom_minimum_size = Vector2(320, 46)
		btn.add_theme_font_size_override("font_size", 18)
		var row := CenterContainer.new()
		row.add_child(btn)
		v.add_child(row)
		if i == 0 and not saves.is_empty():
			var which := UI.label(Game.save_label(saves[0]), "ui_italic", 13, Color(0.96, 0.93, 0.86, 0.8))
			which.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(which)
	center.add_child(v)
	root.add_child(center)
	root.add_child(UI.spacer(false))
	var foot := UI.label(T("ui.title.footer"), "ui_italic", 13, Color(0.96, 0.93, 0.86, 0.7))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(foot)


func _continue_save(dir_name: String) -> void:
	if await main.run_blocking(T("ui.loading.load"), func(): return Game.load_game(dir_name)):
		go("inbox")
	else:
		main.toast(T("ui.saves.load_failed"), "x-circle", "error")


func _load_dialog() -> void:
	var saves := SaveManager.list_saves()
	var dlg := AcceptDialog.new()
	dlg.title = T("ui.title.load")
	dlg.ok_button_text = T("ui.close")
	var v := UI.vbox(8)
	v.custom_minimum_size = Vector2(520, 0)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 240)
	for m in saves:
		var idx := list.add_item(Game.save_label(m))
		list.set_item_metadata(idx, m.get("dir", ""))
	if saves.is_empty():
		v.add_child(UI.text("MetaItalic", T("ui.saves.none")))
	else:
		list.select(0)
		v.add_child(list)
		var load_sel := func():
			var sel := list.get_selected_items()
			if sel.is_empty():
				return
			var sname := str(list.get_item_metadata(sel[0]))
			dlg.hide()
			if await main.run_blocking(T("ui.loading.load"), func(): return Game.load_game(sname)):
				dlg.queue_free()
				go("inbox")
			else:
				dlg.popup_centered()
		list.item_activated.connect(func(_i): load_sel.call())
		var bh := UI.hbox()
		bh.add_child(UI.spacer())
		bh.add_child(UI.primary(T("ui.new_game.load_btn"), load_sel))
		v.add_child(bh)
	var ih := UI.hbox()
	ih.add_child(UI.button(T("ui.saves.import"), func():
		main.import_save(func(dir_name: String):
			dlg.hide()
			if await main.run_blocking(T("ui.loading.load"), func(): return Game.load_game(dir_name)):
				dlg.queue_free()
				go("inbox")
			else:
				dlg.popup_centered())))
	if not saves.is_empty():
		ih.add_child(UI.button(T("ui.saves.export"), func():
			var sel := list.get_selected_items()
			if not sel.is_empty():
				main.export_save(str(list.get_item_metadata(sel[0])))))
	v.add_child(ih)
	if Platform.is_web():
		v.add_child(UI.text("MetaItalic", T("ui.saves.web_note")))
	dlg.add_child(v)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _about() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = T("ui.title.about")
	dlg.ok_button_text = T("ui.close")
	dlg.add_child(UI.about_box(520))
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()
