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
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.8)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_toast_panel.add_theme_stylebox_override("panel", sb)
	_toast_label = Label.new()
	UIHelpers.safe_set_text(_toast_label, "")
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
	UIHelpers.safe_set_text(_toast_label, text)
	# Apply theme font if available
	var tm: Node = get_tree().root.get_node_or_null("/root/ThemeManager")
	if tm != null:
		var f: Font = tm.get_font() as Font
		if f != null:
			_toast_label.add_theme_font_override("font", f)
	
	_toast_panel.visible = true
	# Force update to get correct size
	_toast_panel.reset_size()
	
	# Position centered above bottom
	var vsize: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = _toast_panel.size
	var target_pos = Vector2((vsize.x - panel_size.x) * 0.5, vsize.y - panel_size.y - 64)
	
	_toast_panel.position = target_pos + Vector2(0, 8) # Start slightly lower
	_toast_panel.modulate.a = 0.0
	_toast_visible = true
	
	# Fade/slide in
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_toast_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(_toast_panel, "position:y", target_pos.y, 0.18)
	_toast_timer.start(duration)


func _on_toast_timeout() -> void:
	if not _toast_visible:
		return
	_toast_visible = false
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_toast_panel, "modulate:a", 0.0, 0.22)
	tw.tween_property(_toast_panel, "position:y", _toast_panel.position.y + 8, 0.22)
	tw.chain().tween_callback(_finish_toast)


func _finish_toast() -> void:
	_toast_panel.visible = false


func _exit_tree() -> void:
	# Ensure toast panel and timer are freed
	if _toast_timer != null and is_instance_valid(_toast_timer):
		_toast_timer.stop()
		# Free immediately on shutdown
		_toast_timer.free()
		_toast_timer = null
	if _toast_panel != null and is_instance_valid(_toast_panel):
		_toast_panel.free()
		_toast_panel = null
	_toast_label = null
	# Free any active Tweens attached to this manager to avoid lingering objects
	for c in get_children():
		# Avoid using 'is' with internal classes in static analysis; compare class name
		if is_instance_valid(c) and c.get_class().find("Tween") != -1:
			# Scene tree tweens (SceneTreeTween) are not directly typed as Tween in static analysis
			var t = c
			if is_instance_valid(t):
				# Try to stop if method exists, then free
				if t.has_method("stop_all"):
					t.stop_all()
				t.queue_free()


# Modal alert dialog (simple blocking callback)
func show_alert(title: String, message: String) -> void:
	var pnl: AcceptDialog = AcceptDialog.new()
	pnl.title = title
	pnl.dialog_text = message
	pnl.dialog_autowrap = true
	get_tree().get_root().add_child(pnl)
	pnl.popup_centered(Vector2(300, 100))
	pnl.confirmed.connect(pnl.queue_free)


# Confirm dialog with callback on confirm(true) / cancel(false)
func show_confirm(title: String, message: String, callback: Callable) -> void:
	var dlg: ConfirmationDialog = ConfirmationDialog.new()
	dlg.title = title
	dlg.dialog_text = message
	dlg.dialog_autowrap = true
	dlg.ok_button_text = "Yes"
	dlg.cancel_button_text = "No"
	
	dlg.confirmed.connect(func():
		callback.call(true)
		dlg.queue_free()
	)
	dlg.canceled.connect(func():
		callback.call(false)
		dlg.queue_free()
	)
	
	get_tree().get_root().add_child(dlg)
	dlg.popup_centered(Vector2(300, 100))
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
