extends SceneTree
## Checks that nothing stutters the first time it happens.
##
## Starts the game, waits for the loading warm-up (main/warm_up.gd), then
## plays one of every event that shows an effect or plays a level sound:
## landing, ground pound, dive, coins, crates, stars, bounce pads, lava,
## checkpoints, the time trial and wall kicks. For each one it reports
## pipelines compiled while drawing (the cause of first-time stutter) and the
## slowest frame compared to an ordinary one.
##
## Needs a real renderer, so run it without --headless, from the project folder:
##   godot --fixed-fps 60 -s res://tests/first_use_check.gd
## The exit code is the number of events that stuttered. Events are flagged
## when they compile a pipeline, or when their slowest frame takes three
## times as long as an ordinary frame plus 30 ms.

const TestBase := preload("res://tests/test_base.gd")

var main: Node
var player: Player
var failures := 0
var _before := {}
var _worst_frame := 0.0
var _last_tick := 0
var _normal_frame := 0.0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("first_use_check needs a real renderer: run it without --headless.")
		quit()
		return
	change_scene_to_file("res://main/main.tscn")
	_run.call_deferred()


func _run() -> void:
	while current_scene == null:
		await process_frame
	main = current_scene
	player = main.get_node("Player")
	player.input.scripted = true
	var warm_up := main.get_node_or_null(^"WarmUp")
	if warm_up:
		await warm_up.finished
	_normal_frame = await _measure_normal_frame()
	print("\nFirst-use check (an ordinary frame takes %.1f ms)" % _normal_frame)

	await event("Jump and land", _jump_and_land)
	await event("Ground pound", _ground_pound)
	await event("Dive and belly slide", _dive)
	await event("Air spin", _air_spin)
	await event("Punch combo", _punch_combo)
	await event("Coin", _coin)
	await event("Crate", _crate)
	await event("Star appears", _star_appears)
	await event("Star collected", _star_collected)
	await event("Bounce pad", _bounce_pad)
	await event("Lava", _lava)
	await event("Checkpoint", _checkpoint)
	await event("Time trial", _time_trial)
	await event("Wall kick", _wall_kick)

	print("\n%s" % ("Nothing stuttered." if failures == 0 else "%d event(s) stuttered." % failures))
	TestBase.silence(self)
	quit(failures)


## Plays [param action] and reports what it compiled and its slowest frame.
func event(title: String, action: Callable) -> void:
	player.input.clear()
	_before = _compilations()
	_worst_frame = 0.0
	_last_tick = Time.get_ticks_usec()
	await action.call()
	var after := _compilations()
	var compiled: int = (after.draw - _before.draw) + (after.surface - _before.surface)
	var background: int = after.specialization - _before.specialization
	var slow := _worst_frame > _normal_frame * 3.0 + 30.0
	var stuttered := compiled > 0 or slow
	if stuttered:
		failures += 1
	var notes: Array[String] = []
	if compiled > 0:
		notes.append("compiled %d pipeline(s) while drawing" % compiled)
	if background > 0:
		notes.append("%d in the background" % background)
	print("  %-22s %-10s slowest frame %6.1f ms%s" % [title, "STUTTER" if stuttered else "ok", _worst_frame, ("   (" + ", ".join(notes) + ")") if notes else ""])


func _compilations() -> Dictionary:
	return {
		"draw": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		"surface": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		"specialization": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)),
	}


## The median frame time while standing around.
func _measure_normal_frame() -> float:
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 40:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	return times[floori(times.size() * 0.5)]


func frames(count: int) -> void:
	for i in count:
		await process_frame
		var now := Time.get_ticks_usec()
		_worst_frame = maxf(_worst_frame, (now - _last_tick) / 1000.0)
		_last_tick = now


func wait_until(condition: Callable, max_frames := 120) -> void:
	for i in max_frames:
		if condition.call():
			return
		await frames(1)


func tap(action: StringName) -> void:
	player.input.press(action)
	await physics_frame
	await physics_frame
	player.input.release(action)


