extends SceneTree
## Generates res://levels/movement_gym.tscn, the grey-box test level.
##
## This only bootstraps the level: the saved scene is the source of truth and
## is meant to be edited directly in the editor afterwards. Re-running this
## script OVERWRITES the scene. Run from the project folder with:
##   godot --headless -s res://tools/build_movement_gym.gd

const OUTPUT := "res://levels/movement_gym.tscn"
# Loaded at startup rather than preloaded: some props use the GameState
# autoload, which isn't registered yet while this script is being parsed.
var BlockScript: Script
var PlatformScript: Script
var CoinScript: Script
var StarScript: Script
var CrateScript: Script
var CrateGroupScript: Script
var BouncePadScript: Script
var HazardScript: Script
var CheckpointScript: Script
var GateScript: Script

const GROUND := Color(0.62, 0.66, 0.72)
const STONE := Color(0.78, 0.8, 0.85)
const WARM := Color(0.93, 0.72, 0.45)
const COOL := Color(0.52, 0.7, 0.9)
const GREEN := Color(0.55, 0.8, 0.55)
const PINK := Color(0.9, 0.6, 0.72)
const PURPLE := Color(0.68, 0.6, 0.9)
const GOLD := Color(1.0, 0.8, 0.3)
const DARK := Color(0.42, 0.45, 0.55)

var level: Node3D


func _initialize() -> void:
	BlockScript = load("res://levels/props/block.gd")
	PlatformScript = load("res://levels/props/moving_platform.gd")
	CoinScript = load("res://levels/props/coin.gd")
	StarScript = load("res://levels/props/star.gd")
	CrateScript = load("res://levels/props/crate.gd")
	CrateGroupScript = load("res://levels/props/crate_group.gd")
	BouncePadScript = load("res://levels/props/bounce_pad.gd")
	HazardScript = load("res://levels/props/hazard.gd")
	CheckpointScript = load("res://levels/props/checkpoint.gd")
	GateScript = load("res://levels/props/time_trial_gate.gd")
	level = Node3D.new()
	level.name = "MovementGym"
	# Areas are built in teleport-station order (keys 1-9, then 0, then PageDown).
	_environment()
	_ground_and_spawn()
	_jump_ladder()
	_long_jump_runway()
	_wall_kick_zone()
	_slopes_and_stairs()
	_ledges()
	_crate_yard()
	_moving_platforms()
	_tower_course()
	_parkour_time_trial()
	_wall_kick_chimney()
	_pillar_hop()
	_sky_islands()
	_backflip_cliffs()
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
	for i in 10:
		var angle := TAU * i / 10.0
		_coin(area, Vector3(cos(angle) * 6.5, 0.8, sin(angle) * 6.5))
	_station("Spawn", Vector3(0, 0.1, 3), 0.0)


func _jump_ladder() -> void:
	var area := _area("JumpLadder")
	for i in 7:
		var height := float(i + 1)
		var x := -15.0 + i * 5.0
		var tint := COOL.lerp(PURPLE, i / 6.0)
		_block(area, "Pillar%dm" % (i + 1), Vector3(x, height / 2.0, -20), Vector3(3, height, 3), tint)
		_label(area, "%d m" % (i + 1), Vector3(x, height + 0.7, -18.6), 64)
		_coin(area, Vector3(x, height + 0.8, -20))
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
		_coin_arc(area, Vector3(x, top + 0.8, z), Vector3(x + gap, top + 0.8, z), 1.3, 5)
		x += gap
		_block(area, "Landing%dm" % gap, Vector3(x + landing_length / 2.0, top / 2.0, z), Vector3(landing_length, top, 6), WARM.darkened(0.08 * gap / 6.0))
		x += landing_length
	_label(area, "Long jump: run, crouch, jump", Vector3(24, top + 3.5, z), 56, Color.WHITE, -PI / 2.0)
	_star(area, "Long jump leap", Vector3(x - 3.0, top + 1.3, z))
	_station("Long jump runway", Vector3(20, top, z), -PI / 2.0)


