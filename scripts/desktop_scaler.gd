class_name DesktopScalerControl
extends Control

const BASE_SIZE := Vector2(1080, 720)

@onready var desktop: Control = $Desktop


func _ready() -> void:
	SettingsManager.setting_changed.connect(_on_setting_changed)
	_apply_scale()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_scale()


func _on_setting_changed(_key: StringName, _value: Variant) -> void:
	_apply_scale()


func _apply_scale() -> void:
	if desktop == null:
		return
	var mode: String = String(SettingsManager.get_value("display.scale_mode", "integer"))
	var factor: float = float(SettingsManager.get_value("display.scale_factor", 1.0))
	# Clamp factor to reasonable bounds to avoid absurd scales from corrupted settings
	if factor < 0.5 or factor > 6.0:
		Log.warn("DesktopScaler: display.scale_factor out of bounds (%f); clamping to [0.5,6.0]" % factor)
		factor = clampf(factor, 0.5, 6.0)
	var win_size: Vector2 = get_viewport_rect().size
	var raw: float = minf(win_size.x / BASE_SIZE.x, win_size.y / BASE_SIZE.y) * factor
	# Clamp raw scale to safe range before applying integer/fractional logic
	raw = clampf(raw, 0.5, 6.0)
	var s: float = raw
	if mode == "integer":
		s = clampf(maxf(1.0, floorf(raw)), 1.0, 6.0)
	else:
		s = clampf(raw, 0.5, 6.0)
	# Diagnostic log to help debug invisible UI (reports viewport and computed values)
	Log.info("DesktopScaler: BASE_SIZE=%s win_size=%s raw=%f scale=%f pos=%s" % [str(BASE_SIZE), str(win_size), raw, s, str((win_size - (BASE_SIZE * s)) * 0.5)])
	#desktop.scale = Vector2(s, s)
	#desktop.position = (win_size - (BASE_SIZE * s)) * 0.5
