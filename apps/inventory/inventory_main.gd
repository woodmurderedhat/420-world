extends "res://scripts/app_base.gd"

# inventory_main.gd - App Controller

@onready var view = $Content/View
@onready var currency_lbl = $Content/Footer/CurrencyLabel
@onready var auto_sort_btn = $Content/Footer/AutoSortCheck
@onready var sort_opt = $Content/Footer/SortOption

func _ready() -> void:

	
	# Connect to InventoryManager
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	InventoryManager.inventory_full.connect(_on_inventory_full)
	InventoryManager.auto_sort_changed.connect(_on_auto_sort_changed)
	UserManager.currency_changed.connect(_on_currency_changed)
	
	# Connect UI signals
	auto_sort_btn.toggled.connect(_on_auto_sort_toggled)
	sort_opt.item_selected.connect(_on_sort_criteria_selected)
	
	# Initial UI Sync
	view.refresh()
	_on_currency_changed(UserManager.get_currency())
	_on_auto_sort_changed(InventoryManager.auto_sort_enabled)

func _on_inventory_changed() -> void:
	view.refresh()

func _on_inventory_full() -> void:
	DialogManager.show_toast("Inventory is full!")

func _on_currency_changed(amount: int) -> void:
	currency_lbl.text = "Currency: %d" % amount

func _on_auto_sort_changed(enabled: bool) -> void:
	auto_sort_btn.set_pressed_no_signal(enabled)

func _on_auto_sort_toggled(toggled_on: bool) -> void:
	InventoryManager.set_auto_sort(toggled_on)

func _on_sort_criteria_selected(index: int) -> void:
	var criteria = SortOption_get_text(index).to_lower()
	InventoryManager.set_sort_criteria(criteria)

# Helper to get text from OptionButton index since we can't rely on item text direct access safety in Godot 4 sometimes
func SortOption_get_text(index: int) -> String:
	return sort_opt.get_item_text(index)
