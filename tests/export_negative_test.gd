extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	# Ensure clean slate
	CharacterManager.clear_all_characters()

	var logic := CharacterCreatorLogic.new()
	var body_parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	var stats = logic.default_stats()
	var res = logic.create_character_from_data("ExportTester","Test", body_parts, stats)
	if not res["ok"]:
		print("Export negative test failed: couldn't create character: %s" % res.get("error",""))
		quit(1)

	var cid = CharacterManager.get_all_characters()[0].get("id")

	# Create a file at path 'user://exports' (no trailing slash) to block directory creation
	var exports_dir_no_slash = ProjectSettings.globalize_path("user://exports")
	var f = FileAccess.open(exports_dir_no_slash, FileAccess.WRITE)
	if not f:
		print("Export negative test failed: couldn't create sentinel file")
		quit(1)
	f.store_string("I block the exports dir")
	f.close()

	# Attempt export - should fail (return empty string)
	var p = CharacterManager.export_character(cid)
	# Clean up sentinel
	if FileAccess.file_exists(exports_dir_no_slash):
		DirAccess.remove_absolute(exports_dir_no_slash)

	if p != "":
		print("Export negative test failed: export succeeded unexpectedly: %s" % p)
		quit(1)

	print("Export negative test passed")
	quit(0)
