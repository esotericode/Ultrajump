extends GroundState
## Braking hard to turn around after reversing the stick at speed.
## Jump during the skid to side flip.

## Where the player wants to go once the skid is over.
var turn_direction := Vector3.ZERO


func enter(_previous: StringName, _msg: Dictionary) -> void:
	player.jump_chain = 0
	var input_dir := player.input.move
	turn_direction = input_dir.normalized() if input_dir.length() > 0.1 else -player.facing


func physics_update(delta: float) -> void:
	var input_dir := player.input.move
	if input_dir.length() > 0.3:
		turn_direction = input_dir.normalized()
	if player.consume(&"jump"):
		transition_to(&"SideFlip", {"direction": turn_direction})
		return
	if player.consume(&"dive"):
		player.facing = turn_direction
		player.set_horizontal_velocity(Vector3.ZERO)
		transition_to(&"Dive", {"from_ground": true})
		return
	if input_dir.length() > 0.3 and rad_to_deg(player.facing.angle_to(input_dir)) < 90.0:
		transition_to(&"Run") # Changed our mind: keep running forward.
		return

	var speed := move_toward(player.horizontal_speed(), 0.0, settings.skid_deceleration * delta)
	player.set_horizontal_velocity(player.facing * speed)
	player.velocity.y = 0.0
	player.move(true)
	if check_fall():
		return
	if speed <= 0.5 or time_in_state >= settings.skid_max_time:
		player.facing = turn_direction
		player.set_horizontal_velocity(Vector3.ZERO)
		transition_to(&"Run" if input_dir.length_squared() > 0.0025 else &"Idle")
