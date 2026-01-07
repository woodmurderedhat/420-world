extends AppBase

@onready var input: LineEdit = $VBox/AddRow/Input
@onready var add_button: Button = $VBox/AddRow/AddButton
@onready var items_box: VBoxContainer = $VBox/List/ItemsBox
@onready var status_label: Label = $VBox/Status
@onready var clear_done_button: Button = $VBox/Actions/ClearDone
@onready var clear_all_button: Button = $VBox/Actions/ClearAll

var _items: Array = []  # Array[Dictionary]


func _ready() -> void:
	add_button.pressed.connect(_on_add)
	input.text_submitted.connect(func(_text): _on_add())
	clear_done_button.pressed.connect(_clear_completed)
	clear_all_button.pressed.connect(_clear_all)
	_update_status()


func save_state() -> Dictionary:
	return {"items": _items}


func load_state(data: Dictionary) -> void:
	_clear_all_rows()
	_items.clear()
	var items_in: Array = data.get("items", [])
	for it in items_in:
		if typeof(it) == TYPE_DICTIONARY:
			var item := {
				"text": String(it.get("text", "")),
				"done": bool(it.get("done", false)),
			}
			_items.append(item)
			_add_row(item)
	_update_status()


func _on_add() -> void:
	var txt := input.text.strip_edges()
	if txt == "":
		return
	var item := {"text": txt, "done": false}
	_items.append(item)
	_add_row(item)
	input.clear()
	_update_status()
	_flush()


func _add_row(item: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var box := CheckBox.new()
	box.text = item.get("text", "")
	box.button_pressed = item.get("done", false)
	box.toggled.connect(
		func(v: bool):
			item["done"] = v
			_update_status()
			_flush()
	)
	row.add_child(box)
	var del := Button.new()
	del.text = "X"
	del.focus_mode = Control.FOCUS_NONE
	del.pressed.connect(
		func():
			_items.erase(item)
			row.queue_free()
			_update_status()
			_flush()
	)
	row.add_child(del)
	items_box.add_child(row)


func _clear_completed() -> void:
	for child in items_box.get_children():
		if child is HBoxContainer:
			var cb := child.get_child(0)
			if cb is CheckBox and cb.button_pressed:
				child.queue_free()
	_items = _items.filter(func(it): return not bool(it.get("done", false)))
	_update_status()
	_flush()


func _clear_all() -> void:
	_clear_all_rows()
	_items.clear()
	_update_status()
	_flush()


func _clear_all_rows() -> void:
	for c in items_box.get_children():
		c.queue_free()


func _flush() -> void:
	var sm := get_tree().root.get_node_or_null("/root/SaveManager")
	if sm != null and metadata.has("id"):
		sm.save_app(String(metadata["id"]), {"state": save_state()})


func _update_status() -> void:
	var total := _items.size()
	var done := 0
	for it in _items:
		if bool(it.get("done", false)):
			done += 1
	status_label.text = "Tasks: %d (%d done)" % [total, done]
