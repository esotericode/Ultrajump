class_name Player
extends CharacterBody3D
## A 3D platformer character with a large, expressive moveset.
##
## Behaviour lives in movement states (children of [code]StateMachine[/code]);
## this script holds what they share: the input snapshot and buffers, and the
## physics helpers every state builds on. Visuals, sound and particles only
## react to the signals below and never drive movement. Every tuning value is
## in [member settings].

# These are emitted by the movement states rather than by this script.
@warning_ignore_start("unused_signal")
## Emitted after every state change, e.g. [code]&"Run" -> &"Jump"[/code].
signal state_changed(previous: StringName, current: StringName)
## A jump of some [param kind] left the ground (or a wall / ledge). Kinds:
## single, double, triple, backflip, side_flip, long_jump, rollout, wall_kick,
## ground_pound_jump, ledge_jump, steep_jump.
signal jumped(kind: StringName)
## Touched down after being airborne, at [param impact_speed] m/s.
signal landed(impact_speed: float)
signal ground_pound_impact
signal wall_kicked(wall_normal: Vector3)
signal bonked(wall_normal: Vector3)
signal ledge_grabbed
## An air spin started ([param in_air] true) or a cosmetic ground twirl ([param in_air] false).
signal spun(in_air: bool)
@warning_ignore_restore("unused_signal")
## Moved instantly (respawn / debug teleport); visuals should snap, not blend.
signal teleported
## Popped up or down a step by [param height] meters while walking; visuals can smooth it out.
signal stepped(height: float)

@export var settings: MovementSettings
## Node whose orientation makes stick input camera-relative (normally the camera).
@export var view: Node3D

## The input snapshot states read from. Set [code]input.scripted = true[/code] to drive it from code.
var input := PlayerInput.new()
## Horizontal unit vector the character faces. Ground movement always follows it.
var facing := Vector3.FORWARD
## Position in the single/double/triple chain of the last jump (0 = not chaining).
var jump_chain := 0
var time_since_landing := 0.0
var air_spin_available := true
## Velocity just before the last [method move], i.e. before collisions altered it.
var velocity_before_move := Vector3.ZERO
## Whether the body has been moved during the current physics tick.
var moved_this_tick := false
## Blocks ledge grabs while positive (after dropping from a ledge, etc).
var ledge_cooldown := 0.0
## Collision cylinder dimensions, read from the collision shape.
var radius := 0.35
var height := 1.5

# Stats of the most recent airborne stretch, for tuning (shown on the debug HUD).
var last_air_height := 0.0
var last_air_distance := 0.0
var last_air_time := 0.0

var state_name: StringName:
	get:
		return state_machine.current.name if state_machine and state_machine.current else &""

var _press_ages: Dictionary[StringName, float] = {}
var _wall_cooldown := 0.0
var _wall_cooldown_normal := Vector3.ZERO
var _missed_walls: Array[Vector3] = []
var _air_start := Vector3.ZERO
var _air_peak := 0.0
var _air_time := 0.0
var _was_grounded := true

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if settings == null:
		settings = MovementSettings.new()
	for action in PlayerInput.ACTIONS:
		_press_ages[action] = INF
	var cylinder := collision_shape.shape as CylinderShape3D
	if cylinder:
		radius = cylinder.radius
		height = cylinder.height
	platform_on_leave = PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_block_on_wall = true
	facing = _flat(-global_basis.z, Vector3.FORWARD)
	global_basis = Basis.IDENTITY
	_air_start = global_position
	_apply_settings()
	state_machine.setup(self)


func _physics_process(delta: float) -> void:
	_apply_settings()
	input.gather(view.global_basis if view else Basis.IDENTITY)
	_update_buffers(delta)
	_wall_cooldown = maxf(_wall_cooldown - delta, 0.0)
	ledge_cooldown = maxf(ledge_cooldown - delta, 0.0)
	time_since_landing += delta
	moved_this_tick = false
	state_machine.physics_update(delta)
	_track_air_stats(delta)
	input.end_tick()


