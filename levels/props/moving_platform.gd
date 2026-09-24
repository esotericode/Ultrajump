@tool
class_name MovingPlatform
extends AnimatableBody3D
## A platform that shuttles back and forth along [member travel] (easing in
## and out, pausing at each end) and/or spins around its vertical axis.
## Characters standing on it are carried along.

@export var shape := Block.Shape.BOX:
	set(value):
		shape = value
		_rebuild()
@export var size := Vector3(3.0, 0.5, 3.0):
	set(value):
		size = value.max(Vector3.ONE * 0.05)
		_rebuild()
@export var color := Color(0.95, 0.75, 0.3):
	set(value):
		color = value
		_rebuild()
## Offset from the starting position to the far end of the path.
@export var travel := Vector3(0.0, 0.0, 8.0)
## Seconds to travel one way.
@export var travel_time := 3.0
## Seconds to wait at each end.
@export var pause_time := 0.75
@export var spin_degrees_per_second := 0.0

var _start := Vector3.ZERO
var _time := 0.0
var _visual: MeshInstance3D
var _collider: CollisionShape3D


func _ready() -> void:
	_start = position
	_rebuild()


## Jumps back to the start of the cycle.
func restart() -> void:
	_time = 0.0
	position = _start


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if travel != Vector3.ZERO:
		position = _start + travel * _progress()
	if spin_degrees_per_second != 0.0:
		rotate_y(deg_to_rad(spin_degrees_per_second) * delta)


## 0 at the start, 1 at the far end.
func _progress() -> float:
	var leg := travel_time + pause_time
	var t := fmod(_time, leg * 2.0)
	var outbound := t < leg
	var moving := clampf(((t if outbound else t - leg) - pause_time) / maxf(travel_time, 0.01), 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, moving)
	return eased if outbound else 1.0 - eased


func _rebuild() -> void:
	if not is_node_ready():
		return
	if _visual == null:
		_visual = MeshInstance3D.new()
		add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
		_collider = CollisionShape3D.new()
		add_child(_collider, false, Node.INTERNAL_MODE_FRONT)
	var geometry := Block.build_geometry(shape, size)
	_visual.mesh = geometry[0]
	_collider.shape = geometry[1]
	_visual.material_override = Block.grid_material(color)
