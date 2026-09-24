extends AirState
## Clinging to a wall and sliding down it. Jump to wall kick; hold away from
## the wall (or press crouch) to let go.

var wall_normal := Vector3.ZERO
var _release_time := 0.0


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	wall_normal = msg.normal
	player.facing = -wall_normal
	player.jump_chain = 0
	player.set_horizontal_velocity(Vector3.ZERO)
	player.velocity.y = minf(player.velocity.y, settings.wall_slide_speed)
	_release_time = 0.0


func physics_update(delta: float) -> void:
	if player.consume(&"jump"):
		transition_to(&"WallKick", {"normal": wall_normal})
		return
	if player.consume(&"crouch"):
		_let_go()
		return
	_release_time = _release_time + delta if player.input.move.dot(wall_normal) > 0.5 else 0.0
	if _release_time > settings.wall_release_time:
		_let_go()
		return

	if player.velocity.y > 0.0:
		player.apply_gravity(delta)
	else:
		player.velocity.y = move_toward(player.velocity.y, -settings.wall_slide_speed, settings.wall_slide_deceleration * delta)
	# Keep pressing into the wall so the contact holds.
	player.set_horizontal_velocity(-wall_normal * 1.5)
	player.move()
	if check_landing() or check_ledge():
		return
	if not player.is_on_wall():
		transition_to(&"Fall")
		return
	var normal := player.get_wall_normal()
	if absf(normal.y) < 0.3:
		wall_normal = Vector3(normal.x, 0.0, normal.z).normalized()
		player.facing = -wall_normal


func _let_go() -> void:
	player.start_wall_cooldown(wall_normal)
	player.set_horizontal_velocity(wall_normal * 2.0)
	transition_to(&"Fall")
