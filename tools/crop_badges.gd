extends SceneTree
## Crops the patches from a sheet image (for the user's personal use) into assets/crests/<club_id>.png, removing the
## paper background by flood fill from the edges. Usage: godot --headless --path . -s tools/crop_badges.gd -- <sheet.jpg>

const CROPS := {
	"club_appleby_arrows": [80, 180, 260, 275], "club_ballycastle_bats": [355, 250, 290, 290], "club_caerphilly_catapults": [665, 165, 290, 290],
	"club_chudley_cannons": [105, 525, 330, 195], "club_falmouth_falcons": [660, 535, 230, 235], "club_holyhead_harpies": [140, 775, 210, 255],
	"club_kenmare_kestrels": [560, 805, 290, 210], "club_montrose_magpies": [1125, 190, 330, 240], "club_pride_of_portree": [1590, 190, 275, 275],
	"club_puddlemere_united": [1090, 505, 230, 255], "club_tutshill_tornados": [1525, 510, 320, 220], "club_wigtown_wanderers": [1125, 765, 310, 265],
	"club_wimbourne_wasps": [1665, 775, 230, 275],
}


var figures := false
var rows := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("missing sheet image")
		quit(1)
		return
	# Generic mode: <sheet> <crops.json> <output folder>  (crops: {id: [x, y, w, h]})
	# Auto mode: <sheet> --auto <id1,id2,...> <output folder>: detects the patches on the plain background,
	# sorts them by rows (left to right, top to bottom) and assigns the ids in that order.
	var crops: Dictionary = CROPS
	var out_dir := "res://assets/crests"
	var src := Image.load_from_file(args[0])
	if src == null:
		print("could not open ", args[0])
		quit(1)
		return
	src.convert(Image.FORMAT_RGBA8)
	# Broom mode: <sheet> --rows <id1,id2,...> <folder>: brooms lying horizontally, one below another (split by rows).
	var auto_mode := args.size() >= 4 and (args[1] == "--auto" or args[1] == "--figures" or args[1] == "--rows")
	figures = args[1] == "--figures"
	rows = args[1] == "--rows"
	if auto_mode:
		var ids := args[2].split(",", false)
		out_dir = args[3]
		crops = _row_crops(src, ids) if rows else (_figure_crops(src, ids) if figures else _auto_crops(src, ids))
		if crops.size() != ids.size():
			print("WARNING: detected %d patches for %d ids" % [crops.size(), ids.size()])
	elif args.size() >= 3:
		var fa := FileAccess.open(args[1], FileAccess.READ)
		crops = JSON.parse_string(fa.get_as_text())
		out_dir = args[2]
	var paper := src.get_pixel(20, 20)
	for id in crops.keys():
		var c: Array = crops[id]
		var img := src.get_region(Rect2i(c[0], c[1], c[2], c[3]))
		_knock_out_paper(img, paper)
		if figures:
			_drop_islands(img)
		if rows:
			if img.get_width() > 560:
				img.resize(560, maxi(int(img.get_height() * 560.0 / img.get_width()), 1), Image.INTERPOLATE_LANCZOS)
			img.save_png("%s/%s.png" % [out_dir, id])
			continue
		var side := maxi(img.get_width(), img.get_height()) + 8
		var out := Image.create(side, side, false, Image.FORMAT_RGBA8)
		out.fill(Color(0, 0, 0, 0))
		out.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i((side - img.get_width()) / 2, (side - img.get_height()) / 2))
		var max_side := 440 if figures else 256
		if auto_mode and side > max_side:
			out.resize(max_side, max_side, Image.INTERPOLATE_LANCZOS)
		out.save_png("%s/%s.png" % [out_dir, id])
	print("%d crops" % crops.size())
	quit()


