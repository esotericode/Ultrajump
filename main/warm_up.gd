class_name WarmUp
extends CanvasLayer
## A brief black loading cover that gets first-time costs out of the way.
##
## Godot compiles a material's shaders the first time it is drawn, and the
## level sounds are synthesized the first time they play. Either can stall a
## frame mid-game: the "first time" stutter on the first landing, coin, crate
## or star. Behind this cover, [method run] builds every sound and draws one
## of each effect right in front of the camera, then clears them away and
## fades in.
##
## Anything new that first appears mid-game (an effect, a material swapped in
## later) should get a warm_up() and be added to [method run]. Check with
## tests/first_use_check.gd, which reports anything still compiled during play.

signal finished

## Rendered frames the samples stay in view (they compile on the first).
@export var sample_frames := 3
@export var fade_time := 0.3

var _cover: ColorRect


func _init() -> void:
	name = "WarmUp"
	layer = 100
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)


## Warms everything up, fades the cover out and frees itself. Add it to the
## tree first: it covers the screen from the first frame.
func run(player: Player, hud: DebugHud = null) -> void:
	Synth.prepare()
	# Let the camera settle behind the player first.
	await get_tree().process_frame
	var camera := get_viewport().get_camera_3d()
	if camera:
		var stage := Node3D.new()
		stage.name = "WarmUpStage"
		# Placed once and never moved, so it has nothing to interpolate.
		stage.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		player.get_parent().add_child(stage)
		stage.global_transform = camera.global_transform.translated_local(Vector3(0, 0, -3))
		PropFx.warm_up(stage)
		Star.warm_up(stage)
		Checkpoint.warm_up(stage)
		var effects := player.get_node_or_null(^"Effects") as PlayerEffects
		if effects:
			effects.warm_up(stage)
		if hud:
			hud.warm_up()
		for i in sample_frames:
			await get_tree().process_frame
		stage.queue_free()
	var tween := create_tween()
	tween.tween_property(_cover, ^"color:a", 0.0, fade_time)
	await tween.finished
	finished.emit()
	queue_free()
