extends "res://tests/test_base.gd"
## Headless movement regression tests.
##
## Builds a small arena in code, drives the player with scripted input and
## checks that every move does what it should: heights, distances and the
## states it passes through. Expectations are read from the player's
## MovementSettings, so the tests keep passing while you tune the numbers.
##
## Run from the project folder:
##   godot --headless --fixed-fps 120 -s res://tests/movement_tests.gd
## The exit code is the number of failed checks.

var elevator: MovingPlatform
var shuttle: MovingPlatform


func get_tests() -> Array[Callable]:
	return [
		test_settle_on_ground,
		test_run_speed,
		test_single_jump_height,
		test_short_hop,
		test_triple_jump_chain,
		test_chain_needs_timing,
		test_jump_buffer,
		test_coyote_time,
		test_long_jump,
		test_backflip,
		test_side_flip,
		test_dive_belly_slide_rollout,
		test_air_dive_boost,
		test_ground_pound_and_jump,
		test_ground_pound_dive,
		test_air_spin_once_per_jump,
		test_wall_kick_in_window,
		test_wall_kick_missed,
		test_wall_kick_early_press,
		test_wall_kick_too_early,
		test_wall_contact_needs_speed,
		test_wall_kick_shaft,
		test_ledge_hang_and_climb,
		test_ledge_jump,
		test_ledge_drop,
		test_ledge_mantle,
		test_bonk,
		test_stairs,
		test_walkable_ramp,
		test_steep_slope,
		test_elevator,
		test_shuttle_platform,
		test_long_jump_chain,
		test_steep_slope_jump,
		test_belly_slide_off_ledge_rollout,
		test_skid_punch,
		test_punch_combo,
		test_combo_restarts_after_a_pause,
		test_sprint_dives_instead,
		test_slide_kick,
		test_attacks_hit_targets,
		test_slow_motion_jump_height,
	]


# --- Arena ---------------------------------------------------------------------

func build_arena() -> void:
	box(Vector3(0, -0.5, 0), Vector3(400, 1, 400)) # Floor
	box(Vector3(30, 10, 0), Vector3(2, 20, 40)) # Wall, face at x = 29
	box(Vector3(-33, 10, 0), Vector3(1, 20, 10)) # Shaft: faces at x = -32.5 ...
	box(Vector3(-27.5, 10, 0), Vector3(1, 20, 10)) # ... and x = -28
	box(Vector3(0, 1.6, -40), Vector3(8, 3.2, 6)) # Ledge, top 3.2, face at z = -37
	box(Vector3(20, 1.25, -40), Vector3(8, 2.5, 6)) # Low ledge, top 2.5, face at z = -37
	box(Vector3(0, 1, 60), Vector3(10, 2, 10)) # Platform, top 2, edge at z = 55
	for i in 8: # Stairs rising toward -Z, 0.25 m steps
		var step_height := (i + 1) * 0.25
		box(Vector3(60, step_height / 2.0, -10.25 - i * 0.5), Vector3(4, step_height, 0.5))
	box(Vector3(60, 1.0, -16.0 - 1.0), Vector3(4, 2.0, 2.0)) # Landing at the top of the stairs
	box(Vector3(80, 2, 40), Vector3(6, 0.5, 14), Vector3(-25, 0, 0)) # 25 degree ramp rising toward +Z
	box(Vector3(-60, 3, -40), Vector3(10, 0.5, 12), Vector3(60, 0, 0)) # 60 degree slope, downhill toward +Z
	elevator = _platform(Vector3(-100, 0.25, -100), Vector3(0, 5, 0)) # Rises 5 m
	shuttle = _platform(Vector3(-100, 0.25, -60), Vector3(8, 0, 0)) # Slides 8 m along +X


## A 4 x 4 m platform that waits 0.5 s, travels [param travel] in 1 s, and waits again.
func _platform(position: Vector3, travel: Vector3) -> MovingPlatform:
	var platform := MovingPlatform.new()
	platform.size = Vector3(4, 0.5, 4)
	platform.travel = travel
	platform.travel_time = 1.0
	platform.pause_time = 0.5
	platform.position = position
	root.add_child(platform)
	return platform


# --- Tests -----------------------------------------------------------------------

