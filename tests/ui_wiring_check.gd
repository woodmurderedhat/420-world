extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://apps/character_creator/character_creator.tscn").instantiate()
	# This script extends SceneTree, so use SceneTree methods directly
	get_root().add_child(scene)
	await process_frame

	if scene.get_script() == null:
		print("UI wiring check FAILED: scene script is null")
		quit(1)
	else:
		print("UI wiring check: scene script present: %s" % str(scene.get_script()))

	if not scene.has_method("_refresh_gallery"):
		print("UI wiring check FAILED: scene missing _refresh_gallery method")
		quit(1)
	else:
		print("UI wiring check: _refresh_gallery present")

	# Check _connect_ui has created _ui flag if present
	if scene.has_property("ui_ready"):
		print("UI wiring check: ui_ready=%s" % str(scene.ui_ready))
	else:
		print("UI wiring check: ui_ready property not found")

	quit(0)
