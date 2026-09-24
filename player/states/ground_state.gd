class_name GroundState
extends PlayerState
## Shared behaviour for states where the player stands on the floor.


## The standard jump press: continues the single / double / triple chain when timed right.
func chain_jump() -> void:
	transition_to(&"Jump", {"chain": player.next_chain_jump()})


## Crouch, jump and attack while standing or running. Returns true if the state changed.
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
		attack()
		return true
	if player.consume(&"spin"):
		# A quick spin on the spot doubles as a close-range attack.
		player.spun.emit(false)
		player.strike(&"spin", 0.0, 1.0, 0.8, [])
	return false


## The attack button on the ground: a dive when running flat out, otherwise
## the punch-punch-kick combo.
func attack() -> void:
	var sprinting := player.horizontal_speed() >= settings.ground_dive_min_speed and player.input.move.length() > 0.9
	if sprinting:
		transition_to(&"Dive", {"from_ground": true})
	else:
		transition_to(&"Punch", {"combo": player.next_combo_step()})


## Call after moving: if the floor is gone, fall (with coyote time for a late jump).
func check_fall() -> bool:
	if player.is_on_floor():
		return false
	transition_to(&"Fall", {"coyote": true, "from": name})
	return true
