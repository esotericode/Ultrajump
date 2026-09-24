extends "res://tests/test_base.gd"
## Plays through every challenge in the movement gym and collects its star.
##
## Runs in the real level, driving the player the way a person would: runs,
## jumps, timed wall kicks, and steering toward each landing. If you retune
## the movement (or edit the level) and a challenge stops being possible,
## the matching test fails.
##
## Run from the project folder:
##   godot --headless --fixed-fps 120 -s res://tests/gym_tests.gd
## The exit code is the number of failed checks.
##
## Stepping the whole level as fast as the CPU allows sometimes makes Jolt
## print "job system exceeded the maximum number of jobs". It waits for a free
## job and carries on; the results aren't affected.

var level: Node3D
var game_state: Node


func build_arena() -> void:
	game_state = root.get_node(^"GameState")
	level = (load("res://levels/movement_gym.tscn") as PackedScene).instantiate()
	root.add_child(level)


func get_tests() -> Array[Callable]:
	return [
		test_long_jump_leap,
		test_wall_kick_shaft,
		test_tower_top,
		test_crate_smasher,
		test_parkour_time_trial,
		test_wall_kick_chimney,
		test_pillar_hop,
		test_sky_islands,
		test_backflip_cliffs,
		test_every_star_was_collected,
	]


# --- Driving helpers -------------------------------------------------------------

## Points the stick toward [param target] (x/z), easing off as it gets close,
## like a player lining up a landing.
func steer(target: Vector3) -> void:
	var offset := (target - player.global_position) * Vector3(1, 0, 1)
	player.input.move = (offset * 2.5 / s.air_max_speed).limit_length(1.0)


## Steers toward [param target] until the player lands (climbing up if it
## catches the ledge).
func steer_to_landing(target: Vector3, timeout := 4.0) -> void:
	await frames(3)
	await wait_for(func() -> bool:
		steer(target)
		return player.is_on_floor() or player.state_name == &"LedgeHang", timeout)
	if player.state_name == &"LedgeHang":
		await seconds(s.ledge_input_delay + 0.05)
		await wait_for(func() -> bool:
			steer(target)
			return player.state_name in [&"Idle", &"Run"], 1.5)
	player.input.move = Vector3.ZERO


## Walks until within [param distance] (horizontally) of [param target].
func walk_to(target: Vector3, distance := 0.2) -> bool:
	var reached := await wait_for(func() -> bool:
		steer(target)
		return (target - player.global_position).slide(Vector3.UP).length() < distance, 4.0)
	player.input.move = Vector3.ZERO
	return reached


## Turns around on the spot to face [param direction].
func turn_to(direction: Vector3) -> void:
	player.input.move = direction * 0.2
	await wait_for(func() -> bool: return player.facing.dot(direction) > 0.99, 0.5)
	player.input.move = Vector3.ZERO
	await wait_for(func() -> bool: return player.state_name == &"Idle", 0.5)


## Jumps from where the player stands and steers onto [param target].
func hop_to(target: Vector3) -> bool:
	player.input.move = ((target - player.global_position) * Vector3(1, 0, 1)).normalized()
	await frames(2)
	player.input.press(&"jump")
	await steer_to_landing(target)
	player.input.release(&"jump")
	await frames(10)
	return is_standing_at(target.y)


## Runs toward +x and long jumps once past [param takeoff_x].
func long_jump_east(takeoff_x: float) -> Dictionary:
	player.input.move = Vector3.RIGHT
	await wait_for(func() -> bool: return player.global_position.x > takeoff_x, 3.0)
	player.input.press(&"crouch")
	await frames(1)
	player.input.press(&"jump")
	await frames(2)
	player.input.release(&"crouch")
	player.input.release(&"jump")
	var flight := await fly(3.0)
	player.input.move = Vector3.ZERO
	await wait_for(func() -> bool: return player.state_name in [&"Idle", &"Run", &"Crouch"], 2.0)
	return flight


