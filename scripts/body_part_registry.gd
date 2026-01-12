extends Node

const MANIFEST_PATH: String = "res://data/items/assets/character_parts/manifest.json"
const DEFAULT_TYPES: Array[String] = ["head", "eyes", "mouth", "hair", "body", "arms", "hands", "legs", "feet"]

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
		
	Log.info("BodyPartRegistry: Loading parts (single manifest)...")
	for t in DEFAULT_TYPES:
		parts_cache[t] = []

	if not FileAccess.file_exists(MANIFEST_PATH):
		Log.warn("BodyPartRegistry: missing manifest: %s" % MANIFEST_PATH)
		return

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		Log.error("BodyPartRegistry: failed to open manifest: %s" % MANIFEST_PATH)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		Log.error("BodyPartRegistry: JSON parse failed for %s" % MANIFEST_PATH)
		return

	var data: Dictionary = json.data
	var parts = data.get("parts", null)
	var base_dir: String = MANIFEST_PATH.get_base_dir() + "/"

	# Support grouped manifest: { parts: { "head": [..], "eyes": [..] } }
	if typeof(parts) == TYPE_DICTIONARY:
		for t in parts.keys():
			var arr = parts[t]
			if typeof(arr) != TYPE_ARRAY:
				continue
			for raw_part in arr:
				if typeof(raw_part) != TYPE_DICTIONARY:
					continue
				var p: Dictionary = raw_part
				var pid: String = str(p.get("id", "")).strip_edges()
				if pid == "":
					continue
				p["type"] = t
				if p.has("texture_path"):
					var tex_path: String = str(p.get("texture_path", ""))
					if tex_path.begins_with("res://"):
						p["full_path"] = tex_path
					else:
						p["full_path"] = base_dir + tex_path
				if not parts_cache.has(t):
					parts_cache[t] = []
				parts_cache[t].append(p)
				_part_lookup[pid] = p

	# Backwards-compat: flat list of parts
	elif typeof(parts) == TYPE_ARRAY:
		for raw_part in parts:
			if typeof(raw_part) != TYPE_DICTIONARY:
				continue
			var p: Dictionary = raw_part
			var pid: String = str(p.get("id", "")).strip_edges()
			if pid == "":
				continue
			var ptype: String = str(p.get("type", "")).strip_edges()
			if ptype == "":
				ptype = _infer_type_from_id(pid)
			if ptype == "":
				Log.warn("BodyPartRegistry: skipping part with unknown type: %s" % pid)
				continue
			p["type"] = ptype
			if p.has("texture_path"):
				var tex_path: String = str(p.get("texture_path", ""))
				if tex_path.begins_with("res://"):
					p["full_path"] = tex_path
				else:
					p["full_path"] = base_dir + tex_path
			if not parts_cache.has(ptype):
				parts_cache[ptype] = []
			parts_cache[ptype].append(p)
			_part_lookup[pid] = p

	else:
		Log.warn("BodyPartRegistry: manifest.parts missing or invalid in %s" % MANIFEST_PATH)

func _infer_type_from_id(part_id: String) -> String:
	for t in DEFAULT_TYPES:
		if part_id.begins_with(t + "_"):
			return t
	# Back-compat / special-case naming
	if part_id.begins_with("body"):
		return "body"
	return ""

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
		
	if p.has("full_path") and ResourceLoader.exists(p["full_path"]):
		var tex = load(p["full_path"])
		texture_cache[part_id] = tex
		return tex
			
	return null

func get_part_metadata(part_id: String, type: String = "") -> Dictionary:
	return get_part(part_id)
