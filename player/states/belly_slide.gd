extends GroundState
## Sliding on your belly after a dive lands. Jump (or dive) to roll out.

var _stopped_time := 0.0


func enter(_previous: StringName, _msg: Dictionary) -> void:
	player.jump_chain = 0
	_stopped_time = 0.0


func physics_update(delta: float) -> void:
	if player.consume(&"jump") or player.consume(&"attack"):
		transition_to(&"Rollout")
		return
	player.slide_move(delta, settings.belly_slide_friction, settings.belly_slide_turn_speed)
	player.move(true)
	if not player.is_on_floor():
		# Slid off an edge: keep the dive pose (a late jump still rolls out).
		transition_to(&"Dive", {"slide_off": true})
		return
	if player.horizontal_speed() < 1.0:
		_stopped_time += delta
		if _stopped_time >= settings.belly_slide_getup_time:
			player.enter_ground_state()
	else:
		_stopped_time = 0.0
