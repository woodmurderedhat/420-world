extends "res://scripts/app_base.gd"

var _counter: int = 0

@onready var label: Label = $MainLayout/Label


func launch(_params: Dictionary) -> void:
	_update()


func pause() -> void:
	# Visible indication for MVP
	UIHelpers.safe_set_text(label, "Paused (count=%d)" % _counter)


func resume() -> void:
	_update()


func save_state() -> Dictionary:
	return {"counter": _counter}


func load_state(data: Dictionary) -> void:
	_counter = int(data.get("counter", 0))


func _on_increment() -> void:
	_counter += 1
	_update()


func _update() -> void:
	UIHelpers.safe_set_text(label, "Hello World! Count=%d" % _counter)
