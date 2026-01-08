extends Node

signal body_part_unlocked(part_id: String)
signal milestone_completed(milestone_id: String)

var unlocked_body_parts: Array = []
var milestones: Dictionary = {}

func _ready() -> void:
	var core: Node = get_tree().root.get_node_or_null("/root/CoreRuntime")
	if core != null:
		core.register_service("ProgressionManager")
	
	call_deferred("_load_from_save")

func _load_from_save() -> void:
	var data = SaveManager.load_global()
	var progression = data.get("progression", {})
	
	unlocked_body_parts = progression.get("unlocked_body_parts", [])
	milestones = progression.get("milestones", {})

func _persist() -> void:
	var data = SaveManager.load_global()
	data["progression"] = {
		"unlocked_body_parts": unlocked_body_parts,
		"milestones": milestones
	}
	SaveManager.save_global(data)

# --- Public API ---

func is_body_part_unlocked(part_id: String) -> bool:
	return part_id in unlocked_body_parts

func unlock_body_part(part_id: String) -> void:
	if not part_id in unlocked_body_parts:
		unlocked_body_parts.append(part_id)
		body_part_unlocked.emit(part_id)
		_persist()

func complete_milestone(milestone_id: String) -> void:
	if not milestones.has(milestone_id):
		milestones[milestone_id] = { "completed_at": Time.get_unix_time_from_system() }
		milestone_completed.emit(milestone_id)
		_persist()

func is_milestone_completed(milestone_id: String) -> bool:
	return milestones.has(milestone_id)
