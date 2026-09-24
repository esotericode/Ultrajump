extends PlayerState
## Pulling up onto a ledge: straight up past the edge, then forward onto it.

const LIFT_PORTION := 0.6

var ledge: Dictionary
var _start := Vector3.ZERO


func enter(_previous: StringName, msg: Dictionary) -> void:
	ledge = msg
	_start = player.global_position
	player.velocity = Vector3.ZERO


func physics_update(delta: float) -> void:
	var stand: Vector3 = ledge.stand_position
	var lifted := Vector3(_start.x, stand.y, _start.z)
	var t := (time_in_state + delta) / settings.ledge_climb_time
	if t < LIFT_PORTION:
		player.global_position = _start.lerp(lifted, ease(t / LIFT_PORTION, 0.5))
	elif t < 1.0:
		player.global_position = lifted.lerp(stand, ease((t - LIFT_PORTION) / (1.0 - LIFT_PORTION), 0.6))
	else:
		player.global_position = stand
		player.velocity = Vector3.ZERO
		player.apply_floor_snap()
		player.enter_ground_state()
