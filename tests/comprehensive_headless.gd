extends Node

# A single comprehensive headless test suite.
# Usage: Run with --headless-tests argument.
# The CoreRuntime detects the arg and instantiates this node.

func _ready() -> void:
	Log.info("HEADLESS: Starting comprehensive test suite...")
	
	# Give the system one frame to settle (Autoloads are already ready, but just in case)
	await get_tree().process_frame

	var failures: int = 0
	
	# Run tests sequentially
	failures += _test_core_services()
	failures += await _test_event_bus()
	failures += _test_save_persistence()
	failures += await _test_settings()
	
	failures += _test_theme_manager()
	failures += _test_theme_card_style()
	failures += await _test_character_creation()
	failures += await _test_gallery_ui()

	# Allow one more frame for any pending signals / logs
	await get_tree().process_frame

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
	SettingsManager.setting_changed.disconnect(signal_callback)
	fails += 1
		
	return fails


func _test_theme_manager() -> int:
	Log.info("TEST: Verifying ThemeManager...")
	var fails = 0
	
	if not ThemeManager.THEMES.has(ThemeManager.current_theme):
		Log.error("FAIL: ThemeManager has invalid current_theme: %s" % ThemeManager.current_theme)
		fails += 1
		
	# Verify THEMES dict is populated
	if ThemeManager.THEMES.is_empty():
		Log.error("FAIL: ThemeManager.THEMES is empty.")
		fails += 1
		
	return fails

func _test_theme_card_style() -> int:
	Log.info("TEST: Verifying ThemeManager card style constants...")
	var fails = 0
	var sb = ThemeManager.get_card_stylebox()
	if sb == null:
		Log.error("FAIL: get_card_stylebox returned null")
		return fails + 1
	# Check corner radius and border widths
	if sb.corner_radius_top_left != ThemeManager.CARD_CORNER_RADIUS:
		Log.error("FAIL: Card corner radius mismatch")
		fails += 1
	if sb.border_width_left != ThemeManager.CARD_BORDER_WIDTH:
		Log.error("FAIL: Card border width mismatch")
		fails += 1
	if sb.content_margin_left != ThemeManager.CARD_PADDING_LEFT:
		Log.error("FAIL: Card padding left mismatch")
		fails += 1
	return fails