func test_settle_on_ground() -> void:
	await place(Vector3(0, 1, 0))
	await seconds(0.3)
	check(player.is_on_floor(), "on floor after dropping")
	check(player.state_name == &"Idle", "idle")
	check_near(player.global_position.y, 0.0, 0.02, "resting height")


func test_run_speed() -> void:
	await place(Vector3(100, 0, 100))
	player.input.move = Vector3.FORWARD
	await seconds(1.0)
	check(player.state_name == &"Run", "running")
	check_near(player.horizontal_speed(), s.run_speed, 0.1, "top speed")
	player.input.move = Vector3.ZERO
	await seconds(0.5)
	check(player.state_name == &"Idle", "stops to idle")


func test_single_jump_height() -> void:
	await place(Vector3(100, 0, 100))
	player.input.press(&"jump")
	var flight := await fly()
	player.input.release(&"jump")
	report("single jump height", flight.height)
	check(history.has(&"Jump"), "jumped")
	check_near(flight.height, s.single_jump_height, s.single_jump_height * 0.03, "single jump apex")


func test_short_hop() -> void:
	await place(Vector3(100, 0, 100))
	await tap(&"jump")
	var flight := await fly()
	report("short hop height", flight.height)
	check(flight.height < s.single_jump_height * 0.6, "releasing early cuts the jump")


func test_triple_jump_chain() -> void:
	await place(Vector3(-100, 0, 150))
	player.input.move = Vector3.FORWARD
	await seconds(1.0)
	var heights: Array[float] = []
	var chains: Array[int] = []
	for i in 3:
		var takeoff := player.global_position
		player.input.press(&"jump")
		await frames(1)
		chains.append(player.jump_chain)
		var flight := await fly(4.0, takeoff)
		heights.append(flight.height)
		player.input.release(&"jump")
		await frames(1)
	report("chain heights", heights[0])
	report("", heights[1])
	report("", heights[2])
	check(chains == [1, 2, 3], "chain progresses 1-2-3 (got %s)" % [chains])
	check_near(heights[0], s.single_jump_height, s.single_jump_height * 0.04, "first jump")
	check_near(heights[1], s.double_jump_height, s.double_jump_height * 0.04, "second jump")
	check_near(heights[2], s.triple_jump_height, s.triple_jump_height * 0.04, "third jump")


func test_chain_needs_timing() -> void:
	await place(Vector3(-100, 0, 150))
	player.input.move = Vector3.FORWARD
	await seconds(1.0)
	player.input.press(&"jump")
	await fly()
	player.input.release(&"jump")
	await seconds(s.jump_chain_window + 0.15)
	player.input.press(&"jump")
	await frames(1)
	check(player.jump_chain == 1, "a late jump restarts the chain")
	await fly()
	player.input.release(&"jump")


func test_jump_buffer() -> void:
	await place(Vector3(100, 0, 100))
	player.input.press(&"jump")
	await frames(2)
	player.input.release(&"jump")
	# Press again shortly before touching down; the jump should still happen on landing.
	await wait_for(func() -> bool: return player.velocity.y < 0.0 and player.height_above_ground() < 0.4)
	await tap(&"jump")
	check(not grounded(), "pressed while still airborne")
	var jumped_again := await wait_for(func() -> bool: return player.velocity.y > 1.0, 0.4)
	check(jumped_again, "buffered jump fires on landing")


func test_coyote_time() -> void:
	await place(Vector3(0, 2.2, 58))
	player.input.move = Vector3.FORWARD
	check(await wait_for_state(&"Fall", 2.0), "ran off the platform")
	await seconds(s.coyote_time * 0.5)
	await tap(&"jump")
	check(player.state_name == &"Jump", "late jump still works")
	player.input.move = Vector3.ZERO
	await fly()


func test_long_jump() -> void:
	await place(Vector3(-150, 0, 150))
	player.input.move = Vector3.FORWARD
	await seconds(1.0)
	player.input.press(&"crouch")
	await frames(1)
	check(player.state_name == &"CrouchSlide", "crouching at speed slides")
	await tap(&"jump")
	check(player.state_name == &"LongJump", "long jump")
	var launch_speed := player.horizontal_speed()
	player.input.release(&"crouch")
	var flight := await fly()
	report("long jump speed", launch_speed, "m/s")
	report("long jump distance", flight.distance)
	report("long jump height", flight.height)
	check_near(launch_speed, minf(s.run_speed * s.long_jump_speed_multiplier, s.long_jump_max_speed), 0.8, "takeoff speed")
	check(flight.distance > 8.0, "long jump covers distance")
	check(flight.height < s.single_jump_height, "long jump stays low")
	player.input.move = Vector3.ZERO


