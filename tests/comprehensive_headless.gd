extends Node

# A single comprehensive headless test suite.
# Usage: Run with --headless-tests argument.
# The CoreRuntime detects the arg and instantiates this node.

func _ready() -> void:
	Log.info("HEADLESS: Starting comprehensive test suite...")
	
	# Give the system one frame to settle (Autoloads are already ready, but just in case)
	await get_tree().process_frame

	var failures: int = 0
	
	failures += _test_core_services()
	failures += await _test_event_bus()
	failures += await _test_save_persistence()
	failures += await _test_settings()
	failures += await _test_app_registry()
	failures += await _test_theme_manager()

	if failures == 0:
		Log.info("HEADLESS: All tests passed.")
		CoreRuntime.quit_safely(0)
	else:
		Log.error("HEADLESS: %d test(s) failed." % failures)
		CoreRuntime.quit_safely(1)


func _test_core_services() -> int:
	Log.info("TEST: Verifying Core Services...")
	var fails = 0
	
	# Validate EXPECTED_SERVICES from CoreRuntime
	var expected = CoreRuntime.EXPECTED_SERVICES
	for service_name in expected:
		if not CoreRuntime.has_service(service_name):
			Log.error("FAIL: Service '%s' is not registered in CoreRuntime." % service_name)
			fails += 1
		else:
			# Also verify the globally accessible singleton exists
			if not get_node("/root/" + service_name):
				Log.error("FAIL: Singleton '/root/%s' not found in tree." % service_name)
				fails += 1

	return fails


func _test_event_bus() -> int:
	Log.info("TEST: Verifying EventBus...")
	var fails = 0
	var state = {"payload": null}
	
	var event_name = StringName("test_event")
	var callback = func(p):
		state.payload = p
	
	EventBus.subscribe(event_name, callback)
	EventBus.emit_event(event_name, "hello_world")
	
	# EventBus is synchronous, but we wait a frame just in case of any deferred logic elsewhere
	await get_tree().process_frame
	
	if state.payload != "hello_world":
		Log.error("FAIL: EventBus did not deliver payload. Got: %s" % str(state.payload))
		fails += 1
	
	EventBus.unsubscribe(event_name, callback)
	
	# Verify unsubscribe
	state.payload = null
	EventBus.emit_event(event_name, "should_not_receive")
	await get_tree().process_frame
	
	if state.payload != null:
		Log.error("FAIL: EventBus delivered event after unsubscribe.")
		fails += 1
		
	return fails


func _test_save_persistence() -> int:
	Log.info("TEST: Verifying SaveManager...")
	var fails = 0
	
	var test_data = {
		"headless_test_key": randi(),
		"timestamp": Time.get_ticks_msec()
	}
	
	# 1. Save data
	if not SaveManager.save_global(test_data):
		Log.error("FAIL: SaveManager.save_global returned false.")
		fails += 1
		return fails
		
	# 2. Force fresh load from disk logic (simulate restart)
	SaveManager.refresh_global()
	var loaded_data = SaveManager.load_global()
	
	# 3. Verify
	if not loaded_data.has("headless_test_key"):
		Log.error("FAIL: Loaded data missing key 'headless_test_key'.")
		fails += 1
	elif loaded_data["headless_test_key"] != test_data["headless_test_key"]:
		Log.error("FAIL: Value mismatch. Expected %s, Got %s" % [test_data["headless_test_key"], loaded_data.get("headless_test_key")])
		fails += 1
		
	return fails


func _test_settings() -> int:
	Log.info("TEST: Verifying SettingsManager...")
	var fails = 0
	
	# 1. Set a setting
	var test_key = "display.scale_factor"
	var original_value = SettingsManager.get_value(test_key)
	
	# Ensure test value is different to trigger signal
	var test_value = 2.5
	if is_equal_approx(float(original_value), 2.5):
		test_value = 3.0
	
	var state = {"emitted": false}
	var signal_callback = func(k, v):
		if k == test_key and v == test_value:
			state.emitted = true
			
	SettingsManager.setting_changed.connect(signal_callback)
	
	SettingsManager.set_value(test_key, test_value)
	
	# Wait for signal? It's usually immediate but let's wait a frame
	await get_tree().process_frame
	
	if not state.emitted:
		Log.error("FAIL: SettingsManager did not emit setting_changed signal. (Old: %s, New: %s)" % [original_value, test_value])
		fails += 1
		
	if SettingsManager.get_value(test_key) != test_value:
		Log.error("FAIL: SettingsManager.get_value did not return set value.")
		fails += 1
		
	# Cleanup
	SettingsManager.set_value(test_key, original_value)
	
	return fails


func _test_app_registry() -> int:
	Log.info("TEST: Verifying AppRegistry...")
	var fails = 0
	
	# AppRegistry scans apps in _ready
	if AppRegistry.apps.size() == 0:
		Log.warn("WARN: AppRegistry has no apps. This may be correct if no apps exist in project.")
	else:
		if not AppRegistry.apps.has("hello_world"):
			# hello_world exists in file structure
			Log.error("FAIL: AppRegistry did not find 'hello_world' app.")
			fails += 1
		
	return fails


func _test_theme_manager() -> int:
	Log.info("TEST: Verifying ThemeManager...")
	var fails = 0
	
	if ThemeManager.current_theme not in ["light", "dark"]:
		Log.error("FAIL: ThemeManager has invalid current_theme: %s" % ThemeManager.current_theme)
		fails += 1
		
	# Verify THEMES dict is populated
	if ThemeManager.THEMES.is_empty():
		Log.error("FAIL: ThemeManager.THEMES is empty.")
		fails += 1
		
	return fails
