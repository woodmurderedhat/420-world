extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var called = []
	# Show two confirms; confirm the first then the second after delay
	DialogManager.show_confirm("C1", "First", func(res): called.append({"id":"c1","val":res}))
	DialogManager.show_confirm("C2", "Second", func(res): called.append({"id":"c2","val":res}))
	await get_tree().process_frame

	# Confirm the first (which should be first in the root children list)
	var root = get_tree().get_root()
	var found = false
	for c in root.get_children():
		if c is ConfirmationDialog and not found:
			c.emit_signal("confirmed")
			found = true
			break
	await get_tree().process_frame
	# Wait a few frames (simulate longer interaction)
	for i in range(10):
		await get_tree().process_frame

	# Confirm the next dialog
	for c in root.get_children():
		if c is ConfirmationDialog:
			c.emit_signal("confirmed")
			break
	await get_tree().process_frame

	# Validate both callbacks fired with true
	if called.size() != 2:
		print("Confirm timing test failed: expected 2 callbacks, got %d" % called.size())
		quit(1)
	for e in called:
		if e["val"] != true:
			print("Confirm timing test failed: expected true confirmation for %s" % e["id"])
			quit(1)

	print("Confirm timing test passed")
	quit(0)