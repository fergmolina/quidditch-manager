class_name SaveManager
extends RefCounted
## Saving and loading games in user://saves/<name>/.

static var saves_dir := "user://saves"
const AUTOSAVE_PREFIX := "autosave_"
const AUTOSAVE_SLOTS := [AUTOSAVE_PREFIX + "1", AUTOSAVE_PREFIX + "2"]
## Longest slot folder derived from a manager's name.
const SLOT_NAME_MAX_CHARS := 48
## Largest `.qmsave` the import accepts and largest size its parts may inflate to.
const MAX_IMPORT_BYTES := 64 * 1024 * 1024
const MAX_WORLD_BYTES := 512 * 1024 * 1024
const MAX_META_BYTES := 1024 * 1024
## Folder names Windows refuses whatever the extension.
const _RESERVED_NAMES := ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8",
	"COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]

## The last save written: its folder, the "saved_at" and "save_id" of its meta.json.
static var last_saved_dir := ""
static var last_saved_at := ""
static var last_save_id := ""
static var _save_count := 0


static func save_dir(name: String) -> String:
	return saves_dir.path_join(name.validate_filename())


static func is_autosave_slot(dir_name: String) -> bool:
	return AUTOSAVE_SLOTS.has(dir_name)


## Writes the world and its meta.json. Each file is written next to the old one (".tmp"), checked, and only then
## moved over it, so a full disk or a crash mid-write leaves the previous save intact.
static func save(w: World, name: String) -> Error:
	if Platform.writes_blocked():
		return ERR_UNAVAILABLE
	w.normalize_floats()
	var dir := save_dir(name)
	DirAccess.make_dir_recursive_absolute(dir)
	var world_path := dir.path_join("world.json.gz")
	var meta_path := dir.path_join("meta.json")
	# full_precision: floats round-trip exactly.
	var text := JSON.stringify(w.to_dict(), "", false, true)
	var f := FileAccess.open_compressed(world_path + ".tmp", FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	if f == null:
		return FileAccess.get_open_error()
	var stored := f.store_string(text)
	var written := f.get_length()
	f.close()
	if not stored or not _check_compressed(world_path + ".tmp", written, text.right(32)):
		DirAccess.remove_absolute(world_path + ".tmp")
		return ERR_FILE_CANT_WRITE
	var saved_at := Time.get_datetime_string_from_system()
	_save_count += 1
	var save_id := "%d-%d" % [Time.get_ticks_usec(), _save_count]
	var meta_text := JSON.stringify({"name": name, "schema": World.SCHEMA_VERSION, "pack": w.pack, "today": WDate.to_iso(w.today),
		"season": w.season, "club_id": w.player_club_id, "club_name": (w.my_club().name if w.my_club() else ""),
		"manager": w.manager.get("name", ""), "saved_at": saved_at, "saved_unix": int(Time.get_unix_time_from_system()),
		"save_id": save_id, "career_id": w.career_id})
	var meta := FileAccess.open(meta_path + ".tmp", FileAccess.WRITE)
	if meta == null:
		var open_err := FileAccess.get_open_error()
		DirAccess.remove_absolute(world_path + ".tmp")
		return open_err
	stored = meta.store_string(meta_text)
	meta.close()
	if not stored or FileAccess.get_file_as_string(meta_path + ".tmp") != meta_text:
		DirAccess.remove_absolute(world_path + ".tmp")
		DirAccess.remove_absolute(meta_path + ".tmp")
		return ERR_FILE_CANT_WRITE
	var err := _commit(world_path, meta_path)
	if err == OK:
		last_saved_dir = dir.get_file()
		last_saved_at = saved_at
		last_save_id = save_id
	return err


## Moves both checked ".tmp" files over the save, the world first: a crash in between leaves a meta.json one save
## behind its world, never a meta.json whose world is missing or half written.
static func _commit(world_path: String, meta_path: String) -> Error:
	var err := _replace(world_path + ".tmp", world_path)
	if err != OK:
		DirAccess.remove_absolute(meta_path + ".tmp")
		return err
	return _replace(meta_path + ".tmp", meta_path)


## A compressed file reads back with the expected length and ends with the expected text. Seeking to the end makes
## Godot decompress the last block, so a file cut short by a failed write doesn't pass.
static func _check_compressed(path: String, length: int, tail: String) -> bool:
	var rf := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	if rf == null:
		return false
	var tail_bytes := tail.to_utf8_buffer()
	var ok := rf.get_length() == length and length >= tail_bytes.size()
	if ok:
		rf.seek(length - tail_bytes.size())
		ok = rf.get_buffer(tail_bytes.size()) == tail_bytes
	rf.close()
	return ok


## Moves `from` over `to`. Where the rename can't replace an existing file (Windows), the old one is removed first;
## load() then falls back to the finished ".tmp" if the game stops in between.
static func _replace(from: String, to: String) -> Error:
	if DirAccess.rename_absolute(from, to) == OK:
		return OK
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	if DirAccess.rename_absolute(from, to) == OK:
		return OK
	return ERR_FILE_CANT_WRITE


static func load(name: String) -> World:
	var path := save_dir(name).path_join("world.json.gz")
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".tmp"):
		path += ".tmp"
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
	if f == null:
		return null
	if f.get_length() > MAX_WORLD_BYTES:
		f.close()
		return null
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary) or not _valid_world(data):
		return null
	var w := World.from_dict(data)
	# JSON floats do not always round-trip bit for bit (Godot 4.7): snapping again on load gives back exactly the
	# values that were saved, so a loaded game simulates as the running one would have.
	w.normalize_floats()
	return w


