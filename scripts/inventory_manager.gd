extends Node

signal inventory_changed
signal inventory_full
signal auto_sort_changed(enabled: bool)
signal container_inventory_changed(container_id: String)

# Slot structure: { "id": "item_id", "count": int } or null
var slots: Array = [] 
var containers: Dictionary = {} # character_id -> Array[slots]
var auto_sort_enabled: bool = false
var sort_criteria: String = "name" # name, count, type

func _ready() -> void:
	var core: Node = get_tree().root.get_node_or_null("/root/CoreRuntime")
	if core != null:
		core.register_service("InventoryManager")
	
	# Listen to capacity changes
	UserManager.capacity_changed.connect(_on_capacity_changed)
	
	# Initial Load
	call_deferred("_load_from_save")

func _load_from_save() -> void:
	var data = SaveManager.load_global()
	
	# Load Meta
	var meta = data.get("inventory_meta", {})
	auto_sort_enabled = meta.get("auto_sort", false)
	sort_criteria = meta.get("sort_criteria", "name")
	
	# Load Global Slots
	var saved_slots = data.get("inventory_slots", [])
	var max_s = UserManager.get_max_slots()
	
	slots.resize(max_s)
	for i in range(max_s):
		if i < saved_slots.size():
			slots[i] = saved_slots[i]
		else:
			slots[i] = null
			
	# Load Containers
	containers = data.get("character_containers", {})
			
	inventory_changed.emit()
	auto_sort_changed.emit(auto_sort_enabled)

func _on_capacity_changed(new_size: int) -> void:
	slots.resize(new_size)
	inventory_changed.emit()
	_persist()

# --- Public API ---

func get_slots() -> Array:
	return slots

func add_item(item_id: String, amount: int = 1) -> bool:
	# 1. Try to stack
	if ItemRegistry.get_item(item_id).get("stackable", true):
		for i in range(slots.size()):
			var s = slots[i]
			if s != null and s["id"] == item_id:
				# Check max stack? Assume 99 or infinite for now
				s["count"] += amount
				_on_inventory_modified()
				return true
	
	# 2. Find empty slot
	for i in range(slots.size()):
		if slots[i] == null:
			slots[i] = { "id": item_id, "count": amount }
			_on_inventory_modified()
			return true
			
	inventory_full.emit()
	return false

func remove_item(item_id: String, amount: int = 1) -> bool:
	var remaining = amount
	
	for i in range(slots.size()):
		var s = slots[i]
		if s != null and s["id"] == item_id:
			if s["count"] > remaining:
				s["count"] -= amount
				remaining = 0
				_on_inventory_modified()
				return true
			else:
				remaining -= s["count"]
				slots[i] = null
				if remaining <= 0:
					_on_inventory_modified()
					return true
					
	return remaining == 0 

func has_item(item_id: String) -> bool:
	for s in slots:
		if s != null and s["id"] == item_id:
			return true
	return false

# --- Container API ---

func create_container(container_id: String, capacity: int = 10) -> void:
	if not containers.has(container_id):
		var new_slots = []
		new_slots.resize(capacity)
		for i in range(capacity):
			new_slots[i] = null
		containers[container_id] = new_slots
		_persist()

func delete_container(container_id: String) -> void:
	if containers.erase(container_id):
		_persist()

func get_container_slots(container_id: String) -> Array:
	return containers.get(container_id, [])

func add_to_container(container_id: String, item_id: String, amount: int = 1, validate_bound: bool = true) -> bool:
	if not containers.has(container_id):
		return false
		
	var c_slots: Array = containers[container_id]
	
	# Check bound
	if validate_bound:
		var item_data = ItemRegistry.get_item(item_id)
		if item_data.get("bound_to_character", false):
			# Bound items cannot be added to character containers
			return false

	# 1. Try to stack
	if ItemRegistry.get_item(item_id).get("stackable", true):
		for i in range(c_slots.size()):
			var s = c_slots[i]
			if s != null and s["id"] == item_id:
				s["count"] += amount
				container_inventory_changed.emit(container_id)
				_persist()
				return true

	# 2. Find empty slot
	for i in range(c_slots.size()):
		if c_slots[i] == null:
			c_slots[i] = { "id": item_id, "count": amount }
			container_inventory_changed.emit(container_id)
			_persist()
			return true

	return false

