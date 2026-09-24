class_name PropFx
extends RefCounted
## One-shot particle effects for level props (sparkles, debris). Each effect
## is spawned into the current scene and frees itself when done.

static var _speck: SphereMesh
static var _chunk: BoxMesh
static var _glow: StandardMaterial3D
static var _solid: StandardMaterial3D
static var _fade: Gradient


## Bright specks bursting out of [param at].
static func sparkle(context: Node, at: Vector3, color: Color, amount := 12, speed := 4.0) -> void:
	_launch(context, _sparkle(color, amount, speed), at)


## Chunks of [param color] flying apart and tumbling down (a crate breaking).
static func debris(context: Node, at: Vector3, color: Color, size: float) -> void:
	_launch(context, _debris(color, size), at)


## Fires one of each effect under [param stage] (in view of the camera, behind
## a loading screen), so their shaders are compiled before play instead of
## the first time a crate breaks or a coin is collected.
static func warm_up(stage: Node3D) -> void:
	for particles in [_sparkle(Color.WHITE, 4, 1.0), _debris(Color.WHITE, 0.5)]:
		stage.add_child(particles)
		particles.restart()


static func _sparkle(color: Color, amount: int, speed: float) -> CPUParticles3D:
	var particles := _particles(amount, 0.5)
	if _speck == null:
		_speck = SphereMesh.new()
		_speck.radius = 0.5
		_speck.height = 1.0
		_speck.radial_segments = 6
		_speck.rings = 3
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow.vertex_color_use_as_albedo = true
		_glow.vertex_color_is_srgb = true
	particles.mesh = _speck
	particles.material_override = _glow
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.damping_min = speed
	particles.damping_max = speed * 1.5
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = 0.06
	particles.scale_amount_max = 0.14
	particles.color = color
	return particles


static func _debris(color: Color, size: float) -> CPUParticles3D:
	var particles := _particles(14, 0.9)
	if _chunk == null:
		_chunk = BoxMesh.new()
		_chunk.size = Vector3.ONE
		_solid = StandardMaterial3D.new()
		_solid.vertex_color_use_as_albedo = true
		_solid.vertex_color_is_srgb = true
		_solid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.mesh = _chunk
	particles.material_override = _solid
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3.ONE * size * 0.35
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 6.5
	particles.gravity = Vector3(0, -20, 0)
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = size * 0.15
	particles.scale_amount_max = size * 0.3
	particles.color = color
	particles.particle_flag_rotate_y = true
	return particles


## A one-shot burst, not yet in the scene: configure it, then [method _launch] it.
static func _particles(amount: int, lifetime: float) -> CPUParticles3D:
	if _fade == null:
		_fade = Gradient.new()
		_fade.set_color(0, Color(1, 1, 1, 1))
		_fade.set_color(1, Color(1, 1, 1, 0))
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.color_ramp = _fade
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


## Adds a configured burst to the scene at [param at] and fires it. Uses
## restart(): a one-shot burst with explosiveness 1 that is started by setting
## `emitting` shows nothing (Godot 4.7).
static func _launch(context: Node, particles: CPUParticles3D, at: Vector3) -> void:
	if not context.is_inside_tree():
		particles.free()
		return
	var tree := context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene else tree.root
	parent.add_child(particles)
	particles.global_position = at
	particles.finished.connect(particles.queue_free)
	particles.restart()