## Wall kicks back and forth between two walls, starting with a jump toward
## [param direction], until a kick is heading along [param exit] above
## [param exit_height] (or the player catches a ledge). Returns the kick count.
func wall_kick_up(direction: Vector3, exit: Vector3, exit_height: float) -> int:
	var kicks := 0
	player.input.move = direction
	player.input.press(&"jump")
	for i in 16:
		if not await wait_for(func() -> bool: return player.state_name in [&"WallContact", &"LedgeHang"], 1.5):
			break
		if player.state_name == &"LedgeHang":
			break
		# Jump right as you hit the wall, pushing away from it.
		player.input.release(&"jump")
		await frames(3)
		direction = -direction
		player.input.move = direction
		await tap(&"jump")
		if player.state_name == &"WallKick":
			kicks += 1
		if player.global_position.y > exit_height and (exit.dot(direction) > 0.5 or absf(exit.dot(direction)) < 0.1):
			break
	player.input.release(&"jump")
	return kicks


## Walks into the star named [param star_name], jumping if it floats out of reach.
func collect_star(star_name: String) -> bool:
	var star := level.find_child("Star_" + star_name.validate_node_name(), true, false) as Node3D
	if star == null:
		return false
	var target := star.global_position
	var collected := func() -> bool: return game_state.call(&"has_star", star_name)
	await wait_for(func() -> bool:
		steer(target)
		return collected.call() or (target - player.global_position).slide(Vector3.UP).length() < 0.3, 4.0)
	if not collected.call():
		player.input.press(&"jump")
		await wait_for(func() -> bool:
			steer(target)
			return collected.call(), 1.2)
		player.input.release(&"jump")
	player.input.move = Vector3.ZERO
	return collected.call()


func is_standing_at(height: float) -> bool:
	return player.is_on_floor() and absf(player.global_position.y - height) < 0.1


func near(target: Vector3, radius: float) -> bool:
	return player.global_position.distance_to(target) < radius


# --- Challenges ------------------------------------------------------------------

## Four gaps (6, 8, 10 and 12 m) between 3 m high landings. The longer ones
## take speed built up by chaining long jumps: keep crouch held through each
## landing, slide to the edge, and jump again.
func test_long_jump_leap() -> void:
	# [takeoff edge x, far landing's near edge x]
	var gaps := [[42.0, 48.0], [54.0, 62.0], [68.0, 78.0], [84.0, 96.0]]
	await place(Vector3(30, 3, -34), Vector3.RIGHT)
	player.input.move = Vector3.RIGHT
	player.input.press(&"crouch")
	await wait_for(func() -> bool: return player.state_name == &"Crouch", 0.5)
	player.input.release(&"crouch")
	for gap in gaps:
		var edge: float = gap[0]
		await wait_for(func() -> bool: return player.global_position.x > edge - 0.6, 3.0)
		player.input.press(&"crouch")
		await frames(1)
		await tap(&"jump")
		var takeoff_speed := player.horizontal_speed()
		await frames(3)
		await wait_for(func() -> bool: return player.is_on_floor(), 3.0)
		var width := roundi(gap[1] - edge)
		report("%d m gap: long jump at" % width, takeoff_speed, "m/s")
		check(is_standing_at(3.0) and player.global_position.x > gap[1], "clears the %d m gap" % width)
	player.input.release(&"crouch")
	player.input.move = Vector3.ZERO
	await wait_for(func() -> bool: return player.state_name in [&"Idle", &"Crouch"], 2.0)
	check(await collect_star("Long jump leap"), "collects the long jump star")


## A 16 m shaft between two walls, onto the rooftop to the west.
func test_wall_kick_shaft() -> void:
	await place(Vector3(-22.25, 0, -12), Vector3.RIGHT)
	var kicks := await wall_kick_up(Vector3.RIGHT, Vector3.LEFT, 13.0)
	await steer_to_landing(Vector3(-28.5, 16, -12))
	report("wall kicks", kicks, "")
	check(is_standing_at(16.0), "wall kicks up onto the rooftop")
	check(await collect_star("Wall kick shaft"), "collects the shaft star")