func _test_character_creation() -> int:
	Log.info("TEST: Verifying Character creation flows...")
	var fails = 0
	
	# 1. Ensure clean slate for characters and create a character
	CharacterManager.clear_all_characters()
	var char_name: String = "test_char_" + str(randi() % 100000)
	var body: Dictionary = {"head": "head_01", "eyes": "eyes_01", "mouth": "mouth_01", "hair": "hair_01", "arms": "arms_01", "hands": "hands_01", "legs": "legs_01", "feet": "feet_01"}
	var stats: Dictionary = {"gold": 5, "agility": 5, "strength": 5, "intelligence": 5, "constitution": 5, "luck": 5}
	
	var created = CharacterManager.create_character(char_name, "test", body, stats)
	if not created:
		Log.error("FAIL: CharacterManager.create_character returned false")
		fails += 1
		return fails
	
	# 2. Duplicate name should be rejected
	if CharacterManager.create_character(char_name, "test", body, stats):
		Log.error("FAIL: Duplicate name allowed")
		fails += 1
	
	# 3. modify_stat clamps between 1 and 99
	var chars = CharacterManager.get_all_characters()
	var cid = chars[chars.size() - 1]["id"]
	CharacterManager.modify_stat(cid, "strength", 1000)
	if CharacterManager.get_character_stats(cid)["strength"] != 99:
		Log.error("FAIL: modify_stat did not clamp max")
		fails += 1
	CharacterManager.modify_stat(cid, "strength", -200)
	if CharacterManager.get_character_stats(cid)["strength"] != 1:
		Log.error("FAIL: modify_stat did not clamp min")
		fails += 1
	
	# 4. Inventory container should be present and count zero
	var inv_count = CharacterManager.get_character_inventory_count(cid)
	if inv_count != 0:
		Log.error("FAIL: New character inventory count not zero, got %d" % inv_count)
		fails += 1
	
	# 5. Rendering works for character body parts
	var tex = CharacterRenderer.render_character(body)
	if tex == null:
		Log.error("FAIL: CharacterRenderer returned null")
		fails += 1
	
	# 6. Soft-delete moves to graveyard
	var before_gc = CharacterManager.get_graveyard().size()
	CharacterManager.soft_delete_character(cid)
	if CharacterManager.get_graveyard().size() != before_gc + 1:
		Log.error("FAIL: soft_delete did not append to graveyard")
		fails += 1
	
	# 7. Purge and Clear graveyard API
	CharacterManager.purge_graveyard_entry(CharacterManager.get_graveyard().size() - 1)
	if CharacterManager.get_graveyard().size() != before_gc:
		Log.error("FAIL: purge_graveyard_entry did not remove entry")
		fails += 1
	# Add again and clear
	CharacterManager.soft_delete_character(cid)
	CharacterManager.clear_graveyard()
	if CharacterManager.get_graveyard().size() != 0:
		Log.error("FAIL: clear_graveyard did not clear entries")
		fails += 1

	# 8. Progression unlocking emits signal
	var unlocked_state: Dictionary = {"ok": false}
	var cb: Callable = func(_p) -> void:
		unlocked_state["ok"] = true
	ProgressionManager.body_part_unlocked.connect(cb)
	ProgressionManager.unlock_body_part("head_01")
	await get_tree().process_frame
	ProgressionManager.body_part_unlocked.disconnect(cb)
	if not unlocked_state["ok"]:
		Log.error("FAIL: ProgressionManager did not emit body_part_unlocked signal")
		fails += 1
	if not ProgressionManager.is_body_part_unlocked("head_01"):
		Log.error("FAIL: ProgressionManager did not record unlocked part")
		fails += 1

	# 8. Container transfers (inventory <-> character)
	# Register a test item
	ItemRegistry.register_item({"id":"test_item_01","name":"Test Item","description":"A test item.","category":"misc","icon":"res://assets/icons/default_app.svg","stackable":true})
	InventoryManager.add_item("test_item_01", 2)
	# Create a new character for this test
	var cname = "container_tester_" + str(randi() % 100000)
	var created2 = CharacterManager.create_character(cname, "test", body, stats)
	if not created2:
		Log.error("FAIL: Could not create character for container test")
		fails += 1
		return fails
	var chars2 = CharacterManager.get_all_characters()
	var cid2 = chars2[chars2.size() - 1]["id"]
	# Move one item to container
	if not InventoryManager.add_to_container(cid2, "test_item_01", 1):
		Log.error("FAIL: add_to_container returned false")
		fails += 1
	else:
		# Ensure container has it
		var c_slots = InventoryManager.get_container_slots(cid2)
		var found = false
		for s in c_slots:
			if s != null and s["id"] == "test_item_01": found = true
		if not found:
			Log.error("FAIL: Item not present in container after add")
			fails += 1
		# Remove from container
		if not InventoryManager.remove_from_container(cid2, "test_item_01", 1):
			Log.error("FAIL: remove_from_container failed")
			fails += 1
		# Inventory should be able to accept it back
		if InventoryManager.add_item("test_item_01", 1) == false:
			Log.error("FAIL: Could not add item back to inventory")
			fails += 1
	
	# 6. purge graveyard entry
	CharacterManager.purge_graveyard_entry(CharacterManager.get_graveyard().size() - 1)
	# Entry removed, size equals before_gc
	if CharacterManager.get_graveyard().size() != before_gc:
		Log.error("FAIL: purge_graveyard_entry did not remove entry")
		fails += 1
	
	# 7. purchase_character_slot emits shop_open
	var received = {"ok": false}
	var cb_shop = func(p):
		if p.get("item", "") == "character_slot":
			received["ok"] = true
	EventBus.subscribe("shop_open", cb_shop)
	CharacterManager.purchase_character_slot()
	await get_tree().process_frame
	EventBus.unsubscribe("shop_open", cb_shop)
	if not received["ok"]:
		Log.error("FAIL: purchase_character_slot did not emit shop_open")
		fails += 1
	
	# 8. export_character returns path
	var export_path = CharacterManager.export_character(cid)
	if export_path == "":
		Log.error("FAIL: export_character returned empty path")
		fails += 1
	
	return fails

func _is_focused(node: Node) -> bool:
	if node == null: return false
	if node.has_method("has_focus"):
		if node.has_focus(): return true
	if node.has_method("is_focused"):
		if node.is_focused(): return true
	if UIHelpers.get_focus_owner() == node: return true
	if get_tree().has_method("get_focus_owner"):
		if get_tree().get_focus_owner() == node: return true
	return false

