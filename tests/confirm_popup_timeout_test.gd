extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	# Ensure no auto-confirm happens if no one interacts with the dialog
	var called := false
	DialogManager.show_confirm("Timeout Test", "Please confirm via UI", func(res):
		called = true
	)
	# Wait a short while (longer than typical UI animations)
	await get_tree().create_timer(1.5).timeout
	if called:
		print("Confirm timeout test failed: callback invoked without user interaction")
		quit(1)
	# Clean up the dialog by sending a cancel if present
	for c in get_tree().get_root().get_children():
		if c is ConfirmationDialog:
			c.emit_signal("canceled")
			break
	await get_tree().process_frame
	print("Confirm timeout test passed (no auto-timeout)")
	quit(0)
