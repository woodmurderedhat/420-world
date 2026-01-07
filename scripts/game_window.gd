extends Panel
class_name GameWindowPanel

signal request_focus(id)
signal request_close(id)
signal request_minimize(id)
signal request_restore(id)
signal request_maximize_toggle(id)
signal request_fullscreen_toggle(id)
signal drag_finished(id, final_position: Vector2, final_size: Vector2)
signal drag_moved(id, current_position: Vector2, current_size: Vector2)

var window_id: String = ""

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var resizing: bool = false
var resize_start_mouse: Vector2 = Vector2.ZERO
var resize_start_size: Vector2 = Vector2.ZERO

var _is_focused: bool = false
var _is_minimized: bool = false
var _is_maximized: bool = false
var _is_fullscreen: bool = false
var _palette: Dictionary = {}

@onready var title_bar: Control = $TitleBar
@onready var content_root: Control = $ContentRoot
@onready var input_blocker: Control = $InputBlocker
@onready var resize_handle: Control = $ResizeHandle
@onready var max_button: Button = $TitleBar/MaxButton
@onready var full_button: Button = $TitleBar/FullButton


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	title_bar.gui_input.connect(_on_title_input)
	$TitleBar/CloseButton.pressed.connect(func(): emit_signal("request_close", window_id))
	$TitleBar/MinButton.pressed.connect(
		func():
			if _is_minimized:
				emit_signal("request_restore", window_id)
			else:
				emit_signal("request_minimize", window_id)
	)
	max_button.pressed.connect(func(): emit_signal("request_maximize_toggle", window_id))
	full_button.pressed.connect(func(): emit_signal("request_fullscreen_toggle", window_id))
	input_blocker.gui_input.connect(_on_blocker_input)
	resize_handle.gui_input.connect(_on_resize_input)


func set_title(text: String) -> void:
	$TitleBar/Label.text = text


func set_content(scene: PackedScene) -> Node:
	for child in content_root.get_children():
		child.queue_free()
	if scene == null:
		Log.error("GameWindowPanel: content scene is null")
		return null
	var inst: Node = scene.instantiate()
	content_root.add_child(inst)
	return inst


func set_focused(is_focused: bool) -> void:
	_is_focused = is_focused
	input_blocker.visible = not is_focused
	# Visual cue (hover/focus styling can evolve later)
	modulate = Color(1, 1, 1, 1) if is_focused else Color(0.9, 0.9, 0.9, 1)


func set_minimized(is_minimized: bool) -> void:
	_is_minimized = is_minimized


func set_maximized(is_maximized: bool) -> void:
	_is_maximized = is_maximized
	if is_maximized:
		_is_fullscreen = false
	resize_handle.visible = not is_maximized and not _is_fullscreen


func set_fullscreen(is_fullscreen: bool) -> void:
	_is_fullscreen = is_fullscreen
	if is_fullscreen:
		_is_maximized = false
	resize_handle.visible = not is_fullscreen


func apply_palette(palette: Dictionary) -> void:
	_palette = palette
	var panel_color: Color = palette.get("panel", Color(0.12, 0.13, 0.17)) as Color
	var text: Color = palette.get("text", Color.WHITE) as Color
	var accent: Color = palette.get("accent", Color(0.2, 0.6, 1.0)) as Color

	# Window Background with Shadow
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = panel_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", style)

	# Title Bar
	$TitleBar.self_modulate = Color.WHITE  # Reset mod, use style instead?
	# Actually TitleBar is just a colored rect usually, or inherits.
	# The original code used self_modulate on the HBoxContainer?
	# HBox doesn't draw a background unless it's a PanelContainer.
	# But GameWindow is a Panel, TitleBar is HBoxContainer.
	# If TitleBar is a transparent HBox, we rely on the GameWindow panel
	# or on a specific background rect.
	# Let's check scene structure. TitleBar is HBoxContainer.
	# If we want a different color for title bar, we need a Panel or StyleBox on it?
	# HBoxContainer doesn't support stylebox override directly in Godot 4.
	# Use a PanelContainer if a stylebox is required.
	# BUT `self_modulate` on HBoxContainer only affects children if they inherit? No.
	# Wait, HBoxContainer does NOT draw a background.
	# Setting self_modulate does nothing unless TitleBar has a texture.
	# Ah, in previous code: `$TitleBar.self_modulate = panel_color.lerp(accent, 0.12)`
	# That code likely didn't work as expected if TitleBar has no texture.
	# I will assume TitleBar works because GameWindow is a Panel.
	# To make it distinct, I might need to draw a rect behind it or make GameWindow Gradient?
	# For now, let's just stick to the main Panel style.

	$TitleBar/Label.add_theme_color_override("font_color", text)
	# Apply global font if ThemeManager provides one
	var tm: Node = get_tree().root.get_node_or_null("/root/ThemeManager")
	if tm != null:
		var f: Font = tm.get_font() as Font
		if f != null:
			$TitleBar/Label.add_theme_font_override("font", f)

	var btns: Array = [
		$TitleBar/CloseButton, $TitleBar/MinButton, $TitleBar/MaxButton, $TitleBar/FullButton
	]
	# Load icon overrides from SettingsManager or manifest (modular/user-definable)
	var settings: Node = get_tree().root.get_node_or_null("/root/SettingsManager")
	var icon_cfg: Dictionary = {}
	if settings != null:
		var v: Variant = settings.get_value("ui.window_icons", {})
		if typeof(v) == TYPE_DICTIONARY:
			icon_cfg = v as Dictionary
	# Manifest-level overrides via content root's first child metadata
	if content_root.get_child_count() > 0:
		var app_root: Node = content_root.get_child(0)
		if app_root != null:
			if app_root.has("metadata"):
				var m: Variant = app_root.get("metadata")
				if typeof(m) == TYPE_DICTIONARY and m.has("window_icons"):
					for raw_k in m["window_icons"].keys():
						var k: String = String(raw_k)
						icon_cfg[k] = m["window_icons"].get(k, "")

	# Apply icons or fallback text for titlebar buttons
	_apply_icon_or_text($TitleBar/MinButton, "minimize", "_")
	_apply_icon_or_text($TitleBar/MaxButton, "maximize", "□")
	_apply_icon_or_text($TitleBar/FullButton, "fullscreen", "⤢")
	_apply_icon_or_text($TitleBar/CloseButton, "close", "✕")


