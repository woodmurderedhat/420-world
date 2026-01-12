extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var called_true = false
	var called_false = false
	# Confirm true
	DialogManager.show_confirm("Confirm True", "Please confirm", func(res):
		called_true = res
	)
	await get_tree().process_frame
	# Find dialog and emit confirmed
	for c in get_tree().get_root().get_children():
		if c is ConfirmationDialog:
			c.emit_signal("confirmed")
			break
	await get_tree().process_frame
	if not called_true:
		print("DialogManager test failed: confirmed callback not invoked or not true")
		quit(1)

	# Confirm false (cancel)
	DialogManager.show_confirm("Confirm False", "Please confirm", func(res):
		called_false = not res
	)
	await get_tree().process_frame
	for c in get_tree().get_root().get_children():
		if c is ConfirmationDialog:
			c.emit_signal("canceled")
			break
	await get_tree().process_frame
	if not called_false:
		print("DialogManager test failed: canceled callback not invoked or not false")
		quit(1)

	print("DialogManager tests passed")
	quit(0)