## A world of this build's schema, no other: there is no migration path, so a save of any other schema is refused.
static func _valid_world(d: Dictionary) -> bool:
	if not _is_current_schema(d.get("schema", 0)):
		return false
	for key in ["clubs", "players", "competitions"]:
		var coll = d.get(key)
		if not (coll is Dictionary):
			return false
		for v in coll.values():
			if not (v is Dictionary) or not v.has("id"):
				return false
	for key in World.ARRAY_FIELDS:
		if d.has(key) and not (d[key] is Array):
			return false
	for key in World.DICT_FIELDS:
		if d.has(key) and not (d[key] is Dictionary):
			return false
	return not d.has("owls") or d["owls"] is Dictionary


static func _is_current_schema(schema: Variant) -> bool:
	return (schema is int or schema is float) and int(schema) == World.SCHEMA_VERSION


## The career id written in a slot's meta.json; "" when there is no save there.
static func slot_career_id(name: String) -> String:
	var mf := FileAccess.open(save_dir(name).path_join("meta.json"), FileAccess.READ)
	if mf == null:
		return ""
	var m = JSON.parse_string(mf.get_as_text())
	return str(m.get("career_id", "")) if m is Dictionary else ""


## The slot a career derived from `base` may save to without taking another career's save: `base` itself when
## nothing is there or it already holds this career, else "base_2", "base_3"… A folder whose meta has no career id
## (not written by this game) is left alone too. `base` goes through clean_save_name ("save" if nothing is left of it).
static func free_slot_for(base: String, career_id: String) -> String:
	var b := clean_save_name(base)
	if b == "":
		b = "save"
	var name := b
	var n := 2
	while DirAccess.dir_exists_absolute(save_dir(name)):
		if slot_career_id(name) == career_id:
			break
		name = "%s_%d" % [b, n]
		n += 1
	return name


static func list_saves() -> Array:
	var out := []
	var d := DirAccess.open(saves_dir)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir() and not n.begins_with("_"):
			var mf := FileAccess.open(saves_dir.path_join(n).path_join("meta.json"), FileAccess.READ)
			if mf != null:
				var m = JSON.parse_string(mf.get_as_text())
				if m is Dictionary:
					m["dir"] = n
					if is_autosave_slot(n):
						m["name"] = TranslationServer.translate("ui.saves.autosave_slot") % (AUTOSAVE_SLOTS.find(n) + 1)
					out.append(m)
		n = d.get_next()
	d.list_dir_end()
	out.sort_custom(func(a, b): return str(a.get("saved_at", "")) > str(b.get("saved_at", "")))
	return out


## A save as one portable file (`.qmsave`, a zip of meta.json + world.json.gz), to download in the browser or
## copy between computers. Empty if the save does not exist.
static func export_file(name: String) -> PackedByteArray:
	if Platform.writes_blocked():
		return PackedByteArray()
	var dir := save_dir(name)
	var tmp := "user://_export.qmsave"
	var zip := ZIPPacker.new()
	if zip.open(tmp) != OK:
		return PackedByteArray()
	for f in ["meta.json", "world.json.gz"]:
		var bytes := FileAccess.get_file_as_bytes(dir.path_join(f))
		if bytes.is_empty():
			zip.close()
			DirAccess.remove_absolute(tmp)
			return PackedByteArray()
		zip.start_file(f)
		zip.write_file(bytes)
		zip.close_file()
	zip.close()
	var out := FileAccess.get_file_as_bytes(tmp)
	DirAccess.remove_absolute(tmp)
	return out


