extends AppBase

@onready var mode_option: OptionButton = $VBox/DisplaySection/ScaleMode
@onready var factor_slider: HSlider = $VBox/DisplaySection/ScaleFactor
@onready var factor_value: Label = $VBox/DisplaySection/FactorValue
@onready var animations_check: CheckBox = $VBox/DisplaySection/Animations
@onready var cursor_slider: HSlider = $VBox/DisplaySection/CursorScale
@onready var cursor_value: Label = $VBox/DisplaySection/CursorValue

@onready var theme_option: OptionButton = $VBox/ThemeSection/ThemeOption

@onready var bg_type: OptionButton = $VBox/BackgroundSection/BackgroundType
@onready var bg_color_a: ColorPickerButton = $VBox/BackgroundSection/ColorA
@onready var bg_color_b: ColorPickerButton = $VBox/BackgroundSection/ColorB
@onready var bg_image_path: LineEdit = $VBox/BackgroundSection/ImagePath

@onready var master_slider: HSlider = $VBox/AudioSection/MasterSlider
@onready var master_value: Label = $VBox/AudioSection/MasterValue
@onready var mute_check: CheckBox = $VBox/AudioSection/MuteCheck

@onready var language_option: OptionButton = $VBox/LanguageSection/LanguageOption

@onready var desktop_section: VBoxContainer = $VBox/DesktopSection
@onready var pinned_apps_vbox: VBoxContainer = $VBox/DesktopSection/PinnedAppsVBox
@onready var window_icons_section: VBoxContainer = $VBox/WindowIconsSection
@onready var icon_picker: FileDialog = $IconPicker
@onready var font_path: LineEdit = $VBox/WindowIconsSection/FontRow/FontPath
@onready var font_browse: Button = $VBox/WindowIconsSection/FontRow/FontBrowse
@onready var font_picker: FileDialog = $FontPicker

@onready var apply_button: Button = $VBox/Actions/ApplyButton
@onready var reset_button: Button = $VBox/Actions/ResetButton
@onready var toast_label: Label = $Toast
@onready var toast_timer: Timer = $ToastTimer


func _ready() -> void:
	mode_option.clear()
	mode_option.add_item("Integer", 0)
	mode_option.add_item("Fractional", 1)
	mode_option.item_selected.connect(_on_mode_selected)
	factor_slider.value_changed.connect(_on_factor_changed)
	animations_check.toggled.connect(func(_v): _update_dirty_state())
	cursor_slider.value_changed.connect(_on_cursor_changed)

	theme_option.clear()
	theme_option.add_item("Light", 0)
	theme_option.add_item("Dark", 1)

	bg_type.clear()
	bg_type.add_item("Solid", 0)
	bg_type.set_item_metadata(0, "solid")
	bg_type.add_item("Gradient", 1)
	bg_type.set_item_metadata(1, "gradient")
	bg_type.add_item("Image", 2)
	bg_type.set_item_metadata(2, "image")
	bg_type.item_selected.connect(_on_bg_type_selected)

	bg_color_a.color_changed.connect(func(_c): _update_dirty_state())
	bg_color_b.color_changed.connect(func(_c): _update_dirty_state())
	bg_image_path.text_changed.connect(func(_t): _update_dirty_state())

	master_slider.value_changed.connect(_on_master_changed)
	mute_check.toggled.connect(func(_v): _update_dirty_state())

	language_option.clear()
	language_option.add_item("English", 0)
	language_option.set_item_metadata(0, "en")
	language_option.add_item("Spanish (stub)", 1)
	language_option.set_item_metadata(1, "es")

	apply_button.pressed.connect(_apply)
	reset_button.pressed.connect(_reset_defaults)
	toast_timer.timeout.connect(func(): toast_label.visible = false)

	# Icon picker
	icon_picker.file_selected.connect(_on_icon_picked)

	# Font picker
	font_browse.pressed.connect(func(): font_picker.popup_centered_ratio())
	font_picker.file_selected.connect(func(p): _on_font_picked(p))

	# Build window icons UI
	_build_window_icons_ui()


func launch(_params: Dictionary) -> void:
	_sync_from_settings()


func resume() -> void:
	_sync_from_settings()


