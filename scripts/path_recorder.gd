extends Node

var target: Node3D
var recording := false
var points := []
var min_distance := 2.0  # Minimum distance between recorded points

func _ready():
	if not InputMap.has_action("record_path"):
		InputMap.add_action("record_path")
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_R
		InputMap.action_add_event("record_path", key_event)
	print("PATH RECORDER: Press R to start/stop recording. Drive one lap around the track.")

func start_recording(vehicle: Node3D):
	target = vehicle

func _physics_process(_delta):
	# Toggle recording with R key
	if Input.is_action_just_pressed("record_path"):
		if not recording:
			recording = true
			points.clear()
			print("RECORDING started — drive the racing line!")
		else:
			recording = false
			_save_path()

	# Record positions while driving
	if not recording or not target:
		return

	var container = target.get_node_or_null("Container")
	if not container:
		return

	var pos = container.global_position
	if points.size() == 0 or pos.distance_to(points[-1]) > min_distance:
		points.append(pos)

func _save_path():
	print("RECORDING stopped — ", points.size(), " points captured")
	if points.size() < 5:
		print("Not enough points. Drive further next time.")
		return

	print("\n# --- PASTE THIS INTO main.gd ---")
	print("var recorded_path_points := [")
	for p in points:
		print("\tVector3(", snapped(p.x, 0.01), ", ", snapped(p.y, 0.01), ", ", snapped(p.z, 0.01), "),")
	print("]")
	print("# --- END PASTE ---\n")

	var existing = get_parent().get_node_or_null("RacingPath")
	if existing:
		existing.queue_free()

	var path = Path3D.new()
	path.name = "RacingPath"
	var curve = Curve3D.new()
	for p in points:
		curve.add_point(p)
	curve.closed = true
	path.curve = curve
	get_parent().add_child(path)
	print("Created RacingPath with ", points.size(), " points (length: ", curve.get_baked_length(), ")")
