# Templates UI

*Overview: see `res://apps/character_creator/README.md` for wiring & tests.*

Entry scene: `res://apps/character_creator/templates/templates.tscn`

API:
- `build(container_node, templates_array)` — populates the container with template buttons
- Emits `template_applied(tmpl: Dictionary)` when a template button is pressed.

Usage:
- Instance and call `build()` passing the container node and an array of template dictionaries.

Example:
```
var t = load("res://apps/character_creator/templates/templates.tscn").instantiate()
add_child(t)
t.build(t.get_node_or_null("TemplatesRow"), [{"name":"Magician"}])
t.connect("template_applied", Callable(self, "_on_template"))
func _on_template(tmpl):
	print("Applied: %s" % tmpl.get("name"))
```
- Designed to be a small embeddable row of buttons.

Testing snippet:
```
# Simulate applying a template in a headless test
var t = load("res://apps/character_creator/templates/templates.tscn").instantiate()
add_child(t)
var applied := false
t.connect("template_applied", Callable(func(tmpl): applied = true))
# Simulate a template button press by emitting the signal
var sample = {"name":"TestTemplate"}
t.emit_signal("template_applied", sample)
await get_tree().process_frame
assert(applied)
```