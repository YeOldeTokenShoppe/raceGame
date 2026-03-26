extends Node3D

@export_group("Properties")
@export var target: Node

@onready var camera = $Camera

# Camera modes
enum CameraMode { FAR, CLOSE }
var current_mode := CameraMode.FAR

# Far camera settings (original isometric view)
var far_distance := 16.0
var far_fov := 40.0
var far_follow_speed := 4.0

# Close chase camera settings
var close_offset := Vector3(0, 1.2, -2.5)  # Behind and above the car
var close_fov := 60.0
var close_follow_speed := 8.0
var close_rotation_speed := 5.0

# Functions

func _input(event):
	if event.is_action_pressed("camera_toggle"):
		toggle_camera()

func _ready():
	# Add camera_toggle action if it doesn't exist
	if not InputMap.has_action("camera_toggle"):
		InputMap.add_action("camera_toggle")
		var key_event = InputEventKey.new()
		key_event.physical_keycode = KEY_C
		InputMap.action_add_event("camera_toggle", key_event)

func toggle_camera():
	if current_mode == CameraMode.FAR:
		current_mode = CameraMode.CLOSE
	else:
		current_mode = CameraMode.FAR

func _physics_process(delta):
	if not target:
		return

	if current_mode == CameraMode.FAR:
		_update_far_camera(delta)
	else:
		_update_close_camera(delta)

func _update_far_camera(delta):
	# Overhead follow camera — computed entirely in code
	var target_pos = target.global_position
	var desired_pos = target_pos + Vector3(8, 12, 8)
	self.global_position = self.global_position.lerp(desired_pos, delta * far_follow_speed)
	self.look_at(target_pos, Vector3.UP)
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.fov = lerp(camera.fov, far_fov, delta * 5.0)

func _update_close_camera(delta):
	# Chase cam: follow behind the truck, rotate with it
	var target_pos = target.global_position
	var target_basis = target.global_transform.basis

	# Position behind and above the truck
	var desired_pos = target_pos + target_basis * close_offset
	self.global_position = self.global_position.lerp(desired_pos, delta * close_follow_speed)

	# Look at the truck (slightly ahead of it for better framing)
	var look_target = target_pos + target_basis * Vector3(0, 0.5, 3.0)
	var current_transform = self.global_transform
	var target_transform = current_transform.looking_at(look_target, Vector3.UP)
	self.global_transform = current_transform.interpolate_with(target_transform, delta * close_rotation_speed)

	# Wider FOV for speed sensation
	camera.fov = lerp(camera.fov, close_fov, delta * 5.0)
	# Camera at origin of View node (position is handled by the View node itself)
	camera.position = camera.position.lerp(Vector3.ZERO, delta * 5.0)
