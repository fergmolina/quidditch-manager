extends SceneTree
## Imports the AI-generated sheets. Sheets live outside the repository, in the local work folder
## (default ../Quidditch Manager - work/sheets/<kind>/<batch>.png):
## - crests (default): sheets/crests/<batch>.png → assets/crests/ai/<id>.png, per docs/art/crests/batches.json
## - portraits: sheets/portraits/<batch>.png → assets/portraits/<id>.png, per docs/art/portraits/batches.json
## - brooms: sheets/brooms/<batch>.png → assets/brooms/<id>.png, per docs/art/brooms/batches.json
## godot --headless --path . -s tools/import_crest_sheets.gd [-- portraits|brooms] [all] [sheets=<dir>]
## Only sheets that are new or changed since the last import are processed ("all" reimports every sheet).
## "sheets=<dir>" points to another folder that holds the crests/, portraits/ and brooms/ subfolders.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := "portraits" if args.has("portraits") else ("brooms" if args.has("brooms") else "crests")
	var out_dir: String = {"crests": "res://assets/crests/ai", "portraits": "res://assets/portraits", "brooms": "res://assets/brooms"}[kind]
	var mode: String = {"crests": "--auto", "portraits": "--figures", "brooms": "--rows"}[kind]
	var sheets_root := ProjectSettings.globalize_path("res://").path_join("../Quidditch Manager - work/sheets").simplify_path()
	for a in args:
		if a.begins_with("sheets="):
			sheets_root = a.substr(7)
	var sheets_dir := sheets_root.path_join(kind)
	var batches: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/%s/batches.json" % kind))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var dir := DirAccess.open(sheets_dir)
	if dir == null:
		print("no sheets in ", sheets_dir)
		quit()
		return
	var done := 0
	for f in dir.get_files():
		if not (f.ends_with(".png") or f.ends_with(".jpg") or f.ends_with(".webp")):
			continue
		var key := f.get_basename()
		if not batches.has(key):
			print("sheet with no known batch: ", f)
			continue
		var ids: Array = batches[key]
		if not args.has("all"):
			var sheet_t := FileAccess.get_modified_time(sheets_dir.path_join(f))
			var fresh := true
			for id in ids:
				var out_f := "%s/%s.png" % [out_dir, id]
				if not FileAccess.file_exists(out_f) or FileAccess.get_modified_time(out_f) < sheet_t:
					fresh = false
					break
			if fresh:
				continue
		var log: Array = []
		OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "tools/crop_badges.gd", "--", sheets_dir.path_join(f), mode, ",".join(ids), ProjectSettings.globalize_path(out_dir)], log, true)
		for line in "".join(log).split("\n"):
			if line.begins_with("WARNING"):
				print(f, ": ", line)
		done += 1
		print("%s → %d" % [f, ids.size()])
	print("%d sheets imported" % done)
	quit()