func _wall_kick_zone() -> void:
	var area := _area("WallKicks")
	var z := -12.0
	# The far wall stands taller, so the last kick always carries you onto the rooftop.
	_block(area, "ShaftEast", Vector3(-19.5, 9.5, z), Vector3(1, 19, 10), STONE)
	_block(area, "ShaftWest", Vector3(-25, 8, z), Vector3(1, 16, 10), STONE)
	_block(area, "Rooftop", Vector3(-28.5, 15.75, z), Vector3(6, 0.5, 10), GREEN)
	_label(area, "Wall kick shaft", Vector3(-22.25, 17.5, z + 5.5), 72, GOLD)
	_label(area, "16 m", Vector3(-22.25, 16.6, z + 5.2), 48)
	for i in 4:
		_coin(area, Vector3(-22.25, 4.0 + i * 3.0, z))
	_star(area, "Wall kick shaft", Vector3(-29.0, 17.5, z))
	# A lone wall with small ledges on its face: wall slide, kick, grab.
	_block(area, "SlideWall", Vector3(-40, 7, z), Vector3(1, 14, 12), STONE)
	for i in 3:
		var height := 4.0 + i * 3.5
		_block(area, "WallLedge%d" % (i + 1), Vector3(-38.75, height - 0.25, z + (i - 1) * 3.5), Vector3(1.5, 0.5, 2.5), GREEN)
	_label(area, "Wall kicks & ledges", Vector3(-38, 15.2, z), 56)
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
	var center := Vector3(65, 0, 40)
	_cylinder(area, "Tower", center + Vector3(0, 10, 0), 6.0, 20.0, STONE)
	var steps := 11
	for i in steps:
		var angle := deg_to_rad(200.0 + i * 38.0)
		var height := 1.2 + i * 1.75
		var spot := center + Vector3(cos(angle) * 8.0, height - 0.25, sin(angle) * 8.0)
		_block(area, "Step%d" % (i + 1), spot, Vector3(3, 0.5, 3), COOL.lerp(PINK, float(i) / steps))
		if i % 3 == 1:
			_coin(area, spot + Vector3.UP * 1.0)
	_cylinder(area, "Flagpole", center + Vector3(0, 21.5, 0), 0.2, 3.0, Color(0.9, 0.9, 0.9))
	_block(area, "Flag", center + Vector3(0.8, 22.4, 0), Vector3(1.4, 0.9, 0.1), GOLD)
	_star(area, "Tower top", center + Vector3(0, 21.3, 1.8))
	_label(area, "Tower climb", center + Vector3(0, 4, -8.5), 64, GOLD, PI)
	_station("Tower course", center + Vector3(0, 0, -13), PI)


func _crate_yard() -> void:
	var area := _area("CrateYard")
	var crates := Node3D.new()
	crates.set_script(CrateGroupScript)
	crates.name = "Crates"
	_add(crates, area)
	crates.set(&"reward", _star(area, "Crate smasher", Vector3(12.5, 3.6, 7.5), true))
	# [position, coins inside]
	var spots := [
		[Vector3(9.0, 0.6, 5.0), 1], [Vector3(10.4, 0.6, 5.0), 0], [Vector3(11.8, 0.6, 5.0), 2],
		[Vector3(15.0, 0.6, 7.0), 0], [Vector3(15.0, 1.8, 7.0), 3],
		[Vector3(10.0, 0.6, 10.0), 0], [Vector3(11.4, 0.6, 10.0), 1], [Vector3(10.7, 1.8, 10.0), 2],
	]
	for i in spots.size():
		_crate(crates, "Crate%d" % (i + 1), spots[i][0], spots[i][1])
	_label(area, "Crate yard", Vector3(7.0, 3.4, 7.5), 64, GOLD, -PI / 2.0)
	_label(area, "punch · kick · dive · spin · ground pound", Vector3(7.0, 2.7, 7.5), 36, Color.WHITE, -PI / 2.0)
	_station("Crate yard", Vector3(4.5, 0, 7.5), -PI / 2.0)


