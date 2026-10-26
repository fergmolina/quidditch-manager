extends SceneTree
## Contact sheet of screenshots for visual review: godot --headless --path . -s tools/contact_sheet.gd -- <folder> <prefix> <output.png> [columns]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir := DirAccess.open(a[0])
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with(a[1]) and f.ends_with(".png"):
			files.append(f)
	files.sort()
	var cols := int(a[3]) if a.size() > 3 else 4
	var cw := 683
	var ch := 410
	var rows := int(ceil(files.size() / float(cols)))
	var sheet := Image.create(cw * cols, (ch + 22) * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	for i in files.size():
		var im := Image.load_from_file(a[0] + "/" + files[i])
		im.convert(Image.FORMAT_RGBA8)
		im.resize(cw - 6, ch - 4)
		sheet.blit_rect(im, Rect2i(0, 0, cw - 6, ch - 4), Vector2i((i % cols) * cw, (i / cols) * (ch + 22) + 20))
	sheet.save_png(a[2])
	print(files)
	quit()
