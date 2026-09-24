extends AirState
## An air spin: once per jump, a little lift, a slower fall and extra control.


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	player.air_spin_available = false
	air_control = settings.spin_air_control
	can_spin = false
	var lift := settings.jump_velocity(settings.spin_height, settings.spin_gravity_scale, false)
	player.velocity.y = maxf(player.velocity.y, lift)
	player.spun.emit(true)


func physics_update(delta: float) -> void:
	# Only the descent is slowed, so spinning while rising fast isn't a free boost.
	gravity_scale = settings.spin_gravity_scale if player.velocity.y <= 0.0 else 1.0
	super(delta)
	if is_active() and time_in_state >= settings.spin_duration:
		transition_to(&"Fall")
