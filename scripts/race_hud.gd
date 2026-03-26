extends CanvasLayer

var race_state: Node
var player: Node3D
var view_node: Node3D

var position_label: Label
var lap_label: Label
var countdown_label: Label
var result_label: Label
var fps_label: Label
var coin_label: Label
var timer_label: Label
var race_again_btn: Button

var race_time := 0.0
var race_timing := false

func setup(state: Node, player_vehicle: Node3D):
	race_state = state
	player = player_vehicle
	_build_ui()

	if race_state:
		race_state.race_started.connect(_on_race_started)
		race_state.lap_completed.connect(_on_lap_completed)
		race_state.race_finished.connect(_on_race_finished)

func _build_ui():
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	# Position display (top-left) — e.g. "1st"
	position_label = _make_label(container)
	position_label.position = Vector2(20, 20)
	position_label.add_theme_font_size_override("font_size", 48)
	position_label.text = ""

	# Lap counter (below timer, top-left)
	lap_label = _make_label(container)
	lap_label.position = Vector2(20, 180)
	lap_label.add_theme_font_size_override("font_size", 28)
	lap_label.text = ""

	# Countdown (center)
	countdown_label = _make_label(container)
	countdown_label.anchor_left = 0.5
	countdown_label.anchor_right = 0.5
	countdown_label.anchor_top = 0.5
	countdown_label.anchor_bottom = 0.5
	countdown_label.offset_left = -100
	countdown_label.offset_right = 100
	countdown_label.offset_top = -60
	countdown_label.offset_bottom = 60
	countdown_label.add_theme_font_size_override("font_size", 96)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.text = ""

	# Race result (center, hidden until race ends)
	result_label = _make_label(container)
	result_label.anchor_left = 0.0
	result_label.anchor_right = 1.0
	result_label.anchor_top = 0.3
	result_label.anchor_bottom = 0.7
	result_label.offset_left = 0
	result_label.offset_right = 0
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.text = ""
	result_label.visible = false

	# Race Again button (hidden until race ends)
	race_again_btn = Button.new()
	race_again_btn.text = "Race Again?"
	race_again_btn.custom_minimum_size = Vector2(200, 55)
	race_again_btn.add_theme_font_size_override("font_size", 28)
	race_again_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	race_again_btn.offset_left = -100
	race_again_btn.offset_right = 100
	race_again_btn.offset_top = -120
	race_again_btn.offset_bottom = -65
	race_again_btn.visible = false

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.9)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	race_again_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.3, 0.6, 1.0)
	race_again_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.15, 0.4, 0.75)
	race_again_btn.add_theme_stylebox_override("pressed", btn_pressed)

	race_again_btn.pressed.connect(_on_race_again)
	container.add_child(race_again_btn)

	# FPS counter (top-center)
	fps_label = _make_label(container)
	fps_label.anchor_left = 0.0
	fps_label.anchor_right = 0.0
	fps_label.position = Vector2(20, 60)
	fps_label.add_theme_font_size_override("font_size", 48)
	fps_label.add_theme_color_override("font_color", Color(1, 1, 0, 1.0))
	fps_label.text = ""

	# Coin counter (below FPS, top-left)
	coin_label = _make_label(container)
	coin_label.position = Vector2(20, 110)
	coin_label.add_theme_font_size_override("font_size", 28)
	coin_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	coin_label.text = "Coins: 0"

	# Race timer (below coins, top-left)
	timer_label = _make_label(container)
	timer_label.position = Vector2(20, 145)
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.text = ""

func _make_label(parent: Control) -> Label:
	var label = Label.new()
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _process(delta):
	fps_label.text = str(Engine.get_frames_per_second()) + " FPS"

	if player:
		coin_label.text = "Coins: " + str(player.coins)

	if race_timing:
		race_time += delta
		timer_label.text = _format_time(race_time)

	if not race_state:
		return

	match race_state.state:
		race_state.State.COUNTDOWN:
			var remaining = ceil(race_state.get_countdown_remaining())
			if remaining > 0:
				countdown_label.text = str(int(remaining))
			else:
				countdown_label.text = "GO!"
			position_label.text = ""
			lap_label.text = ""

		race_state.State.RACING:
			countdown_label.text = ""

			# Stop updating position/lap once the player has finished
			if result_label.visible:
				position_label.text = ""
				lap_label.text = ""
			else:
				# Position
				var pos = race_state.get_vehicle_position(player)
				position_label.text = _ordinal(pos)

				# Lap
				var lap = race_state.get_vehicle_lap(player) + 1
				lap = min(lap, race_state.total_laps)
				lap_label.text = "Lap " + str(lap) + "/" + str(race_state.total_laps)

		race_state.State.FINISHED:
			countdown_label.text = ""
			position_label.text = ""
			lap_label.text = ""

func _on_race_started():
	countdown_label.text = "GO!"
	race_timing = true
	race_time = 0.0
	await get_tree().create_timer(1.0).timeout
	countdown_label.text = ""

func _on_lap_completed(vehicle: Node3D, lap: int):
	# Show player's finish position as soon as they cross the line
	if vehicle == player and lap >= race_state.total_laps:
		race_timing = false
		var pos = race_state.finish_order.find(player) + 1
		result_label.text = "You finished " + _ordinal(pos) + "!\nTime: " + _format_time(race_time)
		result_label.visible = true
		race_again_btn.visible = true
		position_label.text = ""
		lap_label.text = ""

		# Switch to far camera view
		if view_node and view_node.current_mode == view_node.CameraMode.CLOSE:
			view_node.toggle_camera()

func _on_race_finished(_results: Array):
	race_again_btn.visible = true

func _on_race_again():
	get_tree().reload_current_scene()

func _format_time(t: float) -> String:
	var minutes = int(t) / 60
	var seconds = int(t) % 60
	var millis = int(fmod(t, 1.0) * 100)
	return "%d:%02d.%02d" % [minutes, seconds, millis]

func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		_: return str(n) + "th"
