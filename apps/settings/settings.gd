extends AppBase

var _pending_icon_key: String = ""

@onready var mode_option: OptionButton = $MainLayout/TabContainer/Display/VBox/DisplaySection/ScaleMode
@onready var factor_slider: HSlider = $MainLayout/TabContainer/Display/VBox/DisplaySection/ScaleFactor
@onready var factor_value: Label = $MainLayout/TabContainer/Display/VBox/DisplaySection/FactorValue
@onready var animations_check: CheckBox = $MainLayout/TabContainer/Display/VBox/DisplaySection/Animations
@onready var cursor_slider: HSlider = $MainLayout/TabContainer/Display/VBox/DisplaySection/CursorScale
@onready var cursor_value: Label = $MainLayout/TabContainer/Display/VBox/DisplaySection/CursorValue

@onready var theme_option: OptionButton = $MainLayout/TabContainer/Display/VBox/ThemeSection/ThemeOption

@onready var bg_type: OptionButton = $MainLayout/TabContainer/Display/VBox/BackgroundSection/BackgroundType
@onready var bg_color_a: ColorPickerButton = $MainLayout/TabContainer/Display/VBox/BackgroundSection/ColorA
@onready var bg_color_b: ColorPickerButton = $MainLayout/TabContainer/Display/VBox/BackgroundSection/ColorB
@onready var bg_image_path: LineEdit = $MainLayout/TabContainer/Display/VBox/BackgroundSection/ImagePath

@onready var master_slider: HSlider = $MainLayout/TabContainer/Audio/VBox/AudioSection/MasterSlider
@onready var master_value: Label = $MainLayout/TabContainer/Audio/VBox/AudioSection/MasterValue
@onready var mute_check: CheckBox = $MainLayout/TabContainer/Audio/VBox/AudioSection/MuteCheck

@onready var language_option: OptionButton = $MainLayout/TabContainer/General/VBox/LanguageSection/LanguageOption

@onready var pinned_apps_vbox: VBoxContainer = $MainLayout/TabContainer/General/VBox/DesktopSection/PinnedAppsVBox
@onready var window_icons_section: VBoxContainer = $MainLayout/TabContainer/Display/VBox/WindowIconsSection
@onready var icon_picker: FileDialog = $IconPicker
@onready var font_path: LineEdit = $MainLayout/TabContainer/Display/VBox/WindowIconsSection/FontRow/FontPath
@onready var font_browse: Button = $MainLayout/TabContainer/Display/VBox/WindowIconsSection/FontRow/FontBrowse
@onready var font_picker: FileDialog = $FontPicker

@onready var apply_button: Button = $MainLayout/Actions/ApplyButton
@onready var reset_button: Button = $MainLayout/Actions/ResetButton
@onready var toast_label: Label = $Toast
@onready var toast_timer: Timer = $ToastTimer

# Theme Designer Vars
const KEY_ORDER = ["bg", "panel", "text", "accent", "accent_hover", "accent_soft"]
var _updating_themes := false
@onready var theme_designer_container: VBoxContainer = $MainLayout/TabContainer/Themes/VBox/DesignerSection
@onready var tm = get_node_or_null("/root/ThemeManager")


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

	if tm:
		tm.theme_changed.connect(_on_theme_changed)


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
	UIHelpers.safe_set_value(factor_slider, float(SettingsManager.get_value("display.scale_factor", 1.0)))
	_update_factor_label(UIHelpers.safe_value(factor_slider))
	UIHelpers.safe_set_bool(animations_check, bool(SettingsManager.get_value("ui.animations", true)))
	UIHelpers.safe_set_value(cursor_slider, float(SettingsManager.get_value("ui.cursor_scale", 1.0)))
	_update_cursor_label(UIHelpers.safe_value(cursor_slider))
	var theme_name := String(SettingsManager.get_value("ui.theme", "light"))
	theme_option.select(0 if theme_name == "light" else 1)

	var bg_t := String(SettingsManager.get_value("background.type", "solid"))
	for i in range(bg_type.item_count):
		if String(bg_type.get_item_metadata(i)) == bg_t:
			bg_type.select(i)
			break
	UIHelpers.safe_set_color(bg_color_a, Color(String(SettingsManager.get_value("background.color_a", "#12141a"))))
	UIHelpers.safe_set_color(bg_color_b, Color(String(SettingsManager.get_value("background.color_b", "#1e222b"))))
	UIHelpers.safe_set_text(bg_image_path, String(SettingsManager.get_value("background.image_path", "")))
	_on_bg_type_selected(bg_type.selected)

	var master := float(SettingsManager.get_value("audio.master_db", 0.0))
	UIHelpers.safe_set_value(master_slider, master)
	_update_master_label(master)
	UIHelpers.safe_set_bool(mute_check, bool(SettingsManager.get_value("audio.muted", false)))
	var lang := String(SettingsManager.get_value("ui.language", "en"))
	language_option.select(0 if lang == "en" else 1)
	_update_dirty_state()

	# Sync pinned apps list
	_build_pinned_apps_ui()
	_sync_window_icons_ui()
	# Sync font path
	var fpath := String(SettingsManager.get_value("ui.font", ""))
	UIHelpers.safe_set_text(font_path, fpath)
	
	_build_theme_designer_ui()


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
		and is_instance_valid(theme_designer_container)
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
		var tex_rect: TextureRect = TextureRect.new()
		UIHelpers.safe_set_texture(tex_rect, tex)
		tex_rect.custom_minimum_size = Vector2(32, 32)
		h.add_child(tex_rect)
		var lbl := Label.new()
		UIHelpers.safe_set_text(lbl, String(manifest.get("name", app_id)))
		h.add_child(lbl)
		var chk: CheckBox = CheckBox.new()
		if is_instance_valid(chk):
			UIHelpers.safe_set_bool(chk, (app_id in saved_pins) or bool(manifest.get("pinned", true)))
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
		UIHelpers.safe_set_text(lbl, key.capitalize())
		h.add_child(lbl)
		var le: LineEdit = LineEdit.new()
		le.name = "le_%s" % key
		h.add_child(le)
		var btn: Button = Button.new()
		UIHelpers.safe_set_text(btn, "Browse")
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
			UIHelpers.safe_set_text(le, String(icons.get(key, "")))


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
			UIHelpers.safe_set_text(le, path)
	_pending_icon_key = ""


