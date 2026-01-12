extends Node
class_name CharacterCreatorUI

# UI coordinator for character creator. Keeps wiring centralized and emits signals
signal create_pressed(name: String, category: String)

var controller: Node = null

# Preloads for internal modules
var PartSelector := preload("res://apps/character_creator/part_selector/character_part_selector.gd")
var StatInputs := preload("res://apps/character_creator/stat_inputs/character_stat_inputs.gd")
var TemplatesUI := preload("res://apps/character_creator/templates/character_templates_ui.gd")
var GalleryClass: Script = null
var GraveyardClass: Script = null
var ShortcutsClass := preload("res://apps/character_creator/shortcuts/character_shortcuts.gd")

var _part_selector: Node = null
var _stat_inputs: Node = null
var _templates_ui: Node = null
var _gallery: Node = null
var _graveyard: Node = null
var _shortcuts: Node = null

func _find_node(cn: Node, candidates: Array) -> Node:
	for p in candidates:
		var n = cn.get_node_or_null(p)
		if n != null:
			return n
	return null

func _try_instance_scene(path: String) -> Node:
	var res = load(path)
	if res is PackedScene:
		return res.instantiate()
	return null

func build(controller_node: Node) -> void:
	controller = controller_node
	# Wire creation button and inputs
	var name_input = controller.get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#NameInput")
	var cat_input = controller.get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#CategoryInput")
	var create_btn = controller.get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#CreateBtn")
	if create_btn:
		create_btn.pressed.connect(func():
			if name_input == null:
				return
				var char_name = name_input.text.strip_edges()
				var category = ""
				if cat_input:
					category = cat_input.text.strip_edges()
				# Emit high level create signal; controller will handle logic
				emit_signal("create_pressed", char_name, category)
			)

	# Part selector (support multiple path variants)
	var part_candidates = [
		"./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#LeftPane/MainTab_Creation_LeftPane#PartScroll/MainTab_Creation_LeftPane_PartScroll#PartsVBox",
		"./MainTab/Creation/LeftPane/PartScroll/PartsVBox",
		"./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#LeftPane#PartsVBox",
	]
	var part_container_node = _find_node(controller, part_candidates)
	if part_container_node != null:
		# Prefer a packaged scene if available
		var part_scene = _try_instance_scene("res://apps/character_creator/part_selector/part_selector.tscn")
		if part_scene != null:
			controller.add_child(part_scene)
			# The scene attaches the module script and will auto-build itself on ready
			_part_selector = part_scene
			_part_selector.connect("part_changed", Callable(controller, "_on_part_selected"))
			controller._part_selector = _part_selector
		else:
			_part_selector = PartSelector.new()
			controller.add_child(_part_selector)
			_part_selector.connect("part_changed", Callable(controller, "_on_part_selected"))
			_part_selector.build(part_container_node, controller.selected_parts)
			controller._part_selector = _part_selector
	else:
		Log.warn("CharacterCreatorUI: part_container not found; skipping part selector build")

	# Stat inputs (support multiple parent variants)
	var parent_candidates = [
		"./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane",
		"./MainTab/Creation/RightPane",
	]
	var parent_right = _find_node(controller, parent_candidates)
	if parent_right != null:
		# Try packaged scene first
		var stat_scene = _try_instance_scene("res://apps/character_creator/stat_inputs/stat_inputs.tscn")
		if stat_scene != null:
			controller.add_child(stat_scene)
			_stat_inputs = stat_scene
			_stat_inputs.connect("stats_changed", Callable(controller, "_on_stats_changed"))
			controller._stat_inputs = _stat_inputs
		else:
			_stat_inputs = StatInputs.new()
			controller.add_child(_stat_inputs)
			_stat_inputs.build(parent_right)
			_stat_inputs.connect("stats_changed", Callable(controller, "_on_stats_changed"))
			controller._stat_inputs = _stat_inputs
	else:
		Log.warn("CharacterCreatorUI: parent_right not found; skipping stat inputs build")

	# Templates
	var tmpl_container = parent_right.get_node_or_null("TemplatesRow") if parent_right else null
	if tmpl_container:
		var templates_scene = _try_instance_scene("res://apps/character_creator/templates/templates.tscn")
		if templates_scene != null:
			controller.add_child(templates_scene)
			_templates_ui = templates_scene
			_templates_ui.build(tmpl_container, controller.templates)
			_templates_ui.connect("template_applied", Callable(controller, "_apply_template_from_ui"))
			controller._templates_ui = _templates_ui
		else:
			_templates_ui = TemplatesUI.new()
			controller.add_child(_templates_ui)
			_templates_ui.build(tmpl_container, controller.templates)
			_templates_ui.connect("template_applied", Callable(controller, "_apply_template_from_ui"))
	else:
		Log.warn("CharacterCreatorUI: template container not found; skipping templates UI")

	# Preview texture reference (for controller to update)
	controller.preview_tex = controller.get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#PreviewTexture")

	# Shortcuts
	var shortcuts_scene = _try_instance_scene("res://apps/character_creator/shortcuts/shortcuts.tscn")
	if shortcuts_scene != null:
		controller.add_child(shortcuts_scene)
		_shortcuts = shortcuts_scene
		_shortcuts.on_open_new = Callable(controller, "_on_gallery_new_requested")
		_shortcuts.on_delete_callback = Callable(controller, "_on_gallery_delete_requested")
		_shortcuts.on_select_callback = Callable(controller, "_invoke_focused_card_select")
	else:
		_shortcuts = ShortcutsClass.new()
		controller.add_child(_shortcuts)
		_shortcuts.on_open_new = Callable(controller, "_on_gallery_new_requested")
		_shortcuts.on_delete_callback = Callable(controller, "_on_gallery_delete_requested")
		_shortcuts.on_select_callback = Callable(controller, "_invoke_focused_card_select")

	# Gallery (support multiple path variants to be robust in tests)
	var gallery_container_candidates = [
		"./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryGrid/MainTab_Gallery_GalleryList_GalleryGrid#GalleryVBox",
		"./MainTab/Gallery/GalleryList/GalleryGrid/GalleryVBox",
	]
	var category_candidates = [
		"./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryTop/MainTab_Gallery_GalleryList_GalleryTop#CategorySelect",
		"./MainTab/Gallery/GalleryList/GalleryTop/CategorySelect",
	]
	var slot_candidates = [
		"./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryTop/MainTab_Gallery_GalleryList_GalleryTop#SlotCounter",
		"./MainTab/Gallery/GalleryList/GalleryTop/SlotCounter",
	]
	var cat_select = _find_node(controller, category_candidates)
	var gallery_container = _find_node(controller, gallery_container_candidates)
	var slot_label = _find_node(controller, slot_candidates)
	# Prefer a packaged gallery app if available
	var gallery_scene = _try_instance_scene("res://apps/character_creator/gallery/gallery.tscn")
	if gallery_scene != null:
		# If a gallery container exists in the current UI, attach the packaged scene there to preserve expected layout
		if gallery_container != null:
			gallery_container.add_child(gallery_scene)
		else:
			controller.add_child(gallery_scene)
		_gallery = gallery_scene
		# connect signals if the scene exposes them
		if _gallery.has_signal("character_selected"):
			_gallery.character_selected.connect(Callable(controller, "_on_character_selected"))
		if _gallery.has_signal("export_requested"):
			_gallery.export_requested.connect(Callable(controller, "_on_gallery_export_requested"))
		if _gallery.has_signal("delete_requested"):
			_gallery.delete_requested.connect(Callable(controller, "_on_gallery_delete_requested"))
		if _gallery.has_signal("new_requested"):
			_gallery.new_requested.connect(Callable(controller, "_on_gallery_new_requested"))
		if _gallery.has_signal("purchase_requested"):
			_gallery.purchase_requested.connect(Callable(controller, "_on_gallery_purchase_requested"))
		# If the current layout provides a gallery container, allow the packaged gallery scene to build into it
		if gallery_container != null and cat_select != null and slot_label != null and _gallery.has_method("build"):
			_gallery.build(gallery_container, cat_select, slot_label)
		Log.info("CharacterCreatorUI: gallery scene instantiated")
		# Expose module instance to controller for convenience
		controller.gallery = _gallery
		if controller.has_method("_on_ui_built"):
			controller._on_ui_built()
		elif controller.has_property("ui_ready"):
			controller.ui_ready = true
	# Fallback to in-place module building
	elif gallery_container and cat_select and slot_label:
		# Load module script at runtime to avoid preload-time parse errors
		if GalleryClass == null:
			GalleryClass = load("res://apps/character_creator/gallery/character_gallery.gd")
		if GalleryClass != null:
			_gallery = GalleryClass.new()
			controller.add_child(_gallery)
			_gallery.build(gallery_container, cat_select, slot_label)
			_gallery.character_selected.connect(Callable(controller, "_on_character_selected"))
			_gallery.export_requested.connect(Callable(controller, "_on_gallery_export_requested"))
			_gallery.delete_requested.connect(Callable(controller, "_on_gallery_delete_requested"))
			_gallery.new_requested.connect(Callable(controller, "_on_gallery_new_requested"))
			_gallery.purchase_requested.connect(Callable(controller, "_on_gallery_purchase_requested"))
			Log.info("CharacterCreatorUI: gallery built and connected")
			# Expose module instance to controller for convenience
			controller.gallery = _gallery
			# Mark controller UI readiness
			if controller.has_method("_on_ui_built"):
				controller._on_ui_built()
			elif controller.has_property("ui_ready"):
				controller.ui_ready = true
		else:
			Log.warn("CharacterCreatorUI: GalleryClass failed to load; skipping gallery build")
	else:
		Log.warn("CharacterCreatorUI: gallery nodes not found; skipping gallery build (container=%s, cat=%s, slot=%s)" % [str(gallery_container), str(cat_select), str(slot_label)])

	# Graveyard: prefer packaged scene
	var grave_scene = _try_instance_scene("res://apps/character_creator/graveyard/graveyard.tscn")
	if grave_scene != null:
		controller.add_child(grave_scene)
		_graveyard = grave_scene
		if _graveyard.has_signal("cleared"):
			_graveyard.cleared.connect(Callable(controller, "_on_graveyard_cleared"))
		if _graveyard.has_signal("entry_purged"):
			_graveyard.entry_purged.connect(Callable(controller, "_on_graveyard_entry_purged"))
		# Expose to controller
		controller.graveyard = _graveyard
	else:
		var clear_btn = controller.get_node_or_null("./MainLayout/MainTab/MainTab#Graveyard/MainTab_Graveyard#GraveyardTop/MainTab_Graveyard_GraveyardTop#GraveyardClearBtn")
		var gv_node = controller.get_node_or_null("./MainLayout/MainTab/MainTab#Graveyard/MainTab_Graveyard#GraveyardScroll/MainTab_Graveyard_GraveyardScroll#GraveyardVBox")
		if gv_node and clear_btn:
			# Load graveyard module at runtime to avoid preload-time parse errors
			if GraveyardClass == null:
				GraveyardClass = load("res://apps/character_creator/graveyard/character_graveyard.gd")
			if GraveyardClass != null:
				_graveyard = GraveyardClass.new()
				controller.add_child(_graveyard)
				_graveyard.build(gv_node, clear_btn)
				_graveyard.cleared.connect(Callable(controller, "_on_graveyard_cleared"))
				_graveyard.entry_purged.connect(Callable(controller, "_on_graveyard_entry_purged"))
				# Expose to controller
				controller.graveyard = _graveyard
			else:
				Log.warn("CharacterCreatorUI: GraveyardClass failed to load; skipping graveyard build")
		_gallery.refresh()
	if _graveyard != null:
		_graveyard.refresh()

func get_selected_parts() -> Dictionary:
	return _part_selector.get_selection() if _part_selector != null else {}

func get_stats() -> Dictionary:
	return _stat_inputs.get_stats() if _stat_inputs != null else {}

func refresh_all() -> void:
	if _gallery != null:
		_gallery.refresh()
	if _graveyard != null:
		_graveyard.refresh()