extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var logic := CharacterCreatorLogic.new()
	logic.load_templates()
	# Build a valid character using defaults
	var valid_body := {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	var valid := {
		"id": "good_char",
		"name": "GoodChar",
		"body_parts": valid_body,
		"stats": logic.default_stats(),
		"inventory_capacity": 10,
		"created_date": Time.get_datetime_string_from_system(),
		"deleted": false
	}

	var validator := preload("res://scripts/validators/character_schema_validator.gd").new()
	var res = validator.validate(valid)
	if not res["ok"]:
		print("CharacterSchema test failed: valid character rejected: %s" % String(res.get("errors","")))
		quit(1)

	# Missing id
	var bad = valid.duplicate(true)
	bad.erase("id")
	res = validator.validate(bad)
	if res["ok"]:
		print("CharacterSchema test failed: missing id accepted")
		quit(1)

	# Wrong type stat
	bad = valid.duplicate(true)
	bad["stats"]["strength"] = "not-a-number"
	res = validator.validate(bad)
	if res["ok"]:
		print("CharacterSchema test failed: wrong type stat accepted")
		quit(1)

	# Invalid body part key
	bad = valid.duplicate(true)
	bad["body_parts"]["wing"] = "wing_01"
	res = validator.validate(bad)
	if res["ok"]:
		print("CharacterSchema test failed: invalid body part key accepted")
		quit(1)

	# End-to-end load: write a mixed characters.json and ensure invalid entries are skipped
	var path = CharacterManager.CHARACTERS_FILE
	var abs_path = ProjectSettings.globalize_path(path)
	var orig_exists = FileAccess.file_exists(abs_path)
	var orig_text = ""
	if orig_exists:
		var f = FileAccess.open(abs_path, FileAccess.READ)
		if f:
			orig_text = f.get_as_text()
			f.close()

	# prepare mixed entries
	var mixed_good = valid
	mixed_good["id"] = "good_char"
	var mixed_bad = bad
	mixed_bad["id"] = "bad_char"
	var mixed_map = {"good_char": mixed_good, "bad_char": mixed_bad}

	# write file
	var fw = FileAccess.open(abs_path, FileAccess.WRITE)
	if fw:
		fw.store_string(JSON.stringify(mixed_map, "\t"))
		fw.close()

	# Reload into CharacterManager
	CharacterManager.clear_all_characters()
	CharacterManager._load_characters()

	var chars = CharacterManager.get_all_characters()
	var found_good := false
	for c in chars:
		if c.get("id","") == "good_char":
			found_good = true
			break
	if not found_good:
		print("CharacterSchema test failed: good char not loaded")
		# restore
		if orig_exists:
			var f2 = FileAccess.open(abs_path, FileAccess.WRITE)
			if f2:
				f2.store_string(orig_text)
				f2.close()
		quit(1)

	# ensure bad not present
	for c in chars:
		if c.get("id","") == "bad_char":
			print("CharacterSchema test failed: bad char loaded")
			if orig_exists:
				var f2 = FileAccess.open(abs_path, FileAccess.WRITE)
				if f2:
					f2.store_string(orig_text)
					f2.close()
			quit(1)

	# restore original file
	if orig_exists:
		var f3 = FileAccess.open(abs_path, FileAccess.WRITE)
		if f3:
			f3.store_string(orig_text)
			f3.close()

	# Cleanup
	CharacterManager.clear_all_characters()

	print("CharacterSchema tests passed")
	quit(0)