func _auto_crops(src: Image, ids: PackedStringArray) -> Dictionary:
	var bg := src.get_pixel(6, 6)
	var step := 4
	var w := src.get_width() / step
	var h := src.get_height() / step
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			var c := src.get_pixel(x * step, y * step)
			mask[y * w + x] = 1 if (absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)) > 0.12 else 0
	var boxes := _components(mask, w, h, Rect2i(0, 0, w, h), step)
	if boxes.size() != ids.size() and (ids.size() == 2 or ids.size() == 3):
		return _figure_crops(src, ids)
	if boxes.size() != ids.size() and ids.size() == 4:
		var sx := _gap(mask, w, h, true)
		var sy := _gap(mask, w, h, false)
		boxes = []
		for cell in [Rect2i(0, 0, sx, sy), Rect2i(sx, 0, w - sx, sy), Rect2i(0, sy, sx, h - sy), Rect2i(sx, sy, w - sx, h - sy)]:
			var bs := _components(mask, w, h, cell, step)
			bs.sort_custom(func(a, b): return a[2] * a[3] > b[2] * b[3])
			if not bs.is_empty():
				boxes.append(bs[0])
	boxes.sort_custom(func(a, b): return a[1] < b[1])
	var rows: Array = []
	for b in boxes:
		var cy: float = b[1] + b[3] / 2.0
		var placed := false
		for row in rows:
			var r0: Array = row[0]
			if absf(cy - (r0[1] + r0[3] / 2.0)) < r0[3] / 2.0:
				row.append(b)
				placed = true
				break
		if not placed:
			rows.append([b])
	var ordered: Array = []
	for row in rows:
		row.sort_custom(func(a, b): return a[0] < b[0])
		ordered.append_array(row)
	var out := {}
	for k in mini(ordered.size(), ids.size()):
		var b: Array = ordered[k]
		var m := 6
		out[ids[k]] = [maxi(b[0] - m, 0), maxi(b[1] - m, 0), mini(b[2] + 2 * m, src.get_width() - b[0] + m), mini(b[3] + 2 * m, src.get_height() - b[1] + m)]
	return out


func _figure_crops(src: Image, ids: PackedStringArray) -> Dictionary:
	var bg := src.get_pixel(6, 6)
	var step := 4
	var w := src.get_width() / step
	var h := src.get_height() / step
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			var c := src.get_pixel(x * step, y * step)
			mask[y * w + x] = 1 if (absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)) > 0.12 else 0
	var n := ids.size()
	var cuts: Array = [0]
	for k in range(1, n):
		var lo := int(w * (k - 0.3) / n)
		var hi := int(w * (k + 0.3) / n)
		var best := (lo + hi) / 2
		var best_c := 1 << 30
		for x in range(lo, hi):
			var c := 0
			for y in h:
				c += mask[y * w + x]
			if c < best_c:
				best_c = c
				best = x
		cuts.append(best)
	cuts.append(w)
	var out := {}
	for k in n:
		var cell := Rect2i(cuts[k], 0, cuts[k + 1] - cuts[k], h)
		var bs := _components(mask, w, h, cell, step)
		if bs.is_empty():
			continue
		var biggest := 0
		for b in bs:
			biggest = maxi(biggest, int(b[4]))
		var r := Rect2i()
		var first := true
		for b in bs:
			if int(b[4]) < biggest * 0.08:
				continue
			var br := Rect2i(b[0], b[1], b[2], b[3])
			r = br if first else r.merge(br)
			first = false
		r = r.grow(8).intersection(Rect2i(0, 0, src.get_width(), src.get_height()))
		out[ids[k]] = [r.position.x, r.position.y, r.size.x, r.size.y]
	return out


func _row_crops(src: Image, ids: PackedStringArray) -> Dictionary:
	var bg := src.get_pixel(6, 6)
	var step := 4
	var w := src.get_width() / step
	var h := src.get_height() / step
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			var c := src.get_pixel(x * step, y * step)
			mask[y * w + x] = 1 if (absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)) > 0.12 else 0
	var n := ids.size()
	var cuts: Array = [0]
	for k in range(1, n):
		var lo := int(h * (k - 0.3) / n)
		var hi := int(h * (k + 0.3) / n)
		var best := (lo + hi) / 2
		var best_c := 1 << 30
		for y in range(lo, hi):
			var c := 0
			for x in w:
				c += mask[y * w + x]
			if c < best_c:
				best_c = c
				best = y
		cuts.append(best)
	cuts.append(h)
	var out := {}
	for k in n:
		var y0: int = cuts[k]
		var y1: int = cuts[k + 1]
		var cols := PackedInt32Array()
		cols.resize(w)
		var rws := PackedInt32Array()
		rws.resize(y1 - y0)
		for y in range(y0, y1):
			for x in w:
				if mask[y * w + x] == 1:
					cols[x] += 1
					rws[y - y0] += 1
		var x_lo := -1
		var x_hi := -1
		for x in w:
			if cols[x] >= 2:
				x_hi = x
				if x_lo < 0:
					x_lo = x
		var r_lo := -1
		var r_hi := -1
		for y in rws.size():
			if rws[y] >= 2:
				r_hi = y
				if r_lo < 0:
					r_lo = y
		if x_lo < 0 or r_lo < 0:
			continue
		var r := Rect2i(x_lo * step, (y0 + r_lo) * step, (x_hi - x_lo + 1) * step, (r_hi - r_lo + 1) * step)
		r = r.grow(8).intersection(Rect2i(0, 0, src.get_width(), src.get_height()))
		out[ids[k]] = [r.position.x, r.position.y, r.size.x, r.size.y]
	return out


