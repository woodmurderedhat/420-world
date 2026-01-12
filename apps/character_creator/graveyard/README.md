# Character Graveyard

*Overview: see `res://apps/character_creator/README.md` for wiring & tests.*

Entry scene: `res://apps/character_creator/graveyard/graveyard.tscn`

Exposed signals:
- `cleared()` — emitted after the graveyard is cleared
- `entry_purged(index: int, name: String)` — emitted after an entry is purged

Usage:
- Instance and call `refresh()` or provide node paths via `build(container_node, clear_button)` when embedding.

Example:
```
var gv = load("res://apps/character_creator/graveyard/graveyard.tscn").instantiate()
add_child(gv)
gv.refresh()
```

- The scene uses `DialogManager.show_confirm` for destructive actions; tests simulate confirmations by emitting signals on the `ConfirmationDialog`.

Testing snippet:
```
# Open the graveyard and trigger a purge that shows a confirm dialog
gv.refresh()
await get_tree().process_frame
# Find the ConfirmationDialog and simulate user clicking Yes
for c in get_tree().get_root().get_children():
	if c is ConfirmationDialog:
		c.emit_signal("confirmed")
		break
await get_tree().process_frame
# Assert graveyard UI updated as expected (check entries or call gv.refresh())
```

Testing:
- See `tests/delete_confirm_integration_test.gd` for a confirm->delete flow and `tests/confirm_popup_timeout_test.gd` to verify dialogs do not auto-timeout. These tests show how to find the dialog instance and emit `confirmed`/`canceled` in headless mode.