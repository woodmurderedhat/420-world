class_name DesktopUI
extends Control

var _palette: Dictionary = {}
var _input_enabled: bool = true

@onready var window_manager: GameWindowManager = $WindowManager
@onready var taskbar: TaskbarUI = $Taskbar
@onready var start_menu: StartMenuPanel = $StartMenu
@onready var background_viewport: SubViewport = $BackgroundViewportContainer/BackgroundViewport
# Dependent on Taskbar internal structure
@onready var start_button: Button = $Taskbar/HBox/StartButton

func _ready() -> void:
	if OS.get_cmdline_args().has("--headless-tests"):
		return

	_input_enabled = not OS.has_feature("headless")
	# Work area is everything above the taskbar.
	call_deferred("_update_work_area")
	get_tree().root.size_changed.connect(_update_work_area)

	window_manager.window_opened.connect(_on_window_opened)
	window_manager.window_closed.connect(_on_window_closed)
	window_manager.window_focused.connect(_on_window_focused)
	window_manager.window_minimized.connect(_on_window_minimized)
	window_manager.window_restored.connect(_on_window_restored)

	taskbar.window_action_requested.connect(_on_taskbar_window_action)
	taskbar.pin_app_requested.connect(_on_pin_app_requested)
	taskbar.start_menu_toggled.connect(_on_start_menu_toggled)
	taskbar.tray_icon_pressed.connect(func(id): _on_tray_icon_pressed(id))
	taskbar.app_launch_requested.connect(func(app_id): 
		window_manager.open_app(app_id)
		start_menu.hide_menu()
	)
	start_menu.app_launch_requested.connect(func(app_id): 
		window_manager.open_app(app_id)
		start_menu.hide_menu()
	)
	start_menu.create_shortcut_requested.connect(func(_app_id): Log.info("Shortcut creation not supported on new desktop"))
	start_menu.pin_to_taskbar_requested.connect(func(app_id): _on_pin_app_requested(app_id, true))
	start_menu.session_exit_requested.connect(func(): _on_session_exit())
	start_menu.session_restart_requested.connect(func(): _on_session_restart())

	AppRegistry.registry_changed.connect(_on_registry_changed)
	_on_registry_changed()

	var settings := get_tree().root.get_node_or_null("/root/SettingsManager")
	if settings != null:
		# Theme changes might still affect windows/taskbar
		pass

	var theme_mgr := get_tree().root.get_node_or_null("/root/ThemeManager")
	if theme_mgr != null:
		_palette = theme_mgr.get_palette()
		_apply_theme(_palette)
		theme_mgr.theme_changed.connect(func(_name, palette): _apply_theme(palette))
	
	_load_background_game()

func _on_pin_app_requested(app_id: String, pin: bool) -> void:
	var settings := get_tree().root.get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	
	var current_pins: Array = []
	var val: Variant = settings.get_value("ui.pinned_apps", null)
	
	# Load current state (or defaults if null)
	if typeof(val) == TYPE_ARRAY:
		current_pins = val.duplicate()
	elif val == null:
		# If settings not set, reconstruct what is currently effectively pinned (manifest defaults)
		for m in AppRegistry.list_manifests():
			if bool(m.get("pinned", false)):
				current_pins.append(m.get("id"))

	if pin:
		if not app_id in current_pins:
			current_pins.append(app_id)
	else:
		if app_id in current_pins:
			current_pins.erase(app_id)

	settings.set_value("ui.pinned_apps", current_pins)
	_update_pinned_apps()

func _update_work_area() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(1080, 720))
	if get_viewport() != null:
		# In a real dynamic resize scenario, we'd use get_viewport_rect().size
		# keeping it simple or consistent with existing scaler logic
		pass
		
	var tb_h: float = float($Taskbar.size.y)
	rect.size.y -= tb_h
	window_manager.set_work_area(rect)


func _on_registry_changed() -> void:
	_update_pinned_apps()


func _update_pinned_apps() -> void:
	var manifests := AppRegistry.list_manifests()
	var ids: Array = []
	var lookup: Dictionary = {}
	var settings := get_tree().root.get_node_or_null("/root/SettingsManager")
	var saved_pins: Array = []
	var use_saved: bool = false
	
	if settings != null:
		var val: Variant = settings.get_value("ui.pinned_apps", null)
		if typeof(val) == TYPE_ARRAY:
			saved_pins = val.duplicate()
			use_saved = true
			
			# Migration/Sanitization: If desktop_game is present, reset it.
			if saved_pins.has("desktop_game"):
				saved_pins = ["settings", "theme_designer"]
				settings.set_value("ui.pinned_apps", saved_pins)
				use_saved = true

	# If using saved list, we just iterate that list directly to preserve order
	if use_saved:
		for app_id in saved_pins:
			# Look up manifest for this id
			var found_manifest = AppRegistry.get_manifest(String(app_id))
			if not found_manifest.is_empty():
				ids.append(app_id)
				lookup[String(app_id)] = found_manifest
	else:
		# Fallback to manifests
		for manifest in manifests:
			var app_id := String(manifest.get("id", ""))
			if app_id == "":
				continue
			var pinned_flag: bool = bool(manifest.get("pinned", false))
			if pinned_flag:
				ids.append(app_id)
				lookup[app_id] = manifest
				
	taskbar.set_pinned_apps(ids, lookup)


