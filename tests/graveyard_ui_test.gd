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
	var res = logic.create_character_from_data("GraveTester","Test", parts, logic.default_stats())
	if not res["ok"]:
		print("Graveyard UI test failed: couldn't create char")
		quit(1)
	var cid = CharacterManager.get_all_characters()[0].get("id")
	# soft-delete to add to grave
	CharacterManager.soft_delete_character(cid)

	var gv = load("res://apps/character_creator/graveyard/graveyard.tscn").instantiate()
	add_child(gv)
	if gv.has_method("refresh"):
		gv.refresh()
	await get_tree().process_frame

	# ensure purge button exists for at least one entry
	var found_purge = false
	var container = gv.get_node_or_null("GraveyardVBox")
	if container == null:
		print("Graveyard UI test failed: container not found")
		quit(1)
	for ch in container.get_children():
		for gc in ch.get_children():
			if gc is Button and gc.text == "Purge":
				found_purge = true
				break
		if found_purge: break
	if not found_purge:
		print("Graveyard UI test failed: purge button missing")
		quit(1)

	# Test clearing via CharacterManager and refresh
	CharacterManager.clear_graveyard()
	gv.refresh()
	await get_tree().process_frame
	if container.get_child_count() == 0:
		print("Graveyard UI test failed: container empty expected to show empty label")
		quit(1)
	var lbl = container.get_child(0)
	if not (lbl is Label) or not lbl.text.begins_with("No entries"):
		print("Graveyard UI test failed: expected empty label")
		quit(1)

	print("Graveyard UI tests passed")
	quit(0)