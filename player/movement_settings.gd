class_name MovementSettings
extends Resource
## Every tunable number behind the player's movement, in one place.
##
## Values can be edited in the inspector, or live while playing from the
## in-game tuning panel (F2), which can also save them back to disk.
## Units: meters, seconds, m/s, m/s², degrees. Jump strengths are expressed as
## the apex height they reach (with the jump button held), not as raw
## velocities, so they stay meaningful when gravity is changed.

@export_group("Ground")
## Top running speed at full stick tilt.
@export_range(1.0, 30.0, 0.1, "suffix:m/s") var run_speed := 10.0
## Speed reached instantly when starting to run. Makes starts feel responsive.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var run_start_speed := 3.0
## Acceleration toward the target run speed.
@export_range(1.0, 150.0, 0.5, "suffix:m/s²") var run_acceleration := 26.0
## Deceleration when the stick is released.
@export_range(1.0, 200.0, 0.5, "suffix:m/s²") var run_deceleration := 45.0
## How fast speed above [member run_speed] bleeds off while grounded (e.g. after a long jump lands).
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var overspeed_deceleration := 14.0
## Turn rate while moving slowly.
@export_range(0.0, 3000.0, 10.0, "suffix:°/s") var turn_speed_slow := 1080.0
## Turn rate at full run speed. Lower values give wider, weightier turns.
@export_range(0.0, 3000.0, 10.0, "suffix:°/s") var turn_speed_fast := 460.0
## Steepest slope that counts as walkable ground. Steeper surfaces make you slide.
@export_range(1.0, 89.0, 1.0, "suffix:°") var max_floor_angle := 46.0
## How much slopes slow you uphill and speed you up downhill while running.
@export_range(0.0, 1.0, 0.01) var slope_speed_influence := 0.3
## Tallest step you can walk up without jumping.
@export_range(0.0, 1.0, 0.01, "suffix:m") var step_height := 0.35

@export_group("Skid & Side Flip")
## Reversing the stick by more than this angle while running fast triggers a skid.
@export_range(60.0, 180.0, 1.0, "suffix:°") var skid_angle := 130.0
## Minimum speed for a reversal to skid instead of just turning.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var skid_min_speed := 5.0
@export_range(1.0, 200.0, 0.5, "suffix:m/s²") var skid_deceleration := 42.0
## The skid always ends (and you turn around) after this long.
@export_range(0.05, 1.0, 0.01, "suffix:s") var skid_max_time := 0.3
## Jump during a skid to side flip.
@export_range(0.5, 15.0, 0.05, "suffix:m") var side_flip_height := 4.3
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var side_flip_speed := 4.5

@export_group("Crouch & Slide")
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var crawl_speed := 2.5
## Crouching faster than this starts a crouch slide (jump out of it to long jump).
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var crouch_slide_min_speed := 4.0
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var crouch_slide_friction := 11.0
## Fraction of gravity that pulls slides (crouch and belly) down walkable slopes.
@export_range(0.0, 3.0, 0.05) var slide_slope_acceleration := 0.9
@export_range(0.0, 1080.0, 5.0, "suffix:°/s") var slide_turn_speed := 120.0
@export_range(1.0, 50.0, 0.5, "suffix:m/s") var slide_max_speed := 22.0

@export_group("Air")
## Gravity while rising. Every other gravity value is a multiplier of this one.
@export_range(1.0, 200.0, 0.5, "suffix:m/s²") var gravity := 40.0
## Gravity multiplier while falling. Higher values give snappier, less floaty descents.
@export_range(0.5, 5.0, 0.05) var fall_gravity_multiplier := 1.35
## Gravity multiplier while rising with the jump button released (variable jump height).
@export_range(1.0, 10.0, 0.1) var jump_release_gravity_multiplier := 3.0
## Vertical speeds closer to zero than this count as the apex of a jump.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var apex_speed_threshold := 2.5
## Gravity multiplier at the apex while jump is held. Lower = floatier hang time.
@export_range(0.05, 1.0, 0.01) var apex_gravity_multiplier := 0.55
@export_range(1.0, 100.0, 0.5, "suffix:m/s") var terminal_velocity := 32.0
@export_range(0.0, 150.0, 0.5, "suffix:m/s²") var air_acceleration := 24.0
## Air control can push you up to this speed. Faster momentum is kept, not clamped.
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var air_max_speed := 10.0
## How quickly speed above [member air_max_speed] decays while airborne.
@export_range(0.0, 50.0, 0.1, "suffix:m/s²") var air_overspeed_drag := 2.0
## Horizontal drag while airborne with the stick released.
@export_range(0.0, 50.0, 0.1, "suffix:m/s²") var air_idle_drag := 3.0
## How fast the character turns to face its air velocity.
@export_range(0.0, 3000.0, 10.0, "suffix:°/s") var air_turn_speed := 540.0
## Grace period after running off a ledge during which you can still jump.
@export_range(0.0, 0.5, 0.01, "suffix:s") var coyote_time := 0.1
## Presses this early before landing (or touching a wall) still count.
@export_range(0.0, 0.5, 0.01, "suffix:s") var input_buffer_time := 0.12

