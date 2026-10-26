extends SceneTree
## Youth development curve (calibration): generates the world, takes new youth players from every club and progresses
## them week by week like the engine does (Progression.weekly + training + summer break), with 0 or 240 min/month.
## Prints median CA at ages 19/21/24/27 per PA band. godot --headless --path . -s tools/youth_curve.gd

func _init() -> void:
	var loader := SimLoader.new()
	loader.load_all("1993-94")
	var w := WorldGenerator.new(loader).generate(1)
	var gen := WorldGenerator.new(loader)
	var rng := w.rng()
	var youths: Array = []
	for c in w.clubs_sorted():
		for i in 6:
			youths.append([gen._make_filler(w, c, str(rng.pick(["C", "C", "C", "B", "B", "K", "S"])), "youth", rng, 900 + i), c])
	var pas: Array = []
	for y in youths:
		pas.append(y[0].pa)
	pas.sort()
	print("youths %d | initial CA med %.0f | PA p10 %.0f med %.0f p90 %.0f max %.0f" % [youths.size(), _med(youths.map(func(y): return y[0].ca())), pas[pas.size() / 10], pas[pas.size() / 2], pas[pas.size() * 9 / 10], pas[-1]])
	for minutes in [0, 240]:
		var ps: Array = []
		for y in youths:
			var p: Player = y[0].clone()
			ps.append([p, y[1], {}])
		var start := w.today
		for week in 52 * 10:
			w.today = start + week * 7
			for e in ps:
				var p: Player = e[0]
				Progression.weekly(p, w, e[1], rng, minutes if p.age(w.today) >= 19 else 0)
				Progression.training(p, "tactics", 2, rng, e[1])
				if week % 52 == 51:
					for k in Player.ATTR_KEYS:
						p.attrs[k] = clampf(float(p.attrs[k]) - 0.15, 1.0, 20.0)
				var a := p.age(w.today)
				if not e[2].has(a):
					e[2][a] = p.ca()
		w.today = start
		var line := "min/month %3d |" % minutes
		for band in [[0, 90], [90, 120], [120, 150], [150, 200]]:
			var sel := ps.filter(func(e): return e[0].pa >= band[0] and e[0].pa < band[1])
			var parts := []
			for age in [19, 21, 24, 27]:
				parts.append("%d:%.0f" % [age, _med(sel.map(func(e): return float(e[2].get(age, 0.0))))])
			line += " PA %d-%d (n=%d) %s |" % [band[0], band[1], sel.size(), " ".join(parts)]
		print(line)
	quit()


func _med(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var a := arr.duplicate()
	a.sort()
	return float(a[a.size() / 2])
