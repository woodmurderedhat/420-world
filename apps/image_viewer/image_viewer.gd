extends "res://scripts/app_base.gd"

const IMAGES := {
	"Shell Icon": "res://icon.svg",
}

var _current_key: String = ""

@onready var selector: OptionButton = $MainLayout/Selector
@onready var preview: TextureRect = $MainLayout/Preview
@onready var status_label: Label = $MainLayout/Status


func _ready() -> void:
	selector.clear()
	var keys := IMAGES.keys()
	keys.sort()
	for item_name in keys:
		selector.add_item(String(item_name))
	selector.item_selected.connect(_on_selection)
	if selector.item_count > 0:
		selector.select(0)
		_apply_selection(selector.get_item_text(0))


func save_state() -> Dictionary:
	return {"selected": _current_key}


func load_state(data: Dictionary) -> void:
	var desired := String(data.get("selected", ""))
	if desired != "" and IMAGES.has(desired):
		var idx := _find_item_index_by_text(desired)
		if idx >= 0:
			selector.select(idx)
			_apply_selection(desired)
			return
	if selector.item_count > 0:
		_apply_selection(UIHelpers.safe_get_selected_text(selector))


func _on_selection(idx: int) -> void:
	_apply_selection(selector.get_item_text(idx))


func _apply_selection(key: String) -> void:
	_current_key = key
	var path := String(IMAGES.get(key, ""))
	if path != "" and ResourceLoader.exists(path):
		var tex := ResourceLoader.load(path)
		if tex is Texture2D:
			UIHelpers.safe_set_texture(preview, tex)
			UIHelpers.safe_set_text(status_label, "Showing %s" % key)
			return
	UIHelpers.safe_set_texture(preview, null)
	UIHelpers.safe_set_text(status_label, "Image missing")


func _find_item_index_by_text(text: String) -> int:
	for i in range(selector.item_count):
		if selector.get_item_text(i) == text:
			return i
	return -1
