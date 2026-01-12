# Character Gallery

*Overview: see `res://apps/character_creator/README.md` for wiring & tests.*

Entry scene: `res://apps/character_creator/gallery/gallery.tscn`

Exposed signals:
- `character_selected(char_id: String)` — card selected
- `export_requested(char_id: String)` — request export
- `delete_requested(char_id: String)` — request delete
- `new_requested()` — New Character requested
- `purchase_requested()` — Purchase slot requested

Usage:
- Instance the scene or add as a child and call `refresh()` to repopulate.
- Connect signals to your controller to handle user actions.

Example:
```
var g = load("res://apps/character_creator/gallery/gallery.tscn").instantiate()
add_child(g)
g.connect("export_requested", Callable(self, "_on_export"))
func _on_export(id: String) -> void:
	print("Export requested for %s" % id)
```

Advanced usage:
```
# Embed gallery in a host scene and toggle wrap-around navigation
var cc = load("res://apps/character_creator/character_creator.tscn").instantiate()
add_child(cc)
# By default navigation clamps; enable wrap-around if desired:
# Prefer using set() in dynamic contexts and tests:
cc.set("gallery_wrap_navigation", true)
# or simply: cc.gallery_wrap_navigation = true
cc._connect_ui()
cc._ui.gallery.connect("character_selected", Callable(self, "_on_character_selected"))
```

Notes:
- The scene is standalone and uses `CharacterManager` and `CharacterRenderer` to render cards.

Testing & behavior:
- Default navigation **clamps** at the ends. To enable wrap-around navigation set the flag before the UI is built:
```
# Safe assignment (works in tests & runtime):
cc.set("gallery_wrap_navigation", true)
# or in plain scenes: cc.gallery_wrap_navigation = true
cc._connect_ui()
```
- Tests covering navigation and keyboard permutations:
  - `tests/focus_wrap_wraparound_test.gd` — basic wrap-around behavior
  - `tests/focus_wrap_updown_edgecases_test.gd` — up/down wrap edge cases (partial rows, single item)
  - `tests/a11y_keyboard_extra_permutations_test.gd` — keyboard permutations (Delete/Cancel, Delete/Confirm, Enter selection)
- Confirm/delete flows are covered by `tests/delete_confirm_integration_test.gd` and `tests/a11y_keyboard_extra_permutations_test.gd` which simulate confirmations by emitting `confirmed`/`canceled` on the active `ConfirmationDialog`.

Testing snippets:
```
# Set wrap flag safely (use `set()` in tests to avoid property binding issues):
cc.set("gallery_wrap_navigation", true)
cc._connect_ui()  # ensure UI is wired
await get_tree().process_frame

# Simulate keyboard navigation in headless tests
var e := InputEventKey.new()
e.keycode = Key.KEY_RIGHT
e.pressed = true
cc._unhandled_input(e)
await get_tree().process_frame

# Find confirmation dialog and confirm/cancel it
for c in get_tree().get_root().get_children():
	if c is ConfirmationDialog:
		c.emit_signal("confirmed")  # or "canceled"
		break

# Check focus owner in tests
var focused = UIHelpers.get_focus_owner()
```