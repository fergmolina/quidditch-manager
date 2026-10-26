extends SceneTree
## Seamless paper textures (tile invisibly): soft grain and a few fibres.
## - assets/art/paper_card.png: the card parchment (base colour CARD).
## - assets/art/paper_mesa.png: the background table (base colour DESK), slightly stronger.
## godot --headless --path . -s tools/make_paper.gd

const SIZE := 256


func _init() -> void:
	_paper(Color("#F7F1E1"), 0.022, 0.035, 11).save_png("res://assets/art/paper_card.png")
	_paper(Color("#E2D3AE"), 0.030, 0.05, 23).save_png("res://assets/art/paper_mesa.png")
	print("paper done")
	quit()


func _noise(rng: RandomNumberGenerator, g: int) -> PackedFloat32Array:
	var grid := PackedFloat32Array()
	grid.resize(g * g)
	for i in g * g:
		grid[i] = rng.randf() * 2.0 - 1.0
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	var cell := float(SIZE) / g
	for y in SIZE:
		for x in SIZE:
			var fx := x / cell
			var fy := y / cell
			var x0 := int(fx) % g
			var y0 := int(fy) % g
			var x1 := (x0 + 1) % g
			var y1 := (y0 + 1) % g
			var tx := smoothstep(0.0, 1.0, fx - floorf(fx))
			var ty := smoothstep(0.0, 1.0, fy - floorf(fy))
			var a := lerpf(grid[y0 * g + x0], grid[y0 * g + x1], tx)
			var b := lerpf(grid[y1 * g + x0], grid[y1 * g + x1], tx)
			out[y * SIZE + x] = lerpf(a, b, ty)
	return out


func _paper(base: Color, amp: float, fiber_amp: float, seed_v: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n1 := _noise(rng, 4)
	var n2 := _noise(rng, 16)
	var n3 := _noise(rng, 64)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var shade := PackedFloat32Array()
	shade.resize(SIZE * SIZE)
	for i in SIZE * SIZE:
		shade[i] = amp * (0.5 * n1[i] + 0.35 * n2[i] + 0.25 * n3[i]) + rng.randf_range(-amp, amp) * 0.35
	for k in 70:
		var x := rng.randf() * SIZE
		var y := rng.randf() * SIZE
		var ang := rng.randf() * TAU
		var length := rng.randf_range(6.0, 22.0)
		var sgn := 1.0 if rng.randf() < 0.5 else -1.0
		for t in int(length):
			var px := int(x + cos(ang) * t) % SIZE
			var py := int(y + sin(ang) * t) % SIZE
			px = (px + SIZE) % SIZE
			py = (py + SIZE) % SIZE
			shade[py * SIZE + px] += sgn * fiber_amp * (1.0 - absf(t - length / 2.0) / length)
			ang += rng.randf_range(-0.12, 0.12)
	for y in SIZE:
		for x in SIZE:
			var s := shade[y * SIZE + x]
			img.set_pixel(x, y, Color(clampf(base.r + s, 0, 1), clampf(base.g + s * 0.95, 0, 1), clampf(base.b + s * 0.85, 0, 1)))
	return img
