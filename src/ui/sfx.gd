class_name Sfx
extends RefCounted
## Synthesised sound effects and music (tools/make_sounds.gd). Volume and mute from Settings. No third-party assets.

static var _players: Dictionary = {}
static var _music: AudioStreamPlayer = null
static var _ambient: AudioStreamPlayer = null
static var _root: Node = null


static func setup(root: Node) -> void:
	_root = root


static func _stream(name: String) -> AudioStream:
	var path := "res://assets/sounds/%s.wav" % name
	return load(path) if ResourceLoader.exists(path) else null


static var _frame := -1
static var _frame_names: Dictionary = {}
static var _voices := 0
const MAX_VOICES := 8


static func play(name: String, volume_db: float = 0.0) -> void:
	if _root == null or Settings.sfx_volume <= 0.0:
		return
	var now := Engine.get_process_frames()
	if now != _frame:
		_frame = now
		_frame_names.clear()
	if _frame_names.has(name) or _voices >= MAX_VOICES:
		return
	var st := _stream(name)
	if st == null:
		return
	_frame_names[name] = true
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = volume_db + linear_to_db(Settings.sfx_volume)
	_voices += 1
	p.finished.connect(p.queue_free)
	p.tree_exited.connect(func(): _voice_done())
	_root.add_child(p)
	p.play()


static func _voice_done() -> void:
	_voices = maxi(_voices - 1, 0)


## Loops a WAV over its whole length. The end point is in frames: computed from the length, because the imported
## data is compressed (QOA), so its byte count is not the frame count.
static func _loop_whole(st: AudioStream) -> void:
	if st is AudioStreamWAV:
		var wav := st as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate))


static var _music_track := ""


static func music(on: bool) -> void:
	if _root == null:
		return
	if not on or Settings.music_volume <= 0.0:
		if _music != null:
			_music.stop()
		return
	if _music != null and _music_track != Settings.music_track:
		_music.stop()
		_music.queue_free()
		_music = null
	if _music == null:
		_music = AudioStreamPlayer.new()
		var st := _stream("theme" if Settings.music_track == "clasico" else "music_" + Settings.music_track)
		if st == null:
			st = _stream("theme")
		_loop_whole(st)
		_music.stream = st
		_music_track = Settings.music_track
		_root.add_child(_music)
	_music.volume_db = linear_to_db(Settings.music_volume) - 6.0
	if not _music.playing:
		_music.play()


static func ambient(on: bool) -> void:
	if _root == null:
		return
	if not on or Settings.sfx_volume <= 0.0:
		if _ambient != null:
			_ambient.stop()
		return
	if _ambient == null:
		_ambient = AudioStreamPlayer.new()
		var st := _stream("crowd")
		_loop_whole(st)
		_ambient.stream = st
		_root.add_child(_ambient)
	_ambient.volume_db = linear_to_db(Settings.sfx_volume) - 14.0
	if not _ambient.playing:
		_ambient.play()


static func refresh_volumes() -> void:
	if _music != null and _music.playing:
		if Settings.music_volume <= 0.0:
			_music.stop()
		else:
			_music.volume_db = linear_to_db(Settings.music_volume) - 6.0
	if _ambient != null and _ambient.playing:
		if Settings.sfx_volume <= 0.0:
			_ambient.stop()
		else:
			_ambient.volume_db = linear_to_db(Settings.sfx_volume) - 14.0
