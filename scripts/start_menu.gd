extends PanelContainer
class_name StartMenuPanel

signal app_launch_requested(app_id: String)
signal create_shortcut_requested(app_id: String)
signal pin_to_taskbar_requested(app_id: String)
signal session_exit_requested
signal session_restart_requested

@onready var apps_box: VBoxContainer = $VBox/AppsBox
@onready var search_box: LineEdit = $VBox/Search
@onready var panel: PanelContainer = self
@onready var exit_button: Button = $VBox/Footer/ExitButton
@onready var restart_button: Button = $VBox/Footer/RestartButton
@onready var profile_name: Label = $VBox/ProfileBox/ProfileName

var _start_button_global: Vector2 = Vector2.ZERO
var _tween: Tween = null
var _is_animating: bool = false

const _PADDING = 12.0
const _OPEN_SCALE = Vector2(0.96, 0.92)
const _CLOSE_SCALE = Vector2(0.98, 0.98)


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	scale = _CLOSE_SCALE
	for side in ["left", "top", "right", "bottom"]:
		panel.add_theme_constant_override("margin_%s" % side, int(_PADDING))
	AppRegistry.registry_changed.connect(_rebuild)
	search_box.text_changed.connect(func(_t): _rebuild())
	_rebuild()

	# Session controls wiring
	if exit_button:
		exit_button.pressed.connect(func(): emit_signal("session_exit_requested"))
	if restart_button:
		restart_button.pressed.connect(func(): emit_signal("session_restart_requested"))


func toggle(start_button_global: Vector2, start_button_size: Vector2) -> void:
	_start_button_global = start_button_global
	if visible:
		_hide_with_animation()
		return
	_rebuild()
	_position_near_start(start_button_global, start_button_size)
	_show_with_animation()


func hide_menu() -> void:
	_hide_with_animation()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = event.position
		if not get_global_rect().has_point(pos):
			hide_menu()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide_menu()

	# Basic keyboard navigation for menu entries
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DOWN:
			_focus_next_app_item()
			return
		if event.keycode == KEY_UP:
			_focus_prev_app_item()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			var f: Node = get_tree().get_focus_owner() as Node
			if f and f is Button:
				(f as Button).emit_signal("pressed")
				return


func _rebuild() -> void:
	for c in apps_box.get_children():
		c.queue_free()
	var query: String = search_box.text.strip_edges().to_lower()
	if query != "":
		_add_flat_results(query)
		return
	var recent_ids: Array = AppRegistry.list_recent()
	var recent_manifests: Array = []
	for rid in recent_ids:
		var m := AppRegistry.get_manifest(rid)
		if not m.is_empty():
			recent_manifests.append(m)
	if not recent_manifests.is_empty():
		_add_section("Recent", recent_manifests)
	var categories: Dictionary = {}
	for manifest: Dictionary in AppRegistry.list_manifests():
		var category := String(manifest.get("category", "General"))
		categories[category] = categories.get(category, [])
		(categories[category] as Array).append(manifest)
	var cat_names := categories.keys()
	cat_names.sort()
	for cat in cat_names:
		var arr: Array = categories[cat]
		arr.sort_custom(
			func(a, b):
				return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", "")))
		)
		_add_section(String(cat), arr)


func _add_flat_results(query: String) -> void:
	var matches: Array = []
	for manifest: Dictionary in AppRegistry.list_manifests():
		var app_name := String(manifest.get("name", ""))
		var desc := String(manifest.get("description", ""))
		var author := String(manifest.get("author", ""))
		var category := String(manifest.get("category", ""))
		if (
			app_name.to_lower().find(query) != -1
			or desc.to_lower().find(query) != -1
			or author.to_lower().find(query) != -1
			or category.to_lower().find(query) != -1
		):
			matches.append(manifest)
	_add_section("Results", matches)


