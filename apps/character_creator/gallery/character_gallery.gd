extends Node

signal character_selected(char_id: String)
signal export_requested(char_id: String)
signal delete_requested(char_id: String)
signal new_requested()
signal purchase_requested()

var container: Node = null
var category_select: Node = null
var slot_label: Node = null

# Helpers for safe tooltip/show hide in headless tests
func _safe_show_tooltip(text: String, pos: Vector2) -> void:
	Log.info("CharacterGallery._safe_show_tooltip: invoked (text=%s, pos=%s, inside_tree=%s)" % [text, str(pos), str(is_inside_tree())])
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		Log.info("CharacterGallery._safe_show_tooltip: get_tree() returned null")
		return
	var root := tree.get_root()
	if root == null:
		Log.info("CharacterGallery._safe_show_tooltip: root null")
		return
	# Autoloads are available at /root/<Name> - use absolute node path to be robust
	var tm := get_node_or_null("/root/TooltipManager")
	Log.info("CharacterGallery._safe_show_tooltip: found tm=%s" % str(tm))
	if tm != null and tm.has_method("show_tooltip"):
		Log.info("CharacterGallery._safe_show_tooltip: calling show_tooltip")
		tm.call_deferred("show_tooltip", text, pos)

func _safe_hide_tooltip() -> void:
	Log.info("CharacterGallery._safe_hide_tooltip: invoked (inside_tree=%s)" % str(is_inside_tree()))
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		Log.info("CharacterGallery._safe_hide_tooltip: get_tree() returned null")
		return
	var root := tree.get_root()
	if root == null:
		Log.info("CharacterGallery._safe_hide_tooltip: root null")
		return
	# Autoloads are available at /root/<Name> - use absolute node path to be robust
	var tm := get_node_or_null("/root/TooltipManager")
	Log.info("CharacterGallery._safe_hide_tooltip: found tm=%s" % str(tm))
	if tm != null and tm.has_method("hide_tooltip"):
		Log.info("CharacterGallery._safe_hide_tooltip: calling hide_tooltip")
		tm.call_deferred("hide_tooltip")

func _on_card_pressed(cid: String, card: Button) -> void:
	emit_signal("character_selected", cid)
	card.grab_focus()

func build(gallery_container: Node, category_select_node: Node, slot_label_node: Node) -> void:
	container = gallery_container
	category_select = category_select_node
	slot_label = slot_label_node
	_attach_category_signal()
	refresh()

func _attach_category_signal() -> void:
	if category_select and category_select.has_signal("item_selected"):
		if not category_select.item_selected.is_connected(Callable(self, "_on_category_selected")):
			category_select.item_selected.connect(Callable(self, "_on_category_selected"))

func _on_category_selected(_index: int) -> void:
	refresh()

