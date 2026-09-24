@tool
class_name Crate
extends StaticBody3D
## A breakable crate: solid to stand on, smashed by punches, kicks, dives,
## spins and ground pounds. Can hold coins that pop out when it breaks.
## Crates stacked on it (siblings) drop into the gap once nothing holds them up.

signal broken

@export var size := 1.2:
	set(value):
		size = maxf(value, 0.2)
		_rebuild()
## Coins that pop out when the crate breaks.
@export_range(0, 20) var coins := 0

static var _material: ShaderMaterial

var _visual: MeshInstance3D
var _collider: CollisionShape3D
var _broken := false


func _ready() -> void:
	# Solid like the rest of the level, and on the Hittable layer for attacks.
	collision_layer = 1 | Player.HITTABLE_LAYER
	_rebuild()


## Called by the player's attacks.
func take_hit(_hit: Dictionary) -> void:
	if _broken:
		return
	_broken = true
	var center := global_position
	PropFx.debris(self, center, Color(0.8, 0.55, 0.3), size)
	Synth.play_at(self, Synth.sound(&"crate"), center, -3.0, randf_range(0.9, 1.1))
	for i in coins:
		Coin.pop_out(get_parent(), center + Vector3.UP * 0.2)
	_release_crates_above()
	broken.emit()
	queue_free()


## Drops the crate one crate-height, along with anything stacked on it.
func fall() -> void:
	_release_crates_above()
	var tween := create_tween()
	tween.tween_property(self, ^"position:y", position.y - size, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Crates resting on this one fall, unless another crate still holds them up.
func _release_crates_above() -> void:
	for crate in _stacked(1.0):
		if crate._stacked(-1.0).all(func(support: Crate) -> bool: return support == self):
			crate.fall()


## Sibling crates overlapping this one's footprint one layer above
## ([param layer] 1) or below (-1).
func _stacked(layer: float) -> Array[Crate]:
	var found: Array[Crate] = []
	for sibling in get_parent().get_children():
		var crate := sibling as Crate
		if crate == null or crate == self or crate._broken:
			continue
		var offset := crate.position - position
		if absf(offset.x) < size and absf(offset.z) < size and absf(offset.y - layer * size) < size * 0.25:
			found.append(crate)
	return found


func _rebuild() -> void:
	if not is_node_ready():
		return
	if _visual == null:
		_visual = MeshInstance3D.new()
		add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
		_collider = CollisionShape3D.new()
		add_child(_collider, false, Node.INTERNAL_MODE_FRONT)
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://levels/props/crate.gdshader")
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	_visual.mesh = mesh
	_visual.material_override = _material
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * size
	_collider.shape = box
