class_name Face
extends Control
## Procedural portrait for a player without a photo, in the style of FM's generated faces: a stylised bust drawn
## in code and deterministic (seed = player id), with robes in the club colours. Features by sex, age and
## region of origin; hairstyle, glasses, beard, freckles or scar from the seed. Regens inherit it automatically.

var player: Player = null
var club: Club = null
var region_id: String = ""
var today: int = 0


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(72, 90)


func setup(p: Player, c: Club, region: String, today_day: int) -> void:
	player = p
	club = c
	region_id = region
	today = today_day
	queue_redraw()


## Skin tones by region [game].
const SKIN := {
	"light": [Color("#F6D7C3"), Color("#F1C9AE"), Color("#E9B898"), Color("#F8E0CC")],
	"medium": [Color("#D9A074"), Color("#C98A5E"), Color("#E0AC84"), Color("#B97A52")],
	"tan": [Color("#C0825A"), Color("#A86A45"), Color("#D1956C")],
	"dark": [Color("#8B5A3C"), Color("#6E4430"), Color("#5A3625"), Color("#7C4D34")],
	"east_asian": [Color("#F3D9BE"), Color("#EBC9A5"), Color("#E6BE98")],
}
const REGION_SKIN := {
	"british_isles": [["light", 8], ["medium", 1], ["dark", 1], ["east_asian", 0.3]],
	"nordic": [["light", 9], ["medium", 0.5], ["dark", 0.5]],
	"eastern_europe": [["light", 8], ["medium", 1.5]],
	"france": [["light", 6], ["medium", 2], ["dark", 1.5], ["tan", 1]],
	"germany": [["light", 8], ["medium", 1], ["dark", 0.5], ["east_asian", 0.3]],
	"iberia_lux": [["light", 5], ["medium", 4], ["tan", 1]],
	"italy": [["light", 5], ["medium", 4], ["tan", 1]],
	"low_countries": [["light", 7], ["medium", 1.5], ["dark", 1]],
	"usa": [["light", 5], ["medium", 2], ["dark", 2.5], ["east_asian", 1]],
	"canada": [["light", 6], ["medium", 1.5], ["dark", 1], ["east_asian", 1.5]],
	"argentina": [["light", 5], ["medium", 4], ["tan", 1]],
	"brazil": [["light", 3], ["medium", 3], ["tan", 2], ["dark", 3]],
	"andes": [["medium", 4], ["tan", 4], ["light", 1.5]],
	"mexico_caribbean": [["medium", 4], ["tan", 3], ["dark", 2], ["light", 1.5]],
	"africa": [["dark", 8], ["tan", 1.5]],
	"maghreb": [["medium", 4], ["tan", 4], ["light", 1], ["dark", 1]],
	"middle_east": [["medium", 5], ["tan", 3], ["light", 2]],
	"south_asia": [["tan", 5], ["medium", 3], ["dark", 2]],
	"east_asia": [["east_asian", 9], ["medium", 1]],
	"japan": [["east_asian", 9.5], ["medium", 0.5]],
	"oceania": [["light", 5], ["medium", 2], ["tan", 2], ["dark", 1]],
	"indian_ocean": [["dark", 4], ["tan", 3], ["medium", 2], ["east_asian", 1]],
}
const HAIR_DARK := [Color("#1E1410"), Color("#2B1B12"), Color("#3A2418")]
const HAIR_BROWN := [Color("#4E3220"), Color("#6B4423"), Color("#8A5A2B")]
const HAIR_LIGHT := [Color("#B8864B"), Color("#D9B26A"), Color("#E8D29A"), Color("#A0522D")]
const EYES := [Color("#4B3621"), Color("#4B3621"), Color("#3B5E8C"), Color("#4F7A4A"), Color("#6B5436"), Color("#2E2E2E")]


