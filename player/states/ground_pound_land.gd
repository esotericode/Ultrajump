extends GroundState
## The impact of a ground pound. Jump right away for a ground pound jump.


func enter(_previous: StringName, _msg: Dictionary) -> void:
	player.velocity = Vector3.ZERO
	player.ground_pound_impact.emit()


func physics_update(_delta: float) -> void:
	if player.consume(&"jump"):
		transition_to(&"GroundPoundJump")
		return
	if player.consume(&"dive"):
		transition_to(&"Dive", {"from_ground": true})
		return
	player.velocity = Vector3.ZERO
	player.move()
	if check_fall():
		return
	if time_in_state >= settings.ground_pound_land_time:
		player.enter_ground_state()
