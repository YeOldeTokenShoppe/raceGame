extends Node3D

# Track settings — adjust per track
var track_downforce := 0.0
var track_speed := 1.0
var track_trail_color := Color(0.55, 0.30, 0.18, 1.0)  # Brown-red dirt dust

# Recorded racing path for monster truck oval (Y smoothed to -17.51)
var monster_truck_path := [
	Vector3(-9.84, -17.18, 1.06),
	Vector3(-10.05, -17.54, 3.07),
	Vector3(-10.35, -17.01, 5.03),
	Vector3(-10.6, -17.49, 6.98),
	Vector3(-10.85, -17.51, 9.03),
	Vector3(-11.02, -17.51, 11.07),
	Vector3(-10.76, -17.51, 13.06),
	Vector3(-10.35, -17.51, 15.08),
	Vector3(-9.88, -17.51, 17.04),
	Vector3(-9.24, -17.51, 18.99),
	Vector3(-8.47, -17.51, 20.86),
	Vector3(-8.7, -17.51, 9.48),
	Vector3(-8.6, -17.51, 11.52),
	Vector3(-8.2, -17.51, 13.54),
	Vector3(-7.59, -17.51, 15.54),
	Vector3(-6.79, -17.51, 17.44),
	Vector3(-5.94, -17.51, 19.26),
	Vector3(-4.08, -17.51, 20.11),
	Vector3(-2.05, -17.51, 20.0),
	Vector3(-0.04, -17.51, 19.77),
	Vector3(1.82, -17.51, 19.02),
	Vector3(2.94, -17.51, 17.32),
	Vector3(3.93, -17.51, 15.58),
	Vector3(5.03, -17.51, 13.88),
	Vector3(6.15, -17.51, 12.18),
	Vector3(7.24, -17.51, 10.49),
	Vector3(8.22, -16.58, 8.99),
	Vector3(9.45, -16.16, 7.46),
	Vector3(10.17, -17.5, 6.16),
	Vector3(10.78, -16.95, 4.33),
	Vector3(10.52, -17.16, 2.31),
	Vector3(10.26, -17.51, 0.24),
	Vector3(9.83, -17.51, -1.82),
	Vector3(9.45, -17.51, -3.86),
	Vector3(9.08, -17.51, -5.87),
	Vector3(8.7, -17.51, -7.85),
	Vector3(7.66, -17.51, -9.57),
	Vector3(5.97, -17.51, -10.65),
	Vector3(4.2, -17.51, -11.63),
	Vector3(2.29, -17.51, -12.25),
	Vector3(0.31, -17.51, -12.63),
	Vector3(-1.73, -17.51, -12.38),
	Vector3(-3.68, -17.51, -11.93),
	Vector3(-5.64, -17.51, -11.45),
	Vector3(-7.36, -17.51, -10.41),
	Vector3(-8.17, -17.51, -8.57),
	Vector3(-8.72, -17.51, -6.64),
	Vector3(-9.14, -17.51, -4.61),
	Vector3(-9.36, -17.51, -2.52),
	Vector3(-9.57, -16.34, -0.82),
]

var race_state: Node
var coin_spawner_node: Node3D
var all_vehicles := []
var _preview_index := 0

var synty_car_models := [
	preload("res://models/cars/MuscleCar_Purple.fbx"),
	preload("res://models/cars/MuscleCar_Blue.fbx"),
	preload("res://models/cars/DerbyCar_Orange.fbx"),
	preload("res://models/cars/RalleyCar_LightBlue.fbx"),
	preload("res://models/cars/StreetCar_Blue.fbx"),
]

var ai_configs := [
	{ "speed": 1.0, "look_ahead": 8.0 },
	{ "speed": 1.0, "look_ahead": 7.0 },
	{ "speed": 1.0, "look_ahead": 6.0 },
]

var spawn_offsets := [
	Vector3(1.5, 0, 0),
	Vector3(1.5, 0, -2.5),
	Vector3(-1.5, 0, -2.5),
]