func _draw() -> void:
	if player == null:
		return
	var w := size.x
	var h := size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(player.id)
	var r := func(a: float, b: float) -> float: return rng.randf_range(a, b)
	var chance := func(p: float) -> bool: return rng.randf() < p
	var female := player.gender == SimPlayer.Gender.F
	var age: int = 25
	age = clampi(player.age(today if today > 0 else player.birth_day + 365 * 25), 11, 60)
	var pc := ThemeBuilder.hex(str(club.colors.get("primary", "#777777"))) if club else Color("#5B6B7A")
	var sc := ThemeBuilder.hex(str(club.colors.get("secondary", "#dddddd"))) if club else Color("#D8D2C4")
	var bg_top := pc.lerp(Color("#F4EFE0"), 0.55)
	var bg_bottom := pc.lerp(Color("#000000"), 0.25)
	for i in 12:
		var t := i / 12.0
		draw_rect(Rect2(0, h * t, w, h / 12.0 + 1), bg_top.lerp(bg_bottom, t))
	var skin := _pick_skin(rng)
	var skin_shadow := skin.darkened(0.18)
	var face_w: float = w * r.call(0.29, 0.35)
	var face_h: float = h * r.call(0.30, 0.34)
	var cx := w / 2.0
	var cy := h * 0.44
	var jaw: float = r.call(0.74, 1.02)
	var nose_w: float = r.call(0.05, 0.11)
	var hair_col := _hair_color(rng, skin, age)
	var eye_col: Color = EYES[rng.randi_range(0, EYES.size() - 1)]
	var hair_style := rng.randi_range(0, 8)
	var bald: bool = not female and age > 28 and chance.call(0.08)
	var beard: bool = not female and age >= 20 and chance.call(0.28)
	var glasses: bool = chance.call(0.14)
	var freckles: bool = skin.get_luminance() > 0.6 and chance.call(0.18)
	var scar: bool = chance.call(0.04)
	var look := player.look
	if not look.is_empty():
		if look.has("skin"):
			skin = _skin_from(str(look["skin"]), rng)
			skin_shadow = skin.darkened(0.18)
		if look.has("hair"):
			hair_col = _hair_from(str(look["hair"]))
			if age >= 33 and not look.has("no_grey"):
				hair_col = hair_col.lerp(Color("#B8B8B8"), clampf((age - 32) / 14.0, 0.0, 0.85))
		if look.has("hair_style"):
			hair_style = _style_from(look["hair_style"])
		if look.has("eyes"):
			eye_col = _eyes_from(str(look["eyes"]))
		if look.has("glasses"):
			glasses = bool(look["glasses"])
		if look.has("beard"):
			beard = bool(look["beard"])
		if look.has("freckles"):
			freckles = bool(look["freckles"])
		if look.has("bald"):
			bald = bool(look["bald"])
		if look.has("scar"):
			scar = typeof(look["scar"]) == TYPE_BOOL and bool(look["scar"])
	var lightning: bool = str(look.get("scar", "")) == "lightning"
	var brow_thick: float = r.call(1.2, 2.6)
	if look.has("brows"):
		brow_thick = 3.2 if str(look["brows"]) == "thick" else 1.2
	var eye_dx: float = face_w * r.call(0.36, 0.44)
	var eye_y: float = cy - face_h * 0.08
	var eye_r: float = face_w * r.call(0.085, 0.105)
	var nose_len: float = face_h * r.call(0.16, 0.24)
	var mouth_w: float = face_w * r.call(0.32, 0.46)
	var smile: float = r.call(-0.3, 1.2)
	var shoulder_y := cy + face_h * 0.95
	var robe := PackedVector2Array([Vector2(cx - w * 0.48, h), Vector2(cx - w * 0.42, shoulder_y + h * 0.06), Vector2(cx - w * 0.18, shoulder_y), Vector2(cx + w * 0.18, shoulder_y), Vector2(cx + w * 0.42, shoulder_y + h * 0.06), Vector2(cx + w * 0.48, h)])
	draw_colored_polygon(robe, pc)
	draw_rect(Rect2(cx - face_w * 0.28, shoulder_y - face_h * 0.25, face_w * 0.56, face_h * 0.3), skin_shadow)
	var collar := PackedVector2Array([Vector2(cx - w * 0.2, shoulder_y), Vector2(cx, shoulder_y + h * 0.12), Vector2(cx + w * 0.2, shoulder_y)])
	draw_colored_polygon(collar, sc)
	draw_polyline(PackedVector2Array([Vector2(cx - w * 0.2, shoulder_y), Vector2(cx, shoulder_y + h * 0.12), Vector2(cx + w * 0.2, shoulder_y)]), pc.darkened(0.3), 1.2, true)
	var long_hair: bool = (female and (hair_style == 5 or hair_style == 3 or hair_style == 2 or hair_style == 8)) or bool(look.get("long_hair", false))
	if long_hair and not bald:
		var back := PackedVector2Array()
		for i in 24:
			var a := PI + i * PI / 23.0
			back.append(Vector2(cx + cos(a) * face_w * 1.15, cy - face_h * 0.15 + sin(a) * face_h * 1.1))
		back.append(Vector2(cx + face_w * 1.1, shoulder_y + h * 0.05))
		back.append(Vector2(cx - face_w * 1.1, shoulder_y + h * 0.05))
		draw_colored_polygon(back, hair_col)
	draw_circle(Vector2(cx - face_w, cy + face_h * 0.05), face_w * 0.16, skin_shadow)
	draw_circle(Vector2(cx + face_w, cy + face_h * 0.05), face_w * 0.16, skin_shadow)
	if female and chance.call(0.5):
		draw_circle(Vector2(cx - face_w, cy + face_h * 0.2), 1.6, sc.lerp(Color("#E8C547"), 0.5))
		draw_circle(Vector2(cx + face_w, cy + face_h * 0.2), 1.6, sc.lerp(Color("#E8C547"), 0.5))
	var face := PackedVector2Array()
	for i in 40:
		var a := i * TAU / 40.0
		var rx := face_w
		var ry := face_h
		var y := sin(a)
		if y > 0.0:
			rx *= lerpf(1.0, jaw, y)
		face.append(Vector2(cx + cos(a) * rx, cy + y * ry))
	draw_colored_polygon(face, skin)
	draw_circle(Vector2(cx - eye_dx, cy + face_h * 0.28), face_w * 0.14, skin.lightened(0.06))
	draw_circle(Vector2(cx + eye_dx, cy + face_h * 0.28), face_w * 0.14, skin.lightened(0.06))
	if freckles:
		for i in 14:
			draw_circle(Vector2(cx + r.call(-0.55, 0.55) * face_w, cy + face_h * r.call(0.1, 0.4)), 0.9, skin_shadow.darkened(0.2))
	for sgn: float in [-1.0, 1.0]:
		var ex := cx + sgn * eye_dx
		draw_circle(Vector2(ex, eye_y), eye_r * 1.25, Color("#F7F3EA"))
		draw_circle(Vector2(ex + sgn * eye_r * 0.1, eye_y), eye_r * 0.8, eye_col)
		draw_circle(Vector2(ex + sgn * eye_r * 0.1, eye_y), eye_r * 0.42, Color("#111111"))
		draw_circle(Vector2(ex + sgn * eye_r * 0.1 - eye_r * 0.25, eye_y - eye_r * 0.3), eye_r * 0.16, Color("#FFFFFF"))
		draw_arc(Vector2(ex, eye_y), eye_r * 1.25, PI + 0.25, TAU - 0.25, 10, skin_shadow, 1.2, true)
		var by := eye_y - eye_r * 2.2
		var brow := PackedVector2Array()
		for i in 7:
			var t := i / 6.0
			brow.append(Vector2(ex - eye_r * 1.3 + eye_r * 2.6 * t, by - sin(t * PI) * eye_r * 0.45 + (t - 0.5) * sgn * eye_r * 0.25))
		draw_polyline(brow, hair_col.darkened(0.2), brow_thick, true)
	var nose_top := Vector2(cx, eye_y + eye_r * 0.6)
	var nose_tip := Vector2(cx + face_w * nose_w * 0.6, nose_top.y + nose_len)
	draw_line(nose_top, nose_tip, skin_shadow, 1.4, true)
	draw_line(nose_tip, Vector2(cx - face_w * nose_w, nose_tip.y - nose_len * 0.1), skin_shadow, 1.4, true)
	draw_arc(Vector2(cx + face_w * nose_w * 0.9, nose_tip.y - nose_len * 0.12), face_w * nose_w * 0.45, 0.2, PI - 0.4, 6, skin_shadow, 1.1, true)
	var my := nose_tip.y + face_h * 0.22
	var mouth := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		var x := cx - mouth_w / 2.0 + mouth_w * t
		var yy := my + smile * 2.4 * sin(t * PI)
		mouth.append(Vector2(x, yy))
	var lip := Color("#A14E4E") if female else skin_shadow.darkened(0.25)
	draw_polyline(mouth, lip, 1.8 if female else 1.4, true)
	if beard:
		var bpts := PackedVector2Array()
		for i in 22:
			var a := i * PI / 21.0
			var rx := face_w * lerpf(1.0, jaw, sin(a)) * 1.03
			bpts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * face_h * 1.04))
		bpts.append(Vector2(cx + face_w * 0.78, my + face_h * 0.06))
		bpts.append(Vector2(cx, my + face_h * 0.12))
		bpts.append(Vector2(cx - face_w * 0.78, my + face_h * 0.06))
		draw_colored_polygon(bpts, Color(hair_col, 0.8))
		if chance.call(0.6):
			draw_line(Vector2(cx - mouth_w * 0.55, my - face_h * 0.07), Vector2(cx + mouth_w * 0.55, my - face_h * 0.07), Color(hair_col, 0.85), 2.2, true)
	if not bald:
		_draw_hair(hair_style, female, cx, cy, face_w, face_h, hair_col, rng)
	else:
		draw_arc(Vector2(cx, cy - face_h * 0.2), face_w * 0.98, PI + 0.5, TAU - 0.5, 16, hair_col.lightened(0.2), 2.0, true)
	if glasses:
		var gc := Color("#2A2A2A") if (chance.call(0.7) or look.has("glasses")) else Color("#B08D57")
		for sgn: float in [-1.0, 1.0]:
			draw_arc(Vector2(cx + sgn * eye_dx, eye_y), eye_r * 1.75, 0, TAU, 20, gc, 1.3, true)
		draw_line(Vector2(cx - eye_dx + eye_r * 1.75, eye_y), Vector2(cx + eye_dx - eye_r * 1.75, eye_y), gc, 1.2, true)
	if lightning:
		var fx := cx + face_w * 0.05
		var fy := eye_y - eye_r * 4.6
		var zig := PackedVector2Array([Vector2(fx, fy), Vector2(fx + face_w * 0.12, fy + face_h * 0.06), Vector2(fx + face_w * 0.02, fy + face_h * 0.1), Vector2(fx + face_w * 0.14, fy + face_h * 0.17)])
		draw_polyline(zig, Color("#9E4A3A"), 1.5, true)
	elif scar:
		var sx := cx + (-1.0 if chance.call(0.5) else 1.0) * face_w * 0.45
		draw_line(Vector2(sx, eye_y - eye_r * 3.2), Vector2(sx + face_w * 0.1, eye_y - eye_r * 1.2), skin_shadow.darkened(0.35), 1.3, true)
	draw_rect(Rect2(0.5, 0.5, w - 1, h - 1), ThemeBuilder.INK.lerp(pc, 0.3), false, 1.5)


