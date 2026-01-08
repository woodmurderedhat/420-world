extends "res://scripts/app_base.gd"

@onready var templates_dir := "res://apps/character_creator/templates/"
var templates: Array = []
var current_viewing_character_id: String = ""
var active_tab: int = 0
var scroll_positions: Dictionary = {}

func _ready() -> void:
	# Lazy init
	BodyPartRegistry.load_all_parts()
	_load_templates()

func _load_templates() -> void:
	templates.clear()
	var dir = DirAccess.open(templates_dir)
	if dir:
		if dir.list_dir_begin() == OK:
			var fname = dir.get_next()
			while fname != "":
				if not dir.current_is_dir() and fname.ends_with('.json'):
					var fpath = templates_dir + fname
					var f = FileAccess.open(fpath, FileAccess.READ)
					if f:
						var j = JSON.new()
						if j.parse(f.get_as_text()) == OK:
							templates.append(j.data)
				fname = dir.get_next()

	# Wire UI callbacks if present
	call_deferred("_connect_ui")

func _connect_ui() -> void:
	# Safe to call even if nodes are missing in headless tests
	var _name_input = get_node_or_null("./MainTab/Creation/RightPane/NameInput")
	var _cat_input = get_node_or_null("./MainTab/Creation/RightPane/CategoryInput")
	var create_btn = get_node_or_null("./MainTab/Creation/RightPane/CreateBtn")
	if create_btn:
		create_btn.pressed.connect(_on_create_pressed)

	# Build part selection UI and preview references
	parts_vbox = get_node_or_null("./MainTab/Creation/LeftPane/PartScroll/PartsVBox")
	preview_tex = get_node_or_null("./MainTab/Creation/RightPane/PreviewTexture")
	_build_part_selection()
	_update_preview()

	# Listen to unlock events
	ProgressionManager.body_part_unlocked.connect(_on_body_part_unlocked)
	# Listen to container inventory changes and refresh if viewing that character
	InventoryManager.container_inventory_changed.connect(func(cid):
		if cid == selected_character_id:
			_refresh_character_inventory(cid)
		)

	# Refresh gallery UI
	_refresh_gallery()

	# Wire graveyard clear button
	var clear_btn = get_node_or_null("./MainTab/Graveyard/GraveyardTop/GraveyardClearBtn")
	if clear_btn:
		clear_btn.pressed.connect(func() -> void:
			DialogManager.show_confirm("Clear Graveyard", "Are you sure you want to clear the entire graveyard?", func(confirmed):
				if confirmed:
					CharacterManager.clear_graveyard()
					_refresh_graveyard()
					DialogManager.show_toast("Graveyard cleared")
				)
			)

	# Initial graveyard build
	_refresh_graveyard()

# --- UI state persistence ---
func save_state() -> Dictionary:
	return {
		"currently_viewing_character_id": current_viewing_character_id,
		"active_tab": active_tab,
		"scroll_positions": scroll_positions
	}

func load_state(data: Dictionary) -> void:
	# Defensive: sometimes callers pass non-dictionary values (eg. a Node) by mistake. Guard and log.
	if typeof(data) != TYPE_DICTIONARY:
		Log.warn("CharacterCreator.load_state: expected Dictionary but got %s (%s)" % [str(typeof(data)), str(data)])
		return
	if data.has("currently_viewing_character_id"):
		current_viewing_character_id = data["currently_viewing_character_id"]
	if data.has("active_tab"):
		active_tab = int(data["active_tab"])
	if data.has("scroll_positions"):
		scroll_positions = data["scroll_positions"]

# --- Helper APIs used by UI ---
func get_templates() -> Array:
	return templates

func validate_name(candidate_name: String) -> Dictionary:
	# Returns {ok: bool, error: String}
	if candidate_name.strip_edges() == "":
		return {"ok": false, "error": "Name cannot be empty."}
	if candidate_name.length() < 1 or candidate_name.length() > 32:
		return {"ok": false, "error": "Name must be 1-32 characters."}
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_ ]+$")
	if not pattern.search(candidate_name):
		return {"ok": false, "error": "Only letters, numbers, spaces and underscores allowed."}
	if CharacterManager.is_name_taken(candidate_name):
		return {"ok": false, "error": "Name already used."}
	return {"ok": true}

