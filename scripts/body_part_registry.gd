extends Node

const PARTS_ROOT = "res://data/items/assets/character_parts/"

# type -> array of parts
var parts_cache: Dictionary = {}
var texture_cache: Dictionary = {}

func _ready() -> void:
	# Lazy-load, so we don't scan here.
	# Register validation for parts later?
	pass

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
	if not file: return
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.data
		if data.has("parts"):
			parts_cache[type] = data["parts"]
			# Prepend path to texture
			for p in parts_cache[type]:
				if p.has("texture_path"):
					p["full_path"] = dir_path + p["texture_path"]

func get_parts(type: String) -> Array:
	if parts_cache.is_empty():
		load_all_parts()
	return parts_cache.get(type, [])

func get_part_texture(part_id: String, type: String) -> Texture2D:
	if texture_cache.has(part_id):
		return texture_cache[part_id]
		
	var parts = get_parts(type)
	for p in parts:
		if p["id"] == part_id:
			if ResourceLoader.exists(p["full_path"]):
				var tex = load(p["full_path"])
				texture_cache[part_id] = tex
				return tex
			
	return null

func get_part_metadata(part_id: String, type: String) -> Dictionary:
	var parts = get_parts(type)
	for p in parts:
		if p["id"] == part_id:
			return p
	return {}
