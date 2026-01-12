# Container Slot Component

*Overview: see `res://apps/character_creator/README.md` for wiring & tests.*

Entry scene: `res://apps/character_creator/components/container_slot/character_container_slot.tscn`

API:
- `setup(container_id, index, slot_data)` — populates the slot UI
- Supports drag & drop and context menu actions

Usage:
- Use this as a reusable slot for inventory or container UIs.

Testing snippet:
```
# Instantiate slot and assert setup populates UI
var slot = load("res://apps/character_creator/components/container_slot/character_container_slot.tscn").instantiate()
add_child(slot)
slot.setup("cid", 0, {"item":"potion", "quantity":1})
await get_tree().process_frame
# Assert label or children updated, eg:
assert(slot.get_child_count() > 0)
```

Testing:
- Inventory and slot flows are exercised in `tests/graveyard_test.gd` and the comprehensive headless suite; use those tests as examples for wiring `setup()` and drag/drop behavior.