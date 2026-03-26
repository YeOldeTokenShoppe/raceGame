extends CanvasLayer

signal intro_finished

func _ready():
	layer = 15
	_build_ui()

func _build_ui():
	# Dimmed background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Center panel
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -280
	panel.offset_bottom = 280

	var style = StyleBoxFlat.new()
	style.bg_color = Color("020E20F2")
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(1, 0.85, 0.2, 0.6)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "MARKET RALLY RACE!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(title)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	vbox.add_child(sep)

	# Info items
	var info_items = [
		["3 Laps", "Complete 3 laps around the track to finish the race."],
		["Coins", "Collect 8 coins to go on a BULL RUN for half a lap!"],
		["Candlesticks", "Collect 3 candles to go on a BULL RUN for half a lap!"],
		["Shortcuts", "Cut through the center for shortcuts, but watch out for obstacles!"],
	]

	for item in info_items:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		vbox.add_child(hbox)

		var heading = Label.new()
		heading.text = item[0]
		heading.custom_minimum_size.x = 160
		heading.add_theme_font_size_override("font_size", 28)
		heading.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(heading)

		var desc = Label.new()
		desc.text = item[1]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 360
		desc.add_theme_font_size_override("font_size", 24)
		desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(desc)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "LET'S RACE!"
	start_btn.custom_minimum_size = Vector2(280, 70)
	start_btn.add_theme_font_size_override("font_size", 36)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.7, 0.3)
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_left = 12
	btn_style.corner_radius_bottom_right = 12
	btn_style.content_margin_top = 10
	btn_style.content_margin_bottom = 10
	start_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.8, 0.35)
	start_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.15, 0.6, 0.25)
	start_btn.add_theme_stylebox_override("pressed", btn_pressed)

	start_btn.pressed.connect(_on_start)
	vbox.add_child(start_btn)

func _on_start():
	intro_finished.emit()
	queue_free()
