extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	CharacterManager.clear_all_characters()
	InventoryManager.slots.clear()
	InventoryManager.containers.clear()

	var logic := CharacterCreatorLogic.new()
	var body_parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	var stats = logic.default_stats()
	var res = logic.create_character_from_data("IconTester","Test", body_parts, stats)
	if not res["ok"]:
		print("Icon test failed: couldn't create character: %s" % res.get("error",""))
		quit(1)

	var cid = CharacterManager.get_all_characters()[0].get("id")
	# Icon path should exist on disk
	var expected_path = ProjectSettings.globalize_path("user://icons/char_%s.png" % cid)
	if not FileAccess.file_exists(expected_path):
		print("Icon test failed: expected icon not found at %s" % expected_path)
		quit(1)

	print("Icon tests passed")
	quit(0)
