# Part Selector

*Overview: see `res://apps/character_creator/README.md` for wiring & tests.*

Entry scene: `res://apps/character_creator/part_selector/part_selector.tscn`

Notes:
- Contains `PartScroller` scene at `res://apps/character_creator/part_selector/part_scroller.tscn`.
- API: `build(parts_vbox_node: Node, selected: Dictionary)`, `get_selection()`, `set_selection()`.
- Emits `part_changed(type, part_id)` when parts change.

Usage:
- Use as an embeddable control or call methods directly after instancing.

Example:
```
var ps = load("res://apps/character_creator/part_selector/part_selector.tscn").instantiate()
add_child(ps)
ps.build(ps.get_node_or_null("PartsVBox"), {"head":"head_01"})
ps.connect("part_changed", Callable(self, "_on_part_changed"))
func _on_part_changed(type, id):
	print("Part %s changed -> %s" % [type, id])
```

Embedding in other scenes:
```
# You can embed the Part Selector as a reusable control and wire its events
var host := Node.new()
add_child(host)
var ps = load("res://apps/character_creator/part_selector/part_selector.tscn").instantiate()
host.add_child(ps)
ps.build(host.get_node_or_null("PartsVBox"), {"head":"head_01"})
ps.connect("part_changed", Callable(self, "_on_part_changed"))
```
- Tests cover selection and next/prev behavior (see `tests/part_scroller_ui_test.gd` for scroller behavior).

Testing snippet:
```
# Headless test example: emit a part change and assert handler invocation
var ps = load("res://apps/character_creator/part_selector/part_selector.tscn").instantiate()
add_child(ps)
ps.build(ps.get_node_or_null("PartsVBox"), {"head":"head_01"})
var fired := false
ps.connect("part_changed", Callable(func(type, id): fired = true))
ps.emit_signal("part_changed", "head", "head_01")
await get_tree().process_frame
assert(fired)
```