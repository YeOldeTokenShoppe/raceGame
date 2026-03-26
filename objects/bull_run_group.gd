extends Node

var total_candles := 3
var collected := 0

func candle_collected(vehicle: Node3D):
	collected += 1
	if collected >= total_candles:
		_trigger_bull_run(vehicle)

func _trigger_bull_run(vehicle: Node3D):
	if vehicle.has_method("start_bull_run"):
		vehicle.start_bull_run()

	# Flash "BULL RUN!" text
	var label = Label.new()
	label.text = "BULL RUN!"
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-200, -50)

	var hud = CanvasLayer.new()
	hud.layer = 10
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)
	hud.add_child(container)
	vehicle.get_tree().root.add_child(hud)

	var tween = vehicle.get_tree().create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(hud.queue_free)
