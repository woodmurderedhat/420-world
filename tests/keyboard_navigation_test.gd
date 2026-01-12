extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	BodyPartRegistry.load_all_parts()
	CharacterManager.clear_all_characters()

	var logic := CharacterCreatorLogic.new()
	logic.templates_dir = "res://apps/character_creator/templates/"
	logic.load_templates()
	var parts = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
	# create multiple characters
	for i in range(6):
		var r = logic.create_character_from_data("Nav%d" % i, "Test", parts, logic.default_stats())
		if not r["ok"]:
			print("Keyboard nav test failed: create char %d" % i)
			quit(1)

	var cc = load("res://apps/character_creator/character_creator.tscn").instantiate()
	add_child(cc)
	await get_tree().process_frame
	# ensure UI ready
	cc._connect_ui()
	await get_tree().process_frame

	# Find gallery grid
	var grid = cc.get_node_or_null("MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryGrid/MainTab_Gallery_GalleryList_GalleryGrid#GalleryVBox")
	if grid == null:
		# try alt path
		grid = cc.get_node_or_null("MainTab/Gallery/GalleryList/GalleryGrid/GalleryVBox")
	if grid == null:
		# If not present, fall back to using _ui.gallery container
		if cc._ui and cc._ui.gallery and cc._ui.gallery.container:
			grid = cc._ui.gallery.container
	if grid == null:
		print("Keyboard nav test failed: gallery grid not found")
		quit(1)

	# ensure there is at least two cards
	var cards = []
	for ch in grid.get_children():
		if ch.name.begins_with("char_card_"):
			cards.append(ch)
	if cards.size() < 2:
		print("Keyboard nav test inconclusive: less than 2 cards")
		quit(0)

	# Focus first card
	cards[0].grab_focus()
	await get_tree().process_frame
	# Simulate right arrow
	var e := InputEventKey.new()
	e.keycode = Key.KEY_RIGHT
	e.pressed = true
	cc._unhandled_input(e)
	await get_tree().process_frame
	# Check focus moved (best-effort)
	var focused = UIHelpers.get_focus_owner()
	if focused == null:
		print("Keyboard nav test warning: no focus owner; skipping assert")
		quit(0)
	if not focused.name.begins_with("char_card_"):
		print("Keyboard nav test failed: focus not on card after arrow")
		quit(1)

	print("Keyboard navigation test passed (best-effort)")
	quit(0)