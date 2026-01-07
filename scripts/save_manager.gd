extends Node

const GLOBAL_SAVE_PATH := "user://global_save.json"
const APPS_SAVE_DIR := "user://apps"
const DEBUG_BUNDLE_PATH := "user://debug.zip"

const SCHEMA_VERSION := 1

var _global_cache: Dictionary = {}
var _loaded_global := false
var _autosave_timer: Timer

@export var auto_save_interval_sec := 120.0

func _ready() -> void:
	var core := get_tree().root.get_node_or_null("/root/CoreRuntime")
	if core != null:
		core.register_service("SaveManager")
	_ensure_apps_dir()
	refresh_global()
	_start_autosave()

func refresh_global() -> void:
	_global_cache = _load_global_from_disk()
	_loaded_global = true
	Log.info("[SaveManager] Global save loaded (schema=%d, keys=%d)" % [int(_global_cache.get("schema_version", SCHEMA_VERSION)), _global_cache.keys().size()])

func load_global() -> Dictionary:
	if not _loaded_global:
		refresh_global()
	return _global_cache.duplicate(true)

func save_global(data: Dictionary) -> bool:
	data = _migrate_global(data)
	data["schema_version"] = SCHEMA_VERSION
	_global_cache = data.duplicate(true)
	return _write_json_with_backup(GLOBAL_SAVE_PATH, _global_cache)

func load_app(app_id: String) -> Dictionary:
	_ensure_apps_dir()
	var parsed := _load_json(_app_path(app_id), _default_app())
	return _migrate_app(app_id, parsed)

func save_app(app_id: String, data: Dictionary) -> bool:
	_ensure_apps_dir()
	data = _migrate_app(app_id, data)
	data["schema_version"] = SCHEMA_VERSION
	return _write_json_with_backup(_app_path(app_id), data)

func delete_app_save(app_id: String) -> void:
	var path := _app_path(app_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var bak := "%s.bak" % path
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(bak)

func manual_save() -> bool:
	return save_global(_global_cache)

func export_debug_bundle() -> bool:
	var zip := ZIPPacker.new()
	var err := zip.open(DEBUG_BUNDLE_PATH)
	if err != OK:
		Log.error("SaveManager: failed to open debug bundle")
		return false
	# Global save + backup
	for path in [GLOBAL_SAVE_PATH, "%s.bak" % GLOBAL_SAVE_PATH]:
		if FileAccess.file_exists(path):
			zip.add_file(_read_bytes(path), _strip_user_prefix(path))
	# App saves
	if DirAccess.dir_exists_absolute(APPS_SAVE_DIR):
		var dir := DirAccess.open(APPS_SAVE_DIR)
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var path := "%s/%s" % [APPS_SAVE_DIR, file_name]
				zip.add_file(_read_bytes(path), _strip_user_prefix(path))
				var bak := "%s.bak" % path
				if FileAccess.file_exists(bak):
					zip.add_file(_read_bytes(bak), _strip_user_prefix(bak))
			file_name = dir.get_next()
		dir.list_dir_end()
	# Manifests
	var mdir := DirAccess.open("res://apps")
	if mdir != null:
		mdir.list_dir_begin()
		var entry := mdir.get_next()
		while entry != "":
			if mdir.current_is_dir() and not entry.begins_with("."):
				var mpath := "res://apps/%s/manifest.json" % entry
				if FileAccess.file_exists(mpath):
					zip.add_file(_read_bytes(mpath), "manifests/%s.json" % entry)
			entry = mdir.get_next()
		mdir.list_dir_end()
	zip.close()
	return true

func _default_global() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"settings": {},
		"inventory": {},
	}

func _default_app() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"state": {},
	}

func _app_path(app_id: String) -> String:
	return "%s/%s.json" % [APPS_SAVE_DIR, app_id]

func _ensure_apps_dir() -> void:
	if DirAccess.dir_exists_absolute(APPS_SAVE_DIR):
		return
	DirAccess.make_dir_recursive_absolute(APPS_SAVE_DIR)

func _load_global_from_disk() -> Dictionary:
	return _migrate_global(_load_json(GLOBAL_SAVE_PATH, _default_global()))

func _load_json(path: String, fallback: Dictionary) -> Dictionary:
	var default_value: Dictionary = fallback.duplicate(true)
	var parsed := _try_load_json(path)
	if parsed.is_empty():
		var bak := "%s.bak" % path
		parsed = _try_load_json(bak)
	if parsed.is_empty():
		return default_value
	return parsed

func _write_json(path: String, data: Dictionary) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		Log.error("SaveManager: failed to write %s" % path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

func _write_json_with_backup(path: String, data: Dictionary) -> bool:
	if FileAccess.file_exists(path):
		var existing := _read_bytes(path)
		if existing.size() > 0:
			var bak := "%s.bak" % path
			var fb := FileAccess.open(bak, FileAccess.WRITE)
			if fb != null:
				fb.store_buffer(existing)
				fb.close()
	return _write_json(path, data)

func _read_bytes(path: String) -> PackedByteArray:
	var arr := PackedByteArray()
	if not FileAccess.file_exists(path):
		return arr
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return arr
	arr = f.get_buffer(f.get_length())
	f.close()
	return arr

func _strip_user_prefix(path: String) -> String:
	if path.begins_with("user://"):
		return path.trim_prefix("user://")
	return path

func _try_load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	if text.strip_edges() == "":
		return {}
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		Log.warn("SaveManager: failed to parse %s" % path)
		return {}
	var parsed: Dictionary = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		Log.warn("SaveManager: malformed data in %s" % path)
		return {}
	return parsed

func _start_autosave() -> void:
	if auto_save_interval_sec <= 0:
		return
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = false
	_autosave_timer.wait_time = auto_save_interval_sec
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(func(): save_global(_global_cache))
	add_child(_autosave_timer)

func _migrate_global(data: Dictionary) -> Dictionary:
	var migrated := _default_global()
	for k in data.keys():
		migrated[k] = data[k]
	if typeof(migrated.get("settings", {})) != TYPE_DICTIONARY:
		migrated["settings"] = {}
	if typeof(migrated.get("inventory", {})) != TYPE_DICTIONARY:
		migrated["inventory"] = {}
	migrated["schema_version"] = SCHEMA_VERSION
	return migrated

func _migrate_app(_app_id: String, data: Dictionary) -> Dictionary:
	var migrated := _default_app()
	for k in data.keys():
		migrated[k] = data[k]
	if typeof(migrated.get("state", {})) != TYPE_DICTIONARY:
		migrated["state"] = {}
	migrated["schema_version"] = SCHEMA_VERSION
	return migrated
