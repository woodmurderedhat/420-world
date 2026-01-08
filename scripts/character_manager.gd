extends Node

signal character_created(char_id: String)
signal character_deleted(char_id: String)
signal character_stats_changed(char_id: String)
signal character_category_changed(char_id: String)
signal slot_count_changed(count: int)

const CHARACTERS_DIR = "user://characters/"
const GRAVEYARD_PATH = "user://character_graveyard.json"

var characters: Dictionary = {} # id -> data
var graveyard: Array = []

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
	var dir = DirAccess.open(CHARACTERS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				_load_character_file(CHARACTERS_DIR + file_name)
			file_name = dir.get_next()
			
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
		if c_data.has("id"):
			characters[c_data["id"]] = c_data

func _save_character(char_id: String) -> void:
	if not characters.has(char_id): return
	var path = CHARACTERS_DIR + char_id + ".json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(characters[char_id], "\t"))

func _load_graveyard() -> void:
	if FileAccess.file_exists(GRAVEYARD_PATH):
		var file = FileAccess.open(GRAVEYARD_PATH, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				graveyard = json.data

func _save_graveyard() -> void:
	var file = FileAccess.open(GRAVEYARD_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(graveyard, "\t"))

func _register_character_as_item(char_id: String) -> void:
	var c_data = characters[char_id]
	var item_def = {
		"id": char_id,
		"name": c_data.get("name", "Unknown Character"),
		"description": "A custom character.",
		"category": "character",
		"icon": "res://assets/icons/default_app.svg", # TODO: Dynamic icon
		"stackable": false,
		"value": 0,
		"bound_to_character": false
	}
	ItemRegistry.register_item(item_def)
	
	# Ensure container exists
	InventoryManager.create_container(char_id, c_data.get("inventory_capacity", 10))

# --- Public API ---

func get_all_characters() -> Array:
	return characters.values().filter(func(c): return not c.get("deleted", false))

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
	
	characters[char_id] = new_char
	_save_character(char_id)
	
	# Write an item manifest under data/items/<char_id>/item_manifest.json so other tools can see this character as an item
	var target_dir_abs = ProjectSettings.globalize_path("res://data/items/%s/" % char_id)
	if not DirAccess.dir_exists_absolute(target_dir_abs):
		DirAccess.make_dir_absolute(target_dir_abs)
	var manifest_path = target_dir_abs + "item_manifest.json"
	var manifest = {
		"id": char_id,
		"name": char_name,
		"description": "A custom character.",
		"category": "character",
		"icon": "res://assets/icons/default_app.svg",
		"stackable": false,
		"value": 0,
		"bound_to_character": false
	}
	var mf = FileAccess.open(manifest_path, FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify(manifest, "\t"))

	_register_character_as_item(char_id)
	InventoryManager.add_item(char_id, 1)
	InventoryManager.create_container(char_id, new_char.get("inventory_capacity", 10))
	Log.info("CharacterManager: created %s" % char_id)
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
		"final_gold": c.get("stats", {}).get("gold", 0)
	}
	graveyard.append(epitaph)
	_save_graveyard()
	
	# Remove from global inventory
	InventoryManager.remove_item(char_id, 1)
	# Do NOT delete container - keep items? Or should we? Design doesn't say. 
	# Safest is to keep container or perhaps empty it.
	
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
		return path
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