func _skin_from(key: String, rng: RandomNumberGenerator) -> Color:
	if key.begins_with("#"):
		return Color(key)
	var pal: Array = SKIN.get(key, SKIN["light"])
	return pal[rng.randi_range(0, pal.size() - 1)]


func _hair_from(key: String) -> Color:
	match key:
		"black": return Color("#1E1410")
		"dark_brown": return Color("#3A2418")
		"brown": return Color("#6B4423")
		"light_brown": return Color("#8A5A2B")
		"red": return Color("#B7472A")
		"auburn": return Color("#8C3B1E")
		"blond": return Color("#D9B26A")
		"platinum": return Color("#EDE3C4")
		"grey": return Color("#A8A8A8")
		"white": return Color("#E6E6E6")
	return Color(key) if key.begins_with("#") else Color("#3A2418")


func _eyes_from(key: String) -> Color:
	match key:
		"green": return Color("#3F8A4A")
		"blue": return Color("#3B5E8C")
		"brown": return Color("#4B3621")
		"hazel": return Color("#6B5436")
		"grey": return Color("#7A8390")
		"dark": return Color("#2E2E2E")
	return Color(key) if key.begins_with("#") else Color("#4B3621")


func _style_from(v: Variant) -> int:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	match str(v):
		"short": return 0
		"buzz": return 1
		"side": return 2
		"curly": return 3
		"back": return 4
		"long": return 5
		"messy": return 6
		"bowl": return 7
		"wavy": return 8
	return 0


