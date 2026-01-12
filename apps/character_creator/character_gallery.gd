extends Node

# Compatibility wrapper delegating to the packaged implementation at runtime
const Impl := preload("res://apps/character_creator/gallery/character_gallery.gd")
var _impl: Node = null

func _ensure_impl() -> void:
	if _impl == null:
		_impl = Impl.new()
		add_child(_impl)

func build(host_container: Node) -> void:
	_ensure_impl()
	if _impl.has_method("build"):
		_impl.build(host_container)

func refresh() -> void:
	_ensure_impl()
	if _impl.has_method("refresh"):
		_impl.refresh()

func _ready() -> void:
	_ensure_impl()
