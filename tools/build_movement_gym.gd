extends SceneTree
## Generates res://levels/movement_gym.tscn, the grey-box test level.
##
## This only bootstraps the level: the saved scene is the source of truth and
## is meant to be edited directly in the editor afterwards. Re-running this
## script OVERWRITES the scene. Run from the project folder with:
##   godot --headless -s res://tools/build_movement_gym.gd

const OUTPUT := "res://levels/movement_gym.tscn"
const BlockScript := preload("res://levels/props/block.gd")
const PlatformScript := preload("res://levels/props/moving_platform.gd")

const GROUND := Color(0.62, 0.66, 0.72)
const STONE := Color(0.78, 0.8, 0.85)
const WARM := Color(0.93, 0.72, 0.45)
const COOL := Color(0.52, 0.7, 0.9)
const GREEN := Color(0.55, 0.8, 0.55)
const PINK := Color(0.9, 0.6, 0.72)
const PURPLE := Color(0.68, 0.6, 0.9)
const GOLD := Color(1.0, 0.8, 0.3)

var level: Node3D


func _initialize() -> void:
	level = Node3D.new()
	level.name = "MovementGym"
	_environment()
	_ground_and_spawn()
	_jump_ladder()
	_long_jump_runway()
	_wall_kick_zone()
	_slopes_and_stairs()
	_ledges()
	_moving_platforms()
	_tower_course()
	var scene := PackedScene.new()
	var error := scene.pack(level)
	if error == OK:
		error = ResourceSaver.save(scene, OUTPUT)
	print("Saved %s: %s" % [OUTPUT, error_string(error)])
	level.free()
	quit(0 if error == OK else 1)


# --- Areas -----------------------------------------------------------------------

func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.55, 0.92)
	sky_material.sky_horizon_color = Color(0.72, 0.84, 0.96)
	sky_material.ground_horizon_color = Color(0.72, 0.84, 0.96)
	sky_material.ground_bottom_color = Color(0.4, 0.45, 0.52)
	sky_material.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.ssao_enabled = true
	environment.ssao_radius = 1.5
	environment.ssao_intensity = 1.5
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	environment.glow_bloom = 0.05
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.7, 0.8, 0.93)
	environment.fog_depth_begin = 60.0
	environment.fog_depth_end = 260.0
	environment.fog_density = 0.5
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	_add(world, level)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	_add(sun, level)


func _ground_and_spawn() -> void:
	var area := _area("Spawn")
	_block(area, "Ground", Vector3(0, -0.5, 0), Vector3(260, 1, 260), GROUND)
	_cylinder(area, "SpawnPad", Vector3(0, 0.05, 0), 8.0, 0.1, STONE)
	_label(area, "ULTRAJUMP", Vector3(0, 5.5, -7), 160, Color(1.0, 0.55, 0.25))
	_label(area, "movement gym  ·  F1 for controls", Vector3(0, 4.3, -7), 48)
	_station("Spawn", Vector3(0, 0.1, 3), 0.0)


func _jump_ladder() -> void:
	var area := _area("JumpLadder")
	for i in 7:
		var height := float(i + 1)
		var x := -15.0 + i * 5.0
		var tint := COOL.lerp(PURPLE, i / 6.0)
		_block(area, "Pillar%dm" % (i + 1), Vector3(x, height / 2.0, -20), Vector3(3, height, 3), tint)
		_label(area, "%d m" % (i + 1), Vector3(x, height + 0.7, -18.6), 64)
	_label(area, "Jump heights", Vector3(0, 9.5, -20), 72, GOLD)
	_label(area, "single 2.1 · double 3.0 · triple 4.6 · backflip 4.9 · ground pound jump 5.3", Vector3(0, 8.7, -20), 36)
	_station("Jump heights", Vector3(0, 0, -12), 0.0)


func _long_jump_runway() -> void:
	var area := _area("LongJump")
	var top := 3.0
	var z := -34.0
	_ramp(area, "Ramp", Vector3(9, 0, z), Vector3.RIGHT, 6.0, 9.0, top, STONE)
	_block(area, "Runway", Vector3(30, top / 2.0, z), Vector3(24, top, 6), WARM)
	var x := 42.0
	for gap in [6.0, 8.0, 10.0, 12.0]:
		var landing_length := 8.0 if gap == 12.0 else 6.0
		_label(area, "%d m" % gap, Vector3(x + gap / 2.0, top + 2.2, z), 80, GOLD, -PI / 2.0)
		x += gap
		_block(area, "Landing%dm" % gap, Vector3(x + landing_length / 2.0, top / 2.0, z), Vector3(landing_length, top, 6), WARM.darkened(0.08 * gap / 6.0))
		x += landing_length
	_label(area, "Long jump: run, crouch, jump", Vector3(24, top + 3.5, z), 56, Color.WHITE, -PI / 2.0)
	_station("Long jump runway", Vector3(20, top, z), -PI / 2.0)


