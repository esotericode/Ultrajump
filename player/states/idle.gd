extends GroundState
## Standing still.


func physics_update(delta: float) -> void:
	if handle_ground_actions():
		return
	if player.input.move.length_squared() > 0.0025:
		transition_to(&"Run")
		return
	player.run_move(delta)
	player.move(true)
	check_fall()
