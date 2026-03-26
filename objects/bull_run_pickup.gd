extends Area3D

var grabbed := false
var group: Node  # Reference to the parent group tracker

func _on_body_entered(body):
	if grabbed:
		return

	var vehicle = body.get_parent()
	if not vehicle or not vehicle.get("is_player"):
		return

	grabbed = true

	# Hide this candle
	for child in get_children():
		if child is Node3D and not child is CollisionShape3D:
			child.visible = false
	monitoring = false

	# Notify the group
	if group and group.has_method("candle_collected"):
		group.candle_collected(vehicle)

func _process(delta):
	if not grabbed:
		rotate_y(1.5 * delta)
		position.y += (cos(Time.get_ticks_msec() * 0.003) * 0.3) * delta
