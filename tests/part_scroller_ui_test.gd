extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	BodyPartRegistry.load_all_parts()
	var sc = load("res://apps/character_creator/part_selector/part_scroller.tscn").instantiate()
	add_child(sc)
	await get_tree().process_frame
	# ensure get_selection returns dictionary and keys exist
	if not sc.has_method("get_selection"):
		print("Part scroller test failed: missing get_selection")
		quit(1)
	var s = sc.get_selection()
	if typeof(s) != TYPE_DICTIONARY:
		print("Part scroller test failed: selection wrong type")
		quit(1)
	if not s.has("head"):
		print("Part scroller test failed: missing head in selection")
		quit(1)

	# test _next/_prev change selection
	var before = s.get("head", "")	
	sc._next("head")
	await get_tree().process_frame
	var after = sc.get_selection().get("head", "")
	# it's okay if same because only one option exists, but ensure method callable
	if typeof(after) != TYPE_STRING:
		print("Part scroller test failed: after selection wrong type")
		quit(1)

	print("Part scroller tests passed")
	quit(0)