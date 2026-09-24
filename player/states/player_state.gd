class_name PlayerState
extends Node
## Base class for the player's movement states.
##
## A state gets [method enter] when it becomes active (with an optional
## message from the previous state), [method physics_update] every physics
## tick while active, and [method exit] when it hands over.

var player: Player
var machine: PlayerStateMachine
## Seconds since this state was entered.
var time_in_state := 0.0

var settings: MovementSettings:
	get:
		return player.settings


func enter(_previous: StringName, _msg: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	machine.transition_to(state_name, msg)


func is_active() -> bool:
	return machine.current == self
