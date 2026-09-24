extends AirState
## The instant after hitting a wall in the air: a short window to wall kick.
##
## Like Super Mario 64, the kick is a timing skill rather than a hold: press
## jump within [member MovementSettings.wall_kick_window] of the hit (or
## [member MovementSettings.wall_kick_early_window] before it). Miss it and you
## bounce off, with no more tries on that wall until you land or kick off
## another one.

var wall_normal := Vector3.ZERO


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	wall_normal = msg.normal
	player.facing = -wall_normal
	player.jump_chain = 0
	player.set_horizontal_velocity(Vector3.ZERO)
	# The hit stops upward momentum, so every kick starts from the same place.
	player.velocity.y = minf(player.velocity.y, 0.0)


func physics_update(delta: float) -> void:
	# Presses since the hit, or up to the early window before it, all count.
	if player.consume(&"jump", time_in_state + settings.wall_kick_early_window):
		_kick()
		return
	if time_in_state >= settings.wall_kick_window:
		_bounce_off()
		return
	# Cling for the brief window: barely any gravity, pressed against the wall.
	player.apply_gravity(delta, 0.25)
	player.set_horizontal_velocity(-wall_normal * 1.0)
	player.move()
	if check_landing() or check_ledge():
		return
	if not player.is_on_wall():
		transition_to(&"Fall")


func _kick() -> void:
	transition_to(&"WallKick", {"normal": wall_normal})


func _bounce_off() -> void:
	player.miss_wall(wall_normal)
	player.set_horizontal_velocity(wall_normal * settings.wall_bounce_speed)
	transition_to(&"Fall")