## A timed obstacle course heading east along z = 70.
func _parkour_time_trial() -> void:
	var area := _area("Parkour")
	var z := 70.0
	var course := "Parkour"
	_label(area, "Parkour time trial", Vector3(21, 4.4, z), 64, GOLD, -PI / 2.0)
	_label(area, "beat 30 s for the star", Vector3(21, 3.7, z), 40, Color.WHITE, -PI / 2.0)
	_gate(area, "Start", Vector3(24, 0, z), PI / 2.0, 0, course)
	# Hop up three steps onto a runway, then long jump the gap.
	for i in 3:
		var top := 1.5 * (i + 1)
		_block(area, "Step%d" % (i + 1), Vector3(30 + 4.5 * i, top / 2.0, z), Vector3(3, top, 3), WARM.lerp(PINK, i / 3.0))
	_block(area, "Runway", Vector3(46, 2.25, z), Vector3(10, 4.5, 4), WARM)
	_coin_arc(area, Vector3(51, 5.3, z), Vector3(59, 5.3, z), 1.4, 5)
	# Land at the foot of a chimney and wall kick up it.
	_block(area, "Landing", Vector3(64.5, 2.25, z), Vector3(11, 4.5, 4.4), STONE)
	_checkpoint(area, Vector3(61, 4.5, z), -PI / 2.0)
	# Its side walls stand above the lookout, so the only way out at the top is east.
	_block(area, "ChimneySouth", Vector3(68, 7, z - 2.6), Vector3(4, 14, 0.8), STONE.darkened(0.1))
	_block(area, "ChimneyNorth", Vector3(68, 7, z + 2.6), Vector3(4, 14, 0.8), STONE.darkened(0.1))
	for i in 3:
		_coin(area, Vector3(68, 6.5 + 2.5 * i, z))
	_block(area, "Lookout", Vector3(73, 6, z), Vector3(6, 12, 6), GREEN)
	_checkpoint(area, Vector3(74, 12, z), -PI / 2.0)
	# Drop down the steps, then ride the shuttle over the lava to the finish.
	var drops := [[80.5, 9.0], [85.5, 6.5], [90.5, 4.0]]
	for i in drops.size():
		var x: float = drops[i][0]
		var top: float = drops[i][1]
		_block(area, "Drop%d" % (i + 1), Vector3(x, top / 2.0, z), Vector3(3, top, 3), COOL.lerp(PURPLE, i / 3.0))
		_coin(area, Vector3(x, top + 0.8, z))
	_checkpoint(area, Vector3(90.5, 4.0, z), -PI / 2.0)
	_hazard(area, "Lava", Vector3(97, -0.3, z), Vector3(10, 1, 8))
	_platform(area, "Shuttle", Vector3(93.5, 3.75, z), Vector3(3, 0.5, 3), Vector3(7, 0, 0), 2.0, 0.6)
	_block(area, "Finish", Vector3(106, 2, z), Vector3(8, 4, 6), GREEN)
	var reward := _star(area, "Parkour under 30 s", Vector3(108.5, 5.6, z), true)
	_gate(area, "FinishLine", Vector3(104.5, 4, z), PI / 2.0, 1, course, 30.0, reward)
	_station("Parkour time trial", Vector3(19, 0, z), -PI / 2.0)


func _wall_kick_chimney() -> void:
	var area := _area("WallKickChimney")
	var z := -12.0
	_block(area, "ChimneyWest", Vector3(-50.2, 11, z), Vector3(1, 22, 8), STONE)
	_block(area, "ChimneyEast", Vector3(-45.8, 12.5, z), Vector3(1, 25, 8), STONE)
	_block(area, "ChimneyTop", Vector3(-52.2, 21.75, z), Vector3(3, 0.5, 8), GREEN)
	for i in 5:
		_coin(area, Vector3(-48, 4.0 + 4.0 * i, z))
	_star(area, "Wall kick chimney", Vector3(-52.2, 23.3, z))
	_checkpoint(area, Vector3(-48, 0, z + 6.5), 0.0)
	_label(area, "Wall kick chimney", Vector3(-48, 23.8, z + 4.3), 64, GOLD)
	_label(area, "22 m · jump the moment you hit the wall", Vector3(-48, 4.5, z + 4.3), 36)
	_station("Wall kick chimney", Vector3(-48, 0, z + 8), 0.0)


func _pillar_hop() -> void:
	var area := _area("PillarHop")
	_hazard(area, "Lava", Vector3(-55, -0.3, 30), Vector3(34, 1, 16))
	_block(area, "Start", Vector3(-36, 0.5, 30), Vector3(4, 1, 4), STONE)
	_checkpoint(area, Vector3(-36, 1, 30), PI / 2.0)
	# [x, z, top]
	var pillars := [[-41.0, 30.0, 1.5], [-44.5, 32.5, 2.0], [-48.0, 30.0, 2.5], [-51.5, 27.0, 2.5],
		[-55.0, 29.0, 3.0], [-58.5, 32.0, 3.5], [-62.0, 30.0, 3.5], [-65.5, 27.5, 4.0]]
	for i in pillars.size():
		var x: float = pillars[i][0]
		var pz: float = pillars[i][1]
		var top: float = pillars[i][2]
		_cylinder(area, "Pillar%d" % (i + 1), Vector3(x, top / 2.0, pz), 1.5, top, WARM.lerp(PINK, i / 7.0))
		if i % 2 == 1:
			_coin(area, Vector3(x, top + 0.8, pz))
	_block(area, "Goal", Vector3(-70, 2.25, 28.5), Vector3(4, 4.5, 4), GREEN)
	_star(area, "Pillar hop", Vector3(-70, 5.9, 28.5))
	_label(area, "Pillar hop", Vector3(-36, 4.2, 27.2), 64, GOLD, PI / 2.0)
	_label(area, "don't touch the lava", Vector3(-36, 3.5, 27.2), 40, Color.WHITE, PI / 2.0)
	_station("Pillar hop", Vector3(-36, 1, 30), PI / 2.0)


