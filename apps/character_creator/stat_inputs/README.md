# Stat Inputs

*Overview: see `res://apps/character_creator/README.md` for wiring & tests.*

Entry scene: `res://apps/character_creator/stat_inputs/stat_inputs.tscn`

API:
- `build(parent_node)` — creates stat inputs under parent node
- `get_stats()` -> Dictionary, `set_stats(dict)`
- Emits `stats_changed(stats)` on change

Usage:
- Use the scene or the script directly to embed stat inputs into right-panel UIs.

Example:
```
var s = load("res://apps/character_creator/stat_inputs/stat_inputs.tscn").instantiate()
add_child(s)
s.build(s)
var current = s.get_stats()
print(current)
```