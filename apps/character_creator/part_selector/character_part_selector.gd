extends Node

signal part_changed(type: String, part_id: String)

var parts_vbox: VBoxContainer = null
var selected_parts: Dictionary = {}
var PART_TYPES: Array = ["head","eyes","mouth","hair","body","arms","hands","legs","feet"]

func build(parts_vbox_node: Node, selected: Dictionary) -> void:
	parts_vbox = parts_vbox_node
	selected_parts = selected.duplicate()
	refresh()

func set_selection(selected: Dictionary) -> void:
	selected_parts = selected.duplicate()
	refresh()

func get_selection() -> Dictionary:
	return selected_parts

func refresh() -> void:
	if parts_vbox == null: return
	# Try to use PartScroller when present
	var scroller = parts_vbox.get_node_or_null("PartScroller")
	if scroller:
		if scroller.has_method("refresh"):
			scroller.refresh()
			scroller.set_selection(selected_parts)
			if not scroller.is_connected("part_changed", Callable(self, "_on_scroller_part_changed")):
				scroller.connect("part_changed", Callable(self, "_on_scroller_part_changed"))
		return

	# Fallback to legacy UI
	for c in parts_vbox.get_children():
		c.queue_free()

	for t in PART_TYPES:
		var lbl := Label.new()
		lbl.text = t.capitalize()
		parts_vbox.add_child(lbl)
		var row := HBoxContainer.new()
		parts_vbox.add_child(row)
		var parts = BodyPartRegistry.get_parts(t)
		for p in parts:
			var pid = p.get("id", "")
			var tex = BodyPartRegistry.get_part_texture(pid, t)
			var btn := TextureButton.new()
			btn.texture_normal = tex
			btn.custom_minimum_size = Vector2(48,48)
			btn.disabled = false
			var locked = false
			if p.get("cost", 0) > 0:
				locked = not ProgressionManager.is_body_part_unlocked(pid)
			if locked:
				btn.modulate = Color(0.6,0.6,0.6,1)
				var unlock_btn := Button.new()
				unlock_btn.text = "Unlock (%d)" % p.get("cost",0)
				unlock_btn.pressed.connect(func() -> void:
					EventBus.emit_event("shop_open", {"item": pid, "cost": p.get("cost",0)})
					DialogManager.show_toast("Shop opened for %s" % pid)
				)
				var vbox := VBoxContainer.new()
				vbox.add_child(btn)
				vbox.add_child(unlock_btn)
				row.add_child(vbox)
			else:
				btn.pressed.connect(func() -> void:
					emit_signal("part_changed", t, pid)
				)
				var vbox := VBoxContainer.new()
				vbox.add_child(btn)
				var name_lbl := Label.new()
				name_lbl.text = p.get("name", "")
				vbox.add_child(name_lbl)
				row.add_child(vbox)

func _on_scroller_part_changed(type: String, part_id: String) -> void:
	selected_parts[type] = part_id
	emit_signal("part_changed", type, part_id)

func _ready() -> void:
	# Auto-build when attached to a scene with PartsVBox
	var pv = get_node_or_null("PartsVBox")
	if pv == null:
		pv = get_node_or_null(".")
	if pv != null:
		build(pv, selected_parts)