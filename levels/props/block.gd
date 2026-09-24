@tool
class_name Block
extends StaticBody3D
## A grey-box building block: a box, ramp or cylinder with matching collision
## and a world-space grid material.
##
## Drop one in, set [member shape], [member size] and [member color], and move
## it around; the mesh and collision update live in the editor. Ramps rise
## toward the block's local -Z (forward) axis.

enum Shape { BOX, RAMP, CYLINDER }

const GRID_SHADER := preload("res://levels/props/grid.gdshader")

@export var shape := Shape.BOX:
	set(value):
		shape = value
		_rebuild()
## Bounding size. For cylinders, x is the diameter and y the height.
@export var size := Vector3(4.0, 1.0, 4.0):
	set(value):
		size = value.max(Vector3.ONE * 0.05)
		_rebuild()
@export var color := Color(0.72, 0.74, 0.8):
	set(value):
		color = value
		_rebuild()

## One shared material per color, so identical blocks batch nicely.
static var _materials: Dictionary[Color, ShaderMaterial] = {}

var _visual: MeshInstance3D
var _collider: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	if _visual == null:
		# Internal children: generated, so they never show up in (or get saved to) the scene.
		_visual = MeshInstance3D.new()
		add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
		_collider = CollisionShape3D.new()
		add_child(_collider, false, Node.INTERNAL_MODE_FRONT)
	var geometry := build_geometry(shape, size)
	_visual.mesh = geometry[0]
	_collider.shape = geometry[1]
	_visual.material_override = grid_material(color)


## Returns [mesh, collision shape] for a block of [param block_shape] and [param block_size].
static func build_geometry(block_shape: Shape, block_size: Vector3) -> Array:
	match block_shape:
		Shape.RAMP:
			return _ramp(block_size)
		Shape.CYLINDER:
			var cylinder_mesh := CylinderMesh.new()
			cylinder_mesh.top_radius = block_size.x * 0.5
			cylinder_mesh.bottom_radius = block_size.x * 0.5
			cylinder_mesh.height = block_size.y
			cylinder_mesh.radial_segments = 48
			var cylinder := CylinderShape3D.new()
			cylinder.radius = block_size.x * 0.5
			cylinder.height = block_size.y
			return [cylinder_mesh, cylinder]
	var box_mesh := BoxMesh.new()
	box_mesh.size = block_size
	var box := BoxShape3D.new()
	box.size = block_size
	return [box_mesh, box]


static func grid_material(tint: Color) -> ShaderMaterial:
	if not _materials.has(tint):
		var material := ShaderMaterial.new()
		material.shader = GRID_SHADER
		material.set_shader_parameter(&"color", tint)
		_materials[tint] = material
	return _materials[tint]


## A wedge filling the block's bounds: flat bottom, vertical back at -Z, slope down to +Z.
static func _ramp(block_size: Vector3) -> Array:
	var h := block_size * 0.5
	var bottom_back_left := Vector3(-h.x, -h.y, -h.z)
	var bottom_back_right := Vector3(h.x, -h.y, -h.z)
	var bottom_front_right := Vector3(h.x, -h.y, h.z)
	var bottom_front_left := Vector3(-h.x, -h.y, h.z)
	var top_left := Vector3(-h.x, h.y, -h.z)
	var top_right := Vector3(h.x, h.y, -h.z)
	var slope_normal := Vector3(0.0, block_size.z, block_size.y).normalized()

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(tool, [bottom_back_left, bottom_back_right, bottom_front_right, bottom_front_left], Vector3.DOWN)
	_quad(tool, [bottom_back_left, bottom_back_right, top_right, top_left], Vector3.FORWARD)
	_quad(tool, [top_left, top_right, bottom_front_right, bottom_front_left], slope_normal)
	_triangle(tool, bottom_back_left, top_left, bottom_front_left, Vector3.LEFT)
	_triangle(tool, bottom_back_right, bottom_front_right, top_right, Vector3.RIGHT)
	var mesh := tool.commit()

	var collision := ConvexPolygonShape3D.new()
	collision.points = PackedVector3Array([bottom_back_left, bottom_back_right, bottom_front_right, bottom_front_left, top_left, top_right])
	return [mesh, collision]


static func _quad(tool: SurfaceTool, corners: Array, normal: Vector3) -> void:
	_triangle(tool, corners[0], corners[1], corners[2], normal)
	_triangle(tool, corners[0], corners[2], corners[3], normal)


## Adds a triangle facing [param normal] (Godot treats clockwise triangles as front faces).
static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	for vertex in [a, b, c]:
		tool.set_normal(normal)
		tool.add_vertex(vertex)
