extends Node3D

# Configuration

@export var is_player := true
@export var racing_path: Path3D
@export_range(0.5, 1.0) var ai_speed_factor := 0.9
@export_range(3.0, 12.0) var ai_look_ahead := 6.0
@export var downforce_strength := 0.0  # 0 = off (flat tracks), higher = sticks to loops
@export var speed_multiplier := 1.0  # Boost for tracks that need more speed
@export var trail_color := Color(0.369, 0.374, 0.42, 1.0)  # Default: gray smoke

# Nodes

@onready var sphere: RigidBody3D = $Sphere
@onready var raycast: RayCast3D = $Ground

# Vehicle elements

@onready var vehicle_model = $Container
var vehicle_body: Node3D
var wheel_fl: Node3D
var wheel_fr: Node3D
var wheel_bl: Node3D
var wheel_br: Node3D

# Effects

@onready var trail_left: GPUParticles3D = $Container/TrailLeft
@onready var trail_right: GPUParticles3D = $Container/TrailRight

# Sounds

@onready var screech_sound: AudioStreamPlayer3D = $Container/ScreechSound
@onready var engine_sound: AudioStreamPlayer3D = $Container/EngineSound

var input: Vector3
var normal: Vector3

var acceleration: float
var angular_speed: float
var linear_speed: float

var colliding: bool
var coins := 0
var finished := false

# Bull Run warp state
var bull_run_active := false
var bull_run_offset := 0.0
var bull_run_target_offset := 0.0
var bull_run_speed := 150.0  # Units per second along the path
var bull_run_path: Path3D

var coins_for_boost := 8

func collect_coin():
	coins += 1
	if coins >= coins_for_boost and not bull_run_active:
		coins = 0
		start_bull_run()
		# Show "COIN BOOST!" text
		var label = Label.new()
		label.text = "COIN BOOST!"
		label.add_theme_font_size_override("font_size", 72)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
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
		get_tree().root.add_child(hud)
		var tween = get_tree().create_tween()
		tween.tween_interval(1.0)
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(hud.queue_free)

func start_bull_run():
	if bull_run_active or not racing_path:
		return
	bull_run_active = true
	bull_run_path = racing_path
	var curve = bull_run_path.curve
	var path_length = curve.get_baked_length()
	var local_pos = bull_run_path.to_local(vehicle_model.global_position)
	bull_run_offset = curve.get_closest_offset(local_pos)
	bull_run_target_offset = bull_run_offset + path_length * 0.5

	# Freeze physics during warp
	sphere.freeze = true

func _ready():
	refresh_model_refs()

func refresh_model_refs():
	var container = get_node_or_null("Container")
	if not container:
		return
	var model = container.get_node_or_null("Model")
	if model:
		vehicle_body = model.get_node_or_null("body")
		# Check Kenney naming first (direct children of Model)
		wheel_fl = model.get_node_or_null("wheel-front-left")
		wheel_fr = model.get_node_or_null("wheel-front-right")
		wheel_bl = model.get_node_or_null("wheel-back-left")
		wheel_br = model.get_node_or_null("wheel-back-right")
		# Fallback: search inside body for Synty naming
		if not wheel_fl and vehicle_body:
			for child in vehicle_body.get_children():
				var cname = String(child.name)
				if "_Wheel_FL" in cname: wheel_fl = child
				elif "_Wheel_FR" in cname: wheel_fr = child
				elif "_Wheel_RL" in cname: wheel_bl = child
				elif "_Wheel_RR" in cname: wheel_br = child
			# Don't tilt the body on Synty models (whole car is the body)
			vehicle_body = null

func apply_trail_color():
	for trail in [trail_left, trail_right]:
		if trail and trail.process_material:
			var mat = trail.process_material.duplicate()
			mat.color = trail_color
			mat.scale_min = 0.5
			mat.scale_max = 1.2
			trail.process_material = mat
			trail.amount = 64
			trail.lifetime = 1.0

# Functions

