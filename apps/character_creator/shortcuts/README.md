# Shortcuts Helper

*Overview: see `res://apps/character_creator/README.md` for wiring & tests.*

Entry scene: `res://apps/character_creator/shortcuts/shortcuts.tscn`

API:
- Callbacks to set: `on_open_new`, `on_delete_callback`, `on_select_callback`.
- The scene listens for key events and calls the provided callbacks.

Usage:
- Use as an application-global helper to centralize keyboard shortcuts for the gallery UI.

Testing:
- The helper is covered by keyboard tests such as `tests/keyboard_navigation_test.gd` and `tests/a11y_keyboard_extra_permutations_test.gd` which exercise key flows (N, Delete, Enter) and confirm/cancel flows.

Example:
```
var s = load("res://apps/character_creator/shortcuts/shortcuts.tscn").instantiate()
add_child(s)
s.build()
s.on_open_new = Callable(self, "_open_new")
```

Testing snippet:
```
# Simulate keypress events to test shortcut behavior
var s = load("res://apps/character_creator/shortcuts/shortcuts.tscn").instantiate()
add_child(s)
# Simulate 'N' key to open new
var e := InputEventKey.new()
e.keycode = Key.KEY_N
e.pressed = true
s._unhandled_input(e)  # the helper responds to key events
await get_tree().process_frame
```