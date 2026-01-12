extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var s = load("res://apps/character_creator/stat_inputs/stat_inputs.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
	if s.has_method("build"):
		s.build(s)
		await get_tree().process_frame
	if not s.has_method("get_stats"):
		print("Stat inputs test failed: missing get_stats")
		quit(1)
	var stats = s.get_stats()
	if typeof(stats) != TYPE_DICTIONARY or not stats.has("gold"):
		print("Stat inputs test failed: unexpected stats")
		quit(1)
	# test set_stats
	var new = stats.duplicate()
	new["gold"] = 42
	s.set_stats(new)
	await get_tree().process_frame
	var stats2 = s.get_stats()
	if stats2.get("gold", 0) != 42:
		print("Stat inputs test failed: set_stats did not update")
		quit(1)

	print("Stat inputs tests passed")
	quit(0)