func _physics_process(delta):

	if bull_run_active:
		_process_bull_run(delta)
		effect_engine(delta)
		return

	if finished:
		# Wind down speed and effects but keep following physics
		input.x = 0.0
		input.z = 0.0
		linear_speed = lerp(linear_speed, 0.0, delta * 3.0)
		acceleration = lerp(acceleration, 0.0, delta * 3.0)
	elif is_player:
		handle_input(delta)
	else:
		handle_ai_input(delta)

	var direction = sign(linear_speed)
	if direction == 0: direction = sign(input.z) if abs(input.z) > 0.1 else 1

	var steering_grip = clamp(abs(linear_speed), 0.2, 1.0)

	var target_angular = -input.x * steering_grip * 4 * direction
	angular_speed = lerp(angular_speed, target_angular, delta * 4)

	vehicle_model.rotate_y(angular_speed * delta)

	# Ground alignment

	if raycast.is_colliding():
		if !colliding:
			if vehicle_body:
				vehicle_body.position = Vector3(0, 0.1, 0) # Bounce
			input.z = 0

		normal = raycast.get_collision_normal()

		# Orient model to colliding normal
		if normal.dot(vehicle_model.global_basis.y) > 0.5:
			var xform = align_with_y(vehicle_model.global_transform, normal)
			vehicle_model.global_transform = vehicle_model.global_transform.interpolate_with(xform, 0.2).orthonormalized()

	colliding = raycast.is_colliding()

	# Downforce for ramp traction (only when moving)
	if downforce_strength > 0 and raycast.is_colliding() and abs(linear_speed) > 0.1:
		sphere.apply_central_force(Vector3.DOWN * downforce_strength * sphere.mass)

	var target_speed = input.z

	if (target_speed < 0 and linear_speed > 0.01):
		linear_speed = lerp(linear_speed, 0.0, delta * 8)
	else:
		if (target_speed < 0):
			linear_speed = lerp(linear_speed, target_speed / 2, delta * 2)
		else:
			linear_speed = lerp(linear_speed, target_speed, delta * 6)

	acceleration = lerpf(acceleration, linear_speed + (abs(sphere.angular_velocity.length() * linear_speed) / 100), delta * 1)

	# Match vehicle model to physics sphere

	vehicle_model.position = sphere.position - Vector3(0, 0.45, 0)
	raycast.position = sphere.position

	# On loop tracks, point raycast toward the track surface using raw normal
	raycast.target_position = Vector3(0, -0.7, 0)

	# Visual and audio effects

	effect_engine(delta)
	effect_body(delta)
	effect_wheels(delta)
	effect_trails()

func _process_bull_run(delta):
	var curve = bull_run_path.curve
	var path_length = curve.get_baked_length()

	# Advance along the path
	bull_run_offset += bull_run_speed * delta
	var current_offset = fmod(bull_run_offset, path_length)

	# Get position and direction on path
	var pos_local = curve.sample_baked(current_offset)
	var next_local = curve.sample_baked(fmod(current_offset + 2.0, path_length))
	var pos_global = bull_run_path.to_global(pos_local)
	var next_global = bull_run_path.to_global(next_local)

	# Move sphere and model to path position
	sphere.global_position = pos_global + Vector3(0, 0.5, 0)
	vehicle_model.global_position = pos_global

	# Orient model along the path direction
	var direction = (next_global - pos_global).normalized()
	if direction.length_squared() > 0.01:
		var target_xform = vehicle_model.global_transform.looking_at(pos_global + direction, Vector3.UP)
		vehicle_model.global_transform = vehicle_model.global_transform.interpolate_with(target_xform, delta * 10.0)

	# Spin wheels fast for effect
	acceleration = 2.0
	effect_wheels(delta)

	# Rev engine sound during warp
	input.z = 1.0
	linear_speed = 1.0

	# Check if warp is complete
	if bull_run_offset >= bull_run_target_offset:
		bull_run_active = false
		sphere.freeze = false

		# Snap model rotation to face along the path direction
		var exit_offset = fmod(bull_run_offset, path_length)
		var exit_pos = curve.sample_baked(exit_offset)
		var exit_next = curve.sample_baked(fmod(exit_offset + 2.0, path_length))
		var exit_dir = (bull_run_path.to_global(exit_next) - bull_run_path.to_global(exit_pos)).normalized()
		if exit_dir.length_squared() > 0.01:
			# Godot's forward is -Z, so look at the point behind to face forward
			vehicle_model.look_at(vehicle_model.global_position - exit_dir, Vector3.UP)

		# Give the car forward momentum coming out of the warp
		var forward = -vehicle_model.global_basis.z
		sphere.linear_velocity = forward * 15.0
		linear_speed = 0.8

