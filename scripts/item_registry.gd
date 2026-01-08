extends Node

const ITEMS_DIR = "res://data/items/"
const DEFAULT_ICON_PATH = "res://assets/icons/default_app.svg"

var items: Dictionary = {}
var _default_icon: Texture2D

func _ready() -> void:
	_default_icon = load(DEFAULT_ICON_PATH)
	_scan_items()
	Log.info("ItemRegistry initialized. Loaded %d items." % items.size())

func _scan_items() -> void:
	var dir = DirAccess.open(ITEMS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				_load_item_from_folder(file_name)
			file_name = dir.get_next()
	else:
		Log.warn("ItemRegistry: Could not open items directory: " + ITEMS_DIR)

func _load_item_from_folder(folder_name: String) -> void:
	var manifest_path = ITEMS_DIR + folder_name + "/item_manifest.json"
	
	if not FileAccess.file_exists(manifest_path):
		return
		
	var file = FileAccess.open(manifest_path, FileAccess.READ)
	if not file:
		return
		
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		var data = json.data
		if data.has("id"):
			# Cache the icon path relative to the manifest, or absolute if user provided
			if data.has("icon") and not data["icon"].begins_with("res://"):
				data["icon"] = ITEMS_DIR + folder_name + "/" + data["icon"]
			
			items[data["id"]] = data
		else:
			Log.warn("ItemRegistry: Item manifest in %s missing 'id'" % folder_name)
	else:
		Log.error("ItemRegistry: Failed to parse manifest for %s" % folder_name)

# --- Public API ---

func register_item(data: Dictionary) -> void:
	if data.has("id"):
		items[data["id"]] = data
	else:
		Log.warn("ItemRegistry: Attempted to register item without id")

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

func get_item_name(id: String) -> String:
	var item = get_item(id)
	return item.get("name", "Unknown Item")

func get_item_description(id: String) -> String:
	var item = get_item(id)
	return item.get("description", "")

func get_item_icon(id: String) -> Texture2D:
	var item = get_item(id)
	if item.has("icon"):
		var icon_path = item["icon"]
		if ResourceLoader.exists(icon_path):
			return load(icon_path)
	return _default_icon

func get_all_items() -> Array:
	return items.values()

func get_items_by_category(category: String) -> Array:
	var result = []
	for key in items:
		if items[key].get("category", "") == category:
			result.append(items[key])
	return result