func _sync_from_settings() -> void:
	# If UI node was freed or not yet in tree, skip syncing to avoid "previously freed" errors
	if not is_inside_tree() or not is_instance_valid(self):
		return
	if not _controls_ready():
		return

	var mode := String(SettingsManager.get_value("display.scale_mode", "integer"))
	mode_option.select(0 if mode == "integer" else 1)
	factor_slider.value = float(SettingsManager.get_value("display.scale_factor", 1.0))
	_update_factor_label(factor_slider.value)
	animations_check.button_pressed = bool(SettingsManager.get_value("ui.animations", true))
	cursor_slider.value = float(SettingsManager.get_value("ui.cursor_scale", 1.0))
	_update_cursor_label(cursor_slider.value)
	var theme_name := String(SettingsManager.get_value("ui.theme", "light"))
	theme_option.select(0 if theme_name == "light" else 1)

	var bg_t := String(SettingsManager.get_value("background.type", "solid"))
	for i in range(bg_type.item_count):
		if String(bg_type.get_item_metadata(i)) == bg_t:
			bg_type.select(i)
			break
	bg_color_a.color = Color(String(SettingsManager.get_value("background.color_a", "#12141a")))
	bg_color_b.color = Color(String(SettingsManager.get_value("background.color_b", "#1e222b")))
	bg_image_path.text = String(SettingsManager.get_value("background.image_path", ""))
	_on_bg_type_selected(bg_type.selected)

	var master := float(SettingsManager.get_value("audio.master_db", 0.0))
	master_slider.value = master
	_update_master_label(master)
	mute_check.button_pressed = bool(SettingsManager.get_value("audio.muted", false))
	var lang := String(SettingsManager.get_value("ui.language", "en"))
	language_option.select(0 if lang == "en" else 1)
	_update_dirty_state()

	# Sync pinned apps list
	_build_pinned_apps_ui()
	_sync_window_icons_ui()
	# Sync font path
	var fpath := String(SettingsManager.get_value("ui.font", ""))
	font_path.text = fpath


func _controls_ready() -> bool:
	return (
		is_instance_valid(mode_option)
		and is_instance_valid(factor_slider)
		and is_instance_valid(factor_value)
		and is_instance_valid(animations_check)
		and is_instance_valid(cursor_slider)
		and is_instance_valid(cursor_value)
		and is_instance_valid(theme_option)
		and is_instance_valid(bg_type)
		and is_instance_valid(bg_color_a)
		and is_instance_valid(bg_color_b)
		and is_instance_valid(bg_image_path)
		and is_instance_valid(master_slider)
		and is_instance_valid(master_value)
		and is_instance_valid(mute_check)
		and is_instance_valid(language_option)
		and is_instance_valid(pinned_apps_vbox)
		and is_instance_valid(window_icons_section)
		and is_instance_valid(font_path)
	)


