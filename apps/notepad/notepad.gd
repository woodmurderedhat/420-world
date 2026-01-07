extends AppBase

@onready var text_area: TextEdit = $VBox/TextArea
@onready var status_label: Label = $VBox/Status
@onready var save_button: Button = $VBox/Actions/SaveButton
@onready var clear_button: Button = $VBox/Actions/ClearButton


func _ready() -> void:
	save_button.pressed.connect(_save_now)
	clear_button.pressed.connect(_clear_text)
	_update_status("Loaded")


func save_state() -> Dictionary:
	return {
		"text": text_area.text,
	}


func load_state(data: Dictionary) -> void:
	text_area.text = String(data.get("text", ""))
	_update_status("Restored")


func _save_now() -> void:
	_flush_to_disk()
	_update_status("Saved")


func _clear_text() -> void:
	text_area.text = ""
	_flush_to_disk()
	_update_status("Cleared")


func _flush_to_disk() -> void:
	var sm := get_tree().root.get_node_or_null("/root/SaveManager")
	if sm != null and metadata.has("id"):
		sm.save_app(String(metadata["id"]), {"state": save_state()})


func _update_status(text: String) -> void:
	status_label.text = text
