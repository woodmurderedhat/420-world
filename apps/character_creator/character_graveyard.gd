extends Node

const Impl := preload("res://apps/character_creator/graveyard/character_graveyard.gd")
var _impl: Node = null

func _ensure_impl() -> void:
	if _impl == null:
		_impl = Impl.new()
		add_child(_impl)

func build(gv_node: Node, clear_button: Node) -> void:
	_ensure_impl()
	if _impl.has_method("build"):
		_impl.build(gv_node, clear_button)

func refresh() -> void:
	_ensure_impl()
	if _impl.has_method("refresh"):
		_impl.refresh()

func _ready() -> void:
	_ensure_impl()
