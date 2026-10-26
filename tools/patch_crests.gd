extends SceneTree
## Embroidered-patch look (like the official crests of the illustrated edition) for the project's own crests:
## - assets/crests/fx/twill.png: twill weave (diagonal thread lines) multiplied over the crest.
## - assets/crests/fx/rim_<shape>.png: embroidered rim (twisted cream cord, frayed threads, shadow) per shape.
## - assets/crests/patched/<id>.png: every SVG crest of the data pack, converted (including the 13 British clubs and the
##   Hogwarts houses, so the public build has an embroidered crest even without third-party artwork).
## godot --headless --path . -s tools/patch_crests.gd

const SCALE := 2.0


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shared/crest_templates.json"))
	DirAccess.make_dir_recursive_absolute("res://assets/crests/fx")
	DirAccess.make_dir_recursive_absolute("res://assets/crests/patched")
	var size: Array = data.get("size", [128, 148])
	var w := int(size[0] * SCALE)
	var h := int(size[1] * SCALE)
	_twill(w, h).save_png("res://assets/crests/fx/twill.png")
	var shapes: Dictionary = data["shapes"]
	for sname in shapes.keys():
		var mask := _shape_mask(str(sname), str(shapes[sname]), size)
		_rim(mask).save_png("res://assets/crests/fx/rim_%s.png" % sname)
	print("layers done")
	var n := 0
	for id in data["pack_shapes"].keys():
		var path := "res://assets/crests/%s.svg" % id
		if not FileAccess.file_exists(path):
			continue
		var svg := Crest.mute_svg(FileAccess.get_file_as_string(path))
		var img := Image.new()
		if img.load_svg_from_string(svg, SCALE) != OK:
			continue
		var rim := Image.load_from_file("res://assets/crests/fx/rim_%s.png" % str(data["pack_shapes"][id]))
		Crest.apply_patch(img, Image.load_from_file("res://assets/crests/fx/twill.png"), rim)
		img.save_png("res://assets/crests/patched/%s.png" % id)
		n += 1
	print("%d crests converted" % n)
	quit()


func _shape_mask(sname: String, d: String, size: Array) -> Image:
	var body := ""
	if sname == "star8":
		body = '<polygon points="%s" fill="#FFFFFF"/>' % d
	else:
		body = '<path d="%s" fill="#FFFFFF"/>' % d
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">%s</svg>' % [size[0], size[1], size[0], size[1], body]
	var img := Image.new()
	img.load_svg_from_string(svg, SCALE)
	return img


func _twill(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in h:
		for x in w:
			var t := (x + y * 2) % 6
			var c := Color(0, 0, 0, 0)
			if t < 2:
				c = Color(0.0, 0.0, 0.0, 0.13)
			elif t == 3:
				c = Color(1.0, 0.97, 0.9, 0.08)
			var nz := rng.randf_range(-0.05, 0.05)
			if nz > 0.035:
				c = Color(1, 1, 1, 0.12)
			elif nz < -0.035:
				c = Color(0, 0, 0, 0.16)
			img.set_pixel(x, y, c)
	return img


func _rim(mask: Image) -> Image:
	var w := mask.get_width()
	var h := mask.get_height()
	var R := 22
	var dist := PackedInt32Array()
	dist.resize(w * h)
	for y in h:
		for x in w:
			dist[y * w + x] = R if mask.get_pixel(x, y).a > 0.5 else 0
	for it in R:
		var changed := false
		var nd := dist.duplicate()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var i := y * w + x
				if dist[i] <= it:
					continue
				var m := mini(mini(dist[i - 1], dist[i + 1]), mini(dist[i - w], dist[i + w])) + 1
				if m < dist[i]:
					nd[i] = m
					changed = true
		dist = nd
		if not changed:
			break
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var cream := Color("#D9C797")
	var thread_dark := Color("#6E5A34")
	for y in h:
		for x in w:
			var d := dist[y * w + x]
			var c := Color(0, 0, 0, 0)
			if d == 0:
				var sx := x - 3
				var sy := y - 5
				if sx >= 0 and sy >= 0 and mask.get_pixel(sx, sy).a > 0.5:
					c = Color(0, 0, 0, 0.28)
			elif d <= 2:
				c = Color(thread_dark, rng.randf_range(0.35, 1.0)) if rng.randf() < 0.8 else Color(cream, 0.9)
			elif d <= 13:
				var tw := 0.82 + 0.22 * sin((x + y) * 0.75 + d * 0.5)
				var vol := 1.0 - absf(d - 7.5) / 9.0
				var cc := cream * (tw * (0.82 + 0.3 * vol))
				cc.a = 1.0
				if d == 3 or d == 13:
					cc = thread_dark
				c = cc
			elif d <= 17:
				c = Color(0, 0, 0, 0.22 * (18 - d) / 4.0)
			out.set_pixel(x, y, c)
	return out
