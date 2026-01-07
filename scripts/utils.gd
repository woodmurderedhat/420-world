class_name Utils
extends Node

# Utility helpers shared across scripts

# Safely read app metadata from a node.
# Supports metadata set via `set_meta("metadata", dict)` or a property named `metadata`.
# Returns an empty Dictionary when metadata is absent or not a Dictionary.
static func get_app_metadata(app_root: Node) -> Dictionary:
	var result: Dictionary = {}
	if app_root == null:
		return result
	var m: Variant = null
	if app_root.has_meta("metadata"):
		m = app_root.get_meta("metadata")
	else:
		var maybe: Variant = app_root.get("metadata")
		if typeof(maybe) != TYPE_NIL:
			m = maybe
	if typeof(m) == TYPE_DICTIONARY:
		return m as Dictionary
	return result


# Return the runtime size of a Control, falling back to its minimum size if not yet calculated.
static func get_control_size(control: Control) -> Vector2:
	if control == null:
		return Vector2.ZERO
	var s: Vector2 = Vector2.ZERO
	# Prefer the runtime size property if initialized
	if typeof(control.size) == TYPE_VECTOR2:
		s = control.size
	if s == Vector2.ZERO:
		s = control.get_minimum_size()
	return s


# Clamp a preferred position so that the rect (pos..pos+size) remains inside vp_size (optionally with margin).
static func clamp_to_viewport(preferred_pos: Vector2, size: Vector2, vp_size: Vector2, margin: Vector2 = Vector2.ZERO) -> Vector2:
	var min_x: float = margin.x
	var min_y: float = margin.y
	var max_x: float = max(min_x, vp_size.x - size.x - margin.x)
	var max_y: float = max(min_y, vp_size.y - size.y - margin.y)
	return Vector2(clamp(preferred_pos.x, min_x, max_x), clamp(preferred_pos.y, min_y, max_y))


# Load a Texture2D if the path exists and is a Texture2D, otherwise return null.
static func load_texture_if_exists(path: String) -> Texture2D:
	if path == null or path == "":
		return null
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	if res is Texture2D:
		return res as Texture2D
	return null
