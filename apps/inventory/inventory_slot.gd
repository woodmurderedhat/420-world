extends PanelContainer

# inventory_slot.gd

var slot_index: int = -1
var item_id: String = ""

@onready var icon_rect = $Icon
@onready var amount_lbl = $Amount

func setup(idx: int, data) -> void:
	slot_index = idx
	
	if data == null:
		item_id = ""
		# Ghost slot styling
		icon_rect.texture = preload("res://assets/icons/default_app.svg")
		icon_rect.modulate = Color(1, 1, 1, 0.2)
		amount_lbl.text = ""
		tooltip_text = "Empty Slot"
	else:
		item_id = data["id"]
		var count = data["count"]
		var item_def = ItemRegistry.get_item(item_id)
		
		icon_rect.texture = ItemRegistry.get_item_icon(item_id)
		icon_rect.modulate = Color(1, 1, 1, 1)
		amount_lbl.text = str(count) if count > 1 else ""
		tooltip_text = "%s\n%s" % [item_def.get("name", "Unknown"), item_def.get("description", "")]

func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id == "":
		return null
		
	var preview = TextureRect.new()
	preview.texture = icon_rect.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(40, 40)
	set_drag_preview(preview)
	
	return { "index": slot_index, "source": "inventory" }

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Accept drags from inventory or character containers
	if not (data is Dictionary):
		return false
	var src = data.get("source", "")
	return src == "inventory" or src == "container"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var src = data.get("source", "")
	if src == "inventory":
		var from_index = data["index"]
		InventoryManager.swap_slots(from_index, slot_index)
		return
	elif src == "container":
		# Move one item from container to inventory
		var container_id = data.get("container_id", "")
		var from_idx = data.get("index", -1)
		if container_id == "" or from_idx < 0:
			return
		var c_slots = InventoryManager.get_container_slots(container_id)
		if from_idx >= c_slots.size(): return
		var s = c_slots[from_idx]
		if s == null: return
		# Attempt to add one to inventory
		if InventoryManager.add_item(s["id"], 1):
			InventoryManager.remove_from_container(container_id, s["id"], 1)
		else:
			# Inventory full — do nothing or notify
			DialogManager.show_alert("Inventory Full", "Cannot move item to inventory. No space available.")
		return

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_show_context_menu()

func _show_context_menu() -> void:
	var menu = PopupMenu.new()
	menu.add_item("Sort Items", 100)
	
	if item_id != "":
		menu.add_separator()
		
		# Custom Actions
		var item_def = ItemRegistry.get_item(item_id)
		var actions = item_def.get("actions", [])
		# actions format: [{"label": "Drink", "event": "drink_potion"}]
		
		# We start IDs from 1000 to avoid conflict
		for i in range(actions.size()):
			var action = actions[i]
			menu.add_item(action.get("label", "Use"), 1000 + i)
			
		menu.add_separator()
		menu.add_item("Discard", 2)
	
	menu.id_pressed.connect(_on_menu_action)
	add_child(menu)
	menu.popup(Rect2(get_global_mouse_position(), Vector2.ZERO))

func _on_menu_action(id: int) -> void:
	match id:
		100:
			InventoryManager.set_auto_sort(true)
		2:
			DialogManager.show_confirm("Discard Item?", "Are you sure you want to discard this item?", func(confirmed):
				if confirmed:
					InventoryManager.remove_item(item_id, 9999) # Remove all
			)
		_:
			if id >= 1000:
				var idx = id - 1000
				var item_def = ItemRegistry.get_item(item_id)
				var actions = item_def.get("actions", [])
				if idx < actions.size():
					var action = actions[idx]
					EventBus.emit_event("item_action", {
						"id": item_id,
						"slot": slot_index,
						"action": action.get("event", "use"),
						"label": action.get("label", "Use")
					}) 