@export_group("Jump Chain")
@export_range(0.5, 15.0, 0.05, "suffix:m") var single_jump_height := 2.1
@export_range(0.5, 15.0, 0.05, "suffix:m") var double_jump_height := 3.0
@export_range(0.5, 15.0, 0.05, "suffix:m") var triple_jump_height := 4.6
## Jumping again within this time after landing continues the chain.
@export_range(0.0, 1.0, 0.01, "suffix:s") var jump_chain_window := 0.2
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var double_jump_min_speed := 1.0
## You need at least this much speed for the third jump of the chain.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var triple_jump_min_speed := 6.5

@export_group("Backflip")
## Jump while crouching (standing still) to backflip.
@export_range(0.5, 15.0, 0.05, "suffix:m") var backflip_height := 4.9
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var backflip_back_speed := 3.5
@export_range(0.0, 2.0, 0.05) var backflip_air_control := 0.4

@export_group("Long Jump")
## Jump during a crouch slide to long jump.
@export_range(0.2, 10.0, 0.05, "suffix:m") var long_jump_height := 1.5
## Your speed is multiplied by this on takeoff...
@export_range(1.0, 3.0, 0.05) var long_jump_speed_multiplier := 1.6
## ...and clamped to this.
@export_range(1.0, 40.0, 0.5, "suffix:m/s") var long_jump_max_speed := 18.0
## Crouch slides slower than this backflip instead of long jumping.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var long_jump_min_speed := 4.0
@export_range(0.1, 2.0, 0.05) var long_jump_gravity_scale := 0.7
@export_range(0.0, 2.0, 0.05) var long_jump_air_control := 0.35

@export_group("Dive")
## Dive (in the air, or while running) to launch forward. Land to belly slide.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var dive_speed_boost := 3.0
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var dive_min_speed := 11.0
## The boost never pushes you past this speed (existing momentum is kept).
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var dive_max_speed := 16.0
## Upward pop when diving from the ground.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var dive_ground_hop := 5.5
## Minimum upward speed after an air dive.
@export_range(-10.0, 20.0, 0.1, "suffix:m/s") var dive_air_hop := 3.0
@export_range(0.1, 3.0, 0.05) var dive_gravity_scale := 0.9
@export_range(0.0, 720.0, 5.0, "suffix:°/s") var dive_steering := 90.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s²") var dive_air_drag := 1.5
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var belly_slide_friction := 9.0
@export_range(0.0, 720.0, 5.0, "suffix:°/s") var belly_slide_turn_speed := 90.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var belly_slide_getup_time := 0.18
## Jump (or dive) during a belly slide to roll out of it.
@export_range(0.2, 10.0, 0.05, "suffix:m") var rollout_height := 1.3

@export_group("Ground Pound")
## Crouch in the air to ground pound. The character flips in place for this long...
@export_range(0.0, 1.0, 0.01, "suffix:s") var ground_pound_hang_time := 0.28
## ...then drops at this speed.
@export_range(1.0, 100.0, 0.5, "suffix:m/s") var ground_pound_drop_speed := 30.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var ground_pound_land_time := 0.3
## Jump right after a ground pound lands for an extra high jump.
@export_range(0.5, 15.0, 0.05, "suffix:m") var ground_pound_jump_height := 5.3
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var ground_pound_jump_speed := 3.0
## Diving out of a ground pound is allowed after this long.
@export_range(0.0, 0.5, 0.01, "suffix:s") var ground_pound_dive_delay := 0.08

