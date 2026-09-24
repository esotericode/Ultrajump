extends AirState
## A quick forward roll out of a belly slide, keeping your momentum.
## You can dive again from it.


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	player.jump_chain = 0
	player.velocity.y = settings.jump_velocity(settings.rollout_height)
	apex_hang = true
	player.jumped.emit(&"rollout")
