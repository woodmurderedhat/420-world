extends Node

var _subscribers: Dictionary = {} # StringName -> Array[Callable]

func _ready() -> void:
	var core := get_tree().root.get_node_or_null("/root/CoreRuntime")
	if core != null:
		core.register_service("EventBus")

func subscribe(event_name: StringName, handler: Callable) -> void:
	var list: Array = _subscribers.get(event_name, [])
	if handler in list:
		return
	list.append(handler)
	_subscribers[event_name] = list

func unsubscribe(event_name: StringName, handler: Callable) -> void:
	if not _subscribers.has(event_name):
		return
	var list: Array = _subscribers[event_name]
	for i in range(list.size() - 1, -1, -1):
		if list[i] == handler:
			list.remove_at(i)
	_subscribers[event_name] = list

func emit_event(event_name: StringName, payload: Variant = null) -> void:
	if not _subscribers.has(event_name):
		return
	# Iterate over a copy so handlers can unsubscribe during callbacks without breaking iteration.
	for handler: Callable in _subscribers[event_name].duplicate():
		if handler.is_valid():
			handler.call(payload)

func clear(event_name: StringName = "") -> void:
	# Clear one event or all; useful for headless tests.
	if event_name == "":
		_subscribers.clear()
		return
	_subscribers.erase(event_name)
