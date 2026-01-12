extends Node

signal cleared()
signal entry_purged(index: int, name: String)

var container: Node = null
var clear_btn: Button = null

func build(gv_node: Node, clear_button: Button) -> void:
	container = gv_node
	clear_btn = clear_button
	# Wire clear button
	if clear_btn:
		clear_btn.pressed.connect(func() -> void:
			DialogManager.show_confirm("Clear Graveyard", "Are you sure you want to clear the entire graveyard?", func(confirmed):
				if confirmed:
					CharacterManager.clear_graveyard()
					refresh()
					emit_signal("cleared")
					DialogManager.show_toast("Graveyard cleared")
				)
			)
	# Initial build
	refresh()

func refresh() -> void:
	if container == null:
		return
	# Clear existing children
	for c in container.get_children():
		c.queue_free()

	var grave = CharacterManager.get_graveyard()
	for i in range(grave.size()):
		var e = grave[i]
		var row := HBoxContainer.new()
		row.name = "grave_%d" % i
		row.custom_minimum_size = Vector2(0, 28)
		var name_lbl := Label.new()
		name_lbl.text = e.get("name", "Unnamed")
		name_lbl.custom_minimum_size = Vector2(180, 0)
		row.add_child(name_lbl)
		var date_lbl := Label.new()
		date_lbl.text = e.get("deletion_date", "")
		date_lbl.custom_minimum_size = Vector2(220, 0)
		row.add_child(date_lbl)
		var stat_lbl := Label.new()
		stat_lbl.text = "Top: %s (%s)" % [e.get("highest_stat", {}).get("name", "None"), str(e.get("highest_stat", {}).get("value", 0))]
		stat_lbl.custom_minimum_size = Vector2(140,0)
		row.add_child(stat_lbl)
		var gold_lbl := Label.new()
		gold_lbl.text = "Gold: %d" % int(e.get("final_gold", 0))
		gold_lbl.custom_minimum_size = Vector2(80,0)
		row.add_child(gold_lbl)
		var idx := i
		var purge_btn := Button.new()
		purge_btn.text = "Purge"
		purge_btn.focus_mode = Control.FOCUS_ALL
		purge_btn.pressed.connect(func() -> void:
			DialogManager.show_confirm("Purge Entry", "Purge entry '%s'?" % e.get("name", ""), func(confirmed):
				if confirmed:
					CharacterManager.purge_graveyard_entry(idx)
					refresh()
					emit_signal("entry_purged", idx, e.get("name", ""))
					DialogManager.show_toast("Purged %s" % e.get("name", ""))
				)
			)
		row.add_child(purge_btn)
		container.add_child(row)

	# If empty, show label
	if grave.size() == 0:
		var lbl := Label.new()
		lbl.text = "No entries in graveyard"
		container.add_child(lbl)

func _ready() -> void:
	# Auto-build when this script is attached to a scene with expected child nodes
	var clear_button = get_node_or_null("GraveyardTop/GraveyardClearBtn")
	if clear_button == null:
		clear_button = get_node_or_null("GraveyardClearBtn")
	var gv_node = get_node_or_null("GraveyardScroll/GraveyardVBox")
	if gv_node == null:
		gv_node = get_node_or_null("GraveyardVBox")
	if gv_node != null:
		build(gv_node, clear_button)