extends Node

var _panel: PanelContainer = null
var _label: Label = null
var _timer: Timer = null

func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.75)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(1,1,1))
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
	_label.text = text
	_panel.visible = true
	_panel.rect_global_position = global_pos + Vector2(8, 16)
	# Apply global font if available
	var tm := get_tree().root.get_node_or_null("/root/ThemeManager")
	if tm != null:
		var f: Font = tm.get_font() as Font
		if f != null:
			_label.add_theme_font_override("font", f)
	_timer.stop()
	_timer.wait_time = duration
	_timer.start()

func hide_tooltip() -> void:
	_timer.stop()
	_panel.visible = false

func _on_timer_timeout() -> void:
	_panel.visible = false
