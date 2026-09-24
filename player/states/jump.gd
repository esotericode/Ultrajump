extends AirState
## A regular jump. Covers the single / double / triple chain, plus plain hops
## other states launch (like jumping off a steep slope).
##
## Message keys: [code]chain[/code] (1-3, or 0 for a jump that doesn't chain),
## and optionally [code]kind[/code], [code]height[/code] and
## [code]horizontal[/code] (a velocity to launch with) to override the defaults.

const CHAIN_KINDS: Array[StringName] = [&"single", &"double", &"triple"]

var chain := 1
var kind := &"single"


func enter(previous: StringName, msg: Dictionary) -> void:
	super(previous, msg)
	chain = msg.get("chain", 1)
	kind = msg.get("kind", CHAIN_KINDS[clampi(chain, 1, 3) - 1])
	var height: float = msg.get("height", _chain_height())
	player.jump_chain = chain
	player.velocity.y = settings.jump_velocity(height)
	if msg.has("horizontal"):
		var launch: Vector3 = msg.horizontal
		player.set_horizontal_velocity(launch)
		if launch.length_squared() > 0.01:
			player.facing = Vector3(launch.x, 0.0, launch.z).normalized()
	# The triple jump always goes full height; the others respond to how long jump is held.
	variable_height = chain != 3
	apex_hang = true
	player.jumped.emit(kind)


func on_land() -> void:
	player.land(chain > 0)
	player.enter_ground_state()


func _chain_height() -> float:
	match chain:
		2:
			return settings.double_jump_height
		3:
			return settings.triple_jump_height
	return settings.single_jump_height
