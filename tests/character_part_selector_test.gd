extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	# Prepare environment
	CharacterManager.clear_all_characters()
	InventoryManager.slots.clear()
	InventoryManager.containers.clear()

	# Stub body parts for head type
	BodyPartRegistry.parts_cache = {
		"head": [
			{"id": "head_free_01", "name": "Free Head", "cost": 0},
			{"id": "head_paid_01", "name": "Paid Head", "cost": 10}
		]
	}

	# Ensure paid parts are locked
	ProgressionManager.unlocked_body_parts = []

	# Create selector and UI container
	var selector := load("res://apps/character_creator/part_selector/character_part_selector.gd").new()
	var vbox := VBoxContainer.new()
	selector.build(vbox, {})

	# After build, there should be children for "head" label and a row
	var found_label := false
	var found_row := null
	for child in vbox.get_children():
		if child is Label and child.text == "Head":
			found_label = true
		elif child is HBoxContainer:
			found_row = child

	if not found_label or found_row == null:
		print("CharacterPartSelector test failed: UI elements not built")
		quit(1)

	# Inspect parts in row: should contain two vbox children (free and paid)
	if found_row.get_child_count() < 2:
		print("CharacterPartSelector test failed: expected 2 part entries, got %d" % found_row.get_child_count())
		quit(1)

	var paid_vbox := null
	var free_vbox := null
	for i in range(found_row.get_child_count()):
		var vb = found_row.get_child(i)
		if vb.get_child_count() >= 2 and vb.get_child(1) is Button:
			paid_vbox = vb
		else:
			free_vbox = vb

	if paid_vbox == null or free_vbox == null:
		print("CharacterPartSelector test failed: could not identify paid/free entries")
		quit(1)

	# Subscribe to shop_open to detect unlock flow
	self.shop_called = false
	EventBus.subscribe("shop_open", Callable(self, "_on_shop_open"))

	# Press the unlock button
	var unlock_btn := paid_vbox.get_child(1)
	unlock_btn.emit_signal("pressed")

	# Check event handler toggled flag
	if not self.shop_called:
		print("CharacterPartSelector test failed: unlock did not emit shop_open")
		quit(1)

	# Test selecting free part triggers part_changed
	self.pressed_ok = false
	selector.connect("part_changed", Callable(self, "_on_part_changed"))
	var free_btn = free_vbox.get_child(0)
	free_btn.emit_signal("pressed")
	if not self.pressed_ok:
		print("CharacterPartSelector test failed: pressing free part did not trigger part_changed")
		quit(1)

	# Cleanup
	EventBus.clear()
	CharacterManager.clear_all_characters()

	print("CharacterPartSelector tests passed")
	quit(0)

func _on_shop_open(payload: Dictionary) -> void:
	# Simple flag set to indicate callback
	if payload.has("item"):
		# Mark flag via a global (test-level) variable on self
		self.set("shop_called", true)

func _on_part_changed(t: String, pid: String) -> void:
	self.set("pressed_ok", true)
