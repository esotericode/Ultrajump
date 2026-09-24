extends SceneTree
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

const PLAYER_SCENE := preload("res://player/player.tscn")
const TICK := 1.0 / 120.0

var player: Player
var s: MovementSettings
var elevator: MovingPlatform
var shuttle: MovingPlatform
var history: Array[StringName] = []
var steps := 0
var checks := 0
var failures := 0
var _current_test := ""


func _initialize() -> void:
	Engine.physics_ticks_per_second = 120
	_build_arena()
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	player.input.scripted = true
	s = player.settings
	player.state_changed.connect(func(_from: StringName, to: StringName) -> void: history.append(to))
	player.stepped.connect(func(_height: float) -> void: steps += 1)
	_run_all.call_deferred()


func _run_all() -> void:
	var tests: Array[Callable] = [
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
		test_wall_slide_and_kick,
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
		test_wall_let_go,
		test_steep_slope_jump,
		test_belly_slide_off_ledge_rollout,
		test_skid_dive,
	]
	for test in tests:
		_current_test = test.get_method()
		var failures_before := failures
		await test.call()
		print("%s %s" % ["PASS" if failures == failures_before else "FAIL", _current_test])
	print("\n%d checks, %d failed" % [checks, failures])
	quit(failures)


# --- Arena ---------------------------------------------------------------------

func _build_arena() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(400, 1, 400)) # Floor
	_box(Vector3(30, 10, 0), Vector3(2, 20, 40)) # Wall, face at x = 29
	_box(Vector3(-33, 10, 0), Vector3(1, 20, 10)) # Shaft: faces at x = -32.5 ...
	_box(Vector3(-27.5, 10, 0), Vector3(1, 20, 10)) # ... and x = -28
	_box(Vector3(0, 1.6, -40), Vector3(8, 3.2, 6)) # Ledge, top 3.2, face at z = -37
	_box(Vector3(20, 1.25, -40), Vector3(8, 2.5, 6)) # Low ledge, top 2.5, face at z = -37
	_box(Vector3(0, 1, 60), Vector3(10, 2, 10)) # Platform, top 2, edge at z = 55
	for i in 8: # Stairs rising toward -Z, 0.25 m steps
		var step_height := (i + 1) * 0.25
		_box(Vector3(60, step_height / 2.0, -10.25 - i * 0.5), Vector3(4, step_height, 0.5))
	_box(Vector3(60, 1.0, -16.0 - 1.0), Vector3(4, 2.0, 2.0)) # Landing at the top of the stairs
	_box(Vector3(80, 2, 40), Vector3(6, 0.5, 14), Vector3(-25, 0, 0)) # 25 degree ramp rising toward +Z
	_box(Vector3(-60, 3, -40), Vector3(10, 0.5, 12), Vector3(60, 0, 0)) # 60 degree slope, downhill toward +Z
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


