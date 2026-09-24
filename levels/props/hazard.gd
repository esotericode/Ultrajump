@tool
class_name Hazard
extends Area3D
## A volume that sends the player back to the last checkpoint: lava, a pit,
## spikes... By default it looks like glowing lava on its top face.

@export var size := Vector3(10.0, 1.0, 10.0):
	set(value):
		size = value.max(Vector3.ONE * 0.1)
		_rebuild()
@export var show_lava := true:
	set(value):
		show_lava = value
		_rebuild()

static var _lava: StandardMaterial3D

var _collider: CollisionShape3D
var _surface: MeshInstance3D
var _phase := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Coin.PLAYER_LAYER
	monitorable = false
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _lava:
		_phase += delta
		_lava.emission_energy_multiplier = 1.1 + sin(_phase * 2.5) * 0.25


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		Synth.play_at(self, Synth.sound(&"sizzle"), body.global_position, -4.0)
		PropFx.sparkle(self, body.global_position + Vector3.UP * 0.5, Color(1.0, 0.5, 0.1), 16, 5.0)
		GameState.request_respawn()


func _rebuild() -> void:
	if not is_node_ready():
		return
	if _collider == null:
		_collider = CollisionShape3D.new()
		add_child(_collider, false, Node.INTERNAL_MODE_FRONT)
		_surface = MeshInstance3D.new()
		add_child(_surface, false, Node.INTERNAL_MODE_FRONT)
	var box := BoxShape3D.new()
	box.size = size
	_collider.shape = box
	_surface.visible = show_lava
	if _lava == null:
		_lava = StandardMaterial3D.new()
		_lava.albedo_color = Color(1.0, 0.35, 0.08)
		_lava.emission_enabled = true
		_lava.emission = Color(1.0, 0.3, 0.05)
		_lava.emission_energy_multiplier = 1.1
	var plane := PlaneMesh.new()
	plane.size = Vector2(size.x, size.z)
	_surface.mesh = plane
	_surface.material_override = _lava
	_surface.position.y = size.y * 0.5
