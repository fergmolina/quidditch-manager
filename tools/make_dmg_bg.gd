extends SceneTree
## DMG window background (660×400): dark parchment, a "drag to Applications" hint and a golden arrow.
func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(660, 400)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var c := Bg.new()
	c.size = Vector2(660, 400)
	vp.add_child(c)
	for i in 12:
		await process_frame
		c.queue_redraw()
	vp.get_texture().get_image().save_png("res://export/dmg_background.png")
	quit()


class Bg extends Control:
	var f: Font
	var g: Font

	func _ready() -> void:
		f = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
		g = load("res://assets/fonts/AlegreyaSans-Medium.ttf")

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#2A1E14"))
		var t := "Quidditch Manager"
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string(f, Vector2((size.x - w) / 2.0, 62), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#D4AF37"))
		# Light cards behind each icon: Finder draws the labels in dark text (in light mode), which was unreadable on
		# the dark background; on parchment they read fine in either mode.
		for cx in [170.0, 490.0]:
			var r := Rect2(cx - 92, 116, 184, 190)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("#EFE6D0")
			sb.border_color = Color("#C9A14A")
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(14)
			draw_style_box(sb, r)
		var s := "Arrastrá el juego a la carpeta Aplicaciones  ·  Drag the game to Applications"
		var ws := g.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(g, Vector2((size.x - ws) / 2.0, 345), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#C9A14A"))
		var gold := Color("#D4AF37")
		draw_line(Vector2(272, 200), Vector2(372, 200), gold, 6.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(392, 200), Vector2(370, 186), Vector2(370, 214)]), gold)