# Handle input when vehicle is colliding with ground (player)

func handle_input(delta):

	if raycast.is_colliding():
		input.x = Input.get_axis("left", "right")
		input.z = Input.get_axis("back", "forward")

	sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * 100 * speed_multiplier) * delta

# Handle AI input — follow racing path

func handle_ai_input(delta):

	if racing_path and racing_path.curve:
		var curve = racing_path.curve
		var path_length = curve.get_baked_length()
		if path_length < 1.0:
			sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * 100 * speed_multiplier) * delta
			return

		# Find closest point on path and look ahead
		var local_pos = racing_path.to_local(vehicle_model.global_position)
		var closest_offset = curve.get_closest_offset(local_pos)
		var look_offset = fmod(closest_offset + ai_look_ahead, path_length)
		var target_local = curve.sample_baked(look_offset)
		var target_global = racing_path.to_global(target_local)

		# Calculate steering
		var to_target = target_global - vehicle_model.global_position
		to_target.y = 0
		if to_target.length_squared() > 0.01:
			to_target = to_target.normalized()
			var forward = -vehicle_model.global_basis.z
			forward.y = 0
			forward = forward.normalized()

			# Cross product determines left/right steering
			var cross = forward.cross(to_target)
			input.x = clamp(cross.y * 4.0, -1.0, 1.0)

			# Throttle — full speed always (needed for ramps/jumps)
			input.z = ai_speed_factor
		else:
			input.x = 0.0
			input.z = ai_speed_factor

	sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * 100 * speed_multiplier) * delta

func effect_body(delta):
	if not vehicle_body:
		return

	# Slightly tilt body based on acceleration and steering

	vehicle_body.rotation.x = lerp_angle(vehicle_body.rotation.x, -(linear_speed - acceleration) / 6, delta * 10)
	vehicle_body.rotation.z = lerp_angle(vehicle_body.rotation.z, -input.x / 5 * linear_speed, delta * 5)

	# Change the body position so wheels don't clip through the body when tilting

	vehicle_body.position = vehicle_body.position.lerp(Vector3(0, 0.2, 0), delta * 5)

func effect_wheels(delta):

	# Rotate wheels based on acceleration

	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		if wheel:
			wheel.rotation.x += acceleration

	# Rotate front wheels based on steering direction

	if wheel_fl:
		wheel_fl.rotation.y = lerp_angle(wheel_fl.rotation.y, -input.x / 1.5, delta * 10)
	if wheel_fr:
		wheel_fr.rotation.y = lerp_angle(wheel_fr.rotation.y, -input.x / 1.5, delta * 10)

# Engine sounds

func effect_engine(delta):

	var speed_factor = clamp(abs(linear_speed), 0.0, 1.0)
	var throttle_factor = clamp(abs(input.z), 0.0, 1.0)

	var target_volume = remap(speed_factor + (throttle_factor * 0.5), 0.0, 1.5, -15.0, -5.0)
	engine_sound.volume_db = lerp(engine_sound.volume_db, target_volume, delta * 5.0)

	var target_pitch = remap(speed_factor, 0.0, 1.0, 0.5, 3)
	if throttle_factor > 0.1: target_pitch += 0.2

	engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, delta * 2.0)

# Show trails (and play skid sound)

func effect_trails():

	var body_roll = abs(vehicle_body.rotation.z) if vehicle_body else 0.0
	var drift_intensity = abs(linear_speed - acceleration) + (body_roll * 2.0)
	var should_emit = drift_intensity > 0.25

	trail_left.emitting = should_emit
	trail_right.emitting = should_emit

	var target_volume = -80.0
	if should_emit: target_volume = remap(clamp(drift_intensity, 0.25, 2.0), 0.25, 2.0, -10.0, 0.0)

	screech_sound.pitch_scale = lerp(screech_sound.pitch_scale, clamp(abs(linear_speed), 1.0, 3.0), 0.1)
	screech_sound.volume_db = lerp(screech_sound.volume_db, target_volume, 10.0 * get_physics_process_delta_time())

# Align vehicle with normal

func align_with_y(xform, new_y):

	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform
