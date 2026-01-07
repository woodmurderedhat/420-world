class_name TaskbarUI
extends PanelContainer

signal window_action_requested(window_id: String, action: StringName)
signal start_menu_toggled
signal tray_icon_pressed(icon_id: String)
signal app_launch_requested(app_id: String)
signal pin_app_requested(app_id: String, pin: bool)

var _buttons: Dictionary = {}  # window_id -> Button
var _states: Dictionary = {}  # window_id -> state string
var _titles: Dictionary = {}  # window_id -> title
var _icons: Dictionary = {}  # window_id -> Texture2D
var _badges: Dictionary = {}  # window_id -> Control
var _window_app: Dictionary = {}  # window_id -> app_id
var _app_windows: Dictionary = {}  # app_id -> Array[String]
var _pinned_buttons: Dictionary = {}  # app_id -> Button
var _manifest_lookup: Dictionary = {}  # app_id -> manifest
var _palette: Dictionary = {}

@onready var start_button: Button = $HBox/StartButton
@onready var pinned_box: HBoxContainer = $HBox/PinnedBox
@onready var windows_box: HBoxContainer = get_node_or_null("HBox/WindowScroll/WindowsBox")
@onready var tray_box: HBoxContainer = get_node_or_null("HBox/TrayBox") as HBoxContainer
@onready var clock_label: Label = get_node_or_null("HBox/ClockLabel") as Label
@onready var volume_button: Button = get_node_or_null("HBox/TrayBox/VolumeButton") as Button
@onready var _clock_timer: Timer = get_node_or_null("ClockTimer") as Timer


func _ready() -> void:
	start_button.pressed.connect(func(): emit_signal("start_menu_toggled"))
	start_button.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	start_button.add_theme_color_override("font_color_hover", Color(1.0, 1.0, 1.0))
	start_button.custom_minimum_size = Vector2(72, 32)
	add_theme_constant_override("separation", 6)

	# Clock setup
	if _clock_timer:
		_clock_timer.timeout.connect(_update_clock)
		_update_clock()
	# Tray icons
	if volume_button:
		volume_button.pressed.connect(func(): emit_signal("tray_icon_pressed", "volume"))
	set_process(false)


func set_pinned_apps(app_ids: Array, manifest_lookup: Dictionary = {}) -> void:
	for b in _pinned_buttons.values():
		b.queue_free()
	_pinned_buttons.clear()
	_manifest_lookup = manifest_lookup
	for raw_id in app_ids:
		var app_id: String = String(raw_id)
		var manifest: Dictionary = manifest_lookup.get(app_id, {})
		var btn: Button = _make_pinned_button(app_id, manifest)
		pinned_box.add_child(btn)
		_pinned_buttons[app_id] = btn


func add_window(window_id: String, app_id: String, title: String, icon: Texture2D = null) -> void:
	if _buttons.has(window_id):
		_titles[window_id] = title
		_icons[window_id] = icon
		_apply_button_state(window_id)
		return
	var b: Button = Button.new()
	b.toggle_mode = true
	# Fixed min width to force scrolling in ScrollContainer
	b.custom_minimum_size = Vector2(145, 32)
	_titles[window_id] = title
	_icons[window_id] = icon
	UIHelpers.safe_set_text(b, title)
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_wire_window_button_inputs(b, window_id)
	b.pressed.connect(func(): _on_button_pressed(window_id))
	windows_box.add_child(b)
	_buttons[window_id] = b
	_states[window_id] = "open"
	_window_app[window_id] = app_id
	var app_list: Array = _app_windows.get(app_id, []) as Array
	if app_list == null:
		app_list = []
	app_list.append(window_id)
	_app_windows[app_id] = app_list
	_badges[window_id] = _make_badge()
	b.add_child(_badges[window_id])
	_apply_button_state(window_id)

	# Auto-scroll to end if possible
	if windows_box.get_parent() is ScrollContainer:
		var sc: ScrollContainer = windows_box.get_parent() as ScrollContainer
		# Defer scroll to next frame after layout update
		get_tree().process_frame.connect(func(): sc.scroll_horizontal = int(windows_box.size.x))


func remove_window(window_id: String) -> void:
	if not _buttons.has(window_id):
		return
	_buttons[window_id].queue_free()
	_buttons.erase(window_id)
	_states.erase(window_id)
	_titles.erase(window_id)
	_icons.erase(window_id)
	_badges.erase(window_id)
	var app_id: String = String(_window_app.get(window_id, ""))
	_window_app.erase(window_id)
	if app_id != "" and _app_windows.has(app_id):
		_app_windows[app_id].erase(window_id)
		if _app_windows[app_id].is_empty():
			_app_windows.erase(app_id)


func set_focused(window_id: String) -> void:
	set_window_state(window_id, "focused")


func set_window_state(window_id: String, state: String) -> void:
	if not _buttons.has(window_id):
		return
	_states[window_id] = state
	_apply_button_state(window_id)


