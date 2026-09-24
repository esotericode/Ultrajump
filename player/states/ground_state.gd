class_name GroundState
extends PlayerState
## Shared behaviour for states where the player stands on the floor.


## The standard jump press: continues the single / double / triple chain when timed right.
func chain_jump() -> void:
	transition_to(&"Jump", {"chain": player.next_chain_jump()})


## Crouch, jump and dive while standing or running. Returns true if the state changed.
func handle_ground_actions() -> bool:
	# Crouch comes first so crouch + jump pressed together still backflips / long jumps.
	if player.input.held(&"crouch"):
		if player.horizontal_speed() >= settings.crouch_slide_min_speed:
			transition_to(&"CrouchSlide")
		else:
			transition_to(&"Crouch")
		return true
	if player.consume(&"jump"):
		chain_jump()
		return true
	if player.consume(&"attack"):
		transition_to(&"Dive", {"from_ground": true})
		return true
	if player.consume(&"spin"):
		player.spun.emit(false)
	return false


## Call after moving: if the floor is gone, fall (with coyote time for a late jump).
func check_fall() -> bool:
	if player.is_on_floor():
		return false
	transition_to(&"Fall", {"coyote": true, "from": name})
	return true