func test_backflip() -> void:
	await place(Vector3(100, 0, 100))
	player.input.press(&"crouch")
	await frames(3)
	check(player.state_name == &"Crouch", "crouching")
	var takeoff := player.global_position
	player.input.press(&"jump")
	await frames(1)
	check(player.state_name == &"Backflip", "backflip")
	player.input.release(&"crouch")
	var flight := await fly(4.0, takeoff)
	player.input.release(&"jump")
	report("backflip height", flight.height)
	check_near(flight.height, s.backflip_height, s.backflip_height * 0.04, "backflip apex")
	check((flight.offset as Vector3).z > 1.0, "flips backwards")


func test_side_flip() -> void:
	await place(Vector3(-100, 0, 100))
	player.input.move = Vector3.FORWARD
	await seconds(1.0)
	player.input.move = Vector3.BACK
	await frames(1)
	check(player.state_name == &"Skid", "reversing at speed skids")
	var takeoff := player.global_position
	player.input.press(&"jump")
	await frames(1)
	check(player.state_name == &"SideFlip", "side flip")
	check(player.velocity.z > 1.0, "side flip heads the new way")
	var flight := await fly(4.0, takeoff)
	player.input.release(&"jump")
	player.input.move = Vector3.ZERO
	report("side flip height", flight.height)
	check_near(flight.height, s.side_flip_height, s.side_flip_height * 0.04, "side flip apex")


func test_dive_belly_slide_rollout() -> void:
	await place(Vector3(150, 0, -100))
	player.input.move = Vector3.FORWARD
	await seconds(0.6)
	await tap(&"attack")
	check(player.state_name == &"Dive", "ground dive")
	check(player.horizontal_speed() >= s.dive_min_speed - 0.01, "dive boosts speed")
	check(await wait_for_state(&"BellySlide", 2.0), "dive lands in a belly slide")
	await frames(10)
	await tap(&"jump")
	check(player.state_name == &"Rollout", "rollout")
	await fly()
	player.input.move = Vector3.ZERO
	await seconds(0.5)
	check(player.state_name in [&"Idle", &"Run"], "back on your feet")


func test_air_dive_boost() -> void:
	await place(Vector3(150, 0, -100))
	player.input.move = Vector3.FORWARD
	await seconds(0.5)
	player.input.press(&"jump")
	await seconds(0.15)
	var before := player.horizontal_speed()
	await tap(&"attack")
	player.input.release(&"jump")
	check(player.state_name == &"Dive", "air dive")
	check(player.horizontal_speed() > before + 0.5, "air dive adds speed")
	await wait_for_state(&"BellySlide", 2.0)
	player.input.move = Vector3.ZERO
	await seconds(1.0)


func test_ground_pound_and_jump() -> void:
	await place(Vector3(100, 0, -100))
	player.input.press(&"jump")
	await seconds(0.3)
	player.input.release(&"jump")
	await tap(&"crouch")
	check(player.state_name == &"GroundPound", "ground pound")
	var hover_y := player.global_position.y
	await seconds(s.ground_pound_hang_time * 0.8)
	check_near(player.global_position.y, hover_y, 0.01, "hangs in the air first")
	check(await wait_for_state(&"GroundPoundLand", 2.0), "lands with an impact")
	var takeoff := player.global_position
	player.input.press(&"jump")
	await frames(1)
	check(player.state_name == &"GroundPoundJump", "ground pound jump")
	var flight := await fly(4.0, takeoff)
	player.input.release(&"jump")
	report("ground pound jump height", flight.height)
	check_near(flight.height, s.ground_pound_jump_height, s.ground_pound_jump_height * 0.04, "ground pound jump apex")


