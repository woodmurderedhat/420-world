extends "res://scripts/app_base.gd"

@onready var templates_dir := "res://apps/character_creator/templates/"
var templates: Array = []
var current_viewing_character_id: String = ""
var active_tab: int = 0
var scroll_positions: Dictionary = {}
var stat_inputs: Dictionary = {}

# Optional behavior: when true, arrow navigation in the gallery wraps around (last->first and vice versa)
@export var gallery_wrap_navigation: bool = false

# State flag indicating the UI coordinator was successfully built
var ui_ready: bool = false

@onready var LogicClass := preload("res://apps/character_creator/character_creator_logic.gd")
var logic: CharacterCreatorLogic = null

var GalleryClass: Script = null
var gallery: Node = null

var GraveyardClass: Script = null
var graveyard: Node = null

func _ready() -> void:
	# Lazy init
	Log.info("CharacterCreator._ready: invoked")
	BodyPartRegistry.load_all_parts()
	# Initialize logic module and templates
	logic = CharacterCreatorLogic.new()
	logic.templates_dir = templates_dir
	logic.load_templates()
	templates = logic.get_templates()

	# Load optional modules at runtime to avoid preload-time parse failures
	GalleryClass = load("res://apps/character_creator/gallery/character_gallery.gd")
	GraveyardClass = load("res://apps/character_creator/graveyard/character_graveyard.gd")

	# Wire UI callbacks now so tests can exercise the UI immediately
	_connect_ui()
	# Try again next frame in case some nodes are not ready yet
	call_deferred("_connect_ui")

func _load_templates() -> void:
	# Delegate template loading to logic module
	if logic == null:
		logic = CharacterCreatorLogic.new()
		logic.templates_dir = templates_dir
	logic.load_templates()
	templates = logic.get_templates()

	# Wire UI callbacks now so tests can exercise the UI immediately
	_connect_ui()

func _connect_ui() -> void:
	Log.info("CharacterCreator._connect_ui: invoked")
	# Delegate heavy UI wiring to CharacterCreatorUI
	if CharacterCreatorUI == null:
		CharacterCreatorUI = load("res://apps/character_creator/character_creator_ui.gd")
	# If loading failed, log and bail; this keeps headless tests from crashing
	if CharacterCreatorUI == null:
		Log.error("CharacterCreator._connect_ui: failed to load CharacterCreatorUI script; aborting UI connect")
		return
	if _ui == null:
		_ui = CharacterCreatorUI.new()
		add_child(_ui)
		if _ui.has_method("build"):
			_ui.build(self)
		else:
			Log.warn("CharacterCreator._connect_ui: UI script missing build() method")
		Log.info("CharacterCreator._connect_ui: created _ui")
		ui_ready = true

	# Listen to unlock events and container changes (these are lightweight and kept here)
	if not ProgressionManager.body_part_unlocked.is_connected(Callable(self, "_on_body_part_unlocked")):
		ProgressionManager.body_part_unlocked.connect(_on_body_part_unlocked)
	# Use a named handler for inventory changes so we can guard against duplicate connects
	if not InventoryManager.container_inventory_changed.is_connected(Callable(self, "_on_container_inventory_changed")):
		InventoryManager.container_inventory_changed.connect(self._on_container_inventory_changed)

	# Ensure UI modules refresh
	if _ui != null:
		_ui.refresh_all()
	else:
		Log.warn("CharacterCreator._connect_ui: _ui still null after attempt; will try on refresh")
		# fallthrough to refresh calls will attempt to build if possible
		_refresh_gallery()
		_refresh_graveyard()

func _on_ui_built() -> void:
	# Callback invoked by CharacterCreatorUI when gallery and core UI parts are wired
	ui_ready = true
	Log.info("CharacterCreator: UI signaled built (ui_ready=true)")

# --- UI state persistence ---
func save_state() -> Dictionary:
	return {
		"currently_viewing_character_id": current_viewing_character_id,
		"active_tab": active_tab,
		"scroll_positions": scroll_positions
	}

func load_state(data: Dictionary) -> void:
	# Defensive: sometimes callers pass non-dictionary values (eg. a Node) by mistake. Guard and log.
	if typeof(data) != TYPE_DICTIONARY:
		Log.warn("CharacterCreator.load_state: expected Dictionary but got %s (%s)" % [str(typeof(data)), str(data)])
		return
	if data.has("currently_viewing_character_id"):
		current_viewing_character_id = data["currently_viewing_character_id"]
	if data.has("active_tab"):
		active_tab = int(data["active_tab"])
	if data.has("scroll_positions"):
		scroll_positions = data["scroll_positions"]

# --- Helper APIs used by UI ---
func get_templates() -> Array:
	return templates

