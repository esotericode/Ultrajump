class_name PlayerCamera
extends Node3D
## Third-person orbit camera tuned for 3D platforming.
##
## Built to stay calm: it only rotates when you rotate it, and it never snaps.
## - Orbit with the mouse or right stick; tap recenter to swing behind the player.
## - Follows closely on the ground, but only lazily in the air: small hops
##   don't bob the view, so jump arcs read clearly. It catches up on landing,
##   or as soon as the player climbs or falls out of a comfortable band.
## - Slides in (quickly, but never in a single frame) when a wall gets between
##   it and the player, and eases back out once the view clears.
## - Widens the FOV a little at very high speed and shakes on big impacts.
##
## This node is the camera's pose; the Camera3D child just renders it. It
## updates every rendered frame from the player's interpolated transform.
## tests/camera_metrics.gd measures how much it moves on its own.

@export var target: Player

@export_group("Orbit")
@export var distance := 6.5
@export_range(-89.0, 89.0, 1.0, "suffix:°") var default_pitch := -16.0
@export_range(-89.0, 0.0, 1.0, "suffix:°") var min_pitch := -70.0
@export_range(-89.0, 89.0, 1.0, "suffix:°") var max_pitch := 30.0
@export var mouse_sensitivity := 0.0025
@export_range(0.0, 720.0, 5.0, "suffix:°/s") var stick_turn_speed := 200.0
@export var invert_x := false
@export var invert_y := false

@export_group("Follow")
## Height above the player's feet the camera looks at.
@export var focus_height := 1.2
## How tightly the camera keeps up horizontally. Higher keeps the player more centered.
@export var horizontal_follow_rate := 16.0
@export var vertical_follow_rate := 5.0
## While airborne, the view only rises once the player is this far above where they took off...
@export var air_band_above := 2.2
## ...and follows right away once they drop this far below it.
@export var air_band_below := 0.4

@export_group("Auto Align")
## Swing behind the player while running, once the camera hasn't been touched
## for [member auto_align_delay] seconds. Off by default: a camera that turns
## by itself also turns the (camera-relative) controls under your thumb.
@export var auto_align := false
@export var auto_align_delay := 2.0
@export var auto_align_strength := 0.6

@export_group("Collision")
@export_flags_3d_physics var collision_mask := 1
@export var collision_radius := 0.2
## The camera never gets closer to the focus point than this, even against a wall.
@export var min_distance := 1.2
## Top speed when sliding in because something is in the way.
@export var pull_in_speed := 20.0
## How quickly the camera eases back out once the view is clear...
@export var push_out_rate := 2.5
## ...after it has stayed clear for this long.
@export var push_out_delay := 0.25

@export_group("Feel")
@export var base_fov := 70.0
@export var speed_fov_bonus := 5.0
## Horizontal speeds above this widen the FOV (running tops out at 10 m/s).
@export var fov_speed_threshold := 12.0
@export var max_shake_offset := 0.2

var yaw := 0.0
var pitch := 0.0

var _focus := Vector3.ZERO
var _anchor_y := 0.0
var _distance := 6.5
var _clear_time := 0.0
var _since_manual := 100.0
var _recentering := false
var _trauma := 0.0
var _time := 0.0
var _noise := FastNoiseLite.new()
var _probe := SphereShape3D.new()

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	top_level = true
	# Moved every rendered frame from interpolated data, so it must not be interpolated itself.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_noise.frequency = 1.5
	_probe.radius = collision_radius
	pitch = deg_to_rad(default_pitch)
	camera.fov = base_fov
	if target:
		target.view = self
		target.ground_pound_impact.connect(add_trauma.bind(0.4))
		target.bonked.connect(func(_normal: Vector3) -> void: add_trauma(0.3))
		target.attack_landed.connect(func(_kind: StringName, _where: Vector3) -> void: add_trauma(0.12))
		target.teleported.connect(snap_behind)
		snap_behind.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= motion.relative.x * mouse_sensitivity * (-1.0 if invert_x else 1.0)
		pitch -= motion.relative.y * mouse_sensitivity * (-1.0 if invert_y else 1.0)
		_manual_control()


