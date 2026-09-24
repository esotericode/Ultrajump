extends PlayerState
## Hanging from a ledge. Push toward it to climb up, jump to hop up and over,
## pull away (or press crouch) to drop.

var ledge: Dictionary
var _grab_from := Vector3.ZERO


func enter(_previous: StringName, msg: Dictionary) -> void:
	ledge = msg
	player.velocity = Vector3.ZERO
	player.facing = -(ledge.normal as Vector3)
	player.jump_chain = 0
	player.air_spin_available = true
	_grab_from = player.global_position
	player.ledge_grabbed.emit()


func physics_update(_delta: float) -> void:
	# Ease into the hang position instead of snapping to it.
	var blend := clampf(time_in_state / 0.08, 0.0, 1.0)
	player.global_position = _grab_from.lerp(ledge.hang_position, blend)
	player.velocity = Vector3.ZERO
	if time_in_state < settings.ledge_input_delay:
		return
	var normal: Vector3 = ledge.normal
	var toward_ledge := player.input.move.dot(-normal)
	if player.consume(&"jump"):
		player.global_position = ledge.hang_position
		transition_to(&"LedgeJump", ledge)
	elif player.consume(&"crouch") or toward_ledge < -0.6:
		player.ledge_cooldown = settings.ledge_regrab_cooldown
		player.set_horizontal_velocity(normal * 1.5)
		transition_to(&"Fall")
	elif toward_ledge > 0.6:
		transition_to(&"LedgeClimb", ledge)
