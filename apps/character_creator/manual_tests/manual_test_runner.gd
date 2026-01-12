extends Control

func _ready() -> void:
	$OpenGallery.pressed.connect(func(): _open_scene("res://apps/character_creator/gallery/gallery.tscn", "Gallery"))
	$OpenGraveyard.pressed.connect(func(): _open_scene("res://apps/character_creator/graveyard/graveyard.tscn", "Graveyard"))
	$OpenParts.pressed.connect(func(): _open_scene("res://apps/character_creator/part_selector/part_selector.tscn", "PartSelector"))
	$OpenTemplates.pressed.connect(func(): _open_scene("res://apps/character_creator/templates/templates.tscn", "Templates"))
	$OpenStats.pressed.connect(func(): _open_scene("res://apps/character_creator/stat_inputs/stat_inputs.tscn", "Stats"))
	$OpenDetails.pressed.connect(func(): _open_scene("res://apps/character_creator/details/details.tscn", "Details"))
	$OpenShortcuts.pressed.connect(func(): _open_scene("res://apps/character_creator/shortcuts/shortcuts.tscn", "Shortcuts"))

func _open_scene(path: String, name: String) -> void:
	# remove previous
	if has_node(name):
		get_node(name).queue_free()
	var s = load(path).instantiate()
	s.name = name
	$Holder.add_child(s)
	$Status.text = "%s instantiated" % name
	print("Manual test: instantiated %s" % path)