## Eleven steps spiralling up a 20 m tower.
func test_tower_top() -> void:
	var center := Vector3(65, 0, 40)
	await place(center + Vector3(0, 0, -13), Vector3.FORWARD)
	var hops := 0
	for i in 11:
		var angle := deg_to_rad(200.0 + i * 38.0)
		var step := center + Vector3(cos(angle) * 8.0, 1.2 + i * 1.75, sin(angle) * 8.0)
		if i == 0:
			await walk_to(step, 3.0)
		if await hop_to(step):
			hops += 1
		else:
			print("    missed step %d (at %s, state %s)" % [i + 1, player.global_position, player.state_name])
			await place(step)
	report("steps reached", hops, "")
	check(hops == 11, "hops up every step")
	check(await hop_to(center + Vector3(0, 20, 1.5)), "jumps onto the top")
	check(await collect_star("Tower top"), "collects the tower star")


func test_crate_smasher() -> void:
	var group := level.find_child("Crates", true, false)
	for attempt in 10:
		var crates := group.get_children().filter(func(node: Node) -> bool: return node.has_method(&"take_hit") and not node.get(&"_broken"))
		if crates.is_empty():
			break
		# Punch the lowest crate left, from the west.
		crates.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.y < b.global_position.y)
		var crate: Node3D = crates[0]
		await place(Vector3(crate.global_position.x - 1.3, 0, crate.global_position.z), Vector3.RIGHT)
		await tap(&"attack")
		await seconds(0.6)
	check(group.get_children().all(func(node: Node) -> bool: return not node.has_method(&"take_hit") or node.get(&"_broken")), "breaks every crate")
	check(await collect_star("Crate smasher"), "collects the star that appears")


## The whole course in one go, against the clock.
func test_parkour_time_trial() -> void:
	var z := 70.0
	await place(Vector3(21, 0, z), Vector3.RIGHT)
	player.input.move = Vector3.RIGHT
	check(await wait_for(func() -> bool: return game_state.get(&"time_trial_course") == "Parkour", 2.0), "the start gate starts the clock")
	# Up the three steps.
	for i in 3:
		var step := Vector3(30 + 4.5 * i, 1.5 * (i + 1), z)
		player.input.move = Vector3.RIGHT
		await wait_for(func() -> bool: return player.global_position.x > step.x - 3.4, 2.0)
		check(await hop_to(step), "hops onto step %d" % (i + 1))
	# Long jump from the runway to the chimney's landing.
	await long_jump_east(50.6)
	check(is_standing_at(4.5) and player.global_position.x > 59.0, "long jumps the 8 m gap")
	# Wall kick up the chimney and out east onto the lookout.
	player.input.move = Vector3.RIGHT
	await wait_for(func() -> bool: return player.global_position.x > 67.5, 2.0)
	await wall_kick_up(Vector3.BACK, Vector3.RIGHT, 9.0)
	await steer_to_landing(Vector3(73, 12, z))
	check(is_standing_at(12.0) and player.global_position.x > 70.0, "wall kicks up onto the lookout")
	# Drop down the steps.
	for drop in [Vector3(80.5, 9, z), Vector3(85.5, 6.5, z), Vector3(90.5, 4, z)]:
		player.input.move = Vector3.RIGHT
		await wait_for(func() -> bool: return not player.is_on_floor(), 2.0)
		await steer_to_landing(drop)
		check(is_standing_at(drop.y), "drops onto the %.1f m step" % drop.y)
	# Wait for the shuttle, ride it over the lava, and run for the line.
	var shuttle := level.get_node(^"Parkour").find_child("Shuttle", true, false) as Node3D
	await walk_to(Vector3(90.5, 4, z))
	await wait_for(func() -> bool: return shuttle.global_position.x < 93.6, 6.0)
	check(await walk_to(shuttle.global_position, 0.6), "steps onto the shuttle")
	await wait_for(func() -> bool: return shuttle.global_position.x > 100.4, 4.0)
	check(is_standing_at(4.0) and near(shuttle.global_position + Vector3.UP * 0.25, 1.6), "rides the shuttle across")
	player.input.move = Vector3.RIGHT
	check(await wait_for(func() -> bool: return game_state.get(&"time_trial_course") == "", 2.0), "crosses the finish line")
	player.input.move = Vector3.ZERO
	var time: float = (game_state.get(&"best_times") as Dictionary).get("Parkour", INF)
	report("course time", time, "s")
	check(time < 30.0, "beats the par time")
	check(await collect_star("Parkour under 30 s"), "collects the time trial star")


