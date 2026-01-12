extends Node

const Impl := preload("res://apps/character_creator/templates/character_templates_ui.gd")
var _impl: Node = null

func _ensure_impl() -> void:
	if _impl == null:
		_impl = Impl.new()
		add_child(_impl)

func build(container_node: Node, templates_array: Array) -> void:
	_ensure_impl()
	if _impl.has_method("build"):
		_impl.build(container_node, templates_array)

func refresh() -> void:
	_ensure_impl()
	if _impl.has_method("refresh"):
		_impl.refresh()

func _ready() -> void:
	_ensure_impl()