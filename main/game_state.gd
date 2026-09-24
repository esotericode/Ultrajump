extends Node
## Session-wide game state: coins, stars, the respawn checkpoint and time
## trial clocks. Registered as the [code]GameState[/code] autoload, so level
## props and the HUD reach it from anywhere.

signal coins_changed(total: int)
signal star_collected(star_name: String, collected: int, total: int)
## A short notification for the HUD ("Checkpoint", "3 crates to go", ...).
signal message(text: String)
signal respawn_requested
signal time_trial_started(course: String)
signal time_trial_finished(course: String, time: float, best: float, new_record: bool)

var coins := 0
var collected_stars: Dictionary[String, bool] = {}
## How many stars exist in the loaded level (each Star registers itself).
var star_total := 0
## Where the player respawns: set by stations and checkpoints.
var checkpoint := Transform3D(Basis.IDENTITY, Vector3.UP)
## The course being timed, or "" when no time trial is running.
var time_trial_course := ""
var time_trial_time := 0.0
var best_times: Dictionary[String, float] = {}


func _physics_process(delta: float) -> void:
	if not time_trial_course.is_empty():
		time_trial_time += delta


func add_coins(amount := 1) -> void:
	coins += amount
	coins_changed.emit(coins)


func register_star() -> void:
	star_total += 1


func has_star(star_name: String) -> bool:
	return collected_stars.has(star_name)


## Returns false if that star was already collected.
func collect_star(star_name: String) -> bool:
	if collected_stars.has(star_name):
		return false
	collected_stars[star_name] = true
	star_collected.emit(star_name, collected_stars.size(), star_total)
	message.emit("★  %s  (%d / %d)" % [star_name, collected_stars.size(), star_total])
	return true


func set_checkpoint(xform: Transform3D, announce := false) -> void:
	checkpoint = xform
	if announce:
		message.emit("Checkpoint")


## Asks the game to put the player back at the checkpoint (hazards use this).
func request_respawn() -> void:
	respawn_requested.emit()


func start_time_trial(course: String) -> void:
	time_trial_course = course
	time_trial_time = 0.0
	time_trial_started.emit(course)
	message.emit("%s: go!" % course)


## Stops the clock if [param course] is being timed; returns the time, or -1.
func finish_time_trial(course: String) -> float:
	if time_trial_course != course:
		return -1.0
	var time := time_trial_time
	time_trial_course = ""
	var best: float = best_times.get(course, INF)
	var new_record := time < best
	if new_record:
		best_times[course] = time
	time_trial_finished.emit(course, time, minf(time, best), new_record)
	message.emit("%s: %.2f s%s" % [course, time, "  (new best!)" if new_record and best < INF else ""])
	return time


func cancel_time_trial() -> void:
	time_trial_course = ""