func _ready():
	print("Main _ready() — spawning AI")

	# Debug: print all light settings
	for child in get_children():
		if child is DirectionalLight3D:
			print("--- ", child.name, " ---")
			print("  Position: ", child.position)
			print("  Rotation (deg): ", child.rotation_degrees)
			print("  Color: ", child.light_color)
			print("  Energy: ", child.light_energy)
			print("  Shadow: ", child.shadow_enabled)
	var env_node = get_node_or_null("WorldEnvironment")
	if env_node and env_node.environment:
		var env = env_node.environment
		# Force ambient to Color mode (Compatibility renderer ignores Background mode)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_energy = 1.2
		print("--- WorldEnvironment ---")
		print("  Ambient Source: ", env.ambient_light_source)
		print("  Ambient Color: ", env.ambient_light_color)
		print("  Ambient Energy: ", env.ambient_light_energy)
		print("  Fog Enabled: ", env.fog_enabled)

	# Add touch controls
	var touch_controls = CanvasLayer.new()
	touch_controls.name = "TouchControls"
	touch_controls.set_script(preload("res://scripts/touch_controls.gd"))
	add_child(touch_controls)

	# Auto-generate collision for Synty track meshes (any FBX track in the scene)
	for child in get_children():
		if "acetrack" in child.name.to_lower() or "racetrack" in child.name.to_lower():
			_generate_track_collision(child)
			print("Generated track collision for: ", child.name)
			# Path will be recorded by driving (press R)
			pass

	var racing_path = get_node_or_null("RacingPath")

	# Flatten path Y values for consistent AI steering (physics handles actual jumps)
	if racing_path and racing_path.curve and racing_path.curve.point_count > 3:
		var avg_y := 0.0
		for i in range(racing_path.curve.point_count):
			avg_y += racing_path.curve.get_point_position(i).y
		avg_y /= racing_path.curve.point_count
		for i in range(racing_path.curve.point_count):
			var p = racing_path.curve.get_point_position(i)
			racing_path.curve.set_point_position(i, Vector3(p.x, avg_y, p.z))
		print("Flattened RacingPath to Y=", snapped(avg_y, 0.01), " (", racing_path.curve.point_count, " points, length: ", racing_path.curve.get_baked_length(), ")")

	# Auto-create path from recorded points if no manual path exists
	if not racing_path and monster_truck_path.size() > 0:
		var has_track = false
		for child in get_children():
			if "racetrack" in child.name.to_lower():
				has_track = true
				break
		if has_track:
			racing_path = Path3D.new()
			racing_path.name = "RacingPath"
			var curve = Curve3D.new()
			for p in monster_truck_path:
				curve.add_point(p)
			curve.closed = true
			racing_path.curve = curve
			add_child(racing_path)
			print("Created RacingPath from recorded points (length: ", curve.get_baked_length(), ")")

	# Wire up camera target to the Container (which visually follows the physics sphere)
	var view = get_node_or_null("View")
	if view:
		var vehicle = get_node_or_null("Vehicle")
		if vehicle:
			view.target = vehicle.get_node("Container")

	# Freeze physics until car is selected
	var player = get_node_or_null("Vehicle")
	if player:
		var sphere = player.get_node_or_null("Sphere") as RigidBody3D
		if sphere:
			sphere.freeze = true

	# Show intro screen, then car selection
	var intro = CanvasLayer.new()
	intro.name = "IntroScreen"
	intro.set_script(preload("res://scripts/intro_screen.gd"))
	add_child(intro)
	intro.intro_finished.connect(_show_car_select)

	# Show initial car on player
	_preview_index = 0
	_swap_vehicle_model(player, synty_car_models[0])

func _show_car_select():
	var car_select = CanvasLayer.new()
	car_select.name = "CarSelectUI"
	car_select.set_script(preload("res://scripts/car_select_ui.gd"))
	add_child(car_select)
	car_select.setup(synty_car_models)
	car_select.car_selected.connect(_on_car_selected)
	car_select.car_previewed.connect(_preview_car)

func _preview_car(index: int):
	var player = get_node_or_null("Vehicle")
	if player and index != _preview_index:
		_preview_index = index
		_swap_vehicle_model(player, synty_car_models[index])

func _on_car_selected(index: int):
	_preview_index = index
	var player = get_node_or_null("Vehicle")
	if player:
		# Unfreeze physics
		var sphere = player.get_node_or_null("Sphere") as RigidBody3D
		if sphere:
			sphere.freeze = false
	# Switch to close camera view
	var view = get_node_or_null("View")
	if view and view.has_method("toggle_camera") and view.current_mode == view.CameraMode.FAR:
		view.toggle_camera()
	_start_race(index)

