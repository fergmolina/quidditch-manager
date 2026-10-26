extends SceneTree
## Generates assets/icon.png (1024×1024): a Golden Snitch on wood. Usage: godot --headless --path . -s tools/make_icon.gd


func _init() -> void:
	var n := 1024
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var madera := Color("#2B1D14")
	var laton := Color("#C9A14A")
	var oro := Color("#E6C35C")
	var oro_osc := Color("#8C6A1E")
	var c := Vector2(n / 2.0, n / 2.0 + 20)
	for y in n:
		for x in n:
			var p := Vector2(x, y)
			var col := Color(0, 0, 0, 0)
			var r := n * 0.22
			var q := Vector2(absf(p.x - n / 2.0), absf(p.y - n / 2.0)) - Vector2(n / 2.0 - r, n / 2.0 - r)
			var d := Vector2(maxf(q.x, 0), maxf(q.y, 0)).length() + minf(maxf(q.x, q.y), 0) - r
			if d < 0.0:
				var veta := 0.022 * sin(y * 0.05 + sin(x * 0.01) * 3.0)
				col = Color(madera.r + veta, madera.g + veta * 0.7, madera.b + veta * 0.5, 1.0)
				if d > -14.0:
					col = laton
			for side: float in [-1.0, 1.0]:
				var wc := Vector2(c.x + side * 300.0, c.y - 60.0)
				var rel := p - wc
				var ang: float = side * 0.35
				var rr := Vector2(rel.x * cos(ang) - rel.y * sin(ang), rel.x * sin(ang) + rel.y * cos(ang))
				var e := pow(rr.x / 210.0, 2.0) + pow(rr.y / 48.0, 2.0)
				if e < 1.0 and d < 0.0:
					var t := clampf(1.0 - e, 0.0, 1.0)
					col = Color("#EFE4C4").lerp(laton, 0.5 - t * 0.4)
					if fmod(rr.y + rr.x * 0.15, 18.0) < 2.0:
						col = col.darkened(0.25)
			var dist := p.distance_to(c)
			if dist < 150.0:
				var nx := (p.x - c.x) / 150.0
				var ny := (p.y - c.y) / 150.0
				var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
				var light := clampf(nx * -0.4 + ny * -0.6 + nz * 0.7, 0.0, 1.0)
				col = oro_osc.lerp(oro, light)
				var spec := pow(clampf((nx * -0.5 + ny * -0.6 + nz * 0.62), 0.0, 1.0), 24.0)
				col = col.lerp(Color.WHITE, spec * 0.7)
				if absf(ny) < 0.03:
					col = col.darkened(0.3)
			elif dist < 156.0:
				col = oro_osc
			img.set_pixel(x, y, col)
	img.save_png("res://assets/icon.png")
	print("icon saved to assets/icon.png")
	quit()
