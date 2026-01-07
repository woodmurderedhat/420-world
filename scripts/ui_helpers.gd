class_name UIHelpers

static func safe_text(node: Node) -> String:
	if not is_instance_valid(node):
		return ""
	if node is Label or node is LineEdit or node is TextEdit or node is Button:
		return String(node.text)
	return ""

static func safe_set_text(node: Node, text: String) -> void:
	if not is_instance_valid(node):
		return
	if node is Label or node is LineEdit or node is TextEdit or node is Button:
		node.text = text

static func build_scroll_tab(title: String) -> Dictionary:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.name = title
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vbox)
	return {"scroll": sc, "vbox": vbox}

static func safe_color(node: Node) -> Color:
	if not is_instance_valid(node):
		return Color(0,0,0,0)
	if node is ColorPickerButton:
		return node.color
	if "color" in node:
		return node.color
	return Color(0,0,0,0)

static func safe_set_color(node: Node, c: Color) -> void:
	if not is_instance_valid(node):
		return
	if node is ColorPickerButton:
		node.color = c
		return
	if "color" in node:
		node.color = c
		return

	# Fallback: if node supports modulate, try that
	if "modulate" in node:
		node.modulate = c

static func safe_color_to_html(node: Node) -> String:
	if not is_instance_valid(node):
		return ""
	if node is ColorPickerButton:
		return node.color.to_html()
	return ""

static func safe_color_from_html(s: String) -> Color:
	if s == null or s == "":
		return Color(0,0,0,0)
	# Color constructor accepts HTML formats like "#rrggbb" or "#rrggbbaa"
	# Wrap in try/catch semantics using typeof checks
	var c: Color
	# Attempt to create Color; if invalid, return transparent
	c = Color(0,0,0,0)
	# Use a simple parse: Color constructor will handle valid html strings
	# Guard against exceptions by checking string prefix
	if s.begins_with("#") or s.find("rgb") != -1:
		c = Color(s)
	return c

static func safe_value(node: Node) -> float:
	if not is_instance_valid(node):
		return 0.0
	if node is HSlider or node is VSlider or node is Range:
		return float(node.value)
	return 0.0

static func safe_set_value(node: Node, v: float) -> void:
	if not is_instance_valid(node):
		return
	if node is HSlider or node is VSlider or node is Range:
		node.value = v

static func safe_set_texture(node: Node, tex) -> void:
	if not is_instance_valid(node):
		return
	if node is TextureRect:
		node.texture = tex

static func safe_get_selected_text(node: Node) -> String:
	if not is_instance_valid(node):
		return ""
	if node is OptionButton:
		if node.selected >= 0 and node.selected < node.get_item_count():
			return node.get_item_text(node.selected)
	return ""

static func safe_bool(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node is CheckBox:
		return bool(node.button_pressed)
	if node is Button:
		if node.has_method("is_pressed"):
			return bool(node.is_pressed())
		if "pressed" in node:
			return bool(node.pressed)
	return false

static func safe_set_bool(node: Node, v: bool) -> void:
	if not is_instance_valid(node):
		return
	if node is CheckBox:
		node.button_pressed = v
	elif node is Button:
		# Prefer a setter method when available to avoid assigning readonly properties
		if node.has_method("set_pressed"):
			node.set_pressed(v)
		elif "pressed" in node and node.has_method("is_pressed"):
			# No setter available; emulate by toggling if necessary
			if bool(node.is_pressed()) != v and node.has_method("toggle"):
				node.toggle()

static func safe_set_disabled(node: Node, v: bool) -> void:
	if not is_instance_valid(node):
		return
	if "disabled" in node:
		node.disabled = v

static func safe_set_modulate(node: Node, c: Color) -> void:
	if not is_instance_valid(node):
		return
	if "modulate" in node:
		node.modulate = c
