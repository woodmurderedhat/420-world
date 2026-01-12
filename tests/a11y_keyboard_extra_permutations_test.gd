extends Node

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	# Test several keyboard permutations and confirm/cancel flows
	BodyPartRegistry.load_all_parts()
	CharacterManager.clear_all_characters()

	var logic := CharacterCreatorLogic.new()
	logic.templates_dir = "res://apps/character_creator/templates/"
	logic.load_templates()
	var parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	# Create two characters
	var r1 = logic.create_character_from_data("PermA", "Test", parts, logic.default_stats())
	var r2 = logic.create_character_from_data("PermB", "Test", parts, logic.default_stats())
	if not r1["ok"] or not r2["ok"]:
		print("A11Y permutations test failed to create characters")
		get_tree().quit()

	var cc = load("res://apps/character_creator/character_creator.tscn").instantiate()
	add_child(cc)
	await get_tree().process_frame
	cc._connect_ui()
	await get_tree().process_frame

	var grid = cc._ui.gallery.container if cc._ui and cc._ui.gallery else null
	if grid == null:
		print("A11Y permutations test failed: gallery grid missing")
		quit(1)
	var cards = []
	for ch in grid.get_children():
		if ch.name.begins_with("char_card_"):
			cards.append(ch)
	if cards.size() < 2:
		print("A11Y permutations test inconclusive: less than 2 cards")
		get_tree().quit()

	# Permutation 1: Delete then Cancel quickly
	cards[0].grab_focus()
	await get_tree().process_frame
	var e := InputEventKey.new()
	e.keycode = Key.KEY_DELETE
	e.pressed = true
	cc._unhandled_input(e)
	await get_tree().process_frame
	# Find dialog and cancel it
	for c in get_tree().get_root().get_children():
		if c is ConfirmationDialog:
			c.emit_signal("canceled")
			break
	await get_tree().process_frame
	# ensure character still exists
	var m = CharacterManager.get_characters_manifest()
	var found = false
	for entry in m:
		if entry.get("name", "") == "PermA":
			found = true
			break
	if not found:
		print("A11Y permutations test failed: character removed after cancel")
		get_tree().quit()

	# Permutation 2: Delete then Confirm
	cards[1].grab_focus()
	await get_tree().process_frame
	e.keycode = Key.KEY_DELETE
	cc._unhandled_input(e)
	await get_tree().process_frame
	for c in get_tree().get_root().get_children():
		if c is ConfirmationDialog:
			c.emit_signal("confirmed")
			break
	await get_tree().process_frame
	# ensure character moved to graveyard
	var found_deleted = false
	for entry in CharacterManager.get_characters_manifest():
		if entry.get("name", "") == "PermB":
			if entry.get("deleted", false):
				found_deleted = true
				break
	if not found_deleted:
		print("A11Y permutations test failed: character not deleted after confirm")
		get_tree().quit()

	# Permutation 3: Focus + Enter selects details via controller
	cards[0].grab_focus()
	await get_tree().process_frame
	e.keycode = Key.KEY_ENTER
	cc._unhandled_input(e)
	await get_tree().process_frame
	# ensure selected_character_id updated
	if cc.selected_character_id == "":
		print("A11Y permutations test failed: Enter did not select character")
		get_tree().quit()

	print("A11Y keyboard permutations test passed")
	quit(0)
