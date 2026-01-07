extends Node
class_name LogManager

const LOG_DIR := "res://debug/logs"

var log_file_path: String = ""
var _log_file_abs: String = ""
var _log_ready := false
var _warning_messages: Array[String] = []
var _error_messages: Array[String] = []

func _ready() -> void:
	_setup_log_file()

func error(message: String) -> void:
	push_error(message)
	_error_messages.append(message)
	_write_line("ERROR", message)

func warn(message: String) -> void:
	push_warning(message)
	_warning_messages.append(message)
	_write_line("WARN", message)

func info(message: String) -> void:
	print(message)
	_write_line("INFO", message)

func get_warning_count() -> int:
	return _warning_messages.size()

func get_error_count() -> int:
	return _error_messages.size()

func get_warnings() -> Array[String]:
	return _warning_messages.duplicate(true)

func get_errors() -> Array[String]:
	return _error_messages.duplicate(true)

func reset_counters() -> void:
	_warning_messages.clear()
	_error_messages.clear()


func _setup_log_file() -> void:
	var abs_dir := ProjectSettings.globalize_path(LOG_DIR)
	var mk := DirAccess.make_dir_recursive_absolute(abs_dir)
	if mk != OK and mk != ERR_ALREADY_EXISTS:
		push_warning("LogManager: failed to create log dir %s (code %d)" % [abs_dir, mk])
		return
	var stamp := _safe_timestamp()
	log_file_path = "%s/log_%s.txt" % [LOG_DIR, stamp]
	_log_file_abs = ProjectSettings.globalize_path(log_file_path)
	var file := FileAccess.open(_log_file_abs, FileAccess.WRITE_READ)
	if file == null:
		push_warning("LogManager: failed to open log file %s" % _log_file_abs)
		return
	file.seek_end()
	file.store_line("=== Session start %s ===" % Time.get_datetime_string_from_system())
	file.flush()
	file.close()
	_log_ready = true

func _write_line(level: String, message: String) -> void:
	if not _log_ready:
		return
	var file := FileAccess.open(_log_file_abs, FileAccess.WRITE_READ)
	if file == null:
		return
	file.seek_end()
	file.store_line("[%s] %s %s" % [Time.get_datetime_string_from_system(), level, message])
	file.flush()
	file.close()

func _safe_timestamp() -> String:
	var raw := Time.get_datetime_string_from_system(true)
	return raw.replace(":", "").replace("-", "").replace("T", "_")