func _start_race(player_car_index: int):
	var racing_path = get_node_or_null("RacingPath")

	if not racing_path:
		push_warning("No RacingPath found — test drive mode (no AI, no race)")
		var player = get_node_or_null("Vehicle")
		if player:
			player.is_player = true
			player.downforce_strength = track_downforce
			player.speed_multiplier = track_speed
			player.trail_color = track_trail_color
			player.apply_trail_color()
		var test_hud = CanvasLayer.new()
		test_hud.name = "RaceHUD"
		test_hud.layer = 2
		test_hud.set_script(preload("res://scripts/race_hud.gd"))
		add_child(test_hud)
		test_hud.setup(null, player)
		return

	# Enable vehicle-to-vehicle collisions (layer 4 = bit 8)
	var player = get_node("Vehicle")
	player.is_player = true
	player.racing_path = racing_path
	player.downforce_strength = track_downforce
	player.speed_multiplier = track_speed
	player.trail_color = track_trail_color
	player.apply_trail_color()
	var player_sphere = player.get_node("Sphere") as RigidBody3D
	player_sphere.collision_mask |= 8  # Add layer 4 to mask

	var vehicle_scene = preload("res://scenes/vehicle.tscn")

	for i in range(3):
		var ai = vehicle_scene.instantiate()
		ai.name = "AI_" + str(i)

		# Swap to the AI's car model
		var model_index = (player_car_index + i + 1) % synty_car_models.size()
		_swap_vehicle_model(ai, synty_car_models[model_index])

		# Configure AI
		ai.is_player = false
		ai.racing_path = racing_path
		ai.ai_speed_factor = ai_configs[i]["speed"]
		ai.ai_look_ahead = ai_configs[i]["look_ahead"]

		# Reduce AI audio
		for snd_path in ["Container/EngineSound", "Container/ScreechSound"]:
			var snd = ai.get_node_or_null(snd_path)
			if snd:
				snd.volume_db -= 12.0

		# Track-specific settings
		ai.downforce_strength = track_downforce
		ai.speed_multiplier = track_speed
		ai.trail_color = track_trail_color

		# Enable vehicle-to-vehicle collisions
		var ai_sphere = ai.get_node("Sphere") as RigidBody3D
		ai_sphere.collision_mask |= 8  # Add layer 4 to mask

		add_child(ai)

		# Apply trail color after add_child so @onready nodes are available
		ai.apply_trail_color()

		# Position on starting grid (after add_child so physics body is in tree)
		ai.position = player.position + spawn_offsets[i]
		ai_sphere.position = Vector3(0, 0.5, 0)  # Reset sphere to local default
		all_vehicles.append(ai)
		print("Spawned AI_", i)

	# Calculate player start offset for positioning collectibles
	var player_offset := 0.0
	var player_container = player.get_node_or_null("Container")
	if player_container:
		var local_pos = racing_path.to_local(player_container.global_position)
		player_offset = racing_path.curve.get_closest_offset(local_pos)

	# Spawn coins along the track (hidden until player reaches halfway)
	coin_spawner_node = Node3D.new()
	coin_spawner_node.name = "CoinSpawner"
	coin_spawner_node.set_script(preload("res://scripts/coin_spawner.gd"))
	add_child(coin_spawner_node)
	coin_spawner_node.player_start_offset = player_offset
	coin_spawner_node.spawn_along_path(racing_path)

	# Spawn Bull Run candlestick pickups (2 per race, random positions)
	_spawn_bull_run_pickups(racing_path)

	# Set up race management
	all_vehicles.insert(0, player)  # Player first in the list
	race_state = Node.new()
	race_state.name = "RaceState"
	race_state.set_script(preload("res://scripts/race_state.gd"))
	add_child(race_state)
	race_state.setup(racing_path, all_vehicles)

	race_state.race_started.connect(_on_race_started)
	race_state.lap_completed.connect(_on_lap_completed)
	race_state.race_finished.connect(_on_race_finished)

	# Set up HUD
	var hud = CanvasLayer.new()
	hud.name = "RaceHUD"
	hud.layer = 2
	hud.set_script(preload("res://scripts/race_hud.gd"))
	add_child(hud)
	hud.setup(race_state, player)
	hud.view_node = get_node_or_null("View")

func _process(_delta):
	if coin_spawner_node and not coin_spawner_node.coins_visible and race_state and race_state.state == race_state.State.RACING:
		var player = get_node_or_null("Vehicle")
		if player:
			var offset = race_state._get_vehicle_offset(player)
			if offset >= race_state.path_length * 0.5:
				coin_spawner_node.reveal_coins()

func _on_race_started():
	print("RACE STARTED!")

func _on_lap_completed(vehicle: Node3D, lap: int):
	print(vehicle.name, " — Lap ", lap, "/", race_state.total_laps)

func _on_race_finished(results: Array):
	print("RACE OVER! Results:")
	for i in range(results.size()):
		print("  ", i + 1, ": ", results[i].name)

