extends Node

const PARTS_ROOT = "res://data/items/assets/character_parts/"

# type -> array of parts
var parts_cache: Dictionary = {}
var texture_cache: Dictionary = {}
var _part_lookup: Dictionary = {}

func _ready() -> void:
	# Eagerly register parts so other systems can query them immediately.
	load_all_parts()

func load_all_parts() -> void:
	if not parts_cache.is_empty(): 
		return
		
	Log.info("BodyPartRegistry: Loading parts...")
	var types = ["head", "eyes", "mouth", "hair", "body", "arms", "hands", "legs", "feet"]
	for t in types:
		_scan_part_type(t)

func _scan_part_type(type: String) -> void:
	var dir_path = PARTS_ROOT + type + "/"
	var manifest_path = dir_path + "manifest.json"
	
	if not FileAccess.file_exists(manifest_path):
		parts_cache[type] = []
		return
		
	var file = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		parts_cache[type] = []
		return

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(text) == OK:
		var data = json.data
		if data.has("parts"):
			parts_cache[type] = data["parts"]
			# Prepend path to texture and populate lookup
			for p in parts_cache[type]:
				if p.has("texture_path"):
					p["full_path"] = dir_path + p["texture_path"]
				p["type"] = type
				_part_lookup[p["id"]] = p
	else:
		parts_cache[type] = []

func get_parts(type: String) -> Array:
	if parts_cache.is_empty():
		load_all_parts()
	return parts_cache.get(type, [])

func get_part(part_id: String) -> Dictionary:
	if parts_cache.is_empty():
		load_all_parts()
	return _part_lookup.get(part_id, {})

func is_part_unlocked(part_id: String, _user_data: Dictionary = {}) -> bool:
	var part = get_part(part_id)
	if part.is_empty():
		return false
	
	# Free parts are always unlocked
	if part.get("cost", 0) <= 0:
		return true
		
	# Check ProgressionManager
	return ProgressionManager.is_body_part_unlocked(part_id)

func get_part_texture(part_id: String, type: String = "") -> Texture2D:
	if texture_cache.has(part_id):
		return texture_cache[part_id]
	
	# If type is not provided, try to find it
	var p = get_part(part_id)
	if p.is_empty():
		return null
		
	if ResourceLoader.exists(p["full_path"]):
		var tex = load(p["full_path"])
		texture_cache[part_id] = tex
		return tex
			
	return null

func get_part_metadata(part_id: String, type: String = "") -> Dictionary:
	return get_part(part_id)