func test_ground_pound_dive() -> void:
	await place(Vector3(100, 0, -100))
	player.input.press(&"jump")
	await seconds(0.3)
	player.input.release(&"jump")
	await tap(&"crouch")
	await seconds(0.12)
	player.input.move = Vector3.LEFT
	await tap(&"attack")
	check(player.state_name == &"Dive", "dive out of a ground pound")
	check(player.velocity.x < -s.dive_min_speed + 0.1, "dives toward the stick")
	player.input.move = Vector3.ZERO
	await wait_for_state(&"BellySlide", 2.0)
	await seconds(1.0)


func test_air_spin_once_per_jump() -> void:
	await place(Vector3(100, 0, 100))
	player.input.press(&"jump")
	await frames(2)
	player.input.release(&"jump")
	await wait_for(func() -> bool: return player.velocity.y < -1.0)
	await tap(&"spin")
	check(player.state_name == &"Spin", "air spin")
	check(player.velocity.y > 0.0, "spin gives lift")
	await seconds(s.spin_duration + 0.05)
	await tap(&"spin")
	check(player.state_name != &"Spin", "only one spin per jump")
	await fly()


## Runs at the big wall (face at x = 29) and jumps into it. Returns whether
## the wall was hit hard enough to open a wall kick window.
func jump_into_wall() -> bool:
	await run_and_jump_at_wall()
	var hit := await wait_for_state(&"WallContact", 1.5)
	player.input.release(&"jump")
	return hit


## Starts a running jump toward the big wall, holding jump for full height.
func run_and_jump_at_wall() -> void:
	await place(Vector3(24, 0, 0), Vector3.RIGHT)
	player.input.move = Vector3.RIGHT
	await seconds(0.2)
	player.input.press(&"jump")


## Seconds until the player, flying toward the big wall, touches it.
func time_to_wall() -> float:
	var gap := 29.0 - player.radius - player.global_position.x
	return gap / maxf(player.velocity.x, 0.01)


func test_wall_kick_in_window() -> void:
	check(await jump_into_wall(), "hits the wall")
	check(player.facing.dot(Vector3.RIGHT) > 0.9, "faces the wall on contact")
	await seconds(s.wall_kick_window * 0.5)
	await tap(&"jump")
	check(player.state_name == &"WallKick", "a well-timed jump kicks off")
	check(player.velocity.x < -s.wall_kick_speed * 0.8, "kicks away from the wall")
	check(player.velocity.y > 5.0, "kicks upward")
	player.input.move = Vector3.ZERO
	await wait_for(grounded, 3.0)


func test_wall_kick_missed() -> void:
	check(await jump_into_wall(), "hits the wall")
	await seconds(s.wall_kick_window + 0.05)
	check(player.state_name == &"Fall", "bounces off once the window closes")
	check(player.velocity.x < 0.0, "bounced back off the wall")
	await tap(&"jump")
	check(player.state_name != &"WallKick", "too late to kick")
	# Still holding into the wall: no second chance on it before landing.
	var retried := await wait_for_state(&"WallContact", 1.0)
	check(not retried, "no retry on the same wall until landing")
	player.input.move = Vector3.ZERO
	await wait_for(grounded, 3.0)


func test_wall_kick_early_press() -> void:
	await run_and_jump_at_wall()
	await wait_for(func() -> bool: return time_to_wall() < s.wall_kick_early_window * 0.5, 1.5)
	await tap(&"jump")
	check(await wait_for_state(&"WallKick", 0.3), "a press just before the hit still kicks")
	player.input.move = Vector3.ZERO
	await wait_for(grounded, 3.0)


func test_wall_kick_too_early() -> void:
	await run_and_jump_at_wall()
	await wait_for(func() -> bool: return time_to_wall() < s.wall_kick_early_window + 0.1, 1.5)
	await tap(&"jump")
	check(await wait_for_state(&"WallContact", 0.5), "hits the wall")
	await seconds(s.wall_kick_window + 0.05)
	check(not history.has(&"WallKick"), "a press well before the hit doesn't count")
	player.input.move = Vector3.ZERO
	await wait_for(grounded, 3.0)


func test_wall_contact_needs_speed() -> void:
	await place(Vector3(27.9, 0, 0), Vector3.RIGHT)
	player.input.press(&"jump")
	await seconds(0.15)
	# Drift gently into the wall instead of hitting it.
	player.input.move = Vector3.RIGHT * 0.3
	await seconds(0.6)
	player.input.release(&"jump")
	await wait_for(grounded, 2.0)
	check(not history.has(&"WallContact"), "a gentle bump isn't a wall hit")
	player.input.move = Vector3.ZERO