func _on_create_pressed() -> void:
	var name_input = get_node_or_null("./MainTab/Creation/NameInput")
	var cat_input = get_node_or_null("./MainTab/Creation/CategoryInput")
	var status = get_node_or_null("./MainTab/Creation/StatusLabel")
	if name_input == null:
		return
	var char_name: String = name_input.text.strip_edges()
	var category = ""
	if cat_input:
		category = cat_input.text.strip_edges()

	# Use first template by default for body parts and stats
	var default_template = templates[0] if templates.size() > 0 else {}
	var body_parts = default_template.get("body_parts", {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"})
	var stats = default_template.get("suggested_stats", {"gold":5,"agility":5,"strength":5,"intelligence":5,"constitution":5,"luck":5})

	var res = create_character_from_ui(char_name, category, body_parts, stats)
	if not res["ok"]:
		if status: status.text = "Error: %s" % res["error"]
		Log.error("Character Creator: %s" % res["error"])
	else:
		if status: status.text = "Created %s" % char_name
		Log.info("Character Creator: Created %s" % char_name)
		# Clear input
		name_input.text = ""
		if cat_input: cat_input.text = ""
		# Refresh gallery
		_refresh_gallery()

func _refresh_gallery() -> void:
	var gallery_grid = get_node_or_null("./MainTab/Gallery/GalleryList/GalleryGrid/GalleryVBox")
	var category_select = get_node_or_null("./MainTab/Gallery/GalleryList/GalleryTop/CategorySelect")
	var slot_label = get_node_or_null("./MainTab/Gallery/GalleryList/GalleryTop/SlotCounter")
	if not gallery_grid or not category_select or not slot_label:
		return
	# Build categories
	var chars = CharacterManager.get_all_characters()
	Log.info("Gallery.refresh: found %d characters" % chars.size())
	var categories = {"All": []}
	for c in chars:
		var cat = c.get("category", "")
		if cat == "": cat = "Uncategorized"
		if not categories.has(cat): categories[cat] = []
		categories[cat].append(c)
	categories["All"] = chars

	# Populate category select
	category_select.clear()
	for cat_name in categories.keys():
		category_select.add_item(cat_name)

	# Update slot counter
	var used = CharacterManager.get_active_character_count()
	var owned = UserManager.get_character_slots_owned()
	slot_label.text = "%d of %d slots used" % [used, owned]

	# Show selected category (default All)
	var sel_idx = category_select.get_selected_id()
	if sel_idx < 0:
		sel_idx = 0
	var sel_cat = category_select.get_item_text(sel_idx)
	var display_chars = categories.get(sel_cat, [])

	# Clear grid
	Log.info("Gallery.refresh: clearing grid (children=%d)" % gallery_grid.get_child_count())
	for c in gallery_grid.get_children():
		c.queue_free()

	# Add cards
	for c in display_chars:
		var cid = c.get("id", "")
		Log.info("Gallery.refresh: adding card for %s" % cid)
		# Use Button for accessibility (focusable, clickable)
		var card := Button.new()
		card.name = "char_card_%s" % cid
		card.custom_minimum_size = Vector2(160, 140)
		card.focus_mode = Control.FOCUS_ALL
		# Clear default text and use children
		card.text = ""
		var vbox := VBoxContainer.new()
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		# Preview and labels
		var preview := TextureRect.new()
		preview.texture = CharacterRenderer.render_character(c.get("body_parts", {}))
		preview.custom_minimum_size = Vector2(64,64)
		preview.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		vbox.add_child(preview)
		var name_lbl := Label.new()
		name_lbl.text = c.get("name", "Unnamed")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)
		# category badge
		var cat_text = c.get("category", "")
		if cat_text == "": cat_text = "Uncategorized"
		var badge := Label.new()
		badge.text = cat_text
		badge.add_theme_color_override("font_color", Color(0.85,0.6,0.15))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(badge)
		card.add_child(vbox)
		# Tooltip with stats + keyboard hints
		var stats = c.get("stats", {})
		var tip = ""
		for k in stats:
			tip += "%s: %s\n" % [k.capitalize(), str(stats[k])]
		tip += "\nShortcuts: Enter=View, Delete=Delete"
		card.tooltip_text = tip
		# Apply themed stylebox for card background
		var sb = ThemeManager.get_card_stylebox()
		card.add_theme_stylebox_override("panel", sb)
		# Hover effects and tooltip wiring
		card.mouse_entered.connect(func() -> void:
			card.modulate = Color(0.98, 0.98, 1.02, 1.0)
			var tm : Node = get_tree().root.get_node_or_null("/root/TooltipManager")
			if tm:
				tm.show_tooltip(tip, get_global_mouse_position(), 4.0)
			# Apply hover stylebox
			card.add_theme_stylebox_override("panel", ThemeManager.get_card_hover_stylebox())
			)
		card.mouse_exited.connect(func() -> void:
			if UIHelpers.get_focus_owner() != card:
				card.modulate = Color(1, 1, 1, 1)
			var tm : Node = get_tree().root.get_node_or_null("/root/TooltipManager")
			if tm:
				tm.hide_tooltip()
			# Revert stylebox
			card.add_theme_stylebox_override("panel", ThemeManager.get_card_stylebox())
			)
		# Focus visuals
		card.focus_entered.connect(func() -> void:
			_on_card_focus_entered(card)
			)
		card.focus_exited.connect(func() -> void:
			_on_card_focus_exited(card)
			)
		# Click selects character
		card.pressed.connect(func() -> void:
			_on_character_selected(cid)
			)
		gallery_grid.add_child(card)
	# Log children names for debugging
	var _tmp_names: Array = []
	var _found_card: bool = false
	for ch in gallery_grid.get_children():
		_tmp_names.append("%s (%s)" % [ch.name, str(ch)])
		Log.info("Gallery child check: %s => begins_with char_card_? %s" % [ch.name, str(ch.name.begins_with("char_card_"))])
		if ch.name.begins_with("char_card_"):
			_found_card = true
	Log.info("Gallery children names: %s" % [_tmp_names])
	Log.info("Gallery has char_card_ child? %s" % _found_card)

	# Hook category selection change
	category_select.pressed.connect(func():
		_refresh_gallery()
		)

	# Add New Character and Purchase buttons
	var btn_row := HBoxContainer.new()
	var new_btn := Button.new()
	new_btn.text = "New Character"
	new_btn.focus_mode = Control.FOCUS_ALL
	new_btn.pressed.connect(func() -> void:
		var tb := get_node_or_null("./MainTab")
		if tb:
			tb.current_tab = 0
		)
	btn_row.add_child(new_btn)

	if used >= owned:
		var purchase_btn := Button.new()
		purchase_btn.text = "Purchase Slot"
		purchase_btn.focus_mode = Control.FOCUS_ALL
		purchase_btn.pressed.connect(func() -> void:
			CharacterManager.purchase_character_slot()
			DialogManager.show_toast("Opened shop for character slots")
			)
		btn_row.add_child(purchase_btn)

	gallery_grid.add_child(btn_row)

# --- Part Selection UI ---
var PART_TYPES: Array = ["head","eyes","mouth","hair","arms","hands","legs","feet"]
var parts_vbox: VBoxContainer = null
var preview_tex: TextureRect = null
var selected_parts: Dictionary = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
var selected_character_id: String = ""

func _build_part_selection() -> void:
	if parts_vbox == null:
		return
	# Clear
	for c in parts_vbox.get_children():
		c.queue_free()

	for t in PART_TYPES:
		var lbl := Label.new()
		lbl.text = t.capitalize()
		parts_vbox.add_child(lbl)
		var row := HBoxContainer.new()
		parts_vbox.add_child(row)
		var parts = BodyPartRegistry.get_parts(t)
		for p in parts:
			var pid = p.get("id", "")
			var tex = BodyPartRegistry.get_part_texture(pid, t)
			var btn := TextureButton.new()
			btn.texture_normal = tex
			btn.custom_minimum_size = Vector2(48,48)
			btn.disabled = false
			# If locked, show overlay and unlock button
			var locked = false
			if p.get("cost", 0) > 0:
				locked = not ProgressionManager.is_body_part_unlocked(pid)
			if locked:
				btn.modulate = Color(0.6,0.6,0.6,1)
				var unlock_btn := Button.new()
				unlock_btn.text = "Unlock (%d)" % p.get("cost",0)
				unlock_btn.pressed.connect(func() -> void:
					EventBus.emit_event("shop_open", {"item": pid, "cost": p.get("cost",0)})
					DialogManager.show_toast("Shop opened for %s" % pid)
					)
				var vbox := VBoxContainer.new()
				vbox.add_child(btn)
				vbox.add_child(unlock_btn)
				row.add_child(vbox)
			else:
				btn.pressed.connect(func() -> void:
					_on_part_selected(t, pid)
					)
				var vbox := VBoxContainer.new()
				vbox.add_child(btn)
				var name_lbl := Label.new()
				name_lbl.text = p.get("name", "")
				vbox.add_child(name_lbl)
				row.add_child(vbox)

func _on_part_selected(type: String, part_id: String) -> void:
	selected_parts[type] = part_id
	_update_preview()

func _update_preview() -> void:
	if preview_tex == null: return
	var tex = CharacterRenderer.render_character(selected_parts)
	preview_tex.texture = tex

func _on_body_part_unlocked(_part_id: String) -> void:
	# Rebuild parts (simple approach)
	_build_part_selection()

func _refresh_graveyard() -> void:
	var gv = get_node_or_null("./MainTab/Graveyard/GraveyardScroll/GraveyardVBox")
	if not gv:
		return
	# Clear
	for c in gv.get_children():
		c.queue_free()
	var grave = CharacterManager.get_graveyard()
	for i in range(grave.size()):
		var e = grave[i]
		var row := HBoxContainer.new()
		row.name = "grave_%d" % i
		row.custom_minimum_size = Vector2(0, 28)
		var name_lbl := Label.new()
		name_lbl.text = e.get("name", "Unnamed")
		name_lbl.custom_minimum_size = Vector2(180, 0)
		row.add_child(name_lbl)
		var date_lbl := Label.new()
		date_lbl.text = e.get("deletion_date", "")
		date_lbl.custom_minimum_size = Vector2(220, 0)
		row.add_child(date_lbl)
		var stat_lbl := Label.new()
		stat_lbl.text = "Top: %s (%s)" % [e.get("highest_stat", {}).get("name", "None"), str(e.get("highest_stat", {}).get("value", 0))]
		stat_lbl.custom_minimum_size = Vector2(140,0)
		row.add_child(stat_lbl)
		var gold_lbl := Label.new()
		gold_lbl.text = "Gold: %d" % int(e.get("final_gold", 0))
		gold_lbl.custom_minimum_size = Vector2(80,0)
		row.add_child(gold_lbl)
		var purge_btn := Button.new()
		purge_btn.text = "Purge"
		purge_btn.focus_mode = Control.FOCUS_ALL
		purge_btn.pressed.connect(func() -> void:
			DialogManager.show_confirm("Purge Entry", "Purge entry '%s'?" % e.get("name", ""), func(confirmed):
				if confirmed:
					CharacterManager.purge_graveyard_entry(i)
					_refresh_graveyard()
					DialogManager.show_toast("Purged %s" % e.get("name", ""))
				)
			)
		row.add_child(purge_btn)
		gv.add_child(row)

	# If empty, show label
	if grave.size() == 0:
		var lbl := Label.new()
		lbl.text = "No entries in graveyard"
		gv.add_child(lbl)

# --- Focus visuals helpers ---
func _on_card_focus_entered(card: Button) -> void:
	card.modulate = Color(0.95, 1.0, 0.95, 1.0)
	# Optional: add a small border by adjusting style if desired

func _on_card_focus_exited(card: Button) -> void:
	card.modulate = Color(1, 1, 1, 1)

# --- Accessibility: keyboard shortcuts ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 'N' to open New Character tab
		if event.keycode == Key.KEY_N:
			var tb = get_node_or_null("./MainTab")
			if tb:
				tb.current_tab = 0
				DialogManager.show_toast("New Character (N)")
		# Delete focused character with Delete key
		elif event.keycode == Key.KEY_DELETE:
			var focused = UIHelpers.get_focus_owner()
			var target = focused
			# Fallback: find focused-like child in gallery if global focus not available
			if target == null:
				var grid = get_node_or_null("./MainTab/Gallery/GalleryList/GalleryGrid/GalleryVBox")
				if grid != null:
					for ch in grid.get_children():
						if ch.name.begins_with("char_card_"):
							if (ch.has_method("is_focused") and ch.is_focused()) or (ch.has_method("has_focus") and ch.has_focus()):
								target = ch
								break
			if target != null and target.name.begins_with("char_card_"):
				var cid = target.name.replace("char_card_", "")
				DialogManager.show_confirm("Delete Character?", "Delete %s? This is permanent." % CharacterManager.get_character(cid).get("name", ""), func(confirmed):
					if confirmed:
						CharacterManager.soft_delete_character(cid)
						_refresh_gallery()
						DialogManager.show_toast("Moved %s to Graveyard" % CharacterManager.get_character(cid).get("name", ""))
					)
		# Arrow key navigation for gallery
		elif event.keycode in [Key.KEY_LEFT, Key.KEY_RIGHT, Key.KEY_UP, Key.KEY_DOWN]:
			var grid = get_node_or_null("./MainTab/Gallery/GalleryList/GalleryGrid/GalleryVBox")
			if grid == null: return
			var cards = []
			for ch in grid.get_children():
				if ch.name.begins_with("char_card_"):
					cards.append(ch)
			if cards.size() == 0: return
			var focused = UIHelpers.get_focus_owner()
			var idx = 0
			if focused != null and focused.name.begins_with("char_card_"):
				idx = cards.find(focused)
			var cols = 4
			var target = idx
			match event.keycode:
				Key.KEY_LEFT:
					target = max(0, idx - 1)
				Key.KEY_RIGHT:
					target = min(cards.size() - 1, idx + 1)
				Key.KEY_UP:
					target = max(0, idx - cols)
				Key.KEY_DOWN:
					target = min(cards.size() - 1, idx + cols)
			if target != idx:
				cards[target].grab_focus()
		# Enter to select focused card
		elif event.keycode == Key.KEY_ENTER or event.keycode == Key.KEY_KP_ENTER:
			var focused = UIHelpers.get_focus_owner()
			if focused != null and focused.name.begins_with("char_card_"):
				var cid = focused.name.replace("char_card_", "")
				_on_character_selected(cid)

func _on_character_selected(char_id: String) -> void:
	# Safe-get details widgets
	var details_preview = get_node_or_null("./MainTab/Gallery/Details/Preview")
	var details_grid = get_node_or_null("./MainTab/Gallery/Details/InfoGrid")
	if details_preview and details_grid:
		DialogManager.show_toast("Selected %s" % CharacterManager.get_character(char_id).get("name", ""))
	var c = CharacterManager.get_character(char_id)
	var body = c.get("body_parts", {})
	if details_preview:
		details_preview.texture = CharacterRenderer.render_character(body)
		# Build inventory grid
		_refresh_character_inventory(char_id)
		# Show slot usage header on details
		var slot_info = get_node_or_null("./MainTab/Gallery/GalleryList/GalleryTop/SlotCounter")
		if slot_info:
			var used = CharacterManager.get_character_inventory_count(char_id)
			slot_info.text = "%d items in character inventory" % used
	# Also refresh graveyard view to keep UI in sync
	_refresh_graveyard()

func _refresh_character_inventory(char_id: String) -> void:
	var grid = get_node_or_null("./MainTab/Gallery/Details/InventoryGrid")
	if not grid: return
	# Clear
	for ch in grid.get_children():
		ch.queue_free()
	# Ensure container exists
	InventoryManager.create_container(char_id, CharacterManager.get_character(char_id).get("inventory_capacity", 10))
	var slots = InventoryManager.get_container_slots(char_id)
	for i in range(slots.size()):
		var panel : PanelContainer = load("res://apps/character_creator/character_container_slot.gd").new()
		panel.setup(char_id, i, slots[i])
		grid.add_child(panel)

	# Ensure we listen for changes for this character
	# Avoid duplicating connections: disconnect then connect
	if InventoryManager.container_inventory_changed.is_connected(_on_container_changed):
		InventoryManager.container_inventory_changed.disconnect(_on_container_changed)
	InventoryManager.container_inventory_changed.connect(_on_container_changed)

func _on_container_changed(cid: String) -> void:
	if cid == selected_character_id:
		_refresh_character_inventory(cid)


func create_character_from_ui(char_name: String, category: String, body_parts: Dictionary, stats: Dictionary) -> Dictionary:
	var validation = validate_name(char_name)
	if not validation["ok"]:
		return {"ok": false, "error": validation["error"]}
	if not CharacterManager.can_create_character():
		return {"ok": false, "error": "No character slots available."}
	var success = CharacterManager.create_character(char_name, category, body_parts, stats)
	if not success:
		return {"ok": false, "error": "Failed to create character."}
	# Refresh gallery after creation
	call_deferred("_refresh_gallery")
	return {"ok": true}