func _test_gallery_ui() -> int:
	Log.info("TEST: Verifying Gallery UI and accessibility...")
	var fails = 0

	# Instantiate the Character Creator scene
	var scene = load("res://apps/character_creator/character_creator.tscn").instantiate()
	get_tree().get_root().add_child(scene)
	await get_tree().process_frame

	# Create a test character
	var ui_char_name: String = "ui_char_" + str(randi() % 100000)
	var body: Dictionary = {"head": "head_01", "eyes": "eyes_01", "mouth": "mouth_01", "hair": "hair_01", "arms": "arms_01", "hands": "hands_01", "legs": "legs_01", "feet": "feet_01"}
	var stats: Dictionary = {"gold": 5, "agility": 5, "strength": 5, "intelligence": 5, "constitution": 5, "luck": 5}
	if not CharacterManager.create_character(ui_char_name, "test", body, stats):
		Log.error("FAIL: Could not create test character for Gallery UI")
		scene.queue_free()
		return fails + 1

	# Refresh gallery and find card
	scene._refresh_gallery()
	await get_tree().process_frame
	var grid = scene.get_node_or_null("./MainTab/Gallery/GalleryList/GalleryGrid/GalleryVBox")
	if not grid or grid.get_child_count() == 0:
		Log.error("FAIL: Gallery grid is empty after refresh")
		fails += 1
	else:
		# Find a gallery card by name (robust against extra widgets)
		var child = null
		for i in range(grid.get_child_count()):
			var ch = grid.get_child(i)
			if ch is Button and ch.name.begins_with("char_card_"):
				child = ch
				break
			# Fallback: pick first Button in grid
			if child == null:
				for e in range(grid.get_child_count()):
					var ch2 = grid.get_child(e)
					if ch2 is Button:
						child = ch2
						break
		if child == null:
			Log.error("FAIL: No character card found in gallery")
			fails += 1
		else:
			# Card should be a Button for accessibility
			if not child is Button:
				Log.error("FAIL: Gallery card is not focusable Button")
				fails += 1
			else:
				# Test focus behavior
				child.grab_focus()
				await get_tree().process_frame
				if not _is_focused(child):
					Log.error("FAIL: Could not focus gallery card via grab_focus")
					fails += 1
				# Simulate focus_entered handler and check visual
				scene._on_card_focus_entered(child)
				if child.modulate == Color(1,1,1,1):
					Log.error("FAIL: Focus visual not applied on card")
					fails += 1
				# Test keyboard shortcut: 'N' to open creation tab
				var ev := InputEventKey.new()
				ev.keycode = Key.KEY_N
				ev.pressed = true
				scene._unhandled_input(ev)
				var tb = scene.get_node_or_null("./MainTab")
				if tb == null or tb.current_tab != 0:
					Log.error("FAIL: 'N' shortcut did not open New Character tab")
					fails += 1
				# Test arrow key navigation
				var ev_left := InputEventKey.new()
				ev_left.keycode = Key.KEY_RIGHT
				ev_left.pressed = true
				scene._unhandled_input(ev_left)
				await get_tree().process_frame
				var found_focus = false
				for ch in grid.get_children():
					if ch.name.begins_with("char_card_") and _is_focused(ch):
						found_focus = true
						break
				if not found_focus:
					Log.error("FAIL: Arrow navigation did not focus a card")
					fails += 1
				# Test Delete shortcut with confirmation: simulate focus and delete
				child.grab_focus()
				await get_tree().process_frame
				var ev2 := InputEventKey.new()
				ev2.keycode = Key.KEY_DELETE
				ev2.pressed = true
				scene._unhandled_input(ev2)
				# Poll for confirmation dialog up to 10 frames
				var dlg_found = null
				for i in range(10):
					for ch in get_tree().get_root().get_children():
						if ch is ConfirmationDialog and ch.title == "Delete Character?":
							dlg_found = ch
							break
					if dlg_found != null:
						break
					await get_tree().process_frame
				if dlg_found:
					dlg_found.emit_signal("confirmed")
					await get_tree().process_frame
					# Character should be in graveyard
					if CharacterManager.get_graveyard().size() == 0:
						Log.error("FAIL: Delete via keyboard shortcut did not move to graveyard")
						fails += 1
				else:
					Log.error("FAIL: Confirmation dialog not found for delete")
					fails += 1
			# Tooltip contains shortcut hint (via TooltipManager)
			# Simulate mouse enter to trigger tooltip
			child.emit_signal("mouse_entered")
			await get_tree().process_frame
			var tm := get_tree().get_root().get_node_or_null("/root/TooltipManager")
			if tm == null:
				Log.error("FAIL: TooltipManager not present")
				fails += 1
			else:
				if not tm.is_visible():
					Log.error("FAIL: Tooltip not visible after mouse_enter")
					fails += 1
				else:
					if tm.get_text().find("Delete") == -1:
						Log.error("FAIL: Tooltip does not contain 'Delete' hint")
						fails += 1
			# Hide tooltip
			child.emit_signal("mouse_exited")
			await get_tree().process_frame
			if tm != null and tm.is_visible():
				Log.error("FAIL: Tooltip still visible after mouse_exit")
				fails += 1

	# Clean up
	scene.queue_free()
	return fails
