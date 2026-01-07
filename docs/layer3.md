# LAYER 3 — WINDOWING & INPUT

**(Authoritative Specification)**

---

## 1. PURPOSE OF LAYER 3

Layer 3 provides:

* A **virtual windowing system** inside Godot
* Deterministic input routing
* Focus & z-order management
* Window lifecycle guarantees

Everything above this layer  **must treat windows as a black box** .

---

## 2. HARD RULES (NON-NEGOTIABLE)

1. **All app visuals live inside windows**
2. **Only the focused window receives input**
3. **Windows never reference each other**
4. **WindowManager is the single authority**
5. **UI never manually reorders windows**

Break any of these and the system collapses later.

---

## 3. ARCHITECTURE OVERVIEW

```
WindowManager (autoload or root child)
│
├── GameWindow (many)
│    ├── TitleBar
│    ├── ContentRoot
│    └── ResizeHandles
│
└── InputRouter
```

Windows are  **Control nodes** , not OS windows.

---

## 4. WINDOW STATES (FINITE STATE MACHINE)

Each window is always in exactly one state:

```text
CREATED → OPEN
OPEN → FOCUSED
FOCUSED → MINIMIZED
MINIMIZED → RESTORED
FOCUSED → CLOSED
```

No skipping allowed.

---

## 5. WINDOW DATA MODEL

```gdscript
class WindowInfo:
    var id: String
    var title: String
    var node: GameWindow
    var z_index: int
    var state: String # open | focused | minimized | closed
    var app_id: String
```

Stored **only** in WindowManager.

---

## 6. SIGNAL CONTRACT (CRITICAL)

### WindowManager emits:

```gdscript
signal window_opened(id)
signal window_closed(id)
signal window_focused(id)
signal window_minimized(id)
signal window_restored(id)
```

### GameWindow emits:

```gdscript
signal request_focus(id)
signal request_close(id)
signal request_minimize(id)
signal request_restore(id)
```

Windows  **request** . Manager  **decides** .

---

## 7. SCENE: GameWindow

### Structure

```
GameWindow (Panel)
├── TitleBar (HBoxContainer)
│   ├── Label
│   ├── MinButton
│   ├── CloseButton
├── ContentRoot (Control)
└── ResizeHandle (Control)
```

---

## 8. GameWindow.gd (FULL CODE)

```gdscript
extends Panel
class_name GameWindow

signal request_focus(id)
signal request_close(id)
signal request_minimize(id)
signal request_restore(id)

var window_id: String
var dragging := false
var drag_offset := Vector2.ZERO

@onready var title_bar := $TitleBar
@onready var content_root := $ContentRoot

func _ready():
    focus_mode = Control.FOCUS_ALL
    title_bar.gui_input.connect(_on_title_input)
    $TitleBar/CloseButton.pressed.connect(
        func(): emit_signal("request_close", window_id)
    )
    $TitleBar/MinButton.pressed.connect(
        func(): emit_signal("request_minimize", window_id)
    )

func _gui_input(event):
    if event is InputEventMouseButton and event.pressed:
        emit_signal("request_focus", window_id)

func _on_title_input(event):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                dragging = true
                drag_offset = event.position
            else:
                dragging = false
    elif event is InputEventMouseMotion and dragging:
        global_position += event.relative

func set_title(text: String):
    $TitleBar/Label.text = text

func set_content(scene: PackedScene):
    content_root.free_children()
    var inst = scene.instantiate()
    content_root.add_child(inst)
    return inst
```

---

## 9. WindowManager.gd (FULL CODE)

```gdscript
extends Control
class_name WindowManager

signal window_opened(id)
signal window_closed(id)
signal window_focused(id)
signal window_minimized(id)
signal window_restored(id)

@export var window_scene: PackedScene

var windows := {}
var z_counter := 0
var focused_id: String = ""

func open_window(app_id: String, title: String, scene: PackedScene) -> String:
    var win: GameWindow = window_scene.instantiate()
    add_child(win)

    var id = "%s_%d" % [app_id, Time.get_ticks_usec()]
    win.window_id = id
    win.set_title(title)

    win.request_focus.connect(_on_request_focus)
    win.request_close.connect(_on_request_close)
    win.request_minimize.connect(_on_request_minimize)

    win.set_content(scene)

    z_counter += 1
    win.z_index = z_counter

    windows[id] = {
        "node": win,
        "state": "open",
        "app_id": app_id
    }

    _focus_window(id)
    emit_signal("window_opened", id)
    return id

func _focus_window(id: String):
    if not windows.has(id):
        return

    z_counter += 1
    windows[id].node.z_index = z_counter
    focused_id = id
    windows[id].state = "focused"
    emit_signal("window_focused", id)

func _on_request_focus(id):
    _focus_window(id)

func _on_request_close(id):
    if not windows.has(id):
        return
    windows[id].node.queue_free()
    windows.erase(id)
    emit_signal("window_closed", id)

func _on_request_minimize(id):
    if not windows.has(id):
        return
    windows[id].node.visible = false
    windows[id].state = "minimized"
    emit_signal("window_minimized", id)

func restore_window(id):
    if not windows.has(id):
        return
    windows[id].node.visible = true
    _focus_window(id)
    emit_signal("window_restored", id)
```

---

## 10. INPUT ROUTING RULES

* Only **focused window** reacts
* Others still receive hover for visual cues only
* Global shortcuts (Alt+Tab, etc.) live **above** this layer later

You enforce this by:

* checking `focused_id` before processing input
* optional `input_pass` flag per window

---

## 11. WHAT THIS LAYER DOES *NOT* DO

❌ Taskbar
❌ App loading
❌ Saving
❌ Animations
❌ Permissions

Those come later.

---

## 12. VALIDATION CHECKLIST (DO NOT SKIP)

✔ Open 5 windows
✔ Drag them independently
✔ Minimize and restore
✔ Click to refocus
✔ Close in any order
✔ No crashes
✔ Z-order always correct

If **any** of these fail → fix before proceeding.

---
