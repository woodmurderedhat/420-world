extends Control

signal part_changed(type:String, part_id:String)

const DEFAULT_TYPES: Array = ["head","eyes","mouth","hair","body","arms","hands","legs","feet"]

@onready var head: TextureRect = $HBoxContainer/SubViewportContainer/SubViewport/Control/head
@onready var eyes: TextureRect = $HBoxContainer/SubViewportContainer/SubViewport/Control/eyes
@onready var mouth: TextureRect = $HBoxContainer/SubViewportContainer/SubViewport/Control/mouth
@onready var hair: TextureRect = $HBoxContainer/SubViewportContainer/SubViewport/Control/hair
@onready var body: TextureRect = $HBoxContainer/SubViewportContainer/SubViewport/Control/body
@onready var legs: TextureRect = $HBoxContainer/SubViewportContainer/SubViewport/Control/legs
@onready var feet: TextureRect = $HBoxContainer/SubViewportContainer/SubViewport/Control/feet
@onready var hands: TextureRect = $HBoxContainer/SubViewportContainer/SubViewport/Control/hands
@onready var arms: TextureRect = $HBoxContainer/SubViewportContainer/SubViewport/Control/arms

var parts_by_type: Dictionary = {}
var indices: Dictionary = {}

func _ready() -> void:
	_update_parts_from_registry()
	# Connect prev/next buttons
	for t in DEFAULT_TYPES:
		var group_name: String = t.capitalize()
		var prev: Button = get_node_or_null("VBoxContainer/%s/ButtonPrev" % group_name)
		var next: Button = get_node_or_null("VBoxContainer/%s/ButtonNext" % group_name)
		if prev:
			prev.pressed.connect(func(t=t): _prev(t))
		if next:
			next.pressed.connect(func(t=t): _next(t))

func _update_parts_from_registry() -> void:
	# Fetch parts from BodyPartRegistry and initialize indices
	for t in DEFAULT_TYPES:
		var arr = BodyPartRegistry.get_parts(t)
		parts_by_type[t] = []
		for p in arr:
			parts_by_type[t].append(p.get("id", ""))
		if parts_by_type[t].size() == 0:
			indices[t] = -1
		else:
			if not indices.has(t) or indices[t] < 0 or indices[t] >= parts_by_type[t].size():
				indices[t] = 0
		_update_type_display(t)

func _update_type_display(t: String) -> void:
	var idx = indices.get(t, -1)
	var pid = ""
	if idx >= 0 and parts_by_type.has(t) and idx < parts_by_type[t].size():
		pid = parts_by_type[t][idx]
	# Update preview layer
	var tex: Texture2D = null
	if pid != "":
		tex = BodyPartRegistry.get_part_texture(pid, t)

	var preview_map := {"head": head, "eyes": eyes, "mouth": mouth, "hair": hair, "body": body, "arms": arms, "hands": hands, "legs": legs, "feet": feet}
	if preview_map.has(t):
		preview_map[t].texture = tex

	# Update label with selected name if present
	var label = get_node_or_null("VBoxContainer/%s/Label" % t.capitalize())
	if label:
		var name = ""
		if pid != "":
			name = BodyPartRegistry.get_part_metadata(pid).get("name", "")
		label.text = t.capitalize() + ((" - " + name) if name != "" else "")

func _prev(t: String) -> void:
	if not parts_by_type.has(t) or parts_by_type[t].size() == 0:
		return
	indices[t] = (indices[t] - 1) % parts_by_type[t].size()
	_update_type_display(t)
	_emit_change(t)

func _next(t: String) -> void:
	if not parts_by_type.has(t) or parts_by_type[t].size() == 0:
		return
	indices[t] = (indices[t] + 1) % parts_by_type[t].size()
	_update_type_display(t)
	_emit_change(t)

func _emit_change(t: String) -> void:
	var idx = indices.get(t, -1)
	if idx < 0:
		return
	var pid = parts_by_type[t][idx]
	emit_signal("part_changed", t, pid)

func set_selection(sel: Dictionary) -> void:
	# sel is a map type -> part_id
	for t in sel.keys():
		if parts_by_type.has(t):
			var pid = sel[t]
			var idx = parts_by_type[t].find(pid)
			if idx != -1:
				indices[t] = idx
	# Refresh all displays
	for t in DEFAULT_TYPES:
		_update_type_display(t)

func get_selection() -> Dictionary:
	var out := {}
	for t in DEFAULT_TYPES:
		var idx = indices.get(t, -1)
		if idx >= 0 and parts_by_type.has(t) and idx < parts_by_type[t].size():
			out[t] = parts_by_type[t][idx]
		else:
			out[t] = ""
	return out

func refresh() -> void:
	_update_parts_from_registry()
