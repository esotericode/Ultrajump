extends AirState
## Kicking off a wall: up and away, angled a little by the stick. Steering is
## damped for a moment so you don't drift straight back into the wall.

var _control_lock := 0.0


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	var normal: Vector3 = msg.normal
	var input_dir := player.input.move
	var along_wall := input_dir - normal * input_dir.dot(normal)
	var direction := (normal + along_wall * settings.wall_kick_input_influence).normalized()
	player.facing = direction
	player.set_horizontal_velocity(direction * settings.wall_kick_speed)
	player.velocity.y = settings.jump_velocity(settings.wall_kick_height)
	player.start_wall_cooldown(normal)
	player.air_spin_available = true
	_control_lock = settings.wall_kick_control_lock
	apex_hang = true
	player.jumped.emit(&"wall_kick")
	player.wall_kicked.emit(normal)


func physics_update(delta: float) -> void:
	_control_lock -= delta
	air_control = 0.15 if _control_lock > 0.0 else 1.0
	super(delta)
