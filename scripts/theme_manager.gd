extends Node

signal theme_changed(theme_name: StringName, palette: Dictionary)

const THEMES: Dictionary = {
	"light":
	{
		"bg": Color(0.94, 0.96, 1.0),
		"panel": Color(0.88, 0.92, 0.98),
		"text": Color(0.1, 0.12, 0.16),
		"accent": Color(0.12, 0.53, 0.98),
		"accent_hover": Color(0.1, 0.47, 0.9),
		"accent_soft": Color(0.75, 0.85, 1.0),
	},
	"dark":
	{
		"bg": Color(0.07, 0.08, 0.10),
		"panel": Color(0.12, 0.13, 0.17),
		"text": Color(0.9, 0.92, 0.96),
		"accent": Color(0.18, 0.68, 1.0),
		"accent_hover": Color(0.14, 0.58, 0.9),
		"accent_soft": Color(0.16, 0.22, 0.3),
	},
}

var current_theme: StringName = "light"
var _font: Font = null


func _ready() -> void:
	var core := get_tree().root.get_node_or_null("/root/CoreRuntime")
	if core != null:
		core.register_service("ThemeManager")
	_apply_settings_theme()
	var settings := get_tree().root.get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.setting_changed.connect(_on_setting_changed)

	# Load global font if configured
	var settings2: Node = get_tree().root.get_node_or_null("/root/SettingsManager")
	if settings2 != null:
		var fpath: String = String(settings2.get_value("ui.font", ""))
		if fpath != "":
			set_font(fpath)
		else:
			# No user-selected font: try bundled fallback
			var bundled := "res://assets/fonts/Inter-Regular.ttf"
			if ResourceLoader.exists(bundled):
				set_font(bundled)


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if String(key) == "ui.theme":
		set_theme(StringName(value))


func set_theme(theme_name: StringName) -> void:
	if not THEMES.has(theme_name):
		Log.warn("ThemeManager: Unknown theme %s" % theme_name)
		return
	current_theme = theme_name
	var palette: Dictionary = THEMES[theme_name]
	emit_signal("theme_changed", current_theme, palette)


func set_font(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		_font = null
		emit_signal("theme_changed", current_theme, get_palette())
		return
	var data = ResourceLoader.load(path)
	if data == null:
		Log.warn("ThemeManager: failed to load font data %s" % path)
		_font = null
		emit_signal("theme_changed", current_theme, get_palette())
		return
	# If the loaded resource is a Font, use it directly. Otherwise, attempt to coerce.
	if data is Font:
		_font = data as Font
	else:
		Log.warn("ThemeManager: loaded font resource is not a Font: %s" % typeof(data))
		_font = null
	emit_signal("theme_changed", current_theme, get_palette())


func get_font() -> Font:
	return _font


func get_palette() -> Dictionary:
	return THEMES.get(current_theme, THEMES["light"])


func _apply_settings_theme() -> void:
	var settings := get_tree().root.get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	var theme_name := StringName(settings.get_value("ui.theme", "light"))
	set_theme(theme_name)
