extends Control

# inventory_view.gd - Handles the Grid and Tabs

@export var slot_scene: PackedScene

@onready var tab_container = $TabContainer

# Category mapping
const TABS = {
	"All": "",
	"Resources": "resource",
	"Consumables": "consumable",
	"Equipment": "equipment"
}

func _ready() -> void:
	# Ensure tab structure exists or create dynamically if possible
	# For now assume Scene structure: TabContainer -> specific tabs
	pass

func refresh() -> void:
	var slots = InventoryManager.get_slots()
	
	# Loop through each tab's grid and update
	# This implies we have a way to find the GridContainer for each tab
	# Let's assume children of TabContainer are ScrollContainers -> GridContainers
	
	for i in range(tab_container.get_child_count()):
		var tab = tab_container.get_child(i)
		var category_filter = _get_category_for_tab(tab.name)
		var grid = _get_grid_from_tab(tab)
		
		if grid:
			_update_grid(grid, slots, category_filter)

func _get_category_for_tab(tab_name: String) -> String:
	return TABS.get(tab_name, "")

func _get_grid_from_tab(tab: Node) -> Control:
	# Expecting ScrollContainer -> GridContainer
	if tab is ScrollContainer:
		for c in tab.get_children():
			if c is GridContainer:
				return c
	return null

func _update_grid(grid: Control, slots: Array, category: String) -> void:
	# Clear existing or object pool?
	# For simplicity, clear and rebuild. Optimisation later.
	for c in grid.get_children():
		c.queue_free()
		
	for i in range(slots.size()):
		var slot_data = slots[i]
		
		# Filter check
		if category != "":
			if slot_data == null:
				continue # Don't show empty slots in categorized tabs? Or do we?
				# Usually categorized tabs only show items matching.
			else:
				var item_def = ItemRegistry.get_item(slot_data["id"])
				if item_def.get("category", "") != category:
					continue
		
		var slot_ui = slot_scene.instantiate()
		grid.add_child(slot_ui)
		slot_ui.setup(i, slot_data) # Pass index and data
