extends AirState
## A head-first dive, from the air or from a run. Carries momentum (plus a
## boost), steers only a little, and lands into a belly slide. Diving
## head-first into a wall at speed bonks you off it.

var _slid_off := false
var _hit: Array = []


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	player.jump_chain = 0
	gravity_scale = settings.dive_gravity_scale
	turn_to_velocity = false
	can_dive = false
	can_ground_pound = false
	can_spin = false
	can_wall_kick = false
	can_grab_ledge = false
	_slid_off = msg.get("slide_off", false)
	_hit.clear()
	if _slid_off:
		return # Slid off an edge during a belly slide: no boost, just keep the pose.

	var input_dir := player.input.move
	var direction := input_dir.normalized() if input_dir.length() > 0.3 else player.facing
	var carried := maxf(player.horizontal_velocity().dot(direction), 0.0)
	var boosted := clampf(carried + settings.dive_speed_boost, settings.dive_min_speed, settings.dive_max_speed)
	player.facing = direction
	player.set_horizontal_velocity(direction * maxf(carried, boosted))
	if msg.get("from_ground", false):
		player.velocity.y = settings.dive_ground_hop
	else:
		player.velocity.y = maxf(player.velocity.y, settings.dive_air_hop)


func physics_update(delta: float) -> void:
	if _slid_off and time_in_state < settings.coyote_time and player.consume(&"jump"):
		transition_to(&"Rollout")
		return
	player.strike(&"dive", 0.6, 0.6, 0.5, _hit)
	player.apply_gravity(delta, gravity_scale)
	var velocity := player.horizontal_velocity()
	var input_dir := player.input.move
	if input_dir.length_squared() > 0.01 and velocity.length_squared() > 0.01:
		var max_turn := deg_to_rad(settings.dive_steering) * delta
		velocity = velocity.rotated(Vector3.UP, clampf(velocity.signed_angle_to(input_dir, Vector3.UP), -max_turn, max_turn))
	velocity = velocity.move_toward(Vector3.ZERO, settings.dive_air_drag * delta)
	player.set_horizontal_velocity(velocity)
	if velocity.length_squared() > 0.01:
		player.facing = velocity.normalized()
	player.move()
	if check_landing():
		return
	if player.is_on_wall():
		_hit_wall(player.get_wall_normal())


func on_land() -> void:
	player.land()
	transition_to(&"BellySlide")


func _hit_wall(normal: Vector3) -> void:
	if normal.y > 0.2:
		transition_to(&"SteepSlide")
		return
	var wall := Vector3(normal.x, 0.0, normal.z).normalized()
	var head_on := player.facing.dot(-wall) > 0.5
	var fast := Vector2(player.velocity_before_move.x, player.velocity_before_move.z).length() >= settings.bonk_min_speed
	if head_on and fast:
		transition_to(&"Bonk", {"normal": wall})
