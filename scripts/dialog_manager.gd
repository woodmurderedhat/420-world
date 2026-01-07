extends CanvasLayer

var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: Timer

var _toast_visible: bool = false

func _ready() -> void:
	self.layer = 100
	# Create toast panel
	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 0.95
	_toast_panel.anchor_bottom = 0.95
	_toast_panel.custom_minimum_size = Vector2(320, 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.8)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_toast_panel.add_theme_stylebox_override("panel", sb)
	_toast_label = Label.new()
	_toast_label.text = ""
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)
	add_child(_toast_panel)

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.autostart = false
	_toast_timer.timeout.connect(_on_toast_timeout)
	add_child(_toast_timer)

func show_toast(text: String, duration: float = 2.0) -> void:
	_toast_label.text = text
	# Apply theme font if available
	var tm := get_tree().root.get_node_or_null("/root/ThemeManager")
	if tm != null:
		var f: Font = tm.get_font() as Font
		if f != null:
			_toast_label.add_theme_font_override("font", f)
	# Position centered above bottom
	var vsize: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = _toast_panel.custom_minimum_size
	_toast_panel.rect_size = panel_size
	_toast_panel.rect_position = Vector2((vsize.x - panel_size.x) * 0.5, vsize.y - 96)
	_toast_panel.modulate = Color(1, 1, 1, 0.0)
	_toast_panel.visible = true
	_toast_visible = true
	# Fade/slide in
	var tw = create_tween()
	tw.tween_property(_toast_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(_toast_panel, "rect_position:y", _toast_panel.rect_position.y - 8, 0.18)
	_toast_timer.start(duration)

func _on_toast_timeout() -> void:
	if not _toast_visible:
		return
	_toast_visible = false
	var tw = create_tween()
	tw.tween_property(_toast_panel, "modulate:a", 0.0, 0.22)
	tw.tween_property(_toast_panel, "rect_position:y", _toast_panel.rect_position.y + 8, 0.22)
	tw.tween_callback(Callable(self, "_finish_toast"))

func _finish_toast() -> void:
	_toast_panel.visible = false

# Modal alert dialog (simple blocking callback)
func show_alert(title: String, message: String) -> void:
	var pnl: AcceptDialog = AcceptDialog.new()
	pnl.window_title = title
	var lbl: Label = Label.new()
	lbl.text = message
	pnl.add_child(lbl)
	get_tree().get_root().add_child(pnl)
	pnl.popup_centered()

# Confirm dialog with callback on confirm(true) / cancel(false)
func show_confirm(title: String, message: String, callback: Callable) -> void:
	var dlg: ConfirmationDialog = ConfirmationDialog.new()
	dlg.window_title = title
	dlg.get_ok().text = "Yes"
	dlg.get_cancel().text = "No"
	var lbl: Label = Label.new()
	lbl.text = message
	dlg.add_child(lbl)
	dlg.get_ok().pressed.connect(Callable(self, "_on_confirm_ok").bind(callback, dlg))
	dlg.get_cancel().pressed.connect(Callable(self, "_on_confirm_cancel").bind(callback, dlg))
	get_tree().get_root().add_child(dlg)
	dlg.popup_centered()

func _on_confirm_ok(callback: Callable, dlg: ConfirmationDialog) -> void:
	if callback != null:
		callback.call(true)
	if dlg != null:
		dlg.queue_free()

func _on_confirm_cancel(callback: Callable, dlg: ConfirmationDialog) -> void:
	if callback != null:
		callback.call(false)
	if dlg != null:
		dlg.queue_free()
