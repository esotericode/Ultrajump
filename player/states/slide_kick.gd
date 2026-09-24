extends AirState
## Attack during a crouch slide: a low kick that bursts forward along the
## ground and hits whatever it meets, landing back in a slide.

var _hit: Array = []


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	_hit.clear()
	var speed := player.horizontal_speed()
	var direction := player.horizontal_velocity() / speed if speed > 0.5 else player.facing
	player.jump_chain = 0
	player.facing = direction
	player.set_horizontal_velocity(direction * maxf(speed, settings.slide_kick_speed))
	player.velocity.y = settings.slide_kick_hop
	air_control = 0.3
	turn_to_velocity = false
	can_dive = false
	can_ground_pound = false
	can_spin = false
	can_grab_ledge = false
	player.attacked.emit(&"slide_kick")


func physics_update(delta: float) -> void:
	player.strike(&"slide_kick", 0.6, 0.6, 0.4, _hit)
	super(delta)
