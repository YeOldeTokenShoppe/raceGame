extends CanvasLayer

# Touch regions and their mapped input actions
var regions := {}  # name -> { "rect": Rect2, "action": String, "node": ColorRect }
var touch_map := {}  # touch_index -> action name
var viewport_size: Vector2

# Camera toggle callback
var camera_view: Node

# Visual settings
var btn_color := Color(0, 0, 0, 0.35)
var btn_pressed_color := Color(1, 1, 1, 0.25)
var label_color := Color(1, 1, 1, 0.8)

func _ready():
	await get_tree().process_frame
	_build_ui()

func _build_ui():
	viewport_size = get_viewport().get_visible_rect().size

	var container = Control.new()
	container.name = "TouchUI"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	# Uniform button size
	var btn_w = max(viewport_size.x * 0.16, 120)
	var btn_h = max(viewport_size.y * 0.18, 85)
	var margin = viewport_size.x * 0.03
	var gap = 10.0

	# Left side: steering (bottom-left corner)
	var left_x = margin
	var left_bottom = viewport_size.y - margin

	_create_button(container, "steer_left", "left",
		Rect2(left_x, left_bottom - btn_h, btn_w, btn_h), "<")
	_create_button(container, "steer_right", "right",
		Rect2(left_x + btn_w + gap, left_bottom - btn_h, btn_w, btn_h), ">")

	# Right side: gas/reverse (bottom-right corner)
	var right_x = viewport_size.x - margin - btn_w

	_create_button(container, "reverse", "back",
		Rect2(right_x - btn_w - gap, left_bottom - btn_h, btn_w, btn_h), "REV")
	_create_button(container, "gas", "forward",
		Rect2(right_x, left_bottom - btn_h, btn_w, btn_h), "GAS")

	# Camera toggle button (top-right corner)
	_create_button(container, "camera", "camera_toggle",
		Rect2(viewport_size.x - margin - btn_w, margin, btn_w, btn_h), "CAM")

func _create_button(parent: Control, region_name: String, action: String, rect: Rect2, text: String):
	var bg = ColorRect.new()
	bg.position = rect.position
	bg.size = rect.size
	bg.color = btn_color
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", label_color)
	label.add_theme_font_size_override("font_size", 32)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(label)

	regions[region_name] = { "rect": rect, "action": action, "node": bg }

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			var action = _action_for_position(event.position)
			if action == "camera_toggle":
				_toggle_camera()
				return
			if action != "":
				touch_map[event.index] = action
				Input.action_press(action)
				_update_visuals()
		else:
			_release_touch(event.index)

	elif event is InputEventScreenDrag:
		var old_action = touch_map.get(event.index, "")
		var new_action = _action_for_position(event.position)
		if new_action == "camera_toggle":
			return
		if new_action != old_action:
			if old_action != "":
				Input.action_release(old_action)
			if new_action != "":
				Input.action_press(new_action)
				touch_map[event.index] = new_action
			else:
				touch_map.erase(event.index)
			_update_visuals()

func _release_touch(index: int):
	if index in touch_map:
		Input.action_release(touch_map[index])
		touch_map.erase(index)
		_update_visuals()

func _action_for_position(pos: Vector2) -> String:
	for region in regions.values():
		if region["rect"].has_point(pos):
			return region["action"]
	return ""

func _toggle_camera():
	if not camera_view:
		camera_view = get_tree().current_scene.get_node_or_null("View")
	if camera_view and camera_view.has_method("toggle_camera"):
		camera_view.toggle_camera()

func _update_visuals():
	var active_actions := {}
	for action in touch_map.values():
		active_actions[action] = true

	for region in regions.values():
		if region["action"] in active_actions:
			region["node"].color = btn_pressed_color
		else:
			region["node"].color = btn_color
