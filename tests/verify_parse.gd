extends Node

var _failures: int = 0


func _ready() -> void:
	_print("Starting parse verification...")
	_scan_dir("res://")
	if _failures > 0:
		push_error("verify_parse: found %d resource/script load failures" % _failures)
		get_tree().quit(1)
	else:
		_print("verify_parse: passed")
		get_tree().quit(0)


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(ProjectSettings.globalize_path(path))
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if (
				name != "."
				and name != ".."
				and name != ".godot"
				and name != ".vscode"
				and name != "debug"
			):
				_scan_dir(path.path_join(name))
		else:
			var full := path.path_join(name)
			if name.ends_with(".gd") or name.ends_with(".tscn"):
				if not _try_load(full):
					_failures += 1
		name = dir.get_next()
	dir.list_dir_end()


func _try_load(p: String) -> bool:
	# Try to load the resource/script. ResourceLoader.load returns null on failure.
	var res := ResourceLoader.load(p)
	if res == null:
		push_error("Failed to load: %s" % p)
		return false
	return true


func _print(msg: String) -> void:
	# Use Log if available; otherwise use print to stdout
	var log := get_tree().root.get_node_or_null("/root/Log")
	if log != null:
		log.info(msg)
	else:
		print(msg)
