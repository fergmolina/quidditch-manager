extends SceneTree
## Synthesizes the sound effects (no third-party assets): whistle, goal, save, Bludger, Snitch,
## crowd murmur and cheer. Usage: godot --headless --path . -s tools/make_sounds.gd  → assets/sounds/*.wav

const RATE := 22050


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/sounds")
	_save("whistle", _whistle())
	_save("goal", _goal())
	_save("save", _thud(0.12, 220.0))
	_save("bludger", _thud(0.18, 90.0))
	_save("snitch", _chime())
	_save("crowd", _crowd(2.5, 0.25))
	_save("cheer", _crowd(1.6, 0.9))
	_save("click", _thud(0.03, 1200.0))
	_save("theme", _theme())
	print("sounds generated in assets/sounds")
	quit()


func _save(name: String, samples: PackedFloat32Array) -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	wav.data = data
	wav.save_to_wav("res://assets/sounds/%s.wav" % name)


func _env(t: float, a: float, d: float, total: float) -> float:
	if t < a:
		return t / a
	if t > total - d:
		return maxf((total - t) / d, 0.0)
	return 1.0


func _whistle() -> PackedFloat32Array:
	var total := 0.7
	var out := PackedFloat32Array()
	var n := int(total * RATE)
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in n:
		var t := float(i) / RATE
		var f := 2600.0 + 40.0 * sin(t * 60.0)
		var pea := 1.0 + 0.35 * sin(t * 2.0 * PI * 24.0)
		out[i] = 0.6 * _env(t, 0.01, 0.08, total) * pea * sin(t * TAU * f) + 0.05 * rng.randf_range(-1, 1)
	return out


## A goal: the stands erupt. A fast swell of crowd noise with a dozen "voices" (resonant band-passed noise whose
## pitch sags like a shouted "yeaah"), a low rumble underneath, and a slow fade as the shout turns into cheering.
func _goal() -> PackedFloat32Array:
	var total := 2.6
	var out := PackedFloat32Array()
	var n := int(total * RATE)
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	const VOICES := 12
	var centre: Array[float] = []   # Hz, the shout's formant per voice
	var onset: Array[float] = []    # s, nobody shouts at exactly the same time
	var vib: Array[float] = []      # Hz, slight wobble
	var s1 := PackedFloat32Array()  # state-variable filter memory (band-pass) per voice
	var s2 := PackedFloat32Array()
	s1.resize(VOICES)
	s2.resize(VOICES)
	for v in VOICES:
		centre.append(rng.randf_range(260.0, 820.0))
		onset.append(rng.randf_range(0.0, 0.16))
		vib.append(rng.randf_range(4.0, 7.0))
	var lp := 0.0
	var lp2 := 0.0
	var rumble := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1, 1)
		# Bed: the same low murmur as the crowd loop, swelling hard at the goal.
		lp += (white - lp) * 0.08
		lp2 += (lp - lp2) * 0.05
		rumble += (white - rumble) * 0.015
		var swell := _env(t, 0.06, 1.2, total)
		var bed := (lp2 * 3.2 + rumble * 2.0) * swell
		# Voices: each one a resonant band-pass on fresh noise; the centre glides down over the shout.
		var voices := 0.0
		for v in VOICES:
			var tv := t - onset[v]
			if tv < 0.0:
				continue
			var env := _env(tv, 0.05, 0.9, total - onset[v]) * (1.0 if tv < 0.7 else 0.55)
			var f: float = centre[v] * (1.0 - 0.18 * clampf(tv / 1.1, 0.0, 1.0)) * (1.0 + 0.02 * sin(tv * TAU * vib[v]))
			var fc := 2.0 * sin(PI * f / RATE)
			var q := 0.12
			var hp := rng.randf_range(-1, 1) - s2[v] - q * s1[v]
			s1[v] += fc * hp
			s2[v] += fc * s1[v]
			voices += s1[v] * env
		out[i] = clampf(0.55 * bed + 0.16 * voices, -1.0, 1.0)
	return out


func _thud(total: float, f: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(total * RATE)
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in n:
		var t := float(i) / RATE
		var e := exp(-t * 28.0)
		out[i] = 0.9 * e * (sin(t * TAU * f * (1.0 - t * 2.0)) * 0.7 + rng.randf_range(-1, 1) * 0.3)
	return out


func _chime() -> PackedFloat32Array:
	var total := 1.2
	var out := PackedFloat32Array()
	var n := int(total * RATE)
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var e := exp(-t * 3.0)
		out[i] = 0.5 * e * (sin(t * TAU * 1760.0) + 0.5 * sin(t * TAU * 2637.0) + 0.3 * sin(t * TAU * 3520.0)) * (1.0 + 0.2 * sin(t * TAU * 6.0))
	return out


func _theme() -> PackedFloat32Array:
	var bpm := 84.0
	var beat := 60.0 / bpm
	var melody := [62, 65, 69, 67, 65, 62, 60, 62, 65, 69, 72, 70, 69, 67, 65, 62, 60, 62, 65, 69, 67, 65, 64, 62, 60, 58, 60, 62, 65, 62, 60, 62]
	var durs := [1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 2]
	var chords := [[50, 57, 62], [48, 55, 60], [46, 53, 58], [45, 52, 57]]
	var total := 0.0
	for d in durs:
		total += d * beat
	var out := PackedFloat32Array()
	var n := int(total * RATE)
	out.resize(n)
	var starts := []
	var acc := 0.0
	for d in durs:
		starts.append(acc)
		acc += d * beat
	var idx := 0
	for i in n:
		var t := float(i) / RATE
		while idx + 1 < starts.size() and t >= starts[idx + 1]:
			idx += 1
		var f: float = 440.0 * pow(2.0, (int(melody[idx]) - 69) / 12.0)
		var lt: float = t - float(starts[idx])
		var e := exp(-lt * 2.2) * minf(lt * 60.0, 1.0)
		var tone := 0.0
		for h in [1.0, 2.0, 3.0, 4.0, 5.0]:
			tone += sin(t * TAU * f * h) / (h * h)
		var bar := int(t / (beat * 4.0)) % 4
		var ch: Array = chords[bar]
		var pad := 0.0
		for midi in ch:
			var cf := 440.0 * pow(2.0, (int(midi) - 69) / 12.0)
			pad += sin(t * TAU * cf) * 0.5 + sin(t * TAU * cf * 2.0) * 0.15
		var env_total := _env(t, 0.05, 1.0, total)
		out[i] = clampf((0.32 * e * tone + 0.08 * pad) * env_total, -1.0, 1.0)
	return out


func _crowd(total: float, intensity: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(total * RATE)
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1, 1)
		lp += (white - lp) * 0.08
		lp2 += (lp - lp2) * 0.05
		var swell := 0.6 + 0.4 * sin(t * TAU * 0.7) * sin(t * TAU * 0.23 + 1.0)
		out[i] = clampf((0.35 + 0.65 * intensity) * _env(t, 0.3, 0.6, total) * swell * lp2 * 4.0, -1.0, 1.0)
	return out
