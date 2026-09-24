extends AirState
## Sliding down a slope too steep to stand on. Jump to hop off it.

var slope_normal := Vector3.UP


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	player.jump_chain = 0
	if player.is_on_wall():
		slope_normal = player.get_wall_normal()


func physics_update(delta: float) -> void:
	var away := Vector3(slope_normal.x, 0.0, slope_normal.z).normalized()
	if player.consume(&"jump"):
		transition_to(&"Jump", {
			"chain": 0,
			"kind": &"steep_jump",
			"height": settings.steep_jump_height,
			"horizontal": away * settings.steep_jump_speed,
		})
		return
	player.apply_gravity(delta)
	# Gentle steering across the slope.
	var velocity := player.horizontal_velocity()
	var input_dir := player.input.move
	if input_dir.length_squared() > 0.01 and velocity.length_squared() > 0.01:
		var max_turn := deg_to_rad(settings.steep_slide_steering) * delta
		velocity = velocity.rotated(Vector3.UP, clampf(velocity.signed_angle_to(input_dir, Vector3.UP), -max_turn, max_turn))
		player.set_horizontal_velocity(velocity)
	player.face_toward(away, deg_to_rad(settings.air_turn_speed) * delta)
	player.move()
	if check_landing():
		return
	if player.is_on_wall() and player.get_wall_normal().y > 0.2:
		slope_normal = player.get_wall_normal()
	else:
		transition_to(&"Fall")