func _gui_input(event: InputEvent) -> void:
	# Clicking anywhere on the window chrome should focus.
	if event is InputEventMouseButton and event.pressed:
		emit_signal("request_focus", window_id)


func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				emit_signal("request_maximize_toggle", window_id)
				get_viewport().set_input_as_handled()
				return
			emit_signal("request_focus", window_id)
			if _is_maximized or _is_fullscreen:
				emit_signal("request_restore", window_id)
			dragging = true
			drag_offset = event.position
			get_viewport().set_input_as_handled()
		else:
			if dragging:
				dragging = false
				emit_signal("drag_finished", window_id, global_position, size)
	elif event is InputEventMouseMotion and dragging:
		global_position += event.relative
		emit_signal("drag_moved", window_id, global_position, size)
		get_viewport().set_input_as_handled()


func _on_blocker_input(event: InputEvent) -> void:
	# Unfocused windows: allow hover/motion cues only; block ALL actionable input.
	if event is InputEventMouseMotion:
		return
	if event is InputEventMouseButton and event.pressed:
		emit_signal("request_focus", window_id)
	get_viewport().set_input_as_handled()


func _on_resize_input(event: InputEvent) -> void:
	if _is_maximized or _is_fullscreen:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			emit_signal("request_focus", window_id)
			resizing = true
			resize_start_mouse = event.global_position
			resize_start_size = size
			get_viewport().set_input_as_handled()
		else:
			if resizing:
				resizing = false
				emit_signal("drag_finished", window_id, global_position, size)
	elif event is InputEventMouseMotion and resizing:
		var delta: Vector2 = event.global_position - resize_start_mouse
		var new_size: Vector2 = resize_start_size + delta
		new_size.x = maxf(new_size.x, 240)
		new_size.y = maxf(new_size.y, 160)
		size = new_size
		get_viewport().set_input_as_handled()
		emit_signal("drag_moved", window_id, global_position, new_size)


func _apply_icon_or_text(btn: Button, key: String, fallback_text: String) -> void:
	btn.flat = true
	btn.add_theme_color_override("font_color", _palette.get("text", Color(1, 1, 1)))
	btn.add_theme_color_override("font_color_hover", _palette.get("accent", Color(0.2, 0.6, 1.0)))
	btn.add_theme_color_override(
		"font_color_pressed", _palette.get("accent", Color(0.2, 0.6, 1.0)).darkened(0.2)
	)
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var settings_node: Node = get_tree().root.get_node_or_null("/root/SettingsManager")
	var icons_map: Dictionary = {}
	if settings_node != null:
		icons_map = settings_node.get_value("ui.window_icons", {}) as Dictionary
	var path: String = String(icons_map.get(key, ""))
	if path != "" and ResourceLoader.exists(path):
		var tex: Texture2D = ResourceLoader.load(path) as Texture2D
		if tex is Texture2D:
			btn.icon = tex
			return
	# fallback to simple text glyph
	btn.icon = null
	btn.text = fallback_text