func test_wall_kick_shaft() -> void:
	await place(Vector3(-30.25, 0, 0), Vector3.LEFT)
	var direction := Vector3.LEFT
	player.input.move = direction
	player.input.press(&"jump")
	var kicks := 0
	var peak := 0.0
	for i in 6:
		if not await wait_for_state(&"WallContact", 1.5):
			break
		player.input.release(&"jump")
		await frames(3)
		direction = -direction
		player.input.move = direction
		await tap(&"jump")
		if player.state_name == &"WallKick":
			kicks += 1
		peak = maxf(peak, player.global_position.y)
	await seconds(0.5)
	peak = maxf(peak, player.global_position.y)
	report("wall kicks", kicks, "")
	report("shaft height reached", peak)
	check(kicks == 6, "well-timed kicks climb back and forth up the shaft")
	check(peak > 10.0, "climbs the shaft")
	player.input.move = Vector3.ZERO
	await wait_for(grounded, 5.0)


func test_ledge_hang_and_climb() -> void:
	await place(Vector3(0, 0, -35.5))
	player.input.move = Vector3.FORWARD
	player.input.press(&"jump")
	check(await wait_for_state(&"LedgeHang", 1.5), "grabs the ledge")
	player.input.release(&"jump")
	await seconds(0.1)
	check_near(player.global_position.y, 3.2 - s.ledge_hang_depth, 0.05, "hangs below the top")
	await seconds(s.ledge_input_delay)
	check(await wait_for_state(&"LedgeClimb", 0.5), "pushing forward climbs")
	check(await wait_for(func() -> bool: return player.state_name in [&"Idle", &"Run"], 1.0), "stands on top")
	check_near(player.global_position.y, 3.2, 0.06, "on the ledge")
	check(player.global_position.z < -37.2, "moved onto the ledge")
	player.input.move = Vector3.ZERO


func test_ledge_jump() -> void:
	await place(Vector3(0, 0, -35.5))
	player.input.move = Vector3.FORWARD
	player.input.press(&"jump")
	await wait_for_state(&"LedgeHang", 1.5)
	player.input.release(&"jump")
	player.input.move = Vector3.ZERO
	await seconds(s.ledge_input_delay + 0.05)
	await tap(&"jump")
	check(player.state_name == &"LedgeJump", "ledge jump")
	await fly()
	check(player.global_position.y > 3.1, "lands on top")


func test_ledge_drop() -> void:
	await place(Vector3(0, 0, -35.5))
	player.input.move = Vector3.FORWARD
	player.input.press(&"jump")
	await wait_for_state(&"LedgeHang", 1.5)
	player.input.release(&"jump")
	player.input.move = Vector3.ZERO
	await seconds(s.ledge_input_delay + 0.05)
	await tap(&"crouch")
	check(player.state_name == &"Fall", "lets go")
	check(await wait_for(grounded, 2.0), "drops to the ground")
	check(player.global_position.y < 0.1, "back on the ground")


func test_ledge_mantle() -> void:
	await place(Vector3(20, 0, -35.5))
	player.input.move = Vector3.FORWARD
	player.input.press(&"jump")
	check(await wait_for_state(&"LedgeClimb", 1.5), "mantles a ledge just out of reach")
	player.input.release(&"jump")
	await wait_for(func() -> bool: return player.state_name in [&"Idle", &"Run"], 1.0)
	check_near(player.global_position.y, 2.5, 0.06, "on top")
	player.input.move = Vector3.ZERO


func test_bonk() -> void:
	await place(Vector3(23, 0, 5), Vector3.RIGHT)
	player.input.move = Vector3.RIGHT
	await seconds(0.3)
	player.input.press(&"jump")
	await seconds(0.1)
	player.input.release(&"jump")
	await tap(&"attack")
	check(await wait_for_state(&"Bonk", 1.0), "diving into a wall bonks")
	player.input.move = Vector3.ZERO
	check(player.velocity.x < 0.0, "knocked back")
	check(await wait_for(func() -> bool: return player.state_name == &"Idle", 2.0), "recovers")


