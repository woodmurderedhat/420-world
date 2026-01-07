extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	# Basic UIHelpers sanity checks
	var btn := Button.new()
	UIHelpers.safe_set_text(btn, "Test")
	if UIHelpers.safe_text(btn) != "Test":
		print("UIHelpers test failed: Button text mismatch")
		quit(1)

	var cp := ColorPickerButton.new()
	UIHelpers.safe_set_color(cp, Color(0.25, 0.5, 0.75, 1))
	var html := UIHelpers.safe_color_to_html(cp)
	if html == "":
		print("UIHelpers test failed: Color to HTML empty")
		quit(1)

	var parsed := UIHelpers.safe_color_from_html(html)
	if parsed == Color(0,0,0,0):
		print("UIHelpers test failed: Color from HTML returned transparent")
		quit(1)

	var slider := HSlider.new()
	UIHelpers.safe_set_value(slider, 1.25)
	if abs(UIHelpers.safe_value(slider) - 1.25) > 0.001:
		print("UIHelpers test failed: Slider value mismatch")
		quit(1)

	var tex_rect := TextureRect.new()
	UIHelpers.safe_set_texture(tex_rect, null)
	if tex_rect.texture != null:
		print("UIHelpers test failed: TextureSet mismatch")
		quit(1)

	print("UIHelpers tests passed")
	quit(0)
