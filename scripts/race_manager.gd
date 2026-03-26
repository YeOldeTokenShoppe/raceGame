extends Node

var racing_path: Path3D

var ai_models := [
	preload("res://models/cars/MuscleCar_Purple.fbx"),
	preload("res://models/cars/MuscleCar_Blue.fbx"),
	preload("res://models/cars/MuscleCar_Purple.fbx"),
]

var ai_configs := [
	{ "speed": 0.82, "look_ahead": 7.0 },
	{ "speed": 0.88, "look_ahead": 5.5 },
	{ "speed": 0.95, "look_ahead": 5.0 },
]

# Staggered grid: two rows, offset from player
var spawn_offsets := [
	Vector3(-3.0, 0, 0),
	Vector3(-3.0, 0, -5.0),
	Vector3(3.0, 0, -5.0),
]

func _ready():
	print("RaceManager _ready() fired")
	# Auto-find the RacingPath node (sibling of this node's parent)
	racing_path = get_parent().get_node_or_null("RacingPath")
	print("Racing path found: ", racing_path)

	# Spawn AI opponents
	var player = get_parent().get_node("Vehicle")
	if not player:
		push_warning("RaceManager: No Vehicle node found")
		return

	if not racing_path:
		push_warning("RaceManager: No racing path assigned — AI won't know where to drive")
		return

	# Give player access to the path too (not used yet, but useful later)
	player.is_player = true

	for i in range(ai_models.size()):
		_spawn_ai(player, i)

func _spawn_ai(player_vehicle: Node3D, index: int):
	# Duplicate the full player vehicle (physics, particles, sounds, everything)
	var ai = player_vehicle.duplicate()
	ai.name = "AI_" + str(index)

	# Swap the truck model to a different color
	var container = ai.get_node("Container")
	var old_model = container.get_node("Model")
	container.remove_child(old_model)
	old_model.free()

	var new_model = ai_models[index].instantiate()
	new_model.name = "Model"
	container.add_child(new_model)

	# Position on the starting grid
	ai.position = player_vehicle.position + spawn_offsets[index]

	# Configure as AI
	ai.is_player = false
	ai.racing_path = racing_path
	ai.ai_speed_factor = ai_configs[index]["speed"]
	ai.ai_look_ahead = ai_configs[index]["look_ahead"]

	# Quiet down AI audio (player's truck should be loudest)
	for snd_path in ["Container/EngineSound", "Container/ScreechSound"]:
		var snd = ai.get_node_or_null(snd_path)
		if snd:
			snd.volume_db -= 12.0

	get_parent().add_child(ai)
