extends Node3D

const COIN_SCENE = preload("res://scenes/coin.tscn")

var group_size := 3
var group_spacing := 1.5  # Distance between coins in a group (along track)
var lateral_offset := 0.0  # How far off-center (0 = center of track)
var coin_height := -0.8  # Height relative to the path
var coins_visible := false
var player_start_offset := 0.0  # Set by main before calling spawn_along_path
var spawn_chance := 0.5  # Probability each remaining group actually spawns

func spawn_along_path(path: Path3D, group_count: int = 8):
	if not path or not path.curve or path.curve.point_count < 3:
		return

	var total_length = path.curve.get_baked_length()
	var spacing = total_length / group_count

	for g in range(group_count):
		# Place groups relative to player start, evenly around the track
		var base_offset = fmod(player_start_offset + spacing * g + spacing * 0.5, total_length)

		# Skip groups in the first 40% of the track ahead of player
		var distance_ahead = fmod(base_offset - player_start_offset + total_length, total_length)
		if distance_ahead < total_length * 0.4:
			continue

		# Randomly decide whether this group appears
		if randf() > spawn_chance:
			continue
		var base_pos = path.curve.sample_baked(fmod(base_offset, total_length))

		# Get track direction at this point for alignment
		var next_pos = path.curve.sample_baked(fmod(base_offset + 1.0, total_length))
		var direction = (next_pos - base_pos).normalized()

		# Alternate groups between left, center, and right
		var lateral = Vector3(-direction.z, 0, direction.x).normalized()
		var side_offsets = [0.0, -0.5, 0.5, -0.3, 0.3, 0.0, -0.4, 0.4]
		var side = side_offsets[g % side_offsets.size()]

		for i in range(group_size):
			var offset_along = (i - 1) * group_spacing  # Center the group
			var coin_pos = base_pos + direction * offset_along + lateral * side
			coin_pos.y += coin_height

			var coin = COIN_SCENE.instantiate()
			coin.position = coin_pos
			coin.collision_mask = 8
			coin.visible = false
			coin.set_deferred("monitoring", false)

			add_child(coin)

func reveal_coins():
	if coins_visible:
		return
	coins_visible = true
	for coin in get_children():
		if coin is Area3D:
			coin.visible = true
			coin.monitoring = true
