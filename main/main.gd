extends Node3D
## Entry point: the movement gym level, the player, the camera and the debug HUD.
## Handles respawning, teleport stations (keys 1-9) and mouse capture.

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
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < mini(_stations.size(), 9):
			go_to_station(index)
			get_viewport().set_input_as_handled()


func respawn() -> void:
	go_to_station(_station)


func go_to_station(index: int) -> void:
	if _stations.is_empty():
		player.teleport(Transform3D(Basis.IDENTITY, Vector3.UP))
		return
	_station = clampi(index, 0, _stations.size() - 1)
	player.teleport(_stations[_station].global_transform)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The click that grabbed the mouse shouldn't also make the player dive.
	_input_block_time = 0.15
