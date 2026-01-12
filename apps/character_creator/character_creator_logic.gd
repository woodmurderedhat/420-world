extends RefCounted
class_name CharacterCreatorLogic

@export var templates_dir: String = "res://apps/character_creator/templates/"
var templates: Array = []

# Load templates from disk into `templates` array
func load_templates() -> void:
	templates.clear()
	var dir = DirAccess.open(templates_dir)
	if dir:
		if dir.list_dir_begin() == OK:
			var fname = dir.get_next()
			while fname != "":
				if not dir.current_is_dir() and fname.ends_with('.json'):
					var fpath = templates_dir + fname
					var f = FileAccess.open(fpath, FileAccess.READ)
					if f:
						var j = JSON.new()
						if j.parse(f.get_as_text()) == OK:
							templates.append(j.data)
				fname = dir.get_next()

func get_templates() -> Array:
	return templates

# Validate name (moved from UI); returns {ok: bool, error: String}
func validate_name(candidate_name: String) -> Dictionary:
	if candidate_name.strip_edges() == "":
		return {"ok": false, "error": "Name cannot be empty."}
	if candidate_name.length() < 1 or candidate_name.length() > 32:
		return {"ok": false, "error": "Name must be 1-32 characters."}
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_ ]+$")
	if not pattern.search(candidate_name):
		return {"ok": false, "error": "Only letters, numbers, spaces and underscores allowed."}
	if CharacterManager.is_name_taken(candidate_name):
		return {"ok": false, "error": "Name already used."}
	return {"ok": true}

# Default stats used by UI when stat inputs are missing
func default_stats() -> Dictionary:
	return {"gold":5,"agility":5,"strength":5,"intelligence":5,"constitution":5,"luck":5}

# Create a character using CharacterManager; returns {ok: bool, error: String}
func create_character_from_data(char_name: String, category: String, body_parts: Dictionary, stats: Dictionary) -> Dictionary:
	var validation = validate_name(char_name)
	if not validation["ok"]:
		return {"ok": false, "error": validation["error"]}
	if not CharacterManager.can_create_character():
		return {"ok": false, "error": "No character slots available."}
	# Validate stats keys and values
	for s_key in ["gold","agility","strength","intelligence","constitution","luck"]:
		if not stats.has(s_key):
			# Fill missing with default
			stats[s_key] = default_stats().get(s_key)
		else:
			stats[s_key] = int(stats[s_key])

	var success = CharacterManager.create_character(char_name, category, body_parts, stats)
	if not success:
		return {"ok": false, "error": "Failed to create character."}
	return {"ok": true}

# Apply a template to selected parts and stats; returns updated {parts: Dictionary, stats: Dictionary}
func apply_template(tmpl: Dictionary, current_parts: Dictionary, current_stats: Dictionary) -> Dictionary:
	var parts = current_parts.duplicate()
	var stats = current_stats.duplicate()
	var t_parts = tmpl.get("body_parts", {})
	for k in t_parts:
		parts[k] = t_parts[k]
	var t_stats = tmpl.get("suggested_stats", {})
	for s in t_stats:
		stats[s] = t_stats[s]
	return {"parts": parts, "stats": stats}
