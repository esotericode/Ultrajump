@tool
class_name BouncePad
extends StaticBody3D
## A springy pad that launches the player [member height] meters up.
## Ground pound onto it to go higher.

@export var height := 8.0
@export var diameter := 2.4:
	set(value):
		diameter = maxf(value, 0.5)
		_rebuild()

const PAD_THICKNESS := 0.3

static var _base_material: StandardMaterial3D
static var _top_material: StandardMaterial3D

var _visual: Node3D
var _top: MeshInstance3D
var _collider: CollisionShape3D
var _trigger: Area3D


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		_trigger.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or player.velocity.y > 1.0:
		return
	player.bounce(height)
	Synth.play_at(self, Synth.sound(&"spring"), global_position, -4.0)
	var tween := create_tween()
	tween.tween_property(_top, "scale:y", 0.3, 0.06)
	tween.tween_property(_top, "scale:y", 1.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _rebuild() -> void:
	if not is_node_ready():
		return
	if _visual == null:
		_build_materials()
		_visual = Node3D.new()
		add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
		var base_instance := MeshInstance3D.new()
		base_instance.name = "Base"
		base_instance.material_override = _base_material
		_visual.add_child(base_instance)
		_top = MeshInstance3D.new()
		_top.material_override = _top_material
		_visual.add_child(_top)
		_collider = CollisionShape3D.new()
		add_child(_collider, false, Node.INTERNAL_MODE_FRONT)
		_trigger = Area3D.new()
		_trigger.collision_layer = 0
		_trigger.collision_mask = Coin.PLAYER_LAYER
		_trigger.monitorable = false
		_trigger.add_child(CollisionShape3D.new())
		add_child(_trigger, false, Node.INTERNAL_MODE_FRONT)
	var radius := diameter * 0.5
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = radius
	base_mesh.bottom_radius = radius * 1.08
	base_mesh.height = PAD_THICKNESS * 0.6
	var base := _visual.get_node(^"Base") as MeshInstance3D
	base.mesh = base_mesh
	base.position.y = PAD_THICKNESS * 0.3
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = radius * 0.85
	top_mesh.bottom_radius = radius * 0.85
	top_mesh.height = PAD_THICKNESS * 0.4
	_top.mesh = top_mesh
	_top.position.y = PAD_THICKNESS * 0.8
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = PAD_THICKNESS
	_collider.shape = shape
	_collider.position.y = PAD_THICKNESS * 0.5
	var trigger_shape := CylinderShape3D.new()
	trigger_shape.radius = radius * 0.9
	trigger_shape.height = 0.5
	(_trigger.get_child(0) as CollisionShape3D).shape = trigger_shape
	_trigger.position.y = PAD_THICKNESS + 0.2


static func _build_materials() -> void:
	if _base_material != null:
		return
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = Color(0.25, 0.27, 0.35)
	_top_material = StandardMaterial3D.new()
	_top_material.albedo_color = Color(1.0, 0.35, 0.45)
	_top_material.emission_enabled = true
	_top_material.emission = Color(1.0, 0.3, 0.4)
	_top_material.emission_energy_multiplier = 0.3