func _gap(mask: PackedByteArray, w: int, h: int, vertical: bool) -> int:
	var n := w if vertical else h
	var best := n / 2
	var best_c := 1 << 30
	for k in range(int(n * 0.35), int(n * 0.65)):
		var c := 0
		for t in (h if vertical else w):
			c += mask[t * w + k] if vertical else mask[k * w + t]
		if c < best_c:
			best_c = c
			best = k
	return best


func _components(mask: PackedByteArray, w: int, h: int, r: Rect2i, step: int) -> Array:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var boxes: Array = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * w + x
			if mask[i] == 0 or seen[i] == 1:
				continue
			var minx := x
			var maxx := x
			var miny := y
			var maxy := y
			var n := 0
			var st: Array[Vector2i] = [Vector2i(x, y)]
			seen[i] = 1
			while not st.is_empty():
				var p: Vector2i = st.pop_back()
				n += 1
				minx = mini(minx, p.x)
				maxx = maxi(maxx, p.x)
				miny = mini(miny, p.y)
				maxy = maxi(maxy, p.y)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + d
					if not r.has_point(q):
						continue
					var j := q.y * w + q.x
					if mask[j] == 1 and seen[j] == 0:
						seen[j] = 1
						st.append(q)
			if n > (w * h) / (4000 if figures else 400):
				boxes.append([minx * step, miny * step, (maxx - minx + 1) * step, (maxy - miny + 1) * step, n])
	return boxes


func _knock_out_paper(img: Image, paper: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if seen[i] == 1:
			continue
		seen[i] = 1
		var col := img.get_pixelv(p)
		var d := absf(col.r - paper.r) + absf(col.g - paper.g) + absf(col.b - paper.b)
		if d > (0.14 if figures else 0.26):
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append(p + Vector2i(1, 0))
		stack.append(p + Vector2i(-1, 0))
		stack.append(p + Vector2i(0, 1))
		stack.append(p + Vector2i(0, -1))
	if figures:
		_knock_out_enclosed(img, paper, w, h)
	var copy := img.duplicate()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if copy.get_pixel(x, y).a == 0.0:
				continue
			var edge := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if copy.get_pixel(x + d.x, y + d.y).a == 0.0:
					edge = true
			if edge:
				var c: Color = copy.get_pixel(x, y)
				c.a = 0.55
				img.set_pixel(x, y, c)


func _knock_out_enclosed(img: Image, paper: Color, w: int, h: int) -> void:
	var seen := PackedByteArray()
	seen.resize(w * h)
	for y0 in h:
		for x0 in w:
			var i0 := y0 * w + x0
			if seen[i0] == 1:
				continue
			seen[i0] = 1
			var c0 := img.get_pixel(x0, y0)
			if c0.a == 0.0 or absf(c0.r - paper.r) + absf(c0.g - paper.g) + absf(c0.b - paper.b) > 0.09:
				continue
			var region: Array[Vector2i] = []
			var st: Array[Vector2i] = [Vector2i(x0, y0)]
			while not st.is_empty():
				var p: Vector2i = st.pop_back()
				region.append(p)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var j := q.y * w + q.x
					if seen[j] == 1:
						continue
					var c := img.get_pixel(q.x, q.y)
					if c.a > 0.0 and absf(c.r - paper.r) + absf(c.g - paper.g) + absf(c.b - paper.b) <= 0.09:
						seen[j] = 1
						st.append(q)
			if region.size() >= 250:
				for p in region:
					img.set_pixelv(p, Color(0, 0, 0, 0))


func _drop_islands(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var sizes: Array[int] = []
	var pixels: Array = []
	for y0 in h:
		for x0 in w:
			var i0 := y0 * w + x0
			if label[i0] != -1 or img.get_pixel(x0, y0).a < 0.2:
				continue
			var id := sizes.size()
			var region: Array[Vector2i] = []
			var st: Array[Vector2i] = [Vector2i(x0, y0)]
			label[i0] = id
			while not st.is_empty():
				var p: Vector2i = st.pop_back()
				region.append(p)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					var q := p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
						continue
					var j := q.y * w + q.x
					if label[j] == -1 and img.get_pixel(q.x, q.y).a >= 0.2:
						label[j] = id
						st.append(q)
			sizes.append(region.size())
			pixels.append(region)
	if sizes.is_empty():
		return
	var biggest: int = sizes.max()
	for k in sizes.size():
		if sizes[k] < biggest * 0.03:
			for p in pixels[k]:
				img.set_pixelv(p, Color(0, 0, 0, 0))