func _on_font_picked(path: String) -> void:
	UIHelpers.safe_set_text(font_path, path)


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
	UIHelpers.safe_set_text(master_value, "Master: %.1f dB" % v)


func _apply() -> void:
	var mode := "integer" if mode_option.selected == 0 else "fractional"
	SettingsManager.set_value("display.scale_mode", mode)
	SettingsManager.set_value("display.scale_factor", UIHelpers.safe_value(factor_slider))
	SettingsManager.set_value("ui.animations", UIHelpers.safe_bool(animations_check))
	SettingsManager.set_value("ui.cursor_scale", UIHelpers.safe_value(cursor_slider))

	var xtheme := "light" if theme_option.selected == 0 else "dark"
	SettingsManager.set_value("ui.theme", xtheme)

	SettingsManager.set_value("audio.master_db", UIHelpers.safe_value(master_slider))
	SettingsManager.set_value("audio.muted", UIHelpers.safe_bool(mute_check))

	var lang_meta: Variant = language_option.get_item_metadata(language_option.selected)
	SettingsManager.set_value("ui.language", String(lang_meta))

	SettingsManager.set_value("background.type", bg_type.get_selected_metadata())
	SettingsManager.set_value("background.color_a", UIHelpers.safe_color_to_html(bg_color_a))
	SettingsManager.set_value("background.color_b", UIHelpers.safe_color_to_html(bg_color_b))
	if is_instance_valid(bg_image_path):
		SettingsManager.set_value("background.image_path", UIHelpers.safe_text(bg_image_path))
	else:
		SettingsManager.set_value("background.image_path", "")

	_show_toast("Settings applied")
	_update_dirty_state()

	# Persist pinned apps from UI
	var pins: Array = []
	for h in pinned_apps_vbox.get_children():
		for c in h.get_children():
			if c is CheckBox and UIHelpers.safe_bool(c):
				pins.append(c.name)
	SettingsManager.set_value("ui.pinned_apps", pins)

	# Persist window icons
	var icon_map: Dictionary = SettingsManager.get_value("ui.window_icons", {})
	if typeof(icon_map) != TYPE_DICTIONARY:
		icon_map = {}
	if is_instance_valid(window_icons_section):
		for h in window_icons_section.get_children():
			if not typeof(h) == TYPE_OBJECT:
				continue
			if not h.name.begins_with("icon_"):
				continue
			var key := h.name.trim_prefix("icon_")
			var le := h.get_node_or_null("le_%s" % key)
			if is_instance_valid(le):
				var txt := UIHelpers.safe_text(le).strip_edges()
				if txt != "":
					icon_map[key] = txt
	SettingsManager.set_value("ui.window_icons", icon_map)

	# Persist font selection
	var fsel := ""
	if is_instance_valid(font_path):
		fsel = UIHelpers.safe_text(font_path).strip_edges()
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
	UIHelpers.safe_set_text(factor_value, "Scale: %.2fx" % v)


func _update_cursor_label(v: float) -> void:
	UIHelpers.safe_set_text(cursor_value, "Cursor: %.2fx" % v)


func _update_dirty_state() -> void:
	# Placeholder hook for future disable/enable apply if dirty tracking needed.
	pass


func _show_toast(text: String) -> void:
	UIHelpers.safe_set_text(toast_label, text)
	toast_label.visible = true
	toast_timer.start(1.5)


# --- Theme Designer Functions ---

func _on_theme_changed(_name, _palette) -> void:
	if not _updating_themes:
		_build_theme_designer_ui()

