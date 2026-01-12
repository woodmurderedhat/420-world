extends Node

func build(details_preview_node: Node, inventory_grid_node: Node) -> void:
	self.details_preview = details_preview_node
	self.inventory_grid = inventory_grid_node

func show_character(char_id: String) -> void:
	if not self.details_preview: return
	var c = CharacterManager.get_character(char_id)
	var body = c.get("body_parts", {})
	self.details_preview.texture = CharacterRenderer.render_character(body)
	_refresh_character_inventory(char_id)

func _refresh_character_inventory(char_id: String) -> void:
	if not self.inventory_grid: return
	for ch in self.inventory_grid.get_children():
		ch.queue_free()
	InventoryManager.create_container(char_id, CharacterManager.get_character(char_id).get("inventory_capacity", 10))
	var slots = InventoryManager.get_container_slots(char_id)
	for i in range(slots.size()):
		var panel = load("res://apps/character_creator/components/container_slot/character_container_slot.tscn").instantiate()
		self.inventory_grid.add_child(panel)
		if panel.has_method("setup"):
			panel.setup(char_id, i, slots[i])