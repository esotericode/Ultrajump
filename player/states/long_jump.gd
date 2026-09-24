extends AirState
## Jump out of a crouch slide: low, fast and far. Steering is limited, and
## holding crouch through the landing slides straight into another one.


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	var speed := player.horizontal_speed()
	var direction := player.horizontal_velocity() / speed if speed > 0.1 else player.facing
	var boosted := minf(speed * settings.long_jump_speed_multiplier, settings.long_jump_max_speed)
	player.jump_chain = 0
	player.facing = direction
	player.set_horizontal_velocity(direction * maxf(boosted, speed))
	gravity_scale = settings.long_jump_gravity_scale
	player.velocity.y = settings.jump_velocity(settings.long_jump_height, gravity_scale, false)
	air_control = settings.long_jump_air_control
	turn_to_velocity = false
	can_ground_pound = false
	player.jumped.emit(&"long_jump")
