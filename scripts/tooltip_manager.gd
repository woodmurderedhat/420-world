extends Node

var _panel: PanelContainer = null
var _label: Label = null
var _timer: Timer = null


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.75)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	# Use a theme stylebox for spacing instead of margin_* properties
	_label.add_theme_constant_override("margin_left", 8)
	_label.add_theme_constant_override("margin_right", 8)
	_label.add_theme_constant_override("margin_top", 6)
	_label.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(_label)
	add_child(_panel)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 3.0
	_timer.autostart = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func show_tooltip(text: String, global_pos: Vector2, duration: float = 3.0) -> void:
	UIHelpers.safe_set_text(_label, text)
	_panel.visible = true

	# Compute tooltip position with adaptive placement and viewport clamping
	var offset_below: Vector2 = Vector2(8, 16)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = Utils.get_control_size(_panel)

	var preferred_pos: Vector2 = global_pos + offset_below
	# If tooltip doesn't fit below the anchor, prefer placing it above
	if preferred_pos.y + panel_size.y > vp_size.y:
		preferred_pos = global_pos + Vector2(8, -panel_size.y - 8)

	# Clamp to viewport bounds so tooltip never goes off-screen (2px margin)
	_panel.global_position = Utils.clamp_to_viewport(preferred_pos, panel_size, vp_size, Vector2(2, 2))

	# Apply global font if available
	var tm: Node = get_tree().root.get_node_or_null("/root/ThemeManager")
	if tm != null:
		var f: Font = tm.get_font() as Font
		if f != null:
			_label.add_theme_font_override("font", f)
	_timer.stop()
	_timer.wait_time = duration
	_timer.start()

# For tests and UI assertions
func is_visible() -> bool:
	return _panel.visible

func get_text() -> String:
	return _label.text


func hide_tooltip() -> void:
	_timer.stop()
	_panel.visible = false


func _on_timer_timeout() -> void:
	_panel.visible = false


func _exit_tree() -> void:
	# Cleanup dynamically created UI to avoid leaked CanvasItem RIDs
	if _timer != null and is_instance_valid(_timer):
		_timer.stop()
		_timer.queue_free()
		_timer = null
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
	if _label != null:
		_label = null
