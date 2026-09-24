extends PlayerState
## Knocked back off a wall after diving into it; briefly stunned on landing.

var _landed := false
var _stun_time := 0.0


func enter(_previous: StringName, msg: Dictionary) -> void:
	var normal: Vector3 = msg.normal
	player.jump_chain = 0
	player.facing = -normal
	player.set_horizontal_velocity(normal * settings.bonk_knockback)
	player.velocity.y = settings.bonk_hop
	_landed = false
	_stun_time = 0.0
	player.bonked.emit(normal)


func physics_update(delta: float) -> void:
	if not _landed:
		player.apply_gravity(delta)
		player.move()
		if player.is_on_floor():
			_landed = true
			player.land()
		return
	var velocity := player.horizontal_velocity().move_toward(Vector3.ZERO, settings.run_deceleration * delta)
	player.set_horizontal_velocity(velocity)
	player.velocity.y = 0.0
	player.move()
	_stun_time += delta
	if not player.is_on_floor():
		transition_to(&"Fall")
	elif _stun_time >= settings.bonk_stun_time:
		player.enter_ground_state()
