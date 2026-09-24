@tool
class_name Star
extends Area3D
## A star: the prize at the end of a challenge. Touch it to collect it.
##
## With [member hidden_until_revealed], it stays invisible until something
## calls [method reveal] (a cleared crate group, a fast enough time trial...).
## Collected stars remain as translucent ghosts.

@export var star_name := "Star"
@export var hidden_until_revealed := false

static var _mesh: ArrayMesh
static var _gold: StandardMaterial3D
static var _ghost: StandardMaterial3D

var _visual: MeshInstance3D
var _phase := 0.0
var _revealed := true
var _collected := false


func _ready() -> void:
	collision_layer = Coin.PICKUP_LAYER
	collision_mask = Coin.PLAYER_LAYER
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	shape.shape = sphere
	add_child(shape, false, Node.INTERNAL_MODE_FRONT)
	_build_resources()
	_visual = MeshInstance3D.new()
	_visual.mesh = _mesh
	_visual.material_override = _gold
	_visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		return
	GameState.register_star()
	body_entered.connect(_on_body_entered)
	if GameState.has_star(star_name):
		_show_collected()
	elif hidden_until_revealed:
		_revealed = false
		_visual.visible = false
		set_deferred(&"monitoring", false)


func _process(delta: float) -> void:
	_phase += delta
	_visual.rotation.y = _phase * 1.8
	_visual.position.y = sin(_phase * 2.0) * 0.12


## Makes a hidden star appear (with a flourish).
func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	_visual.visible = true
	set_deferred(&"monitoring", true)
	_visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Synth.play_at(self, Synth.sound(&"reveal"), global_position, -4.0)
	PropFx.sparkle(self, global_position, Color(1.0, 0.9, 0.4), 24, 6.0)
	GameState.message.emit("A star appeared!")


func _on_body_entered(body: Node3D) -> void:
	if _collected or not _revealed or not body is Player:
		return
	if GameState.collect_star(star_name):
		Synth.play_at(self, Synth.sound(&"star"), global_position, -2.0)
		PropFx.sparkle(self, global_position, Color(1.0, 0.9, 0.4), 30, 7.0)
	_show_collected()


func _show_collected() -> void:
	_collected = true
	_visual.material_override = _ghost


## A puffy five-pointed star, pointed front and back.
static func _build_resources() -> void:
	if _mesh != null:
		return
	var rim: Array[Vector3] = []
	for i in 10:
		var angle := PI / 2.0 + i * PI / 5.0
		var radius := 0.62 if i % 2 == 0 else 0.27
		rim.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0.0))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tip in [Vector3(0, 0, 0.22), Vector3(0, 0, -0.22)]:
		for i in rim.size():
			_face(tool, tip, rim[i], rim[(i + 1) % rim.size()])
	_mesh = tool.commit()
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(1.0, 0.85, 0.2)
	_gold.metallic = 0.3
	_gold.roughness = 0.35
	_gold.emission_enabled = true
	_gold.emission = Color(1.0, 0.7, 0.15)
	_gold.emission_energy_multiplier = 0.8
	_gold.rim_enabled = true
	_ghost = StandardMaterial3D.new()
	_ghost.albedo_color = Color(0.6, 0.8, 1.0, 0.45)
	_ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost.emission_enabled = true
	_ghost.emission = Color(0.3, 0.5, 0.9)
	_ghost.emission_energy_multiplier = 0.4


## A flat-shaded triangle facing away from the star's center.
static func _face(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.dot((a + b + c) / 3.0) < 0.0:
		normal = -normal
		var swap := b
		b = c
		c = swap
	# Godot treats clockwise triangles as front faces.
	for vertex in [a, c, b]:
		tool.set_normal(normal)
		tool.add_vertex(vertex)