func _sky_islands() -> void:
	var area := _area("SkyIslands")
	var z := -8.0
	_bounce_pad(area, "GroundPad", Vector3(36, 0, z), 8.5)
	for i in 4:
		_coin(area, Vector3(36, 3.0 + 1.5 * i, z))
	_block(area, "Island1", Vector3(41.5, 6.5, z), Vector3(5, 1, 5), COOL)
	_bounce_pad(area, "IslandPad", Vector3(42.5, 7, z), 9.0)
	_block(area, "Island2", Vector3(49, 14.5, z), Vector3(5, 1, 5), COOL.lightened(0.1))
	_coin_arc(area, Vector3(51.5, 15.8, z), Vector3(58.5, 15.8, z), 1.2, 5)
	_block(area, "Island3", Vector3(61, 14.5, z), Vector3(5, 1, 5), GREEN)
	_star(area, "Sky islands", Vector3(61.5, 16.4, z))
	_label(area, "Sky islands", Vector3(32.5, 4.5, z), 64, GOLD, -PI / 2.0)
	_label(area, "bounce pads · ground pound onto one to go higher", Vector3(32.5, 3.8, z), 34, Color.WHITE, -PI / 2.0)
	_station("Sky islands", Vector3(31, 0, z), -PI / 2.0)


func _backflip_cliffs() -> void:
	var area := _area("BackflipCliffs")
	for i in 3:
		var top := 4.5 * (i + 1)
		var tier_z := -28.0 - 4.0 * i
		_block(area, "Tier%d" % (i + 1), Vector3(-3, top / 2.0, tier_z), Vector3(12, top, 4), PURPLE.lerp(PINK, i / 2.0))
		_coin(area, Vector3(-3, top + 0.8, tier_z))
	_star(area, "Backflip cliffs", Vector3(-3, 15.1, -36))
	_label(area, "Backflip cliffs", Vector3(-3, 3.1, -25.9), 64, GOLD)
	_label(area, "4.5 m steps · crouch + jump", Vector3(-3, 2.4, -25.9), 40)
	_station("Backflip cliffs", Vector3(-3, 0, -24), 0.0)


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


func _coin(parent: Node, position: Vector3) -> void:
	var coin := Area3D.new()
	coin.set_script(CoinScript)
	coin.name = "Coin"
	coin.position = position
	_add(coin, parent)


## Coins along a jump arc from [param from] to [param to], peaking [param height] above the line.
func _coin_arc(parent: Node, from: Vector3, to: Vector3, height: float, count: int) -> void:
	for i in count:
		var t := (i + 1.0) / (count + 1.0)
		_coin(parent, from.lerp(to, t) + Vector3.UP * (4.0 * height * t * (1.0 - t)))


func _star(parent: Node, star_name: String, position: Vector3, hidden := false) -> Area3D:
	var star := Area3D.new()
	star.set_script(StarScript)
	star.name = "Star_" + star_name.validate_node_name()
	star.position = position
	star.set(&"star_name", star_name)
	star.set(&"hidden_until_revealed", hidden)
	_add(star, parent)
	return star


func _crate(parent: Node, crate_name: String, position: Vector3, coins: int) -> void:
	var crate := StaticBody3D.new()
	crate.set_script(CrateScript)
	crate.name = crate_name
	crate.position = position
	crate.set(&"coins", coins)
	_add(crate, parent)


func _bounce_pad(parent: Node, pad_name: String, position: Vector3, height: float) -> void:
	var pad := StaticBody3D.new()
	pad.set_script(BouncePadScript)
	pad.name = pad_name
	pad.position = position
	pad.set(&"height", height)
	_add(pad, parent)


func _hazard(parent: Node, hazard_name: String, center: Vector3, size: Vector3) -> void:
	var hazard := Area3D.new()
	hazard.set_script(HazardScript)
	hazard.name = hazard_name
	hazard.position = center
	hazard.set(&"size", size)
	_add(hazard, parent)


func _checkpoint(parent: Node, position: Vector3, yaw: float) -> void:
	var checkpoint := Area3D.new()
	checkpoint.set_script(CheckpointScript)
	checkpoint.name = "Checkpoint"
	checkpoint.position = position
	checkpoint.rotation.y = yaw
	_add(checkpoint, parent)


## A time trial start ([param role] 0) or finish (1) line across the course.
func _gate(parent: Node, gate_name: String, position: Vector3, yaw: float, role: int, course: String, par_time := 0.0, reward: Node = null) -> void:
	var gate := Area3D.new()
	gate.set_script(GateScript)
	gate.name = gate_name
	gate.position = position
	gate.rotation.y = yaw
	gate.set(&"role", role)
	gate.set(&"course", course)
	gate.set(&"par_time", par_time)
	if reward:
		gate.set(&"reward", reward)
	_add(gate, parent)


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