func _build_pinned_apps_ui() -> void:
	for c in pinned_apps_vbox.get_children():
		c.queue_free()
	var saved_pins: Array = SettingsManager.get_value("ui.pinned_apps", []) as Array
	if typeof(saved_pins) != TYPE_ARRAY:
		saved_pins = []
	for manifest in AppRegistry.list_manifests():
		var app_id := String(manifest.get("id", ""))
		if app_id == "":
			continue
		var h := HBoxContainer.new()
		var tex: Texture2D = null
		var icon_path := String(manifest.get("icon", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var t: Texture2D = ResourceLoader.load(icon_path) as Texture2D
			if t is Texture2D:
				tex = t
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(32, 32)
		h.add_child(tr)
		var lbl := Label.new()
		lbl.text = String(manifest.get("name", app_id))
		h.add_child(lbl)
		var chk: CheckBox = CheckBox.new()
		chk.button_pressed = (app_id in saved_pins) or bool(manifest.get("pinned", true))
		chk.name = app_id
		h.add_child(chk)
		pinned_apps_vbox.add_child(h)


func _build_window_icons_ui() -> void:
	# keys: close, minimize, maximize, fullscreen
	var keys := ["close", "minimize", "maximize", "fullscreen"]
	for c in window_icons_section.get_children():
		if c != null and c.name != "WindowIconsLabel":
			c.queue_free()
	for key in keys:
		var h := HBoxContainer.new()
		h.name = "icon_%s" % key
		var lbl := Label.new()
		lbl.text = key.capitalize()
		h.add_child(lbl)
		var le: LineEdit = LineEdit.new()
		le.name = "le_%s" % key
		h.add_child(le)
		var btn: Button = Button.new()
		btn.text = "Browse"
		btn.name = "btn_%s" % key
		var cur_key: String = key
		btn.pressed.connect(func(): _on_browse_icon(cur_key))
		h.add_child(btn)
		window_icons_section.add_child(h)


func _sync_window_icons_ui() -> void:
	var icons: Dictionary = SettingsManager.get_value("ui.window_icons", {}) as Dictionary
	if typeof(icons) != TYPE_DICTIONARY:
		icons = {}
	for h in window_icons_section.get_children():
		if typeof(h) != TYPE_OBJECT:
			continue
		if not h.name.begins_with("icon_"):
			continue
		var key := h.name.trim_prefix("icon_")
		var le := h.get_node_or_null("le_%s" % key)
		if le != null:
			le.text = String(icons.get(key, ""))


var _pending_icon_key: String = ""


func _on_browse_icon(key: String) -> void:
	_pending_icon_key = key
	icon_picker.popup_centered_ratio()


func _on_icon_picked(path: String) -> void:
	if _pending_icon_key == "":
		return
	var h := window_icons_section.get_node_or_null("icon_%s" % _pending_icon_key)
	if h != null:
		var le := h.get_node_or_null("le_%s" % _pending_icon_key)
		if le != null:
			le.text = path
	_pending_icon_key = ""


func _on_font_picked(path: String) -> void:
	font_path.text = path


func _on_mode_selected(_idx: int) -> void:
	# Do not auto-apply; wait for Apply.
	pass


func _on_factor_changed(v: float) -> void:
	_update_factor_label(v)
	_update_dirty_state()


func _on_cursor_changed(v: float) -> void:
	_update_cursor_label(v)
	_update_dirty_state()


func _on_master_changed(v: float) -> void:
	_update_master_label(v)


func _on_bg_type_selected(_idx: int) -> void:
	var type := String(bg_type.get_selected_metadata())
	bg_color_a.visible = (type == "solid" or type == "gradient")
	bg_color_b.visible = (type == "gradient")
	bg_image_path.visible = (type == "image")
	_update_dirty_state()


func _update_master_label(v: float) -> void:
	master_value.text = "Master: %.1f dB" % v


func _apply() -> void:
	var mode := "integer" if mode_option.selected == 0 else "fractional"
	SettingsManager.set_value("display.scale_mode", mode)
	SettingsManager.set_value("display.scale_factor", float(factor_slider.value))
	SettingsManager.set_value("ui.animations", animations_check.button_pressed)
	SettingsManager.set_value("ui.cursor_scale", float(cursor_slider.value))

	var xtheme := "light" if theme_option.selected == 0 else "dark"
	SettingsManager.set_value("ui.theme", xtheme)

	SettingsManager.set_value("audio.master_db", float(master_slider.value))
	SettingsManager.set_value("audio.muted", mute_check.button_pressed)

	var lang_meta: Variant = language_option.get_item_metadata(language_option.selected)
	SettingsManager.set_value("ui.language", String(lang_meta))

	SettingsManager.set_value("background.type", bg_type.get_selected_metadata())
	SettingsManager.set_value("background.color_a", bg_color_a.color.to_html())
	SettingsManager.set_value("background.color_b", bg_color_b.color.to_html())
	SettingsManager.set_value("background.image_path", bg_image_path.text)

	_show_toast("Settings applied")
	_update_dirty_state()

	# Persist pinned apps from UI
	var pins: Array = []
	for h in pinned_apps_vbox.get_children():
		for c in h.get_children():
			if c is CheckBox and (c as CheckBox).button_pressed:
				pins.append(c.name)
	SettingsManager.set_value("ui.pinned_apps", pins)

	# Persist window icons
	var icon_map: Dictionary = SettingsManager.get_value("ui.window_icons", {})
	if typeof(icon_map) != TYPE_DICTIONARY:
		icon_map = {}
	for h in window_icons_section.get_children():
		if not h.name.begins_with("icon_"):
			continue
		var key := h.name.trim_prefix("icon_")
		var le := h.get_node_or_null("le_%s" % key)
		if le != null and le.text.strip_edges() != "":
			icon_map[key] = le.text.strip_edges()
	SettingsManager.set_value("ui.window_icons", icon_map)

	# Persist font selection
	var fsel := font_path.text.strip_edges()
	SettingsManager.set_value("ui.font", fsel)
	# Apply immediately
	var tm := get_tree().root.get_node_or_null("/root/ThemeManager")
	if tm != null:
		tm.set_font(fsel)


func _reset_defaults() -> void:
	SettingsManager.reset_to_defaults()
	_sync_from_settings()
	_show_toast("Settings reset to defaults")


func _update_factor_label(v: float) -> void:
	factor_value.text = "Scale: %.2fx" % v


func _update_cursor_label(v: float) -> void:
	cursor_value.text = "Cursor: %.2fx" % v


func _update_dirty_state() -> void:
	# Placeholder hook for future disable/enable apply if dirty tracking needed.
	pass


func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start(1.5)
