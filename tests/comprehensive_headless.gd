extends Node

const WM_SCRIPT := preload("res://scripts/window_manager.gd")
const TASKBAR_SCENE := preload("res://scenes/taskbar.tscn")
const START_MENU_SCENE := preload("res://scenes/start_menu.tscn")
const GAME_WINDOW_SCENE := preload("res://scenes/game_window.tscn")

var _errors: Array = []

func _ready() -> void:
	var logm: LogManager = Log
	if log != null:
		logm.reset_counters()
	await get_tree().process_frame
	await _run_suite()
	_collect_log_warnings()
	if _errors.is_empty():
		print("[Tests] Comprehensive headless checks passed")
		get_tree().quit(0)
	else:
		for e in _errors:
			push_error(e)
		push_error("[Tests] Comprehensive headless checks failed (%d issues)" % _errors.size())
		get_tree().quit(1)

func _collect_log_warnings() -> void:
	var logm: LogManager = Log
	if logm == null:
		return
	var warn_count := logm.get_warning_count()
	var err_count := logm.get_error_count()
	if warn_count > 0:
		for w in logm.get_warnings():
			_errors.append("[Warning] %s" % w)
	if err_count > 0:
		for m in logm.get_errors():
			_errors.append("[LogError] %s" % m)

func _run_suite() -> void:
	_test_project_compilation()
	_test_service_registration()
	_test_event_bus()
	_test_save_manager()
	await _test_settings_manager()
	_test_inventory_manager()
	await _test_theme_manager()
	_test_app_registry()
	await _test_apps_lifecycle()
	await _test_window_manager()
	await _test_window_manager_leaks()
	await _test_taskbar_and_start_menu()

func _test_service_registration() -> void:
	var names: Array = CoreRuntime.get_ready_service_names()
	var expected: Array = CoreRuntime.EXPECTED_SERVICES
	for service in expected:
		if not names.has(service):
			_fail("Service registration missing %s" % service)

func _test_event_bus() -> void:
	var bus := EventBus
	if bus == null:
		_fail("EventBus singleton missing")
		return
	var payloads: Array = []
	var cb: Callable = func(p): payloads.append(p)
	bus.subscribe("ping", cb)
	bus.emit_event("ping", 42)
	bus.unsubscribe("ping", cb)
	bus.emit_event("ping", 7)
	bus.clear()
	if payloads != [42]:
		_fail("EventBus payload mismatch: %s" % payloads)

func _test_save_manager() -> void:
	var sm := SaveManager
	if sm == null:
		_fail("SaveManager singleton missing")
		return
	var original: Dictionary = sm.load_global()
	var marker := "__comprehensive_marker__"
	var token := int(Time.get_unix_time_from_system())
	var mutated := original.duplicate(true)
	mutated[marker] = token
	if not sm.save_global(mutated):
		_fail("SaveManager failed to persist global marker")
	var reread: Dictionary = sm.load_global()
	if int(reread.get(marker, -1)) != token:
		_fail("SaveManager global marker mismatch: %s" % reread.get(marker))
	sm.save_global(original)

	var app_id := "__comprehensive_app__"
	var state := {"state": {"marker": token}}
	if not sm.save_app(app_id, state):
		_fail("SaveManager failed to persist app save for %s" % app_id)
	var loaded := sm.load_app(app_id)
	if int(loaded.get("state", {}).get("marker", -1)) != token:
		_fail("SaveManager app state mismatch for %s" % app_id)
	sm.delete_app_save(app_id)

func _test_settings_manager() -> void:
	var settings := SettingsManager
	if settings == null:
		_fail("SettingsManager singleton missing")
		return
	var backup := settings.get_all()
	var toggled_mode := "fractional" if String(settings.get_value("display.scale_mode", "integer")) == "integer" else "integer"
	settings.set_value("display.scale_mode", toggled_mode)
	settings.set_value("display.scale_factor", 3.5)
	if String(settings.get_value("display.scale_mode")) != toggled_mode:
		_fail("SettingsManager scale mode did not update")
	if abs(float(settings.get_value("display.scale_factor")) - 3.5) > 0.001:
		_fail("SettingsManager scale factor did not update")
	settings.reset_to_defaults()
	await get_tree().process_frame
	for key in backup.keys():
		settings.set_value(key, backup[key])

func _test_inventory_manager() -> void:
	var inv := InventoryManager
	if inv == null:
		_fail("InventoryManager singleton missing")
		return
	var backup := inv.items.duplicate(true)
	var test_id := "headless_test_item"
	inv.add_item(test_id, 4)
	if not inv.has_item(test_id):
		_fail("InventoryManager failed to add items")
	if not inv.remove_item(test_id, 4):
		_fail("InventoryManager failed to remove items")
	if inv.has_item(test_id):
		_fail("InventoryManager left zeroed item in inventory")
	inv.items = backup.duplicate(true)
	var sm := SaveManager
	if sm != null:
		var global := sm.load_global()
		global["inventory"] = backup.duplicate(true)
		sm.save_global(global)

