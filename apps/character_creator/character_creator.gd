extends "res://scripts/app_base.gd"

@onready var templates_dir := "res://apps/character_creator/templates/"
var templates: Array = []
var current_viewing_character_id: String = ""
var active_tab: int = 0
var scroll_positions: Dictionary = {}
var stat_inputs: Dictionary = {}

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
	var _name_input = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#NameInput")
	var _cat_input = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#CategoryInput")
	var create_btn = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#CreateBtn")
	if create_btn:
		create_btn.pressed.connect(_on_create_pressed)

	# Build part selection UI and preview references
	parts_vbox = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#LeftPane/MainTab_Creation_LeftPane#PartScroll/MainTab_Creation_LeftPane_PartScroll#PartsVBox")
	preview_tex = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#PreviewTexture")
	_build_part_selection()
	_build_stat_inputs()
	_build_template_buttons()
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
	
	# Wire category selection
	var cat_select = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryTop/MainTab_Gallery_GalleryList_GalleryTop#CategorySelect")
	if cat_select:
		if cat_select.has_signal("item_selected"):
			if not cat_select.item_selected.is_connected(_on_category_selected):
				cat_select.item_selected.connect(_on_category_selected)

	# Wire graveyard clear button
	var clear_btn = get_node_or_null("./MainLayout/MainTab/MainTab#Graveyard/MainTab_Graveyard#GraveyardTop/MainTab_Graveyard_GraveyardTop#GraveyardClearBtn")
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
	var name_input = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#NameInput")
	var cat_input = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#CategoryInput")
	var status = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#StatusLabel")
	if name_input == null:
		return
	var char_name: String = name_input.text.strip_edges()
	var category = ""
	if cat_input:
		category = cat_input.text.strip_edges()

	# Use selected parts (live from UI)
	var body_parts = selected_parts.duplicate()

	# Read stats from UI
	var stats = {}
	if stat_inputs.is_empty():
		# Fallback
		stats = {"gold":5,"agility":5,"strength":5,"intelligence":5,"constitution":5,"luck":5}
	else:
		for k in stat_inputs:
			stats[k] = int(stat_inputs[k].value)

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


func _on_category_selected(_index: int) -> void:
	_refresh_gallery()

