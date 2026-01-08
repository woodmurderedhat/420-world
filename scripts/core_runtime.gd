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
	get_tree().quit(code)


func _run_headless_tests() -> void:
	pass
	#var RunnerScene: Script = preload("res://tests/comprehensive_headless.gd")
	#var runner: Node = RunnerScene.new()
	#get_tree().root.add_child(runner)
	## DialogManager may initialize after CoreRuntime; avoid hard warning here.