func _box(position: Vector3, size: Vector3, rotation_degrees := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = position
	body.rotation_degrees = rotation_degrees
	root.add_child(body)


# --- Helpers ---------------------------------------------------------------------

func frames(count: int) -> void:
	for i in count:
		await physics_frame


func seconds(time: float) -> void:
	await frames(roundi(time / TICK))


## Teleports the player, clears input and lets it settle on the ground.
func place(position: Vector3, facing := Vector3.FORWARD) -> void:
	player.input.clear()
	player.teleport(Transform3D(Basis.looking_at(facing), position))
	await frames(10)
	history.clear()
	steps = 0


func tap(action: StringName) -> void:
	player.input.press(action)
	await frames(1)
	player.input.release(action)


## Waits until [param condition] is true, for at most [param timeout] seconds.
func wait_for(condition: Callable, timeout := 3.0) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if condition.call():
			return true
		await frames(1)
		elapsed += TICK
	return condition.call()


func wait_for_state(state: StringName, timeout := 3.0) -> bool:
	return await wait_for(func() -> bool: return player.state_name == state, timeout)


func grounded() -> bool:
	return player.is_on_floor()


## Follows the player through the air until it lands. Returns the peak height
## gained, the horizontal distance covered and the displacement, measured from
## [param start] (defaults to where the player is now).
func fly(timeout := 4.0, start := Vector3.INF) -> Dictionary:
	if start == Vector3.INF:
		start = player.global_position
	var peak := start.y
	var elapsed := 0.0
	await frames(2)
	while elapsed < timeout:
		peak = maxf(peak, player.global_position.y)
		if player.is_on_floor() or player.state_name in [&"LedgeHang", &"WallSlide"]:
			break
		await frames(1)
		elapsed += TICK
	var offset := player.global_position - start
	return {
		"height": peak - start.y,
		"distance": Vector2(offset.x, offset.z).length(),
		"offset": offset,
		"time": elapsed,
	}


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("  FAILED [%s] %s (state %s, history %s)" % [_current_test, label, player.state_name, history])


func check_near(value: float, expected: float, tolerance: float, label: String) -> void:
	check(absf(value - expected) <= tolerance, "%s: got %.3f, expected %.3f ± %.3f" % [label, value, expected, tolerance])


func report(label: String, value: float, unit := "m") -> void:
	print("    %s = %.2f %s" % [label, value, unit])


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
	await tap(&"dive")
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
	await tap(&"dive")
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
	await tap(&"dive")
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


func test_wall_slide_and_kick() -> void:
	await place(Vector3(26, 0, 0), Vector3.RIGHT)
	player.input.move = Vector3.RIGHT
	player.input.press(&"jump")
	check(await wait_for_state(&"WallSlide", 1.5), "latches onto the wall")
	player.input.release(&"jump")
	check(player.facing.dot(Vector3.RIGHT) > 0.9, "faces the wall while sliding")
	await wait_for(func() -> bool: return player.velocity.y < 0.0, 1.0)
	await seconds(0.3)
	check(player.velocity.y >= -s.wall_slide_speed - 0.01, "slides slowly")
	await tap(&"jump")
	check(player.state_name == &"WallKick", "wall kick")
	check(player.velocity.x < -s.wall_kick_speed * 0.8, "kicks away from the wall")
	check(player.velocity.y > 5.0, "kicks upward")
	player.input.move = Vector3.ZERO
	await fly()


func test_wall_kick_shaft() -> void:
	await place(Vector3(-30.25, 0, 0), Vector3.LEFT)
	var direction := Vector3.LEFT
	player.input.move = direction
	player.input.press(&"jump")
	await wait_for_state(&"WallSlide", 1.5)
	player.input.release(&"jump")
	var kicks := 0
	var peak := 0.0
	for i in 6:
		if not await wait_for_state(&"WallSlide", 1.5):
			break
		await frames(2)
		direction = -direction
		player.input.move = direction
		await tap(&"jump")
		if player.state_name == &"WallKick":
			kicks += 1
		await seconds(0.25)
		peak = maxf(peak, player.global_position.y)
	await seconds(0.5)
	peak = maxf(peak, player.global_position.y)
	report("wall kicks", kicks, "")
	report("shaft height reached", peak)
	check(kicks == 6, "kicks back and forth up the shaft")
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
	await tap(&"dive")
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
	check(not history.has(&"WallSlide"), "never got stuck")
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


func test_wall_let_go() -> void:
	await place(Vector3(26, 0, 0), Vector3.RIGHT)
	player.input.move = Vector3.RIGHT
	player.input.press(&"jump")
	check(await wait_for_state(&"WallSlide", 1.5), "on the wall")
	player.input.release(&"jump")
	player.input.move = Vector3.LEFT
	check(await wait_for_state(&"Fall", 0.5), "holding away lets go")
	check(player.velocity.x < 0.0, "pushes off the wall")
	player.input.move = Vector3.ZERO
	await wait_for(grounded, 2.0)


func test_steep_slope_jump() -> void:
	await place(Vector3(-60, 8, -41))
	check(await wait_for_state(&"SteepSlide", 2.0), "sliding")
	await tap(&"jump")
	check(player.state_name == &"Jump", "jumps off the slope")
	check(player.velocity.z > 1.0 and player.velocity.y > 1.0, "hops up and away from the slope")
	await wait_for(grounded, 3.0)


func test_belly_slide_off_ledge_rollout() -> void:
	await place(Vector3(0, 2.2, 61))
	player.input.move = Vector3.FORWARD
	await seconds(0.1)
	await tap(&"dive")
	player.input.move = Vector3.ZERO
	check(await wait_for_state(&"BellySlide", 1.5), "belly slide on the platform")
	check(await wait_for_state(&"Dive", 2.0), "slides off the edge")
	await tap(&"jump")
	check(player.state_name == &"Rollout", "a late jump still rolls out")
	await wait_for(grounded, 3.0)


func test_skid_dive() -> void:
	await place(Vector3(-100, 0, 100))
	player.input.move = Vector3.FORWARD
	await seconds(1.0)
	player.input.move = Vector3.BACK
	await frames(1)
	check(player.state_name == &"Skid", "skidding")
	await tap(&"dive")
	check(player.state_name == &"Dive", "dives out of the skid")
	check(player.velocity.z > s.dive_min_speed - 0.1, "dives the new way")
	player.input.move = Vector3.ZERO
	await wait_for_state(&"BellySlide", 2.0)
	await seconds(1.0)
