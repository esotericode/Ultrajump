extends GroundState
## Running. Speed builds along the facing direction, which turns toward the
## stick; yanking the stick backwards at speed skids.


func physics_update(delta: float) -> void:
	if handle_ground_actions():
		return
	var input_dir := player.input.move
	var speed := player.horizontal_speed()
	if input_dir.length_squared() < 0.0025 and speed < 0.1:
		transition_to(&"Idle")
		return
	if _wants_to_skid(input_dir, speed):
		transition_to(&"Skid")
		return
	player.run_move(delta)
	player.move(true)
	check_fall()


func _wants_to_skid(input_dir: Vector3, speed: float) -> bool:
	if speed < settings.skid_min_speed or input_dir.length() < 0.5:
		return false
	return rad_to_deg(player.facing.angle_to(input_dir)) > settings.skid_angle
