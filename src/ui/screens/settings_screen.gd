extends UIScreen
## Settings: language, text size and density separately. Applied instantly.


func build() -> void:
	header(T("ui.menu.settings"))
	var p := UI.panel()
	p.custom_minimum_size = Vector2(0, 0)
	var v := UI.vbox(12)
	v.add_child(UI.subtitle(T("ui.settings.display")))
	_row(v, T("ui.language"), UI.option(Settings.LANGUAGES, Settings.language, func(val): Game.set_language(str(val)); main.apply_settings()))
	var scales := []
	for sc in Settings.TEXT_SCALES:
		scales.append([sc[0], sc[1]])
	_row(v, T("ui.settings.text_size"), UI.option(scales, "%.2f" % Settings.text_scale if Settings.text_scale != 1.0 and Settings.text_scale != 1.3 else ("1.0" if Settings.text_scale == 1.0 else "1.3"), func(val): Settings.text_scale = float(val); main.apply_settings()))
	_row(v, T("ui.settings.density"), UI.option([["compact", T("ui.settings.density_compact")], ["comfortable", T("ui.settings.density_comfortable")]], Settings.density, func(val): Settings.density = str(val); main.apply_settings()))
	v.add_child(UI.gap(4))
	v.add_child(UI.subtitle(T("ui.settings.audio")))
	var sfx := UI.slider(Settings.sfx_volume * 100.0, func(val): Settings.sfx_volume = val / 100.0; Settings.save_settings(); Sfx.refresh_volumes(); Sfx.play("click"), 0.0, 100.0, false)
	_row(v, T("ui.settings.sfx"), sfx)
	var mus := UI.slider(Settings.music_volume * 100.0, func(val): Settings.music_volume = val / 100.0; Settings.save_settings(); Sfx.refresh_volumes(); Sfx.music(true), 0.0, 100.0, false)
	_row(v, T("ui.settings.music"), mus)
	var tracks := []
	for tk in Settings.MUSIC_TRACKS:
		tracks.append([tk, T("music." + tk)])
	_row(v, T("ui.settings.music_track"), UI.option(tracks, Settings.music_track, func(val): Settings.music_track = str(val); Settings.save_settings(); Sfx.music(true)))
	var an := UI.text("MetaItalic", T("ui.settings.audio_note"))
	an.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(an)
	var tut := CheckBox.new()
	tut.text = T("ui.settings.tutorial")
	tut.button_pressed = Settings.tutorial
	tut.toggled.connect(func(on): Settings.tutorial = on; Settings.save_settings())
	_row(v, "", tut)
	if Game.has_game():
		v.add_child(UI.gap(4))
		v.add_child(UI.subtitle(T("ui.settings.game")))
		for pair in [["press", "ui.settings.press"], ["match_replays", "ui.settings.replays"], ["book_events", "ui.settings.book_events"], ["autosave", "ui.settings.autosave"]]:
			var cb := CheckBox.new()
			cb.text = T(pair[1])
			cb.button_pressed = bool(Game.world.settings.get(pair[0], true))
			var key: String = pair[0]
			cb.toggled.connect(func(on): Game.world.settings[key] = on; Game.mark_dirty())
			v.add_child(cb)
		var dh := UI.hbox(8)
		dh.add_child(UI.label(T("ui.settings.match_detail"), "ui", 14))
		dh.add_child(UI.option([[4, T("ui.match.detail_key")], [3, T("ui.match.detail_extended")], [1, T("ui.match.detail_full")]], int(Game.world.settings.get("match_detail", 3)), func(val): Game.world.settings["match_detail"] = int(val); Game.mark_dirty()))
		v.add_child(dh)
	var note := UI.text("MetaItalic", T("ui.settings.note"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	v.add_child(UI.gap(8))
	v.add_child(UI.subtitle(T("ui.settings.shortcuts")))
	var sc := UI.text("Body", T("ui.continue_hint") + " · F1: " + T("ui.help.button"))
	sc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sc)
	v.add_child(UI.gap(8))
	if Platform.is_web():
		v.add_child(UI.subtitle(T("ui.account.title")))
		var acc := UI.text("Body", T("ui.account.checking"))
		acc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(acc)
		var ah := UI.hbox()
		var manage := UI.button(T("ui.account.manage"), func(): Platform.open_account_page())
		manage.visible = false
		ah.add_child(manage)
		v.add_child(ah)
		Platform.fetch_viewer(func(me: Dictionary):
			if not is_instance_valid(acc):
				return
			if bool(me.get("logged_in", false)):
				acc.text = T("ui.account.signed_in") % str(me.get("username", ""))
				manage.visible = true
			else:
				acc.text = T("ui.account.offline"))
		v.add_child(UI.gap(8))
	v.add_child(UI.subtitle(T("ui.settings.about")))
	v.add_child(UI.about_box())
	p.add_child(v)
	root.add_child(p)
	if not Game.has_game():
		var bh := UI.hbox()
		bh.add_child(UI.button(T("ui.back"), func(): go("title")))
		root.add_child(bh)


func _row(v: VBoxContainer, label: String, control: Control) -> void:
	var h := UI.hbox(12)
	var l := UI.text("Body", label)
	l.custom_minimum_size = Vector2(220, 0)
	h.add_child(l)
	control.custom_minimum_size = Vector2(240, 32)
	h.add_child(control)
	h.add_child(UI.spacer())
	v.add_child(h)
