class_name LeagueMap
extends Control
## Antique atlas map with a wax seal per league (or school). Clicking a seal → `pin_pressed(id)`.
## Positions come from data/shared/map.json (tools/make_map.py); the image from assets/art/map_<name>.png.

signal pin_pressed(id: String)

var map_name := "world"
var texture: Texture2D
var aspect := 1.0                 # image height / width
var pins: Array = []              # [{id, x, y (0-1), label, school}]
var selected := ""
var _hover := ""
## Which seals are shown: "all", "clubs" (leagues) or "schools" (the New Game filter).
var seal_filter := "all"

const R := 8.0


func setup(name: String, pin_list: Array) -> void:
	map_name = name
	texture = load("res://assets/art/map_%s.png" % name)
	if texture != null:
		aspect = float(texture.get_height()) / float(texture.get_width())
	pins = pin_list
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	custom_minimum_size.y = size.x * aspect
	queue_redraw()


func _pin_at(p: Vector2) -> String:
	var best := ""
	var best_d := R + 6.0
	for pin in pins:
		if not _shown(pin):
			continue
		var d := p.distance_to(Vector2(float(pin["x"]) * size.x, float(pin["y"]) * size.y))
		if d < best_d:
			best_d = d
			best = str(pin["id"])
	return best


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := _pin_at(ev.position)
		if h != _hover:
			_hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var id := _pin_at(ev.position)
		if id != "":
			selected = id
			queue_redraw()
			pin_pressed.emit(id)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != "":
		_hover = ""
		queue_redraw()


func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
	var font := ThemeBuilder.font("ui_bold")
	var label_pin: Dictionary = {}
	for pin in pins:
		if not _shown(pin):
			continue
		var c := Vector2(float(pin["x"]) * size.x, float(pin["y"]) * size.y)
		var id := str(pin["id"])
		var big := id == selected or id == _hover
		var r := R * (1.35 if big else 1.0)
		var wax := ThemeBuilder.BLUE if bool(pin.get("school", false)) else ThemeBuilder.SEALING_WAX
		if id == selected:
			draw_circle(c, r + 5.0, Color(ThemeBuilder.GOLD, 0.35))
		draw_circle(c + Vector2(1.5, 2.0), r, Color(0, 0, 0, 0.28))
		draw_circle(c, r, wax)
		draw_arc(c, r, 0.0, TAU, 28, ThemeBuilder.BRASS, 1.6, true)
		draw_arc(c, r * 0.55, 0.0, TAU, 20, Color(ThemeBuilder.BRASS, 0.8), 1.0, true)
		draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.22, Color(1, 1, 1, 0.35))
		if big:
			label_pin = pin
	if not label_pin.is_empty():
		var c := Vector2(float(label_pin["x"]) * size.x, float(label_pin["y"]) * size.y)
		var txt := str(label_pin["label"])
		var fs := 13
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := c + Vector2(-tw / 2.0, -R * 1.35 - 10.0)
		pos.x = clampf(pos.x, 4.0, size.x - tw - 8.0)
		pos.y = maxf(pos.y, 18.0)
		var box := Rect2(pos + Vector2(-5, -14), Vector2(tw + 10, 19))
		draw_rect(box, Color(ThemeBuilder.CARD, 0.95))
		draw_rect(box, ThemeBuilder.BORDER_CONTROL, false, 1.0)
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ThemeBuilder.INK)


func _shown(pin: Dictionary) -> bool:
	return seal_filter == "all" or (seal_filter == "schools") == bool(pin.get("school", false))


## A small seal in the map's colours (red wax: a league of clubs; blue: a school), for the legend.
static func seal(school: bool) -> Control:
	var s := Seal.new()
	s.school = school
	s.custom_minimum_size = Vector2(18, 18)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


class Seal extends Control:
	var school := false

	func _draw() -> void:
		var c := size / 2.0
		var r := 6.5
		draw_circle(c + Vector2(1.0, 1.5), r, Color(0, 0, 0, 0.28))
		draw_circle(c, r, ThemeBuilder.BLUE if school else ThemeBuilder.SEALING_WAX)
		draw_arc(c, r, 0.0, TAU, 24, ThemeBuilder.BRASS, 1.4, true)
		draw_arc(c, r * 0.55, 0.0, TAU, 16, Color(ThemeBuilder.BRASS, 0.8), 1.0, true)
