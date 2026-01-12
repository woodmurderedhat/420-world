# Character Creator — Overview 📚

This folder contains the modular sub-apps that make up the Character Creator. Each sub-app is self-contained (has an entry scene and a `manifest.json`) and can be used standalone, embedded in other scenes, or wired together by the `CharacterCreator` coordinator.

Modules (link to per-module README):
- **Gallery** — `res://apps/character_creator/gallery/gallery.tscn` (`apps/character_creator/gallery/README.md`)
- **Graveyard** — `res://apps/character_creator/graveyard/graveyard.tscn` (`apps/character_creator/graveyard/README.md`)
- **Part Selector** — `res://apps/character_creator/part_selector/part_selector.tscn` (`apps/character_creator/part_selector/README.md`)
- **Templates** — `res://apps/character_creator/templates/templates.tscn` (`apps/character_creator/templates/README.md`)
- **Stat Inputs** — `res://apps/character_creator/stat_inputs/stat_inputs.tscn` (`apps/character_creator/stat_inputs/README.md`)
- **Details** — `res://apps/character_creator/details/details.tscn` (`apps/character_creator/details/README.md`)
- **Shortcuts** — `res://apps/character_creator/shortcuts/shortcuts.tscn` (`apps/character_creator/shortcuts/README.md`)
- **Components** — reusable controls such as `components/container_slot/character_container_slot.tscn` (`apps/character_creator/components/.../README.md`)

Quick wiring patterns 🔧

- Embed the main Character Creator and enable gallery wrap-around navigation (safe in tests):

```
var cc = load("res://apps/character_creator/character_creator.tscn").instantiate()
add_child(cc)
# Prefer set() in tests/dynamic contexts (avoids binding order issues):
cc.set("gallery_wrap_navigation", true)
cc._connect_ui()
# Access module instances when built
cc._ui.gallery.connect("character_selected", Callable(self, "_on_character_selected"))
```

- Embed the Part Selector and connect to changes:

```
var ps = load("res://apps/character_creator/part_selector/part_selector.tscn").instantiate()
add_child(ps)
ps.build(ps.get_node_or_null("PartsVBox"), {"head":"head_01"})
ps.connect("part_changed", Callable(self, "_on_part_changed"))
```

Headless testing snippets (copy-paste):

- Simulate a confirm dialog response:
```
DialogManager.show_confirm("Delete?","Are you sure?", func(res): /* callback */ )
for c in get_tree().get_root().get_children():
	if c is ConfirmationDialog:
		c.emit_signal("confirmed")  # or "canceled"
		break
await get_tree().process_frame
```

- Simulate a keypress in tests:
```
var e := InputEventKey.new()
e.keycode = Key.KEY_DELETE
e.pressed = true
cc._unhandled_input(e)
await get_tree().process_frame
```

Testing references ✔️
- Use the comprehensive suite and the following focused tests as examples:
  - `tests/focus_wrap_wraparound_test.gd` — left/right wrap-around
  - `tests/focus_wrap_updown_edgecases_test.gd` — up/down wrap edge-cases
  - `tests/a11y_keyboard_extra_permutations_test.gd` — keyboard permutations + confirm flows
  - `tests/confirm_popup_timeout_test.gd` — confirm dialogs don't auto-timeout

Notes
- Default gallery navigation is *clamped*; wrap-around must be explicitly enabled.
- If you'd like, I can add a short paragraph at the top of each module README that points to this overview page.
