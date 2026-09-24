@tool
class_name PlayerModel
extends Node3D
## The player's look, built from primitives and animated entirely in code.
##
## An original mascot: a bean-shaped body, a beanie with a springy pom-pom,
## and floating hands and feet. Every pose is procedural (squash & stretch,
## leans, banking, flips, a run cycle) and driven by the parent [Player]'s
## state and signals. It never affects movement, so it can later be swapped
## for an imported, hand-animated model without touching gameplay code.

## Height of the point flips and leans rotate around.
const PIVOT_HEIGHT := 0.8
## Distance covered by one full run cycle (two steps).
const STRIDE_LENGTH := 2.4

const HAND_REST := Vector3(0.5, 0.78, -0.02)
const FOOT_REST := Vector3(0.17, 0.09, 0.0)

@export_group("Colors")
@export var body_color := Color("ff7a3d"):
	set(value):
		body_color = value
		_recolor()
@export var belly_color := Color("ffe0bf"):
	set(value):
		belly_color = value
		_recolor()
@export var hat_color := Color("2d3a8c"):
	set(value):
		hat_color = value
		_recolor()
@export var glove_color := Color("fafafa"):
	set(value):
		glove_color = value
		_recolor()
@export var shoe_color := Color("3d2b2b"):
	set(value):
		shoe_color = value
		_recolor()

var player: Player

var _pivot: Node3D
var _body: Node3D
var _hands: Array[MeshInstance3D] = []
var _feet: Array[MeshInstance3D] = []
var _eyes: Array[Node3D] = []
var _pupils: Array[Node3D] = []
var _pom: MeshInstance3D
var _pom_anchor: Node3D
var _materials: Dictionary[StringName, StandardMaterial3D] = {}

# Animation state.
var _time := 0.0
var _yaw := 0.0
var _turn_rate := 0.0
var _lean := 0.0
var _roll := 0.0
var _pivot_height := PIVOT_HEIGHT
var _crouch := 0.0
var _hand_positions: Array[Vector3] = [HAND_REST * Vector3(-1, 1, 1), HAND_REST]
var _foot_positions: Array[Vector3] = [FOOT_REST * Vector3(-1, 1, 1), FOOT_REST]
var _squash := 0.0
var _squash_velocity := 0.0
var _run_phase := 0.0
var _flips: Array[Flip] = []
var _blink_timer := 2.0
var _eye_closed := 0.0
var _vertical_offset := 0.0
var _last_floor_y := 0.0
var _was_on_floor := false
var _pom_position := Vector3.ZERO
var _pom_velocity := Vector3.ZERO


## A rotation played over time around one of the pivot's axes (x = pitch,
## y = yaw, z = roll). Full turns end where they started, so finishing one is seamless.
class Flip:
	var axis: int
	var angle: float
	var duration: float
	var tuck: bool
	var time := 0.0
	var settling := false
	var settle_from := 0.0
	var settle_to := 0.0

	func _init(flip_axis: int, flip_angle: float, flip_duration: float, tuck_limbs: bool) -> void:
		axis = flip_axis
		angle = flip_angle
		duration = maxf(flip_duration, 0.01)
		tuck = tuck_limbs

	## Current rotation contributed by this flip.
	func value() -> float:
		var t := clampf(time / duration, 0.0, 1.0)
		if settling:
			return lerpf(settle_from, settle_to, t)
		return angle * t * t * (3.0 - 2.0 * t)

	func finished() -> bool:
		return time >= duration

	## Stops early by easing to the nearest whole turn instead of snapping.
	func cancel() -> void:
		if settling:
			return
		var current := value()
		settling = true
		settle_from = current
		settle_to = roundf(current / TAU) * TAU
		time = 0.0
		duration = 0.12
		tuck = false


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	player = get_parent() as Player
	if player == null:
		push_warning("PlayerModel expects to be a child of a Player.")
		return
	player.jumped.connect(_on_jumped)
	player.landed.connect(_on_landed)
	player.state_changed.connect(_on_state_changed)
	player.spun.connect(_on_spun)
	player.ground_pound_impact.connect(_on_ground_pound_impact)
	player.teleported.connect(_snap)
	_snap.call_deferred()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	_time += delta
	_animate(delta)