## A 22 m chimney, onto the platform to the west.
func test_wall_kick_chimney() -> void:
	await place(Vector3(-48, 0, -12), Vector3.RIGHT)
	var kicks := await wall_kick_up(Vector3.RIGHT, Vector3.LEFT, 19.0)
	await steer_to_landing(Vector3(-52.2, 22, -12))
	report("wall kicks", kicks, "")
	check(is_standing_at(22.0), "wall kicks up onto the top")
	check(await collect_star("Wall kick chimney"), "collects the chimney star")


## Eight pillars over lava, each hop taken from a standstill.
func test_pillar_hop() -> void:
	# [x, z, top]: the start block, the pillars, then the goal.
	var spots := [[-36.0, 30.0, 1.0], [-41.0, 30.0, 1.5], [-44.5, 32.5, 2.0], [-48.0, 30.0, 2.5], [-51.5, 27.0, 2.5],
		[-55.0, 29.0, 3.0], [-58.5, 32.0, 3.5], [-62.0, 30.0, 3.5], [-65.5, 27.5, 4.0], [-70.0, 28.5, 4.5]]
	await place(Vector3(spots[0][0], spots[0][2], spots[0][1]), Vector3.LEFT)
	var hops := 0
	for i in range(1, spots.size()):
		if await hop_to(Vector3(spots[i][0], spots[i][2], spots[i][1])):
			hops += 1
		else:
			break
	report("hops", hops, "")
	check(hops == spots.size() - 1, "hops every pillar to the goal")
	check(await collect_star("Pillar hop"), "collects the pillar star")


## Bounce pads up to a chain of floating islands.
func test_sky_islands() -> void:
	var z := -8.0
	await place(Vector3(32, 0, z), Vector3.RIGHT)
	player.input.move = Vector3.RIGHT
	check(await wait_for(func() -> bool: return player.state_name == &"Jump", 1.5), "the ground pad launches you")
	await steer_to_landing(Vector3(40.5, 7, z))
	check(is_standing_at(7.0), "lands on the first island")
	player.input.move = Vector3.RIGHT
	check(await wait_for(func() -> bool: return player.state_name == &"Jump", 1.5), "the island's pad launches you")
	await steer_to_landing(Vector3(47.5, 15, z))
	check(is_standing_at(15.0), "lands on the second island")
	var flight := await long_jump_east(51.0)
	report("long jump", flight.distance)
	check(is_standing_at(15.0) and player.global_position.x > 58.5, "long jumps to the last island")
	check(await collect_star("Sky islands"), "collects the sky star")


## Three 4.5 m cliffs, each climbed with a backflip from right against it.
func test_backflip_cliffs() -> void:
	for tier in 3:
		var face_z := -26.0 - 4.0 * tier
		var floor_y := 4.5 * tier
		if tier == 0:
			await place(Vector3(-3, 0, face_z + player.radius + 0.1), Vector3.BACK)
		else:
			# Walk to the next cliff, then turn your back to it.
			await walk_to(Vector3(-3, floor_y, face_z + player.radius + 0.1))
			await turn_to(Vector3.BACK)
		player.input.press(&"crouch")
		await frames(6)
		player.input.press(&"jump")
		await frames(2)
		player.input.release(&"crouch")
		await fly(3.0)
		player.input.release(&"jump")
		await frames(10)
		check(is_standing_at(floor_y + 4.5), "backflips up cliff %d" % (tier + 1))
	check(await collect_star("Backflip cliffs"), "collects the cliff star")


func test_every_star_was_collected() -> void:
	var total: int = game_state.get(&"star_total")
	var collected: int = (game_state.get(&"collected_stars") as Dictionary).size()
	print("    stars = %d / %d" % [collected, total])
	check(total == 9 and collected == total, "every star in the gym can be collected")
