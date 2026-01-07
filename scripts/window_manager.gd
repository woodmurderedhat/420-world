extends Control
class_name GameWindowManager

signal window_opened(id)
signal window_closed(id)
signal window_focused(id)
signal window_minimized(id)
signal window_restored(id)

@export var window_scene: PackedScene = preload("res://scenes/game_window.tscn")

const KNOWN_PERMISSIONS := {
	"filesystem.read": "Read user data",
	"filesystem.write": "Write user data",
	"inventory": "Access shared inventory",
	"network": "Network access",
	"settings": "Modify settings",
}

var windows: Dictionary = {} # id -> Dictionary
var z_counter := 0
var focused_id: String = ""

var _last_rect_by_app: Dictionary = {} # app_id -> Rect2
var _snap_preview: ColorRect = null
var _snap_panel: PanelContainer = null
var _snap_fill: ColorRect = null

var work_area: Rect2 = Rect2(Vector2.ZERO, Vector2(1080, 720))

const SNAP_MARGIN := 32.0
const CENTER_SNAP_MARGIN := 64.0

const STATE_OPEN := "open"
const STATE_FOCUSED := "focused"
const STATE_MINIMIZED := "minimized"
const STATE_CLOSED := "closed"

func set_work_area(rect: Rect2) -> void:
	work_area = rect

func open_app(app_id: String, params: Dictionary = {}) -> String:
	var manifest := AppRegistry.get_manifest(app_id)
	if manifest.is_empty():
		Log.warn("WindowManager: unknown app_id %s" % app_id)
		return ""
	var entry_path := String(manifest.get("entry_scene", ""))
	var scene_res := load(entry_path)
	if scene_res == null:
		Log.error("WindowManager: failed to load entry scene %s for %s" % [entry_path, app_id])
		return ""
	if not (scene_res is PackedScene):
		Log.error("WindowManager: entry scene is not a PackedScene for %s (%s)" % [app_id, entry_path])
		return ""
	return open_window(app_id, String(manifest.get("name", app_id)), scene_res, manifest, params)

func open_window(app_id: String, title: String, scene: PackedScene, manifest: Dictionary = {}, params: Dictionary = {}) -> String:
	var win: GameWindowPanel = window_scene.instantiate()
	add_child(win)
	_warn_permissions(manifest)

	var id := "%s_%d" % [app_id, Time.get_ticks_usec()]
	win.window_id = id
	win.set_title(title)
	win.global_position = work_area.position + Vector2(80, 80)
	win.size = Vector2(640, 420)
	if _last_rect_by_app.has(app_id):
		var remembered: Rect2 = _last_rect_by_app[app_id]
		win.global_position = remembered.position
		win.size = remembered.size
		_clamp_to_work_area(win)

	win.request_focus.connect(_on_request_focus)
	win.request_close.connect(_on_request_close)
	win.request_minimize.connect(_on_request_minimize)
	win.request_restore.connect(_on_request_restore)
	win.request_maximize_toggle.connect(_on_request_maximize)
	win.request_fullscreen_toggle.connect(_on_request_fullscreen)
	win.drag_finished.connect(_on_drag_finished)
	win.drag_moved.connect(_on_drag_moved)

	var app_node := win.set_content(scene)
	var save_mgr := get_tree().root.get_node_or_null("/root/SaveManager")
	if app_node is AppBase:
		app_node.metadata = manifest
		if save_mgr != null:
			var saved_state: Dictionary = save_mgr.load_app(app_id)
			app_node.load_state(saved_state.get("state", {}))
		app_node.launch(params)
	else:
		Log.warn("WindowManager: app root does not extend AppBase (%s)" % app_id)

	z_counter += 1
	win.z_index = z_counter

	windows[id] = {
		"node": win,
		"state": STATE_OPEN,
		"app_id": app_id,
		"title": title,
		"app_node": app_node,
		"restore_rect": Rect2(win.global_position, win.size),
		"manifest": manifest,
		"is_maximized": false,
		"is_fullscreen": false,
	}

	_focus_window(id)
	emit_signal("window_opened", id)
	return id

