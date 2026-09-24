extends GroundState
## Sliding on your feet after crouching at speed; slopes speed you up.
## Jump to long jump.


func enter(_previous: StringName, _msg: Dictionary) -> void:
	player.jump_chain = 0
	# This press was spent crouching; it mustn't become a ground pound after the next jump.
	player.clear_buffer(&"crouch")


func physics_update(delta: float) -> void:
	if player.consume(&"jump"):
		var fast_enough := player.horizontal_speed() >= settings.long_jump_min_speed
		transition_to(&"LongJump" if fast_enough else &"Backflip")
		return
	if player.consume(&"dive"):
		transition_to(&"Dive", {"from_ground": true})
		return
	player.slide_move(delta, settings.crouch_slide_friction, settings.slide_turn_speed)
	player.move(true)
	if check_fall():
		return
	if not player.input.held(&"crouch"):
		player.enter_ground_state() # Stand up, keeping the momentum.
	elif player.horizontal_speed() < 1.0:
		transition_to(&"Crouch")