func _test_theme_manager() -> void:
	var theme := ThemeManager
	if theme == null:
		_fail("ThemeManager singleton missing")
		return
	var original := String(theme.current_theme)
	var state := { "triggered": false }
	var cb = func(name, palette): state.triggered = true
	theme.theme_changed.connect(cb)
	var new_theme := "dark" if original == "light" else "light"
	SettingsManager.set_value("ui.theme", new_theme)
	await get_tree().process_frame
	if not state.triggered:
		_fail("ThemeManager did not notify on theme change")
	SettingsManager.set_value("ui.theme", original)
	await get_tree().process_frame

func _test_app_registry() -> void:
	var registry := AppRegistry
	var manifests := registry.list_manifests()
	if manifests.is_empty():
		_fail("AppRegistry found no manifests")
	var app_id := "hello_world"
	var manifest := registry.get_manifest(app_id)
	if manifest.is_empty():
		_fail("AppRegistry missing expected manifest %s" % app_id)
	registry.record_recent(app_id)
	if not registry.list_recent().has(app_id):
		_fail("AppRegistry failed to record recent app %s" % app_id)

func _test_apps_lifecycle() -> void:
	print("Test: Verifying lifecycle for all registered apps...")
	var manifests := AppRegistry.list_manifests()
	var tested_count := 0
	
	for manifest in manifests:
		var app_id: String = manifest.get("id", "unknown")
		var entry_path: String = manifest.get("entry_scene", "")
		
		# print("Test: Checking %s..." % app_id)
		
		if entry_path.is_empty():
			_fail("App %s has no entry_scene" % app_id)
			continue
			
		var scene = load(entry_path)
		if scene == null:
			_fail("Failed to load scene for %s" % app_id)
			continue
			
		if not (scene is PackedScene):
			_fail("Entry scene for %s is not a PackedScene" % app_id)
			continue
			
		var instance = scene.instantiate()
		if not (instance is AppBase):
			_fail("App %s root node does not extend AppBase" % app_id)
			instance.free()
			continue
			
		# Add to tree to trigger _ready
		get_tree().root.add_child(instance)
		await get_tree().process_frame
		
		# Exercise lifecycle
		instance.launch({})
		instance.pause()
		instance.resume()
		var state: Dictionary = instance.save_state()
		if typeof(state) != TYPE_DICTIONARY:
			_fail("App %s save_state() returned %s, expected Dictionary" % [app_id, type_string(typeof(state))])
		
		instance.load_state(state)
		
		instance.queue_free()
		tested_count += 1
		
	print("Test: Verified lifecycle for %d apps" % tested_count)

func _test_window_manager() -> void:
	var wm := WM_SCRIPT.new()
	get_tree().root.add_child(wm)
	await get_tree().process_frame
	wm.window_scene = GAME_WINDOW_SCENE
	var scene_a := _make_dummy_scene("Alpha")
	var scene_b := _make_dummy_scene("Beta")
	var win_a := wm.open_window("test_app", "Alpha", scene_a)
	var win_b := wm.open_window("test_app", "Beta", scene_b)
	await get_tree().process_frame
	if wm.focused_id != win_b:
		_fail("WindowManager did not focus the second window")
	wm.minimize_window(win_b)
	await get_tree().process_frame
	if wm.get_window_state(win_b) != wm.STATE_MINIMIZED:
		_fail("WindowManager failed to minimize")
	wm.restore_window(win_b)
	await get_tree().process_frame
	if wm.get_window_state(win_b) != wm.STATE_FOCUSED:
		_fail("WindowManager failed to restore focus")
	wm.maximize_window(win_b)
	await get_tree().process_frame
	if not wm.windows[win_b].get("is_maximized", false):
		_fail("WindowManager failed to maximize")
	wm.maximize_window(win_b)
	await get_tree().process_frame
	wm.toggle_fullscreen_window(win_b)
	await get_tree().process_frame
	if not wm.windows[win_b].get("is_fullscreen", false):
		_fail("WindowManager failed to enter fullscreen")
	wm.toggle_fullscreen_window(win_b)
	await get_tree().process_frame
	if wm.windows[win_b].get("is_fullscreen", false):
		_fail("WindowManager did not exit fullscreen")
	var ids := wm.windows.keys()
	for id in ids:
		wm.close_window(String(id))
	await get_tree().process_frame
	if not wm.windows.is_empty():
		_fail("WindowManager left entries after closing windows")
	wm.queue_free()

