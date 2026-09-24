extends AirState
## Jump while crouching: a tall flip backwards.


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	player.jump_chain = 0
	player.velocity.y = settings.jump_velocity(settings.backflip_height)
	player.set_horizontal_velocity(-player.facing * settings.backflip_back_speed)
	air_control = settings.backflip_air_control
	turn_to_velocity = false
	apex_hang = true
	player.jumped.emit(&"backflip")
