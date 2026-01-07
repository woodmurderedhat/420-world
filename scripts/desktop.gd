extends Control
class_name DesktopUI

@onready var window_manager: GameWindowManager = $WindowManager
@onready var taskbar: TaskbarUI = $Taskbar
@onready var start_menu: StartMenuPanel = $StartMenu
@onready var icons_box: VBoxContainer = $DesktopLayer/Icons
@onready var start_button: Button = $Taskbar/HBox/StartButton
@onready var background_layer: TextureRect = $DesktopLayer

var _palette: Dictionary = {}

var _input_enabled: bool = true

func _ready() -> void:
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
	taskbar.start_menu_toggled.connect(_on_start_menu_toggled)
	taskbar.tray_icon_pressed.connect(func(id): _on_tray_icon_pressed(id))
	taskbar.app_launch_requested.connect(func(app_id): window_manager.open_app(app_id))
	start_menu.app_launch_requested.connect(func(app_id): window_manager.open_app(app_id))
	start_menu.create_shortcut_requested.connect(func(app_id): _create_shortcut(app_id))
	start_menu.pin_to_taskbar_requested.connect(func(app_id): _pin_to_taskbar(app_id))
	start_menu.session_exit_requested.connect(func(): _on_session_exit())
	start_menu.session_restart_requested.connect(func(): _on_session_restart())

	AppRegistry.registry_changed.connect(_on_registry_changed)
	_on_registry_changed()

	var settings := get_tree().root.get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.setting_changed.connect(_on_setting_changed)
		_update_background()

	var theme_mgr := get_tree().root.get_node_or_null("/root/ThemeManager")
	if theme_mgr != null:
		_palette = theme_mgr.get_palette()
		_apply_theme(_palette)
		theme_mgr.theme_changed.connect(func(_name, palette): _apply_theme(palette))

func _update_work_area() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(1080, 720))
	# Desktop is rendered in virtual coordinates (scaled by DesktopScaler).
	var tb_h: float = float($Taskbar.size.y)
	rect.size.y -= tb_h
	window_manager.set_work_area(rect)

func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if String(key).begins_with("background."):
		_update_background()

func _update_background() -> void:
	var settings := get_tree().root.get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	
	var type: String = settings.get_value("background.type", "solid")
	var color_a := Color(String(settings.get_value("background.color_a", "#12141a")))
	var color_b := Color(String(settings.get_value("background.color_b", "#1e222b")))
	var image_path: String = settings.get_value("background.image_path", "")
	
	match type:
		"solid":
			var grad := GradientTexture2D.new()
			grad.width = 1
			grad.height = 1
			grad.fill = GradientTexture2D.FILL_LINEAR
			grad.gradient = Gradient.new()
			grad.gradient.offsets = PackedFloat32Array([0.0, 1.0])
			grad.gradient.colors = PackedColorArray([color_a, color_a])
			background_layer.texture = grad
		"gradient":
			var grad := GradientTexture2D.new()
			grad.width = 64
			grad.height = 64
			grad.fill_from = Vector2(0, 0)
			grad.fill_to = Vector2(0, 1) # Vertical
			grad.gradient = Gradient.new()
			grad.gradient.colors = PackedColorArray([color_a, color_b])
			background_layer.texture = grad
		"image":
			if image_path != "" and ResourceLoader.exists(image_path):
				var tex = ResourceLoader.load(image_path)
				if tex is Texture2D:
					background_layer.texture = tex
					return
			
			# Fallback to solid if image invalid
			var grad := GradientTexture2D.new()
			grad.width = 1
			grad.height = 1
			grad.fill = GradientTexture2D.FILL_LINEAR
			grad.gradient = Gradient.new()
			grad.gradient.offsets = PackedFloat32Array([0.0, 1.0])
			grad.gradient.colors = PackedColorArray([color_a, color_a])
			background_layer.texture = grad

func _get_icon_from_manifest(manifest: Dictionary) -> Texture2D:
	var icon_path := String(manifest.get("icon", ""))
	if icon_path == "":
		icon_path = "res://assets/icons/default_app.svg"
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex := ResourceLoader.load(icon_path)
		if tex is Texture2D:
			return tex
	return null

func _on_window_opened(id: String) -> void:
	var manifest: Dictionary = window_manager.windows[id].get("manifest", {}) if window_manager.windows.has(id) else {}
	var icon_tex: Texture2D = null
	icon_tex = _get_icon_from_manifest(manifest)
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
	# Right-click on desktop -> show context menu
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var menu := PopupMenu.new()
		add_child(menu)
		menu.add_item("Refresh", 1)
		menu.add_item("Change Theme", 2)
		menu.add_item("Open Settings", 3)
		menu.id_pressed.connect(func(id: int):
			match id:
				1:
					_refresh_desktop()
				2:
					_cycle_theme()
				3:
					_open_settings()
			menu.queue_free()
		)
		menu.popup(Rect2(event.position, Vector2(180, 96)))
		return
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
		if not start_menu.get_global_rect().has_point(pos) and not start_button.get_global_rect().has_point(pos):
			start_menu.hide_menu()

func _rebuild_icons() -> void:
	for c in icons_box.get_children():
		c.queue_free()
	for manifest in AppRegistry.list_manifests():
		var app_id := String(manifest.get("id", ""))
		var app_name := String(manifest.get("name", app_id))
		if app_id == "":
			continue
		var b := Button.new()
		b.text = app_name
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tex := _get_icon_from_manifest(manifest)
		if tex != null:
			b.icon = tex
		b.pressed.connect(func(): window_manager.open_app(app_id))
		icons_box.add_child(b)

