@tool
class_name Checkpoint
extends Area3D
## Touch it to make it the respawn point (for falls, hazards and R). Its flag
## turns green once active. The player respawns facing its -Z axis.

static var _pole_material: StandardMaterial3D
static var _off_material: StandardMaterial3D
static var _on_material: StandardMaterial3D

var _flag: MeshInstance3D
var _active := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Coin.PLAYER_LAYER
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.5, 3.0, 2.5)
	shape.shape = box
	shape.position.y = 1.5
	add_child(shape, false, Node.INTERNAL_MODE_FRONT)
	_build_materials()
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.05
	pole_mesh.bottom_radius = 0.05
	pole_mesh.height = 2.2
	pole.mesh = pole_mesh
	pole.material_override = _pole_material
	pole.position = Vector3(1.0, 1.1, 0.0)
	add_child(pole, false, Node.INTERNAL_MODE_FRONT)
	_flag = MeshInstance3D.new()
	_flag.mesh = _flag_mesh()
	_flag.material_override = _off_material
	_flag.position = Vector3(1.38, 1.95, 0.0)
	add_child(_flag, false, Node.INTERNAL_MODE_FRONT)
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	var here := Transform3D(global_basis.orthonormalized(), global_position)
	if _active and GameState.checkpoint.origin.is_equal_approx(here.origin):
		return
	_active = true
	_flag.material_override = _on_material
	GameState.set_checkpoint(here, true)
	Synth.play_at(self, Synth.sound(&"checkpoint"), global_position, -6.0)


## Adds a raised (glowing) flag under [param stage] (in view of the camera,
## behind a loading screen), so its material is compiled before play instead
## of at the first checkpoint.
static func warm_up(stage: Node3D) -> void:
	_build_materials()
	var flag := MeshInstance3D.new()
	flag.mesh = _flag_mesh()
	flag.material_override = _on_material
	stage.add_child(flag)


static func _build_materials() -> void:
	if _pole_material != null:
		return
	_pole_material = StandardMaterial3D.new()
	_pole_material.albedo_color = Color(0.85, 0.85, 0.9)
	_off_material = StandardMaterial3D.new()
	_off_material.albedo_color = Color(0.55, 0.55, 0.6)
	_on_material = StandardMaterial3D.new()
	_on_material.albedo_color = Color(0.3, 0.95, 0.45)
	_on_material.emission_enabled = true
	_on_material.emission = Color(0.2, 0.9, 0.35)
	_on_material.emission_energy_multiplier = 0.5


static func _flag_mesh() -> BoxMesh:
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.7, 0.45, 0.04)
	return flag_mesh
