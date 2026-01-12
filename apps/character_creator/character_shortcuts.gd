extends Node

const Impl := preload("res://apps/character_creator/shortcuts/character_shortcuts.gd")
var _impl: Node = null

func _ensure_impl() -> void:
	if _impl == null:
		_impl = Impl.new()
		add_child(_impl)
		if _impl.has_method("build"):
			_impl.build()

func set_on_open_new(cb: Callable) -> void:
	_ensure_impl()
	if _impl != null and _impl.has_variable("on_open_new"):
		_impl.on_open_new = cb

func set_on_delete_callback(cb: Callable) -> void:
	_ensure_impl()
	if _impl != null and _impl.has_variable("on_delete_callback"):
		_impl.on_delete_callback = cb

func set_on_select_callback(cb: Callable) -> void:
	_ensure_impl()
	if _impl != null and _impl.has_variable("on_select_callback"):
		_impl.on_select_callback = cb

func build() -> void:
	_ensure_impl()

func _unhandled_input(event: InputEvent) -> void:
	_ensure_impl()
	if _impl != null and _impl.has_method("_unhandled_input"):
		_impl._unhandled_input(event)
