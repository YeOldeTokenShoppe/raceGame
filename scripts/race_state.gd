extends Node

signal race_started
signal lap_completed(vehicle: Node3D, lap: int)
signal race_finished(results: Array)
signal position_updated(positions: Array)

enum State { COUNTDOWN, RACING, FINISHED }

var state := State.COUNTDOWN
var total_laps := 3
var countdown_time := 3.0

# Per-vehicle race data
var vehicle_data := {}
var racing_path: Path3D
var path_length: float

# Results
var finish_order := []

func _ready():
	set_process(false)

func setup(path: Path3D, vehicles: Array):
	racing_path = path
	path_length = path.curve.get_baked_length()
	print("Path length: ", path_length)

	for v in vehicles:
		var start_offset = _get_vehicle_offset(v)
		vehicle_data[v] = {
			"lap": 0,
			"last_offset": start_offset,
			"total_distance": 0.0,
			"total_progress": start_offset,
			"finished": false,
		}
		print(v.name, " start offset: ", start_offset)

	# Freeze all vehicles during countdown
	for v in vehicle_data:
		var sphere = v.get_node_or_null("Sphere") as RigidBody3D
		if sphere:
			sphere.freeze = true

	state = State.COUNTDOWN
	set_process(true)

var countdown_elapsed := 0.0

func _process(delta):
	match state:
		State.COUNTDOWN:
			_process_countdown(delta)
		State.RACING:
			_process_racing(delta)

func _process_countdown(delta):
	countdown_elapsed += delta
	if countdown_elapsed >= countdown_time:
		for v in vehicle_data:
			var sphere = v.get_node_or_null("Sphere") as RigidBody3D
			if sphere:
				sphere.freeze = false
		state = State.RACING
		race_started.emit()
		print("GO!")

func _process_racing(_delta):
	for v in vehicle_data:
		if vehicle_data[v]["finished"]:
			continue
		_update_vehicle_progress(v)

	_update_positions()

func _update_vehicle_progress(vehicle: Node3D):
	var data = vehicle_data[vehicle]
	var current_offset = _get_vehicle_offset(vehicle)
	var last_offset = data["last_offset"]

	# Calculate how far we moved along the path this frame
	var offset_delta = current_offset - last_offset

	# Handle wrap-around: if offset jumped by more than half the track, it wrapped
	if offset_delta < -path_length * 0.4:
		# Crossed finish line going forward (offset went from near-end to near-start)
		offset_delta += path_length
	elif offset_delta > path_length * 0.4:
		# Went backward across the start (ignore / count as backward)
		offset_delta -= path_length

	# Accumulate total distance traveled
	data["total_distance"] += offset_delta

	# Check for lap completion based on total distance
	var expected_laps = int(data["total_distance"] / path_length)
	if expected_laps > data["lap"] and expected_laps <= total_laps:
		data["lap"] = expected_laps
		print(vehicle.name, " completed lap ", data["lap"], " (total dist: ", snapped(data["total_distance"], 0.1), ")")

		if data["lap"] >= total_laps:
			data["finished"] = true
			finish_order.append(vehicle)
			print(vehicle.name, " FINISHED in position ", finish_order.size())
			_stop_vehicle(vehicle)

		lap_completed.emit(vehicle, data["lap"])

		if data["finished"] and finish_order.size() >= vehicle_data.size():
			_end_race()

	# Update progress for position tracking (laps + current offset)
	data["total_progress"] = data["lap"] * path_length + current_offset
	data["last_offset"] = current_offset

func _update_positions():
	var sorted_vehicles = vehicle_data.keys()
	sorted_vehicles.sort_custom(func(a, b):
		return vehicle_data[a]["total_progress"] > vehicle_data[b]["total_progress"]
	)
	position_updated.emit(sorted_vehicles)

func _get_vehicle_offset(vehicle: Node3D) -> float:
	var model = vehicle.get_node_or_null("Container")
	if not model:
		return 0.0
	var local_pos = racing_path.to_local(model.global_position)
	return racing_path.curve.get_closest_offset(local_pos)

func get_vehicle_lap(vehicle: Node3D) -> int:
	if vehicle in vehicle_data:
		return vehicle_data[vehicle]["lap"]
	return 0

func get_vehicle_position(vehicle: Node3D) -> int:
	var sorted_vehicles = vehicle_data.keys()
	sorted_vehicles.sort_custom(func(a, b):
		return vehicle_data[a]["total_progress"] > vehicle_data[b]["total_progress"]
	)
	return sorted_vehicles.find(vehicle) + 1

func _stop_vehicle(vehicle: Node3D):
	vehicle.finished = true

func _end_race():
	state = State.FINISHED
	set_process(false)

	for v in vehicle_data:
		if not vehicle_data[v]["finished"]:
			finish_order.append(v)
			_stop_vehicle(v)

	race_finished.emit(finish_order)

func get_countdown_remaining() -> float:
	if state == State.COUNTDOWN:
		return max(0.0, countdown_time - countdown_elapsed)
	return 0.0
