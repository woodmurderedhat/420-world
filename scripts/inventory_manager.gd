extends Node

signal inventory_changed

var items: Dictionary = {} # id -> count

func _ready() -> void:
	var core := get_tree().root.get_node_or_null("/root/CoreRuntime")
	if core != null:
		core.register_service("InventoryManager")
	_load_from_save()

func add_item(item_id: String, amount: int = 1) -> void:
	items[item_id] = int(items.get(item_id, 0)) + amount
	_emit_and_persist()

func remove_item(item_id: String, amount: int = 1) -> bool:
	var cur := int(items.get(item_id, 0))
	if cur < amount:
		return false
	cur -= amount
	if cur <= 0:
		items.erase(item_id)
	else:
		items[item_id] = cur
	_emit_and_persist()
	return true

func has_item(item_id: String) -> bool:
	return items.has(item_id)

func _emit_and_persist() -> void:
	emit_signal("inventory_changed")
	_persist()

func _load_from_save() -> void:
	var sm := get_tree().root.get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	var data: Dictionary = sm.load_global()
	var inv: Variant = data.get("inventory", {})
	if typeof(inv) == TYPE_DICTIONARY:
		items = inv.duplicate(true)

func _persist() -> void:
	var sm := get_tree().root.get_node_or_null("/root/SaveManager")
	if sm == null:
		return
	var data: Dictionary = sm.load_global()
	data["inventory"] = items.duplicate(true)
	sm.save_global(data)
