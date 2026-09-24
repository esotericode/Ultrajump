class_name PlayerStateMachine
extends Node
## Runs the player's movement states. Every child node is a [PlayerState],
## addressed by its node name (e.g. [code]&"Run"[/code]).

## The state the player starts in.
@export var initial_state: PlayerState

var player: Player
var current: PlayerState
var states: Dictionary[StringName, PlayerState] = {}


func setup(owner_player: Player) -> void:
	player = owner_player
	for child in get_children():
		var state := child as PlayerState
		if state:
			states[state.name] = state
			state.player = player
			state.machine = self
	current = initial_state if initial_state else states.values()[0]
	current.enter(&"", {})


func physics_update(delta: float) -> void:
	# A state may hand over to another one before it moves the body (say, Run
	# seeing a jump press). The new state then runs in the same tick, so taking
	# off never costs a frame of motion. Once the body has moved, the tick ends.
	for i in 4:
		var state := current
		state.physics_update(delta)
		state.time_in_state += delta
		if current == state or player.moved_this_tick:
			break


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	var next: PlayerState = states.get(state_name)
	if next == null:
		push_error("Player has no state named '%s'." % state_name)
		return
	var previous := current
	previous.exit()
	current = next
	current.time_in_state = 0.0
	current.enter(previous.name, msg)
	player.state_changed.emit(previous.name, current.name)
