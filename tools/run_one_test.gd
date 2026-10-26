extends SceneTree
## Runs one test function of tests/run_tests.gd without the 19-minute suite: the function (plus check() and the
## helpers named in QM_HELPERS) is compiled out of the file into a scratch script and called once.
## Run: QM_TEST=test_determinism [QM_HELPERS=_sim,_rm_tree] godot --headless --path . -s tools/run_one_test.gd
## Exit 0 when every check passed, 1 on a failed check, 2 when a function is missing or the body does not compile.
func _init() -> void:
	var name := OS.get_environment("QM_TEST")
	var src := FileAccess.get_file_as_string("res://tests/run_tests.gd")
	var body := ""
	var names := ["check", name]
	for h in OS.get_environment("QM_HELPERS").split(",", false):
		names.append(h)
	for fn in names:
		var start := src.find("\nfunc " + fn + "(")
		if start < 0:
			print("MISSING FUNC ", fn)
			quit(2)
			return
		var end := src.find("\nfunc ", start + 1)
		if end < 0:
			end = src.length()
		body += src.substr(start, end - start) + "\n"
	var gd := GDScript.new()
	gd.source_code = "extends RefCounted\nvar failures := 0\nvar passed := 0\nvar loader := SimLoader.new()\n" + body
	if gd.reload() != OK:
		print("COMPILE FAILED")
		quit(2)
		return
	var t = gd.new()
	SaveManager.saves_dir = "user://test_saves"
	t.loader.load_all("1993-94")
	var t0 := Time.get_ticks_msec()
	t.call(name)
	print("RESULT %s: %d passed, %d failed, %d ms" % [name, t.passed, t.failures, Time.get_ticks_msec() - t0])
	quit(1 if t.failures > 0 else 0)