func _on_button_pressed(window_id: String) -> void:
	var state: String = String(_states.get(window_id, ""))
	match state:
		"minimized":
			emit_signal("window_action_requested", window_id, "restore")
		"focused":
			emit_signal("window_action_requested", window_id, "minimize")
		_:
			emit_signal("window_action_requested", window_id, "focus")


func _on_pinned_pressed(app_id: String) -> void:
	var existing: Array = _app_windows.get(app_id, []) as Array
	if existing == null:
		existing = []
	if existing.size() > 0:
		emit_signal("window_action_requested", String(existing[0]), "focus")
		return
	emit_signal("app_launch_requested", app_id)


func _apply_button_state(window_id: String) -> void:
	if not _buttons.has(window_id):
		return
	var b: Button = _buttons[window_id]
	var title: String = String(_titles.get(window_id, UIHelpers.safe_text(b)))
	var state: String = String(_states.get(window_id, "open"))
	var icon: Texture2D = _icons.get(window_id, null)
	# Use ThemeManager helper to apply icons consistently
	var tm: Node = get_tree().root.get_node_or_null("/root/ThemeManager")
	if tm != null:
		(tm as Object).apply_icon_to_button(b, icon)
	else:
		b.icon = icon
	UIHelpers.safe_set_text(b, title.substr(0, 16) + ("..." if title.length() > 16 else ""))
	UIHelpers.safe_set_bool(b, (state == "focused"))
	UIHelpers.safe_set_disabled(b, false)
	var badge: Control = _badges.get(window_id, null)
	if badge:
		badge.visible = (state == "minimized")

	b.flat = false
	var is_open := state != "closed" and state != "minimized"
	var is_focused := state == "focused"
	_style_button(b, is_focused or is_open, true)

	if is_focused:
		UIHelpers.safe_set_modulate(b, Color(1, 1, 1, 1))
	else:
		UIHelpers.safe_set_modulate(b, Color(0.9, 0.9, 0.9, 0.8))


func _make_pinned_button(app_id: String, manifest: Dictionary) -> Button:
	var b: Button = Button.new()
	UIHelpers.safe_set_text(b, "")
	b.tooltip_text = String(manifest.get("name", app_id))
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var tm: Node = get_tree().root.get_node_or_null("/root/ThemeManager")
	var tex: Texture2D = null
	var icon_path: String = ""
	if manifest.has("icon") and typeof(manifest["icon"]) == TYPE_STRING:
		icon_path = String(manifest["icon"])

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var res: Resource = ResourceLoader.load(icon_path)
		if res is Texture2D:
			tex = res as Texture2D
	
	if tex == null and ResourceLoader.exists("res://assets/icons/default_app.svg"):
		tex = ResourceLoader.load("res://assets/icons/default_app.svg") as Texture2D

	# Apply via ThemeManager helper so pinned sizing is correct
	if tex != null and tm != null:
		(tm as Object).apply_icon_to_button(b, tex)
		if tm.has_method("get_pinned_icon_vector"):
			b.custom_minimum_size = tm.get_pinned_icon_vector()
	elif tex != null:
		b.icon = tex
		b.expand_icon = true
		b.custom_minimum_size = Vector2(32, 32)
	
	b.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var menu := PopupMenu.new()
			add_child(menu)
			menu.add_item("Unpin from Taskbar", 1)
			menu.id_pressed.connect(func(_id):
				emit_signal("pin_app_requested", app_id, false)
				menu.queue_free()
			)
			menu.popup_hide.connect(menu.queue_free)
			menu.popup(Rect2(event.global_position, Vector2(160, 48)))
	)

	b.pressed.connect(func(): _on_pinned_pressed(app_id))

	_style_button(b, false, false)

	# TooltipManager (if autoload present)
	var tt: Node = get_tree().root.get_node_or_null("/root/TooltipManager")
	if tt != null:
		b.mouse_entered.connect(
			func(): tt.show_tooltip(String(manifest.get("name", app_id)), b.get_global_position())
		)
		b.mouse_exited.connect(func(): tt.hide_tooltip())
	return b


func _make_badge() -> Control:
	var c: ColorRect = ColorRect.new()
	c.color = Color(0.95, 0.35, 0.35, 1)
	c.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	c.offset_left = -14.0
	c.offset_right = -4.0
	c.offset_top = 4.0
	c.offset_bottom = 14.0
	c.visible = false
	return c


func _wire_window_button_inputs(button: Button, window_id: String) -> void:
	button.gui_input.connect(
		func(event: InputEvent):
			if (
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_MIDDLE
				and event.pressed
			):
				emit_signal("window_action_requested", window_id, "close")
				get_viewport().set_input_as_handled()
			elif (
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_RIGHT
				and event.pressed
			):
				_show_context_menu(window_id, button, event)
	)


func _update_clock() -> void:
	if clock_label != null:
		var time = Time.get_time_dict_from_system()
		UIHelpers.safe_set_text(clock_label, "%02d:%02d" % [time.hour, time.minute])


