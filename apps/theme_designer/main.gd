extends Control

@onready var tm = get_node_or_null("/root/ThemeManager")
@onready var controls_container = $MainLayout/ScrollContainer/Controls
@onready var button_row = $MainLayout/ButtonRow
@onready var apply_btn = $MainLayout/ButtonRow/ApplyButton
@onready var save_btn = $MainLayout/ButtonRow/SaveButton

const KEY_ORDER = ["bg", "panel", "text", "accent", "accent_hover", "accent_soft"]

# Flag to prevent loop when we update controls from code
var _updating_controls := false

func _ready() -> void:
	if not tm:
		Log.error("Theme Designer: ThemeManager not found")
		return

	# Initial UI Build
	_rebuild_ui()

	# Connect static buttons
	apply_btn.pressed.connect(_on_apply_pressed)
	save_btn.pressed.connect(_on_save_pressed)

	# Listen for external theme changes
	tm.theme_changed.connect(_on_theme_changed)

func _on_theme_changed(_name, _palette) -> void:
	if not _updating_controls:
		_rebuild_ui()

func _rebuild_ui() -> void:
	_updating_controls = true
	
	# Clear dynamic controls
	for c in controls_container.get_children():
		c.queue_free()
	
	# --- Theme Selection ---
	var theme_row = HBoxContainer.new()
	var t_lbl = Label.new()
	UIHelpers.safe_set_text(t_lbl, "Theme:")
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
	)
	theme_row.add_child(t_opt)
	controls_container.add_child(theme_row)
	
	controls_container.add_child(HSeparator.new())
	
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
		# Use deferred connection to avoid immediate signal if init triggers it? No, it's fine.
		picker.color_changed.connect(func(c):
			_on_color_changed(k, c)
		)
		row.add_child(picker)
		controls_container.add_child(row)

	controls_container.add_child(HSeparator.new())

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
	controls_container.add_child(scale_row)
	
	# Move buttons to bottom
	if button_row.get_parent() == controls_container:
		controls_container.move_child(button_row, -1)
	
	_updating_controls = false

func _on_color_changed(key: String, color: Color) -> void:
	if not tm: return
	var new_pal = tm.get_palette().duplicate()
	new_pal[key] = color
	tm.set_palette_for_theme(tm.current_theme, new_pal)
		# Force update of global resource on root
	get_tree().root.set_theme(tm.build_basic_theme_resource(tm.current_theme))

func _on_apply_pressed() -> void:
	if tm:
		get_tree().root.set_theme(tm.build_basic_theme_resource(tm.current_theme))
		_flash_feedback("Applied!")

func _on_save_pressed() -> void:
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
			Log.info("Theme Designer: saved theme to %s and persisted config" % fname)
			_flash_feedback("Saved!")
		else:
			Log.error("Theme Designer: Failed to save theme to %s" % fname)
			_flash_feedback("Error!")

func _flash_feedback(msg: String) -> void:
	var original = UIHelpers.safe_text(save_btn)
	UIHelpers.safe_set_text(save_btn, msg)
	UIHelpers.safe_set_disabled(save_btn, true)
	var timer = get_tree().create_timer(1.5)
	await timer.timeout
	if is_instance_valid(save_btn):
		UIHelpers.safe_set_text(save_btn, original)
		UIHelpers.safe_set_disabled(save_btn, false)

func _exit_tree() -> void:
	# Clear runtime theme when leaving designer (optional)
	pass
