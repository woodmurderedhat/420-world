extends Node

signal character_created(char_id: String)
signal character_deleted(char_id: String)
signal character_stats_changed(char_id: String)
signal character_category_changed(char_id: String)
signal slot_count_changed(count: int)

const CHARACTERS_DIR = "res://data/characters/"
const CHARACTERS_FILE = CHARACTERS_DIR + "characters.json"
const GRAVEYARD_PATH = "res://data/characters/graveyard/character_graveyard.json"

var characters: Dictionary = {} # id -> data
var graveyard: Array = []
# When true, created characters will be moved to `player_created` folder for later cleanup
var archive_on_create: bool = false
# Opt-in: when migrating legacy per-character files into `characters.json`, remove the legacy per-file JSONs and any per-character item manifests
@export var cleanup_legacy_files_on_migrate: bool = false
# Should deleting a character also purge its item container? (configurable)
@export var purge_containers_on_delete: bool = false
# Path fragment for player-created characters
const PLAYER_CREATED_SUBDIR := "player_created/"
@onready var CHARACTER_SCHEMA_VALIDATOR := preload("res://scripts/validators/character_schema_validator.gd").new()

func _ready() -> void:
	var core: Node = get_tree().root.get_node_or_null("/root/CoreRuntime")
	if core != null:
		core.register_service("CharacterManager")
	
	_ensure_dirs()
	_load_characters()
	_load_graveyard()

func _ensure_dirs() -> void:
	if not DirAccess.dir_exists_absolute(CHARACTERS_DIR):
		DirAccess.make_dir_absolute(CHARACTERS_DIR)

func _load_characters() -> void:
	# Prefer a single aggregated characters file for performance and simplicity
	if FileAccess.file_exists(ProjectSettings.globalize_path(CHARACTERS_FILE)):
		var f = FileAccess.open(CHARACTERS_FILE, FileAccess.READ)
		if f:
			var j = JSON.new()
			if j.parse(f.get_as_text()) == OK:
				var data = j.data
				# Expect data to be dictionary id -> char_data
				if typeof(data) == TYPE_DICTIONARY:
					for k in data.keys():
						var c = data[k]
						var res = CHARACTER_SCHEMA_VALIDATOR.validate(c)
						if res["ok"]:
							# Use sanitized version if provided
							if res.has("sanitized") and res["sanitized"] != null:
								characters[k] = res["sanitized"]
							else:
								characters[k] = c
						else:
							Log.error("CharacterManager: rejected character %s due to validation errors: %s" % [k, String(res["errors"])])
	else:
		# Fallback: legacy per-file loading (migrate to single file after reading)
		var dir = DirAccess.open(CHARACTERS_DIR)
		var legacy_cids: Array = []
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".json"):
					# Skip central aggregated file if present
					if file_name == "characters.json":
						file_name = dir.get_next()
						continue
					_load_character_file(CHARACTERS_DIR + file_name)
					legacy_cids.append(file_name.replace(".json", ""))
				file_name = dir.get_next()
			# Persist migration to single file to reduce future FS churn
			_save_all_characters()

			# If user opted-in, remove legacy files and any per-character item manifests
			if cleanup_legacy_files_on_migrate and legacy_cids.size() > 0:
				for fname in legacy_cids:
					var legacy_abs = ProjectSettings.globalize_path(CHARACTERS_DIR + fname + ".json")
					if FileAccess.file_exists(legacy_abs):
						DirAccess.remove_absolute(legacy_abs)
						Log.info("CharacterManager: removed legacy character file %s.json" % fname)
					# Also remove per-character item_manifest if present
					var manifest_abs = ProjectSettings.globalize_path("res://data/items/%s/item_manifest.json" % fname)
					if FileAccess.file_exists(manifest_abs):
						DirAccess.remove_absolute(manifest_abs)
						Log.info("CharacterManager: removed legacy item_manifest for %s" % fname)
				# Optionally remove items dirs if empty
				for fname in legacy_cids:
					var items_dir_abs = ProjectSettings.globalize_path("res://data/items/%s/" % fname)
					var idir = DirAccess.open(items_dir_abs)
					if idir != null:
						idir.list_dir_begin()
						var child = idir.get_next()
						var empty = true
						while child != "":
							if not idir.current_is_dir():
								empty = false
								break
							child = idir.get_next()
						idir.list_dir_end()
						if empty:
							DirAccess.remove_absolute(items_dir_abs)
							Log.info("CharacterManager: removed empty items dir for %s" % fname)

	# Also register them as items
	for char_id in characters:
		if not characters[char_id].get("deleted", false):
			_register_character_as_item(char_id)

	slot_count_changed.emit(get_active_character_count())

