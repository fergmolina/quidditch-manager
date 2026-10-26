extends Node
## Compiles every GDScript under src, tools and tests and reports the ones that fail.
## Run: godot --headless --path . tools/check_scripts.tscn
## Exits with code 1 if any script fails. A few seconds: the cheap gate between edits. It runs as a scene, not with
## `-s`, so the `Game` autoload exists and the src/ui scripts compile too.


func _ready() -> void:
	var failed := 0
	var total := 0
	for root in ["res://src", "res://tools", "res://tests"]:
		for path in _scripts(root):
			total += 1
			var s: Script = load(path)
			if s == null or s.reload(true) != OK:
				failed += 1
				print("FAILED: ", path)
	print("check_scripts: %d scripts, %d failed" % [total, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _scripts(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir.path_join(n)
		if d.current_is_dir():
			out.append_array(_scripts(p))
		elif n.ends_with(".gd") and n != "check_scripts.gd":
			out.append(p)
		n = d.get_next()
	d.list_dir_end()
	return out