func _spawn_bull_run_pickups(path: Path3D):
	if not path or not path.curve:
		return
	var curve = path.curve
	var path_length = curve.get_baked_length()
	var candlestick_scene = load("res://models/CandlestickSpeedBoost.fbx")
	if not candlestick_scene:
		push_warning("CandlestickSpeedBoost.fbx not found")
		return

	var pickup_script = preload("res://objects/bull_run_pickup.gd")
	var group_script = preload("res://objects/bull_run_group.gd")
	var num_groups := 2
	var candles_per_group := 3
	var candle_spacing := 3.0  # Distance between candles in a group along the track

	# Place candles relative to where the player starts so they appear later in the race
	# First group at ~40% ahead, second at ~75% ahead
	var player_node = get_node_or_null("Vehicle")
	var player_start_offset := 0.0
	if player_node:
		var container = player_node.get_node_or_null("Container")
		if container:
			var local_pos = path.to_local(container.global_position)
			player_start_offset = curve.get_closest_offset(local_pos)
	var group_offsets := [0.4, 0.75]  # Fraction of track ahead of player start

	for g in range(num_groups):
		var group = Node.new()
		group.name = "BullRunGroup_" + str(g)
		group.set_script(group_script)
		add_child(group)

		var base_offset = fmod(player_start_offset + path_length * group_offsets[g], path_length)

		# Get track direction at this point
		var base_pos = curve.sample_baked(fmod(base_offset, path_length))
		var next_pos = curve.sample_baked(fmod(base_offset + 1.0, path_length))
		var direction = (next_pos - base_pos).normalized()

		for c in range(candles_per_group):
			var offset_along = (c - 1) * candle_spacing
			var candle_pos = base_pos + direction * offset_along
			candle_pos.y += -0.8  # Same offset as coins

			# Create Area3D pickup
			var pickup = Area3D.new()
			pickup.name = "BullRunCandle_" + str(g) + "_" + str(c)
			pickup.set_script(pickup_script)
			pickup.group = group
			pickup.collision_layer = 0
			pickup.collision_mask = 8
			pickup.monitoring = true
			# Position relative to the path's parent (same space as coins)
			pickup.position = candle_pos

			# Add the candlestick model
			var model = candlestick_scene.instantiate()
			pickup.add_child(model)

			# Add collision shape
			var shape = BoxShape3D.new()
			shape.size = Vector3(2.5, 4.0, 2.5)
			var collision = CollisionShape3D.new()
			collision.shape = shape
			pickup.add_child(collision)

			pickup.body_entered.connect(pickup._on_body_entered)
			add_child(pickup)
			print("  Candle_", g, "_", c, " at ", pickup.position)

		print("Spawned BullRunGroup_", g, " at offset ", base_offset)

func _make_model_from_fbx(scene: PackedScene) -> Node3D:
	var instance = scene.instantiate()
	instance.name = "Model"
	instance.scale = Vector3(0.2, 0.2, 0.2)
	return instance

func _swap_vehicle_model(vehicle: Node3D, scene: PackedScene):
	var new_model = _make_model_from_fbx(scene)
	if not new_model:
		return

	var container = vehicle.get_node("Container")
	var old_model = container.get_node("Model")
	container.remove_child(old_model)
	old_model.free()
	container.add_child(new_model)
	vehicle.refresh_model_refs()

func _generate_track_collision(node: Node):
	for child in node.get_children():
		# Remove any remaining decoration vehicles
		if child.name.begins_with("SR_Veh_"):
			child.queue_free()
			continue
		# Generate collision for track, barriers, and props (skip jumps)
		if child is MeshInstance3D and (
			child.name.begins_with("SR_Env_")
			or child.name.begins_with("SR_Bld_")
			or child.name.begins_with("SR_Prop_")
		):
			child.create_trimesh_collision()
		_generate_track_collision(child)

func _generate_racing_path(track_root: Node):
	# Find all dirt track pieces and print their positions
	var pieces := []
	_find_track_pieces(track_root, pieces)

	# Sort by name to get correct order
	pieces.sort_custom(func(a, b): return a["name"] < b["name"])

	print("--- Track pieces found: ", pieces.size(), " ---")
	for p in pieces:
		print("  ", p["name"], " -> ", p["pos"])

	if pieces.size() < 3:
		print("Not enough track pieces to generate path")
		return

	# Create the Path3D
	var path = Path3D.new()
	path.name = "RacingPath"
	var curve = Curve3D.new()

	for p in pieces:
		curve.add_point(p["pos"])

	curve.closed = true  # Loop the track
	path.curve = curve
	add_child(path)
	print("Generated RacingPath with ", curve.point_count, " points")

func _find_track_pieces(node: Node, results: Array):
	if node.name.begins_with("SR_Env_Dirt_Track_"):
		results.append({
			"name": String(node.name),
			"pos": node.global_position
		})
	for child in node.get_children():
		_find_track_pieces(child, results)
