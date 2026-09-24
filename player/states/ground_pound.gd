extends AirState
## Crouch in the air: flip in place for a moment, then plummet. Dive out of it
## to launch forward instead; land it to shake the ground.

var dropping := false
var _hit: Array = []


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	player.jump_chain = 0
	player.velocity = Vector3.ZERO
	dropping = false
	_hit.clear()


func physics_update(_delta: float) -> void:
	if time_in_state >= settings.ground_pound_dive_delay and player.consume(&"attack"):
		transition_to(&"Dive")
		return
	if not dropping and time_in_state >= settings.ground_pound_hang_time:
		dropping = true
	player.velocity = Vector3.DOWN * settings.ground_pound_drop_speed if dropping else Vector3.ZERO
	if dropping:
		# Smash through breakable things on the way down.
		player.strike(&"ground_pound", 0.0, 0.6, 0.0, _hit)
	player.move()
	if player.is_on_floor():
		player.land()
		transition_to(&"GroundPoundLand")
	elif player.is_on_wall() and player.get_wall_normal().y > 0.2:
		transition_to(&"SteepSlide")
