extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var tmpl_scene = load("res://apps/character_creator/templates/templates.tscn").instantiate()
	add_child(tmpl_scene)
	await get_tree().process_frame
	# call build with small templates array
	if tmpl_scene.has_method("build"):
		tmpl_scene.build(tmpl_scene.get_node_or_null("TemplatesRow"), [{"name":"T1"}])
		await get_tree().process_frame
		# There should be a Button child
		var row = tmpl_scene.get_node_or_null("TemplatesRow")
		if row == null or row.get_child_count() == 0:
			print("Templates UI test failed: TemplatesRow missing or empty")
			quit(1)
		var btn = row.get_child(0)
		if not (btn is Button):
			print("Templates UI test failed: expected Button")
			quit(1)
		var applied = false
		if tmpl_scene.has_signal("template_applied"):
			tmpl_scene.connect("template_applied", Callable(self, "_on_templ"))
			func _on_templ(t: Dictionary) -> void:
				applied = t.get("name", "") == "T1"
			btn.pressed.emit()
			await get_tree().process_frame
			if not applied:
				print("Templates UI test failed: template_applied not emitted")
				quit(1)

	print("Templates UI tests passed")
	quit(0)