func _get_icon_from_manifest(manifest: Dictionary) -> Texture2D:
	var icon_path: String = String(manifest.get("icon", ""))
	var tex: Texture2D = null

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var res = ResourceLoader.load(icon_path)
		if res is Texture2D:
			tex = res as Texture2D
	
	if tex == null:
		var def_path = "res://assets/icons/default_app.svg"
		if ResourceLoader.exists(def_path):
			tex = ResourceLoader.load(def_path) as Texture2D

	return tex


func _on_window_opened(id: String) -> void:
	var manifest: Dictionary = (
		window_manager.windows[id].get("manifest", {}) if window_manager.windows.has(id) else {}
	)
	var icon_tex: Texture2D = _get_icon_from_manifest(manifest)
	var app_id := window_manager.get_window_app_id(id)
	taskbar.add_window(id, app_id, window_manager.get_window_title(id), icon_tex)
	taskbar.set_window_state(id, window_manager.get_window_state(id))
	_apply_theme_to_window(id)


func _on_window_closed(id: String) -> void:
	taskbar.remove_window(id)


func _on_window_focused(id: String) -> void:
	taskbar.set_window_state(id, window_manager.STATE_FOCUSED)


func _on_window_minimized(id: String) -> void:
	taskbar.set_window_state(id, window_manager.STATE_MINIMIZED)


func _on_window_restored(id: String) -> void:
	taskbar.set_window_state(id, window_manager.get_window_state(id))


func _on_taskbar_window_action(window_id: String, action: StringName) -> void:
	if not window_manager.windows.has(window_id):
		return
	match String(action):
		"focus":
			window_manager.focus_window(window_id)
		"restore":
			window_manager.restore_window(window_id)
		"minimize":
			window_manager.minimize_window(window_id)
		"close":
			window_manager.close_window(window_id)
		_:
			pass


func _on_start_menu_toggled() -> void:
	var gpos := start_button.get_global_position()
	var gsize := start_button.size
	start_menu.toggle(gpos, gsize)


func _unhandled_input(event: InputEvent) -> void:
	if _input_enabled and event is InputEventKey and event.pressed and not event.echo:
		if event.alt_pressed and event.keycode == KEY_F4:
			_close_focused_window()
			return
		if event.alt_pressed and event.keycode == KEY_TAB:
			_cycle_windows()
			return
		if event.ctrl_pressed and event.keycode == KEY_TAB:
			_cycle_windows()
			return
		if event.keycode == KEY_META:
			_toggle_start_menu()
			return
	if not start_menu.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = event.position
		if (
			not start_menu.get_global_rect().has_point(pos)
			and not start_button.get_global_rect().has_point(pos)
		):
			start_menu.hide_menu()


func _toggle_start_menu() -> void:
	var gpos := start_button.get_global_position()
	var gsize := start_button.size
	start_menu.toggle(gpos, gsize)


func _close_focused_window() -> void:
	var id := window_manager.get_focused_window_id()
	if id != "":
		window_manager.close_window(id)


func _cycle_windows() -> void:
	var ids: Array = []
	for id in window_manager.windows.keys():
		ids.append(id)
	if ids.is_empty():
		return
	ids.sort_custom(
		func(a, b):
			return window_manager.get_window_z_index(a) < window_manager.get_window_z_index(b)
	)
	var current := window_manager.get_focused_window_id()
	var next_idx := 0
	if current != "":
		var idx := ids.find(current)
		next_idx = (idx + 1) % ids.size()
	window_manager.focus_window(String(ids[next_idx]))


func _apply_theme(palette: Dictionary) -> void:
	_palette = palette
	taskbar.apply_palette(palette)
	start_menu.apply_palette(palette)
	for id in window_manager.windows.keys():
		_apply_theme_to_window(String(id))


func _apply_theme_to_window(id: String) -> void:
	if not window_manager.windows.has(id):
		return
	var win: Object = window_manager.windows[id]["node"]
	if win.has_method("apply_palette"):
		win.apply_palette(_palette)


func _on_tray_icon_pressed(_id: int) -> void:
	pass


func _on_session_exit() -> void:
	get_tree().quit()


func _on_session_restart() -> void:
	var exe_path = OS.get_executable_path()
	OS.create_process(exe_path, OS.get_cmdline_args())
	get_tree().quit()


func _load_background_game() -> void:
	var app_id = "desktop_game"
	var manifest = AppRegistry.get_manifest(app_id)
	if manifest == null:
		Log.error("Desktop: Could not find manifest for " + app_id)
		return
	
	var scene_path = manifest.get("entry_scene", "")
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		Log.error("Desktop: Invalid entry scene for " + app_id)
		return
		
	var scene = ResourceLoader.load(scene_path)
	if scene:
		var instance = scene.instantiate()
		background_viewport.add_child(instance)
		if instance.has_method("launch"):
			instance.launch({})
		Log.info("Desktop: Loaded background game")
