class_name Settings
extends RefCounted
## UI preferences persisted in user://settings.cfg. Applied by rebuilding the theme.

const PATH := "user://settings.cfg"
const TEXT_SCALES := [["1.0", "100 %"], ["1.15", "115 %"], ["1.3", "130 %"]]
const DENSITIES := ["compact", "comfortable"]

static var text_scale: float = 1.0
static var density: String = "compact"
static var language: String = "en"
## Game languages (Godot locale code, name in its own language).
const LANGUAGES := [["es", "Español"], ["en", "English"], ["de", "Deutsch"], ["fr", "Français"], ["it", "Italiano"],
	["pt_BR", "Português (Brasil)"], ["nl", "Nederlands"], ["ru", "Русский"], ["ja", "日本語"], ["zh_CN", "简体中文"]]
static var sfx_volume: float = 0.8
static var music_volume: float = 0.5
static var tutorial: bool = true   # welcome owls with tips at game start
static var music_track: String = "partido"   # office | match | common room | classic
const MUSIC_TRACKS := ["despacho", "partido", "sala_comun", "clasico"]


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	text_scale = clampf(float(cfg.get_value("ui", "text_scale", 1.0)), 1.0, 1.3)
	density = str(cfg.get_value("ui", "density", "compact"))
	if not DENSITIES.has(density):
		density = "compact"
	language = str(cfg.get_value("ui", "language", "en"))
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", 0.5)), 0.0, 1.0)
	tutorial = bool(cfg.get_value("game", "tutorial", true))
	music_track = str(cfg.get_value("audio", "music_track", "partido"))
	if not MUSIC_TRACKS.has(music_track):
		music_track = "partido"


static func save_settings() -> void:
	if Platform.writes_blocked():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "text_scale", text_scale)
	cfg.set_value("ui", "density", density)
	cfg.set_value("ui", "language", language)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("game", "tutorial", tutorial)
	cfg.set_value("audio", "music_track", music_track)
	cfg.save(PATH)


## Table row height by density.
static func row_height() -> int:
	return int((26 if density == "compact" else 32) * text_scale)


static func px(size: int) -> int:
	return int(round(size * text_scale))
