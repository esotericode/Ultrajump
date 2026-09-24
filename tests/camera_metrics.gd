extends SceneTree
## Measures how much the camera moves on its own.
##
## Plays scripted runs through the real movement gym without ever touching the
## camera, and reports the motion the camera made by itself: rotation nobody
## asked for, sudden jumps in distance, how far the character drifts from the
## center of the screen, and FOV swings. These are what make a camera feel
## disorienting, so they should stay small.
##
## Run from the project folder:
##   godot --headless --fixed-fps 60 -s res://tests/camera_metrics.gd
## Pass `-- --strict` to fail (non-zero exit code) when a comfort limit is exceeded.

## Comfort limits checked with --strict.
const LIMITS := {
	"unrequested_yaw_deg": 5.0, # The camera shouldn't rotate on its own.
	"max_distance_jump_m": 0.35, # No snapping in or out between two frames.
	"max_sideways_drift": 0.25, # The character stays near the middle (1.0 = screen edge).
	"max_vertical_drift": 0.7, # Jumps may move them up the screen, within reason.
	"max_fov_rate_deg_s": 12.0, # No zoom pumping.
}

var main: Node
var player: Player
var rig: PlayerCamera
var camera: Camera3D
var failures := 0
var strict := false


func _initialize() -> void:
	strict = "--strict" in OS.get_cmdline_user_args()
	change_scene_to_file("res://main/main.tscn")
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await process_frame
	main = current_scene
	player = main.get_node("Player")
	rig = main.get_node("PlayerCamera")
	camera = rig.camera
	player.input.scripted = true

	# Stick input is camera-relative, exactly like a player holding a direction.
	await scenario("Hold sideways (circle strafe)", 0, 5.0, func(_t: float) -> Vector2: return Vector2(1.0, 0.0))
	await scenario("Zigzag while running", 0, 5.0, func(t: float) -> Vector2: return Vector2(1.0 if fmod(t, 1.0) < 0.5 else -1.0, 1.0))
	await scenario("Run, stop, turn back", 0, 5.0, func(t: float) -> Vector2:
		if t < 1.5:
			return Vector2(0.0, 1.0)
		if t < 2.2:
			return Vector2.ZERO
		return Vector2(0.0, -1.0))
	await scenario("Run between the jump pillars", 1, 5.0, func(t: float) -> Vector2: return Vector2(0.7 if t > 1.0 else 0.0, 1.0))
	await scenario("Circle the tower", 7, 7.0, func(_t: float) -> Vector2: return Vector2(1.0, 0.25))
	await scenario("Long jumps and dives", 2, 5.0, func(_t: float) -> Vector2: return Vector2(0.0, 1.0), _long_jump_driver)
	print("\n%s" % ("All comfort limits met." if failures == 0 else "%d comfort limit(s) exceeded." % failures))
	quit(failures if strict else 0)


## Teleports to [param station], then holds the stick given by [param stick] (a
## function of time) for [param duration] seconds while recording the camera.
func scenario(title: String, station: int, duration: float, stick: Callable, buttons := Callable()) -> void:
	player.input.clear()
	main.go_to_station(station)
	for i in 30:
		await physics_frame
	var stats := {
		"unrequested_yaw_deg": 0.0,
		"max_distance_jump_m": 0.0,
		"max_sideways_drift": 0.0,
		"max_vertical_drift": 0.0,
		"mean_sideways_drift": 0.0,
		"max_fov_rate_deg_s": 0.0,
		"fov_range": Vector2(camera.fov, camera.fov),
		"worst": "",
	}
	var elapsed := 0.0
	var frames := 0
	var last_yaw := rig.yaw
	var last_distance := _arm_length()
	var last_fov := camera.fov
	var viewport_size := Vector2(root.get_visible_rect().size)
	while elapsed < duration:
		_drive(stick.call(elapsed))
		if buttons.is_valid():
			buttons.call(elapsed)
		await process_frame
		var delta := 1.0 / 60.0
		elapsed += delta
		frames += 1
		stats.unrequested_yaw_deg += absf(rad_to_deg(angle_difference(last_yaw, rig.yaw)))
		last_yaw = rig.yaw
		var distance := _arm_length()
		stats.max_distance_jump_m = maxf(stats.max_distance_jump_m, absf(distance - last_distance))
		last_distance = distance
		var body := player.get_global_transform_interpolated().origin + Vector3.UP * 0.8
		var drift := Vector2(9.99, 9.99) # Off screen (behind the camera).
		if not camera.is_position_behind(body):
			drift = ((camera.unproject_position(body) / viewport_size) * 2.0 - Vector2.ONE).abs()
		if drift.x > stats.max_sideways_drift:
			stats.max_sideways_drift = drift.x
			stats.worst = "t=%.2fs state=%s arm=%.2fm speed=%.1f" % [elapsed, player.state_name, distance, player.horizontal_speed()]
		stats.max_vertical_drift = maxf(stats.max_vertical_drift, drift.y)
		stats.mean_sideways_drift += drift.x
		stats.max_fov_rate_deg_s = maxf(stats.max_fov_rate_deg_s, absf(camera.fov - last_fov) / delta)
		last_fov = camera.fov
		stats.fov_range = Vector2(minf(stats.fov_range.x, camera.fov), maxf(stats.fov_range.y, camera.fov))
	stats.mean_sideways_drift /= maxi(frames, 1)
	player.input.clear()
	_report(title, stats)


func _drive(stick: Vector2) -> void:
	var forward := -rig.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	player.input.move = (right * stick.x + forward * stick.y).limit_length(1.0)


func _long_jump_driver(t: float) -> void:
	# Run, then alternate long jumps (crouch + jump) and dives.
	var phase := fmod(t, 1.6)
	if t < 1.0:
		return
	if phase < 0.02:
		player.input.press(&"crouch")
	elif phase < 0.04:
		player.input.press(&"jump")
	elif phase < 0.3:
		player.input.release(&"crouch")
		player.input.release(&"jump")
	elif phase > 0.9 and phase < 0.92:
		player.input.press(&"attack")
	elif phase > 0.95:
		player.input.release(&"attack")


## Current length of the camera arm (from the point it orbits to the camera).
func _arm_length() -> float:
	return rig.get(&"_distance")


func _report(title: String, stats: Dictionary) -> void:
	print("\n%s" % title)
	for key in ["unrequested_yaw_deg", "max_distance_jump_m", "max_sideways_drift", "max_vertical_drift", "mean_sideways_drift", "max_fov_rate_deg_s"]:
		var value: float = stats[key]
		var limit: float = LIMITS.get(key, INF)
		var over := value > limit
		if over:
			failures += 1
		print("  %-22s %8.2f%s" % [key, value, "   <-- over %.2f" % limit if over else ""])
	print("  %-22s %8.1f .. %.1f" % ["fov_range", stats.fov_range.x, stats.fov_range.y])
	print("  worst sideways drift at %s" % stats.worst)
