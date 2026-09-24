class_name PlayerAudio
extends Node
## Placeholder sound effects for the player's moves, synthesized at startup.
##
## Every sound is generated in code (sweeps, noise bursts, envelopes), so the
## project needs no audio assets. Replace [member sounds] entries with real
## AudioStreams whenever you have them; the triggers stay the same.

const RATE := 22050
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
		&"long_jump":
			play(&"long_jump", -6.0)
		&"wall_kick":
			play(&"wall_kick", -7.0)
		&"rollout":
			play(&"jump", -10.0, 0.85)


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
	sounds[&"jump"] = _to_stream(_sweep(0.13, 300.0, 620.0, 0.5, 0.0))
	sounds[&"jump_big"] = _to_stream(_sweep(0.26, 360.0, 980.0, 0.45, 7.0))
	sounds[&"long_jump"] = _to_stream(_mix([_sweep(0.24, 520.0, 340.0, 0.35, 0.0), _noise(0.24, 2500.0, 0.3)]))
	sounds[&"wall_kick"] = _to_stream(_mix([_sweep(0.09, 700.0, 380.0, 0.4, 0.0), _noise(0.06, 3000.0, 0.3)]))
	sounds[&"dive"] = _to_stream(_noise(0.26, 1800.0, 0.6, true))
	sounds[&"spin"] = _to_stream(_noise(0.36, 3200.0, 0.5, true, 22.0))
	sounds[&"land"] = _to_stream(_mix([_sweep(0.09, 130.0, 55.0, 0.9, 0.0, true), _noise(0.06, 900.0, 0.35)]))
	sounds[&"ground_pound_spin"] = _to_stream(_sweep(0.16, 900.0, 420.0, 0.3, 0.0))
	sounds[&"ground_pound_impact"] = _to_stream(_mix([_sweep(0.4, 95.0, 32.0, 1.0, 0.0, true), _noise(0.22, 700.0, 0.8)]))
	sounds[&"bonk"] = _to_stream(_mix([_sweep(0.14, 340.0, 170.0, 0.55, 0.0), _sweep(0.05, 900.0, 900.0, 0.25, 0.0, true)]))
	sounds[&"wall_touch"] = _to_stream(_mix([_sweep(0.06, 220.0, 150.0, 0.7, 0.0, true), _noise(0.04, 1500.0, 0.4)]))
	sounds[&"grab"] = _to_stream(_mix([_noise(0.025, 4000.0, 0.5), _sweep(0.04, 1300.0, 1100.0, 0.25, 0.0, true)]))
	var skid := _to_stream(_noise(1.0, 1400.0, 0.5))
	skid.loop_mode = AudioStreamWAV.LOOP_FORWARD
	skid.loop_end = RATE
	sounds[&"skid"] = skid


## A pitch sweep with a punchy envelope. Square-ish unless [param pure] (sine).
func _sweep(duration: float, from_hz: float, to_hz: float, volume: float, vibrato_hz: float, pure := false) -> PackedFloat32Array:
	var count := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var frequency := lerpf(from_hz, to_hz, t * (2.0 - t))
		if vibrato_hz > 0.0:
			frequency *= 1.0 + 0.04 * sin(TAU * vibrato_hz * i / RATE)
		phase += TAU * frequency / RATE
		var wave := sin(phase)
		if not pure:
			wave = 0.55 * signf(wave) + 0.45 * wave
		samples[i] = wave * volume * _envelope(t, duration)
	return samples


## Low-passed white noise. [param swell] fades it in and out (a whoosh);
## [param tremolo_hz] pulses it.
func _noise(duration: float, cutoff_hz: float, volume: float, swell := false, tremolo_hz := 0.0) -> PackedFloat32Array:
	var count := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var smoothing := 1.0 - exp(-TAU * cutoff_hz / RATE)
	var filtered := 0.0
	for i in count:
		var t := float(i) / count
		filtered += smoothing * (randf_range(-1.0, 1.0) - filtered)
		var gain := sin(PI * t) if swell else _envelope(t, duration)
		if tremolo_hz > 0.0:
			gain *= 0.6 + 0.4 * sin(TAU * tremolo_hz * i / RATE)
		samples[i] = filtered * volume * gain * 2.0
	return samples


## Quick attack, then an exponential-ish decay.
func _envelope(t: float, duration: float) -> float:
	var attack := minf(0.005 / duration, 0.2)
	if t < attack:
		return t / attack
	return pow(1.0 - (t - attack) / (1.0 - attack), 1.6)


## Sums sample buffers of any lengths.
func _mix(layers: Array[PackedFloat32Array]) -> PackedFloat32Array:
	var mixed := PackedFloat32Array()
	for layer in layers:
		if layer.size() > mixed.size():
			mixed.resize(layer.size())
		for i in layer.size():
			mixed[i] += layer[i]
	return mixed


func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
