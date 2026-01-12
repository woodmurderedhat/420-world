extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var logic := CharacterCreatorLogic.new()
	logic.templates_dir = "res://apps/character_creator/templates/"
	logic.load_templates()
	if logic.get_templates().size() == 0:
		print("CharacterTemplates test failed: no templates available")
		quit(1)

	var tmpl := logic.get_templates()[0]
	var current_parts := {}
	var current_stats := {"gold":1,"agility":1}
	var res := logic.apply_template(tmpl, current_parts, current_stats)
	if not res.has("parts") or not res.has("stats"):
		print("CharacterTemplates test failed: apply_template did not return parts/stats")
		quit(1)

	# Ensure template overrides/adds body_parts entries
	var t_parts := tmpl.get("body_parts", {})
	for k in t_parts.keys():
		if res["parts"].get(k, "") != t_parts[k]:
			print("CharacterTemplates test failed: template part %s not applied" % k)
			quit(1)

	# Ensure suggested_stats merged into stats
	var s_stats := tmpl.get("suggested_stats", {})
	for sk in s_stats.keys():
		if res["stats"].get(sk, null) != s_stats[sk]:
			print("CharacterTemplates test failed: suggested stat %s not applied" % sk)
			quit(1)

	print("CharacterTemplates tests passed")
	quit(0)