func _build_theme_designer_ui() -> void:
	if not is_instance_valid(theme_designer_container):
		return
		
	_updating_themes = true
	
	# Clear dynamic controls
	for c in theme_designer_container.get_children():
		c.queue_free()
	
	if not tm:
		_updating_themes = false
		return
	
	# --- Theme Selection ---
	var theme_row = HBoxContainer.new()
	var t_lbl = Label.new()
	UIHelpers.safe_set_text(t_lbl, "Active Theme:")
	t_lbl.custom_minimum_size.x = 120
	theme_row.add_child(t_lbl)
	
	var t_opt = OptionButton.new()
	var themes: Dictionary = tm.THEMES
	var current = tm.current_theme
	var idx = 0
	var select_idx = 0
	
	for k in themes.keys():
		t_opt.add_item(str(k).capitalize())
		t_opt.set_item_metadata(idx, k)
		if k == current:
			select_idx = idx
		idx += 1
	
	t_opt.selected = select_idx
	t_opt.item_selected.connect(func(index):
		var val = t_opt.get_item_metadata(index)
		tm.set_theme(val)
		# Also sync generic theme option
		var theme_name := String(val)
		theme_option.select(0 if theme_name == "light" else 1)
	)
	theme_row.add_child(t_opt)
	
	# Start Save Button
	var save_btn = Button.new()
	UIHelpers.safe_set_text(save_btn, "Save Custom Theme")
	save_btn.pressed.connect(_on_save_theme_pressed)
	theme_row.add_child(save_btn)
	
	theme_designer_container.add_child(theme_row)
	theme_designer_container.add_child(HSeparator.new())
	
	# --- Colors ---
	var pal: Dictionary = tm.get_palette()
	var keys = pal.keys()
	
	# Sort keys based on KEY_ORDER
	keys.sort_custom(func(a, b):
		var ia = KEY_ORDER.find(a)
		var ib = KEY_ORDER.find(b)
		if ia == -1: ia = 999
		if ib == -1: ib = 999
		if ia != ib: return ia < ib
		return a < b
	)
	
	for k in keys:
		var val = pal[k]
		if typeof(val) != TYPE_COLOR:
			continue
			
		var row = HBoxContainer.new()
		var lbl = Label.new()
		UIHelpers.safe_set_text(lbl, str(k).capitalize())
		lbl.custom_minimum_size.x = 120
		row.add_child(lbl)
		
		var picker = ColorPickerButton.new()
		UIHelpers.safe_set_color(picker, val)
		picker.custom_minimum_size.x = 60
		picker.size_flags_horizontal = SIZE_EXPAND_FILL
		picker.edit_alpha = false
		picker.color_changed.connect(func(c):
			_on_color_changed(k, c)
		)
		row.add_child(picker)
		theme_designer_container.add_child(row)

	theme_designer_container.add_child(HSeparator.new())

	# --- Icon Scale ---
	var scale_row = HBoxContainer.new()
	var s_lbl = Label.new()
	UIHelpers.safe_set_text(s_lbl, "Icon Scale")
	s_lbl.custom_minimum_size.x = 120
	scale_row.add_child(s_lbl)
	
	var s_slider = HSlider.new()
	s_slider.min_value = 0.5
	s_slider.max_value = 2.0
	s_slider.step = 0.05
	UIHelpers.safe_set_value(s_slider, tm.icon_scale)
	s_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	
	var s_val_lbl = Label.new()
	UIHelpers.safe_set_text(s_val_lbl, "%.2f" % tm.icon_scale)
	s_val_lbl.custom_minimum_size.x = 40
	s_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	s_slider.value_changed.connect(func(val):
		UIHelpers.safe_set_text(s_val_lbl, "%.2f" % val)
		if tm: tm.set_icon_scale(val)
		# Force theme resource rebuild on root
		get_tree().root.set_theme(tm.build_basic_theme_resource(tm.current_theme))
	)
	
	scale_row.add_child(s_slider)
	scale_row.add_child(s_val_lbl)
	theme_designer_container.add_child(scale_row)
	
	_updating_themes = false


func _on_color_changed(key: String, color: Color) -> void:
	if not tm: return
	var new_pal = tm.get_palette().duplicate()
	new_pal[key] = color
	tm.set_palette_for_theme(tm.current_theme, new_pal)
	# Force update of global resource on root
	get_tree().root.set_theme(tm.build_basic_theme_resource(tm.current_theme))


func _on_save_theme_pressed() -> void:
	if not tm: return
	var t: Theme = tm.build_basic_theme_resource(tm.current_theme)
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("themes"):
			dir.make_dir("themes")
		
		var fname = "user://themes/%s.tres" % [String(tm.current_theme)]
		var err = ResourceSaver.save(t, fname)
		
		# Also persist to ThemeManager JSON
		if tm.has_method("save_custom_themes"):
			tm.save_custom_themes()
			
		if err == OK:
			Log.info("Settings: saved theme to %s and persisted config" % fname)
			_show_toast("Theme Saved!")
		else:
			Log.error("Settings: Failed to save theme to %s" % fname)
			_show_toast("Error saving theme!")
