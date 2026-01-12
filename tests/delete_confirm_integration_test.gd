extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	BodyPartRegistry.load_all_parts()
	CharacterManager.clear_all_characters()
	InventoryManager.slots.clear()
	InventoryManager.containers.clear()

	var logic := CharacterCreatorLogic.new()
	logic.templates_dir = "res://apps/character_creator/templates/"
	logic.load_templates()
	var parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	var res = logic.create_character_from_data("DelConfirm","Test", parts, logic.default_stats())
	if not res["ok"]:
		print("Delete confirm integration test failed: couldn't create char")
		quit(1)
	var cid = CharacterManager.get_all_characters()[0].get("id")

	# Call controller handler directly to exercise DialogManager path
	var cc = load("res://apps/character_creator/character_creator.tscn").instantiate()
	add_child(cc)
	await get_tree().process_frame
	# Ensure UI wired
	if not cc.ui_ready:
		# try to connect UI
		cc._connect_ui()
		await get_tree().process_frame

	# Invoke delete handler
	cc._on_gallery_delete_requested(cid)
	await get_tree().process_frame
	# Find confirmation dialog and confirm
	for c in get_tree().get_root().get_children():
		if c is ConfirmationDialog:
			c.emit_signal("confirmed")
			break
	await get_tree().process_frame
	# Verify character marked deleted / moved to graveyard
	if not CharacterManager.characters[cid].get("deleted", false):
		print("Delete confirm integration test failed: character not marked deleted after confirm")
		quit(1)
	if CharacterManager.get_graveyard().size() == 0:
		print("Delete confirm integration test failed: graveyard empty after confirm")
		quit(1)

	print("Delete confirm integration test passed")
	quit(0)