extends Node

signal theme_changed(theme_name: StringName, palette: Dictionary)

var THEMES: Dictionary = {
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

# Icon and sizing defaults
const DEFAULT_ICON_SIZE: int = 32
var icon_scale: float = 1.0
var desktop_icon_size: int = DEFAULT_ICON_SIZE
var pinned_icon_size: int = DEFAULT_ICON_SIZE
var window_icon_height: int = 32

signal theme_resource_changed(theme_name: StringName, theme: Theme)

func _ready() -> void:
	var core := get_tree().root.get_node_or_null("/root/CoreRuntime")
	if core != null:
		core.register_service("ThemeManager")
	load_custom_themes()
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
			var bundled := "res://assets/fonts/Inter-Variable.ttf"
			if ResourceLoader.exists(bundled):
				set_font(bundled)


# --- Icon / sizing helpers -------------------------------------------------
func get_icon_size() -> int:
	return int(clamp(desktop_icon_size * icon_scale, 8, 256))

func get_desktop_icon_vector() -> Vector2:
	var s := get_icon_size()
	return Vector2(s, s)

func get_pinned_icon_vector() -> Vector2:
	var s := int(clamp(pinned_icon_size * icon_scale, 8, 256))
	return Vector2(s, s)

func get_window_icon_height() -> int:
	return int(clamp(window_icon_height * icon_scale, 8, 512))

func set_icon_scale(scale: float) -> void:
	icon_scale = clamp(scale, 0.25, 4.0)
	emit_signal("theme_changed", current_theme, get_palette())

func set_desktop_icon_size(size: int) -> void:
	desktop_icon_size = max(size, 8)
	emit_signal("theme_changed", current_theme, get_palette())

func set_pinned_icon_size(size: int) -> void:
	pinned_icon_size = max(size, 8)
	emit_signal("theme_changed", current_theme, get_palette())

func set_window_icon_height(size: int) -> void:
	window_icon_height = max(size, 8)
	emit_signal("theme_changed", current_theme, get_palette())

func set_palette_for_theme(theme_name: StringName, palette: Dictionary) -> void:
	if THEMES.has(theme_name):
		THEMES[theme_name] = palette
		if current_theme == theme_name:
			emit_signal("theme_changed", current_theme, palette)

func apply_icon_to_button(b: Button, tex: Texture2D) -> void:
	# Centralized helper to apply icons consistently across the shell
	if b == null:
		return
	b.icon = tex
	# Prefer scaling icons to fit button area so huge textures do not blow up UI
	b.expand_icon = true
	# If this button appears in pinned box, ensure square pinned icon sizing
	if b.get_parent() and b.get_parent().name == "PinnedBox":
		b.custom_minimum_size = get_pinned_icon_vector()
		return
	# For generic window buttons, keep height consistent
	if b.custom_minimum_size.y == 0 or b.custom_minimum_size.y < 24:
		b.custom_minimum_size.y = get_window_icon_height()

func build_basic_theme_resource(theme_name: StringName = "builtin") -> Theme:
	# Build a minimal Theme resource with font and important constants
	var theme: Theme = Theme.new()
	# Add font if available
	if _font != null:
		theme.set_font("default_font", "Label", _font)
		theme.set_font("font", "PopupMenu", _font)
		# Make the font available to Buttons/Labels via theme; callers may still use add_theme_font_override
		# Important constants
		theme.set_constant("icon_size", "Button", get_icon_size())
	
	# PopupMenu styling to look like tooltips (dark, rounded)
	var sb_popup: StyleBoxFlat = StyleBoxFlat.new()
	sb_popup.bg_color = Color(0.12, 0.13, 0.17, 0.95)
	sb_popup.corner_radius_top_left = 6
	sb_popup.corner_radius_top_right = 6
	sb_popup.corner_radius_bottom_left = 6
	sb_popup.corner_radius_bottom_right = 6
	sb_popup.border_width_left = 1
	sb_popup.border_width_top = 1
	sb_popup.border_width_right = 1
	sb_popup.border_width_bottom = 1
	sb_popup.border_color = Color(0.3, 0.35, 0.4)
	sb_popup.content_margin_left = 8
	sb_popup.content_margin_right = 8
	sb_popup.content_margin_top = 8
	sb_popup.content_margin_bottom = 8
	
	theme.set_stylebox("panel", "PopupMenu", sb_popup)
	theme.set_color("font_color", "PopupMenu", Color(0.9, 0.92, 0.96))
	theme.set_color("font_hover_color", "PopupMenu", Color(1.0, 1.0, 1.0))
	theme.set_constant("v_separation", "PopupMenu", 8)
	
	# Item hover style for PopupMenu
	var sb_hover: StyleBoxFlat = StyleBoxFlat.new()
	sb_hover.bg_color = Color(1.0, 1.0, 1.0, 0.1)
	sb_hover.corner_radius_top_left = 4
	sb_hover.corner_radius_top_right = 4
	sb_hover.corner_radius_bottom_left = 4
	sb_hover.corner_radius_bottom_right = 4
	theme.set_stylebox("hover", "PopupMenu", sb_hover)

	# Colors and styleboxes could be added here for a richer theme
	emit_signal("theme_resource_changed", theme_name, theme)
	return theme


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if String(key) == "ui.theme":
		set_theme(StringName(value))


func set_theme(theme_name: StringName) -> void:
	if not THEMES.has(theme_name):
		Log.warn("ThemeManager: Unknown theme %s" % theme_name)
		return
	current_theme = theme_name
	var palette: Dictionary = THEMES[theme_name]
	get_tree().root.theme = build_basic_theme_resource(current_theme)
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


const CUSTOM_THEMES_PATH = "user://custom_themes.json"

func load_custom_themes() -> void:
	if not FileAccess.file_exists(CUSTOM_THEMES_PATH):
		return
		
	var f = FileAccess.open(CUSTOM_THEMES_PATH, FileAccess.READ)
	if f == null:
		return
		
	var text = f.get_as_text()
	var json = JSON.new()
	if json.parse(text) != OK:
		Log.error("ThemeManager: Corrupt custom_themes.json at line %s" % json.get_error_line())
		return
		
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return
		
	for theme_name in data:
		var hex_pal = data[theme_name]
		if typeof(hex_pal) != TYPE_DICTIONARY:
			continue
			
		var pal = {}
		if THEMES.has(theme_name):
			pal = THEMES[theme_name].duplicate()
			
		for k in hex_pal:
			pal[k] = Color.from_string(hex_pal[k], Color.BLACK)
			
		THEMES[theme_name] = pal
	
	Log.info("ThemeManager: Loaded custom themes")


func save_custom_themes() -> void:
	var export_data = {}
	for theme_name in THEMES:
		var pal = THEMES[theme_name]
		var hex_pal = {}
		for k in pal:
			var c = pal[k]
			if c is Color:
				hex_pal[k] = c.to_html()
		export_data[theme_name] = hex_pal
		
	var f = FileAccess.open(CUSTOM_THEMES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(export_data, "\t"))
		Log.info("ThemeManager: Saved custom themes")
