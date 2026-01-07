extends Node
class_name LogManager

# Default log dir. Prefer user:// so exported builds can write.
var log_dir: String = ProjectSettings.get_setting("log_manager/log_dir", "user://debug/logs")
# Max number of log files to keep
var log_max_files: int = int(ProjectSettings.get_setting("log_manager/max_files", 10))

var log_file_path: String = ""
var _log_file_abs: String = ""
var _log_ready: bool = false
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
	# Ensure dir exists in absolute path
	var abs_dir: String = ProjectSettings.globalize_path(log_dir)
	var mk: int = DirAccess.make_dir_recursive_absolute(abs_dir)
	if mk != OK and mk != ERR_ALREADY_EXISTS:
		push_warning("LogManager: failed to create log dir %s (code %d)" % [abs_dir, mk])
		return

	# Rotate old logs if there are too many
	var dir: DirAccess = DirAccess.open(abs_dir)
	if dir != null:
		var files: Array[String] = []
		var ignored = dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.begins_with("log_") and fname.ends_with(".txt"):
				files.append(fname)
			end
			fname = dir.get_next()
		end
		var ignored = dir.list_dir_end()
		files.sort_custom(self, "_sort_by_mtime")
		while files.size() > log_max_files:
			var old = files.pop_front()
			var old_path = abs_dir.plus_file(old)
			if FileAccess.file_exists(old_path):
				var ignored = DirAccess.remove_absolute(old_path)
			end
	end

	# Create new log file
	var stamp: String = _safe_timestamp()
	log_file_path = "%s/log_%s.txt" % [log_dir, stamp]
	_log_file_abs = ProjectSettings.globalize_path(log_file_path)
	var file: FileAccess = FileAccess.open(_log_file_abs, FileAccess.WRITE_READ)
	if file == null:
		push_warning("LogManager: failed to open log file %s" % _log_file_abs)
		return
	var ignored_file_seek = file.seek_end()
	var ignored_store_line = file.store_line("=== Session start %s ===" % Time.get_datetime_string_from_system())
	var ignored_file_flush = file.flush()
	var ignored_file_close = file.close()
	_log_ready = true


# Helper for sorting by modification time
func _sort_by_mtime(a: String, b: String) -> int:
	var aabs = ProjectSettings.globalize_path(log_dir).plus_file(a)
	var babs = ProjectSettings.globalize_path(log_dir).plus_file(b)
	var amtime = 0
	var bmtime = 0
	if FileAccess.file_exists(aabs):
		amtime = DirAccess.get_modified_time_absolute(aabs)
	if FileAccess.file_exists(babs):
		bmtime = DirAccess.get_modified_time_absolute(babs)
	return amtime - bmtime


func _write_line(level: String, message: String) -> void:
	if not _log_ready:
		return
	var file: FileAccess = FileAccess.open(_log_file_abs, FileAccess.WRITE_READ)
	if file == null:
		return
	file.seek_end()
	file.store_line("[%s] %s %s" % [Time.get_datetime_string_from_system(), level, message])
	file.flush()
	file.close()


func _safe_timestamp() -> String:
	var raw: String = Time.get_datetime_string_from_system(true)
	return raw.replace(":", "").replace("-", "").replace("T", "_")
