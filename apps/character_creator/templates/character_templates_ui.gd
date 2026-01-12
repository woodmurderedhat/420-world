extends Node

signal template_applied(tmpl: Dictionary)

var container: Node = null
var templates: Array = []

func build(container_node: Node, templates_arr: Array) -> void:
	container = container_node
	templates = templates_arr.duplicate()
	refresh()

func refresh() -> void:
	if container == null: return
	for c in container.get_children():
		c.queue_free()
	for tmpl in templates:
		var btn := Button.new()
		btn.text = tmpl.get("name", "Template")
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(func(): emit_signal("template_applied", tmpl))
		container.add_child(btn)

func _ready() -> void:
	# Auto-build when this script is attached to a scene
	var container_node = get_node_or_null("TemplatesRow")
	if container_node == null:
		container_node = get_node_or_null(".")
	if container_node != null:
		build(container_node, templates)

func set_templates(tmpls: Array) -> void:
	templates = tmpls.duplicate()
	refresh()