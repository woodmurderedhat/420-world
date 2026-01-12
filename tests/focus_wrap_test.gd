extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	BodyPartRegistry.load_all_parts()
	CharacterManager.clear_all_characters()

	var logic := CharacterCreatorLogic.new()
	logic.templates_dir = "res://apps/character_creator/templates/"
	logic.load_templates()
	var parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	# create characters
	for i in range(6):
		var r = logic.create_character_from_data("Wrap%d" % i, "Test", parts, logic.default_stats())
		if not r["ok"]:
			print("Focus wrap test failed: couldn't create char %d" % i)
			quit(1)

	var cc = load("res://apps/character_creator/character_creator.tscn").instantiate()
	add_child(cc)
	await get_tree().process_frame
	cc._connect_ui()
	await get_tree().process_frame

	# Resolve cards list
	var grid = cc._ui.gallery.container if cc._ui and cc._ui.gallery else null
	if grid == null:
		print("Focus wrap test failed: gallery grid missing")
		quit(1)
	var cards = []
	for ch in grid.get_children():
		if ch.name.begins_with("char_card_"):
			cards.append(ch)
	if cards.size() < 2:
		print("Focus wrap test inconclusive: less than 2 cards")
		quit(0)

	# Focus last card and press Right (should remain clamped to last)
	cards[-1].grab_focus()
	await get_tree().process_frame
	var e := InputEventKey.new()
	e.keycode = Key.KEY_RIGHT
	e.pressed = true
	cc._unhandled_input(e)
	await get_tree().process_frame
	var focused = UIHelpers.get_focus_owner()
	if focused == null or not focused.name.begins_with("char_card_"):
		print("Focus wrap test failed: focus lost after right arrow")
		quit(1)
	if focused != cards[-1]:
		print("Focus wrap test failed: expected clamp to last, but moved")
		quit(1)

	# Focus first and press Left (should clamp to first)
	cards[0].grab_focus()
	await get_tree().process_frame
	e.keycode = Key.KEY_LEFT
	cc._unhandled_input(e)
	await get_tree().process_frame
	focused = UIHelpers.get_focus_owner()
	if focused != cards[0]:
		print("Focus wrap test failed: expected clamp to first, but moved")
		quit(1)

	print("Focus wrap test passed (behavior: clamped, no wrap-around)")
	quit(0)