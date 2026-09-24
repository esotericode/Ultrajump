extends AirState
## Jump out of a skid: a tall flip that sends you the new way.


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	var direction: Vector3 = msg.get("direction", -player.facing)
	player.jump_chain = 0
	player.facing = direction
	player.velocity.y = settings.jump_velocity(settings.side_flip_height)
	player.set_horizontal_velocity(direction * settings.side_flip_speed)
	apex_hang = true
	player.jumped.emit(&"side_flip")
