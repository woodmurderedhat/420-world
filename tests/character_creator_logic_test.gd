extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var logic := CharacterCreatorLogic.new()
	logic.templates_dir = "res://apps/character_creator/templates/"
	logic.load_templates()
	if logic.get_templates().size() == 0:
		print("CharacterCreatorLogic test failed: no templates loaded")
		quit(1)

	# Name validation
	var res = logic.validate_name("")
	if res["ok"]:
		print("CharacterCreatorLogic test failed: empty name accepted")
		quit(1)

	res = logic.validate_name("Bad/Name")
	if res["ok"]:
		print("CharacterCreatorLogic test failed: invalid chars accepted")
		quit(1)

	# Create character (this will interact with CharacterManager)
	CharacterManager.clear_all_characters()
	var body_parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	var stats = logic.default_stats()
	res = logic.create_character_from_data("TestCharLogic", "Test", body_parts, stats)
	if not res["ok"]:
		print("CharacterCreatorLogic test failed: create returned error: %s" % res.get("error", ""))
		quit(1)

	# confirm character present
	var chars = CharacterManager.get_all_characters()
	var found := false
	for c in chars:
		if c.get("name", "") == "TestCharLogic":
			found = true
			break
	if not found:
		print("CharacterCreatorLogic test failed: created character not found")
		quit(1)

	# Cleanup
	CharacterManager.clear_all_characters()

	print("CharacterCreatorLogic tests passed")
	quit(0)
