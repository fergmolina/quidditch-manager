class_name Stands
extends Control
## 2D stands [game]: a ring around the oval with sections separated by aisles, rows of seats with the
## crowd seated in rows (home colours, with an away section), a middle walkway in the large stands,
## a shaded edge and pennants of both clubs. Drawn only once (changes only with size, capacity or
## attendance); the match is drawn on top in Pitch2D.

var capacity := 20000
var fill := 0.7
var home_col := Color("#1F3A6B")
var home_sec := Color("#E8D9A0")
var away_col := Color("#7A2A2A")
var away_sec := Color("#F0E6D0")
var inner: Rect2 = Rect2()
var width := 20.0
var seed_value := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true


func configure(cap: int, f: float, hc: Club, ac: Club, r: Rect2, w: float) -> void:
	capacity = cap
	fill = f
	if hc != null:
		home_col = ThemeBuilder.hex(str(hc.colors.get("primary", "#1F3A6B")))
		home_sec = ThemeBuilder.hex(str(hc.colors.get("secondary", "#E8D9A0")))
	if ac != null:
		away_col = ThemeBuilder.hex(str(ac.colors.get("primary", "#7A2A2A")))
		away_sec = ThemeBuilder.hex(str(ac.colors.get("secondary", "#F0E6D0")))
	inner = r
	width = w
	seed_value = cap + int(f * 100.0)
	queue_redraw()


func _oval_pts(r: Rect2, n: int = 40) -> PackedVector2Array:
	var rad := r.size.y / 2.0
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := PI / 2.0 + PI * i / n
		pts.append(r.position + Vector2(rad, rad) + Vector2(cos(a), sin(a)) * rad)
	for i in n + 1:
		var a := -PI / 2.0 + PI * i / n
		pts.append(r.position + Vector2(r.size.x - rad, rad) + Vector2(cos(a), sin(a)) * rad)
	return pts


func _perim(r: Rect2) -> float:
	var rad := r.size.y / 2.0
	return 2.0 * (r.size.x - 2.0 * rad) + 2.0 * PI * rad


func _point(r: Rect2, u: float, off: float) -> Vector2:
	var rad := r.size.y / 2.0
	var straight := r.size.x - 2.0 * rad
	var arc := PI * rad
	var d := fmod(u, 1.0) * _perim(r)
	if d < straight:
		return Vector2(r.position.x + rad + d, r.position.y - off)
	d -= straight
	if d < arc:
		var a := -PI / 2.0 + d / rad
		return Vector2(r.end.x - rad, r.position.y + rad) + Vector2(cos(a), sin(a)) * (rad + off)
	d -= arc
	if d < straight:
		return Vector2(r.end.x - rad - d, r.end.y + off)
	d -= straight
	var a2 := PI / 2.0 + d / rad
	return Vector2(r.position.x + rad, r.position.y + rad) + Vector2(cos(a2), sin(a2)) * (rad + off)


func _draw() -> void:
	if inner.size.x <= 0.0:
		return
	var r := inner
	var w := width
	var outer := r.grow(w)
	var rng := SimRng.new(seed_value)
	draw_colored_polygon(_oval_pts(outer.grow(3.0)), Color(0, 0, 0, 0.18))
	var bands := 6
	for i in bands:
		var t0 := float(i) / bands
		var t1 := float(i + 1) / bands
		var c := Color("#7B6243").lerp(Color("#4E3B25"), t1)
		var ring := _oval_pts(r.grow(w * t1))
		draw_colored_polygon(ring, c)
	var tiers := 1 if w < 18.0 else 2
	var split := 0.48
	var row_gap := 5.2
	var rows := maxi(2, int((w - 5.0) / row_gap))
	var perim := _perim(r)
	var seat_gap := 4.8
	var n_seats := int(perim / seat_gap)
	var sectors := 8 if w < 18.0 else 12
	var aisle := 0.006
	var away_from := 0.22
	var away_to := 0.30
	for i in rows:
		var off := 3.5 + (i + 0.5) * row_gap
		if off > w - 3.0:
			break
		var tier_gap := tiers == 2 and absf(off / w - split) < row_gap / w * 0.6
		if tier_gap:
			var pts := PackedVector2Array()
			for k in 160:
				pts.append(_point(r, float(k) / 160.0, off))
			pts.append(pts[0])
			draw_polyline(pts, Color("#A89068"), 3.0, true)
			continue
		var row_col := Color("#8C7250").lerp(Color("#5A4530"), float(i) / rows)
		var pts2 := PackedVector2Array()
		for k in 160:
			pts2.append(_point(r, float(k) / 160.0, off))
		pts2.append(pts2[0])
		draw_polyline(pts2, row_col, 1.0, true)
		for s in n_seats:
			var u := (float(s) + 0.5 * (i % 2)) / n_seats
			var sector_u := fmod(u * sectors, 1.0)
			if sector_u < aisle * sectors or sector_u > 1.0 - aisle * sectors:
				continue
			var p := _point(r, u, off)
			var is_away := u >= away_from and u <= away_to
			var occupied := rng.next() < (fill * (0.85 if is_away else 1.0) + 0.08)
			var seat := Color("#8E7352") if not is_away else Color("#86705A")
			if not occupied:
				draw_rect(Rect2(p - Vector2(1.5, 1.2), Vector2(3.0, 2.4)), seat)
				continue
			var base: Color = away_col if is_away else home_col
			var sec: Color = away_sec if is_away else home_sec
			var x := rng.next()
			var c: Color = base if x < 0.55 else (sec if x < 0.75 else Color("#C9B48E").lerp(base, 0.3))
			c = c.lerp(Color(0.1, 0.08, 0.05), 0.12 * float(i) / rows)
			draw_rect(Rect2(p - Vector2(1.9, 0.2), Vector2(3.8, 2.4)), c.darkened(0.15))
			draw_circle(p - Vector2(0.0, 1.0), 1.5, c)
	for sct in sectors:
		var u := float(sct) / sectors
		var a := _point(r, u, 2.0)
		var b := _point(r, u, w - 1.0)
		draw_line(a, b, Color("#2E2114"), 4.0, true)
		draw_line(a, b, Color("#B8A077"), 2.0, true)
	draw_polyline(_oval_pts(r.grow(1.0)), Color("#2E2114"), 3.0, true)
	draw_polyline(_oval_pts(r.grow(2.5)), Color("#C9B080"), 1.2, true)
	draw_polyline(_oval_pts(outer.grow(-1.5)), Color("#1E150C"), 3.5, true)
	draw_polyline(_oval_pts(outer), Color("#5A4530"), 1.5, true)
	var poles := sectors
	for i in poles:
		var u := (float(i) + 0.5) / poles
		var base := _point(r, u, w + 1.0)
		var tip := _point(r, u, w + 9.0)
		draw_line(base, tip, Color("#3B2B19"), 1.5, true)
		var fc: Color = away_col if (u >= away_from and u <= away_to) else home_col
		var fs: Color = away_sec if (u >= away_from and u <= away_to) else home_sec
		var dir := (tip - base).normalized()
		var side := Vector2(-dir.y, dir.x)
		var flag := PackedVector2Array([tip, tip - dir * 5.0 + side * 6.0, tip - dir * 6.0])
		draw_colored_polygon(flag, fc)
		draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), fs, 0.8, true)
