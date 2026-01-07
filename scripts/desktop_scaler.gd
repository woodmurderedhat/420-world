extends Control
class_name DesktopScaler

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
	var mode := String(SettingsManager.get_value("display.scale_mode", "integer"))
	var factor := float(SettingsManager.get_value("display.scale_factor", 1.0))
	var win_size := get_viewport_rect().size
	var raw := minf(win_size.x / BASE_SIZE.x, win_size.y / BASE_SIZE.y) * factor
	var s := raw
	if mode == "integer":
		s = maxf(1.0, floorf(raw))
	else:
		s = clampf(raw, 0.5, 6.0)
	desktop.scale = Vector2(s, s)
	desktop.position = (win_size - (BASE_SIZE * s)) * 0.5
