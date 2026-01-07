# Godot 4.5+ Modular Desktop Framework

## Architecture Overview

- **Visual OS Simulation**: A `Control`-based desktop environment. Windows are internal nodes managed by `WindowManager`, not native OS windows.
- **Autoloads (Singletons)**: Core logic resides in `scripts/` autoloads defined in `project.godot`:
  - `Log`: (LogManager) File-backed logging handler. FIRST to initialize.
  - `CoreRuntime`: Service locator and init tracking.
  - `EventBus`: Decoupled communication.
  - `AppRegistry`: Scans `apps/` for `manifest.json` and manages app lifecycle.
  - `WindowManager`: Handles window instances, focus, and minimizing/maximizing.
- **App Structure**: Each app lives in `apps/<id>/`. It requires:
  - `manifest.json`: Metadata (ID, name, entry scene).
  - Main Scene: Must extend `AppBase` (`scripts/app_base.gd`).

## Godot 4.5.1 Syntax & Standards

If uncertain about anything, refer to the official Godot docs.

- **Strict Typing**: ALWAYS use static typing for variables, arguments, and return types.
  - **Yes**: `var health: int = 100`, `func get_name() -> String:`, `var items: Array[Dictionary] = []`
  - **No**: `var health = 100`, `func get_name():`
- **Logging**:
  - **ALWAYS** use `Log.info()`, `Log.warn()`, `Log.error()` instead of `print()` or `push_error()`.
  - Logs are written to `res://debug/logs/` (timestamped) and mirrored to stdout.
- **Godot 4.x Keywords**:
  - Use `await` instead of `yield`.
  - Use `super()` calls instead of `.` (e.g., `super._ready()`).
  - Use `@export`, `@onready`, `@icon` annotations.
  - Use `Callable` for signals: `button.pressed.connect(_on_pressed)`.
- **Event-Driven**: Prefer `EventBus.emit_event("name", payload)` over direct node references for cross-system chatter.

## Critical Workflows

use existing system and apps if they exist. always check the existing code before implementing something new. we dont want to have duplicate code or duplicate systems. everything must be well integrated

### Creating a New App

1. Create folder `apps/<my_app>/`.
2. Create `manifest.json`: `{ "id": "my_app", "entry_scene": "res://apps/my_app/main.tscn", ... }`.
3. Create `main.tscn` with a root script extending `AppBase`.
4. Implement `save_state() -> Dictionary` and `load_state(data: Dictionary)` for persistence.

### Integration Reference

- **Persistence**:
  - `SaveManager.save_app(app_id, state_dict)` / `load_app(app_id)`
  - `SaveManager.save_global(dict)` references `user://global_save.json`.
- **Window Management**:
  - Open: `WindowManager.open_window(app_id, title, scene_instance)`
  - Close: `WindowManager.close_window(window_id)`

---

## Testing Architecture

The project relies on a **Single Comprehensive Headless Suite** that verifies the entire shell infrastructure without a window.

**1. Running Tests**

- **Command**: See `docs/headless-tests.md` for the exact PowerShell command using the Godot binary path from `.vscode/settings.json`.
- **Argument**: `--headless-tests` triggers `CoreRuntime` to run `tests/comprehensive_headless.gd`.

**2. Scope of Tests**

- **Service Registration**: checks specific order of Autoloads.
- **Data Layers**: Validates `EventBus`, `SaveManager` (JSON round-trips), `SettingsManager`, `InventoryManager`.
- **UI Logic**: Headless verification of `WindowManager` (focus, stacking, minimizing), `Taskbar`, and `StartMenu` state.

**3. Debugging Failures**

- **Logs**: Failures are logged via `Log.error` to `debug/logs/log_<timestamp>.txt`.
- **Exit Codes**: The suite loops on `get_tree().process_frame` via `await` and quits with code `0` (pass) or `1` (fail).

---

## Dependency Graph & Build Layers

**Layer 0: Diagnostics**

- *Components*: `LogManager`.
- *Responsibility*: Application-wide logging infrastructure.

**Layer 1: Boot & Core Runtime**

- *Components*: `CoreRuntime`.
- *Responsibility*: Safe startup, service locator, crash handling.

**Layer 2: Kernel Services**

- *Components*: `EventBus`, `SaveManager`, `SettingsManager`.
- *Responsibility*: Data persistence, decoupled communication, global config.

**Layer 3: Windowing & Input**

- *Components*: `WindowManager`, `ThemeManager`.
- *Responsibility*: Managing the "nodes that act like windows", z-order, focus, resizing.

**Layer 4: Desktop UI**

- *Components*: `Taskbar`, `StartMenu`, `DesktopBackground`.
- *Responsibility*: The "Shell" that hosts windows. Depends on WindowManager.

**Layer 5: App & Filesystem**

- *Components*: `AppRegistry`, `AppBase`.
- *Responsibility*: Discovering, loading, and isolating games/apps.

**Layer 6: Cross-Game Unification**

- *Components*: `InventoryManager`, Shared Resources.
- *Responsibility*: Letting App A send items to App B.
