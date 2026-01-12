extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	# Basic setup
	BodyPartRegistry.load_all_parts()
	CharacterManager.clear_all_characters()
	InventoryManager.slots.clear()
	InventoryManager.containers.clear()

	# 1) Gallery scene
	var gallery_scene = load("res://apps/character_creator/gallery/gallery.tscn").instantiate()
	add_child(gallery_scene)
	if gallery_scene.has_method("refresh"):
		gallery_scene.refresh()
	# allow a frame
	await get_tree().process_frame
	gallery_scene.queue_free()

	# 2) Graveyard scene
	var grave_scene = load("res://apps/character_creator/graveyard/graveyard.tscn").instantiate()
	add_child(grave_scene)
	if grave_scene.has_method("refresh"):
		grave_scene.refresh()
	await get_tree().process_frame
	grave_scene.queue_free()

	# 3) Part selector scene
	var part_scene = load("res://apps/character_creator/part_selector/part_selector.tscn").instantiate()
	add_child(part_scene)
	if part_scene.has_method("refresh"):
		part_scene.refresh()
	await get_tree().process_frame
	part_scene.queue_free()

	# 4) Templates scene
	var tmpl_scene = load("res://apps/character_creator/templates/templates.tscn").instantiate()
	add_child(tmpl_scene)
	# If the script exposed build, call it with small template
	if tmpl_scene.has_method("build"):
		tmpl_scene.build(tmpl_scene.get_node_or_null("TemplatesRow"), [{"name":"T1"}])
	await get_tree().process_frame
	tmpl_scene.queue_free()

	# 5) Stat inputs scene
	var stat_scene = load("res://apps/character_creator/stat_inputs/stat_inputs.tscn").instantiate()
	add_child(stat_scene)
	if stat_scene.has_method("build"):
		stat_scene.build(stat_scene.get_node_or_null(".") )
	await get_tree().process_frame
	if stat_scene.has_method("get_stats"):
		var s = stat_scene.get_stats()
		if typeof(s) != TYPE_DICTIONARY:
			print("Stat inputs test failed: get_stats returned wrong type")
			quit(1)
	stat_scene.queue_free()

	# 6) Details scene (requires a character)
	var logic := CharacterCreatorLogic.new()
	logic.templates_dir = "res://apps/character_creator/templates/"
	logic.load_templates()
	var parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	var res = logic.create_character_from_data("SceneTester","Test", parts, logic.default_stats())
	if not res["ok"]:
		print("Details test failed: couldn't create character")
		quit(1)
	var cid = CharacterManager.get_all_characters()[0].get("id")
	var details_scene = load("res://apps/character_creator/details/details.tscn").instantiate()
	add_child(details_scene)
	if details_scene.has_method("show_character"):
		details_scene.show_character(cid)
	await get_tree().process_frame
	details_scene.queue_free()

	# 7) Shortcuts scene
	var sc_scene = load("res://apps/character_creator/shortcuts/shortcuts.tscn").instantiate()
	add_child(sc_scene)
	await get_tree().process_frame
	sc_scene.queue_free()

	print("Sub-app scene smoke tests passed")
	quit(0)