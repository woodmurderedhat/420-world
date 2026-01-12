class_name CharacterRenderer
extends Node

# Simple renderer that composites canonical 32x32 part textures into a final Texture2D.
# Usage: var tex = CharacterRenderer.render_character({"head":"head_01","eyes":"eyes_01", ...})

static var _cache: Dictionary = {}

static func _parts_order() -> Array:
	# Order from background to foreground
	return ["legs", "body", "arms", "hands", "head", "hair", "eyes", "mouth"]

static func _hash_bodyparts(body_parts: Dictionary) -> String:
	return JSON.stringify(body_parts)

static func render_character(body_parts: Dictionary) -> Texture2D:
	var key = _hash_bodyparts(body_parts)
	if _cache.has(key):
		return _cache[key]

	# Create blank RGBA image
	var canvas := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0,0,0,0))

	# Layer each part if present
	for t in _parts_order():
		if body_parts.has(t) and body_parts[t] != "":
			var part_id = body_parts[t]
			var tex = BodyPartRegistry.get_part_texture(part_id, t)
			if tex != null:
				# Get image from texture and blit
				var src_img := tex.get_image()
				if src_img != null:
					if src_img.get_size() != Vector2i(32,32):
						# scale the source image into a 32x32 buffer
						src_img.resize(32, 32)
					canvas.blit_rect(src_img, Rect2(Vector2.ZERO, src_img.get_size()), Vector2.ZERO)
			else:
				Log.warn("CharacterRenderer: missing texture for part %s (%s)" % [t, part_id])

	# Convert to texture and cache
	var out_tex = ImageTexture.create_from_image(canvas)
	_cache[key] = out_tex
	return out_tex

static func save_icon(char_id: String, body_parts: Dictionary) -> String:
	# Render and save a 32x32 icon to user://icons/char_<id>.png
	var tex = render_character(body_parts)
	if tex == null:
		return ""
	var img = tex.get_image()
	if img == null:
		return ""
	var dir_abs = ProjectSettings.globalize_path("user://icons/")
	if not DirAccess.dir_exists_absolute(dir_abs):
		DirAccess.make_dir_absolute(dir_abs)
	var path = dir_abs.path_join("char_%s.png" % char_id)
	var ok = img.save_png(path)
	if ok != OK:
		Log.error("CharacterRenderer: failed to save icon to %s" % path)
		return ""
	Log.info("CharacterRenderer: saved icon to %s" % path)
	return path

static func cleanup_cache() -> void:
	_cache.clear()
	Log.info("CharacterRenderer: cleared texture cache")
