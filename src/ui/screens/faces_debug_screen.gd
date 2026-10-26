extends UIScreen
## Development tool: grid of procedural portraits from several clubs to calibrate Face.


func build() -> void:
	header("Caras")
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var w := Game.world
	var canon_ids := ["student_harry_potter", "student_ron_weasley", "student_ginny_weasley", "student_fred_weasley", "student_oliver_wood", "student_angelina_johnson", "student_cedric_diggory", "student_cho_chang", "student_draco_malfoy", "student_marcus_flint"]
	for pid in canon_ids:
		var p: Player = w.player(pid)
		if p == null:
			continue
		var v := UI.vbox(2)
		var h := UI.hbox()
		h.add_child(UI.spacer())
		h.add_child(UI.portrait(p, Game.team_as_club(Schools.house_id("school_hogwarts", p.house)) if p.house != "" else null, 96))
		h.add_child(UI.spacer())
		v.add_child(h)
		var l := UI.text("Meta", "%s %d" % [p.last_name, p.age(w.today)])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(110, 0)
		v.add_child(l)
		grid.add_child(v)
	var clubs := ["club_puddlemere_united", "club_holyhead_harpies", "club_africa_league_1", "club_toyohashi_tengu", "club_brazil_league_1", "club_nordic_league_1", "club_andes_league_1", "club_eastern_europe_league_1"]
	for cid in clubs:
		if not w.clubs.has(cid):
			continue
		var n := 0
		for p in w.squad_of(cid):
			if n >= 5:
				break
			var v := UI.vbox(2)
			var h := UI.hbox()
			h.add_child(UI.spacer())
			h.add_child(UI.portrait(p, w.clubs[cid], 96))
			h.add_child(UI.spacer())
			v.add_child(h)
			var l := UI.text("Meta", "%s %d" % [p.last_name, p.age(w.today)])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.custom_minimum_size = Vector2(110, 0)
			v.add_child(l)
			grid.add_child(v)
			n += 1
	root.add_child(UI.scroll(grid))