func _process(delta: float) -> void:
	if target == null:
		return
	_time += delta
	var look := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if look != Vector2.ZERO:
		var turn := deg_to_rad(stick_turn_speed) * delta
		yaw -= look.x * turn * (-1.0 if invert_x else 1.0)
		pitch -= look.y * turn * 0.6 * (-1.0 if invert_y else 1.0)
		_manual_control()
	else:
		_since_manual += delta
	if Input.is_action_just_pressed(&"camera_recenter"):
		_recentering = true

	if _recentering:
		_recenter(delta)
	elif auto_align and _since_manual > auto_align_delay:
		_auto_align(delta)
	pitch = clampf(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	_follow(_target_feet(), delta)
	_place(delta)
	var speed_boost := clampf((target.horizontal_speed() - fov_speed_threshold) / 8.0, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, base_fov + speed_fov_bonus * speed_boost, _blend(1.5, delta))


## Kicks off a camera shake; [param amount] 0..1 stacks up to 1.
func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## Instantly puts the camera behind the player (after spawning or teleporting).
func snap_behind() -> void:
	if target == null:
		return
	yaw = _yaw_toward(target.facing)
	pitch = deg_to_rad(default_pitch)
	var feet := target.global_position
	_anchor_y = feet.y
	_focus = feet + Vector3.UP * focus_height
	_distance = distance
	_clear_time = 0.0
	_recentering = false
	_place(0.0)


## The player's smoothly interpolated position. Right after a teleport the
## interpolated value still points at the old spot until the next physics
## tick, so fall back to the real position when the two are far apart.
func _target_feet() -> Vector3:
	var interpolated := target.get_global_transform_interpolated().origin
	if interpolated.distance_squared_to(target.global_position) > 9.0:
		return target.global_position
	return interpolated


func _manual_control() -> void:
	_since_manual = 0.0
	_recentering = false


func _recenter(delta: float) -> void:
	var behind := _yaw_toward(target.facing)
	yaw = lerp_angle(yaw, behind, _blend(12.0, delta))
	pitch = lerpf(pitch, deg_to_rad(default_pitch), _blend(10.0, delta))
	if absf(angle_difference(yaw, behind)) < 0.01:
		_recentering = false


func _auto_align(delta: float) -> void:
	var velocity := target.horizontal_velocity()
	var speed := velocity.length()
	if speed < 2.0 or not target.is_on_floor():
		return
	var offset := angle_difference(yaw, _yaw_toward(velocity / speed))
	if absf(offset) > deg_to_rad(110.0):
		return # Running toward the camera: don't whip around.
	var strength := auto_align_strength * clampf(speed / target.settings.run_speed, 0.0, 1.0)
	yaw += offset * minf(strength * delta, 1.0)


func _follow(feet: Vector3, delta: float) -> void:
	# Follow tighter when pulled in close, so the lag looks the same on screen.
	var closeness := clampf(distance / maxf(_distance, 0.1), 1.0, 5.0)
	var follow := _blend(horizontal_follow_rate * closeness, delta)
	_focus.x = lerpf(_focus.x, feet.x, follow)
	_focus.z = lerpf(_focus.z, feet.z, follow)

	# The air band shrinks when the camera is pulled in, where the same height
	# difference covers more of the screen.
	var reach := clampf(_distance / distance, 0.2, 1.0)
	var band_above := air_band_above * reach
	var band_below := air_band_below * reach
	var settled := target.is_on_floor() or target.state_name in [&"WallContact", &"LedgeHang", &"LedgeClimb"]
	if settled:
		# Small steps ease in gently; big climbs (a ledge, a tall step) catch up fast.
		var gap := absf(feet.y - _anchor_y)
		_anchor_y = lerpf(_anchor_y, feet.y, _blend(vertical_follow_rate * (1.0 + gap), delta))
	elif feet.y > _anchor_y + band_above:
		_anchor_y = lerpf(_anchor_y, feet.y - band_above, _blend(vertical_follow_rate, delta))
	elif feet.y < _anchor_y - band_below:
		_anchor_y = lerpf(_anchor_y, feet.y + band_below, _blend(vertical_follow_rate * 2.0, delta))
	# Never let the player leave the frame, however fast they move.
	_anchor_y = clampf(_anchor_y, feet.y - (air_band_above + 1.0) * reach, feet.y + (air_band_below + 1.0) * reach)
	_focus.y = _anchor_y + focus_height

	# The trailing focus point must never end up inside a wall the player just
	# ran past: the camera orbits it and casts from it.
	var head := feet + Vector3.UP * focus_height
	var hit := _ray(head, _focus)
	if not hit.is_empty():
		_focus = (hit.position as Vector3) + (head - _focus).normalized() * collision_radius


func _place(delta: float) -> void:
	var orbit := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var wanted := _focus + orbit * Vector3(0.0, 0.0, distance)
	var clear := maxf(_clear_distance(_focus, wanted), min_distance)
	if delta == 0.0:
		_distance = clear
	elif clear < _distance:
		# Something is in the way: slide in fast, but never snap.
		_distance = move_toward(_distance, clear, pull_in_speed * delta)
		_clear_time = 0.0
	else:
		# Wait for the view to stay clear before easing back out, so the camera
		# doesn't pump in and out while passing pillars.
		_clear_time += delta
		if _clear_time >= push_out_delay:
			_distance = lerpf(_distance, clear, _blend(push_out_rate, delta))

	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	var shake := _trauma * _trauma * max_shake_offset
	var jitter := Vector3(_noise.get_noise_1d(_time * 60.0), _noise.get_noise_1d(_time * 60.0 + 100.0), 0.0) * shake
	global_transform = Transform3D(orbit, _focus + orbit * (Vector3(0.0, 0.0, _distance) + jitter))


## How far the camera can back away from [param from] toward [param to] without hitting level geometry.
func _clear_distance(from: Vector3, to: Vector3) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _probe
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	query.collision_mask = collision_mask
	query.exclude = [target.get_rid()]
	var result := get_world_3d().direct_space_state.cast_motion(query)
	return distance * (result[0] if result.size() > 0 else 1.0)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [target.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


static func _yaw_toward(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


static func _blend(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
