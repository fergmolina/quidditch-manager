extends SceneTree
## Draws three logo proposals for the game using the project's fonts and palette and saves them as PNG.
## godot --path . -s tools/make_logo.gd -- [--out docs/logo] [--size 1400]
## A: snitch + wordmark · B: round seal with the three hoops · C: flat hoops (works as an icon)

const GOLD := Color("#D4AF37")
const BRASS := Color("#C9A14A")
const ORO_CLARO := Color("#F1D97A")
const INK := Color("#2A1E14")
const PARCHMENT := Color("#F7F1E1")
const SEALING_WAX := Color("#8E1F1C")
const GREEN := Color("#2F5A2A")
const PLATA := Color("#D9DCE2")


func _init() -> void:
	var raw := OS.get_cmdline_user_args()
	var out := "docs/logo"
	var size := 1400
	for i in raw.size():
		if raw[i] == "--out" and i + 1 < raw.size():
			out = raw[i + 1]
		if raw[i] == "--size" and i + 1 < raw.size():
			size = int(raw[i + 1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out))
	var jobs := [["A", "dark"], ["A", "light"], ["B", "dark"], ["B", "light"], ["C", "dark"], ["C", "light"], ["C", "icon"],
		["iso", "dark"], ["iso", "light"], ["iso", "clear"], ["iso", "icon"], ["A", "clear"]]
	for j in jobs:
		await _render(str(j[0]), str(j[1]), size, out)
	quit()


func _render(kind: String, bg: String, size: int, out: String) -> void:
	var w := size
	var h := size if (bg == "icon" or kind == "iso") else int(size * 0.5)
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = bg == "icon" or bg == "clear"
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var logo := Logo.new()
	logo.kind = kind
	logo.bg = bg
	logo.size = Vector2(w, h)
	vp.add_child(logo)
	for i in 4:
		await process_frame
	var img := vp.get_texture().get_image()
	var path := "res://%s/logo_%s_%s.png" % [out, kind, bg]
	img.save_png(path)
	print("saved ", path)
	vp.queue_free()


