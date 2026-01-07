extends Control
class_name AppBase

signal request_close
signal request_minimize
signal request_focus

var metadata: Dictionary = {}

func launch(_params: Dictionary) -> void:
	pass

func pause() -> void:
	pass

func resume() -> void:
	pass

func save_state() -> Dictionary:
	return {}

func load_state(_data: Dictionary) -> void:
	pass

func minimize() -> void:
	request_minimize.emit()

func focus() -> void:
	request_focus.emit()

func close() -> void:
	request_close.emit()
