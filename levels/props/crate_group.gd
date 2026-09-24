@tool
class_name CrateGroup
extends Node3D
## Watches the Crate nodes under it and reveals [member reward] once every
## one of them is broken.

signal cleared

@export var reward: Star

var _remaining := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for crate in _crates(self):
		_remaining += 1
		crate.broken.connect(_on_crate_broken)


func _on_crate_broken() -> void:
	_remaining -= 1
	if _remaining > 0:
		GameState.message.emit("%d crate%s to go" % [_remaining, "" if _remaining == 1 else "s"])
		return
	cleared.emit()
	if reward:
		reward.reveal()


static func _crates(node: Node) -> Array[Crate]:
	var found: Array[Crate] = []
	for child in node.get_children():
		if child is Crate:
			found.append(child)
		found.append_array(_crates(child))
	return found
