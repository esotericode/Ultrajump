class_name PlayerAudio
extends Node
## Placeholder sound effects for the player's moves, synthesized at startup.
##
## Every sound is generated in code with [Synth] (sweeps, noise bursts,
## envelopes), so the project needs no audio assets. Replace [member sounds]
## entries with real AudioStreams whenever you have them; the triggers stay the same.

const VOICES := 6

## Generated sounds by name. Swap any entry for an imported stream.
var sounds: Dictionary[StringName, AudioStream] = {}
var player: Player

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _skid: AudioStreamPlayer


func _ready() -> void:
	player = get_parent() as Player
	if player == null:
		push_warning("PlayerAudio expects to be a child of a Player.")
		return
	_generate()
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_skid = AudioStreamPlayer.new()
	_skid.stream = sounds[&"skid"]
	_skid.volume_db = -14.0
	add_child(_skid)

	player.jumped.connect(_on_jumped)
	player.attacked.connect(_on_attacked)
	player.attack_landed.connect(func(_kind: StringName, _where: Vector3) -> void: play(&"hit", -4.0))
	player.landed.connect(_on_landed)
	player.state_changed.connect(_on_state_changed)
	player.ground_pound_impact.connect(play.bind(&"ground_pound_impact", -2.0))
	player.bonked.connect(func(_normal: Vector3) -> void: play(&"bonk", -4.0))
	player.ledge_grabbed.connect(play.bind(&"grab", -8.0))
	player.spun.connect(func(in_air: bool) -> void: play(&"spin", -8.0 if in_air else -12.0))


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var sliding := player.state_name in [&"Skid", &"CrouchSlide", &"BellySlide", &"SteepSlide"]
	var speed := player.horizontal_speed()
	if sliding and speed > 1.5:
		if not _skid.playing:
			_skid.play()
		_skid.volume_db = linear_to_db(clampf(speed / 12.0, 0.05, 1.0)) - 12.0
		_skid.pitch_scale = 0.8 + clampf(speed / 20.0, 0.0, 0.6)
	elif _skid.playing:
		_skid.stop()


## Plays a sound by name with a little random pitch variation.
func play(sound: StringName, volume_db := -6.0, pitch := 1.0) -> void:
	var stream: AudioStream = sounds.get(sound)
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = pitch * randf_range(0.96, 1.04)
	voice.play()


func _on_jumped(kind: StringName) -> void:
	match kind:
		&"single", &"ledge_jump", &"steep_jump":
			play(&"jump", -9.0)
		&"double":
			play(&"jump", -8.0, 1.2)
		&"triple":
			play(&"jump_big", -6.0, 1.1)
		&"backflip", &"side_flip", &"ground_pound_jump":
			play(&"jump_big", -6.0)
		&"bounce":
			play(&"boing", -6.0)
		&"long_jump":
			play(&"long_jump", -6.0)
		&"wall_kick":
			play(&"wall_kick", -7.0)
		&"rollout":
			play(&"jump", -10.0, 0.85)


func _on_attacked(kind: StringName) -> void:
	match kind:
		&"punch_1":
			play(&"swing", -10.0, 1.1)
		&"punch_2":
			play(&"swing", -10.0, 1.25)
		&"kick":
			play(&"swing", -8.0, 0.8)
		&"slide_kick":
			play(&"swing", -8.0, 0.7)


func _on_landed(impact_speed: float) -> void:
	if impact_speed > 3.0:
		play(&"land", linear_to_db(clampf(impact_speed / 25.0, 0.15, 1.0)) - 4.0)


func _on_state_changed(_previous: StringName, current: StringName) -> void:
	match current:
		&"Dive":
			play(&"dive", -8.0)
		&"GroundPound":
			play(&"ground_pound_spin", -9.0)
		&"WallContact":
			play(&"wall_touch", -5.0)


# --- Synthesis -------------------------------------------------------------------

func _generate() -> void:
	sounds[&"jump"] = Synth.to_stream(Synth.sweep(0.13, 300.0, 620.0, 0.5, 0.0))
	sounds[&"jump_big"] = Synth.to_stream(Synth.sweep(0.26, 360.0, 980.0, 0.45, 7.0))
	sounds[&"long_jump"] = Synth.to_stream(Synth.mix([Synth.sweep(0.24, 520.0, 340.0, 0.35, 0.0), Synth.noise(0.24, 2500.0, 0.3)]))
	sounds[&"wall_kick"] = Synth.to_stream(Synth.mix([Synth.sweep(0.09, 700.0, 380.0, 0.4, 0.0), Synth.noise(0.06, 3000.0, 0.3)]))
	sounds[&"dive"] = Synth.to_stream(Synth.noise(0.26, 1800.0, 0.6, true))
	sounds[&"spin"] = Synth.to_stream(Synth.noise(0.36, 3200.0, 0.5, true, 22.0))
	sounds[&"land"] = Synth.to_stream(Synth.mix([Synth.sweep(0.09, 130.0, 55.0, 0.9, 0.0, true), Synth.noise(0.06, 900.0, 0.35)]))
	sounds[&"ground_pound_spin"] = Synth.to_stream(Synth.sweep(0.16, 900.0, 420.0, 0.3, 0.0))
	sounds[&"ground_pound_impact"] = Synth.to_stream(Synth.mix([Synth.sweep(0.4, 95.0, 32.0, 1.0, 0.0, true), Synth.noise(0.22, 700.0, 0.8)]))
	sounds[&"bonk"] = Synth.to_stream(Synth.mix([Synth.sweep(0.14, 340.0, 170.0, 0.55, 0.0), Synth.sweep(0.05, 900.0, 900.0, 0.25, 0.0, true)]))
	sounds[&"swing"] = Synth.to_stream(Synth.noise(0.11, 4200.0, 0.55, true))
	sounds[&"hit"] = Synth.to_stream(Synth.mix([Synth.sweep(0.08, 180.0, 70.0, 0.9, 0.0, true), Synth.noise(0.07, 2600.0, 0.6)]))
	sounds[&"boing"] = Synth.sound(&"spring")
	sounds[&"wall_touch"] = Synth.to_stream(Synth.mix([Synth.sweep(0.06, 220.0, 150.0, 0.7, 0.0, true), Synth.noise(0.04, 1500.0, 0.4)]))
	sounds[&"grab"] = Synth.to_stream(Synth.mix([Synth.noise(0.025, 4000.0, 0.5), Synth.sweep(0.04, 1300.0, 1100.0, 0.25, 0.0, true)]))
	var skid := Synth.to_stream(Synth.noise(1.0, 1400.0, 0.5))
	skid.loop_mode = AudioStreamWAV.LOOP_FORWARD
	skid.loop_end = Synth.RATE
	sounds[&"skid"] = skid