# --- Pose logic ------------------------------------------------------------------

func _animate(delta: float) -> void:
	var s := player.settings
	var state := player.state_name
	var speed := player.horizontal_speed()
	var speed_ratio := clampf(speed / s.run_speed, 0.0, 1.5)
	var rising := player.velocity.y > 0.5

	# Facing, and how fast it is turning (for banking into turns).
	var target_yaw := atan2(-player.facing.x, -player.facing.z)
	var yaw_step := angle_difference(_yaw, target_yaw)
	_yaw = lerp_angle(_yaw, target_yaw, _blend(22.0, delta))
	_turn_rate = lerpf(_turn_rate, yaw_step / maxf(delta, 0.0001), _blend(10.0, delta))

	# Default pose: standing, arms relaxed.
	var lean := 0.0
	var roll := 0.0
	var pivot := PIVOT_HEIGHT
	var crouch := 0.0
	var hands: Array[Vector3] = [_mirror(HAND_REST), HAND_REST]
	var feet: Array[Vector3] = [_mirror(FOOT_REST), FOOT_REST]
	var squint := 0.0
	var limb_rate := 18.0

	match state:
		&"Idle":
			var breath := sin(_time * 2.4)
			crouch = 0.02 + breath * 0.015
			hands = [Vector3(-0.48, 0.74 + breath * 0.02, 0.02), Vector3(0.48, 0.74 + breath * 0.02, 0.02)]
		&"Run":
			_run_phase = fmod(_run_phase + delta * speed / STRIDE_LENGTH * TAU, TAU)
			var stride := lerpf(0.1, 0.36, minf(speed_ratio, 1.0))
			var lift := lerpf(0.06, 0.26, minf(speed_ratio, 1.0))
			for i in 2:
				var phase := _run_phase + PI * i
				var side := -1.0 if i == 0 else 1.0
				feet[i] = Vector3(side * 0.17, FOOT_REST.y + maxf(0.0, cos(phase)) * lift, -sin(phase) * stride)
				hands[i] = Vector3(side * 0.47, 0.8 + maxf(0.0, -sin(phase)) * 0.08 * speed_ratio, sin(phase) * stride * 0.9)
			pivot += absf(cos(_run_phase)) * 0.06 * minf(speed_ratio, 1.0)
			lean = -0.08 - 0.22 * minf(speed_ratio, 1.0)
			roll = clampf(-_turn_rate * speed * 0.012, -0.4, 0.4)
			limb_rate = 30.0
		&"Skid":
			lean = 0.4
			crouch = 0.12
			hands = [Vector3(-0.5, 1.05, 0.25), Vector3(0.5, 1.0, 0.3)]
			feet = [Vector3(-0.18, 0.09, -0.38), Vector3(0.17, 0.09, 0.15)]
		&"Crouch":
			crouch = 0.36
			var crawl := speed / maxf(s.crawl_speed, 0.1)
			_run_phase = fmod(_run_phase + delta * crawl * 6.0, TAU)
			for i in 2:
				var side := -1.0 if i == 0 else 1.0
				var step := sin(_run_phase + PI * i) * 0.12 * crawl
				hands[i] = Vector3(side * 0.42, 0.42, -0.12 + step)
				feet[i] = Vector3(side * 0.2, FOOT_REST.y, -step)
		&"CrouchSlide":
			crouch = 0.3
			lean = 0.25
			hands = [Vector3(-0.46, 0.55, 0.25), Vector3(0.46, 0.6, 0.2)]
			feet = [Vector3(-0.17, 0.12, -0.32), Vector3(0.17, 0.09, 0.08)]
		&"LongJump":
			lean = -1.05
			hands = [Vector3(-0.3, 1.35, -0.25), Vector3(0.3, 1.35, -0.25)]
			feet = [Vector3(-0.17, 0.12, 0.25), Vector3(0.17, 0.2, 0.3)]
		&"Dive", &"BellySlide":
			lean = -1.45
			if state == &"BellySlide":
				pivot = 0.42
			hands = [Vector3(-0.22, 1.55, -0.12), Vector3(0.22, 1.55, -0.12)]
			feet = [Vector3(-0.14, 0.02, 0.1), Vector3(0.14, 0.06, 0.12)]
			squint = 0.3
		&"GroundPound":
			if (player.state_machine.current as Node).get(&"dropping"):
				crouch = -0.15
				hands = [Vector3(-0.36, 1.45, 0.0), Vector3(0.36, 1.45, 0.0)]
				feet = [Vector3(-0.2, 0.32, -0.05), Vector3(0.2, 0.32, -0.05)]
				squint = 0.5
			limb_rate = 30.0
		&"GroundPoundLand":
			crouch = 0.28
			hands = [Vector3(-0.64, 0.42, 0.0), Vector3(0.64, 0.42, 0.0)]
			feet = [Vector3(-0.3, 0.09, 0.0), Vector3(0.3, 0.09, 0.0)]
			squint = 0.8
			limb_rate = 30.0
		&"WallSlide":
			lean = 0.1
			hands = [Vector3(-0.3, 1.18, -0.4), Vector3(0.3, 1.1, -0.4)]
			feet = [Vector3(-0.18, 0.18, -0.33), Vector3(0.18, 0.1, -0.3)]
			squint = 0.4
		&"LedgeHang":
			var sway := sin(_time * 3.0) * 0.04
			hands = [Vector3(-0.26, s.ledge_hang_depth + 0.03, -0.44), Vector3(0.26, s.ledge_hang_depth + 0.03, -0.44)]
			feet = [Vector3(-0.15, 0.1, -0.22 + sway), Vector3(0.15, 0.12, -0.22 - sway)]
			lean = 0.05
		&"LedgeClimb":
			var ledge: Dictionary = (player.state_machine.current as Node).get(&"ledge")
			var hand_height := clampf(float(ledge.get("top_y", 0.0)) - player.global_position.y + 0.03, 0.2, 1.6)
			hands = [Vector3(-0.26, hand_height, -0.4), Vector3(0.26, hand_height, -0.4)]
			feet = [Vector3(-0.15, 0.42, -0.3), Vector3(0.15, 0.1, 0.0)]
			lean = -0.3
			limb_rate = 30.0
		&"Spin":
			hands = [Vector3(-0.66, 0.98, 0.0), Vector3(0.66, 0.98, 0.0)]
			feet = [Vector3(-0.1, 0.04, 0.0), Vector3(0.1, 0.04, 0.0)]
		&"Bonk":
			if player.is_on_floor():
				var wobble := sin(_time * 9.0)
				crouch = 0.22
				lean = 0.28
				roll = wobble * 0.12
				hands = [Vector3(-0.42, 0.25, 0.28), Vector3(0.42, 0.25, 0.28)]
				feet = [Vector3(-0.2, 0.1, -0.3), Vector3(0.2, 0.1, -0.3)]
			else:
				lean = 0.6
				hands = [Vector3(-0.45, 1.35 + sin(_time * 25.0) * 0.08, 0.1), Vector3(0.45, 1.35 - sin(_time * 25.0) * 0.08, 0.1)]
				feet = [Vector3(-0.17, 0.2, -0.3), Vector3(0.17, 0.25, -0.25)]
			squint = 1.0
		&"SteepSlide":
			lean = 0.45
			crouch = 0.2
			hands = [Vector3(-0.42, 0.45, 0.3), Vector3(0.42, 0.45, 0.3)]
			feet = [Vector3(-0.18, 0.1, -0.35), Vector3(0.18, 0.1, -0.35)]
			squint = 0.3
		_:
			# Generic airborne pose: arms up on the way up, flailing out on the way down.
			if rising:
				hands = [Vector3(-0.42, 1.25, -0.05), Vector3(0.42, 1.25, -0.05)]
				feet = [Vector3(-0.15, 0.24, 0.05), Vector3(0.15, 0.2, 0.08)]
			else:
				var flail := sin(_time * 16.0) * 0.06
				hands = [Vector3(-0.56, 1.05 + flail, 0.02), Vector3(0.56, 1.05 - flail, 0.02)]
				feet = [Vector3(-0.17, 0.03, 0.06), Vector3(0.17, 0.06, 0.02)]
			if state == &"GroundPoundJump":
				hands = [Vector3(-0.2, 1.65, 0.0), Vector3(0.2, 1.65, 0.0)]
				feet = [Vector3(-0.08, 0.0, 0.0), Vector3(0.08, 0.0, 0.0)]
			lean = -0.12 * minf(speed_ratio, 1.0)

	# Flips tuck the limbs into a ball.
	var flip_angles := _update_flips(delta)
	for flip in _flips:
		if flip.tuck:
			hands = [Vector3(-0.28, 0.55, -0.28), Vector3(0.28, 0.55, -0.28)]
			feet = [Vector3(-0.16, 0.36, -0.12), Vector3(0.16, 0.36, -0.12)]
			crouch = maxf(crouch, 0.12)
			squint = maxf(squint, 0.6)
			break

	# Blend toward the pose.
	_lean = lerpf(_lean, lean, _blend(14.0, delta))
	_roll = lerpf(_roll, roll, _blend(10.0, delta))
	_pivot_height = lerpf(_pivot_height, pivot, _blend(16.0, delta))
	_crouch = lerpf(_crouch, crouch, _blend(18.0, delta))
	for i in 2:
		_hand_positions[i] = _hand_positions[i].lerp(hands[i], _blend(limb_rate, delta))
		_foot_positions[i] = _foot_positions[i].lerp(feet[i], _blend(limb_rate, delta))

	_update_squash(delta)
	_update_step_smoothing(delta)
	_update_eyes(delta, squint)
	_apply(flip_angles)
	_update_pom(delta)


