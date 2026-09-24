@tool
class_name Coin
extends Area3D
## A coin: touch it to collect it. Coins collected in quick succession chime
## higher and higher.

const PICKUP_LAYER := 1 << 3
const PLAYER_LAYER := 1 << 1

static var _mesh: CylinderMesh
static var _material: StandardMaterial3D
static var _last_pickup := -10.0
static var _streak := 0

var _visual: MeshInstance3D
var _phase := 0.0
var _collected := false


func _ready() -> void:
	collision_layer = PICKUP_LAYER
	collision_mask = PLAYER_LAYER
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	add_child(shape, false, Node.INTERNAL_MODE_FRONT)
	if _mesh == null:
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 0.34
		_mesh.bottom_radius = 0.34
		_mesh.height = 0.08
		_mesh.radial_segments = 20
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(1.0, 0.8, 0.2)
		_material.metallic = 0.6
		_material.roughness = 0.3
		_material.emission_enabled = true
		_material.emission = Color(1.0, 0.7, 0.15)
		_material.emission_energy_multiplier = 0.35
	_visual = MeshInstance3D.new()
	_visual.mesh = _mesh
	_visual.material_override = _material
	# Spun every rendered frame, so skip physics interpolation.
	_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	_phase = fmod(absf(position.x * 0.7 + position.z * 0.3), TAU)
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_phase += delta
	_visual.rotation = Vector3(PI / 2.0, _phase * 3.0, 0.0)
	_visual.position.y = sin(_phase * 2.0) * 0.08


## Pops a coin out of [param at] (a broken crate) in a little hop, landing
## [param spread] meters away.
static func pop_out(parent: Node, at: Vector3, spread := 1.2) -> Coin:
	var coin := Coin.new()
	parent.add_child(coin)
	coin.global_position = at
	var angle := randf() * TAU
	var landing := at + Vector3(cos(angle), 0.0, sin(angle)) * spread + Vector3.UP * 0.2
	var tween := coin.create_tween()
	tween.tween_property(coin, "global_position:x", landing.x, 0.45)
	tween.parallel().tween_property(coin, "global_position:z", landing.z, 0.45)
	tween.parallel().tween_property(coin, "global_position:y", at.y + 1.4, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(coin, "global_position:y", landing.y, 0.25).set_delay(0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	return coin


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body is Player:
		return
	_collected = true
	GameState.add_coins(1)
	var now := Time.get_ticks_msec() / 1000.0
	_streak = _streak + 1 if now - _last_pickup < 0.6 else 0
	_last_pickup = now
	Synth.play_at(self, Synth.sound(&"coin"), global_position, -9.0, pow(2.0, minf(_streak, 12) / 12.0))
	PropFx.sparkle(self, global_position, Color(1.0, 0.9, 0.4), 8, 3.0)
	queue_free()
