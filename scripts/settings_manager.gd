extends Node

signal setting_changed(key: StringName, value: Variant)

const DEFAULTS := {
	"display.scale_mode": "integer", # "integer" | "fractional"
	"display.scale_factor": 1.0,
	"audio.master_db": 0.0,
	"audio.muted": false,
	"ui.theme": "light",
	"ui.cursor_scale": 1.0,
	"ui.animations": true,
	"ui.language": "en",
	"background.type": "solid", # "solid" | "gradient" | "image"
	"background.color_a": "#12141a",
	"background.color_b": "#1e222b",
	"background.image_path": "",
}

var _values: Dictionary = {}

func _ready() -> void:
	var core := get_tree().root.get_node_or_null("/root/CoreRuntime")
	if core != null:
		core.register_service("SettingsManager")
	_load_from_global_save()

func get_value(key: StringName, default_value: Variant = null) -> Variant:
	if _values.has(key):
		return _values[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return default_value

func set_value(key: StringName, value: Variant) -> void:
	value = _validate(key, value)
	if _values.has(key) and _values[key] == value:
		return
	_values[key] = value
	emit_signal("setting_changed", key, value)
	_save_to_global_save()

func get_all() -> Dictionary:
	var out := {}
	for k in DEFAULTS.keys():
		out[k] = get_value(k)
	for k in _values.keys():
		out[k] = _values[k]
	return out

func get_defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)

func reset_to_defaults() -> void:
	_values.clear()
	for k in DEFAULTS.keys():
		set_value(k, DEFAULTS[k])

func _validate(key: StringName, value: Variant) -> Variant:
	match String(key):
		"display.scale_mode":
			if value != "integer" and value != "fractional":
				return "integer"
			return value
		"display.scale_factor":
			var f := float(value)
			return clampf(f, 0.5, 6.0)
		"audio.master_db":
			return clampf(float(value), -80.0, 6.0)
		"audio.muted":
			return bool(value)
		"ui.theme":
			var s := String(value)
			return s if s in ["light", "dark"] else "light"
		"ui.cursor_scale":
			return clampf(float(value), 0.5, 3.0)
		"ui.animations":
			return bool(value)
		"ui.language":
			return String(value)
		"background.type":
			var s := String(value)
			return s if s in ["solid", "gradient", "image"] else "solid"
		"background.color_a", "background.color_b":
			return String(value) # Colors stored as hex strings
		"background.image_path":
			return String(value)
		_:
			return value

func _load_from_global_save() -> void:
	var sm := get_tree().root.get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	var data: Dictionary = sm.load_global()
	var settings: Dictionary = data.get("settings", {})
	if typeof(settings) == TYPE_DICTIONARY:
		_values = settings.duplicate(true)

func _save_to_global_save() -> void:
	var sm := get_tree().root.get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	var data: Dictionary = sm.load_global()
	data["settings"] = _values
	sm.save_global(data)
