extends Node3D
## Entry point: the movement gym level, the player, the camera and the debug HUD.
## Handles respawning (at the last station or checkpoint), teleport stations
## (keys 1-9 and 0, PageUp / PageDown to cycle) and mouse capture.

## Falling below this height respawns the player at the current station.
@export var kill_height := -30.0

var _stations: Array[Node3D] = []
var _station := 0
var _input_block_time := 0.0

@onready var level: Node3D = $Level
@onready var player: Player = $Player
@onready var hud: DebugHud = $DebugHud


func _ready() -> void:
	var markers := level.get_node_or_null(^"Stations")
	if markers:
		for child in markers.get_children():
			if child is Node3D:
				_stations.append(child)
	var names := PackedStringArray()
	for station in _stations:
		names.append(String(station.name))
	hud.station_names = names
	# Deferred: hazards ask for respawns from inside physics callbacks.
	GameState.respawn_requested.connect(respawn, CONNECT_DEFERRED)
	_capture_mouse()
	go_to_station(0)


func _process(delta: float) -> void:
	_input_block_time = maxf(_input_block_time - delta, 0.0)
	player.input.enabled = _input_block_time <= 0.0 and not hud.wants_input()


func _physics_process(_delta: float) -> void:
	if player.global_position.y < kill_height:
		respawn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"respawn"):
		respawn()
	elif event.is_action_pressed(&"pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			_capture_mouse()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_capture_mouse()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var index := _station_for_key(event.keycode)
		if index >= 0 and index < _stations.size():
			go_to_station(index)
			get_viewport().set_input_as_handled()


## Back to the last station or checkpoint.
func respawn() -> void:
	player.teleport(GameState.checkpoint)


func go_to_station(index: int) -> void:
	GameState.cancel_time_trial()
	if _stations.is_empty():
		GameState.set_checkpoint(Transform3D(Basis.IDENTITY, Vector3.UP))
	else:
		_station = clampi(index, 0, _stations.size() - 1)
		var marker := _stations[_station]
		GameState.set_checkpoint(Transform3D(marker.global_basis.orthonormalized(), marker.global_position))
	respawn()


## Index of the station named [param station_name], or -1.
func find_station(station_name: String) -> int:
	for i in _stations.size():
		if String(_stations[i].name) == station_name.validate_node_name():
			return i
	return -1


## Keys 1-9 and 0 pick the first ten stations; PageDown / PageUp cycle through all of them.
func _station_for_key(key: Key) -> int:
	if key >= KEY_1 and key <= KEY_9:
		return key - KEY_1
	match key:
		KEY_0:
			return 9
		KEY_PAGEDOWN:
			return (_station + 1) % maxi(_stations.size(), 1)
		KEY_PAGEUP:
			return (_station - 1 + _stations.size()) % maxi(_stations.size(), 1)
	return -1


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The click that grabbed the mouse shouldn't also make the player dive.
	_input_block_time = 0.15