func _add_section(title: String, manifests: Array) -> void:
	if manifests.is_empty():
		return
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color(0.8, 0.86, 0.94))
	apps_box.add_child(label)
	for manifest: Dictionary in manifests:
		var app_id := String(manifest.get("id", ""))
		var app_name := String(manifest.get("name", app_id))
		if app_id == "":
			continue
		var icon_path := String(manifest.get("icon", ""))
		var b := Button.new()
		# ensure keyboard-focusable
		b.focus_mode = Control.FOCUS_ALL
		b.text = app_name
		b.custom_minimum_size = Vector2(0, 32)
		b.add_theme_constant_override("h_separation", 12)
		b.add_theme_color_override("font_color", Color(0.9, 0.93, 0.95))
		b.add_theme_color_override("font_color_hover", Color(1, 1, 1))
		b.add_theme_color_override("font_color_pressed", Color(0.95, 1.0, 1.0))
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
		var desc := String(manifest.get("description", "")).strip_edges()
		var author := String(manifest.get("author", "")).strip_edges()
		var version := String(manifest.get("version", ""))
		var min_shell := String(manifest.get("min_shell_version", "")).strip_edges()
		var min_ok := bool(manifest.get("min_shell_ok", true))
		var tooltip_lines: Array = []
		if desc != "":
			tooltip_lines.append(desc)
		if author != "":
			tooltip_lines.append("By %s" % author)
		if version != "":
			tooltip_lines.append("Version %s" % version)
		if min_shell != "":
			var suffix := " (requires update)" if not min_ok else ""
			tooltip_lines.append("Needs shell >= %s%s" % [min_shell, suffix])
		if not tooltip_lines.is_empty():
			b.tooltip_text = "\n".join(tooltip_lines)
			if icon_path != "" and ResourceLoader.exists(icon_path):
				var tex: Texture2D = ResourceLoader.load(icon_path) as Texture2D
				if tex is Texture2D:
					b.icon = tex
		b.pressed.connect(
			func():
				AppRegistry.record_recent(app_id)
				hide_menu()
				emit_signal("app_launch_requested", app_id)
		)

		# Right-click context menu for Create Shortcut / Pin
		b.gui_input.connect(
			func(event: InputEvent):
				if (
					event is InputEventMouseButton
					and event.button_index == MOUSE_BUTTON_RIGHT
					and event.pressed
				):
					var menu := PopupMenu.new()
					add_child(menu)
					menu.add_item("Create Desktop Shortcut", 1)
					menu.add_item("Pin to Taskbar", 2)
					menu.id_pressed.connect(
						func(id: int):
							match id:
								1:
									emit_signal("create_shortcut_requested", app_id)
								2:
									emit_signal("pin_to_taskbar_requested", app_id)
							menu.queue_free()
					)
					menu.popup(get_global_rect())
					get_viewport().set_input_as_handled()
		)
		apps_box.add_child(b)


func _position_near_start(start_global: Vector2, start_size: Vector2) -> void:
	# Place menu anchored to Start button top-left, prefer above taskbar if space.
	var menu_size := get_combined_minimum_size()
	var viewport_rect := get_viewport_rect()
	var pos := Vector2(start_global.x, start_global.y - menu_size.y)
	if pos.y < 0:
		pos.y = start_global.y + start_size.y
	if pos.x + menu_size.x > viewport_rect.size.x:
		pos.x = viewport_rect.size.x - menu_size.x
	if pos.x < 0:
		pos.x = 0
	global_position = pos


func _show_with_animation() -> void:
	visible = true
	if _tween:
		_tween.kill()
	modulate.a = 0.0
	scale = _OPEN_SCALE
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.14).set_ease(Tween.EASE_OUT).set_trans(
		Tween.TRANS_QUAD
	)
	(
		_tween
		. parallel()
		. tween_property(self, "scale", Vector2.ONE, 0.16)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)
	_is_animating = true
	_tween.finished.connect(func(): _is_animating = false)


func _hide_with_animation() -> void:
	if _is_animating and _tween:
		_tween.kill()
	if not visible:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.12).set_ease(Tween.EASE_IN).set_trans(
		Tween.TRANS_QUAD
	)
	(
		_tween
		. parallel()
		. tween_property(self, "scale", _CLOSE_SCALE, 0.12)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_QUAD)
	)
	_is_animating = true
	_tween.finished.connect(
		func():
			visible = false
			_is_animating = false
	)


func apply_palette(palette: Dictionary) -> void:
	var panel_color: Color = palette.get("panel", Color(0.12, 0.13, 0.17)) as Color
	var text_color: Color = palette.get("text", Color.WHITE) as Color
	self_modulate = panel_color
	search_box.add_theme_color_override("font_color", text_color)
	search_box.add_theme_color_override("font_color_placeholder", text_color * Color(1, 1, 1, 0.6))

	# Apply global font if ThemeManager provides one
	var tm: Node = get_tree().root.get_node_or_null("/root/ThemeManager")
	if tm != null:
		var f: Font = tm.get_font() as Font
		if f != null:
			search_box.add_theme_font_override("font", f)
			for c in apps_box.get_children():
				if c is Button:
					(c as Button).add_theme_font_override("font", f)
				elif c is Label:
					(c as Label).add_theme_font_override("font", f)


func _get_app_items() -> Array:
	var items: Array = []
	for c in apps_box.get_children():
		if c is Button:
			items.append(c)
	return items


func _focus_next_app_item() -> void:
	var items: Array = _get_app_items()
	if items.is_empty():
		return
	var cur: Control = get_tree().get_focus_owner() as Control
	var idx: int = items.find(cur) if cur in items else -1
	var next: Control = items[(idx + 1) % items.size()]
	next.grab_focus()


func _focus_prev_app_item() -> void:
	var items: Array = _get_app_items()
	if items.is_empty():
		return
	var cur: Control = get_tree().get_focus_owner() as Control
	var idx: int = items.find(cur) if cur in items else items.size()
	var prev: Control = items[(idx - 1 + items.size()) % items.size()]
	prev.grab_focus()
