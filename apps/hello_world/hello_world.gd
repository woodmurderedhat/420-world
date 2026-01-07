extends AppBase

var _counter := 0

@onready var label: Label = $VBox/Label

func launch(_params: Dictionary) -> void:
	_update()

func pause() -> void:
	# Visible indication for MVP
	label.text = "Paused (count=%d)" % _counter

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
	label.text = "Hello World! Count=%d" % _counter