func _load_character_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		var c_data = json.data
		if typeof(c_data) == TYPE_DICTIONARY and c_data.has("id"):
			var res = CHARACTER_SCHEMA_VALIDATOR.validate(c_data)
			if res["ok"]:
				if res.has("sanitized") and res["sanitized"] != null:
					characters[c_data["id"]] = res["sanitized"]
				else:
					characters[c_data["id"]] = c_data
			else:
				Log.error("CharacterManager: rejected legacy character %s due to validation errors: %s" % [c_data.get("id", "<no-id>"), String(res["errors"])])

func _save_character(char_id: String) -> void:
	# Persist entire characters collection atomically to a single file
	_save_all_characters()

func _load_graveyard() -> void:
	if FileAccess.file_exists(GRAVEYARD_PATH):
		var file = FileAccess.open(GRAVEYARD_PATH, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				graveyard = json.data


func _save_all_characters() -> void:
	# Ensure directory exists
	_ensure_dirs()
	var path = CHARACTERS_FILE
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(characters, "\t"))
		file.close()
	else:
		Log.error("CharacterManager: failed to open characters file for write: %s" % path)

func _save_graveyard() -> void:
	var file = FileAccess.open(GRAVEYARD_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(graveyard, "\t"))
		file.close()
	else:
		Log.error("CharacterManager: failed to open graveyard file for write: %s" % GRAVEYARD_PATH)

func _register_character_as_item(char_id: String) -> void:
	var c_data = characters[char_id]
	# Generate dynamic icon if possible
	var icon_path = CharacterRenderer.save_icon(char_id, c_data.get("body_parts", {}))
	var item_def = {
		"id": char_id,
		"name": c_data.get("name", "Unknown Character"),
		"description": "A custom character.",
		"category": "character",
		"icon": icon_path if icon_path != "" else "res://assets/icons/default_app.svg",
		"stackable": false,
		"value": 0,
		"bound_to_character": false
	}
	ItemRegistry.register_item(item_def)

	# Ensure container exists
	InventoryManager.create_container(char_id, c_data.get("inventory_capacity", 10))

