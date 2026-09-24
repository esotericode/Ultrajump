class_name PlayerEffects
extends Node3D
## Dust, shockwaves and sparkles that react to the player's moves.
##
## Purely cosmetic: listens to the parent [Player]'s signals and state.
## One-shot bursts are spawned into the level so they stay put while the
## player moves on; trails and slide dust are continuous emitters that follow.

const SLIDE_STATES: Array[StringName] = [&"Skid", &"CrouchSlide", &"BellySlide", &"SteepSlide"]
const TRAIL_STATES: Array[StringName] = [&"Dive", &"LongJump", &"GroundPound", &"Spin", &"GroundPoundJump"]

var player: Player

var _puff_mesh: SphereMesh
var _dust_material: StandardMaterial3D
var _sparkle_material: StandardMaterial3D
var _fade_out: Gradient
var _shrink: Curve
var _slide_dust: CPUParticles3D
var _wall_dust: CPUParticles3D
var _trail: CPUParticles3D


func _ready() -> void:
	player = get_parent() as Player
	if player == null:
		push_warning("PlayerEffects expects to be a child of a Player.")
		return
	_puff_mesh = SphereMesh.new()
	_puff_mesh.radius = 0.5
	_puff_mesh.height = 1.0
	_puff_mesh.radial_segments = 8
	_puff_mesh.rings = 4
	_dust_material = _particle_material(false)
	_sparkle_material = _particle_material(true)
	_fade_out = Gradient.new()
	_fade_out.set_color(0, Color(1, 1, 1, 0.9))
	_fade_out.set_color(1, Color(1, 1, 1, 0.0))
	_shrink = Curve.new()
	_shrink.add_point(Vector2(0.0, 1.0))
	_shrink.add_point(Vector2(1.0, 0.2))

	_slide_dust = _emitter(24, 0.45, 0.28, Color(0.92, 0.9, 0.86, 0.8))
	_slide_dust.position = Vector3(0, 0.1, 0)
	_wall_dust = _emitter(16, 0.35, 0.18, Color(0.92, 0.9, 0.86, 0.8))
	_trail = _emitter(40, 0.35, 0.12, Color(1.0, 0.95, 0.75, 0.9))
	_trail.material_override = _sparkle_material
	_trail.position = Vector3(0, 0.8, 0)
	_trail.emission_sphere_radius = 0.35

	player.landed.connect(_on_landed)
	player.jumped.connect(_on_jumped)
	player.ground_pound_impact.connect(_on_ground_pound_impact)
	player.wall_kicked.connect(_on_wall_kicked)
	player.bonked.connect(_on_bonked)
	player.ledge_grabbed.connect(_on_ledge_grabbed)
	player.spun.connect(_on_spun)
	player.teleported.connect(_on_teleported)


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var state := player.state_name
	var speed := player.horizontal_speed()
	_slide_dust.emitting = state in SLIDE_STATES and speed > 2.0
	_trail.emitting = state in TRAIL_STATES or (state == &"Run" and speed > player.settings.run_speed * 1.2)
	var wall_sliding := state == &"WallSlide" and player.velocity.y < -1.0
	_wall_dust.emitting = wall_sliding
	if wall_sliding:
		_wall_dust.global_position = player.global_position + player.facing * (player.radius + 0.05) + Vector3.UP * 1.1


# --- Reactions -------------------------------------------------------------------

func _on_landed(impact_speed: float) -> void:
	if impact_speed > 18.0:
		_rumble(0.3, 0.1, 0.12)
	if impact_speed > 5.0:
		var amount := clampi(int(impact_speed * 0.8), 6, 20)
		_ring_burst(player.global_position + Vector3.UP * 0.1, amount, clampf(impact_speed * 0.25, 2.0, 6.0), 0.3)


func _on_jumped(kind: StringName) -> void:
	var feet := player.global_position + Vector3.UP * 0.1
	if kind in [&"single", &"double", &"triple", &"backflip", &"side_flip", &"long_jump", &"ground_pound_jump"]:
		_ring_burst(feet, 7, 2.5, 0.22)
	if kind in [&"triple", &"backflip", &"side_flip", &"ground_pound_jump"]:
		_sparkle_burst(player.global_position + Vector3.UP * 0.8, 10, 3.5)


func _on_ground_pound_impact() -> void:
	var feet := player.global_position + Vector3.UP * 0.08
	_ring_burst(feet, 22, 7.0, 0.4)
	_shockwave(feet)
	_rumble(0.6, 0.8, 0.22)


