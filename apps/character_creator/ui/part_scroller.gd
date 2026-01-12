extends Node

# Compatibility shim: instantiate the canonical UI PartScroller scene so node paths and textures resolve
var PartScrollerScene := preload("res://apps/character_creator/ui/part_scroller.tscn")
static var _instantiating: bool = false
var _inst: Node = null

func _find_global_node_by_name(name: String) -> Node:
	var cs: Node = null
	if get_tree().has_method("get_current_scene"):
		cs = get_tree().get_current_scene()
	if cs != null and cs.has_method("find_node"):
		return cs.find_node(name, true, false)
	# Fallback: scan top-level children but avoid autoloads like LogManager
	for c in get_tree().get_root().get_children():
		if c is Node and c.has_method("find_node") and not c.get_class().ends_with("Manager"):
			var f: Node = c.find_node(name, true, false)
			if f != null:
				return f
	return null

func _ready() -> void:
	if _inst == null and not _instantiating:
		# Guard against re-entrant instantiation causing recursion
		_instantiating = true
		# Avoid instantiating if a PartScroller is already present somewhere in the scene
		var existing: Node = _find_global_node_by_name("PartScroller")
		if existing != null:
			_inst = existing
			_instantiating = false
			return

		_inst = PartScrollerScene.instantiate()
		add_child(_inst)
		# If the instantiated scene has a build() hook, call it for safety
		if _inst.has_method("build"):
			_inst.build()
		_instantiating = false