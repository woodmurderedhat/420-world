# Character Details

*Overview: see `res://apps/character_creator/README.md` for wiring & tests.*

Entry scene: `res://apps/character_creator/details/details.tscn`

API:
- `show_character(char_id)` — displays character preview and populates the inventory grid

Usage:
- Instance and call `show_character()` to update the view for a character.

Example:
```
var d = load("res://apps/character_creator/details/details.tscn").instantiate()
add_child(d)
d.show_character(character_id)
```
- Inventory slots are provided by `components/container_slot/character_container_slot.tscn`.  

Testing:
- Selection and detail flows are exercised in `tests/a11y_keyboard_extra_permutations_test.gd` which verifies Enter selection updates `selected_character_id` and that details are shown correctly.