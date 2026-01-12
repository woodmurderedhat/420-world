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
	var res = logic.create_character_from_data("DetailTester","Test", parts, logic.default_stats())
	if not res["ok"]:
		print("Details test failed: couldn't create character")
		quit(1)
	var cid = CharacterManager.get_all_characters()[0].get("id")
	var d = load("res://apps/character_creator/details/details.tscn").instantiate()
	add_child(d)
	await get_tree().process_frame
	if d.has_method("show_character"):
		d.show_character(cid)
		await get_tree().process_frame
	# check preview texture set
	var prev = d.get_node_or_null("DetailsPreview")
	if prev == null or prev.texture == null:
		print("Details test failed: preview missing or null")
		quit(1)
	# check inventory grid populated
	var grid = d.get_node_or_null("InventoryGrid")
	if grid == null:
		print("Details test failed: inventory grid missing")
		quit(1)

	print("Details tests passed")
	quit(0)