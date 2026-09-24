@tool
class_name TimeTrialGate
extends Area3D
## The start or finish line of a timed course. Run through the start to start
## the clock, and through the finish to stop it. Finishing within
## [member par_time] reveals [member reward].

enum Role { START, FINISH }

@export var role := Role.START:
	set(value):
		role = value
		_rebuild()
@export var course := "Parkour"
@export var width := 4.0:
	set(value):
		width = maxf(value, 1.0)
		_rebuild()
## Finish only: finishing faster than this (seconds) reveals the reward. 0 = any time.
@export var par_time := 0.0
## Finish only: the star revealed for beating the par time.
@export var reward: Star

var _posts: Array[MeshInstance3D] = []
var _banner: MeshInstance3D
var _collider: CollisionShape3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Coin.PLAYER_LAYER
	monitorable = false
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	if role == Role.START:
		if GameState.time_trial_course != course:
			GameState.start_time_trial(course)
			Synth.play_at(self, Synth.sound(&"whistle"), global_position, -6.0)
		return
	var time := GameState.finish_time_trial(course)
	if time < 0.0:
		return
	Synth.play_at(self, Synth.sound(&"checkpoint"), global_position, -4.0)
	if reward and (par_time <= 0.0 or time <= par_time):
		reward.reveal()
	elif reward and not GameState.has_star(reward.star_name):
		GameState.message.emit("Beat %.1f s for the star!" % par_time)


func _rebuild() -> void:
	if not is_node_ready():
		return
	if _collider == null:
		_collider = CollisionShape3D.new()
		add_child(_collider, false, Node.INTERNAL_MODE_FRONT)
		for i in 2:
			var post := MeshInstance3D.new()
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.12
			post_mesh.bottom_radius = 0.12
			post_mesh.height = 3.2
			post.mesh = post_mesh
			add_child(post, false, Node.INTERNAL_MODE_FRONT)
			_posts.append(post)
		_banner = MeshInstance3D.new()
		add_child(_banner, false, Node.INTERNAL_MODE_FRONT)
	var box := BoxShape3D.new()
	box.size = Vector3(width, 3.0, 0.6)
	_collider.shape = box
	_collider.position.y = 1.5
	var tint := Color(0.3, 0.9, 0.45) if role == Role.START else Color(0.95, 0.95, 0.95)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.25
	for i in 2:
		_posts[i].position = Vector3((i - 0.5) * width, 1.6, 0.0)
		_posts[i].material_override = material
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(width, 0.5, 0.08)
	_banner.mesh = banner_mesh
	_banner.material_override = material
	_banner.position.y = 3.0
