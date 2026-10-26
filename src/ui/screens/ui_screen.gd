class_name UIScreen
extends Control
## Base of all screens. Each screen is built in build() and updated in refresh().

var main: Node = null
var params: Dictionary = {}
var root: VBoxContainer


func setup(main_in: Node, params_in: Dictionary = {}) -> void:
	main = main_in
	params = params_in
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	root = UI.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	build()
	refresh()


func screen_title() -> String:
	return ""


func build() -> void:
	pass


func refresh() -> void:
	pass


## What the screen has selected (a competition, a school, a tab) as params, so Back and Forward return to the same
## view: main merges it into the screen's history entry when the player leaves it (main._remember_state).
func nav_state() -> Dictionary:
	return {}


func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Screen header: H1 on the left, secondary info on the right; no rule (whitespace separates).
func header(text: String, sub: String = "") -> void:
	var h := UI.hbox()
	h.add_child(UI.title(text))
	if sub != "":
		h.add_child(UI.spacer())
		var m := UI.meta(sub)
		m.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(m)
	root.add_child(h)
	root.add_child(UI.gap(4))


func go(screen: String, p: Dictionary = {}) -> void:
	main.go(screen, p)


func T(key: String, p: Dictionary = {}) -> String:
	return Game.t(key, p)
