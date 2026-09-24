extends GroundState
## Punch, punch, kick: the attack button's ground combo, Super Mario 64 style.
##
## Pressing attack during a hit queues the next one; the kick ends the combo.
## Each hit turns toward the stick, lunges a little, and hits whatever is in
## front of the player mid-swing.

const KINDS: Array[StringName] = [&"punch_1", &"punch_2", &"kick"]

## 1 and 2 are punches, 3 is the kick.
var combo := 1

var _queued := false
var _hit: Array = []


func enter(_previous: StringName, msg: Dictionary) -> void:
	combo = clampi(msg.get("combo", 1), 1, 3)
	player.jump_chain = 0
	_queued = false
	_hit.clear()
	var input_dir := player.input.move
	if input_dir.length() > 0.2:
		player.facing = input_dir.normalized()
	var lunge := settings.kick_lunge_speed if combo == 3 else settings.punch_lunge_speed
	player.set_horizontal_velocity(player.facing * maxf(player.horizontal_speed() * 0.5, lunge))
	player.attacked.emit(KINDS[combo - 1])


func exit() -> void:
	player.combo_step = combo
	player.time_since_attack = 0.0


func physics_update(delta: float) -> void:
	if player.consume(&"jump"):
		chain_jump()
		return
	if combo < 3 and player.consume(&"attack"):
		_queued = true
	var duration := settings.kick_duration if combo == 3 else settings.punch_duration
	var progress := time_in_state / duration
	if progress > 0.15 and progress < 0.6:
		# Mid-swing: the fist (or foot) connects.
		player.strike(KINDS[combo - 1], settings.attack_reach, settings.attack_radius, 0.6 if combo == 3 else 0.9, _hit)
	player.set_horizontal_velocity(player.horizontal_velocity().move_toward(Vector3.ZERO, settings.punch_friction * delta))
	player.velocity.y = 0.0
	player.move(true)
	if check_fall():
		return
	if _queued and time_in_state >= settings.combo_min_time:
		transition_to(&"Punch", {"combo": combo + 1})
	elif time_in_state >= duration:
		player.enter_ground_state()
