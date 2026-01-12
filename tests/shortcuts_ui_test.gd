extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var s = load("res://apps/character_creator/shortcuts/shortcuts.tscn").instantiate()
	add_child(s)
	await get_tree().process_frame
	var called = false
	# set callback
	if s.has_method("build"):
		s.build()
	if s.has_variable("on_open_new"):
		s.on_open_new = Callable(self, "_on_new")
	else:
		s.set("on_open_new", Callable(self, "_on_new"))
	func _on_new() -> void:
		called = true
	# simulate key event N
	var e := InputEventKey.new()
	e.keycode = Key.KEY_N
	e.pressed = true
	s._unhandled_input(e)
	await get_tree().process_frame
	if not called:
		print("Shortcuts test failed: on_open_new not invoked")
		quit(1)

	print("Shortcuts tests passed")
	quit(0)