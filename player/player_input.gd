class_name PlayerInput
extends RefCounted
## A snapshot of the player's intent for one physics tick.
##
## The player never reads [Input] directly; it reads this object instead. By
## default it is filled from the input map every tick, relative to the camera.
## Set [member scripted] to drive the character from code instead (automated
## tests, replays, cutscenes, AI): then call [method press], [method release]
## and set [member move] yourself.

## Actions that can be buffered by the player (see [method Player.consume]).
const ACTIONS: Array[StringName] = [&"jump", &"crouch", &"attack", &"spin"]

## Desired horizontal movement in world space. Length is 0..1 (stick tilt).
var move := Vector3.ZERO
## Raw stick / WASD vector before being made camera-relative.
var move_raw := Vector2.ZERO

## When true, [method gather] leaves every field alone so code can drive them.
var scripted := false
## When false, [method gather] reports no input at all (e.g. while a menu is open).
var enabled := true

var _held: Dictionary[StringName, bool] = {}
var _pressed: Dictionary[StringName, bool] = {}


func _init() -> void:
	for action in ACTIONS:
		_held[action] = false
		_pressed[action] = false


## Refreshes the snapshot from the input map, relative to [param view_basis] (the camera).
func gather(view_basis: Basis) -> void:
	if scripted:
		return
	if not enabled:
		clear()
		return

	move_raw = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if Input.is_action_pressed(&"walk"):
		move_raw = move_raw.limit_length(0.45)

	var forward := -view_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		# Looking straight down: fall back to the camera's up vector.
		forward = -view_basis.y
		forward.y = 0.0
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	move = (right * move_raw.x - forward * move_raw.y).limit_length(1.0)

	for action in ACTIONS:
		_held[action] = Input.is_action_pressed(action)
		_pressed[action] = Input.is_action_just_pressed(action)


## True on the tick the action went down.
func pressed(action: StringName) -> bool:
	return _pressed.get(action, false)


## True while the action is held down.
func held(action: StringName) -> bool:
	return _held.get(action, false)


## Scripted input: pushes an action down (it counts as pressed on the next tick).
func press(action: StringName) -> void:
	_pressed[action] = true
	_held[action] = true


## Scripted input: lets go of an action.
func release(action: StringName) -> void:
	_held[action] = false


## Forgets this tick's presses. Called by the player once a tick has been processed.
func end_tick() -> void:
	for action in ACTIONS:
		_pressed[action] = false


func clear() -> void:
	move = Vector3.ZERO
	move_raw = Vector2.ZERO
	for action in ACTIONS:
		_held[action] = false
		_pressed[action] = false