func _wall_kick_zone() -> void:
	var area := _area("WallKicks")
	var z := -12.0
	_block(area, "ShaftEast", Vector3(-19.5, 8, z), Vector3(1, 16, 10), STONE)
	_block(area, "ShaftWest", Vector3(-25, 8, z), Vector3(1, 16, 10), STONE)
	_block(area, "Rooftop", Vector3(-28.5, 15.75, z), Vector3(6, 0.5, 10), GREEN)
	_label(area, "Wall kick shaft", Vector3(-22.25, 17.5, z + 5.5), 72, GOLD)
	_label(area, "16 m", Vector3(-22.25, 16.6, z + 5.2), 48)
	# A lone wall with small ledges on its face: wall slide, kick, grab.
	_block(area, "SlideWall", Vector3(-40, 7, z), Vector3(1, 14, 12), STONE)
	for i in 3:
		var height := 4.0 + i * 3.5
		_block(area, "WallLedge%d" % (i + 1), Vector3(-38.75, height - 0.25, z + (i - 1) * 3.5), Vector3(1.5, 0.5, 2.5), GREEN)
	_label(area, "Wall slide & ledges", Vector3(-38, 15.2, z), 56)
	_station("Wall kicks", Vector3(-22.25, 0, -3), 0.0)


func _slopes_and_stairs() -> void:
	var area := _area("SlopesAndStairs")
	var start_z := 14.0
	var ramps := [[15.0, 12.0, -14.0], [30.0, 8.0, -8.0], [45.0, 5.0, -2.0], [55.0, 4.0, 4.0]]
	for entry in ramps:
		var angle: float = entry[0]
		var length: float = entry[1]
		var x: float = entry[2]
		var height := length * tan(deg_to_rad(angle))
		var tint := GREEN if angle <= 45.0 else PINK
		_ramp(area, "Ramp%d" % angle, Vector3(x, 0, start_z), Vector3.BACK, 4.0, length, height, tint)
		_block(area, "Ramp%dTop" % angle, Vector3(x, height / 2.0, start_z + length + 2.0), Vector3(4, height, 4), tint.darkened(0.1))
		_label(area, "%d°" % angle, Vector3(x, 2.0, start_z - 1.0), 64, GOLD if angle > 45.0 else Color.WHITE, PI)
	_label(area, "Slopes: 46° and steeper make you slide", Vector3(-5, 4.0, start_z - 1.0), 40, Color.WHITE, PI)

	# Stairs: 0.25 m and 0.35 m steps (the default step height is 0.35).
	for flight in [[0.25, 12, 11.0], [0.35, 8, 17.0]]:
		var rise: float = flight[0]
		var steps: int = flight[1]
		var x: float = flight[2]
		for i in steps:
			var step_top := rise * (i + 1)
			_block(area, "Step%d_%d" % [int(rise * 100), i + 1], Vector3(x, step_top / 2.0, start_z + 0.3 + i * 0.6), Vector3(4, step_top, 0.6), STONE)
		var top := rise * steps
		_block(area, "Landing%d" % int(rise * 100), Vector3(x, top / 2.0, start_z + steps * 0.6 + 2.0), Vector3(4, top, 4), STONE.darkened(0.1))
		_label(area, "%.2f m steps" % rise, Vector3(x, 1.6, start_z - 1.0), 44, Color.WHITE, PI)

	# A long hill to crouch-slide down (building speed) into a long jump.
	_ramp(area, "SlideHill", Vector3(-28, 0, 16), Vector3.BACK, 6.0, 24.0, 8.5, COOL)
	_block(area, "SlideHillTop", Vector3(-28, 4.25, 43), Vector3(6, 8.5, 6), COOL.darkened(0.1))
	_label(area, "Slide hill: crouch-slide down, jump", Vector3(-28, 2.2, 14), 44, Color.WHITE, PI)
	_station("Slopes & stairs", Vector3(0, 0, 9), PI)


func _ledges() -> void:
	var area := _area("Ledges")
	var heights := [2.4, 3.2, 4.0]
	for i in heights.size():
		var height: float = heights[i]
		var z := -8.0 + i * 6.0
		_block(area, "Ledge%s" % str(height).replace(".", "_"), Vector3(24, height / 2.0, z), Vector3(4, height, 5), PURPLE.lightened(0.1 * i))
		var hint := "mantle" if height < 3.0 else "grab"
		_label(area, "%.1f m · %s" % [height, hint], Vector3(21.9, height + 0.6, z), 44, Color.WHITE, -PI / 2.0)
	_station("Ledges", Vector3(15, 0, -2), -PI / 2.0)