func _focus_window(id: String) -> void:
	if not windows.has(id):
		return
	if windows[id].get("state", STATE_OPEN) == STATE_MINIMIZED:
		restore_window(id)
		return
	if focused_id == id:
		return

	var prev := focused_id
	focused_id = id

	if prev != "" and windows.has(prev):
		windows[prev]["state"] = STATE_OPEN
		var prev_win: GameWindowPanel = windows[prev]["node"]
		prev_win.set_focused(false)
		var prev_app: Node = windows[prev].get("app_node")
		if prev_app is AppBase:
			prev_app.pause()

	z_counter += 1
	var win: GameWindowPanel = windows[id]["node"]
	win.z_index = z_counter
	win.set_focused(true)
	win.visible = true
	win.set_minimized(false)
	windows[id]["state"] = STATE_FOCUSED

	var app: Node = windows[id].get("app_node")
	if app is AppBase:
		app.resume()

	emit_signal("window_focused", id)

func focus_window(id: String) -> void:
	_focus_window(id)

func _on_request_focus(id: String) -> void:
	_focus_window(id)

func _on_request_close(id: String) -> void:
	close_window(id)

func close_window(id: String) -> void:
	if not windows.has(id):
		return
	var app_id: String = windows[id]["app_id"]
	var app: Node = windows[id].get("app_node")
	if app is AppBase:
		var state: Dictionary = app.save_state()
		var sm := get_tree().root.get_node_or_null("/root/SaveManager")
		if sm != null:
			sm.save_app(app_id, {"state": state})
	var win: GameWindowPanel = windows[id]["node"]
	if not windows[id].get("is_fullscreen", false):
		var rect_to_store: Rect2 = windows[id].get("restore_rect", Rect2(win.global_position, win.size))
		_last_rect_by_app[app_id] = rect_to_store
	win.queue_free()
	windows.erase(id)
	if focused_id == id:
		focused_id = ""
	emit_signal("window_closed", id)

func _on_request_minimize(id: String) -> void:
	minimize_window(id)

