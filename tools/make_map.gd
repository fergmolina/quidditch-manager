extends SceneTree
## Converts the SVG maps from tools/make_map.py to PNG with paper grain and toasted edges (assets/art/map_*.png).
## godot --headless --path . -s tools/make_map.gd


func _init() -> void:
	var paper: Image = load("res://assets/art/paper_card.png").get_image()
	if paper.is_compressed():
		paper.decompress()
	paper.convert(Image.FORMAT_RGBA8)
	for name in ["world", "europe"]:
		var img := Image.new()
		if img.load_svg_from_string(FileAccess.get_file_as_string("res://tools/map_data/map_%s.svg" % name), 1.0) != OK:
			print("could not read ", name)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()
		var ps := paper.get_width()
		for y in h:
			for x in w:
				var c := img.get_pixel(x, y)
				var g := paper.get_pixel(x % ps, y % ps)
				var f := (g.r + g.g + g.b) / (3.0 * 0.945)
				c = Color(c.r * f, c.g * f, c.b * f, 1.0)
				var dx := minf(x, w - 1 - x) / float(w)
				var dy := minf(y, h - 1 - y) / float(h)
				var edge := clampf(minf(dx, dy) * 10.0, 0.0, 1.0)
				c = c.lerp(Color("#B08A55"), (1.0 - edge) * 0.35)
				img.set_pixel(x, y, c)
		img.save_png("res://assets/art/map_%s.png" % name)
		print("map ", name, " ", w, "x", h)
	quit()
