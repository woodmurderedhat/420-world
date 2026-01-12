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
	# create 2 characters
	for i in range(2):
		var r = logic.create_character_from_data("A11Y%d" % i, "Test", parts, logic.default_stats())
		if not r["ok"]:
			print("A11Y test failed: couldn't create char %d" % i)
			quit(1)

	var cc = load("res://apps/character_creator/character_creator.tscn").instantiate()
	add_child(cc)
	await get_tree().process_frame
	cc._connect_ui()
	await get_tree().process_frame

	# find first card
	var grid = cc._ui.gallery.container if cc._ui and cc._ui.gallery else null
	if grid == null:
		print("A11Y test failed: gallery grid missing")
		quit(1)
	var first_card = null
	for ch in grid.get_children():
		if ch.name.begins_with("char_card_"):
			first_card = ch
			break
	if first_card == null:
		print("A11Y test failed: no card found")
		quit(1)

	# Connect selection signal
	var selected_id = ""
	cc._ui.gallery.connect("character_selected", Callable(self, "_on_selected"))
	func _on_selected(id: String) -> void:
		selected_id = id

	# Focus and simulate Enter via controller _unhandled_input (this is the a11y path)
	first_card.grab_focus()
	await get_tree().process_frame
	var e := InputEventKey.new()
	e.keycode = Key.KEY_ENTER
	e.pressed = true
	cc._unhandled_input(e)
	await get_tree().process_frame
	if selected_id == "":
		print("A11Y test failed: Enter did not select focused card")
		quit(1)

	# Test Delete triggers confirm and deletion flow
	var cid = selected_id
	# Send Delete through controller
	e.keycode = Key.KEY_DELETE
	cc._unhandled_input(e)
	await get_tree().process_frame
	# Confirm the dialog
	for c in get_tree().get_root().get_children():
		if c is ConfirmationDialog:
			c.emit_signal("confirmed")
			break
	await get_tree().process_frame
	if not CharacterManager.characters[cid].get("deleted", false):
		print("A11Y test failed: Delete confirm flow did not mark character deleted")
		quit(1)

	print("A11Y keyboard permutations test passed")
	quit(0)