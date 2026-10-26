class_name LoadingOverlay
extends CanvasLayer
## Loading overlay: a golden snitch fluttering and orbiting over a parchment card, with a text
## ("Advancing…", "Preparing the world…"). It covers the screen (nothing can be touched while it works) and only
## shows up if the wait exceeds DELAY seconds, to avoid flicker on quick transitions.

const DELAY := 0.25

var _shade: ColorRect
var _card: PanelContainer
var _label: Label
var _sub: Label
var _snitch: Control
var _active := false
var _t := 0.0


func _ready() -> void:
	layer = 50
	_shade = ColorRect.new()
	_shade.color = Color(ThemeBuilder.WOOD, 0.0)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.add_child(center)
	_card = UI.panel(18)
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card.custom_minimum_size = Vector2(320, 0)
	var v := UI.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_snitch = Control.new()
	_snitch.custom_minimum_size = Vector2(120, 80)
	_snitch.draw.connect(_draw_snitch)
	v.add_child(_snitch)
	_label = UI.label("", "title", 22, ThemeBuilder.INK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_label)
	_sub = UI.label("", "ui", 14, ThemeBuilder.INK_SOFT)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_sub)
	_card.add_child(v)
	center.add_child(_card)
	visible = false


func begin(text: String) -> void:
	_label.text = text
	_sub.text = ""
	_active = true
	_t = 0.0
	visible = true
	_shade.color.a = 0.0
	_card.modulate.a = 0.0


func set_detail(text: String) -> void:
	_sub.text = text


func end() -> void:
	_active = false
	visible = false


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	var k := clampf((_t - DELAY) / 0.2, 0.0, 1.0)
	_shade.color.a = 0.45 * k
	_card.modulate.a = k
	_snitch.queue_redraw()


func _draw_snitch() -> void:
	var c := _snitch.size / 2.0
	var pos := c + Vector2(sin(_t * 2.2) * 26.0, sin(_t * 4.4) * 9.0)
	var flap := sin(_t * 28.0)
	var wing_col := Color("#E8E6DA")
	var edge := Color("#8C7A55")
	for side in [-1.0, 1.0]:
		var base := pos + Vector2(side * 7.0, -2.0)
		var lift := -14.0 - flap * 8.0
		var pts := PackedVector2Array([base, base + Vector2(side * 26.0, lift), base + Vector2(side * 30.0, lift + 9.0), base + Vector2(side * 12.0, 4.0)])
		_snitch.draw_colored_polygon(pts, wing_col)
		_snitch.draw_polyline(pts + PackedVector2Array([base]), edge, 1.2, true)
		for f in 3:
			var tip := base + Vector2(side * (14.0 + f * 6.0), lift * (0.45 + f * 0.18))
			_snitch.draw_line(base, tip, Color(edge, 0.55), 1.0, true)
	_snitch.draw_circle(pos + Vector2(1.5, 2.0), 9.0, Color(0, 0, 0, 0.2))
	_snitch.draw_circle(pos, 9.0, ThemeBuilder.GOLD)
	_snitch.draw_arc(pos, 9.0, 0.0, TAU, 24, Color("#9C7A1E"), 1.4, true)
	_snitch.draw_arc(pos, 5.5, PI * 0.2, PI * 0.8, 10, Color("#9C7A1E"), 1.0, true)
	_snitch.draw_circle(pos + Vector2(-3.0, -3.0), 2.4, Color(1, 1, 1, 0.6))
	for i in 6:
		var tt := _t - i * 0.06
		var sp := c + Vector2(sin(tt * 2.2) * 26.0, sin(tt * 4.4) * 9.0)
		_snitch.draw_circle(sp, 2.2 - i * 0.3, Color(ThemeBuilder.GOLD, 0.35 - i * 0.05))
