**Menu Window Pattern**

- **Purpose**: A concise, repeatable layout for small desktop apps in this shell. Uses Godot `Control` nodes so apps scale, scroll, and fit inside the shell "window" without overflowing.

**Core Node Tree**
- **Root**: `Control` with `anchors_preset = 15` (Full Rect).
- **MainLayout**: `VBoxContainer` named `MainLayout` (margined inset, expands both axes).
- **Title**: `Label` at top (centered or left as needed).
- **Primary Content**: `TabContainer` (or a single `ScrollContainer`) inside `MainLayout` to separate logical sections.
- **Per-Tab Content**: each tab holds a `ScrollContainer` -> `VBoxContainer` for stacked controls. This gives vertical scrollbars automatically when content exceeds height.
- **Action Row**: `HBoxContainer` for buttons (Apply / Save / Reset) kept outside the `ScrollContainer` so actions are always reachable.

**Layout & Sizing Rules**
- Use `anchors_preset = 15` for root `Control` so the app fills the window.
- `MainLayout` should use inset offsets (12px) and `grow_* = 2` so it resizes with the window.
- On content nodes that should fill available space, use `size_flags_vertical = 3` (Expand) or `size_flags_horizontal = 3` as appropriate.
- Use `theme_override_constants/separation` on `VBoxContainer` to control spacing consistently.

**Tabs & Scrolling**
- Use `TabContainer` to group settings by category (e.g., General, Display, Audio).
- Inside each tab, place a `ScrollContainer` with a `VBoxContainer` child. Let controls stack vertically and scroll when needed.
- Keep control density reasonable — prefer grouping related properties in nested `VBoxContainer` blocks.

**Script Conventions**
- Use `AppBase` (existing project base) as the script base class.
- Use `@onready` with full path into `MainLayout` (for example `@onready var selector: OptionButton = $MainLayout/Selector`) so refactors of local node names are explicit.
- Use `get_node_or_null("/root/ServiceName")` for autoloads (e.g., `ThemeManager`) and test presence before use.
- Guard against freed nodes: use `is_instance_valid(node)` before accessing properties like `.text` or `.color`.

**Persistence API**
- Implement `save_state() -> Dictionary` and `load_state(data: Dictionary)` for app persistence so the shell can call them uniformly.
- Use `SettingsManager.set_value()` and `SettingsManager.get_value()` for global UI settings when available.

**UX Guidelines**
- Keep an action row visible (Apply/Save/Reset) outside scrollers.
- Provide immediate visual feedback after Apply/Save via a small toast label or button text change.
- Prefer `CheckBox`, `OptionButton`, `HSlider`, `ColorPickerButton`, `LineEdit` for typical settings controls.

**Safety & Robustness**
- Always check `if is_instance_valid(node)` before reading/writing its properties when the node might be dynamically freed.
- When building dynamic child controls, use `get_node_or_null` or temporary locals; avoid storing long-lived direct references to nodes that you may `queue_free()`.
- Use `await get_tree().create_timer(...)` for temporary feedback timers and re-check UI nodes with `is_instance_valid` before updating them.

**Example node snippet**

- Scene layout (summary):
  - `Control` (root, anchors_preset=15)
    - `VBoxContainer` (`MainLayout`)
      - `Label` (`Title`)
      - `TabContainer`
        - `ScrollContainer` (tab: "General")
          - `VBoxContainer` (language, pinned apps)
        - `ScrollContainer` (tab: "Display")
          - `VBoxContainer` (scale, theme, background, icons)
      - `HBoxContainer` (`Actions`) (Apply / Reset)

**Example script patterns**
- `@onready var apply_button: Button = $MainLayout/Actions/ApplyButton`
- Guarding access:
  ```gdscript
  if is_instance_valid(bg_image_path):
      SettingsManager.set_value("background.image_path", bg_image_path.text)
  ```
- Dynamic lists: build `VBoxContainer` children at runtime, and when persisting iterate children via `for c in list_vbox.get_children():` and check types via `if c is CheckBox:`.

**Migration checklist**
- Rename local root `VBox` to `MainLayout` and update all `@onready` paths.
- Replace long single-column content with `TabContainer` + `ScrollContainer` per tab.
- Move action buttons outside scrollable area.
- Add `is_instance_valid` guards where `.text` or other properties are used.

**References / Examples**
- Example Settings app: [apps/settings/settings.tscn](apps/settings/settings.tscn) and [apps/settings/settings.gd](apps/settings/settings.gd)

**UI Helpers**
- **Location**: `scripts/ui_helpers.gd`
- **Provided helpers**:
  - `UIHelpers.safe_text(node)` — returns node text or empty string; checks `is_instance_valid` and node type.
  - `UIHelpers.safe_set_text(node, text)` — sets `.text` when safe.
  - `UIHelpers.build_scroll_tab(title)` — convenience builder returning a `ScrollContainer` and inner `VBoxContainer` for tabs.

Use these helpers when reading/writing `.text` or similar properties to avoid "previously freed" errors when nodes are dynamic.

**Next steps**
- Convert remaining apps to this pattern (if not already done).
- Use `UIHelpers` to replace direct `.text` reads/writes where appropriate.