func _apply(flip_angles: Vector3) -> void:
	basis = Basis(Vector3.UP, _yaw)
	position = Vector3(0.0, _vertical_offset, 0.0)
	_pivot.position = Vector3(0.0, _pivot_height, 0.0)
	_pivot.basis = Basis.from_euler(Vector3(_lean + flip_angles.x, flip_angles.y, _roll + flip_angles.z))
	var stretch := clampf((1.0 - _crouch) * (1.0 + _squash), 0.4, 1.6)
	var widen := 1.0 / sqrt(stretch)
	_body.scale = Vector3(widen, stretch, widen)
	_body.position = Vector3(0.0, -PIVOT_HEIGHT, 0.0)
	# Limbs are placed in feet space; follow the body's squash so they stay attached.
	for i in 2:
		var hand := _hand_positions[i]
		_hands[i].position = Vector3(hand.x * widen, hand.y * stretch, hand.z) - Vector3(0.0, PIVOT_HEIGHT, 0.0)
		_feet[i].position = _foot_positions[i] - Vector3(0.0, PIVOT_HEIGHT, 0.0)


func _update_squash(delta: float) -> void:
	# A damped spring: impulses from jumps and landings wobble back to rest.
	var accel := -220.0 * _squash - 14.0 * _squash_velocity
	_squash_velocity += accel * delta
	_squash = clampf(_squash + _squash_velocity * delta, -0.45, 0.45)


