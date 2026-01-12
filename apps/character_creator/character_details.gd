extends Node

const Impl := preload("res://apps/character_creator/details/character_details.gd")
var _impl: Node = null

func _ensure_impl() -> void:
	if _impl == null:
		_impl = Impl.new()
		add_child(_impl)

func show_character(char_id: String) -> void:
	_ensure_impl()
	if _impl.has_method("show_character"):
		_impl.show_character(char_id)

func _ready() -> void:
	_ensure_impl()
