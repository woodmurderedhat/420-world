extends Node

signal stats_changed(stats: Dictionary)

var container: GridContainer = null
var inputs: Dictionary = {}
var stat_names: Array = ["gold", "agility", "strength", "intelligence", "constitution", "luck"]

func build(parent_node: Node) -> void:
	container = parent_node.get_node_or_null("StatsGrid")
	if not container:
		container = GridContainer.new()
		container.name = "StatsGrid"
		container.columns = 2
		parent_node.add_child(container)
	# Clear existing
	for c in container.get_children():
		c.queue_free()
	inputs.clear()
	for s in stat_names:
		var lbl = Label.new()
		lbl.text = s.capitalize()
		container.add_child(lbl)
		var sb = SpinBox.new()
		sb.min_value = 1
		sb.max_value = 99
		sb.value = 5
		sb.step = 1
		sb.connect("value_changed", Callable(self, "_on_value_changed"))
		container.add_child(sb)
		inputs[s] = sb

func _on_value_changed(_v: float) -> void:
	emit_signal("stats_changed", get_stats())

func get_stats() -> Dictionary:
	var out: Dictionary = {}
	for s in stat_names:
		out[s] = int(inputs[s].value)
	return out

func set_stats(stats: Dictionary) -> void:
	for s in stat_names:
		if stats.has(s) and inputs.has(s):
			inputs[s].value = int(stats[s])
	emit_signal("stats_changed", get_stats())