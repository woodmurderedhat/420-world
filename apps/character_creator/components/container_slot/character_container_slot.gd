extends PanelContainer

var container_id: String = ""
var slot_index: int = -1
var item_id: String = ""

@onready var icon_rect = $Icon
@onready var amount_lbl = $Amount

func setup(_container_id: String, idx: int, data) -> void:
	container_id = _container_id
	slot_index = idx
	if data == null:
		item_id = ""
		icon_rect.texture = preload("res://assets/icons/default_app.svg")
		icon_rect.modulate = Color(1,1,1,0.2)
		amount_lbl.text = "" 		
		tooltip_text = "Empty Slot"
	else:
		item_id = data["id"]
		var count = data["count"]
		icon_rect.texture = ItemRegistry.get_item_icon(item_id)
		icon_rect.modulate = Color(1,1,1,1)
		amount_lbl.text = str(count) if count > 1 else ""
		tooltip_text = "%s\n%s" % [ItemRegistry.get_item_name(item_id), ItemRegistry.get_item_description(item_id)]

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id == "":
		return null
	var preview = TextureRect.new()
	preview.texture = icon_rect.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(40,40)
	set_drag_preview(preview)
	return { "container_id": container_id, "index": slot_index, "source": "container" }

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary): return false
	var src = data.get("source", "")
	# Accept drops from player inventory or other containers
	return src == "inventory" or src == "container"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var src = data.get("source", "")
	if src == "inventory":
		var from_index = data.get("index", -1)
		if from_index < 0: return
		var s = InventoryManager.get_slots()[from_index]
		if s == null: return
		# Attempt to add one to container
		if InventoryManager.add_to_container(container_id, s["id"], 1, true):
			InventoryManager.remove_item(s["id"], 1)
		else:
			DialogManager.show_alert("Cannot add", "Item cannot be placed into container.")
		return
	elif src == "container":
		var from_cid = data.get("container_id", "")
		var from_idx = data.get("index", -1)
		if from_cid == "" or from_idx < 0: return
		# Swap items between containers if same size
		var c_slots = InventoryManager.get_container_slots(from_cid)
		var target_slots = InventoryManager.get_container_slots(container_id)
		if from_idx >= c_slots.size() or slot_index >= target_slots.size(): return
		var a = c_slots[from_idx]
		var b = target_slots[slot_index]
		# Simple swap
		c_slots[from_idx] = b
		target_slots[slot_index] = a
		InventoryManager.container_inventory_changed.emit(from_cid)
		InventoryManager.container_inventory_changed.emit(container_id)
		InventoryManager._persist()
		return

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_show_context_menu()

func _show_context_menu() -> void:
	var menu = PopupMenu.new()
	if item_id != "":
		menu.add_item("Remove", 1)
		menu.id_pressed.connect(func(id):
			if id == 1:
				InventoryManager.remove_from_container(container_id, item_id, 1)
				InventoryManager.container_inventory_changed.emit(container_id)
			)
	add_child(menu)
	menu.popup(Rect2(get_global_mouse_position(), Vector2.ZERO))