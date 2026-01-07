# Boot & Init Order

Phase 1 requires deterministic startup. The autoload list is frozen in this order (top to bottom in `project.godot`):

1. CoreRuntime — records init order and prints `[Init #..]` lines
2. EventBus
3. SaveManager
4. SettingsManager
5. AppRegistry
6. InventoryManager
7. ThemeManager

The main entry scene remains `res://scenes/main.tscn`, which instantiates `DesktopScaler` and the `Desktop` shell root (WindowManager + Taskbar + StartMenu). Pressing Play or running headless instantiates that scene.

## Headless verification

Run the automated checks for Phase 1 & 2 (no rendering required):

```
godot --headless --script res://tests/phase1_2_headless.gd
```

The script validates autoload order, EventBus delivery, SaveManager round-trips (global + per-app), SettingsManager persistence, InventoryManager persistence, and that the desktop shell scene instantiates without errors.