func _show_context_menu(window_id: String, _button: Button, event: InputEventMouseButton) -> void:
	var menu: PopupMenu = PopupMenu.new()
	var app_id: String = String(_window_app.get(window_id, ""))
	var is_pinned: bool = _pinned_buttons.has(app_id)
	
	add_child(menu)
	menu.add_item("Focus", 1)
	menu.add_item("Minimize", 2)
	menu.add_separator()
	if app_id != "":
		if is_pinned:
			menu.add_item("Unpin from Taskbar", 4)
		else:
			menu.add_item("Pin to Taskbar", 4)
		menu.add_separator()
	menu.add_item("Close", 3)
	
	menu.id_pressed.connect(
		func(id: int):
			match id:
				1:
					emit_signal("window_action_requested", window_id, "focus")
				2:
					emit_signal("window_action_requested", window_id, "minimize")
				3:
					emit_signal("window_action_requested", window_id, "close")
				4:
					emit_signal("pin_app_requested", app_id, not is_pinned)
			menu.queue_free()
	)
	menu.popup_hide.connect(menu.queue_free)
	menu.popup(Rect2(event.global_position, Vector2(160, 128)))


func apply_palette(palette: Dictionary) -> void:
	_palette = palette
	var bg_color: Color = palette.get("panel", Color.BLACK)
	self_modulate = bg_color

	# Update Start Button
	var accent: Color = palette.get("accent", Color.BLUE)
	var text: Color = palette.get("text", Color.WHITE)
	var sb_style_n: StyleBoxFlat = StyleBoxFlat.new()
	sb_style_n.bg_color = accent.darkened(0.3)
	sb_style_n.corner_radius_top_left = 4
	sb_style_n.corner_radius_top_right = 4
	sb_style_n.corner_radius_bottom_left = 4
	sb_style_n.corner_radius_bottom_right = 4
	sb_style_n.content_margin_left = 12
	sb_style_n.content_margin_right = 12
	start_button.add_theme_stylebox_override("normal", sb_style_n)
	var sb_style_h: StyleBoxFlat = sb_style_n.duplicate()
	sb_style_h.bg_color = accent
	start_button.add_theme_stylebox_override("hover", sb_style_h)
	var sb_style_p: StyleBoxFlat = sb_style_n.duplicate()
	sb_style_p.bg_color = accent.lightened(0.2)
	start_button.add_theme_stylebox_override("pressed", sb_style_p)

	start_button.add_theme_color_override("font_color", text)
	start_button.add_theme_color_override("font_color_hover", Color(text.r, text.g, text.b, 1))
	start_button.add_theme_color_override("font_color_pressed", accent)

	# Update Window Buttons
	for id in _buttons.keys():
		_apply_button_state(String(id))

	# Update Pinned Buttons
	for b in _pinned_buttons.values():
		_style_button(b, false, false)

	# Clock color
	if clock_label:
		var text_color: Color = palette.get("text", Color.WHITE)
		clock_label.add_theme_color_override("font_color", text_color)
		UIHelpers.safe_set_text(clock_label, UIHelpers.safe_text(clock_label))

	# Apply global font if ThemeManager provides one
	var tm: Node = get_tree().root.get_node_or_null("/root/ThemeManager")
	if tm != null:
		var f: Font = tm.get_font() as Font
		if f != null:
			start_button.add_theme_font_override("font", f)
			for b in _pinned_buttons.values():
				b.add_theme_font_override("font", f)
			for id in _buttons.keys():
				var bt: Button = _buttons[id] as Button
				if bt:
					bt.add_theme_font_override("font", f)


func _style_button(b: Button, active: bool, _has_badge: bool) -> void:
	var accent: Color = _palette.get("accent", Color.BLUE)
	var text_col: Color = _palette.get("text", Color.WHITE)

	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_color_hover", text_col)
	b.add_theme_color_override("font_color_pressed", text_col)

	var style_n: StyleBoxFlat = StyleBoxFlat.new()
	style_n.bg_color = Color(1, 1, 1, 0.05) if active else Color.TRANSPARENT
	style_n.corner_radius_top_left = 4
	style_n.corner_radius_top_right = 4
	style_n.corner_radius_bottom_left = 4
	style_n.corner_radius_bottom_right = 4
	style_n.border_width_bottom = 2 if active else 0
	style_n.border_color = accent

	var style_h: StyleBoxFlat = style_n.duplicate()
	style_h.bg_color = Color(1, 1, 1, 0.1)

	var style_p: StyleBoxFlat = style_n.duplicate()
	style_p.bg_color = Color(1, 1, 1, 0.2)

	b.add_theme_stylebox_override("normal", style_n)
	b.add_theme_stylebox_override("hover", style_h)
	b.add_theme_stylebox_override("pressed", style_p)


func _start_menu_btn_init() -> void:
	# Keep this for reference if we need to reset start button default init
	pass