func validate_name(candidate_name: String) -> Dictionary:
	# Delegate to logic module (ensures consistent validation)
	if logic == null:
		logic = CharacterCreatorLogic.new()
		logic.templates_dir = templates_dir
		logic.load_templates()
	return logic.validate_name(candidate_name)

func _on_create_pressed() -> void:
	var name_input = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#NameInput")
	var cat_input = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#CategoryInput")
	var status = get_node_or_null("./MainLayout/MainTab/MainTab#Creation/MainTab_Creation#RightPane/MainTab_Creation_RightPane#StatusLabel")
	if name_input == null:
		return
	var char_name: String = name_input.text.strip_edges()
	var category = ""
	if cat_input:
		category = cat_input.text.strip_edges()

	# Use selected parts (live from UI)
	var body_parts = selected_parts.duplicate()

	# Read stats from UI
	var stats = {}
	if stat_inputs.is_empty():
		# Fallback
		stats = {"gold":5,"agility":5,"strength":5,"intelligence":5,"constitution":5,"luck":5}
	else:
		for k in stat_inputs:
			stats[k] = int(stat_inputs[k].value)

	var res = create_character_from_ui(char_name, category, body_parts, stats)
	if not res["ok"]:
		if status: status.text = "Error: %s" % res["error"]
		Log.error("Character Creator: %s" % res["error"])
	else:
		if status: status.text = "Created %s" % char_name
		Log.info("Character Creator: Created %s" % char_name)
		# Clear input
		name_input.text = ""
		if cat_input: cat_input.text = ""
		# Refresh gallery
		_refresh_gallery()


func _on_category_selected(_index: int) -> void:
	_refresh_gallery()

# --- Gallery signal handlers (delegated)
func _on_gallery_export_requested(char_id: String) -> void:
	var path = CharacterManager.export_character(char_id)
	if path != "":
		DialogManager.show_toast("Exported: " + path)

func _on_gallery_delete_requested(char_id: String) -> void:
	DialogManager.show_confirm("Delete?", "Delete %s?" % CharacterManager.get_character(char_id).get("name", ""), func(yes):
		if yes:
			CharacterManager.soft_delete_character(char_id)
			if gallery != null:
				gallery.refresh()
			else:
				_refresh_gallery()
			DialogManager.show_toast("Moved %s to Graveyard" % CharacterManager.get_character(char_id).get("name", ""))
		)

func _on_gallery_new_requested() -> void:
	var tb := get_node_or_null("./MainLayout/MainTab")
	if tb:
		tb.current_tab = 0

func _on_gallery_purchase_requested() -> void:
	CharacterManager.purchase_character_slot()
	DialogManager.show_toast("Opened shop for character slots")

# --- Graveyard signal handlers
func _on_graveyard_cleared() -> void:
	# Refresh gallery and graveyard UI when the graveyard is cleared
	if gallery != null:
		gallery.refresh()
	else:
		_refresh_gallery()

func _on_graveyard_entry_purged(index: int, name: String) -> void:
	# Refresh gallery and graveyard after a purge
	if gallery != null:
		gallery.refresh()
	else:
		_refresh_gallery()
	# Optionally show a toast was already shown by graveyard module, but keep this hook for further actions


func _refresh_gallery() -> void:
	# Ensure UI wiring attempted (helps tests that call refresh after dynamic scene changes)
	if _ui == null:
		_connect_ui()
	# Prefer UI coordinator when available
	if _ui != null:
		if _ui.has_method("refresh_all"):
			_ui.refresh_all()
			return
		else:
			Log.warn("CharacterCreator._refresh_gallery: _ui has no refresh_all(); will fallback to gallery if available")
	# Prefer scene-instanced gallery if the UI created one
	if _ui != null and _ui.has_method("gallery") and _ui.gallery != null:
		_ui.gallery.refresh()
		return
	# Fallback to gallery module if present
	if gallery != null:
		gallery.refresh()
		return
	# Nothing to do if neither UI coordinator nor gallery module is available
	Log.warn("CharacterCreator._refresh_gallery: no gallery UI available to refresh")

# --- Part Selection UI (delegated to CharacterPartSelector) ---
var parts_vbox: VBoxContainer = null
var preview_tex: TextureRect = null
var selected_parts: Dictionary = {"head":"head_01","eyes":"eyes_01","mouth":"mouth_01","hair":"hair_01","body":"body_01","arms":"arms_01","hands":"hands_01","legs":"legs_01","feet":"feet_01"}
var selected_character_id: String = ""

# Local references to modules (preload to ensure static typing)
var PartSelector = preload("res://apps/character_creator/part_selector/character_part_selector.gd")
var _part_selector: Node = null
var StatInputs = preload("res://apps/character_creator/stat_inputs/character_stat_inputs.gd")
var _stat_inputs: Node = null
var TemplatesUI = preload("res://apps/character_creator/templates/character_templates_ui.gd")
var _templates_ui: Node = null
var DetailsClass: Script = preload("res://apps/character_creator/details/character_details.gd")
var _details: Node = null
var ShortcutsClass = preload("res://apps/character_creator/shortcuts/character_shortcuts.gd")
var _shortcuts: Node = null
var CharacterCreatorUI: Script = null
var _ui: CharacterCreatorUI = null