## Smooths out the pop of stepping up stairs (or snapping down them).
func _update_step_smoothing(delta: float) -> void:
	var on_floor := player.is_on_floor()
	var y := player.global_position.y
	if on_floor and _was_on_floor:
		var step := y - _last_floor_y
		if absf(step) > 0.02 and absf(step) < 0.6:
			_vertical_offset -= step
	_vertical_offset = lerpf(_vertical_offset, 0.0, _blend(16.0, delta))
	_last_floor_y = y
	_was_on_floor = on_floor


func _update_eyes(delta: float, squint: float) -> void:
	_blink_timer -= delta
	var blink := 0.0
	if _blink_timer < 0.0:
		blink = 1.0
		if _blink_timer < -0.12:
			_blink_timer = randf_range(1.8, 4.5)
	_eye_closed = lerpf(_eye_closed, maxf(squint, blink), _blend(30.0, delta))
	# Glance toward where we're heading.
	var local_velocity := (basis.inverse() * player.velocity).limit_length(10.0) / 10.0
	for i in 2:
		_eyes[i].scale = Vector3(1.0, lerpf(1.0, 0.12, _eye_closed), 1.0)
		_pupils[i].position = Vector3(local_velocity.x * 0.025, -local_velocity.y * 0.012, 0.0)


