extends AirState
## Jumping from a ledge hang: hop up, and keep drifting toward the ledge until
## clear of its lip so you land on top.

## Speed toward the ledge while rising past its lip.
const DRIFT_SPEED := 2.5

var _top_y := 0.0
var _drift := Vector3.ZERO


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	_top_y = msg.top_y
	_drift = -(msg.normal as Vector3) * DRIFT_SPEED
	player.jump_chain = 0
	player.velocity.y = settings.jump_velocity(settings.ledge_jump_height)
	player.set_horizontal_velocity(_drift)
	apex_hang = true
	# Rising along the ledge's face: don't cling to it or re-grab it.
	can_wall_slide = false
	can_grab_ledge = false
	player.jumped.emit(&"ledge_jump")


func physics_update(delta: float) -> void:
	# Sliding up the wall cancels velocity into it; keep pushing until past the lip.
	var toward_ledge := _drift.normalized()
	var velocity := player.horizontal_velocity()
	var speed_toward := velocity.dot(toward_ledge)
	if player.global_position.y < _top_y + 0.1 and speed_toward < DRIFT_SPEED:
		player.set_horizontal_velocity(velocity + toward_ledge * (DRIFT_SPEED - speed_toward))
	super(delta)