func refresh() -> void:
	if container == null or category_select == null or slot_label == null:
		Log.warn("CharacterGallery.refresh: missing UI nodes (container=%s, category_select=%s, slot_label=%s)" % [str(container), str(category_select), str(slot_label)])
		return

	# Diagnostics for headless tests: log resolved node paths
	Log.info("CharacterGallery.refresh: container=%s, category_select=%s, slot_label=%s" % [container.get_path(), category_select.get_path(), slot_label.get_path()])

	# Ensure grid columns
	if container is GridContainer:
		container.columns = 4

	# Build categories from central manifest
	var chars = CharacterManager.get_characters_manifest()
	Log.info("CharacterGallery: found %d characters" % chars.size())
	var categories = {"All": []}
	for c in chars:
		var cat = c.get("category", "")
		if cat == "": cat = "Uncategorized"
		if not categories.has(cat): categories[cat] = []
		categories[cat].append(c)
	categories["All"] = chars

	# Populate category select (preserve selection if possible)
	var current_cat_idx = category_select.get_selected_id()
	if current_cat_idx < 0: current_cat_idx = 0
	var current_cat_name = ""
	if category_select.item_count > 0:
		current_cat_name = category_select.get_item_text(current_cat_idx)

	category_select.clear()
	var cat_keys = categories.keys()
	cat_keys.sort()
	cat_keys.erase("All")
	cat_keys.insert(0, "All")
	for i in range(cat_keys.size()):
		category_select.add_item(cat_keys[i], i)
		if cat_keys[i] == current_cat_name:
			category_select.select(i)
	if category_select.get_selected_id() < 0:
		category_select.select(0)

	# Update slot counter
	var used = CharacterManager.get_active_character_count()
	var owned = UserManager.get_character_slots_owned()
	slot_label.text = "%d of %d slots used" % [used, owned]

	# Get chars for current selection
	var sel_idx = category_select.get_selected_id()
	if sel_idx < 0: sel_idx = 0
	var sel_cat = category_select.get_item_text(sel_idx)
	var display_chars = categories.get(sel_cat, [])

	# Clear grid safely (defer frees to avoid "object locked" errors in headless tests)
	var old_children = container.get_children()
	for c in old_children:
		if is_instance_valid(c):
			container.remove_child(c)
			c.call_deferred("free")

	# Add cards
	for c in display_chars:
		var cid = c.get("id", "")
		# Use Button as the card root to improve accessibility and match test expectations
		var card := Button.new()
		card.name = "char_card_%s" % cid
		card.custom_minimum_size = Vector2(160, 190)
		card.focus_mode = Control.FOCUS_ALL
		
		var vbox := VBoxContainer.new()
		vbox.anchor_right = 1.0
		vbox.anchor_bottom = 1.0
		var preview := TextureRect.new()
		preview.texture = CharacterRenderer.render_character(c.get("body_parts", {}))
		preview.custom_minimum_size = Vector2(64,64)
		preview.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		vbox.add_child(preview)
		var name_lbl := Label.new()
		name_lbl.text = c.get("name", "Unnamed")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)
		var cat_text = c.get("category", "")
		if cat_text == "": cat_text = "Uncategorized"
		var badge := Label.new()
		badge.text = cat_text
		badge.add_theme_color_override("font_color", Color(0.85,0.6,0.15))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(badge)

		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		var btn_exp := Button.new()
		btn_exp.text = "Exp"
		btn_exp.tooltip_text = "Export JSON"
		btn_exp.focus_mode = Control.FOCUS_ALL
		btn_exp.mouse_filter = Control.MOUSE_FILTER_STOP
		btn_exp.pressed.connect(func(): emit_signal("export_requested", cid))
		var btn_del := Button.new()
		btn_del.text = "Del"
		btn_del.tooltip_text = "Delete"
		btn_del.modulate = Color(1,0.5,0.5)
		btn_del.focus_mode = Control.FOCUS_ALL
		btn_del.mouse_filter = Control.MOUSE_FILTER_STOP
		btn_del.pressed.connect(func(): emit_signal("delete_requested", cid))
		actions.add_child(btn_exp)
		actions.add_child(btn_del)
		vbox.add_child(actions)
		card.add_child(vbox)

		var stats = c.get("stats", {})
		var tip = ""
		for k in stats:
			tip += "%s: %s\n" % [k.capitalize(), str(stats[k])]
		tip += "\nShortcuts: Enter=View, Delete=Delete"
		card.tooltip_text = tip

		# Tooltips (connect to global TooltipManager when available)
		# Use bound Callables so we avoid closure capture issues and ensure deterministic args
		card.mouse_entered.connect(Callable(self, "_safe_show_tooltip").bind(card.tooltip_text, card.get_global_position()))
		card.mouse_entered.connect(func(c=card): Log.info("inline mouse_entered: %s" % c.name))
		card.mouse_exited.connect(Callable(self, "_safe_hide_tooltip"))
		card.mouse_exited.connect(func(c=card): Log.info("inline mouse_exited: %s" % c.name))
		card.pressed.connect(Callable(self, "_on_card_pressed").bind(cid, card))
		card.pressed.connect(func(id=cid, c=card): Log.info("inline pressed: %s" % c.name))
		Log.info("CharacterGallery: connected callbacks for %s" % card.name)
		card.focus_entered.connect(func() -> void: card.modulate = Color(0.95, 1.0, 0.95, 1.0))
		card.focus_exited.connect(func() -> void: card.modulate = Color(1, 1, 1, 1))
		container.add_child(card)

	# Add New Character and Purchase buttons
	var btn_row := HBoxContainer.new()
	var new_btn := Button.new()
	new_btn.text = "New Character"
	new_btn.focus_mode = Control.FOCUS_ALL
	new_btn.pressed.connect(func(): emit_signal("new_requested"))
	btn_row.add_child(new_btn)
	if used >= owned:
		var purchase_btn := Button.new()
		purchase_btn.text = "Purchase Slot"
		purchase_btn.focus_mode = Control.FOCUS_ALL
		purchase_btn.pressed.connect(func(): emit_signal("purchase_requested"))
		btn_row.add_child(purchase_btn)
	container.add_child(btn_row)
	# Log final state for debugging headless tests
	Log.info("CharacterGallery.refresh: final child_count=%d" % container.get_child_count())

func _ready() -> void:
	# Auto-build when this script is attached to a scene that provides the expected child nodes
	var cat_select = get_node_or_null("GalleryTop/CategorySelect")
	if cat_select == null:
		cat_select = get_node_or_null("CategorySelect")
	var gallery_container = get_node_or_null("GalleryGrid/GalleryVBox")
	if gallery_container == null:
		gallery_container = get_node_or_null("GalleryVBox")
	var slot_label = get_node_or_null("GalleryTop/SlotCounter")
	if slot_label == null:
		slot_label = get_node_or_null("SlotCounter")
	if gallery_container != null and cat_select != null and slot_label != null:
		build(gallery_container, cat_select, slot_label)