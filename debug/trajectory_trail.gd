class_name TrajectoryTrail
extends MeshInstance3D
## Draws the player's recent path as a line, colored by movement state, to
## make jump arcs and distances visible while tuning. Toggle with F4.

## Seconds of path to keep.
@export var duration := 4.0
@export var player: Player

## Colors per state; anything else is drawn in [member default_color].
var state_colors: Dictionary[StringName, Color] = {
	&"Jump": Color(0.3, 1.0, 0.4),
	&"LedgeJump": Color(0.3, 1.0, 0.4),
	&"Backflip": Color(0.7, 0.4, 1.0),
	&"SideFlip": Color(1.0, 0.4, 0.9),
	&"LongJump": Color(1.0, 0.6, 0.1),
	&"Dive": Color(1.0, 0.25, 0.2),
	&"BellySlide": Color(0.8, 0.2, 0.2),
	&"Rollout": Color(1.0, 0.6, 0.7),
	&"GroundPound": Color(0.2, 0.3, 1.0),
	&"GroundPoundJump": Color(0.2, 0.9, 1.0),
	&"WallContact": Color(0.65, 0.45, 0.25),
	&"WallKick": Color(0.1, 0.8, 0.7),
	&"Spin": Color(0.6, 0.85, 1.0),
	&"Fall": Color(0.75, 0.75, 0.75),
	&"Bonk": Color(0.2, 0.2, 0.2),
}
var default_color := Color(1.0, 0.95, 0.2)

var _points := PackedVector3Array()
var _colors := PackedColorArray()
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material_override = material
	if player:
		player.teleported.connect(clear)


func _physics_process(_delta: float) -> void:
	if player == null or not visible:
		return
	_points.append(player.global_position + Vector3.UP * 0.05)
	_colors.append(state_colors.get(player.state_name, default_color))
	var excess := _points.size() - int(duration * Engine.physics_ticks_per_second)
	if excess > 0:
		_points = _points.slice(excess)
		_colors = _colors.slice(excess)


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in _points.size():
		_mesh.surface_set_color(_colors[i])
		_mesh.surface_add_vertex(_points[i])
	_mesh.surface_end()


func clear() -> void:
	_points.clear()
	_colors.clear()