func place(position: Vector3, facing := Vector3.FORWARD) -> void:
	player.input.clear()
	player.teleport(Transform3D(Basis.looking_at(facing), position))
	await frames(6)


func station(station_name: String) -> void:
	player.input.clear()
	main.go_to_station(main.find_station(station_name))
	await frames(6)


# --- Events ----------------------------------------------------------------------

func _jump_and_land() -> void:
	await station("Spawn")
	await tap(&"jump")
	await frames(4)
	await wait_until(func() -> bool: return player.is_on_floor())
	await frames(10)


func _ground_pound() -> void:
	await station("Spawn")
	await tap(&"jump")
	await frames(10)
	await tap(&"crouch")
	await wait_until(func() -> bool: return player.state_name == &"GroundPoundLand")
	await frames(15)


func _dive() -> void:
	await station("Spawn")
	player.input.move = Vector3.FORWARD
	await tap(&"jump")
	await frames(6)
	await tap(&"attack")
	await wait_until(func() -> bool: return player.state_name == &"BellySlide")
	player.input.move = Vector3.ZERO
	await frames(20)


func _air_spin() -> void:
	await station("Spawn")
	await tap(&"jump")
	await frames(6)
	await tap(&"spin")
	await frames(20)


func _punch_combo() -> void:
	await station("Spawn")
	for i in 3:
		await tap(&"attack")
		await frames(5)
	await frames(15)


func _coin() -> void:
	# The spawn ring's coin on the +x side.
	await station("Spawn")
	await place(Vector3(6.5, 0, 1.2), Vector3.FORWARD)
	player.input.move = Vector3.FORWARD
	await frames(12)
	player.input.move = Vector3.ZERO
	await frames(10)


func _crate() -> void:
	await station("Crate yard")
	await place(Vector3(7.9, 0, 5.0), Vector3.RIGHT)
	await tap(&"attack")
	await frames(30)


func _star_appears() -> void:
	var group := main.get_node("Level").find_child("Crates", true, false)
	for crate in group.get_children():
		if crate.has_method(&"take_hit") and not crate.get(&"_broken"):
			crate.call(&"take_hit", {"attacker": player, "kind": &"kick", "direction": Vector3.RIGHT, "position": Vector3.ZERO})
	await frames(20)


func _star_collected() -> void:
	var star: Node3D = main.get_node("Level").find_child("Crates", true, false).get(&"reward")
	await place(star.global_position - Vector3.UP * 1.0)
	await frames(20)


func _bounce_pad() -> void:
	await station("Sky islands")
	player.input.move = Vector3.RIGHT
	await wait_until(func() -> bool: return player.state_name == &"Jump")
	player.input.move = Vector3.ZERO
	await frames(20)


func _lava() -> void:
	await station("Pillar hop")
	await place(Vector3(-50, 0.3, 36), Vector3.LEFT)
	await frames(20)


func _checkpoint() -> void:
	# The chimney's flag stands just ahead of its station.
	await station("Wall kick chimney")
	player.input.move = Vector3.FORWARD
	await frames(15)
	player.input.move = Vector3.ZERO
	await frames(10)


func _time_trial() -> void:
	await station("Parkour time trial")
	player.input.move = Vector3.RIGHT
	await wait_until(func() -> bool: return player.global_position.x > 25.0)
	await place(Vector3(103.0, 4.0, 70.0), Vector3.RIGHT)
	player.input.move = Vector3.RIGHT
	await frames(15)
	player.input.move = Vector3.ZERO
	await frames(10)


func _wall_kick() -> void:
	await station("Wall kick chimney")
	await place(Vector3(-48, 0, -12), Vector3.RIGHT)
	player.input.move = Vector3.RIGHT
	player.input.press(&"jump")
	await wait_until(func() -> bool: return player.state_name == &"WallContact")
	player.input.release(&"jump")
	await physics_frame
	player.input.move = Vector3.LEFT
	await tap(&"jump")
	player.input.move = Vector3.ZERO
	await frames(30)
