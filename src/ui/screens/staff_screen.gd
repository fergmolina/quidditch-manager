extends UIScreen
## Staff: who holds each role, their level, wage and contract; search candidates, hire and fire.

var body: VBoxContainer
var open_role := ""


func build() -> void:
	header(T("ui.staff.title"), Game.my_club().name)
	body = UI.vbox(10)
	root.add_child(UI.scroll(body))


func refresh() -> void:
	clear(body)
	var w := Game.world
	var club := Game.my_club()
	Staff.ensure_pool(w, Game.loader, w.rng(), club.region_id)
	body.add_child(UI.text("MetaItalic", T("ui.staff.note")))
	for role in Club.STAFF_ROLES:
		var p := UI.panel(10)
		var v := UI.vbox(6)
		var st: Dictionary = club.staff.get(role, {})
		var h := UI.hbox(10)
		var rl := UI.text("BodyMedium", T("staff." + role))
		rl.custom_minimum_size = Vector2(170, 0)
		rl.tooltip_text = T("staff." + role + ".tip")
		rl.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(rl)
		var nl := UI.text("Body", str(st.get("name", T("ui.staff.vacant"))))
		nl.custom_minimum_size = Vector2(220, 0)
		h.add_child(nl)
		h.add_child(UI.segments(club.staff_level(role), 5, ThemeBuilder.BRONZE_TEXT))
		if not st.is_empty():
			h.add_child(UI.text("Meta", "%d G / %s" % [int(st.get("wage", 0)), T("ui.week")]))
			var shown_end := Staff.contract_end_shown(Game.world, st)
			if shown_end > 0:
				h.add_child(UI.text("Meta", T("ui.until") + " " + str(WDate.year(shown_end))))
		h.add_child(UI.spacer())
		var r: String = role
		h.add_child(UI.button(T("ui.staff.search") if open_role != role else T("ui.staff.close_search"), func(): open_role = "" if open_role == r else r; refresh()))
		if not st.is_empty():
			h.add_child(UI.seal_button(T("ui.staff.fire") % Game.galleons(Staff.severance(w, club, role)), func(): _confirm_fire(r)))
		v.add_child(h)
		if open_role == role:
			var t := UI.table([{"title": T("ui.col.name"), "width": 200, "expand": true}, {"title": T("ui.staff.level"), "width": 100}, {"title": T("ui.col.age"), "width": 50, "align": "right"}, {"title": T("ui.col.wage"), "width": 70, "align": "right"}, {"title": "", "width": 150}], 44 + 32 * Staff.POOL_PER_ROLE)
			for c in Staff.candidates(w, role):
				UI.row(t, [str(c["name"]), "★".repeat(int(c["level"])) + "☆".repeat(5 - int(c["level"])), str(int(c["age"])), str(int(c["wage"])), T("ui.staff.hire_fee") % Game.galleons(int(c["wage"]) * 10)], c)
			t.item_activated.connect(func():
				var it := t.get_selected()
				if it == null:
					return
				var res := Staff.hire(w, club, it.get_metadata(0))
				main.toast(T(str(res["key"])))
				Game.world_changed.emit()
				open_role = ""
				refresh())
			v.add_child(t)
			v.add_child(UI.text("MetaItalic", T("ui.staff.hire_hint")))
		p.add_child(v)
		body.add_child(p)


func _confirm_fire(role: String) -> void:
	var w := Game.world
	var club := Game.my_club()
	var st: Dictionary = club.staff.get(role, {})
	if st.is_empty():
		return
	var dlg := ConfirmationDialog.new()
	dlg.cancel_button_text = T("ui.cancel")
	UI.cancel_right(dlg)
	dlg.title = T("staff." + role)
	dlg.dialog_text = T("ui.staff.fire_confirm", {"name": str(st.get("name", "")), "role": T("staff." + role), "cost": Game.galleons(Staff.severance(w, club, role))})
	dlg.ok_button_text = T("ui.staff.fire") % Game.galleons(Staff.severance(w, club, role))
	dlg.confirmed.connect(func():
		var res := Staff.fire(w, club, role)
		main.toast(T(str(res["key"])))
		Game.world_changed.emit()
		refresh())
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _debug_open() -> void:
	open_role = "assistant"
	refresh()