func remove_from_container(container_id: String, item_id: String, amount: int = 1) -> bool:
	if not containers.has(container_id):
		return false
		
	var c_slots: Array = containers[container_id]
	var remaining = amount
	
	for i in range(c_slots.size()):
		var s = c_slots[i]
		if s != null and s["id"] == item_id:
			if s["count"] > remaining:
				s["count"] -= amount
				remaining = 0
				container_inventory_changed.emit(container_id)
				_persist()
				return true
			else:
				remaining -= s["count"]
				c_slots[i] = null
				if remaining <= 0:
					container_inventory_changed.emit(container_id)
					_persist()
					return true
					
	return remaining == 0

func swap_container_slots(container_id: String, from_idx: int, to_idx: int) -> void:
	if not containers.has(container_id):
		return
		
	var c_slots: Array = containers[container_id]
	if from_idx < 0 or from_idx >= c_slots.size() or to_idx < 0 or to_idx >= c_slots.size():
		return
		
	var temp = c_slots[from_idx]
	c_slots[from_idx] = c_slots[to_idx]
	c_slots[to_idx] = temp
	
	container_inventory_changed.emit(container_id)
	_persist()


func count_item(item_id: String) -> int:
	var total = 0
	for s in slots:
		if s != null and s["id"] == item_id:
			total += s["count"]
	return total

func swap_slots(idx_a: int, idx_b: int) -> void:
	if idx_a < 0 or idx_a >= slots.size() or idx_b < 0 or idx_b >= slots.size():
		return
		
	var temp = slots[idx_a]
	slots[idx_a] = slots[idx_b]
	slots[idx_b] = temp
	
	if auto_sort_enabled:
		set_auto_sort(false)
		
	_on_inventory_modified(false) # Don't sort again

func set_auto_sort(enabled: bool) -> void:
	auto_sort_enabled = enabled
	auto_sort_changed.emit(enabled)
	if enabled:
		sort_items()
	_persist()

func set_sort_criteria(criteria: String) -> void:
	sort_criteria = criteria
	_persist()
	if auto_sort_enabled:
		sort_items()

func sort_items() -> void:
	# Logic to sort 'slots' array compacting nulls to the end
	var existing_items = []
	for s in slots:
		if s != null:
			existing_items.append(s)
			
	existing_items.sort_custom(_sort_func)
	
	# Rebuild slots
	for i in range(slots.size()):
		if i < existing_items.size():
			slots[i] = existing_items[i]
		else:
			slots[i] = null
			
	inventory_changed.emit()
	_persist()

func _sort_func(a, b) -> bool:
	# return true if a < b
	var id_a = a["id"]
	var id_b = b["id"]
	var meta_a = ItemRegistry.get_item(id_a)
	var meta_b = ItemRegistry.get_item(id_b)
	
	if sort_criteria == "name":
		return meta_a.get("name", id_a) < meta_b.get("name", id_b)
	elif sort_criteria == "count":
		return a["count"] > b["count"] # Higher count first
	elif sort_criteria == "type":
		return meta_a.get("category", "") < meta_b.get("category", "")
	return false

func _on_inventory_modified(trigger_sort: bool = true) -> void:
	if auto_sort_enabled and trigger_sort:
		sort_items()
	else:
		inventory_changed.emit()
		_persist()

func _persist() -> void:
	var data = SaveManager.load_global()
	data["inventory_slots"] = slots
	data["character_containers"] = containers
	data["inventory_meta"] = {
		"auto_sort": auto_sort_enabled,
		"sort_criteria": sort_criteria
	}
	SaveManager.save_global(data)
