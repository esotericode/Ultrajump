extends GroundState
## Crouching in place (or crawling). Jump to backflip.


func enter(_previous: StringName, _msg: Dictionary) -> void:
	player.jump_chain = 0
	# This press was spent crouching; it mustn't become a ground pound after the next jump.
	player.clear_buffer(&"crouch")


func physics_update(delta: float) -> void:
	if player.consume(&"jump"):
		transition_to(&"Backflip")
		return
	if player.consume(&"attack"):
		attack()
		return
	if not player.input.held(&"crouch"):
		transition_to(&"Run" if player.input.move.length_squared() > 0.0025 else &"Idle")
		return
	player.crawl_move(delta)
	player.move(true)
	check_fall()