func _build_part_selection() -> void:
	# Deprecated: part selection is now handled by `CharacterPartSelector` module. Use the `CharacterCreatorUI` coordinator instead.
	Log.warn("CharacterCreator._build_part_selection is deprecated; use CharacterPartSelector")
	return

func _build_stat_inputs() -> void:
	# Deprecated: stat inputs are now handled by `CharacterStatInputs` module. Use the `CharacterCreatorUI` coordinator instead.
	Log.warn("CharacterCreator._build_stat_inputs is deprecated; use CharacterStatInputs")
	return

func _build_template_buttons() -> void:
	# Deprecated: template button UI is now handled by `CharacterTemplatesUI` module. Use the `CharacterCreatorUI` coordinator instead.
	Log.warn("CharacterCreator._build_template_buttons is deprecated; use CharacterTemplatesUI")
	return

func _apply_template(tmpl: Dictionary) -> void:
	# Maintain compatibility: delegate template application to logic and StatInputs module
	if logic == null:
		logic = CharacterCreatorLogic.new()
		logic.templates_dir = templates_dir
		logic.load_templates()
	var stats_dict = _stat_inputs.get_stats() if _stat_inputs != null else _stat_inputs_to_dict()
	var result = logic.apply_template(tmpl, selected_parts, stats_dict)
	selected_parts = result["parts"]
	var stats = result.get("stats", {})
	if _stat_inputs != null:
		_stat_inputs.set_stats(stats)
	else:
		for s in stats:
			if stat_inputs.has(s):
				stat_inputs[s].value = int(stats[s])
	_update_preview()
	DialogManager.show_toast("Applied template: %s" % tmpl.get("name", ""))

func _on_part_selected(type: String, part_id: String) -> void:
	selected_parts[type] = part_id
	_update_preview()

func _update_preview() -> void:
	if preview_tex == null: return
	var tex = CharacterRenderer.render_character(selected_parts)
	preview_tex.texture = tex

func _on_body_part_unlocked(_part_id: String) -> void:
	# Rebuild parts (simple approach)
	_build_part_selection()

func _on_container_inventory_changed(cid: String) -> void:
	# Named handler for InventoryManager.container_inventory_changed
	if cid == selected_character_id:
		_refresh_character_inventory(cid)

func _stat_inputs_to_dict() -> Dictionary:
	var out: Dictionary = {}
	for k in stat_inputs:
		out[k] = int(stat_inputs[k].value)
	return out

func _refresh_graveyard() -> void:
	# Prefer UI coordinator when available
	if _ui != null:
		_ui.refresh_all()
		return
	# Prefer scene-instanced graveyard if UI created one
	if _ui != null and _ui.has_method("graveyard") and _ui.graveyard != null:
		_ui.graveyard.refresh()
		return
	# Fallback to graveyard module if present
	if graveyard != null:
		graveyard.refresh()
		return
	# Nothing to do if neither UI coordinator nor graveyard module is available
	Log.warn("CharacterCreator._refresh_graveyard: no graveyard UI available to refresh")

# --- Focus visuals helpers ---
func _on_card_focus_entered(card: Button) -> void:
	card.modulate = Color(0.95, 1.0, 0.95, 1.0)
	# Optional: add a small border by adjusting style if desired

func _on_card_focus_exited(card: Button) -> void:
	card.modulate = Color(1, 1, 1, 1)

