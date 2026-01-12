extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _find_button(node: Node, text: String) -> Button:
	for ch in node.get_children():
		if ch is Button and ch.text == text:
			return ch
		elif ch.get_child_count() > 0:
			var res = _find_button(ch, text)
			if res != null:
				return res
	return null

func _run_tests() -> void:
	BodyPartRegistry.load_all_parts()
	CharacterManager.clear_all_characters()
	InventoryManager.slots.clear()
	InventoryManager.containers.clear()

	var logic := CharacterCreatorLogic.new()
	logic.templates_dir = "res://apps/character_creator/templates/"
	logic.load_templates()
	var parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	var res = logic.create_character_from_data("GTest","Tools", parts, logic.default_stats())
	if not res["ok"]:
		print("Gallery UI test failed: couldn't create character")
		quit(1)
	var cid = CharacterManager.get_all_characters()[0].get("id")

	var g = load("res://apps/character_creator/gallery/gallery.tscn").instantiate()
	add_child(g)
	if g.has_method("refresh"):
		g.refresh()
	await get_tree().process_frame

	# find the card
	var found = null
	var grid = g.get_node_or_null("GalleryVBox")
	if grid == null:
		print("Gallery UI test failed: grid not found")
		quit(1)
	for ch in grid.get_children():
		if ch.name == "char_card_%s" % cid:
			found = ch
			break
	if found == null:
		print("Gallery UI test failed: card not found for %s" % cid)
		quit(1)

	# export signal
	var exported = false
	if g.has_signal("export_requested"):
		g.connect("export_requested", Callable(self, "_on_export_requested"))
		func _on_export_requested(id: String) -> void:
			exported = id == cid

	var exp_btn = _find_button(found, "Exp")
	if exp_btn == null:
		print("Gallery UI test failed: export button not found")
		quit(1)
	exp_btn.pressed.emit()
	await get_tree().process_frame
	if not exported:
		print("Gallery UI test failed: export signal not emitted")
		quit(1)

	# delete signal
	var deleted = false
	if g.has_signal("delete_requested"):
		g.connect("delete_requested", Callable(self, "_on_delete_requested"))
		func _on_delete_requested(id: String) -> void:
			deleted = id == cid
	var del_btn = _find_button(found, "Del")
	if del_btn == null:
		print("Gallery UI test failed: delete button not found")
		quit(1)
	del_btn.pressed.emit()
	await get_tree().process_frame
	if not deleted:
		print("Gallery UI test failed: delete signal not emitted")
		quit(1)

	print("Gallery UI tests passed")
	quit(0)