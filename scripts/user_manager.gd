extends Node

signal stats_changed
signal currency_changed(new_amount: int)
signal capacity_changed(new_capacity: int)

# Core persistent data
var data: Dictionary = {
	"currency": 0,
	"max_slots": 20,
	"level": 1,
	"experience": 0,
	"character_slots_owned": 4
}

func _ready() -> void:
	Log.info("UserManager initialized")
	call_deferred("_load_initial_state")

func _load_initial_state() -> void:
	var global = SaveManager.load_global()
	if global.has("user_data"):
		load_save_data(global["user_data"])
	else:
		_notify_save()

# --- Getters ---

func get_currency() -> int:
	return data.get("currency", 0)

func get_character_slots_owned() -> int:
	return data.get("character_slots_owned", 4)

func add_character_slots(amount: int) -> void:
	data["character_slots_owned"] = get_character_slots_owned() + amount
	_notify_save()

func get_max_slots() -> int:
	return data.get("max_slots", 20)

func get_level() -> int:
	return data.get("level", 1)

# --- Modifiers ---

func add_currency(amount: int) -> void:
	data.currency = get_currency() + amount
	currency_changed.emit(data.currency)
	_notify_save()

func remove_currency(amount: int) -> bool:
	if get_currency() >= amount:
		data.currency -= amount
		currency_changed.emit(data.currency)
		_notify_save()
		return true
	return false

func set_max_slots(slots: int) -> void:
	data.max_slots = slots
	capacity_changed.emit(slots)
	_notify_save()

# --- Persistence Interface ---

func get_save_data() -> Dictionary:
	return data.duplicate()

func load_save_data(loaded_data: Dictionary) -> void:
	# Merge loaded data with defaults to ensure missing keys don't crash
	for key in data.keys():
		if loaded_data.has(key):
			data[key] = loaded_data[key]
	
	# Emit updates to sync UI
	currency_changed.emit(data.currency)
	capacity_changed.emit(data.max_slots)
	stats_changed.emit()

func _notify_save() -> void:
	var global = SaveManager.load_global()
	global["user_data"] = get_save_data()
	SaveManager.save_global(global)
