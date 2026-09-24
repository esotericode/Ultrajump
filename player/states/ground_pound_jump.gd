extends AirState
## Jump right as a ground pound lands: the highest standing jump.


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	var input_dir := player.input.move
	if input_dir.length() > 0.1:
		player.facing = input_dir.normalized()
	player.set_horizontal_velocity(input_dir * settings.ground_pound_jump_speed)
	player.velocity.y = settings.jump_velocity(settings.ground_pound_jump_height)
	apex_hang = true
	player.jumped.emit(&"ground_pound_jump")