func _refresh_gallery() -> void:
	# Target the inner GridContainer (GalleryVBox) inside the ScrollContainer (GalleryGrid)
	var gallery_container = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryGrid/MainTab_Gallery_GalleryList_GalleryGrid#GalleryVBox")
	
	var category_select = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryTop/MainTab_Gallery_GalleryList_GalleryTop#CategorySelect")
	var slot_label = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryTop/MainTab_Gallery_GalleryList_GalleryTop#SlotCounter")
	if not gallery_container or not category_select or not slot_label:
		return
		
	# Ensure grid columns 
	if gallery_container is GridContainer:
		gallery_container.columns = 4
		
	# Build categories
	var chars = CharacterManager.get_all_characters()
	var categories = {"All": []}
	for c in chars:
		var cat = c.get("category", "")
		if cat == "": cat = "Uncategorized"
		if not categories.has(cat): categories[cat] = []
		categories[cat].append(c)
	categories["All"] = chars

	# Populate category select (only if empty or we want to refresh categories, 
	# but we must preserve selection if possible)
	var current_cat_idx = category_select.get_selected_id() # ID is actually index in OptionButton usually
	if current_cat_idx < 0: current_cat_idx = 0
	var current_cat_name = ""
	if category_select.item_count > 0:
		current_cat_name = category_select.get_item_text(current_cat_idx)
	
	# Re-populate if counts differ or force refresh. Simple approach: Valid categories might change.
	# We'll just clear and rebuild, trying to restore selection.
	category_select.clear()
	var cat_keys = categories.keys()
	cat_keys.sort()
	# Ensure "All" is first or specific order? "All" usually first.
	cat_keys.erase("All")
	cat_keys.insert(0, "All")
	
	for i in range(cat_keys.size()):
		category_select.add_item(cat_keys[i], i)
		if cat_keys[i] == current_cat_name:
			category_select.select(i)
	
	if category_select.get_selected_id() < 0:
		category_select.select(0) # Default to All

	# Update slot counter
	var used = CharacterManager.get_active_character_count()
	var owned = UserManager.get_character_slots_owned()
	slot_label.text = "%d of %d slots used" % [used, owned]

	# Get chars for current selection
	var sel_idx = category_select.get_selected_id()
	if sel_idx < 0: sel_idx = 0
	var sel_cat = category_select.get_item_text(sel_idx)
	var display_chars = categories.get(sel_cat, [])

	# Clear grid
	for c in gallery_container.get_children():
		c.queue_free()

	# Add cards
	for c in display_chars:
		var cid = c.get("id", "")
		# Use PanelContainer for card to avoid nested button issues
		var card := PanelContainer.new()
		card.name = "char_card_%s" % cid
		card.custom_minimum_size = Vector2(160, 190)
		card.focus_mode = Control.FOCUS_ALL
		
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
		
		# Category badge
		var cat_text = c.get("category", "")
		if cat_text == "": cat_text = "Uncategorized"
		var badge := Label.new()
		badge.text = cat_text
		badge.add_theme_color_override("font_color", Color(0.85,0.6,0.15))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(badge)
		
		# Buttons Row
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		var btn_exp := Button.new()
		btn_exp.text = "Exp"
		btn_exp.tooltip_text = "Export JSON"
		btn_exp.focus_mode = Control.FOCUS_ALL
		btn_exp.mouse_filter = Control.MOUSE_FILTER_STOP # Ensure clickable
		btn_exp.pressed.connect(func():
			var path = CharacterManager.export_character(cid)
			if path != "": DialogManager.show_toast("Exported: " + path)
			)
			
		var btn_del := Button.new()
		btn_del.text = "Del"
		btn_del.tooltip_text = "Delete"
		btn_del.modulate = Color(1,0.5,0.5)
		btn_del.focus_mode = Control.FOCUS_ALL
		btn_del.mouse_filter = Control.MOUSE_FILTER_STOP
		btn_del.pressed.connect(func():
			DialogManager.show_confirm("Delete?", "Delete %s?" % c.get("name", ""), func(yes):
				if yes:
					CharacterManager.soft_delete_character(cid)
					_refresh_gallery()
				)
			)
			
		actions.add_child(btn_exp)
		actions.add_child(btn_del)
		vbox.add_child(actions)
		
		card.add_child(vbox)
		
		# Tooltip
		var stats = c.get("stats", {})
		var tip = ""
		for k in stats:
			tip += "%s: %s\n" % [k.capitalize(), str(stats[k])]
		tip += "\nShortcuts: Enter=View, Delete=Delete"
		card.tooltip_text = tip

		# Handle Card Click (Selection) via gui_input
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_character_selected(cid)
				card.grab_focus()
			)
			
		# Focus visuals
		card.focus_entered.connect(func() -> void:
			card.modulate = Color(0.95, 1.0, 0.95, 1.0)
			# Visual indication of focus
			)
		card.focus_exited.connect(func() -> void:
			card.modulate = Color(1, 1, 1, 1)
			)
			
		gallery_container.add_child(card)

	# Add New Character and Purchase buttons
	var btn_row := HBoxContainer.new()
	var new_btn := Button.new()
	new_btn.text = "New Character"
	new_btn.focus_mode = Control.FOCUS_ALL
	new_btn.pressed.connect(func() -> void:
		var tb := get_node_or_null("./MainLayout/MainTab")
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

	gallery_container.add_child(btn_row)


# --- Part Selection UI ---
var PART_TYPES: Array = ["head","eyes","mouth","hair","body","arms","hands","legs","feet"]
var parts_vbox: VBoxContainer = null
var preview_tex: TextureRect = null
var selected_parts: Dictionary = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
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

func _build_stat_inputs() -> void:
	var parent = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane")
	if not parent: return

	# Create container if not exists
	var container = parent.get_node_or_null("StatsGrid")
	if not container:
		container = GridContainer.new()
		container.name = "StatsGrid"
		container.columns = 2
		# Insert before button if possible? We'll just add child for now.
		parent.add_child(container)
		# Try to move create button to end if we can find it
		var btn = parent.get_node_or_null("CreateBtn")
		if btn:
			parent.move_child(btn, -1)
			
	for c in container.get_children():
		c.queue_free()
		
	var stat_names = ["gold", "agility", "strength", "intelligence", "constitution", "luck"]
	stat_inputs.clear()
	
	for s in stat_names:
		var lbl = Label.new()
		lbl.text = s.capitalize()
		container.add_child(lbl)
		
		var sb = SpinBox.new()
		sb.min_value = 1
		sb.max_value = 99
		sb.value = 5 # Default
		container.add_child(sb)
		stat_inputs[s] = sb

func _build_template_buttons() -> void:
	var parent = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane")
	if not parent: return

	var container = parent.get_node_or_null("TemplatesRow")
	if not container:
		container = HBoxContainer.new()
		container.name = "TemplatesRow"
		parent.add_child(container)
		parent.move_child(container, 0) # Top

	for c in container.get_children():
		c.queue_free()

	for tmpl in templates:
		var btn = Button.new()
		btn.text = tmpl.get("name", "Template")
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(func(): _apply_template(tmpl))
		container.add_child(btn)

func _apply_template(tmpl: Dictionary) -> void:
	var parts = tmpl.get("body_parts", {})
	for t in parts:
		if selected_parts.has(t):
			selected_parts[t] = parts[t]
	_update_preview()

	var stats = tmpl.get("suggested_stats", {})
	for s in stats:
		if stat_inputs.has(s):
			stat_inputs[s].value = stats[s]

	DialogManager.show_toast("Applied template: %s" % tmpl.get("name", ""))

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
	var gv = get_node_or_null("./MainLayout/MainTab/MainTab#Graveyard/MainTab_Graveyard#GraveyardScroll/MainTab_Graveyard_GraveyardScroll#GraveyardVBox")
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
			var tb = get_node_or_null("./MainLayout/MainTab")
			if tb:
				tb.current_tab = 0
				DialogManager.show_toast("New Character (N)")
		# Delete focused character with Delete key
		elif event.keycode == Key.KEY_DELETE:
			var focused = UIHelpers.get_focus_owner()
			var target = focused
			# Fallback: find focused-like child in gallery if global focus not available
			if target == null:
				var grid = get_node_or_null("./MainLayout/MainTab/Gallery/GalleryList/GalleryGrid/GalleryVBox")
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
			var grid = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryGrid/MainTab_Gallery_GalleryList_GalleryGrid#GalleryVBox")
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
	selected_character_id = char_id
	# Safe-get details widgets
	var details_preview = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#Details/MainTab_Gallery_Details#DetailsPreview")
	var details_grid = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#Details/MainTab_Gallery_Details#InventoryGrid")
	if details_preview and details_grid:
		DialogManager.show_toast("Selected %s" % CharacterManager.get_character(char_id).get("name", ""))
	var c = CharacterManager.get_character(char_id)
	var body = c.get("body_parts", {})
	if details_preview:
		details_preview.texture = CharacterRenderer.render_character(body)
		# Build inventory grid
		_refresh_character_inventory(char_id)
		# Show slot usage header on details
		var slot_info = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryTop/MainTab_Gallery_GalleryList_GalleryTop#SlotCounter")
		if slot_info:
			var used = CharacterManager.get_character_inventory_count(char_id)
			slot_info.text = "%d items in character inventory" % used
	# Also refresh graveyard view to keep UI in sync
	_refresh_graveyard()

func _refresh_character_inventory(char_id: String) -> void:
	var grid = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#Details/MainTab_Gallery_Details#InventoryGrid")
	if not grid: return
	# Clear
	for ch in grid.get_children():
		ch.queue_free()
	# Ensure container exists
	InventoryManager.create_container(char_id, CharacterManager.get_character(char_id).get("inventory_capacity", 10))
	var slots = InventoryManager.get_container_slots(char_id)
	for i in range(slots.size()):
		var panel = load("res://apps/character_creator/character_container_slot.tscn").instantiate()
		grid.add_child(panel)
		# Delay setup so nodes actially exist or use call_deferred if setup relies on onready vars.
		# Ideally setup should just set data and _ready uses it, or we access nodes via get_node checking.
		# Assuming setup() accesses onready vars, we must wait? No, onready vars are init when entering tree.
		# Since we added child, they should be ready by next frame or immediately? 
		# In Godot 4, add_child triggers _enter_tree and _ready immediately.
		if panel.has_method("setup"):
			panel.setup(char_id, i, slots[i])

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
	
	# Validate stats
	for s in stats:
		var val = stats[s]
		if val < 1 or val > 99:
			return {"ok": false, "error": "Stat %s must be between 1 and 99" % s}

	var success = CharacterManager.create_character(char_name, category, body_parts, stats)
	if not success:
		return {"ok": false, "error": "Failed to create character."}
	# Refresh gallery after creation
	call_deferred("_refresh_gallery")
	return {"ok": true}
