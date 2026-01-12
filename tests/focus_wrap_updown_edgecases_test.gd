extends Node

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	BodyPartRegistry.load_all_parts()
	CharacterManager.clear_all_characters()

	var logic := CharacterCreatorLogic.new()
	logic.templates_dir = "res://apps/character_creator/templates/"
	logic.load_templates()
	var parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	# create 7 characters (partial final row for 4-col grid)
	for i in range(7):
		var r = logic.create_character_from_data("UDWrap%d" % i, "Test", parts, logic.default_stats())
		if not r["ok"]:
			print("Focus up/down wrap test failed: couldn't create char %d" % i)
		get_tree().quit()
	var cc = load("res://apps/character_creator/character_creator.tscn").instantiate()
	cc.set("gallery_wrap_navigation", true)
	add_child(cc)
	await get_tree().process_frame
	cc._connect_ui()
	await get_tree().process_frame

	var grid = cc._ui.gallery.container if cc._ui and cc._ui.gallery else null
	if grid == null:
		print("Focus up/down wrap test failed: gallery grid missing")
		get_tree().quit()
	var cards = []
	for ch in grid.get_children():
		if ch.name.begins_with("char_card_"):
			cards.append(ch)
	if cards.size() < 2:
		print("Focus up/down wrap test inconclusive: less than 2 cards")
		get_tree().quit()

	# Choose an index in first row (index 1) and test Down wraps to correct index in last partial row
	var cols: int = 4
	var start_idx: int = 1
	cards[start_idx].grab_focus()
	await get_tree().process_frame
	var e := InputEventKey.new()
	e.keycode = Key.KEY_DOWN
	e.pressed = true
	cc._unhandled_input(e)
	await get_tree().process_frame
	var focused = UIHelpers.get_focus_owner()
	# Expected: move down by cols wrapping to the same column in bottom-most rows
	var rows = int((cards.size() + cols - 1) / cols)
	var expected = (start_idx + cols * (rows - 1)) % cards.size()
	if focused != cards[expected]:
		print("Focus up/down wrap test failed: expected to wrap to %d but got %s" % [expected, str(focused)])
		get_tree().quit()

	# Now test Up from partial last row index wraps to correct top row index
	# pick last row index with same column (if exists)
	cards[expected].grab_focus()
	await get_tree().process_frame
	e.keycode = Key.KEY_UP
	cc._unhandled_input(e)
	await get_tree().process_frame
	focused = UIHelpers.get_focus_owner()
	if focused != cards[start_idx]:
		print("Focus up/down wrap test failed: expected to wrap back to %d but got %s" % [start_idx, str(focused)])
		get_tree().quit()

	# Edge-case: Single item grid should remain focused on up/down
	CharacterManager.clear_all_characters()
	logic.create_character_from_data("Solo", "Test", parts, logic.default_stats())
	await get_tree().process_frame
	cc._refresh_gallery()
	await get_tree().process_frame
	# rebuild cards array
	cards = []
	for ch in grid.get_children():
		if ch.name.begins_with("char_card_"):
			cards.append(ch)
	if cards.size() == 1:
		cards[0].grab_focus()
		await get_tree().process_frame
		e.keycode = Key.KEY_DOWN
		cc._unhandled_input(e)
		await get_tree().process_frame
		var focused2 = UIHelpers.get_focus_owner()
		if focused2 != cards[0]:
			print("Focus up/down wrap test failed: single item focus moved on Down")
		get_tree().quit()
	print("Focus up/down wrap test passed")
	get_tree().quit()