## Adds a `.qmsave` file to the saved games. Returns the new save's folder name, or "" if the file is not a valid
## save (not a zip, too big, missing parts, a world that wouldn't load, or a schema other than this version's).
## Nothing from the file is executed.
static func import_file(bytes: PackedByteArray) -> String:
	if Platform.writes_blocked() or bytes.is_empty() or bytes.size() > MAX_IMPORT_BYTES:
		return ""
	# ZIPReader inflates a whole entry at the size its header declares, so the declared sizes are checked first.
	var sizes := _zip_sizes(bytes)
	if int(sizes.get("meta.json", MAX_META_BYTES + 1)) > MAX_META_BYTES or int(sizes.get("world.json.gz", MAX_WORLD_BYTES + 1)) > MAX_WORLD_BYTES:
		return ""
	var tmp := "user://_import.qmsave"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return ""
	var stored := f.store_buffer(bytes)
	f.close()
	var zip := ZIPReader.new()
	var ok := stored and zip.open(tmp) == OK
	var meta_bytes := zip.read_file("meta.json") if ok and zip.file_exists("meta.json") else PackedByteArray()
	var world_bytes := zip.read_file("world.json.gz") if ok and zip.file_exists("world.json.gz") else PackedByteArray()
	if ok:
		zip.close()
	DirAccess.remove_absolute(tmp)
	var meta = JSON.parse_string(meta_bytes.get_string_from_utf8())
	if not (meta is Dictionary) or world_bytes.is_empty():
		return ""
	if not _is_current_schema(meta.get("schema", 0)):
		return ""
	# world.json.gz is Godot's compressed-file format (FileAccess.open_compressed), so it is checked by reading it back
	# the same way the game loads it.
	var check_path := "user://_import_world.gz"
	var cf := FileAccess.open(check_path, FileAccess.WRITE)
	if cf == null:
		return ""
	stored = cf.store_buffer(world_bytes)
	cf.close()
	var world = null
	var rf: FileAccess = FileAccess.open_compressed(check_path, FileAccess.READ, FileAccess.COMPRESSION_GZIP) if stored else null
	if rf != null:
		if rf.get_length() <= MAX_WORLD_BYTES:
			world = JSON.parse_string(rf.get_as_text())
		rf.close()
	DirAccess.remove_absolute(check_path)
	if not (world is Dictionary) or not _valid_world(world):
		return ""
	var base := _import_base_name(meta)
	var name := base
	var n := 2
	while DirAccess.dir_exists_absolute(save_dir(name)):
		name = "%s (%d)" % [base, n]
		n += 1
	meta["name"] = name
	var dir := save_dir(name)
	DirAccess.make_dir_recursive_absolute(dir)
	var wf := FileAccess.open(dir.path_join("world.json.gz"), FileAccess.WRITE)
	stored = wf != null and wf.store_buffer(world_bytes)
	if wf != null:
		wf.close()
	var mf: FileAccess = FileAccess.open(dir.path_join("meta.json"), FileAccess.WRITE) if stored else null
	stored = mf != null and mf.store_string(JSON.stringify(meta))
	if mf != null:
		mf.close()
	if not stored:
		delete_save(name)
		return ""
	return name.validate_filename()


static func _import_base_name(meta: Dictionary) -> String:
	for candidate in [meta.get("name", ""), meta.get("club_name", ""), meta.get("manager", "")]:
		var base := clean_save_name(str(candidate)).validate_filename()
		if base != "":
			return base
	return "save"


## A save name typed by the player (or carried by an imported save), made usable: no leading "_" (list_saves hides
## those folders) and no trailing dots or spaces (Windows drops them). "" if nothing is left or the name is reserved:
## an autosave slot, which the next autosave would overwrite, or a name Windows refuses.
static func clean_save_name(name: String) -> String:
	var base := name.strip_edges().lstrip("_").strip_edges().rstrip(". ")
	var folder := base.validate_filename()
	if folder == "" or folder.begins_with("_") or folder.to_lower().begins_with(AUTOSAVE_PREFIX):
		return ""
	if _RESERVED_NAMES.has(folder.split(".")[0].strip_edges().to_upper()):
		return ""
	return base


## Uncompressed size of each entry, from the zip's central directory ({} if it isn't a zip). Zip64 entries (and any
## entry over 4 GB) read as too big.
static func _zip_sizes(b: PackedByteArray) -> Dictionary:
	var out := {}
	var eocd := -1
	var i := b.size() - 22
	var stop := maxi(b.size() - 22 - 65535, 0)
	while i >= stop:
		if b[i] == 0x50 and b[i + 1] == 0x4b and b[i + 2] == 0x05 and b[i + 3] == 0x06:
			eocd = i
			break
		i -= 1
	if eocd < 0:
		return out
	var count := b.decode_u16(eocd + 10)
	var p := b.decode_u32(eocd + 16)
	for _e in count:
		if p + 46 > b.size() or b.decode_u32(p) != 0x02014b50:
			return {}
		var name_len := b.decode_u16(p + 28)
		if p + 46 + name_len > b.size():
			return {}
		var entry := b.slice(p + 46, p + 46 + name_len).get_string_from_utf8()
		out[entry] = maxi(int(out.get(entry, 0)), b.decode_u32(p + 24))
		p += 46 + name_len + b.decode_u16(p + 30) + b.decode_u16(p + 32)
	return out


static func delete_save(name: String) -> void:
	if Platform.writes_blocked():
		return
	var dir := save_dir(name)
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)
