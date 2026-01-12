extends Node

const Impl := preload("res://apps/character_creator/stat_inputs/character_stat_inputs.gd")
var _impl: Node = null

func _ensure_impl(parent_node: Node = null) -> void:
	if _impl == null:
		_impl = Impl.new()
		add_child(_impl)
		if parent_node != null and _impl.has_method("build"):
			_impl.build(parent_node)

func build(parent_node: Node) -> void:
	_ensure_impl(parent_node)

func get_stats() -> Dictionary:
	_ensure_impl()
	if _impl.has_method("get_stats"):
		return _impl.get_stats()
	return {}

func set_stats(stats: Dictionary) -> void:
	_ensure_impl()
	if _impl.has_method("set_stats"):
		_impl.set_stats(stats)

func _ready() -> void:
	_ensure_impl()
