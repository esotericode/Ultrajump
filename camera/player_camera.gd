class_name PlayerCamera
extends Node3D
## Third-person orbit camera tuned for 3D platforming.
##
## - Orbit with the mouse or right stick; tap recenter to swing behind the player.
## - Follows tightly on the ground, but only lazily in the air: small hops
##   don't bob the view, so jump arcs read clearly. It catches up on landing,
##   or as soon as the player climbs or falls out of a comfortable band.
## - Looks ahead along the direction of travel, widens the FOV at high speed,
##   drifts behind the player while running (after a pause in manual control),
##   shakes on big impacts, and pulls in instead of clipping through walls.
##
## This node is the camera's pose; the Camera3D child just renders it. It
## updates every rendered frame from the player's interpolated transform.

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
@export var horizontal_follow_rate := 12.0
@export var vertical_follow_rate := 5.0
## While airborne, the view only rises once the player is this far above where they took off...
@export var air_band_above := 2.2
## ...and follows right away once they drop this far below it.
@export var air_band_below := 0.4
## Seconds of travel the camera looks ahead.
@export var look_ahead_time := 0.2
@export var max_look_ahead := 2.0

@export_group("Auto Align")
## Drift behind the player while running, when the camera hasn't been touched for a moment.
@export var auto_align := true
@export var auto_align_delay := 1.2
@export var auto_align_strength := 0.9

@export_group("Feel")
@export var base_fov := 70.0
@export var speed_fov_bonus := 10.0
## Horizontal speeds above this widen the FOV.
@export var fov_speed_threshold := 11.0
@export var max_shake_offset := 0.3
@export var collision_radius := 0.25
@export_flags_3d_physics var collision_mask := 1

var yaw := 0.0
var pitch := 0.0

var _focus := Vector3.ZERO
var _anchor_y := 0.0
var _look_ahead := Vector3.ZERO
var _distance := 6.5
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
		target.ground_pound_impact.connect(add_trauma.bind(0.45))
		target.bonked.connect(func(_normal: Vector3) -> void: add_trauma(0.35))
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

	_follow(target.get_global_transform_interpolated().origin, delta)
	_place(delta)
	var speed_boost := clampf((target.horizontal_speed() - fov_speed_threshold) / 8.0, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, base_fov + speed_fov_bonus * speed_boost, _blend(3.0, delta))


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
	_look_ahead = Vector3.ZERO
	_distance = distance
	_recentering = false
	_place(0.0)


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
	var travel := target.horizontal_velocity()
	var ahead := (travel * look_ahead_time).limit_length(max_look_ahead)
	_look_ahead = _look_ahead.lerp(ahead, _blend(3.0, delta))
	var goal := feet + _look_ahead
	var follow := _blend(horizontal_follow_rate, delta)
	_focus.x = lerpf(_focus.x, goal.x, follow)
	_focus.z = lerpf(_focus.z, goal.z, follow)

	var settled := target.is_on_floor() or target.state_name in [&"WallSlide", &"LedgeHang", &"LedgeClimb"]
	if settled:
		_anchor_y = lerpf(_anchor_y, feet.y, _blend(vertical_follow_rate, delta))
	elif feet.y > _anchor_y + air_band_above:
		_anchor_y = lerpf(_anchor_y, feet.y - air_band_above, _blend(vertical_follow_rate, delta))
	elif feet.y < _anchor_y - air_band_below:
		_anchor_y = lerpf(_anchor_y, feet.y + air_band_below, _blend(vertical_follow_rate * 2.0, delta))
	# Never let the player leave the frame, however fast they move.
	_anchor_y = clampf(_anchor_y, feet.y - air_band_above - 1.5, feet.y + air_band_below + 1.0)
	_focus.y = _anchor_y + focus_height


func _place(delta: float) -> void:
	var orbit := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var wanted := _focus + orbit * Vector3(0.0, 0.0, distance)
	var clear := _clear_distance(_focus, wanted)
	# Pull in instantly so walls never block the view; ease back out.
	_distance = clear if clear < _distance or delta == 0.0 else lerpf(_distance, clear, _blend(4.0, delta))

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


static func _yaw_toward(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


static func _blend(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
