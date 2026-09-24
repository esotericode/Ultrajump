extends "res://tests/test_base.gd"
## Headless tests for the level props: coins, stars, crates, bounce pads,
## hazards, checkpoints and time trials.
##
## Run from the project folder:
##   godot --headless --fixed-fps 120 -s res://tests/gameplay_tests.gd
## The exit code is the number of failed checks.
##
## Props are loaded at runtime (not preloaded): they use the GameState
## autoload, which isn't registered yet while this script is parsed.

var game_state: Node
var coin: Node3D
var star: Node3D
var crates: Array[Node3D] = []
var stack: Array[Node3D] = []
var group_star: Node3D
var pad: Node3D
var lava: Node3D
var checkpoint: Node3D
var start_gate: Node3D
var finish_gate: Node3D
var trial_star: Node3D


func get_tests() -> Array[Callable]:
	return [
		test_collect_coin,
		test_collect_star_once,
		test_crates_break_and_drop_coins,
		test_breaking_every_crate_reveals_the_star,
		test_stacked_crates_fall,
		test_bounce_pad,
		test_ground_pound_bounces_higher,
		test_checkpoint_and_lava,
		test_time_trial,
	]


func build_arena() -> void:
	game_state = root.get_node(^"GameState")
	box(Vector3(0, -0.5, 0), Vector3(400, 1, 400))
	coin = _prop("coin", Area3D.new(), Vector3(0, 0.8, -3))
	star = _prop("star", Area3D.new(), Vector3(20, 0.8, -3))
	star.set(&"star_name", "Test star")
	# Three crates in a group whose reward starts hidden.
	group_star = _prop("star", Area3D.new(), Vector3(40, 3, -10))
	group_star.set(&"star_name", "Crate star")
	group_star.set(&"hidden_until_revealed", true)
	var group := _prop("crate_group", Node3D.new(), Vector3.ZERO)
	group.set(&"reward", group_star)
	for i in 3:
		var crate := _prop("crate", StaticBody3D.new(), Vector3(40 + i * 3.0, 0.6, -3), group)
		crate.set(&"coins", 2 if i == 0 else 0)
		crates.append(crate)
	# Two crates side by side with one straddling them, and a plain stack of two.
	var pile := Node3D.new()
	root.add_child(pile)
	for spot in [Vector3(60, 0.6, -3), Vector3(61.2, 0.6, -3), Vector3(60.6, 1.8, -3), Vector3(64, 0.6, -3), Vector3(64, 1.8, -3)]:
		stack.append(_prop("crate", StaticBody3D.new(), spot, pile))
	pad = _prop("bounce_pad", StaticBody3D.new(), Vector3(-40, 0, -3))
	pad.set(&"height", 7.0)
	checkpoint = _prop("checkpoint", Area3D.new(), Vector3(-80, 0, 0))
	lava = _prop("hazard", Area3D.new(), Vector3(-80, -0.3, -8))
	lava.set(&"size", Vector3(6, 1, 4))
	start_gate = _prop("time_trial_gate", Area3D.new(), Vector3(80, 0, -3))
	finish_gate = _prop("time_trial_gate", Area3D.new(), Vector3(80, 0, -13))
	trial_star = _prop("star", Area3D.new(), Vector3(90, 3, -13))
	trial_star.set(&"star_name", "Trial star")
	trial_star.set(&"hidden_until_revealed", true)
	for gate: Node3D in [start_gate, finish_gate]:
		gate.set(&"course", "Test course")
	finish_gate.set(&"role", 1)
	finish_gate.set(&"par_time", 10.0)
	finish_gate.set(&"reward", trial_star)
	# Nobody else answers respawn requests here, so do what the main scene does.
	game_state.connect(&"respawn_requested", func() -> void: player.teleport(game_state.get(&"checkpoint")), CONNECT_DEFERRED)


func _prop(script_name: String, node: Node3D, position: Vector3, parent: Node = null) -> Node3D:
	node.set_script(load("res://levels/props/%s.gd" % script_name))
	node.position = position
	(parent if parent else root).add_child(node)
	return node


func coin_count() -> int:
	return game_state.get(&"coins")


func test_collect_coin() -> void:
	await place(Vector3(0, 0, 0))
	var before := coin_count()
	player.input.move = Vector3.FORWARD
	await seconds(0.6)
	player.input.move = Vector3.ZERO
	check(coin_count() == before + 1, "touching a coin collects it")
	check(not is_instance_valid(coin), "the coin is gone")


