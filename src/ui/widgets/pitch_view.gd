class_name PitchView
extends Control
## Quidditch pitch drawn vertically (like Football Manager's tactics screen): an oval, three hoops per
## side, our hoops at the bottom and the seven positions as tokens spread over the whole pitch. An empty slot
## is drawn as a dotted circle. Visual only: the simulator is still zone-based.
## - Dragging a token onto another: `swap_requested(a, b)`.
## - Clicking a slot (token or gap): `slot_pressed(index)` (0 K, 1-3 C, 4-5 B, 6 S).
## - Dropping a player dragged from a list ({"player_id": id}) near a slot: `player_dropped(player_id, index)`;
##   the slot under the drag is highlighted while hovering.

const SLOTS := ["K", "C", "C", "C", "B", "B", "S"]
const R := 16.0

var club: Club = null
var players: Array = []   # 7 entries in SLOTS order: {pos, name, condition, id} or {} if empty
var formation: String = "free"
var highlight := -1       # highlighted slot (e.g. while picking a player from the list)
var _chips: Array = []
var _drag := -1
var _drag_pos := Vector2.ZERO
var _press_pos := Vector2.ZERO
var accept_drops := true  # false on a read-only lineup (another club's)
var _drop_hover := -1
signal swap_requested(a_id: String, b_id: String)
signal slot_pressed(index: int)
signal player_dropped(player_id: String, index: int)


func _ready() -> void:
	custom_minimum_size = Vector2(260, 460)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_lineup(c: Club, ps: Array, form: String = "free") -> void:
	club = c
	players = ps
	formation = form
	queue_redraw()


func _slot_at(p: Vector2) -> int:
	for i in _chips.size():
		if _chips[i].distance_to(p) <= R + 6.0:
			return i
	return -1


func _nearest_slot(p: Vector2) -> int:
	var best := -1
	var best_d := R * 3.0
	for i in _chips.size():
		var d: float = _chips[i].distance_to(p)
		if d <= best_d:
			best = i
			best_d = d
	return best


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var ok: bool = accept_drops and data is Dictionary and str(data.get("player_id", "")) != ""
	var target: int = _nearest_slot(at_position) if ok else -1
	if target != _drop_hover:
		_drop_hover = target
		queue_redraw()
	return target >= 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var target := _nearest_slot(at_position)
	_drop_hover = -1
	queue_redraw()
	if target >= 0 and data is Dictionary:
		player_dropped.emit(str(data.get("player_id", "")), target)


func _notification(what: int) -> void:
	if (what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT) and _drop_hover != -1:
		_drop_hover = -1
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
			var i := _slot_at(event.position)
			if i >= 0 and i < players.size() and not players[i].is_empty():
				_drag = i
				_drag_pos = event.position
			queue_redraw()
		else:
			var target := _slot_at(event.position)
			if _drag >= 0 and target >= 0 and target != _drag and event.position.distance_to(_press_pos) > 6.0:
				if not players[target].is_empty():
					swap_requested.emit(str(players[_drag]["id"]), str(players[target]["id"]))
			elif target >= 0:
				slot_pressed.emit(target)
			_drag = -1
			queue_redraw()
	elif event is InputEventMouseMotion and _drag >= 0:
		_drag_pos = event.position
		queue_redraw()