# --- Input buffering ---------------------------------------------------------

## Uses up a recent press of [param action]. Presses stay usable for
## [member MovementSettings.input_buffer_time] (or [param max_age] seconds, if
## given), so a press slightly before landing still counts.
func consume(action: StringName, max_age := -1.0) -> bool:
	var window := settings.input_buffer_time if max_age < 0.0 else max_age
	if _press_ages.get(action, INF) <= window:
		_press_ages[action] = INF
		return true
	return false


func is_buffered(action: StringName) -> bool:
	return _press_ages.get(action, INF) <= settings.input_buffer_time


func clear_buffer(action: StringName) -> void:
	_press_ages[action] = INF


func _update_buffers(delta: float) -> void:
	for action in PlayerInput.ACTIONS:
		_press_ages[action] += delta
		if input.pressed(action):
			_press_ages[action] = 0.0


# --- Velocity helpers ---------------------------------------------------------

func horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


## Rotates [member facing] toward [param direction] by at most [param max_angle] radians.
func face_toward(direction: Vector3, max_angle: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.000001:
		return
	var angle := facing.signed_angle_to(direction.normalized(), Vector3.UP)
	facing = facing.rotated(Vector3.UP, clampf(angle, -max_angle, max_angle)).normalized()


## Turns to face the direction of horizontal travel.
func face_velocity(delta: float, turn_speed_degrees: float) -> void:
	var hv := horizontal_velocity()
	if hv.length_squared() > 0.25:
		face_toward(hv, deg_to_rad(turn_speed_degrees) * delta)


## Gravity with the platformer niceties: faster falls, a floaty apex while jump
## is held, and extra gravity when jump is released early (variable height).
func apply_gravity(delta: float, gravity_scale := 1.0, variable_height := false, apex_hang := false) -> void:
	var s := settings
	var g := s.gravity * gravity_scale
	var holding_jump := input.held(&"jump")
	if velocity.y > 0.0:
		if variable_height and not holding_jump:
			g *= s.jump_release_gravity_multiplier
		elif apex_hang and holding_jump and velocity.y < s.apex_speed_threshold:
			g *= s.apex_gravity_multiplier
	else:
		g *= s.fall_gravity_multiplier
		if apex_hang and holding_jump and velocity.y > -s.apex_speed_threshold:
			g *= s.apex_gravity_multiplier
	velocity.y = maxf(velocity.y - g * delta, -s.terminal_velocity)


## Grounded running. Speed builds along [member facing], and facing turns toward
## the stick at a rate that drops as speed rises: tight turns when slow, weighty
## arcs when fast.
func run_move(delta: float) -> void:
	var s := settings
	var input_dir := input.move
	var strength := input_dir.length()
	var speed := horizontal_speed()
	if strength > 0.05:
		var turn_speed := lerpf(s.turn_speed_slow, s.turn_speed_fast, clampf(speed / s.run_speed, 0.0, 1.0))
		face_toward(input_dir, deg_to_rad(turn_speed) * delta)
		var target := s.run_speed * strength * _slope_speed_factor()
		if speed < target:
			speed = maxf(speed, minf(s.run_start_speed, target))
			speed = move_toward(speed, target, s.run_acceleration * delta)
		else:
			speed = move_toward(speed, target, s.overspeed_deceleration * delta)
	else:
		var decel := s.overspeed_deceleration if speed > s.run_speed else s.run_deceleration
		speed = move_toward(speed, 0.0, decel * delta)
	set_horizontal_velocity(facing * speed)
	velocity.y = 0.0


## Slow crouched movement toward the stick.
func crawl_move(delta: float) -> void:
	var s := settings
	var target := input.move * s.crawl_speed
	var hv := horizontal_velocity().move_toward(target, s.run_deceleration * delta)
	set_horizontal_velocity(hv)
	if input.move.length_squared() > 0.01:
		face_toward(input.move, deg_to_rad(s.turn_speed_slow) * delta)
	velocity.y = 0.0


## Sliding (crouch slide / belly slide): friction, slopes pull you downhill, and
## the stick only steers the slide gently.
func slide_move(delta: float, friction: float, turn_speed_degrees: float) -> void:
	var s := settings
	var hv := horizontal_velocity()
	if is_on_floor():
		var n := get_floor_normal()
		hv += Vector3(n.x, 0.0, n.z) * s.gravity * s.slide_slope_acceleration * delta
	hv = hv.move_toward(Vector3.ZERO, friction * delta)
	var input_dir := input.move
	if input_dir.length_squared() > 0.01 and hv.length_squared() > 0.01:
		var max_turn := deg_to_rad(turn_speed_degrees) * delta * minf(input_dir.length(), 1.0)
		hv = hv.rotated(Vector3.UP, clampf(hv.signed_angle_to(input_dir, Vector3.UP), -max_turn, max_turn))
	hv = hv.limit_length(s.slide_max_speed)
	set_horizontal_velocity(hv)
	if hv.length_squared() > 0.25:
		facing = hv.normalized()
	velocity.y = 0.0


## Air control. Accelerates toward the stick direction, but momentum above
## [member MovementSettings.air_max_speed] is preserved: steering can redirect
## it and pulling back brakes it, but it is otherwise only worn down by drag.
func air_move(delta: float, control := 1.0) -> void:
	var s := settings
	var hv := horizontal_velocity()
	var speed := hv.length()
	var input_dir := input.move
	if input_dir.length_squared() > 0.0025 and control > 0.0:
		var steered := hv.move_toward(input_dir * s.air_max_speed, s.air_acceleration * control * delta)
		if speed > s.air_max_speed:
			var keep := maxf(speed - s.air_overspeed_drag * delta, s.air_max_speed)
			var steered_speed := steered.length()
			if steered_speed > keep or (input_dir.dot(hv) >= 0.0 and steered_speed > 0.001):
				steered = steered * (keep / steered_speed)
		hv = steered
	else:
		var drag := s.air_idle_drag
		if speed > s.air_max_speed:
			drag = maxf(drag, s.air_overspeed_drag)
		hv = hv.move_toward(Vector3.ZERO, drag * delta)
	set_horizontal_velocity(hv)


## Moves the body with [method CharacterBody3D.move_and_slide]. With
## [param allow_step] (grounded states), small steps are climbed automatically.
func move(allow_step := false) -> void:
	velocity_before_move = velocity
	moved_this_tick = true
	if allow_step and is_on_floor() and _try_step_up():
		return
	var height_before := global_position.y
	var on_flat_floor := is_on_floor() and get_floor_normal().y > 0.99
	move_and_slide()
	# On flat, static ground, any drop is floor snapping down a step.
	if allow_step and on_flat_floor and is_on_floor() and get_floor_normal().y > 0.99 and get_platform_velocity().is_zero_approx():
		var drop := global_position.y - height_before
		if drop < -0.02:
			stepped.emit(drop)


## Where to go once landed: running, standing, or crouching/sliding if crouch is held.
func enter_ground_state() -> void:
	var speed := horizontal_speed()
	if speed > 0.5:
		facing = horizontal_velocity() / speed
	if input.held(&"crouch"):
		state_machine.transition_to(&"CrouchSlide" if speed >= settings.crouch_slide_min_speed else &"Crouch")
	elif speed > 0.1 or input.move.length_squared() > 0.0025:
		state_machine.transition_to(&"Run")
	else:
		state_machine.transition_to(&"Idle")


## Bookkeeping for touching down. [param keep_chain] keeps the jump chain alive.
func land(keep_chain := false) -> void:
	landed.emit(maxf(-velocity_before_move.y, 0.0))
	time_since_landing = 0.0
	if not keep_chain:
		jump_chain = 0
	air_spin_available = true
	_missed_walls.clear()
	# Crouch / spin presses made in the air shouldn't leak into the next move.
	clear_buffer(&"crouch")
	clear_buffer(&"spin")


## Which jump of the chain the next jump press should be (1, 2 or 3).
func next_chain_jump() -> int:
	var s := settings
	if jump_chain == 0 or time_since_landing > s.jump_chain_window:
		return 1
	var speed := horizontal_speed()
	if jump_chain == 1 and speed >= s.double_jump_min_speed:
		return 2
	if jump_chain == 2 and speed >= s.triple_jump_min_speed:
		return 3
	return 1


# --- Walls and ledges ------------------------------------------------------------

## Whether hitting the wall facing [param wall_normal] counts as a wall contact
## (a chance to wall kick).
func can_touch_wall(wall_normal: Vector3) -> bool:
	if _wall_cooldown > 0.0 and wall_normal.dot(_wall_cooldown_normal) > 0.9:
		return false
	for missed in _missed_walls:
		if wall_normal.dot(missed) > 0.9:
			return false
	return height_above_ground(settings.wall_contact_min_height + 0.1) >= settings.wall_contact_min_height


## Ignores the wall facing [param wall_normal] for a moment (just kicked off it).
func start_wall_cooldown(wall_normal: Vector3) -> void:
	_wall_cooldown = settings.wall_regrab_cooldown
	_wall_cooldown_normal = wall_normal


## The kick off this wall was missed: no more tries on it until landing or a
## successful kick off another wall.
func miss_wall(wall_normal: Vector3) -> void:
	_missed_walls.append(wall_normal)


func forgive_missed_walls() -> void:
	_missed_walls.clear()


## Distance from the feet down to the ground, or [param max_distance] if further.
func height_above_ground(max_distance := 100.0) -> float:
	var from := global_position + Vector3.UP * 0.05
	var hit := _ray(from, from + Vector3.DOWN * (max_distance + 0.05))
	if hit.is_empty():
		return max_distance
	return global_position.y - (hit.position as Vector3).y


## Looks for a ledge in [param direction] whose top is between just above the
## feet and [member MovementSettings.ledge_max_height]. Returns an empty
## dictionary, or one with: [code]top_y[/code], [code]normal[/code] (wall
## normal, horizontal), [code]edge[/code], [code]hang_position[/code] and
## [code]stand_position[/code]. Room to stand on top is guaranteed; room to
## hang is not (check [method is_space_blocked] on [code]hang_position[/code]).
func find_ledge(direction: Vector3) -> Dictionary:
	var s := settings
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return {}
	direction = direction.normalized()
	var feet := global_position
	var reach := radius + 0.3

	# 1. A walkable top surface just past the wall, within hand reach.
	var probe := feet + direction * reach
	var top := _ray(probe + Vector3.UP * (s.ledge_max_height + 0.05), probe + Vector3.UP * 0.15)
	if top.is_empty() or (top.normal as Vector3).y < cos(floor_max_angle) or _is_moving_body(top.collider):
		return {}
	var top_y: float = (top.position as Vector3).y

	# 2. The ledge's face, just below its top, right in front of us.
	var face_from := Vector3(feet.x, top_y - 0.1, feet.z)
	var face := _ray(face_from, face_from + direction * (reach + 0.1))
	if face.is_empty() or absf((face.normal as Vector3).y) > 0.3:
		return {}
	var normal := _flat(face.normal, -direction)

	# 3. Open air just above the top: a ledge, not a notch in a taller wall.
	var above_from := Vector3(feet.x, top_y + 0.15, feet.z)
	if not _ray(above_from, above_from + direction * (reach + 0.1)).is_empty():
		return {}

	# 4. Room to pull ourselves straight up past the edge, and to stand on top.
	var face_point: Vector3 = face.position
	var edge := Vector3(face_point.x, top_y, face_point.z)
	var hang_position := edge + normal * (radius + 0.02) + Vector3.DOWN * s.ledge_hang_depth
	var stand_position := edge - normal * (radius + 0.15) + Vector3.UP * 0.05
	var lifted_position := Vector3(feet.x, stand_position.y, feet.z)
	if is_space_blocked(stand_position) or is_space_blocked(lifted_position):
		return {}
	return {
		"top_y": top_y,
		"normal": normal,
		"edge": edge,
		"hang_position": hang_position,
		"stand_position": stand_position,
	}


## True if the player's collision shape would overlap level geometry with its feet at [param feet_position].
func is_space_blocked(feet_position: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = Transform3D(Basis.IDENTITY, feet_position + collision_shape.position)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# --- Teleporting ---------------------------------------------------------------

## Instantly moves the player (respawn / debug stations), facing [param xform]'s -Z.
func teleport(xform: Transform3D) -> void:
	global_position = xform.origin
	facing = _flat(-xform.basis.z, facing)
	velocity = Vector3.ZERO
	jump_chain = 0
	_air_start = global_position
	_air_peak = global_position.y
	state_machine.transition_to(&"Fall")
	reset_physics_interpolation()
	teleported.emit()


# --- Internals -------------------------------------------------------------------

func _apply_settings() -> void:
	floor_max_angle = deg_to_rad(settings.max_floor_angle)
	floor_snap_length = maxf(settings.step_height + 0.1, 0.2)


func _slope_speed_factor() -> float:
	if not is_on_floor():
		return 1.0
	var n := get_floor_normal()
	# The floor normal's horizontal part points downhill; its length is sin(slope).
	return 1.0 + facing.dot(Vector3(n.x, 0.0, n.z)) * settings.slope_speed_influence


## Walks up steps no taller than [member MovementSettings.step_height]: if the
## horizontal move is blocked, try it from higher up and settle onto the step.
func _try_step_up() -> bool:
	var motion := horizontal_velocity() * get_physics_process_delta_time()
	if motion.length_squared() < 0.000001 or settings.step_height <= 0.0:
		return false
	var start := global_transform
	var blocker := KinematicCollision3D.new()
	if not test_move(start, motion, blocker):
		return false
	if blocker.get_normal().y >= cos(floor_max_angle):
		return false # A walkable slope; move_and_slide handles it.
	var lift := Vector3.UP * settings.step_height
	var ceiling := KinematicCollision3D.new()
	if test_move(start, lift, ceiling):
		lift = ceiling.get_travel()
	var raised := start.translated(lift)
	if test_move(raised, motion):
		return false # Still blocked from up high: a wall, not a step.
	var over_step := raised.translated(motion)
	var ground := KinematicCollision3D.new()
	if not test_move(over_step, -lift - Vector3.UP * 0.05, ground):
		return false # Nothing to stand on up there.
	if ground.get_normal().y < cos(floor_max_angle):
		return false
	var landed_transform := over_step.translated(ground.get_travel())
	var rise := landed_transform.origin.y - start.origin.y
	if rise < 0.01:
		return false
	global_transform = landed_transform
	stepped.emit(rise)
	return true


func _track_air_stats(delta: float) -> void:
	var grounded := is_on_floor() or state_name in [&"LedgeHang", &"LedgeClimb"]
	if grounded:
		if not _was_grounded:
			last_air_time = _air_time
			last_air_height = _air_peak - _air_start.y
			last_air_distance = Vector2(global_position.x - _air_start.x, global_position.z - _air_start.z).length()
		_air_start = global_position
		_air_peak = global_position.y
		_air_time = 0.0
	else:
		_air_time += delta
		_air_peak = maxf(_air_peak, global_position.y)
	_was_grounded = grounded


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


func _is_moving_body(collider: Object) -> bool:
	return collider is AnimatableBody3D or collider is RigidBody3D or collider is CharacterBody3D


static func _flat(v: Vector3, fallback: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length_squared() > 0.000001 else fallback
