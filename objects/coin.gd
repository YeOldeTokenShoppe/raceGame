extends Area3D

var time := 0.0
var grabbed := false

# Collecting coins

func _on_body_entered(body):
	if grabbed:
		return

	# The body is the Sphere (RigidBody3D) — walk up to the Vehicle node
	var vehicle = body.get_parent()
	if not vehicle or not vehicle.has_method("collect_coin"):
		return
	# Only the player can collect coins
	if not vehicle.get("is_player"):
		return
	vehicle.collect_coin()

	# Play coin sound
	var sfx = AudioStreamPlayer.new()
	sfx.stream = preload("res://audio/coin.ogg")
	sfx.bus = "Master"
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	$Mesh.queue_free()
	$Particles.emitting = false

	grabbed = true

# Rotating, animating up and down

func _process(delta):
	
	rotate_y(2 * delta) # Rotation
	position.y += (cos(time * 5) * 1) * delta # Sine movement
	
	time += delta