func _spots() -> Array:
	var c := [Vector2(0.68, 0.5), Vector2(0.56, 0.22), Vector2(0.56, 0.78)]
	match formation:
		"hawkshead":
			c = [Vector2(0.72, 0.5), Vector2(0.60, 0.30), Vector2(0.60, 0.70)]
		"porskoff":
			c = [Vector2(0.68, 0.26), Vector2(0.56, 0.5), Vector2(0.68, 0.74)]
		"shimmy":
			c = [Vector2(0.60, 0.34), Vector2(0.70, 0.54), Vector2(0.56, 0.74)]
		"looping":
			c = [Vector2(0.66, 0.5), Vector2(0.52, 0.26), Vector2(0.52, 0.74)]
	return [Vector2(0.06, 0.5), c[0], c[1], c[2], Vector2(0.38, 0.3), Vector2(0.38, 0.7), Vector2(0.81, 0.5)]


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-6)
	var grass := Color("#5B7A3C")
	var stripe := Color("#557238")
	var line := Color(ThemeBuilder.CARD, 0.85)
	var rad := r.size.x / 2.0
	var top := r.position + Vector2(rad, rad)
	var bottom := Vector2(top.x, r.end.y - rad)
	draw_rect(Rect2(r.position + Vector2(0, rad), Vector2(r.size.x, r.size.y - 2 * rad)), grass)
	draw_circle(top, rad, grass)
	draw_circle(bottom, rad, grass)
	for k in range(1, 8, 2):
		var y0 := r.position.y + rad + (r.size.y - 2 * rad) * k / 8.0
		draw_rect(Rect2(r.position.x, y0, r.size.x, (r.size.y - 2 * rad) / 8.0), stripe)
	var cy := r.position.y + r.size.y / 2.0
	draw_line(Vector2(r.position.x, cy), Vector2(r.end.x, cy), line, 1.5)
	draw_arc(Vector2(top.x, cy), rad * 0.38, 0, TAU, 48, line, 1.5)
	for side: float in [-1.0, 1.0]:
		var gy: float = cy + side * (r.size.y / 2.0 - rad * 0.55)
		draw_arc(Vector2(top.x, gy), rad * 0.62, 0, TAU, 48, line, 1.0)
		for i in 3:
			var hx := top.x + (i - 1) * rad * 0.5
			var hr := 7.0 if i == 1 else 6.0
			draw_arc(Vector2(hx, gy), hr, 0, TAU, 20, ThemeBuilder.GOLD, 2.0)
			draw_line(Vector2(hx + hr, gy), Vector2(hx + hr + 4, gy), ThemeBuilder.GOLD, 2.0)
	var pc := ThemeBuilder.hex(str(club.colors.get("primary", "#888"))) if club else ThemeBuilder.BORDER_CONTROL
	var sc := ThemeBuilder.hex(str(club.colors.get("secondary", "#ddd"))) if club else ThemeBuilder.BRASS
	var font := ThemeBuilder.font("ui_bold")
	var small := ThemeBuilder.font("ui")
	var letters: Array[String] = []
	for s in SLOTS:
		letters.append(UI.pos_short(str(s)))
	var spots := _spots()
	_chips.clear()
	for i in SLOTS.size():
		var rel: Vector2 = spots[i]
		var at := Vector2(r.position.x + rel.y * r.size.x, r.end.y - rel.x * r.size.y)
		_chips.append(at)
	for i in SLOTS.size():
		var at: Vector2 = _chips[i]
		var p: Dictionary = players[i] if i < players.size() else {}
		if i == highlight or i == _drop_hover:
			draw_circle(at, R + 7.0, Color(ThemeBuilder.GOLD, 0.45))
		if p.is_empty():
			draw_arc(at, R, 0, TAU, 24, Color(ThemeBuilder.CARD, 0.7), 2.0, true)
			var ts0 := font.get_string_size(letters[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
			draw_string(font, at + Vector2(-ts0.x / 2.0, 5.0), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(ThemeBuilder.CARD, 0.8))
			continue
		if i == _drag:
			at = _drag_pos
		var cond := float(p.get("condition", 100.0))
		var available := bool(p.get("available", true))
		draw_circle(at + Vector2(1.5, 2.0), R, Color(0, 0, 0, 0.25))
		draw_circle(at, R, sc)
		draw_circle(at, R - 2.5, pc)
		if not available:
			draw_arc(at, R, 0, TAU, 24, ThemeBuilder.SEALING_WAX, 3.0, true)
		var ts := font.get_string_size(letters[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		draw_string(font, at + Vector2(-ts.x / 2.0, 5.0), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ThemeBuilder.text_on(pc))
		var name := str(p.get("name", ""))
		var parts := name.split(" ")
		var short := parts[parts.size() - 1] if parts.size() > 1 else name
		if not available:
			short += " ✚"
		var ns := small.get_string_size(short, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		var ny := at.y + R + 14.0
		draw_rect(Rect2(at.x - ns.x / 2.0 - 3, ny - 11, ns.x + 6, 15), Color(ThemeBuilder.WOOD, 0.6))
		draw_string(small, Vector2(at.x - ns.x / 2.0, ny), short, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ThemeBuilder.SEALING_WAX.lerp(Color.WHITE, 0.5) if not available else ThemeBuilder.CARD)
		draw_rect(Rect2(at.x - 14, ny + 6, 28, 3), Color(ThemeBuilder.WOOD, 0.5))
		draw_rect(Rect2(at.x - 14, ny + 6, 28 * clampf(cond / 100.0, 0.0, 1.0), 3), ThemeBuilder.bar_color(cond))