@export_group("Wall Slide & Kick")
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var wall_slide_speed := 3.5
## How quickly a fast fall is braked down to [member wall_slide_speed].
@export_range(1.0, 200.0, 0.5, "suffix:m/s²") var wall_slide_deceleration := 50.0
## Walls closer to the ground than this are ignored (you just land instead).
@export_range(0.0, 5.0, 0.05, "suffix:m") var wall_slide_min_height := 0.6
## Minimum speed into a wall (or stick push toward it) to latch on.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var wall_slide_min_approach_speed := 1.0
## Hold away from the wall this long to let go.
@export_range(0.0, 1.0, 0.01, "suffix:s") var wall_release_time := 0.15
@export_range(0.5, 15.0, 0.05, "suffix:m") var wall_kick_height := 2.6
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var wall_kick_speed := 7.5
## Air control is reduced for this long after a kick so you don't steer straight back.
@export_range(0.0, 1.0, 0.01, "suffix:s") var wall_kick_control_lock := 0.22
## How much the stick can angle a wall kick along the wall.
@export_range(0.0, 1.0, 0.01) var wall_kick_input_influence := 0.5
## The same wall can't be grabbed again for this long after leaving it.
@export_range(0.0, 1.0, 0.01, "suffix:s") var wall_regrab_cooldown := 0.25

@export_group("Ledge Grab")
@export var ledge_grab_enabled := true
## Ledge tops between these heights (above your feet) are grabbed and hung from.
@export_range(0.0, 3.0, 0.05, "suffix:m") var ledge_min_height := 1.0
@export_range(0.0, 3.0, 0.05, "suffix:m") var ledge_max_height := 2.0
## Falling past a ledge that's below your hands but above your feet pulls you
## straight up onto it, instead of scraping down the wall.
@export var ledge_mantle_enabled := true
## How far below the ledge top your feet hang.
@export_range(0.5, 2.5, 0.01, "suffix:m") var ledge_hang_depth := 1.45
## Ledges are only grabbed when rising slower than this (or falling).
@export_range(-10.0, 20.0, 0.1, "suffix:m/s") var ledge_grab_max_rise_speed := 2.0
@export_range(0.05, 1.0, 0.01, "suffix:s") var ledge_climb_time := 0.3
## Jump while hanging to hop up and over the ledge.
@export_range(0.5, 15.0, 0.05, "suffix:m") var ledge_jump_height := 2.3
## Inputs are ignored for this long after grabbing, to avoid accidental climbs/drops.
@export_range(0.0, 1.0, 0.01, "suffix:s") var ledge_input_delay := 0.12
@export_range(0.0, 2.0, 0.01, "suffix:s") var ledge_regrab_cooldown := 0.35

@export_group("Air Spin")
## Spin in the air once per jump for a little lift and extra control.
@export_range(0.0, 10.0, 0.05, "suffix:m") var spin_height := 1.0
@export_range(0.05, 2.0, 0.01, "suffix:s") var spin_duration := 0.45
@export_range(0.05, 2.0, 0.05) var spin_gravity_scale := 0.6
@export_range(0.0, 3.0, 0.05) var spin_air_control := 1.3

@export_group("Bonk")
## Diving head-first into a wall faster than this bonks you off it.
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var bonk_min_speed := 6.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var bonk_knockback := 5.0
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var bonk_hop := 4.0
@export_range(0.0, 2.0, 0.01, "suffix:s") var bonk_stun_time := 0.35

@export_group("Steep Slopes")
## Jump off a steep slope while sliding down it.
@export_range(0.2, 10.0, 0.05, "suffix:m") var steep_jump_height := 1.8
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var steep_jump_speed := 6.0
@export_range(0.0, 720.0, 5.0, "suffix:°/s") var steep_slide_steering := 60.0


## Initial upward speed needed to reach [param height] with the jump button held,
## accounting for the reduced apex gravity. [param gravity_scale] scales all gravity.
func jump_velocity(height: float, gravity_scale := 1.0, apex_hang := true) -> float:
	var g := gravity * gravity_scale
	var speed: float
	var threshold := apex_speed_threshold
	var g_apex := g * apex_gravity_multiplier
	var apex_zone_height := threshold * threshold / (2.0 * g_apex)
	if not apex_hang:
		speed = sqrt(2.0 * g * height)
	elif height <= apex_zone_height:
		speed = sqrt(2.0 * g_apex * height)
	else:
		speed = sqrt(2.0 * g * (height - apex_zone_height) + threshold * threshold)
	# Stepping physics in discrete ticks loses about half a tick of rise;
	# add it back so the apex matches the configured height.
	return speed + 0.5 * g / Engine.physics_ticks_per_second
