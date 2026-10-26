extends UIScreen
## Development tool: all canon crests in a grid.


func build() -> void:
	header("Escudos")
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for c in Game.world.clubs_sorted():
		if c.emblem_key == "" and c.source == "filler":
			continue
		var v := UI.vbox(2)
		var h := UI.hbox()
		h.add_child(UI.spacer())
		h.add_child(UI.crest(c, 72))
		h.add_child(UI.spacer())
		v.add_child(h)
		var l := UI.text("Meta", c.short_name)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size = Vector2(120, 0)
		v.add_child(l)
		grid.add_child(v)
	for hid in Game.world.houses.keys():
		var v := UI.vbox(2)
		var h := UI.hbox()
		h.add_child(UI.spacer())
		h.add_child(UI.crest(Game.team_as_club(hid), 72))
		h.add_child(UI.spacer())
		v.add_child(h)
		var l := UI.text("Meta", Game.world.team_name(hid))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(120, 0)
		v.add_child(l)
		grid.add_child(v)
	root.add_child(UI.scroll(grid))