func _pick_skin(rng: RandomNumberGenerator) -> Color:
	var weights: Array = REGION_SKIN.get(region_id, [["light", 5], ["medium", 3], ["tan", 1], ["dark", 1], ["east_asian", 1]])
	var total := 0.0
	for wgt in weights:
		total += float(wgt[1])
	var x := rng.randf() * total
	var group := "light"
	for wgt in weights:
		x -= float(wgt[1])
		if x <= 0.0:
			group = str(wgt[0])
			break
	var pal: Array = SKIN[group]
	return pal[rng.randi_range(0, pal.size() - 1)]


## Hair colour weights by region [game]: [black, brown, light/blond or red].
const REGION_HAIR := {
	"nordic": [1.0, 3.0, 6.0], "british_isles": [2.0, 5.0, 3.0], "germany": [2.0, 5.0, 3.0], "low_countries": [2.0, 5.0, 3.0],
	"eastern_europe": [3.0, 5.0, 2.0], "france": [3.0, 5.0, 2.0], "usa": [3.0, 4.0, 3.0], "canada": [3.0, 4.0, 3.0], "oceania": [3.0, 4.0, 3.0],
	"iberia_lux": [5.0, 4.0, 1.0], "italy": [5.0, 4.0, 1.0], "argentina": [5.0, 4.0, 1.0], "brazil": [6.0, 3.0, 1.0],
	"andes": [8.0, 2.0, 0.2], "mexico_caribbean": [7.0, 2.5, 0.5], "africa": [9.0, 1.0, 0.1], "indian_ocean": [8.0, 1.5, 0.2],
	"maghreb": [7.0, 2.5, 0.3], "middle_east": [7.0, 2.5, 0.3], "south_asia": [9.0, 1.0, 0.1], "japan": [9.5, 0.5, 0.05], "east_asia": [9.5, 0.5, 0.05],
}


