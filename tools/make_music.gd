extends SceneTree
## Synthesised background music (original compositions and instruments, no third-party samples).
## godot --headless --path . -s tools/make_music.gd   -> assets/sounds/music_*.wav
## Themes: despacho/office (waltz in E minor: harp, celesta and strings), partido/match (march in D: horns, strings
## and timpani), sala_comun/common room (jig in G Dorian: flute, lute and bodhrán). Each theme is a ~1 minute loop.

const RATE := 22050
var buf := PackedFloat32Array()
var rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/sounds")
	_despacho()
	_save("music_despacho")
	_partido()
	_save("music_partido")
	_sala_comun()
	_save("music_sala_comun")
	print("music generated")
	quit()


func _alloc(seconds: float) -> void:
	buf = PackedFloat32Array()
	buf.resize(int(seconds * RATE) + RATE * 3)


func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


func _add(start: float, samples: PackedFloat32Array, gain: float) -> void:
	var i0 := int(start * RATE)
	for i in samples.size():
		var j := i0 + i
		if j >= buf.size():
			break
		buf[j] += samples[i] * gain


func _reverb(wet: float) -> void:
	var combs := [[1557, 0.84], [1617, 0.83], [1491, 0.85], [1422, 0.86]]
	var out := PackedFloat32Array()
	out.resize(buf.size())
	for c in combs:
		var d: int = int(c[0] * RATE / 44100.0)
		var fb: float = c[1]
		var line := PackedFloat32Array()
		line.resize(d)
		var idx := 0
		var lp := 0.0
		for i in buf.size():
			var y := line[idx]
			lp = y * 0.7 + lp * 0.3
			line[idx] = buf[i] + lp * fb
			idx = (idx + 1) % d
			out[i] += y * 0.25
	for ap in [225, 556]:
		var d2: int = int(ap * RATE / 44100.0)
		var line2 := PackedFloat32Array()
		line2.resize(d2)
		var k := 0
		for i in out.size():
			var bufout := line2[k]
			var v := out[i] + bufout * 0.5
			line2[k] = v
			out[i] = bufout - v * 0.5
			k = (k + 1) % d2
	for i in buf.size():
		buf[i] = buf[i] * (1.0 - wet * 0.5) + out[i] * wet