func _test_window_manager_leaks() -> void:
	SettingsManager.set_value("ui.animations", false) # Disable animations to sync logic
	
	var wm := WM_SCRIPT.new()
	get_tree().root.add_child(wm)
	await get_tree().process_frame
	wm.window_scene = GAME_WINDOW_SCENE
	
	await get_tree().create_timer(1.0).timeout
	var initial_nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var scene_res := _make_dummy_scene("LeakCheck")

	# Burn-in cycle
	var id1 := wm.open_window("leak_test", "BurnIn", scene_res)
	await get_tree().process_frame
	wm.close_window(id1)
	await get_tree().process_frame
	
	var base_nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	# Stress cycle
	for i in range(20):
		var id := wm.open_window("leak_test", "Win%d" % i, scene_res)
		wm.minimize_window(id)
		wm.restore_window(id)
		wm.close_window(id)
	
	# Allow cleanup
	await get_tree().create_timer(0.2).timeout
	
	var final_nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	# Allow small margin for unrelated engine allocs, but 20 windows shouldn't remain.
	if final_nodes > base_nodes + 5:
		_fail("Possible leak detected: Nodes went from %d to %d after closing 20 windows" % [base_nodes, final_nodes])
	
	wm.queue_free()

func _test_taskbar_and_start_menu() -> void:
	var start_menu = START_MENU_SCENE.instantiate()
	var taskbar = TASKBAR_SCENE.instantiate()
	get_tree().root.add_child(start_menu)
	get_tree().root.add_child(taskbar)
	await get_tree().process_frame
	start_menu.toggle(Vector2(32, 680), Vector2(72, 32))
	await get_tree().create_timer(0.2).timeout
	if not start_menu.visible:
		_fail("StartMenu did not become visible")
	start_menu.search_box.text = "hello"
	await get_tree().process_frame
	start_menu.hide_menu()
	await get_tree().create_timer(0.25).timeout
	if start_menu.visible:
		_fail("StartMenu did not hide after toggle")
	var manifest := AppRegistry.get_manifest("hello_world")
	if manifest.is_empty():
		_fail("StartMenu expected hello_world manifest")
	taskbar.apply_palette(ThemeManager.get_palette())
	taskbar.set_pinned_apps(["hello_world"], {"hello_world": manifest})
	if not taskbar._pinned_buttons.has("hello_world"):
		_fail("Taskbar failed to create pinned button")
	var launched: Array = []
	taskbar.app_launch_requested.connect(func(app_id): launched.append(app_id))
	var pinned_button: Button = taskbar._pinned_buttons.get("hello_world")
	if pinned_button != null:
		pinned_button.emit_signal("pressed")
		await get_tree().process_frame
		if launched != ["hello_world"]:
			_fail("Taskbar did not emit pinned launch signal")
	else:
		_fail("Taskbar has no pinned button to press")
	taskbar.add_window("task_win", "hello_world", "Pinned Window")
	taskbar.set_window_state("task_win", "focused")
	taskbar.set_window_state("task_win", "minimized")
	await get_tree().process_frame
	var badge: Control = taskbar._badges.get("task_win")
	if badge == null or not badge.visible:
		_fail("Taskbar badge did not show for minimized window")
	taskbar.remove_window("task_win")
	start_menu.queue_free()
	taskbar.queue_free()

func _test_project_compilation() -> void:
	print("Test: Compiling all project scripts...")
	var scripts: Array[String] = []
	_scan_for_scripts("res://", scripts)
	var count := 0
	for path in scripts:
		# specific exclusion for tests or addons if needed
		if path.begins_with("res://tests/") or path.begins_with("res://addons/"):
			continue
		
		# Attempt load - this triggers GDScript compilation
		var res = load(path)
		if res == null:
			_fail("Script compilation failed: %s" % path)
		count += 1
	print("Test: Verified compilation of %d scripts" % count)

func _scan_for_scripts(dir_path: String, results: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				var skip := file_name == "." or file_name == ".." or file_name == ".godot" or file_name == ".vscode" or file_name == "debug"
				if not skip:
					_scan_for_scripts(dir_path.path_join(file_name), results)
			else:
				if file_name.ends_with(".gd"):
					results.append(dir_path.path_join(file_name))
			file_name = dir.get_next()

func _make_dummy_scene(xname: String) -> PackedScene:
	var script := GDScript.new()
	script.source_code = "extends AppBase\nfunc launch(_p):pass\nfunc pause():pass\nfunc resume():pass\nfunc save_state() -> Dictionary:\n\treturn {\"label\": \"%s\"}\nfunc load_state(_d):pass" % xname
	script.reload()
	var root := Control.new()
	root.set_script(script)
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

func _fail(message: String) -> void:
	_errors.append(message)