func _update_pom(delta: float) -> void:
	var anchor := _pom_anchor.global_position
	var accel := (anchor - _pom_position) * 380.0 - _pom_velocity * 12.0 + Vector3.DOWN * 5.0
	_pom_velocity += accel * delta
	_pom_position += _pom_velocity * delta
	var offset := _pom_position - anchor
	if offset.length() > 0.16:
		_pom_position = anchor + offset.normalized() * 0.16
	_pom.global_position = _pom_position


func _update_flips(delta: float) -> Vector3:
	var angles := Vector3.ZERO
	for i in range(_flips.size() - 1, -1, -1):
		var flip := _flips[i]
		flip.time += delta
		if flip.finished():
			_flips.remove_at(i)
		else:
			angles[flip.axis] += flip.value()
	return angles


func _start_flip(axis: int, angle: float, duration: float, tuck := true) -> void:
	_cancel_flips()
	_flips.append(Flip.new(axis, angle, duration, tuck))


func _cancel_flips() -> void:
	for flip in _flips:
		flip.cancel()


# --- Signal reactions --------------------------------------------------------------

func _on_jumped(kind: StringName) -> void:
	_squash_velocity += 3.2
	match kind:
		&"double":
			_start_flip(Vector3.AXIS_Y, TAU, 0.45, false)
		&"triple":
			_start_flip(Vector3.AXIS_X, -TAU, 0.62)
		&"backflip":
			_start_flip(Vector3.AXIS_X, TAU, 0.8)
		&"side_flip":
			_start_flip(Vector3.AXIS_Z, TAU, 0.65)
		&"rollout":
			_start_flip(Vector3.AXIS_X, -TAU, 0.38)
		&"ground_pound_jump":
			_squash_velocity += 2.0
			_start_flip(Vector3.AXIS_Y, TAU * 2.0, 0.7, false)
		&"wall_kick":
			_start_flip(Vector3.AXIS_Y, TAU, 0.35, false)
		&"long_jump":
			_squash_velocity -= 1.5


func _on_state_changed(_previous: StringName, current: StringName) -> void:
	match current:
		&"GroundPound":
			_start_flip(Vector3.AXIS_X, -TAU, player.settings.ground_pound_hang_time * 0.9)
		&"Dive", &"WallSlide", &"LedgeHang", &"LedgeClimb", &"Bonk", &"BellySlide", &"SteepSlide":
			_cancel_flips()


func _on_landed(impact_speed: float) -> void:
	_squash_velocity -= clampf(impact_speed * 0.22, 0.5, 6.0)
	_cancel_flips()


func _on_ground_pound_impact() -> void:
	_squash_velocity -= 4.0


func _on_spun(in_air: bool) -> void:
	var duration := player.settings.spin_duration if in_air else 0.35
	_start_flip(Vector3.AXIS_Y, TAU * (2.0 if in_air else 1.0), duration, false)


## Jumps straight to the current pose (after teleporting).
func _snap() -> void:
	if player == null:
		return
	_yaw = atan2(-player.facing.x, -player.facing.z)
	_flips.clear()
	_squash = 0.0
	_squash_velocity = 0.0
	_vertical_offset = 0.0
	_apply(Vector3.ZERO)
	_pom_position = _pom_anchor.global_position
	_pom_velocity = Vector3.ZERO
	_pom.global_position = _pom_position
	_pom.reset_physics_interpolation()


# --- Construction -----------------------------------------------------------------