func test_collect_star_once() -> void:
	await place(Vector3(20, 0, 0))
	player.input.move = Vector3.FORWARD
	await seconds(0.6)
	player.input.move = Vector3.ZERO
	check(game_state.call(&"has_star", "Test star"), "touching a star collects it")
	check(not game_state.call(&"collect_star", "Test star"), "a star can't be collected twice")


func test_crates_break_and_drop_coins() -> void:
	await place(Vector3(40, 0, -1.4))
	var before := coin_count()
	await tap(&"attack")
	await seconds(0.3)
	check(not is_instance_valid(crates[0]), "a punch breaks the crate")
	var loose := root.find_children("*", "Area3D", true, false).filter(func(node: Node) -> bool: return node.get_script() == load("res://levels/props/coin.gd"))
	check(loose.size() == 2, "its coins pop out (found %d)" % loose.size())
	await seconds(0.6)
	# Walk around where they landed to pick them up (some may land on you).
	for spot in loose:
		if is_instance_valid(spot):
			player.teleport(Transform3D(Basis.IDENTITY, (spot as Node3D).global_position - Vector3.UP * 0.2))
			await frames(4)
	check(coin_count() == before + 2, "and can be collected")


func test_breaking_every_crate_reveals_the_star() -> void:
	check(not group_star.get(&"monitoring") or not group_star.get(&"_revealed"), "the reward starts hidden")
	for crate in crates:
		if is_instance_valid(crate):
			await place(crate.global_position + Vector3(0, -0.6, 1.4))
			await tap(&"attack")
			await seconds(0.3)
	await frames(2)
	check(group_star.get(&"_revealed"), "breaking every crate reveals the star")


func test_stacked_crates_fall() -> void:
	var hit := {"attacker": player, "kind": &"dive", "direction": Vector3.FORWARD, "position": Vector3.ZERO}
	stack[3].call(&"take_hit", hit)
	await seconds(0.5)
	check_near(stack[4].position.y, 0.6, 0.01, "a crate drops when the one under it breaks")
	stack[0].call(&"take_hit", hit)
	await seconds(0.5)
	check_near(stack[2].position.y, 1.8, 0.01, "a crate resting on two stays up while one is left")
	stack[1].call(&"take_hit", hit)
	await seconds(0.5)
	check_near(stack[2].position.y, 0.6, 0.01, "and drops once both are gone")


func test_bounce_pad() -> void:
	await place(Vector3(-40, 0, 1))
	player.input.move = Vector3.FORWARD
	check(await wait_for(func() -> bool: return player.state_name == &"Jump", 1.5), "stepping on the pad launches you")
	player.input.move = Vector3.ZERO
	var flight := await fly(4.0, Vector3(-40, 0.3, -3))
	report("bounce height", flight.height)
	check_near(flight.height, 7.0, 0.35, "reaches the pad's height")
	await wait_for(grounded, 3.0)


func test_ground_pound_bounces_higher() -> void:
	await place(Vector3(-40, 6, -3))
	await tap(&"crouch")
	check(await wait_for(func() -> bool: return player.state_name == &"Jump", 2.0), "a ground pound onto the pad launches you")
	var flight := await fly(5.0, Vector3(-40, 0.3, -3))
	report("ground pound bounce height", flight.height)
	check(flight.height > 7.0 * 1.3, "higher than a plain bounce")
	player.input.move = Vector3.LEFT
	await wait_for(grounded, 4.0)
	player.input.move = Vector3.ZERO


func test_checkpoint_and_lava() -> void:
	await place(Vector3(-80, 0, 3))
	player.input.move = Vector3.FORWARD
	await seconds(0.4)
	player.input.move = Vector3.ZERO
	var saved: Transform3D = game_state.get(&"checkpoint")
	check(saved.origin.distance_to(Vector3(-80, 0, 0)) < 0.1, "touching the checkpoint saves it")
	await place(Vector3(-80, 0, -8))
	await seconds(0.2)
	check(player.global_position.distance_to(Vector3(-80, 0, 0)) < 0.5, "lava sends you back to the checkpoint")


func test_time_trial() -> void:
	await place(Vector3(80, 0, 0))
	player.input.move = Vector3.FORWARD
	await seconds(0.5)
	check(game_state.get(&"time_trial_course") == "Test course", "the start gate starts the clock")
	await wait_for(func() -> bool: return game_state.get(&"time_trial_course") == "", 3.0)
	player.input.move = Vector3.ZERO
	var best: float = (game_state.get(&"best_times") as Dictionary).get("Test course", INF)
	report("course time", best, "s")
	check(best < 10.0, "the finish gate records the time")
	await frames(2)
	check(trial_star.get(&"_revealed"), "finishing under par reveals the star")