# --- Accessibility: keyboard shortcuts ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# 'N' to open New Character tab
		if event.keycode == Key.KEY_N:
			var tb = get_node_or_null("./MainLayout/MainTab")
			if tb:
				tb.current_tab = 0
				DialogManager.show_toast("New Character (N)")
		# Delete focused character with Delete key
		elif event.keycode == Key.KEY_DELETE:
			var focused = UIHelpers.get_focus_owner()
			var target = focused
			# Fallback: find focused-like child in gallery if global focus not available
			if target == null:
				var grid = get_node_or_null("./MainLayout/MainTab/Gallery/GalleryList/GalleryGrid/GalleryVBox")
				if grid != null:
					for ch in grid.get_children():
						if ch.name.begins_with("char_card_"):
							if (ch.has_method("is_focused") and ch.is_focused()) or (ch.has_method("has_focus") and ch.has_focus()):
								target = ch
								break
			# Debug: log delete-key target to help headless diagnostics
			Log.info("CharacterCreator._unhandled_input: DELETE pressed. target=%s" % str(target))
			if target != null and target.name.begins_with("char_card_"):
				var cid = target.name.replace("char_card_", "")
				DialogManager.show_confirm("Delete Character?", "Delete %s? This is permanent." % CharacterManager.get_character(cid).get("name", ""), func(confirmed):
					if confirmed:
						CharacterManager.soft_delete_character(cid)
						_refresh_gallery()
						DialogManager.show_toast("Moved %s to Graveyard" % CharacterManager.get_character(cid).get("name", ""))
					)
		# Arrow key navigation for gallery
		elif event.keycode in [Key.KEY_LEFT, Key.KEY_RIGHT, Key.KEY_UP, Key.KEY_DOWN]:
			var grid = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryGrid/MainTab_Gallery_GalleryList_GalleryGrid#GalleryVBox")
			if grid == null: return
			var cards = []
			for ch in grid.get_children():
				if ch.name.begins_with("char_card_"):
					cards.append(ch)
			if cards.size() == 0: return
			var focused = UIHelpers.get_focus_owner()
			var idx = 0
			if focused != null and focused.name.begins_with("char_card_"):
				idx = cards.find(focused)
			var cols = 4
			var target = idx
			var wrap := gallery_wrap_navigation
			match event.keycode:
				Key.KEY_LEFT:
					if idx == 0 and wrap:
						target = cards.size() - 1
					else:
						target = max(0, idx - 1)
				Key.KEY_RIGHT:
					if idx == cards.size() - 1 and wrap:
						target = 0
					else:
						target = min(cards.size() - 1, idx + 1)
				Key.KEY_UP:
					if idx - cols < 0:
						if wrap and cards.size() > 0:
							var rows = int((cards.size() + cols - 1) / cols)
							var new_idx = idx + cols * (rows - 1)
							target = new_idx % cards.size()
						else:
							target = max(0, idx - cols)
					else:
						target = max(0, idx - cols)
				Key.KEY_DOWN:
					if idx + cols >= cards.size():
						if wrap and cards.size() > 0:
							target = (idx + cols) % cards.size()
						else:
							target = min(cards.size() - 1, idx + cols)
					else:
						target = min(cards.size() - 1, idx + cols)
			if target != idx:
				cards[target].grab_focus()
		# Enter to select focused card
		elif event.keycode == Key.KEY_ENTER or event.keycode == Key.KEY_KP_ENTER:
			var focused = UIHelpers.get_focus_owner()
			if focused != null and focused.name.begins_with("char_card_"):
				var cid = focused.name.replace("char_card_", "")
				_on_character_selected(cid)

func _on_character_selected(char_id: String) -> void:
	selected_character_id = char_id
	# Use CharacterDetails module if available
	if _details == null:
		# create details helper when necessary
		_details = DetailsClass.new()
		add_child(_details)
	# Show selected character UI
	_details.show_character(char_id)
	var slot_info = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#GalleryList/MainTab_Gallery_GalleryList#GalleryTop/MainTab_Gallery_GalleryList_GalleryTop#SlotCounter")
	if slot_info:
		var used = CharacterManager.get_character_inventory_count(char_id)
		slot_info.text = "%d items in character inventory" % used
	# Keep graveyard in sync
	_refresh_graveyard()

func _refresh_character_inventory(char_id: String) -> void:
	# Delegated to CharacterDetails if present
	if _details != null:
		_details.show_character(char_id)
		return
	# Fallback: original inline behaviour
	var grid = get_node_or_null("./MainLayout/MainTab/MainTab#Gallery/MainTab_Gallery#Details/MainTab_Gallery_Details#InventoryGrid")
	if not grid: return
	for ch in grid.get_children():
		ch.queue_free()
	InventoryManager.create_container(char_id, CharacterManager.get_character(char_id).get("inventory_capacity", 10))
	var slots = InventoryManager.get_container_slots(char_id)
	for i in range(slots.size()):
		var panel = load("res://apps/character_creator/components/container_slot/character_container_slot.tscn").instantiate()
		grid.add_child(panel)
		if panel.has_method("setup"):
			panel.setup(char_id, i, slots[i])

	if InventoryManager.container_inventory_changed.is_connected(_on_container_changed):
		InventoryManager.container_inventory_changed.disconnect(_on_container_changed)
	InventoryManager.container_inventory_changed.connect(_on_container_changed)

func _on_container_changed(cid: String) -> void:
	if cid == selected_character_id:
		_refresh_character_inventory(cid)


func create_character_from_ui(char_name: String, category: String, body_parts: Dictionary, stats: Dictionary) -> Dictionary:
	if logic == null:
		logic = CharacterCreatorLogic.new()
		logic.templates_dir = templates_dir
		logic.load_templates()
	var res = logic.create_character_from_data(char_name, category, body_parts, stats)
	if res.has("ok") and res["ok"]:
		call_deferred("_refresh_gallery")
	return res