func test_stairs() -> void:
	await place(Vector3(60, 0, -8))
	player.input.move = Vector3.FORWARD
	await wait_for(func() -> bool: return player.global_position.z < -16.5, 3.0)
	report("stairs height", player.global_position.y)
	check(player.global_position.y > 1.95, "walked up the stairs")
	check(steps >= 7, "each step is reported for smoothing (got %d)" % steps)
	check(not history.has(&"WallContact"), "never got stuck")
	player.input.move = Vector3.ZERO


func test_walkable_ramp() -> void:
	await place(Vector3(80, 0, 30), Vector3.BACK)
	player.input.move = Vector3.BACK
	await wait_for(func() -> bool: return player.global_position.z > 42.0, 3.0)
	report("ramp height", player.global_position.y)
	check(player.global_position.y > 3.0, "ran up the ramp")
	check(steps == 0, "slopes aren't mistaken for steps (got %d)" % steps)
	check(player.state_name == &"Run", "still running")
	player.input.move = Vector3.ZERO
	await wait_for(grounded, 3.0)


func test_steep_slope() -> void:
	await place(Vector3(-60, 8, -41))
	check(await wait_for_state(&"SteepSlide", 2.0), "slides on a steep slope")
	check(await wait_for(func() -> bool: return player.state_name in [&"Idle", &"Run"], 4.0), "slides off onto the floor")


func test_elevator() -> void:
	elevator.restart()
	await place(Vector3(-100, 0.6, -100))
	await seconds(1.6)
	check(player.is_on_floor(), "still standing on the elevator")
	check_near(player.global_position.y, 5.5, 0.1, "rides the elevator up")
	check(steps == 0, "elevators aren't mistaken for steps (got %d)" % steps)


func test_shuttle_platform() -> void:
	shuttle.restart()
	await place(Vector3(-100, 0.6, -60))
	var start_x := player.global_position.x
	await seconds(1.6)
	check(player.is_on_floor(), "still standing on the shuttle")
	check_near(player.global_position.x - start_x, 8.0, 0.25, "carried along by the shuttle")


func test_long_jump_chain() -> void:
	await place(Vector3(-150, 0, 150))
	player.input.move = Vector3.FORWARD
	await seconds(1.0)
	player.input.press(&"crouch")
	await frames(1)
	await tap(&"jump")
	# Keep crouch held through the landing: it slides straight into another long jump.
	check(await wait_for_state(&"CrouchSlide", 2.0), "lands back in a crouch slide")
	await tap(&"jump")
	check(player.state_name == &"LongJump", "second long jump")
	check(history.count(&"LongJump") == 2, "two long jumps in a row")
	player.input.release(&"crouch")
	player.input.move = Vector3.ZERO
	await fly()


func test_steep_slope_jump() -> void:
	await place(Vector3(-60, 8, -41))
	check(await wait_for_state(&"SteepSlide", 2.0), "sliding")
	await tap(&"jump")
	check(player.state_name == &"Jump", "jumps off the slope")
	check(player.velocity.z > 1.0 and player.velocity.y > 1.0, "hops up and away from the slope")
	await wait_for(grounded, 3.0)


func test_belly_slide_off_ledge_rollout() -> void:
	await place(Vector3(0, 2.2, 64.5))
	player.input.move = Vector3.FORWARD
	await seconds(0.3)
	await tap(&"attack")
	player.input.move = Vector3.ZERO
	check(await wait_for_state(&"BellySlide", 1.5), "belly slide on the platform")
	check(await wait_for_state(&"Dive", 2.0), "slides off the edge")
	await tap(&"jump")
	check(player.state_name == &"Rollout", "a late jump still rolls out")
	await wait_for(grounded, 3.0)


func test_skid_punch() -> void:
	await place(Vector3(-100, 0, 100))
	player.input.move = Vector3.FORWARD
	await seconds(1.0)
	player.input.move = Vector3.BACK
	await frames(1)
	check(player.state_name == &"Skid", "skidding")
	await tap(&"attack")
	check(player.state_name == &"Punch", "punches out of the skid")
	check(player.facing.dot(Vector3.BACK) > 0.9, "punches the new way")
	player.input.move = Vector3.ZERO
	await seconds(0.8)