func _on_registry_changed() -> void:
	_rebuild_icons()
	_update_pinned_apps()

func _update_pinned_apps() -> void:
	var manifests := AppRegistry.list_manifests()
	var ids: Array = []
	var lookup: Dictionary = {}
	# Read saved pinned list from SettingsManager if available
	var settings := get_tree().root.get_node_or_null("/root/SettingsManager")
	var saved_pins: Array = []
	if settings != null:
		var val := settings.get_value("ui.pinned_apps", null)
		if typeof(val) == TYPE_ARRAY:
			saved_pins = val.duplicate()

	for manifest in manifests:
		var app_id := String(manifest.get("id", ""))
		if app_id == "":
			continue
		lookup[app_id] = manifest
		var pinned_flag: bool = bool(manifest.get("pinned", true))
		# If saved pins present, prefer saved list
		if not saved_pins.is_empty():
			if app_id in saved_pins:
				ids.append(app_id)
		else:
			if pinned_flag:
				ids.append(app_id)
	taskbar.set_pinned_apps(ids, lookup)

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
	ids.sort_custom(func(a, b): return window_manager.get_window_z_index(a) < window_manager.get_window_z_index(b))
	var current := window_manager.get_focused_window_id()
	var next_idx := 0
	if current != "":
		var idx := ids.find(current)
		next_idx = (idx + 1) % ids.size()
	window_manager.focus_window(String(ids[next_idx]))

func _apply_theme(palette: Dictionary) -> void:
	_palette = palette
	# Background color from theme is ignored in favor of SettingsManager "background" prefs
	# unless we add logic to respect "theme" setting for background.
	# For now, just refresh background in case it's solid/gradient.
	_update_background()
	taskbar.apply_palette(palette)
	start_menu.apply_palette(palette)
	for id in window_manager.windows.keys():
		_apply_theme_to_window(String(id))

func _apply_theme_to_window(id: String) -> void:
	if not window_manager.windows.has(id):
		return
	var win: GameWindowPanel = window_manager.windows[id]["node"]
	if win.has_method("apply_palette"):
		win.apply_palette(_palette)

func _refresh_desktop() -> void:
	_rebuild_icons()
	var log := get_tree().root.get_node_or_null("/root/Log")
	if log != null:
		log.info("Desktop: refresh requested")
	else:
		print("Desktop: refresh requested")

func _cycle_theme() -> void:
	var settings := get_tree().root.get_node_or_null("/root/SettingsManager")
	if settings != null:
		var cur := String(settings.get_value("ui.theme", "light"))
		var next := "dark" if cur != "dark" else "light"
		settings.set_value("ui.theme", next)
	else:
		print("No SettingsManager to change theme")

func _open_settings() -> void:
	if window_manager != null:
		window_manager.open_app("settings")
	else:
		print("No WindowManager to open settings")

func _create_shortcut(app_id: String) -> void:
	var manifest := AppRegistry.get_manifest(app_id)
	if manifest.is_empty():
		return
	var existing := null
	for c in icons_box.get_children():
		if c.name == app_id:
			existing = c
			break
	if existing != null:
		return
	var b := Button.new()
	b.name = app_id
	b.text = String(manifest.get("name", app_id))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tex := _get_icon_from_manifest(manifest)
	if tex != null:
		b.icon = tex
	b.pressed.connect(func(): window_manager.open_app(app_id))
	b.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var menu := PopupMenu.new()
			add_child(menu)
			menu.add_item("Pin to Taskbar", 1)
			menu.add_item("Remove Shortcut", 2)
			menu.id_pressed.connect(func(id: int):
				match id:
					1:
						_pin_to_taskbar(app_id)
					2:
						b.queue_free()
				menu.queue_free()
			)
			menu.popup(get_global_rect())
			get_viewport().set_input_as_handled()
		)
	icons_box.add_child(b)

func _pin_to_taskbar(app_id: String) -> void:
	var manifests := AppRegistry.list_manifests()
	var ids: Array = []
	var lookup: Dictionary = {}
	var found := false
	for manifest in manifests:
		var aid := String(manifest.get("id", ""))
		if aid == "":
			continue
		lookup[aid] = manifest
		var pinned_flag: bool = bool(manifest.get("pinned", true))
		if pinned_flag or aid == app_id:
			ids.append(aid)
		if aid == app_id:
			found = true
	if not found:
		return
	taskbar.set_pinned_apps(ids, lookup)
	# Persist pinned list in SettingsManager
	var settings := get_tree().root.get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.set_value("ui.pinned_apps", ids)
	else:
		var sm := get_tree().root.get_node_or_null("/root/SaveManager")
		if sm != null:
			var g := sm.load_global()
			g["pinned_apps"] = ids
			sm.save_global(g)

func _on_tray_icon_pressed(id: String) -> void:
	if id == "volume":
		var log := get_tree().root.get_node_or_null("/root/Log")
		if log != null:
			log.info("Tray: volume pressed")
		else:
			print("Tray: volume pressed")

func _on_session_exit() -> void:
	var log := get_tree().root.get_node_or_null("/root/Log")
	if log != null:
		log.info("Session: exit requested")
	get_tree().quit(0)

func _on_session_restart() -> void:
	var log := get_tree().root.get_node_or_null("/root/Log")
	if log != null:
		log.info("Session: restart requested")
	get_tree().quit(0)
