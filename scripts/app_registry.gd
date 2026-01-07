extends Node

signal registry_changed

const SHELL_VERSION = "0.1.0"
const KNOWN_PERMISSIONS = {
	"filesystem.read": "Read user data",
	"filesystem.write": "Write user data",
	"inventory": "Access shared inventory",
	"network": "Network access",
	"settings": "Modify settings",
}
const RECENT_LIMIT = 6

var apps: Dictionary = {}  # app_id -> manifest Dictionary
var recently_used: Array[String] = []


func _ready() -> void:
	var core: Node = get_tree().root.get_node_or_null("/root/CoreRuntime")
	if core != null:
		core.register_service("AppRegistry")
	scan_for_apps()


func scan_for_apps() -> void:
	apps.clear()
	var dir: DirAccess = DirAccess.open("res://apps")
	if dir == null:
		emit_signal("registry_changed")
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if dir.current_is_dir() and not entry_name.begins_with("."):
			var manifest_path: String = "res://apps/%s/manifest.json" % entry_name
			if FileAccess.file_exists(manifest_path):
				var manifest: Dictionary = _load_manifest(manifest_path)
				if _is_manifest_valid(manifest):
					apps[manifest["id"]] = manifest
		entry_name = dir.get_next()
	dir.list_dir_end()
	emit_signal("registry_changed")


func get_manifest(app_id: String) -> Dictionary:
	return apps.get(app_id, {})


func list_manifests() -> Array:
	var out: Array = apps.values()
	out.sort_custom(_compare_manifest_names)
	return out


func record_recent(app_id: String) -> void:
	if not apps.has(app_id):
		return
	recently_used.erase(app_id)
	recently_used.push_front(app_id)
	if recently_used.size() > RECENT_LIMIT:
		recently_used.resize(RECENT_LIMIT)


func list_recent() -> Array[String]:
	return recently_used.duplicate()


func _compare_manifest_names(a: Dictionary, b: Dictionary) -> int:
	return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", "")))


func _load_manifest(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		Log.warn("AppRegistry: failed to open %s" % path)
		return {}
	var text: String = f.get_as_text()
	f.close()
	if text.strip_edges() == "":
		Log.warn("AppRegistry: empty manifest %s" % path)
		return {}
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		Log.warn("AppRegistry: invalid JSON in %s" % path)
		return {}
	var parsed: Dictionary = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		Log.warn("AppRegistry: invalid JSON in %s" % path)
		return {}
	return parsed


func _is_manifest_valid(manifest: Dictionary) -> bool:
	for key in ["id", "name", "entry_scene", "version"]:
		if not manifest.has(key):
			Log.warn("AppRegistry: manifest missing %s" % key)
			return false
	var id_val: Variant = manifest["id"]
	var name_val: Variant = manifest["name"]
	var entry_scene_val: Variant = manifest["entry_scene"]
	var version_val: Variant = manifest["version"]
	if (
		typeof(id_val) != TYPE_STRING
		or String(id_val).is_empty()
		or typeof(name_val) != TYPE_STRING
		or String(name_val).is_empty()
		or typeof(entry_scene_val) != TYPE_STRING
		or typeof(version_val) != TYPE_STRING
		or String(version_val).is_empty()
	):
		return false
	var entry_scene_path: String = String(entry_scene_val)
	if not ResourceLoader.exists(entry_scene_path):
		Log.warn("AppRegistry: entry scene missing for %s" % manifest.get("id", "?"))
		return false
	if manifest.has("icon") and typeof(manifest["icon"]) == TYPE_STRING and manifest["icon"] != "":
		if not ResourceLoader.exists(manifest["icon"]):
			Log.warn("AppRegistry: icon missing for %s" % manifest.get("id", "?"))
			manifest.erase("icon")
	# Optional enrichment fields
	manifest["category"] = String(manifest.get("category", "General"))
	manifest["description"] = String(manifest.get("description", ""))
	manifest["author"] = String(manifest.get("author", ""))
	manifest["min_shell_version"] = String(manifest.get("min_shell_version", ""))
	manifest["pinned"] = bool(manifest.get("pinned", true))
	manifest["permissions"] = _sanitize_permissions(manifest.get("permissions", []))
	if manifest["min_shell_version"] != "":
		if _compare_semver(SHELL_VERSION, manifest["min_shell_version"]) < 0:
			Log.warn(
				(
					"AppRegistry: %s requires shell >= %s (current %s)"
					% [manifest.get("id", "?"), manifest["min_shell_version"], SHELL_VERSION]
				)
			)
			manifest["min_shell_ok"] = false
		else:
			manifest["min_shell_ok"] = true
	return true


func _sanitize_permissions(value: Variant) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for p in value:
		var pstr: String = String(p).strip_edges()
		if pstr == "":
			continue
		out.append(pstr)
	return out


func _parse_semver(text: String) -> Array[int]:
	var parts: Array = text.split(".")
	var out: Array[int] = [0, 0, 0]
	for i in range(min(parts.size(), 3)):
		out[i] = int(parts[i])
	return out


func _compare_semver(a: String, b: String) -> int:
	var ap: Array[int] = _parse_semver(a)
	var bp: Array[int] = _parse_semver(b)
	for i in range(3):
		if ap[i] == bp[i]:
			continue
		return 1 if ap[i] > bp[i] else -1
	return 0
