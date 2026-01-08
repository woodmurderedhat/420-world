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

	# Convert to texture and cache
	var out_tex = ImageTexture.create_from_image(canvas)
	_cache[key] = out_tex
	return out_tex
