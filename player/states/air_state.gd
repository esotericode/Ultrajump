class_name AirState
extends PlayerState
## Shared behaviour for airborne states: gravity, air control, and what happens
## on touching the floor, a wall, a steep slope or a ledge.
##
## Subclasses tweak the flags below in [method enter] (after calling
## [code]super()[/code]) to shape the move, and can override
## [method on_land] for special landings.

## Multiplies all gravity while in this state.
var gravity_scale := 1.0
## Releasing jump early cuts the jump short.
var variable_height := false
## Softer gravity around the apex while jump is held.
var apex_hang := false
## Multiplies air acceleration (0 = no steering).
var air_control := 1.0
## Turn the character to face its direction of travel.
var turn_to_velocity := true
var can_dive := true
var can_ground_pound := true
var can_spin := true
var can_wall_kick := true
var can_grab_ledge := true


func enter(_previous: StringName, _msg: Dictionary) -> void:
	gravity_scale = 1.0
	variable_height = false
	apex_hang = false
	air_control = 1.0
	turn_to_velocity = true
	can_dive = true
	can_ground_pound = true
	can_spin = true
	can_wall_kick = true
	can_grab_ledge = true


func physics_update(delta: float) -> void:
	if handle_air_actions():
		return
	player.apply_gravity(delta, gravity_scale, variable_height, apex_hang)
	player.air_move(delta, air_control)
	if turn_to_velocity:
		player.face_velocity(delta, settings.air_turn_speed)
	player.move()
	after_move()


## Dive, ground pound and air spin presses. Returns true if the state changed.
func handle_air_actions() -> bool:
	if can_dive and player.consume(&"attack"):
		transition_to(&"Dive")
		return true
	if can_ground_pound and player.consume(&"crouch"):
		transition_to(&"GroundPound")
		return true
	if can_spin and player.air_spin_available and player.consume(&"spin"):
		transition_to(&"Spin")
		return true
	return false


## Reacts to what the last move ran into. Returns true if the state changed.
func after_move() -> bool:
	return check_landing() or check_ledge() or check_surfaces()


func check_landing() -> bool:
	if not player.is_on_floor():
		return false
	on_land()
	return true


## Called on touchdown. By default: land and run / stand / crouch.
func on_land() -> void:
	player.land()
	player.enter_ground_state()


## Hitting a wall at speed opens a brief wall kick window; slopes too steep to
## stand on start a steep slide.
func check_surfaces() -> bool:
	if not player.is_on_wall():
		return false
	var normal := player.get_wall_normal()
	if normal.y > 0.2:
		transition_to(&"SteepSlide")
		return true
	if not can_wall_kick or normal.y < -0.3:
		return false
	var wall := Vector3(normal.x, 0.0, normal.z).normalized()
	var speed_into_wall := player.velocity_before_move.dot(-wall)
	if speed_into_wall < settings.wall_contact_min_speed or not player.can_touch_wall(wall):
		return false
	transition_to(&"WallContact", {"normal": wall})
	return true


func check_ledge() -> bool:
	if not can_grab_ledge or not settings.ledge_grab_enabled or player.ledge_cooldown > 0.0:
		return false
	if player.velocity.y > settings.ledge_grab_max_rise_speed:
		return false
	var direction := player.facing
	if player.is_on_wall():
		direction = -player.get_wall_normal()
	elif player.input.move.dot(direction) < 0.1 and player.velocity_before_move.dot(direction) < 0.5:
		return false # Only grab ledges we're actually heading toward.
	var ledge := player.find_ledge(direction)
	if ledge.is_empty():
		return false
	var top_above_feet: float = ledge.top_y - player.global_position.y
	if top_above_feet >= settings.ledge_min_height:
		if player.is_space_blocked(ledge.hang_position):
			return false
		transition_to(&"LedgeHang", ledge)
		return true
	if settings.ledge_mantle_enabled and player.velocity.y <= 0.0:
		transition_to(&"LedgeClimb", ledge)
		return true
	return false
