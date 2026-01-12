extends Node

const EXPECTED_SERVICES = [
	"CoreRuntime",
	"EventBus",
	"SaveManager",
	"SettingsManager",
	"AppRegistry",
	"InventoryManager",
	"ThemeManager",
]

const ARG_HEADLESS_TESTS = "--headless-tests"

var _start_time_ms: int = 0
var _init_log: Array = []  # Array[Dictionary]
var _announced: bool = false


func _ready() -> void:
	_start_time_ms = Time.get_ticks_msec()
	register_service("CoreRuntime")
	if OS.get_cmdline_args().has(ARG_HEADLESS_TESTS):
		call_deferred("_run_headless_tests")


func register_service(service_name: String) -> void:
	# Record deterministic init order and emit a concise log line.
	var now_ms: int = Time.get_ticks_msec()
	var entry: Dictionary = {
		"name": service_name,
		"order": _init_log.size(),
		"ms_since_boot": now_ms - _start_time_ms,
	}
	_init_log.append(entry)
	Log.info("[Init #%02d] %s ready (+%d ms)" % [entry.order + 1, entry.name, entry.ms_since_boot])
	if not _announced and _all_expected_registered():
		_announced = true
		Log.info("[Init] All core services ready in %d ms" % (now_ms - _start_time_ms))


func get_init_order() -> Array:
	# Returns a deep copy so callers cannot mutate the log.
	return _init_log.duplicate(true)


func get_ready_service_names() -> Array:
	var names: Array = []
	for e in _init_log:
		names.append(e.get("name", ""))
	return names


func has_service(service_name: String) -> bool:
	for e in _init_log:
		if String(e.get("name", "")) == service_name:
			return true
	return false


func _all_expected_registered() -> bool:
	for expected in EXPECTED_SERVICES:
		if not has_service(expected):
			return false
	return true


func quit_safely(code: int = 0) -> void:
	# Central safe exit for headless tests and runtime shutdown.
	# Before quitting, perform test cleanup: if CharacterManager supports archival cleanup, call it.
	var cm = get_tree().root.get_node_or_null("/root/CharacterManager")
	if cm != null and cm.has_method("cleanup_player_created_characters"):
		cm.cleanup_player_created_characters()
	# Also sweep transient UI (dialogs, popups, and tweens) to avoid lingering nodes at exit
	_cleanup_transient_ui()
	# Call explicit cleanup hooks on key singletons so they free timers/panels/resources now
	var sm = get_tree().root.get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("_exit_tree"):
		sm._exit_tree()
	var tm = get_tree().root.get_node_or_null("/root/TooltipManager")
	if tm != null and tm.has_method("_exit_tree"):
		tm._exit_tree()
	var dm = get_tree().root.get_node_or_null("/root/DialogManager")
	if dm != null and dm.has_method("_exit_tree"):
		dm._exit_tree()
	# Clear cached renderer textures to free Resource references
	if typeof(CharacterRenderer) != TYPE_NIL:
		# call static cleanup if available
		if "cleanup_cache" in CharacterRenderer:
			CharacterRenderer.cleanup_cache()
	# Log node snapshot for diagnostics (helps identify leaked nodes)
	_log_node_snapshot()
	# Call quit() to allow clean teardown. Also schedule a short delayed watchdog
	# that re-invokes quit() in case the process does not exit promptly.
	get_tree().quit(code)
	# Schedule a watchdog timer to force another quit after 2 seconds to avoid hangs
	var t = get_tree().create_timer(2.0)
	if t:
		t.timeout.connect(Callable(self, "_on_force_quit"))
		self.set_meta("_forced_quit_code", int(code))

func _log_node_snapshot() -> void:
	var root = get_tree().get_root()
	Log.info("CoreRuntime: Node snapshot (root child count=%d)" % root.get_child_count())
	for child in root.get_children():
		var cls = child.get_class()
		Log.info(" - %s (%s) children=%d" % [child.name, cls, child.get_child_count()])
		# list first-level children
		for c in child.get_children():
			Log.info("   - %s (%s)" % [c.name, c.get_class()])


func _cleanup_transient_ui() -> void:
	var root = get_tree().get_root()
	# Free common dialog/popup classes
	for child in root.get_children():
		var cls = child.get_class()
		if cls == "ConfirmationDialog" or cls == "AcceptDialog" or cls == "Popup":
			Log.info("CoreRuntime: freeing transient UI %s" % cls)
			# Use free() to ensure immediate removal during shutdown
			child.free()
	# Also sweep for any Tween nodes anywhere under root
	var stack = [root]
	while stack.size() > 0:
		var node = stack.pop_back()
		for c in node.get_children():
			if is_instance_valid(c) and c.get_class().find("Tween") != -1:
				Log.info("CoreRuntime: freeing Tween attached to %s" % node.name)
				# Try to stop the tween if it exposes the stop_all method
				if c.has_method("stop_all"):
					c.stop_all()
				c.queue_free()
			else:
				stack.append(c)

func _on_force_quit() -> void:
	var code = int(self.get_meta("_forced_quit_code", 1))
	Log.error("CoreRuntime: Force quit triggered; calling get_tree().quit(%d)" % code)
	get_tree().quit(code)

@export var headless_watchdog_seconds: float = 60.0

func _run_headless_tests() -> void:
	# Start the comprehensive headless test runner if present.
	var runner_path := "res://tests/comprehensive_headless.gd"
	if not ResourceLoader.exists(runner_path):
		Log.error("CoreRuntime: headless test runner not found: %s" % runner_path)
		# Ensure we still exit to avoid hanging in CI
		get_tree().quit(1)
		return

	var RunnerScene: Script = load(runner_path)
	if RunnerScene == null:
		Log.error("CoreRuntime: failed to load headless runner: %s" % runner_path)
		get_tree().quit(1)
		return
	var runner: Node = RunnerScene.new()
	# Ensure headless tests run with a clean progression state to avoid flakes
	var g: Dictionary = SaveManager.load_global()
	if g.has("progression"):
		g["progression"] = {}
		SaveManager.save_global(g)
		SaveManager.refresh_global()
	get_tree().root.add_child(runner)
	Log.info("CoreRuntime: Headless tests launched.")
	# Start watchdog to ensure process can't hang indefinitely
	call_deferred("_start_headless_watchdog")
	# If running headless tests, enable CharacterManager archival of created characters
	var cm = get_tree().root.get_node_or_null("/root/CharacterManager")
	if cm != null and cm.has_method("_ensure_player_created_dir"):
		cm.archive_on_create = true

func _start_headless_watchdog() -> void:
	if headless_watchdog_seconds <= 0:
		return
	var t = get_tree().create_timer(headless_watchdog_seconds)
	if t:
		t.timeout.connect(Callable(self, "_on_headless_timeout"))

func _on_headless_timeout() -> void:
	Log.error("CoreRuntime: Headless tests did not complete within %s seconds; forcing exit." % str(headless_watchdog_seconds))
	get_tree().quit(1)
