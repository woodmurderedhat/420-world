# Comprehensive Framework Design — Godot 4.5.1 Modular Desktop Front-End

---

# 1 — High-level architecture (what talks to what)

* **Shell (Desktop)** — top-level scene that runs at project start. Hosts:
  * `WindowManager` (manages in-game windows)
  * `Taskbar` / `Dock`
  * `StartMenu` / `AppLauncher`
  * `DesktopLayer` (background, desktop icons, widgets)
  * `FileBrowser`, `Settings`, `ThemeManager`
* **App Registry / Loader** — registry of available apps/games. Can load PackedScenes or modular packages.
* **App / Game** — packaged as a Godot scene that meets the App API (lifecycle methods & metadata).
* **Global Singletons (autoloads)** — `InventoryManager`, `PlayerDatabase`, `SaveManager`, `EventBus`, `SettingsManager`, `ThemeManager`.
* **Data persistence** — SaveManager handles a global save file (user://global_save.json) plus per-app saves (user://apps/<app_id>.json).
* **Plugin system** — each app includes a small `manifest.json` (or .tres) describing ID, name, icon, entry scene, required permissions.

All UI is 2D (Control nodes) so behaviour is consistent across platforms.

---

# 2 — Design principles

* **Modular** : Each game is a self-contained scene + manifest. Desktop only needs to instantiate and call into that scene’s API.
* **API-first** : Standardize what an app must expose (launch, pause, resume, save_state, load_state).
* **Data-first** : Shared resources (items, characters) are `Resource` classes — serializable and referenceable across games.
* **Pixel-perfect** : Use integer coordinates, disable texture filtering, enable pixel snap, use a fixed virtual resolution + scale.
* **In-game windows** : Use Control-based windows (Panels with titlebars) so windows are consistent regardless of platform. (Optionally support OS windows later.)
* **Event-driven** : Use signals and `EventBus` for decoupled communication.

---

# 3 — Folder / file layout (recommended)

```
/project
  /addons              # editor tools, optional
  /apps                # each app/game is a folder with manifest + scene
    /farm_sim
      farm_sim.tscn
      manifest.json
      scripts/
      assets/
    /rpg
      rpg.tscn
      manifest.json
  /resources
    /items
      item_resource.gd
  /scenes
    desktop.tscn
    window_manager.tscn
    game_window.tscn
    taskbar.tscn
    start_menu.tscn
    file_browser.tscn
  /scripts
    app_registry.gd
    window_manager.gd
    inventory_manager.gd
    save_manager.gd
    event_bus.gd
    theme_manager.gd
  /user:// (runtime folder for saves)
```

---

# 4 — App manifest (example)

Use a small JSON manifest in each app folder.

`apps/rpg/manifest.json`

```json
{
  "id": "rpg",
  "name": "RPG",
  "entry_scene": "res://apps/rpg/rpg.tscn",
  "icon": "res://apps/rpg/assets/icon.png",
  "version": "0.1",
  "permissions": ["cross_inventory", "character_access"]
}
```

AppRegistry scans `res://apps` (or `user://apps`) for manifests and registers launchable apps.

---

# 5 — App API spec (what each app should implement)

Each app should extend a small App base script:

```gdscript
# scripts/app_base.gd
extends Node
class_name AppBase

signal request_close()
signal request_minimize()
signal request_focus()

var metadata := {} # populated from manifest

func launch(params: Dictionary) -> void:
    # Called by the shell to start the app
    pass

func pause() -> void:
    # Called when window minimized or switched away
    pass

func resume() -> void:
    # Called on focus regain
    pass

func save_state() -> Dictionary:
    # Return serializable state
    return {}

func load_state(data: Dictionary) -> void:
    # Load state back in
    pass
```

The shell calls these lifecycle methods.

---

# 6 — Windowing system (in-game windows)

Create a reusable `GameWindow` scene (Panel with TitleBar, Buttons, and Grip for resizing). Windows are children of `WindowManager`.

`scenes/game_window.tscn` structure (concept):

* `GameWindow (Panel)`
  * `TitleBar (HBoxContainer)` (drag to move)
    * `Label (title)`
    * `Button (minimize)`
    * `Button (maximize)`
    * `Button (close)`
  * `Content (Control)` — container where app scene is instanced
  * `SizeGrip (Control)` — resize handle

Basic window script:

```gdscript
# scripts/game_window.gd
extends Panel
class_name GameWindow

signal closed(window_id)
signal minimized(window_id)
signal focused(window_id)

var window_id: String
var is_minimized := false
var is_maximized := false

@onready var title_label = $TitleBar/Label
@onready var content = $Content

func _ready():
    self.focus_mode = Control.FOCUS_ALL
    $TitleBar/CloseButton.pressed.connect(_on_close_pressed)
    $TitleBar/MinButton.pressed.connect(_on_minimize_pressed)
    $TitleBar/MaxButton.pressed.connect(_on_maximize_pressed)
    # drag handling
    $TitleBar.connect("gui_input", Callable(self, "_on_title_gui_input"))

func set_title(text: String):
    title_label.text = text

func set_content_scene(scene: PackedScene):
    content.free_children()
    var inst = scene.instantiate()
    content.add_child(inst)
    return inst

func _on_close_pressed():
    emit_signal("closed", window_id)
    queue_free()

func _on_minimize_pressed():
    is_minimized = !is_minimized
    visible = not is_minimized
    emit_signal("minimized", window_id)

func _on_maximize_pressed():
    is_maximized = !is_maximized
    # TODO: handle layout transform to fullscreen region
    emit_signal("focused", window_id)

func _on_title_gui_input(ev):
    if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
        get_tree().set_input_as_handled()
        # start drag — implement dragging by tracking mouse
```

`WindowManager` listens for these signals, tracks z-order and focus, and informs Taskbar.

---

# 7 — Taskbar & Start menu

* **Taskbar** : shows open windows and pinned apps. When window signals `minimized` or `closed`, update icons. Clicking a taskbar item focuses the window (bring to front or restore).
* **StartMenu** : lists manifest entries from AppRegistry; launching an app asks WindowManager to create a new `GameWindow` and instance the app’s scene.

Taskbar communicates with WindowManager via `EventBus` signals like `window_opened`, `window_closed`, `window_focused`.

---

# 8 — App loading & modularity

 **Simple mode** : load a PackedScene from `res://apps/<app_id>/<entry_scene>`:

```gdscript
var scene = ResourceLoader.load(manifest["entry_scene"])
var app_inst = scene.instantiate()
```

 **Advanced mode** : support `.pck` or resource packs (for DLC / mod-style installs). You can use Godot’s resource pack loading APIs (check ProjectSettings / ResourceLoader docs) to mount packs at runtime, then scan for manifests.

Each app should ship all its resources within its folder so it’s easy to add/remove.

---

# 9 — Cross-game shared data: Inventory & Characters

Use typed `Resource` classes for portability:

`resources/item_resource.gd`

```gdscript
extends Resource
class_name ItemResource
@export var id: String
@export var name: String
@export var description: String
@export var icon: Texture2D
@export var properties: Dictionary = {}
```

`inventory_manager.gd`

```gdscript
extends Node
class_name InventoryManager

signal inventory_changed()

var items: Dictionary = {} # id -> count or list

func add_item(item_res: ItemResource, amount: int = 1):
    items[item_res.id] = items.get(item_res.id, 0) + amount
    emit_signal("inventory_changed")

func remove_item(item_id: String, amount: int = 1) -> bool:
    if items.get(item_id,0) >= amount:
        items[item_id] -= amount
        if items[item_id] <= 0:
            items.erase(item_id)
        emit_signal("inventory_changed")
        return true
    return false

func has_item(item_id: String) -> bool:
    return items.has(item_id)
```

**Usage:** any app can `InventoryManager.add_item(item)`; UIs listen for `inventory_changed` to update displays. SaveManager will serialize `items`.

 **Characters** : create `CharacterResource` with stats and unique ID. `PlayerDatabase` stores references to owned characters.

---

# 10 — Save system + data migrations

`SaveManager` responsibilities:

* Maintain `global_save.json` with schema version.
* Save `InventoryManager` state, `PlayerDatabase`, global settings.
* Provide per-app save hooks: call `app.save_state()` and write result to `user://apps/<app_id>.json`.
* Migration: keep `schema_version` in save and migration functions when loading older versions.

Example:

```gdscript
func save_global():
    var data = {
        "schema_version": 1,
        "inventory": InventoryManager.items,
        "players": PlayerDatabase.export_all()
    }
    var f = FileAccess.open("user://global_save.json", FileAccess.WRITE)
    f.store_string(JSON.print(data))
    f.close()
```

Use `FileAccess` for cross-platform safe file I/O.

---

# 11 — Theming & pixel-perfect UI

Project settings (recommendations):

* Stretch mode: `2d` and set a fixed **virtual resolution** (e.g., 1280×720 or smaller for pixel art).
* Disable texture filtering for pixel art (`image_flags`/`filter` false on textures or set in import).
* Enable *Use Pixel Snap* and *Snap* to integer positions for Control nodes.
* Create a `Theme.tres` resource for UI widgets (buttons, scrollbars) with pixel-art sprites.

All UI should use `Size Flags` and anchors to scale nicely with pixel snapping.

---

# 12 — Event Bus

Simple autoload:

```gdscript
# scripts/event_bus.gd
extends Node
class_name EventBus
# dynamic signals can be used with emit_signal / connect by name
```

Use `EventBus.emit_signal("window_focused", window_id)` rather than direct coupling.

---

# 13 — Security / sandboxing considerations

* Apps all run inside same Godot process; they share memory. Enforce app API and do not call arbitrary OS commands.
* SaveManager and AppRegistry should validate manifest files to avoid loading malicious scripts (if you plan to load community packs).
* Optionally run untrusted apps in a stricter environment or require signing for third-party packs.

---

# 14 — Performance & optimization

* Only keep visible apps/paused apps in memory if resources allow. Provide an option to suspend low-priority apps (call app.pause() and free heavy resources).
* Use `VisibilityNotifier2D` / culling where applicable.
* Profile frequently with Godot’s built-in profiler (avoid high-frequency signals if not necessary).

---

# 15 — Developer ergonomics & editor workflows

* Create an **App Template** scene and a script template that implements the App API — speed up new game scaffolding.
* Make an **Editor plugin** (optional) that registers a “Create App Package” builder which creates the manifest, icons, and checks.
* Use Scenes and subscenes for common UI (titlebars, window templates).

---

# 16 — Example quick-start MVP (milestones)

**MVP (1–2 weeks)**

* Desktop shell scene with background and draggable icons.
* WindowManager + GameWindow with basic move/resize/minimize/close.
* Taskbar that lists open windows and can focus/restore them.
* AppRegistry that can load 1 sample app (simple demo game).
* Global `InventoryManager` and `SaveManager` wired up.

**Next (2–4 weeks)**

* StartMenu & App installation (scan manifests).
* FileBrowser to read/write user saves (show examples).
* Theming engine + pixel-perfect UI.
* App API enforcement (lifecycle & saving).

**Later (ongoing)**

* Resource packs / .pck support for DLC.
* Editor plugin for packaging apps.
* Cross-game systems: shared achievements, cross-save migration, cloud sync (optional).
* Multi-window OS-level optional mode (if you want separate OS windows for each game).

---

# 17 — Concrete code snippets (put these in your autoloads)

**AppRegistry (simplified)**

```gdscript
# scripts/app_registry.gd
extends Node
class_name AppRegistry

var apps: Dictionary = {}

func _ready():
    scan_for_apps()

func scan_for_apps():
    var dir = DirAccess.open("res://apps")
    if not dir:
        return
    dir.list_dir_begin()
    var name = dir.get_next()
    while name != "":
        if dir.current_is_dir():
            var manifest_path = "res://apps/%s/manifest.json" % name
            if FileAccess.file_exists(manifest_path):
                var t = FileAccess.open(manifest_path, FileAccess.READ)
                var data = JSON.parse_string(t.get_as_text()).result
                apps[data.id] = data
            # else skip
        name = dir.get_next()
    dir.list_dir_end()

func get_manifest(app_id:String) -> Dictionary:
    return apps.get(app_id, null)
```

**WindowManager launch example**

```gdscript
# scripts/window_manager.gd
extends Node
class_name WindowManager

onready var window_template = preload("res://scenes/game_window.tscn")
var windows := {}

func open_app(app_manifest: Dictionary, params = {}):
    var win = window_template.instantiate()
    win.window_id = "%s_%d" % [app_manifest.id, OS.get_unix_time()]
    add_child(win)
    var packed = ResourceLoader.load(app_manifest.entry_scene)
    var app_node = win.set_content_scene(packed)
    # call standardized method if exists
    if app_node.has_method("launch"):
        app_node.launch(params)
    windows[win.window_id] = win
    # propagate event
    EventBus.emit_signal("window_opened", win.window_id)
    return win.window_id
```

---