func _moving_platforms() -> void:
	var area := _area("MovingPlatforms")
	var z := -44.0
	_block(area, "TowerA", Vector3(-50, 2, z), Vector3(4, 4, 4), STONE)
	_block(area, "TowerB", Vector3(-30, 2, z), Vector3(4, 4, 4), STONE)
	_platform(area, "Shuttle", Vector3(-44.5, 3.75, z), Vector3(3, 0.5, 3), Vector3(9, 0, 0), 3.0, 0.8)
	_block(area, "TowerC", Vector3(-60, 5, z), Vector3(4, 10, 4), STONE)
	_platform(area, "Elevator", Vector3(-56.5, 0.25, z), Vector3(3, 0.5, 3), Vector3(0, 9.75, 0), 4.0, 1.2)
	var spinner := _platform(area, "Spinner", Vector3(-40, 1.25, z + 14), Vector3(9, 0.5, 9), Vector3.ZERO, 1.0, 0.0)
	spinner.set(&"shape", 2)
	spinner.set(&"spin_degrees_per_second", 30.0)
	_label(area, "Moving platforms", Vector3(-40, 7.5, z), 64, GOLD, -PI / 2.0)
	_station("Moving platforms", Vector3(-50, 4, z), -PI / 2.0)


func _tower_course() -> void:
	var area := _area("TowerCourse")
	var center := Vector3(45, 0, 40)
	_cylinder(area, "Tower", center + Vector3(0, 10, 0), 6.0, 20.0, STONE)
	var steps := 11
	for i in steps:
		var angle := deg_to_rad(200.0 + i * 38.0)
		var height := 1.2 + i * 1.75
		var spot := center + Vector3(cos(angle) * 8.0, height - 0.25, sin(angle) * 8.0)
		_block(area, "Step%d" % (i + 1), spot, Vector3(3, 0.5, 3), COOL.lerp(PINK, float(i) / steps))
	_cylinder(area, "Flagpole", center + Vector3(0, 21.5, 0), 0.2, 3.0, Color(0.9, 0.9, 0.9))
	_block(area, "Flag", center + Vector3(0.8, 22.4, 0), Vector3(1.4, 0.9, 0.1), GOLD)
	_label(area, "Tower climb", center + Vector3(0, 4, -8.5), 64, GOLD, PI)
	_station("Tower course", center + Vector3(0, 0, -13), PI)


# --- Builders --------------------------------------------------------------------

func _area(area_name: String) -> Node3D:
	var area := Node3D.new()
	area.name = area_name
	_add(area, level)
	return area


func _block(parent: Node, block_name: String, center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var block := StaticBody3D.new()
	block.set_script(BlockScript)
	block.name = block_name
	block.position = center
	block.set(&"size", size)
	block.set(&"color", color)
	_add(block, parent)
	return block


func _cylinder(parent: Node, block_name: String, center: Vector3, diameter: float, height: float, color: Color) -> StaticBody3D:
	var block := _block(parent, block_name, center, Vector3(diameter, height, diameter), color)
	block.set(&"shape", 2)
	return block


## A ramp whose low edge starts at [param base] and rises along [param direction].
func _ramp(parent: Node, block_name: String, base: Vector3, direction: Vector3, width: float, length: float, height: float, color: Color) -> StaticBody3D:
	var block := _block(parent, block_name, base + direction * length / 2.0 + Vector3.UP * height / 2.0, Vector3(width, height, length), color)
	block.set(&"shape", 1)
	block.rotation.y = atan2(-direction.x, -direction.z)
	return block


func _platform(parent: Node, platform_name: String, center: Vector3, size: Vector3, travel: Vector3, travel_time: float, pause_time: float) -> AnimatableBody3D:
	var platform := AnimatableBody3D.new()
	platform.set_script(PlatformScript)
	platform.name = platform_name
	platform.position = center
	platform.set(&"size", size)
	platform.set(&"travel", travel)
	platform.set(&"travel_time", travel_time)
	platform.set(&"pause_time", pause_time)
	_add(platform, parent)
	return platform


func _label(parent: Node, text: String, position: Vector3, font_size: int, color := Color.WHITE, yaw := 0.0) -> Label3D:
	var label := Label3D.new()
	label.name = "Label_" + text.validate_node_name().left(24)
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.01
	label.outline_size = maxi(roundi(font_size / 6.0), 8)
	label.outline_modulate = Color(0.1, 0.1, 0.16)
	label.modulate = color
	label.position = position
	label.rotation.y = yaw
	label.double_sided = true
	_add(label, parent)
	return label


## A teleport destination (keys 1-9). The player spawns facing the marker's -Z.
func _station(station_name: String, position: Vector3, yaw: float) -> void:
	var stations := level.get_node_or_null("Stations")
	if stations == null:
		stations = _area("Stations")
	var marker := Marker3D.new()
	marker.name = station_name.validate_node_name()
	marker.position = position + Vector3.UP * 0.1
	marker.rotation.y = yaw
	_add(marker, stations)


func _add(node: Node, parent: Node) -> void:
	parent.add_child(node, true)
	node.owner = level
