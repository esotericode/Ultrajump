extends SceneTree
## Shared harness for the headless test suites.
##
## Spawns the player with scripted input into an arena the suite builds, runs
## the suite's tests one after another, and quits with the number of failed
## checks as the exit code. Suites extend this script and override
## [method build_arena] and [method get_tests].

const TICK := 1.0 / 120.0

var player: Player
var s: MovementSettings
var history: Array[StringName] = []
var steps := 0
var checks := 0
var failures := 0
var _current_test := ""


## Override: builds the static world the tests run in.
func build_arena() -> void:
	pass


## Override: the test methods to run, in order.
func get_tests() -> Array[Callable]:
	return []


func _initialize() -> void:
	Engine.physics_ticks_per_second = 120
	build_arena()
	player = (load("res://player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	player.input.scripted = true
	s = player.settings
	player.state_changed.connect(func(_from: StringName, to: StringName) -> void: history.append(to))
	player.stepped.connect(func(_height: float) -> void: steps += 1)
	_run_all.call_deferred()


func _run_all() -> void:
	for test in get_tests():
		_current_test = test.get_method()
		var failures_before := failures
		await test.call()
		print("%s %s" % ["PASS" if failures == failures_before else "FAIL", _current_test])
	print("\n%d checks, %d failed" % [checks, failures])
	silence(self)
	quit(failures)


## Stops every sound and gives the audio thread a moment to retire them. The
## tests run much faster than real time, so sounds are usually still playing
## when they end, and those would be reported as leaks at exit.
static func silence(tree: SceneTree) -> void:
	for type in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		for sound in tree.root.find_children("*", type, true, false):
			sound.call(&"stop")
	OS.delay_msec(200)


func box(position: Vector3, size: Vector3, rotation_degrees := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
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
		if player.is_on_floor() or player.state_name in [&"LedgeHang", &"WallContact"]:
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

