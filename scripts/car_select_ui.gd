extends CanvasLayer

signal car_selected(index: int)
signal car_previewed(index: int)

var car_models: Array
var car_names: Array[String]
var current_index := 0

var name_label: Label
var left_btn: Button
var right_btn: Button
var go_btn: Button

var preview_viewport: SubViewport
var preview_model: Node3D
var preview_pivot: Node3D

func setup(models: Array):
	car_models = models
	car_names = []
	for model in models:
		var path: String = model.resource_path
		var file = path.get_file().get_basename()
		file = file.replace("_", " ")
		# Strip color suffix (last word) from names like "MuscleCar Blue"
		var words = file.split(" ")
		var colors = ["Blue", "Red", "Green", "Yellow", "Purple", "Orange", "White", "Black", "LightBlue"]
		if words.size() > 1 and words[-1] in colors:
			words.remove_at(words.size() - 1)
		file = " ".join(words)
		# Split CamelCase: "MuscleCar" -> "Muscle Car"
		var spaced = ""
		for j in range(file.length()):
			var ch = file[j]
			if j > 0 and ch == ch.to_upper() and ch != " " and file[j - 1] != " ":
				spaced += " "
			spaced += ch
		car_names.append(spaced)
	_build_ui()
	_update_display()

func _build_ui():
	layer = 10

	# Dimmed background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Center container
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -360
	panel.offset_bottom = 200

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.92)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(1, 1, 1, 0.3)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "CHOOSE YOUR CAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	vbox.add_child(title)

	# 3D Preview
	_build_preview(vbox)

	# Car name + arrows row
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	left_btn = _make_arrow_btn("<")
	left_btn.pressed.connect(_on_prev)
	row.add_child(left_btn)

	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size.x = 340
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(name_label)

	right_btn = _make_arrow_btn(">")
	right_btn.pressed.connect(_on_next)
	row.add_child(right_btn)

	# Car counter
	var counter = Label.new()
	counter.name = "Counter"
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_font_size_override("font_size", 22)
	counter.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	vbox.add_child(counter)

	# GO button
	go_btn = Button.new()
	go_btn.text = "GO!"
	go_btn.custom_minimum_size = Vector2(240, 65)
	go_btn.add_theme_font_size_override("font_size", 36)

	var go_style = StyleBoxFlat.new()
	go_style.bg_color = Color(0.2, 0.7, 0.3)
	go_style.corner_radius_top_left = 10
	go_style.corner_radius_top_right = 10
	go_style.corner_radius_bottom_left = 10
	go_style.corner_radius_bottom_right = 10
	go_style.content_margin_top = 8
	go_style.content_margin_bottom = 8
	go_btn.add_theme_stylebox_override("normal", go_style)

	var go_hover = go_style.duplicate()
	go_hover.bg_color = Color(0.25, 0.8, 0.35)
	go_btn.add_theme_stylebox_override("hover", go_hover)

	var go_pressed = go_style.duplicate()
	go_pressed.bg_color = Color(0.15, 0.6, 0.25)
	go_btn.add_theme_stylebox_override("pressed", go_pressed)

	go_btn.pressed.connect(_on_go)
	vbox.add_child(go_btn)

func _build_preview(parent: Control):
	# SubViewport for 3D car preview
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(600, 360)
	preview_viewport.transparent_bg = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.msaa_3d = Viewport.MSAA_2X

	# Camera — close up, centered on car
	var camera = Camera3D.new()
	camera.fov = 40
	preview_viewport.add_child(camera)
	camera.transform.origin = Vector3(0.15, 0.5, 1.8)
	camera.look_at(Vector3(-0.1, 0.05, 0), Vector3.UP)

	# Lighting
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.5
	preview_viewport.add_child(light)

	var fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-20, -120, 0)
	fill_light.light_energy = 0.6
	preview_viewport.add_child(fill_light)

	# Pivot for spinning the model
	preview_pivot = Node3D.new()
	preview_viewport.add_child(preview_pivot)

	# Environment for ambient light
	var env = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.8
	env.background_mode = Environment.BG_CLEAR_COLOR
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	preview_viewport.add_child(world_env)

	# SubViewportContainer to display in UI
	var viewport_container = SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(600, 360)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_container.add_child(preview_viewport)
	parent.add_child(viewport_container)

func _update_preview_model():
	# Remove old model
	if preview_model:
		preview_pivot.remove_child(preview_model)
		preview_model.queue_free()
		preview_model = null

	# Instantiate new model
	var instance = car_models[current_index].instantiate()
	instance.scale = Vector3(0.2, 0.2, 0.2)
	preview_pivot.add_child(instance)
	preview_model = instance

func _process(delta):
	if preview_pivot:
		preview_pivot.rotate_y(delta * 0.4)

func _make_arrow_btn(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(65, 65)
	btn.add_theme_font_size_override("font_size", 36)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.4)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.4, 0.4, 0.55)
	btn.add_theme_stylebox_override("hover", hover)

	return btn

func _on_prev():
	current_index = (current_index - 1 + car_models.size()) % car_models.size()
	_update_display()

func _on_next():
	current_index = (current_index + 1) % car_models.size()
	_update_display()

func _update_display():
	name_label.text = car_names[current_index]
	var counter = name_label.get_parent().get_parent().get_node_or_null("Counter")
	if counter:
		counter.text = str(current_index + 1) + " / " + str(car_models.size())
	_update_preview_model()
	car_previewed.emit(current_index)

func _on_go():
	car_selected.emit(current_index)
	queue_free()

func _input(event):
	if event.is_action_pressed("ui_left"):
		_on_prev()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_on_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_go()
		get_viewport().set_input_as_handled()