func _save(name: String) -> void:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var g := 0.85 / peak
	var n: int = buf.size() - RATE * 3
	var data := PackedByteArray()
	data.resize(n * 2)
	var fade := int(0.04 * RATE)
	for i in n:
		var v := buf[i] + (buf[i + n] if i + n < buf.size() else 0.0)
		var e := 1.0
		if i < fade:
			e = float(i) / fade
		elif i > n - fade:
			e = float(n - i) / fade
		data.encode_s16(i * 2, int(clampf(v * g * e, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.save_to_wav("res://assets/sounds/%s.wav" % name)
	print(name, ": ", snappedf(float(n) / RATE, 0.1), " s")


func _pluck(midi: float, dur: float, bright: float = 0.5) -> PackedFloat32Array:
	var f := _hz(midi)
	var n := int(dur * RATE)
	var period := maxi(int(RATE / f), 2)
	var line := PackedFloat32Array()
	line.resize(period)
	for i in period:
		line[i] = rng.randf_range(-1.0, 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var idx := 0
	var damp := 0.4985 + bright * 0.0013
	for i in n:
		var a := line[idx]
		var b := line[(idx + 1) % period]
		var v := (a + b) * damp
		line[idx] = v
		out[i] = a
		idx = (idx + 1) % period
	return out


func _bell(midi: float, dur: float) -> PackedFloat32Array:
	var f := _hz(midi)
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 3.2) * minf(t * 400.0, 1.0)
		var mod := sin(TAU * f * 3.5 * t) * 1.6 * exp(-t * 6.0)
		out[i] = sin(TAU * f * t + mod) * env
	return out


func _strings(midi: float, dur: float, att: float = 0.5) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var fs := [_hz(midi) * 0.997, _hz(midi), _hz(midi) * 1.004]
	var ph := [0.0, 0.33, 0.66]
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in 3:
			ph[k] = fmod(ph[k] + fs[k] / RATE, 1.0)
			s += ph[k] * 2.0 - 1.0
		lp += (s / 3.0 - lp) * 0.08
		var env := minf(t / att, 1.0) * minf((dur - t) / 0.6, 1.0)
		out[i] = lp * maxf(env, 0.0)
	return out


func _flute(midi: float, dur: float) -> PackedFloat32Array:
	var f := _hz(midi)
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var vib := 1.0 + 0.006 * sin(TAU * 5.2 * t) * minf(t / 0.35, 1.0)
		ph += f * vib / RATE
		var env := minf(t / 0.05, 1.0) * minf((dur - t) / 0.06, 1.0)
		var breath := rng.randf_range(-1.0, 1.0) * 0.05 * exp(-t * 12.0)
		out[i] = (sin(TAU * ph) + 0.22 * sin(TAU * ph * 2.0)) * maxf(env, 0.0) + breath
	return out


func _horn(midi: float, dur: float) -> PackedFloat32Array:
	var f := _hz(midi)
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		ph = fmod(ph + f / RATE, 1.0)
		var saw := ph * 2.0 - 1.0
		var cutoff := 0.05 + 0.08 * minf(t / 0.12, 1.0)
		lp += (saw - lp) * cutoff
		var env := minf(t / 0.09, 1.0) * minf((dur - t) / 0.15, 1.0)
		out[i] = lp * maxf(env, 0.0)
	return out


func _drum(midi: float, dur: float, noise: float) -> PackedFloat32Array:
	var f := _hz(midi)
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += f * (1.0 + 0.6 * exp(-t * 30.0)) / RATE
		out[i] = (sin(TAU * ph) * exp(-t * 7.0) + rng.randf_range(-1.0, 1.0) * noise * exp(-t * 40.0))
	return out


func _melody(chords: Array, scale: Array, notes_per_bar: int, root_octave: int, seed_value: int) -> Array:
	rng.seed = seed_value
	var out: Array = []
	var cur := root_octave + int(chords[0][0]) % 12 + 12
	for bar in chords.size():
		var ch: Array = chords[bar]
		for k in notes_per_bar:
			var strong := k == 0 or (notes_per_bar >= 4 and k == notes_per_bar / 2)
			var cand: Array = []
			for octave in [root_octave + 12, root_octave + 24]:
				if strong:
					for m in ch:
						cand.append(octave + int(m) % 12)
				else:
					for d in scale:
						cand.append(octave + int(d))
			cand.sort_custom(func(a, b): return absi(a - cur) < absi(b - cur))
			var pick: int = cand[mini(rng.randi_range(0, 2), cand.size() - 1)]
			if absi(pick - cur) > 7:
				pick = cand[0]
			cur = clampi(pick, root_octave + 10, root_octave + 31)
			out.append(cur)
	return out


func _despacho() -> void:
	var beat := 60.0 / 84.0
	var bar := beat * 3.0
	var prog := [[52, 55, 59], [48, 52, 55], [43, 47, 50], [47, 50, 54], [52, 55, 59], [45, 48, 52], [47, 51, 54], [52, 55, 59]]
	var prog_b := [[45, 48, 52], [50, 54, 57], [43, 47, 50], [48, 52, 55], [45, 48, 52], [47, 51, 54], [52, 55, 59], [47, 51, 54]]
	var chords: Array = prog + prog + prog_b + prog
	var scale := [4, 6, 7, 9, 11, 12, 14, 16]
	_alloc(chords.size() * bar)
	var mel_a := _melody(prog, scale, 3, 60, 11)
	var mel_b := _melody(prog_b, scale, 3, 60, 23)
	var mel: Array = mel_a + mel_a + mel_b + mel_a
	rng.seed = 5
	for b in chords.size():
		var ch: Array = chords[b]
		var t0 := b * bar
		_add(t0, _pluck(float(ch[0]) - 12.0, 2.2, 0.6), 0.32)
		_add(t0 + beat, _pluck(float(ch[1]), 1.6, 0.8), 0.18)
		_add(t0 + beat * 1.5, _pluck(float(ch[2]), 1.6, 0.8), 0.16)
		_add(t0 + beat * 2.0, _pluck(float(ch[1]) + 12.0, 1.6, 0.8), 0.15)
		if b % 2 == 0:
			for m in ch:
				_add(t0, _strings(float(m), bar * 2.0 + 0.4, 0.9), 0.045)
		for k in 3:
			var m2: int = mel[b * 3 + k]
			if b >= 8 and b < 16:
				m2 += 12
			if k == 1 and rng.randf() < 0.35:
				continue
			_add(t0 + k * beat, _bell(float(m2), 1.4), 0.2)
	_reverb(0.35)


func _partido() -> void:
	var beat := 60.0 / 112.0
	var bar := beat * 4.0
	var prog := [[50, 54, 57], [55, 59, 62], [57, 61, 64], [50, 54, 57], [47, 50, 54], [55, 59, 62], [57, 61, 64], [57, 61, 64]]
	var prog_b := [[55, 59, 62], [50, 54, 57], [52, 55, 59], [57, 61, 64], [55, 59, 62], [50, 54, 57], [57, 61, 64], [50, 54, 57]]
	var chords: Array = prog + prog_b + prog + prog_b
	var scale := [2, 4, 6, 7, 9, 11, 12, 14]
	_alloc(chords.size() * bar)
	var mel: Array = _melody(prog, scale, 4, 48, 7) + _melody(prog_b, scale, 4, 48, 9)
	mel = mel + mel
	rng.seed = 3
	for b in chords.size():
		var ch: Array = chords[b]
		var t0 := b * bar
		for k in 8:
			var m: int = ch[k % 3]
			_add(t0 + k * beat * 0.5, _strings(float(m), beat * 0.45, 0.02), 0.06)
		_add(t0, _drum(38.0, 1.0, 0.25), 0.42)
		_add(t0 + beat * 2.0, _drum(33.0, 1.0, 0.25), 0.36)
		_add(t0 + beat * 3.5, _drum(45.0, 0.4, 0.5), 0.12)
		_add(t0, _pluck(float(ch[0]) - 12.0, 1.8, 0.2), 0.22)
		for k in 4:
			var m3: int = mel[b * 4 + k]
			var dur := beat * (1.9 if k == 3 else 0.95)
			_add(t0 + k * beat, _horn(float(m3), dur), 0.17)
			if b >= 16:
				_add(t0 + k * beat, _horn(float(m3) - 12.0, dur), 0.09)
	_reverb(0.25)


func _sala_comun() -> void:
	var beat := 60.0 / 120.0
	var eighth := beat / 3.0
	var bar := beat * 2.0
	var prog := [[43, 46, 50], [41, 45, 48], [43, 46, 50], [48, 52, 55], [43, 46, 50], [41, 45, 48], [38, 41, 45], [43, 46, 50]]
	var prog_b := [[46, 50, 53], [41, 45, 48], [48, 52, 55], [43, 46, 50], [46, 50, 53], [48, 52, 55], [38, 42, 45], [43, 46, 50]]
	var chords: Array = prog + prog + prog_b + prog_b
	var scale := [7, 9, 10, 12, 14, 16, 17, 19]
	_alloc(chords.size() * bar)
	var mel: Array = _melody(prog, scale, 6, 60, 31) + _melody(prog, scale, 6, 60, 31) + _melody(prog_b, scale, 6, 60, 37) + _melody(prog_b, scale, 6, 60, 41)
	rng.seed = 9
	for b in chords.size():
		var ch: Array = chords[b]
		var t0 := b * bar
		for k in 6:
			var m: int = ch[[0, 2, 1, 0, 2, 1][k]]
			_add(t0 + k * eighth, _pluck(float(m), 0.7, 0.3), 0.13 if k % 3 == 0 else 0.08)
		_add(t0, _drum(43.0, 0.35, 0.35), 0.3)
		_add(t0 + beat, _drum(43.0, 0.35, 0.35), 0.26)
		_add(t0 + eighth * 2.0, _drum(50.0, 0.2, 0.6), 0.08)
		_add(t0 + beat + eighth * 2.0, _drum(50.0, 0.2, 0.6), 0.08)
		for k in 6:
			var m4: int = mel[b * 6 + k]
			if k % 3 == 1 and rng.randf() < 0.3:
				continue
			_add(t0 + k * eighth, _flute(float(m4) + 12.0, eighth * (2.0 if k % 3 == 2 else 0.95)), 0.16)
	_reverb(0.3)