class Logo extends Control:
	var kind := "A"
	var bg := "dark"
	var f_title: FontFile
	var f_small: FontFile
	var f_gothic: FontFile

	func _ready() -> void:
		f_title = load("res://assets/fonts/IMFellEnglish-Regular.ttf")
		f_small = load("res://assets/fonts/AlegreyaSans-Bold.ttf")
		f_gothic = load("res://assets/fonts/IMFellEnglishSC-Regular.ttf")
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var dark := bg == "dark" or bg == "clear"
		if bg != "icon" and bg != "clear":
			draw_rect(Rect2(0, 0, w, h), INK if dark else PARCHMENT)
		var ink := PARCHMENT if dark else INK
		match kind:
			"iso":
				_isotype(w, h)
			"A":
				_logo_a(w, h, ink)
			"B":
				_logo_b(w, h, ink, dark)
			_:
				_logo_c(w, h, ink, dark)

	func _logo_a(w: float, h: float, ink: Color) -> void:
		var cx := w * 0.5
		_snitch(Vector2(cx, h * 0.3), h * 0.11)
		var t1 := "Quidditch"
		var s1 := int(h * 0.30)
		var sz := f_title.get_string_size(t1, HORIZONTAL_ALIGNMENT_CENTER, -1, s1)
		draw_string(f_title, Vector2(cx - sz.x / 2.0, h * 0.70), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, s1, ink)
		var t2 := "M A N A G E R"
		var s2 := int(h * 0.085)
		var sz2 := f_small.get_string_size(t2, HORIZONTAL_ALIGNMENT_CENTER, -1, s2)
		draw_string(f_small, Vector2(cx - sz2.x / 2.0, h * 0.84), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, s2, GOLD)
		var y := h * 0.815
		draw_line(Vector2(cx - sz2.x / 2.0 - w * 0.03, y), Vector2(cx - sz2.x / 2.0 - w * 0.16, y), GOLD, 2.0, true)
		draw_line(Vector2(cx + sz2.x / 2.0 + w * 0.03, y), Vector2(cx + sz2.x / 2.0 + w * 0.16, y), GOLD, 2.0, true)
		draw_circle(Vector2(cx - sz2.x / 2.0 - w * 0.165, y), 4.0, GOLD)
		draw_circle(Vector2(cx + sz2.x / 2.0 + w * 0.165, y), 4.0, GOLD)

	func _logo_b(w: float, h: float, ink: Color, dark: bool) -> void:
		var c := Vector2(w * 0.28, h * 0.5)
		var R := h * 0.42
		draw_circle(c, R, GOLD)
		draw_circle(c, R * 0.95, INK if not dark else Color("#1C140D"))
		draw_arc(c, R * 0.80, 0, TAU, 96, GOLD, 2.0, true)
		draw_arc(c, R * 0.975, 0, TAU, 96, BRASS.darkened(0.3), 2.0, true)
		draw_circle(c, R * 0.78, GREEN.darkened(0.15))
		var hoop := ORO_CLARO
		for i in 3:
			var hx := c.x + (i - 1) * R * 0.32
			var hh := R * (0.30 if i == 1 else 0.22)
			var base := c.y + R * 0.38
			draw_line(Vector2(hx, base), Vector2(hx, base - hh), hoop, R * 0.035, true)
			draw_arc(Vector2(hx, base - hh - R * 0.11), R * 0.11, 0, TAU, 40, hoop, R * 0.035, true)
		_snitch(Vector2(c.x, c.y - R * 0.42), R * 0.13)
		_ring_text(c, R * 0.835, "QUIDDITCH MANAGER", f_gothic, int(R * 0.105), GOLD, -PI / 2.0 - 1.35, 2.7)
		_ring_text(c, R * 0.835, "· 1993 ·", f_gothic, int(R * 0.10), GOLD, PI / 2.0 + 0.35, -0.7, true)
		var x := w * 0.50
		var s1 := int(h * 0.22)
		draw_string(f_title, Vector2(x, h * 0.46), "Quidditch", HORIZONTAL_ALIGNMENT_LEFT, -1, s1, ink)
		draw_string(f_title, Vector2(x, h * 0.66), "Manager", HORIZONTAL_ALIGNMENT_LEFT, -1, s1, GOLD)
		var s2 := int(h * 0.055)
		draw_string(f_small, Vector2(x + 4, h * 0.76), "LIGAS · MUNDIAL · HOGWARTS", HORIZONTAL_ALIGNMENT_LEFT, -1, s2, ink.lerp(GOLD, 0.3))

	func _logo_c(w: float, h: float, ink: Color, dark: bool) -> void:
		var icon := bg == "icon"
		var c := Vector2(w * (0.5 if icon else 0.25), h * (0.5 if icon else 0.5))
		var R := (w * 0.42) if icon else h * 0.40
		if icon:
			var rect := Rect2(c.x - R * 1.1, c.y - R * 1.1, R * 2.2, R * 2.2)
			var sb := StyleBoxFlat.new()
			sb.bg_color = INK
			sb.set_corner_radius_all(int(R * 0.45))
			draw_style_box(sb, rect)
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = Color(0, 0, 0, 0)
			sb2.border_color = GOLD
			sb2.set_border_width_all(int(R * 0.05))
			sb2.set_corner_radius_all(int(R * 0.45))
			draw_style_box(sb2, rect)
		var hoop := GOLD if (dark or icon) else INK
		for i in 3:
			var hx := c.x + (i - 1) * R * 0.5
			var hh := R * (0.95 if i == 1 else 0.6)
			var base := c.y + R * 0.75
			draw_line(Vector2(hx, base), Vector2(hx, base - hh), hoop, R * 0.06, true)
			draw_arc(Vector2(hx, base - hh - R * 0.19), R * 0.19, 0, TAU, 48, hoop, R * 0.06, true)
		_snitch(Vector2(c.x + R * 0.55, c.y - R * 0.72), R * 0.12)
		draw_line(Vector2(c.x - R * 0.9, c.y + R * 0.75), Vector2(c.x + R * 0.9, c.y + R * 0.75), hoop, R * 0.04, true)
		if icon:
			return
		var x := w * 0.48
		var s1 := int(h * 0.19)
		draw_string(f_small, Vector2(x, h * 0.44), "QUIDDITCH", HORIZONTAL_ALIGNMENT_LEFT, -1, s1, ink)
		draw_string(f_small, Vector2(x, h * 0.64), "MANAGER", HORIZONTAL_ALIGNMENT_LEFT, -1, s1, GOLD)
		var s2 := int(h * 0.05)
		draw_string(f_title, Vector2(x + 2, h * 0.75), "A Quidditch manager faithful to the books", HORIZONTAL_ALIGNMENT_LEFT, -1, s2, ink.lerp(GOLD, 0.25))

	func _isotype(w: float, h: float) -> void:
		var c := Vector2(w * 0.5, h * 0.54)
		if bg == "icon":
			var R := w * 0.46
			var rect := Rect2(c.x - R, h * 0.5 - R, R * 2.0, R * 2.0)
			var sb := StyleBoxFlat.new()
			sb.bg_color = INK
			sb.set_corner_radius_all(int(R * 0.42))
			draw_style_box(sb, rect)
			var sb2 := StyleBoxFlat.new()
			sb2.bg_color = Color(0, 0, 0, 0)
			sb2.border_color = GOLD
			sb2.set_border_width_all(int(R * 0.04))
			sb2.set_corner_radius_all(int(R * 0.42))
			draw_style_box(sb2, rect)
			_snitch(c, w * 0.085)
			return
		_snitch(c, w * 0.115)

	func _snitch(at: Vector2, r: float) -> void:
		for sgn: float in [-1.0, 1.0]:
			var wing := PackedVector2Array([at + Vector2(sgn * r * 0.6, -r * 0.1), at + Vector2(sgn * r * 1.6, -r * 1.3), at + Vector2(sgn * r * 3.4, -r * 1.6), at + Vector2(sgn * r * 3.9, -r * 0.9), at + Vector2(sgn * r * 2.6, -r * 0.2), at + Vector2(sgn * r * 1.2, r * 0.25)])
			draw_colored_polygon(wing, PLATA)
			draw_polyline(wing, PLATA.darkened(0.35), maxf(r * 0.06, 1.0), true)
			for k in 3:
				var t := 0.3 + k * 0.25
				draw_line(at + Vector2(sgn * r * 0.8, -r * 0.05), at + Vector2(sgn * r * (1.2 + 2.4 * t), -r * (0.4 + 1.1 * t)), PLATA.darkened(0.3), maxf(r * 0.05, 1.0), true)
		draw_circle(at, r, GOLD.darkened(0.25))
		draw_circle(at + Vector2(-r * 0.12, -r * 0.12), r * 0.85, GOLD)
		draw_circle(at + Vector2(-r * 0.35, -r * 0.4), r * 0.28, ORO_CLARO)
		draw_arc(at, r * 0.78, 0.3, 2.4, 24, GOLD.darkened(0.15), maxf(r * 0.08, 1.0), true)

	func _ring_text(c: Vector2, radius: float, text: String, font: Font, px: int, color: Color, start: float, span: float, inside: bool = false) -> void:
		var n := text.length()
		for i in n:
			var ch := text[i]
			var a := start + span * (i + 0.5) / n
			var r := radius if not inside else radius + px * 0.75
			var pos := c + Vector2(cos(a), sin(a)) * r
			var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			draw_set_transform(pos, a + PI / 2.0 + (PI if inside else 0.0), Vector2.ONE)
			draw_string(font, Vector2(-cw / 2.0, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