func _on_wall_kicked(wall_normal: Vector3) -> void:
	_ring_burst(player.global_position - wall_normal * player.radius + Vector3.UP * 0.4, 8, 2.5, 0.25, wall_normal)


func _on_bonked(_wall_normal: Vector3) -> void:
	_sparkle_burst(player.global_position + Vector3.UP * 1.4, 8, 2.0, Color(1.0, 0.85, 0.2))
	_rumble(0.5, 0.5, 0.18)


func _on_ledge_grabbed() -> void:
	_ring_burst(player.global_position + player.facing * player.radius + Vector3.UP * player.settings.ledge_hang_depth, 5, 1.5, 0.15)


func _on_spun(in_air: bool) -> void:
	if in_air:
		_sparkle_burst(player.global_position + Vector3.UP * 0.8, 12, 4.0, Color(0.75, 0.9, 1.0))


func _on_teleported() -> void:
	for emitter in [_slide_dust, _wall_dust, _trail]:
		(emitter as CPUParticles3D).restart()
		(emitter as CPUParticles3D).emitting = false


# --- Particle helpers ----------------------------------------------------------------

## A flat ring of dust puffs spreading out from [param at] (perpendicular to [param axis]).
func _ring_burst(at: Vector3, amount: int, speed: float, size: float, axis := Vector3.UP) -> void:
	var burst := _one_shot(at, amount, 0.5, _dust_material)
	# Particles spread in the emitter's local XZ plane; turn local Y to face the axis.
	burst.direction = Vector3.RIGHT
	burst.spread = 180.0
	burst.flatness = 1.0
	var across := axis.cross(Vector3.UP)
	if across.length_squared() > 0.001:
		across = across.normalized()
		burst.basis = Basis(across, axis, across.cross(axis))
	burst.initial_velocity_min = speed * 0.6
	burst.initial_velocity_max = speed
	burst.damping_min = speed * 1.5
	burst.damping_max = speed * 2.0
	burst.gravity = Vector3(0, 1.5, 0)
	burst.scale_amount_min = size * 0.7
	burst.scale_amount_max = size * 1.2
	burst.color = Color(0.93, 0.9, 0.85, 0.85)


## Bright specks flying out in all directions.
func _sparkle_burst(at: Vector3, amount: int, speed: float, color := Color(1.0, 0.95, 0.7)) -> void:
	var burst := _one_shot(at, amount, 0.45, _sparkle_material)
	burst.direction = Vector3.UP
	burst.spread = 180.0
	burst.initial_velocity_min = speed * 0.5
	burst.initial_velocity_max = speed
	burst.damping_min = speed
	burst.damping_max = speed * 1.5
	burst.gravity = Vector3.ZERO
	burst.scale_amount_min = 0.06
	burst.scale_amount_max = 0.12
	burst.color = color


## An expanding ring on the ground.
func _shockwave(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 32
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 1, 1, 0.85)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_level().add_child(ring)
	ring.global_position = at
	ring.scale = Vector3(0.4, 0.3, 0.4)
	var tween := ring.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(ring, "scale", Vector3(4.0, 0.3, 4.0), 0.4)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(ring.queue_free)


func _one_shot(at: Vector3, amount: int, lifetime: float, material: Material) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.mesh = _puff_mesh
	particles.material_override = material
	particles.scale_amount_curve = _shrink
	particles.color_ramp = _fade_out
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_level().add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


func _emitter(amount: int, lifetime: float, size: float, color: Color) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.emitting = false
	particles.mesh = _puff_mesh
	particles.material_override = _dust_material
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.2
	particles.direction = Vector3.UP
	particles.spread = 60.0
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.5
	particles.gravity = Vector3(0, 0.5, 0)
	particles.scale_amount_min = size * 0.7
	particles.scale_amount_max = size * 1.2
	particles.scale_amount_curve = _shrink
	particles.color = color
	particles.color_ramp = _fade_out
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles


func _particle_material(glowing: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	if glowing:
		material.emission_enabled = true
		material.emission = Color(1.0, 0.95, 0.8)
		material.emission_energy_multiplier = 0.6
	return material


## Gamepad vibration on every connected controller.
func _rumble(weak: float, strong: float, duration: float) -> void:
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, duration)


## Where one-shot effects are spawned: the player's parent (the level), so they stay in place.
func _level() -> Node:
	return player.get_parent() if player.get_parent() else self