func test_slow_motion_jump_height() -> void:
	await place(Vector3(100, 0, 100))
	Engine.time_scale = 0.25
	player.input.press(&"jump")
	var flight := await fly(8.0)
	player.input.release(&"jump")
	Engine.time_scale = 1.0
	report("single jump height at 0.25x", flight.height)
	check_near(flight.height, s.single_jump_height, s.single_jump_height * 0.02, "slow motion doesn't change jump height")


# --- Attacks -----------------------------------------------------------------------

func test_punch_combo() -> void:
	await place(Vector3(100, 0, -60))
	var combo: Array[int] = []
	for i in 3:
		await tap(&"attack")
		await wait_for(func() -> bool: return player.state_name == &"Punch" and player.state_machine.current.get(&"combo") == i + 1, 0.5)
		combo.append(player.state_machine.current.get(&"combo"))
		await seconds(s.combo_min_time)
	check(combo == [1, 2, 3], "punch, punch, kick (got %s)" % [combo])
	check(await wait_for_state(&"Idle", 1.0), "back to standing after the kick")
	check(player.horizontal_speed() < 0.1, "punches don't keep you sliding")


func test_combo_restarts_after_a_pause() -> void:
	await place(Vector3(100, 0, -60))
	await tap(&"attack")
	await wait_for_state(&"Idle", 1.0)
	await seconds(0.4)
	await tap(&"attack")
	check(player.state_name == &"Punch" and player.state_machine.current.get(&"combo") == 1, "starts over with the first punch")
	await wait_for_state(&"Idle", 1.0)


func test_sprint_dives_instead() -> void:
	await place(Vector3(100, 0, -60))
	player.input.move = Vector3.FORWARD * 0.5
	await seconds(0.5)
	await tap(&"attack")
	check(player.state_name == &"Punch", "a punch while walking")
	player.input.move = Vector3.FORWARD
	await wait_for(func() -> bool: return player.state_name == &"Run" and player.horizontal_speed() >= s.ground_dive_min_speed, 2.0)
	await tap(&"attack")
	check(player.state_name == &"Dive", "a dive when running flat out")
	player.input.move = Vector3.ZERO
	await wait_for_state(&"BellySlide", 2.0)
	await seconds(1.0)


func test_slide_kick() -> void:
	await place(Vector3(100, 0, -60))
	player.input.move = Vector3.FORWARD
	await seconds(0.5)
	player.input.press(&"crouch")
	await frames(2)
	check(player.state_name == &"CrouchSlide", "crouch sliding")
	await tap(&"attack")
	check(player.state_name == &"SlideKick", "slide kick")
	check(player.horizontal_speed() >= s.slide_kick_speed - 0.01, "bursts forward")
	check(await wait_for_state(&"CrouchSlide", 1.5), "lands back in a slide (crouch held)")
	player.input.release(&"crouch")
	player.input.move = Vector3.ZERO
	await seconds(1.0)


## A box on the Hittable layer that counts how often it gets hit.
func _target(position: Vector3) -> StaticBody3D:
	var script := GDScript.new()
	script.source_code = "extends StaticBody3D\nvar hits: Array[StringName] = []\nfunc take_hit(hit: Dictionary) -> void:\n\thits.append(hit.kind)\n"
	script.reload()
	var target := StaticBody3D.new()
	target.set_script(script)
	target.collision_layer = Player.HITTABLE_LAYER
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.6, 0.6, 0.6)
	shape.shape = box_shape
	target.add_child(shape)
	target.position = position
	root.add_child(target)
	return target


func test_attacks_hit_targets() -> void:
	await place(Vector3(100, 0, -40))
	var target := _target(Vector3(100, 0.9, -41.1))
	await frames(2)
	for i in 3:
		await tap(&"attack")
		await seconds(s.combo_min_time + 0.02)
	await wait_for_state(&"Idle", 1.0)
	var hits: Array = target.get(&"hits")
	check(hits == [&"punch_1", &"punch_2", &"kick"], "each hit of the combo connects once (got %s)" % [hits])
	target.free()
	# Ground pound onto something breakable from above.
	var below := _target(Vector3(100, 3.0, -30))
	await place(Vector3(100, 5.0, -30))
	await tap(&"crouch")
	check(await wait_for(func() -> bool: return (below.get(&"hits") as Array).has(&"ground_pound"), 2.0), "a ground pound smashes what's below")
	below.free()
	await wait_for(grounded, 2.0)