func _build() -> void:
	for child in get_children():
		child.queue_free()
	_hands.clear()
	_feet.clear()
	_eyes.clear()
	_pupils.clear()
	_materials = {
		&"body": _toon(body_color),
		&"belly": _toon(belly_color),
		&"hat": _toon(hat_color),
		&"glove": _toon(glove_color),
		&"shoe": _toon(shoe_color),
		&"nose": _toon(body_color.darkened(0.15)),
		&"eye": _toon(Color.WHITE, false),
		&"pupil": _toon(Color("1b1b2a"), false),
	}

	_pivot = _node("Pivot", self, Vector3(0, PIVOT_HEIGHT, 0))
	_body = _node("Body", _pivot, Vector3(0, -PIVOT_HEIGHT, 0))

	var torso := CapsuleMesh.new()
	torso.radius = 0.36
	torso.height = 1.12
	_part("Torso", torso, &"body", _body, Vector3(0, 0.84, 0))
	var belly := SphereMesh.new()
	belly.radius = 0.25
	belly.height = 0.5
	_part("Belly", belly, &"belly", _body, Vector3(0, 0.66, -0.2), Vector3(1.0, 1.15, 0.6))

	# Hat: a beanie with a folded brim and a pom-pom on a spring.
	var cap := SphereMesh.new()
	cap.radius = 0.375
	cap.height = 0.375
	cap.is_hemisphere = true
	_part("Hat", cap, &"hat", _body, Vector3(0, 1.2, 0), Vector3(1.0, 0.85, 1.0))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.385
	brim.bottom_radius = 0.38
	brim.height = 0.1
	_part("Brim", brim, &"hat", _body, Vector3(0, 1.21, 0))
	_pom_anchor = _node("PomAnchor", _body, Vector3(0, 1.5, 0.02))
	var pom_mesh := SphereMesh.new()
	pom_mesh.radius = 0.1
	pom_mesh.height = 0.2
	_pom = _part("PomPom", pom_mesh, &"glove", self, Vector3(0, 1.56, 0))
	_pom.top_level = true

	# Eyes: tall ovals with pupils and a glint; scaled vertically to blink.
	for side in [-1.0, 1.0]:
		var eye := _node("Eye", _body, Vector3(0.125 * side, 1.02, -0.335))
		eye.rotation.y = -0.3 * side
		var sclera := SphereMesh.new()
		sclera.radius = 0.09
		sclera.height = 0.18
		_part("Sclera", sclera, &"eye", eye, Vector3.ZERO, Vector3(1.0, 1.4, 0.55))
		var pupil_root := _node("Pupil", eye, Vector3.ZERO)
		var pupil := SphereMesh.new()
		pupil.radius = 0.046
		pupil.height = 0.092
		_part("Iris", pupil, &"pupil", pupil_root, Vector3(0.0, 0.0, -0.036), Vector3(1.0, 1.3, 0.5))
		var glint := SphereMesh.new()
		glint.radius = 0.014
		glint.height = 0.028
		_part("Glint", glint, &"eye", pupil_root, Vector3(0.016, 0.024, -0.058))
		_eyes.append(eye)
		_pupils.append(pupil_root)
	var nose := SphereMesh.new()
	nose.radius = 0.055
	nose.height = 0.11
	_part("Nose", nose, &"nose", _body, Vector3(0.0, 0.9, -0.37), Vector3(1.1, 0.9, 1.0))

	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.11
	hand_mesh.height = 0.22
	var foot_mesh := SphereMesh.new()
	foot_mesh.radius = 0.12
	foot_mesh.height = 0.24
	for i in 2:
		_hands.append(_part("Hand", hand_mesh, &"glove", _pivot, Vector3.ZERO))
		_feet.append(_part("Foot", foot_mesh, &"shoe", _pivot, Vector3.ZERO, Vector3(1.0, 0.72, 1.45)))
	_apply(Vector3.ZERO)


func _node(node_name: String, parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = at
	parent.add_child(node)
	return node


func _part(node_name: String, mesh: Mesh, material: StringName, parent: Node3D, at: Vector3, part_scale := Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	part.mesh = mesh
	part.material_override = _materials[material]
	part.position = at
	part.scale = part_scale
	parent.add_child(part)
	return part


func _toon(color: Color, outlined := true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	material.rim_enabled = true
	material.rim = 0.3
	material.rim_tint = 0.6
	if outlined:
		var outline := ShaderMaterial.new()
		outline.shader = preload("res://player/model/outline.gdshader")
		material.next_pass = outline
	return material


func _recolor() -> void:
	if _materials.is_empty():
		return
	_materials[&"body"].albedo_color = body_color
	_materials[&"nose"].albedo_color = body_color.darkened(0.15)
	_materials[&"belly"].albedo_color = belly_color
	_materials[&"hat"].albedo_color = hat_color
	_materials[&"glove"].albedo_color = glove_color
	_materials[&"shoe"].albedo_color = shoe_color


static func _mirror(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## Frame-rate independent smoothing factor for lerping toward a target.
static func _blend(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
