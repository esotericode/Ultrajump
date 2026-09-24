extends AirState
## Airborne without having jumped: ran off a ledge, let go of a wall, etc.
## Shortly after running off a ledge, a jump still works (coyote time) and
## becomes whatever jump the ground state would have done.

var _coyote_time := 0.0
var _coyote_from := &""


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	_coyote_time = settings.coyote_time if msg.get("coyote", false) else 0.0
	_coyote_from = msg.get("from", &"")


func physics_update(delta: float) -> void:
	if _coyote_time > 0.0:
		_coyote_time -= delta
		if player.consume(&"jump"):
			_coyote_jump()
			return
	super(delta)


func _coyote_jump() -> void:
	match _coyote_from:
		&"CrouchSlide":
			transition_to(&"LongJump")
		&"Crouch":
			transition_to(&"Backflip")
		&"Skid":
			transition_to(&"SideFlip", {"direction": -player.facing})
		_:
			transition_to(&"Jump", {"chain": player.next_chain_jump()})
