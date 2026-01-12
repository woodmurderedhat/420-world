extends Node

const Impl := preload("res://apps/character_creator/part_selector/character_part_selector.gd")
var _impl: Node = null

func _ensure_impl(parent_node: Node = null) -> void:
	if _impl == null:
		_impl = Impl.new()
		add_child(_impl)
		if parent_node != null and _impl.has_method("build"):
			_impl.build(parent_node)

func build(parent_node: Node) -> void:
	_ensure_impl(parent_node)

func get_selection() -> Dictionary:
	_ensure_impl()
	if _impl.has_method("get_selection"):
		return _impl.get_selection()
	return {}

func set_selection(selected: Dictionary) -> void:
	_ensure_impl()
	if _impl.has_method("set_selection"):
		_impl.set_selection(selected)

func refresh() -> void:
	_ensure_impl()
	if _impl.has_method("refresh"):
		_impl.refresh()

func _ready() -> void:
	_ensure_impl()