func _hair_color(rng: RandomNumberGenerator, skin: Color, age: int) -> Color:
	var wts: Array = REGION_HAIR.get(region_id, [4.0, 4.0, 2.0])
	if skin.get_luminance() < 0.5:
		wts = [9.0, 1.0, 0.1]
	var total: float = float(wts[0]) + float(wts[1]) + float(wts[2])
	var x := rng.randf() * total
	var col: Color
	if x < float(wts[0]):
		col = HAIR_DARK[rng.randi_range(0, 2)]
	elif x < float(wts[0]) + float(wts[1]):
		col = HAIR_BROWN[rng.randi_range(0, 2)]
	else:
		col = HAIR_LIGHT[rng.randi_range(0, 3)]
	if age >= 33:
		col = col.lerp(Color("#B8B8B8"), clampf((age - 32) / 14.0, 0.0, 0.85))
	return col


func _draw_hair(style: int, female: bool, cx: float, cy: float, fw: float, fh: float, col: Color, rng: RandomNumberGenerator) -> void:
	var hairline := cy - fh * 0.42
	var pts := PackedVector2Array()
	for i in 25:
		var a := PI + i * PI / 24.0
		pts.append(Vector2(cx + cos(a) * fw * 1.08, cy - fh * 0.08 + sin(a) * fh * 1.08))
	match style:
		0:
			pts.append(Vector2(cx + fw * 1.0, cy - fh * 0.2))
			pts.append(Vector2(cx + fw * 0.85, hairline))
			pts.append(Vector2(cx - fw * 0.85, hairline))
			pts.append(Vector2(cx - fw * 1.0, cy - fh * 0.2))
		1:
			pts.append(Vector2(cx + fw * 1.0, cy - fh * 0.3))
			pts.append(Vector2(cx + fw * 0.8, hairline - fh * 0.12))
			pts.append(Vector2(cx - fw * 0.8, hairline - fh * 0.12))
			pts.append(Vector2(cx - fw * 1.0, cy - fh * 0.3))
		2:
			pts.append(Vector2(cx + fw * 1.0, cy - fh * 0.15))
			pts.append(Vector2(cx + fw * 0.6, hairline - fh * 0.1))
			pts.append(Vector2(cx - fw * 0.2, hairline + fh * 0.08))
			pts.append(Vector2(cx - fw * 0.9, hairline - fh * 0.05))
			pts.append(Vector2(cx - fw * 1.0, cy - fh * 0.15))
		3:
			pts.clear()
			for i in 25:
				var a := PI + i * PI / 24.0
				var bump := 1.0 + 0.06 * (1.0 if i % 2 == 0 else -1.0)
				pts.append(Vector2(cx + cos(a) * fw * 1.14 * bump, cy - fh * 0.05 + sin(a) * fh * 1.2 * bump))
			pts.append(Vector2(cx + fw * 1.05, cy - fh * 0.1))
			pts.append(Vector2(cx + fw * 0.7, hairline + fh * 0.02))
			pts.append(Vector2(cx, hairline - fh * 0.04))
			pts.append(Vector2(cx - fw * 0.7, hairline + fh * 0.02))
			pts.append(Vector2(cx - fw * 1.05, cy - fh * 0.1))
		4:
			pts.append(Vector2(cx + fw * 1.0, cy - fh * 0.25))
			pts.append(Vector2(cx + fw * 0.75, hairline - fh * 0.06))
			pts.append(Vector2(cx, hairline - fh * 0.14))
			pts.append(Vector2(cx - fw * 0.75, hairline - fh * 0.06))
			pts.append(Vector2(cx - fw * 1.0, cy - fh * 0.25))
		6:
			pts.clear()
			for i in 25:
				var a := PI + i * PI / 24.0
				var spike := 1.0 + (0.14 if i % 3 == 0 else 0.0)
				pts.append(Vector2(cx + cos(a) * fw * 1.08 * spike, cy - fh * 0.08 + sin(a) * fh * 1.1 * spike))
			pts.append(Vector2(cx + fw * 1.0, cy - fh * 0.15))
			pts.append(Vector2(cx + fw * 0.7, hairline - fh * 0.04))
			pts.append(Vector2(cx + fw * 0.35, hairline + fh * 0.1))
			pts.append(Vector2(cx, hairline - fh * 0.02))
			pts.append(Vector2(cx - fw * 0.4, hairline + fh * 0.12))
			pts.append(Vector2(cx - fw * 0.75, hairline - fh * 0.03))
			pts.append(Vector2(cx - fw * 1.0, cy - fh * 0.15))
		7:
			pts.append(Vector2(cx + fw * 1.0, cy - fh * 0.05))
			pts.append(Vector2(cx + fw * 0.9, hairline + fh * 0.1))
			pts.append(Vector2(cx - fw * 0.9, hairline + fh * 0.1))
			pts.append(Vector2(cx - fw * 1.0, cy - fh * 0.05))
		8:
			pts.clear()
			for i in 25:
				var a := PI + i * PI / 24.0
				var wave := 1.0 + 0.05 * sin(i * 1.7)
				pts.append(Vector2(cx + cos(a) * fw * 1.16 * wave, cy + fh * 0.02 + sin(a) * fh * 1.12 * wave))
			pts.append(Vector2(cx + fw * 1.12, cy + fh * 0.3))
			pts.append(Vector2(cx + fw * 0.95, cy - fh * 0.05))
			pts.append(Vector2(cx + fw * 0.55, hairline + fh * 0.03))
			pts.append(Vector2(cx, hairline - fh * 0.06))
			pts.append(Vector2(cx - fw * 0.55, hairline + fh * 0.03))
			pts.append(Vector2(cx - fw * 0.95, cy - fh * 0.05))
			pts.append(Vector2(cx - fw * 1.12, cy + fh * 0.3))
		_:
			pts.append(Vector2(cx + fw * 1.1, cy + fh * 0.15))
			pts.append(Vector2(cx + fw * 0.95, cy - fh * 0.1))
			pts.append(Vector2(cx + fw * 0.7, hairline + fh * 0.05))
			pts.append(Vector2(cx - fw * 0.7, hairline + fh * 0.05))
			pts.append(Vector2(cx - fw * 0.95, cy - fh * 0.1))
			pts.append(Vector2(cx - fw * 1.1, cy + fh * 0.15))
	draw_colored_polygon(pts, col)
	if style == 4 and female:
		draw_circle(Vector2(cx, cy - fh * 1.12), fw * 0.3, col)
	draw_arc(Vector2(cx, cy - fh * 0.1), fw * 0.9, PI + 0.55, PI + 1.25, 8, col.lightened(0.25), 1.6, true)
