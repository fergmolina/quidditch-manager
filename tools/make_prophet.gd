extends SceneTree
## Daily Prophet badge for the newspaper masthead: an ink shield with an owl and two crossed quills,
## transparent background, 512×600. Original drawing (not a copy of the film crest).
## godot --path . -s tools/make_prophet.gd   → assets/art/prophet.png

const INK := Color("#1E1712")
const PAPER := Color("#EEE8D8")
const GOLD := Color("#B8892E")


func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 600)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var c := ProphetCrest.new()
	c.size = Vector2(512, 600)
	vp.add_child(c)
	for i in 8:
		await process_frame
	vp.get_texture().get_image().save_png("res://assets/art/prophet.png")
	print("ok")
	quit()


class ProphetCrest extends Control:
	func _draw() -> void:
		var cx := 256.0
		for sgn: float in [-1.0, 1.0]:
			_quill(Vector2(cx + sgn * 225, 40), Vector2(cx - sgn * 110, 560), sgn)
		var shield := PackedVector2Array()
		var top := 120.0
		var w := 300.0
		var h := 380.0
		shield.append(Vector2(cx - w / 2, top))
		shield.append(Vector2(cx + w / 2, top))
		shield.append(Vector2(cx + w / 2, top + h * 0.5))
		for i in range(1, 21):
			var t := i / 20.0
			var a := Vector2(cx + w / 2, top + h * 0.5)
			var ctrl := Vector2(cx + w / 2, top + h * 0.85)
			var b := Vector2(cx, top + h)
			shield.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
		for i in range(1, 21):
			var t := i / 20.0
			var a := Vector2(cx, top + h)
			var ctrl := Vector2(cx - w / 2, top + h * 0.85)
			var b := Vector2(cx - w / 2, top + h * 0.5)
			shield.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
		draw_colored_polygon(shield, INK)
		var inner := PackedVector2Array()
		for p in shield:
			inner.append(Vector2(cx, top + h * 0.42) + (p - Vector2(cx, top + h * 0.42)) * 0.88)
		draw_colored_polygon(inner, PAPER)
		var inner2 := PackedVector2Array()
		for p in shield:
			inner2.append(Vector2(cx, top + h * 0.42) + (p - Vector2(cx, top + h * 0.42)) * 0.84)
		draw_polyline(inner2 + PackedVector2Array([inner2[0]]), GOLD, 3.0, true)
		var oc := Vector2(cx, 330)
		var body := PackedVector2Array()
		for i in 40:
			var a := i * TAU / 40.0
			body.append(oc + Vector2(cos(a) * 78, sin(a) * 105 + (18 if sin(a) > 0 else 0)))
		draw_colored_polygon(body, INK)
		var head := Vector2(cx, 235)
		draw_circle(head, 72, INK)
		for sgn: float in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([head + Vector2(sgn * 34, -50), head + Vector2(sgn * 70, -96), head + Vector2(sgn * 62, -36)]), INK)
			draw_circle(head + Vector2(sgn * 30, -2), 26, PAPER)
			draw_circle(head + Vector2(sgn * 30, -2), 15, GOLD)
			draw_circle(head + Vector2(sgn * 30, -2), 8, INK)
			draw_circle(head + Vector2(sgn * 26, -7), 3.5, PAPER)
			for k in 3:
				draw_arc(oc + Vector2(sgn * 38, 10 + k * 26), 34, PI * 0.5 - sgn * 0.9, PI * 0.5 + sgn * 0.9, 12, PAPER, 3.0, true)
		draw_colored_polygon(PackedVector2Array([head + Vector2(-9, 18), head + Vector2(9, 18), head + Vector2(0, 40)]), GOLD)
		for r in 3:
			for q in 3 - (r % 2):
				var x := -22 + q * 22 + (11 if r % 2 == 1 else 0)
				draw_arc(oc + Vector2(x, -10 + r * 24), 9, 0.2, PI - 0.2, 8, PAPER, 2.5, true)
		draw_line(Vector2(cx - 120, 452), Vector2(cx + 120, 452), INK, 12.0, true)
		for sgn: float in [-1.0, 1.0]:
			for k in 3:
				draw_line(Vector2(cx + sgn * 26, 430), Vector2(cx + sgn * 26 + (k - 1) * 9, 452), GOLD, 4.0, true)

	func _quill(tip: Vector2, base: Vector2, sgn: float) -> void:
		var dir := (base - tip).normalized()
		var n := Vector2(-dir.y, dir.x)
		var vane := PackedVector2Array()
		for i in 21:
			var t := i / 20.0
			var width := sin(t * PI) * 46.0
			vane.append(tip + dir * (t * 260.0) + n * width)
		for i in range(20, -1, -1):
			var t := i / 20.0
			var width := sin(t * PI) * 30.0
			vane.append(tip + dir * (t * 260.0) - n * width)
		draw_colored_polygon(vane, INK)
		draw_line(tip, base, GOLD, 4.0, true)
		for k in 6:
			var p := tip + dir * (40.0 + k * 34.0)
			draw_line(p, p + n * 30.0 + dir * 14.0, PAPER, 2.0, true)