func minimize_window(id: String) -> void:
	if not windows.has(id):
		return
	var win: GameWindowPanel = windows[id]["node"]
	windows[id]["restore_rect"] = Rect2(win.global_position, win.size)
	
	var perform_minimize := func():
		win.visible = false
		win.set_minimized(true)
		windows[id]["state"] = STATE_MINIMIZED
		win.set_focused(false)
		if focused_id == id:
			focused_id = ""
		var app: Node = windows[id].get("app_node")
		if app is AppBase:
			app.pause()
		emit_signal("window_minimized", id)

	var anim: bool = bool(SettingsManager.get_value("ui.animations", true))
	if anim:
		win.pivot_offset = win.size / 2.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(win, "scale", Vector2(0.9, 0.9), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(win, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(perform_minimize)
		tween.tween_callback(func():
			win.scale = Vector2.ONE
			win.modulate.a = 1.0
		)
	else:
		perform_minimize.call()

func _on_request_restore(id: String) -> void:
	restore_window(id)

func restore_window(id: String) -> void:
	if not windows.has(id):
		return
	var win: GameWindowPanel = windows[id]["node"]
	win.visible = true
	win.set_minimized(false)
	if windows[id].get("is_fullscreen", false):
		_apply_fullscreen_geometry(id)
	elif windows[id].get("is_maximized", false):
		_apply_maximized_geometry(id)
	else:
		_restore_rect(id)
	windows[id]["state"] = STATE_OPEN
	_focus_window(id)
	
	var anim: bool = bool(SettingsManager.get_value("ui.animations", true))
	if anim:
		win.modulate.a = 0.0
		win.scale = Vector2(0.95, 0.95)
		win.pivot_offset = win.size / 2.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(win, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(win, "modulate:a", 1.0, 0.2)
	
	emit_signal("window_restored", id)

func get_window_title(id: String) -> String:
	if not windows.has(id):
		return ""
	return String(windows[id].get("title", id))

func get_window_app_id(id: String) -> String:
	if not windows.has(id):
		return ""
	return String(windows[id].get("app_id", ""))

func get_window_state(id: String) -> String:
	if not windows.has(id):
		return ""
	return String(windows[id].get("state", ""))

func get_window_z_index(id: String) -> int:
	if not windows.has(id):
		return -1
	var win: GameWindowPanel = windows[id]["node"]
	return win.z_index

func get_focused_window_id() -> String:
	return focused_id

func _on_request_maximize(id: String) -> void:
	maximize_window(id)

func maximize_window(id: String) -> void:
	if not windows.has(id):
		return
	if windows[id].get("is_fullscreen", false):
		return
	var win: GameWindowPanel = windows[id]["node"]
	if windows[id].get("is_maximized", false):
		_restore_rect(id)
		_focus_window(id)
		return
	windows[id]["restore_rect"] = Rect2(win.global_position, win.size)
	windows[id]["is_maximized"] = true
	windows[id]["is_fullscreen"] = false
	_apply_maximized_geometry(id)
	_focus_window(id)

func _apply_maximized_geometry(id: String) -> void:
	if not windows.has(id):
		return
	var win: GameWindowPanel = windows[id]["node"]
	win.set_maximized(true)
	win.set_fullscreen(false)
	win.global_position = work_area.position
	win.size = work_area.size

func _on_request_fullscreen(id: String) -> void:
	toggle_fullscreen_window(id)

func toggle_fullscreen_window(id: String) -> void:
	if not windows.has(id):
		return
	var win: GameWindowPanel = windows[id]["node"]
	if windows[id].get("is_fullscreen", false):
		_restore_rect(id)
		_focus_window(id)
		return
	windows[id]["restore_rect"] = Rect2(win.global_position, win.size)
	windows[id]["is_fullscreen"] = true
	windows[id]["is_maximized"] = false
	_apply_fullscreen_geometry(id)
	_focus_window(id)

func _apply_fullscreen_geometry(id: String) -> void:
	if not windows.has(id):
		return
	var win: GameWindowPanel = windows[id]["node"]
	win.set_fullscreen(true)
	win.set_maximized(false)
	var rect := get_viewport_rect()
	win.global_position = rect.position
	win.size = rect.size

func _restore_rect(id: String) -> void:
	if not windows.has(id):
		return
	var win: GameWindowPanel = windows[id]["node"]
	var rect: Rect2 = windows[id].get("restore_rect", Rect2(work_area.position + Vector2(80, 80), win.size))
	win.set_maximized(false)
	win.set_fullscreen(false)
	win.global_position = rect.position
	win.size = rect.size
	_clamp_to_work_area(win)
	windows[id]["is_maximized"] = false
	windows[id]["is_fullscreen"] = false
	windows[id]["restore_rect"] = Rect2(win.global_position, win.size)

func _on_drag_finished(id: String, final_pos: Vector2, final_size: Vector2) -> void:
	if not windows.has(id):
		return
	var win: GameWindowPanel = windows[id]["node"]
	windows[id]["is_maximized"] = false
	windows[id]["is_fullscreen"] = false
	win.set_maximized(false)
	win.set_fullscreen(false)
	win.global_position = final_pos
	win.size = final_size
	_clamp_to_work_area(win)
	_apply_snap_if_needed(id)
	_set_restore_rect_from_window(id)
	_hide_snap_preview()

func _on_drag_moved(id: String, cur_pos: Vector2, cur_size: Vector2) -> void:
	var preview_rect: Variant = _calculate_snap_rect(cur_pos, cur_size)
	if preview_rect:
		_show_snap_preview(preview_rect)
	else:
		_hide_snap_preview()

func _calculate_snap_rect(pos: Vector2, win_size: Vector2) -> Variant:
	var wa: Rect2 = work_area
	# Left snap
	if pos.x <= wa.position.x + SNAP_MARGIN:
		return Rect2(wa.position, Vector2(wa.size.x * 0.5, wa.size.y))
	# Right snap
	if pos.x + win_size.x >= wa.position.x + wa.size.x - SNAP_MARGIN:
		return Rect2(Vector2(wa.position.x + wa.size.x * 0.5, wa.position.y), Vector2(wa.size.x * 0.5, wa.size.y))
	# Center snap (top center)
	if abs((pos.x + win_size.x * 0.5) - (wa.position.x + wa.size.x * 0.5)) <= CENTER_SNAP_MARGIN:
		var target_size := wa.size * 0.7
		return Rect2(wa.position + (wa.size - target_size) * 0.5, target_size)
	return null

func _show_snap_preview(rect: Rect2) -> void:
	if _snap_panel == null:
		_snap_panel = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_color = Color(0.18, 0.68, 1.0, 0.9)
		_snap_panel.add_theme_stylebox_override("panel", sb)
		_snap_fill = ColorRect.new()
		_snap_fill.color = Color(0.18, 0.68, 1.0, 0.14)
		_snap_panel.add_child(_snap_fill)
		add_child(_snap_panel)
	_snap_panel.visible = true
	_snap_panel.global_position = rect.position
	_snap_panel.size = rect.size
	_snap_fill.size = rect.size
	# animate fade in
	_snap_panel.modulate.a = 0.0
	_snap_fill.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_snap_panel, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_snap_fill, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _hide_snap_preview() -> void:
	if _snap_panel != null and _snap_panel.visible:
		var t := create_tween()
		t.tween_property(_snap_panel, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(_snap_fill, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.finished.connect(func(): _snap_panel.visible = false)

func _apply_snap_if_needed(id: String) -> void:
	if not windows.has(id):
		return
	var win: GameWindowPanel = windows[id]["node"]
	var pos := win.global_position
	var win_size := win.size
	var wa: Rect2 = work_area
	var was_snapped := false
	if pos.x <= wa.position.x + SNAP_MARGIN:
		win.global_position = wa.position
		win.size = Vector2(wa.size.x * 0.5, wa.size.y)
		was_snapped = true
	elif pos.x + win_size.x >= wa.position.x + wa.size.x - SNAP_MARGIN:
		win.global_position = Vector2(wa.position.x + wa.size.x * 0.5, wa.position.y)
		win.size = Vector2(wa.size.x * 0.5, wa.size.y)
		was_snapped = true
	elif abs((pos.x + win_size.x * 0.5) - (wa.position.x + wa.size.x * 0.5)) <= CENTER_SNAP_MARGIN:
		var target_size := wa.size * 0.7
		win.size = target_size
		win.global_position = wa.position + (wa.size - target_size) * 0.5
		was_snapped = true
	if was_snapped:
		_clamp_to_work_area(win)
		windows[id]["restore_rect"] = Rect2(win.global_position, win.size)

func _set_restore_rect_from_window(id: String) -> void:
	if not windows.has(id):
		return
	var win: GameWindowPanel = windows[id]["node"]
	windows[id]["restore_rect"] = Rect2(win.global_position, win.size)

func _clamp_to_work_area(win: GameWindowPanel) -> void:
	var pos := win.global_position
	var win_size := win.size
	if win_size.x > work_area.size.x:
		win_size.x = work_area.size.x
	if win_size.y > work_area.size.y:
		win_size.y = work_area.size.y
	pos.x = clamp(pos.x, work_area.position.x, work_area.position.x + work_area.size.x - win_size.x)
	pos.y = clamp(pos.y, work_area.position.y, work_area.position.y + work_area.size.y - win_size.y)
	win.global_position = pos
	win.size = win_size

func _warn_permissions(manifest: Dictionary) -> void:
	var perms: Array = manifest.get("permissions", [])
	if perms.is_empty():
		return
	var app_id := String(manifest.get("id", ""))
	for p in perms:
		var pname := String(p)
		if not KNOWN_PERMISSIONS.has(pname):
			Log.warn("Permissions: %s requested unknown permission '%s' (not enforced)" % [app_id, pname])
		else:
			Log.info("[Permissions] %s requests %s (not enforced)" % [app_id, pname])