# --- Player-created character archival helpers ---
func _ensure_player_created_dir() -> void:
	var abs_dir = ProjectSettings.globalize_path(CHARACTERS_DIR + PLAYER_CREATED_SUBDIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_absolute(abs_dir)

func _move_character_to_player_created(char_id: String) -> void:
	# Legacy support: if there exists a per-character file on disk, move it to player_created
	var old_rel = CHARACTERS_DIR + char_id + ".json"
	var old_abs = ProjectSettings.globalize_path(old_rel)
	var target_rel = CHARACTERS_DIR + PLAYER_CREATED_SUBDIR + char_id + ".json"
	var target_abs = ProjectSettings.globalize_path(target_rel)
	_ensure_player_created_dir()
	if FileAccess.file_exists(old_abs):
		var fr = FileAccess.open(old_abs, FileAccess.READ)
		if fr:
			var contents = fr.get_as_text()
			fr.close()
			var fw = FileAccess.open(target_abs, FileAccess.WRITE)
			if fw:
				fw.store_string(contents)
				fw.close()
			DirAccess.remove_absolute(old_abs)
			Log.info("CharacterManager: moved %s to player_created folder (legacy file)" % char_id)
	# New behavior: mark the character as archived in the central file
	if characters.has(char_id):
		characters[char_id]["_archived"] = true
		_save_all_characters()
		Log.info("CharacterManager: marked %s as archived" % char_id)

func cleanup_player_created_characters() -> void:
	# Clean up both legacy per-file archived characters and newly-archived entries in the central characters file
	# 1) Legacy per-file artifacts
	var abs_dir = ProjectSettings.globalize_path(CHARACTERS_DIR + PLAYER_CREATED_SUBDIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		var dir = DirAccess.open(abs_dir)
		if dir != null:
			dir.list_dir_begin()
			var fname = dir.get_next()
			while fname != "":
				if not dir.current_is_dir() and fname.ends_with(".json"):
					var cid = fname.replace(".json", "")
					# Soft-delete if still present
					if characters.has(cid) and not characters[cid].get("deleted", false):
						soft_delete_character(cid)
					# Remove file
					var fpath = abs_dir.path_join(fname)
					if FileAccess.file_exists(fpath):
						DirAccess.remove_absolute(fpath)
					# Also remove item manifest for the char if present
					var manifest_abs = ProjectSettings.globalize_path("res://data/items/%s/item_manifest.json" % cid)
					if FileAccess.file_exists(manifest_abs):
						DirAccess.remove_absolute(manifest_abs)
				# Remove items dir if empty
					var items_dir_abs = ProjectSettings.globalize_path("res://data/items/%s/" % cid)
					var idir = DirAccess.open(items_dir_abs)
					if idir != null:
						idir.list_dir_begin()
						var child = idir.get_next()
						var empty = true
						while child != "":
							if not idir.current_is_dir():
								empty = false
								break
							child = idir.get_next()
						idir.list_dir_end()
						if empty:
							DirAccess.remove_absolute(items_dir_abs)
					Log.info("CharacterManager: cleaned up legacy archived character %s" % cid)
			fname = dir.get_next()
			dir.list_dir_end()

	# 2) New-style archives recorded in the central characters dictionary
	var removed: Array = []
	for cid in characters.keys():
		if characters[cid].get("_archived", false):
			# Soft-delete if not already
			if not characters[cid].get("deleted", false):
				soft_delete_character(cid)
			# Remove entry from central registry
			removed.append(cid)
	for cid in removed:
		characters.erase(cid)
		Log.info("CharacterManager: removed archived character %s from central registry" % cid)
	# Persist changes
	_save_all_characters()

# --- Public API ---

func get_all_characters() -> Array:
	return characters.values().filter(func(c): return not c.get("deleted", false))

# Return a manifest (array of simplified character entries) for quick listing UIs
func get_characters_manifest() -> Array:
	var result: Array = []
	for cid in characters.keys():
		var c = characters[cid]
		if c.get("deleted", false):
			continue
		# Minimal manifest fields (can be extended as needed)
		var m: Dictionary = {
			"id": c.get("id", cid),
			"name": c.get("name", "Unnamed"),
			"category": c.get("category", ""),
			"created_date": c.get("created_date", ""),
			"body_parts": c.get("body_parts", {}),
			"stats": c.get("stats", {})
		}
		result.append(m)
	return result

func get_character(char_id: String) -> Dictionary:
	return characters.get(char_id, {})

func get_character_stats(char_id: String) -> Dictionary:
	return get_character(char_id).get("stats", {})

func get_active_character_count() -> int:
	var count = 0
	for cid in characters:
		if not characters[cid].get("deleted", false):
			count += 1
	return count

func can_create_character() -> bool:
	return get_active_character_count() < UserManager.get_character_slots_owned()

func is_name_taken(name_str: String) -> bool:
	for cid in characters:
		if not characters[cid].get("deleted", false):
			if characters[cid].get("name", "") == name_str:
				return true
	return false

func create_character(char_name: String, category: String, body_parts: Dictionary, stats: Dictionary) -> bool:
	if not can_create_character():
		return false
	if is_name_taken(char_name):
		return false
		
	# Create a deterministic-ish id using timestamp + hash of body parts
	var body_str = JSON.stringify(body_parts)
	var h: int = 0
	for i in range(body_str.length()):
		h = (h * 31 + ord(body_str[i])) % 1000000
	var char_id = "char_%d_%d" % [Time.get_unix_time_from_system(), h]
	
	var new_char = {
		"id": char_id,
		"name": char_name,
		"category": category,
		"body_parts": body_parts,
		"stats": stats,
		"inventory_capacity": 10,
		"created_date": Time.get_datetime_string_from_system(),
		"deleted": false
	}

	# Validate or sanitize before persisting
	var validation = CHARACTER_SCHEMA_VALIDATOR.validate(new_char)
	if not validation["ok"]:
		if validation.has("sanitized") and validation["sanitized"] != null:
			new_char = validation["sanitized"]
			Log.warn("CharacterManager: sanitized character before creation: %s" % String(validation["errors"]))
		else:
			Log.error("CharacterManager: rejected create_character call due to validation errors: %s" % String(validation["errors"]))
			return false

	characters[char_id] = new_char
	# Persist collection
	_save_all_characters()

	# Register as an item in ItemRegistry (no on-disk item_manifest per-character to avoid filesystem churn)
	_register_character_as_item(char_id)
	InventoryManager.add_item(char_id, 1)
	InventoryManager.create_container(char_id, new_char.get("inventory_capacity", 10))
	Log.info("CharacterManager: created %s" % char_id)
	# Optionally mark the character as archived so cleanup can remove it later (avoids per-file moves)
	if archive_on_create:
		characters[char_id]["_archived"] = true
		_save_all_characters()
	# Emit signals so other systems can react
	character_created.emit(char_id)
	character_category_changed.emit(char_id)
	slot_count_changed.emit(get_active_character_count())
	return true

func modify_stat(char_id: String, stat_name: String, delta: int) -> bool:
	if not characters.has(char_id): return false
	var stats = characters[char_id].get("stats", {})
	if not stats.has(stat_name): return false
	
	var val = stats[stat_name]
	var new_val = val + delta
	
	# Clamp 1-99 for now
	if new_val < 1: new_val = 1
	if new_val > 99: new_val = 99
	
	stats[stat_name] = new_val
	characters[char_id]["stats"] = stats
	_save_character(char_id)
	
	character_stats_changed.emit(char_id)
	return true

func soft_delete_character(char_id: String) -> void:
	if not characters.has(char_id): return
	
	var c = characters[char_id]
	c["deleted"] = true
	_save_character(char_id)
	
	# Add to graveyard
	var epitaph = {
		"name": c["name"],
		"deletion_date": Time.get_datetime_string_from_system(),
		"highest_stat": _get_highest_stat(c.get("stats", {})),
		"final_gold": c.get("stats", {}).get("gold", 0),
		"container_purged": false
	}
	# Optionally purge container when deleting
	if purge_containers_on_delete:
		InventoryManager.delete_container(char_id)
		epitaph["container_purged"] = true

	graveyard.append(epitaph)
	_save_graveyard()

	# Remove from global inventory
	InventoryManager.remove_item(char_id, 1)
	# Note: container retention policy is configurable via purge_containers_on_delete
	
	character_deleted.emit(char_id)
	slot_count_changed.emit(get_active_character_count())

func _get_highest_stat(stats: Dictionary) -> Dictionary:
	var highest = { "name": "None", "value": 0 }
	for k in stats:
		if k == "gold": continue
		if stats[k] > highest["value"]:
			highest = { "name": k, "value": stats[k] }
	return highest

func get_graveyard() -> Array:
	return graveyard

func clear_graveyard() -> void:
	graveyard.clear()
	_save_graveyard()

func clear_all_characters() -> void:
	# Clear in-memory character registry and graveyard for test/setup purposes.
	for cid in characters.keys():
		# Note: we intentionally do not remove item manifests on disk to avoid destructive behavior
		# during normal runtime, but clearing in-memory state helps tests run in isolation.
		pass
	characters.clear()
	graveyard.clear()
	_save_graveyard()
	slot_count_changed.emit(get_active_character_count())

func purge_graveyard_entry(index: int) -> void:
	if index < 0 or index >= graveyard.size():
		return
	graveyard.remove_at(index)
	_save_graveyard()

func export_character(char_id: String) -> String:
	var c = get_character(char_id)
	if c.is_empty():
		return ""
	var exports_dir = ProjectSettings.globalize_path("user://exports/")
	if not DirAccess.dir_exists_absolute(exports_dir):
		DirAccess.make_dir_absolute(exports_dir)
	var ts = str(Time.get_unix_time_from_system()).replace(".", "")
	var safe_name = c.get("name", "character").replace(" ", "_")
	var path = exports_dir + "character_%s_%s.json" % [safe_name, ts]
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(c, "\t"))
		f.close()
		Log.info("CharacterManager: exported character %s to %s" % [char_id, path])
		return path
	else:
		Log.error("CharacterManager: failed to export character %s to %s" % [char_id, path])
		return ""

func get_character_inventory_count(char_id: String) -> int:
	var slots_arr = InventoryManager.get_container_slots(char_id)
	var total = 0
	for s in slots_arr:
		if s != null:
			total += s.get("count", 0)
	return total

func purchase_character_slot() -> void:
	# Emits a shop_open event; external shop handles the purchase flow and should call UserManager.add_character_slots on success
	EventBus.emit_event("shop_open", {"item": "character_slot", "cost": 100})
