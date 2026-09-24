class_name Synth
extends RefCounted
## Tiny procedural sound synthesizer for placeholder sound effects.
##
## Builds short sounds from pitch sweeps and filtered noise, so the project
## needs no audio assets. [method sound] returns shared, cached level sounds
## (coins, stars, crates, springs); the player's own sounds live in
## PlayerAudio. Swap any of them for real recordings later.
##
## Generating a sound takes a few milliseconds, so [method prepare] builds
## them all while the game loads rather than the first time each one plays.

const RATE := 22050
## Every sound [method sound] can build.
const NAMES: Array[StringName] = [&"coin", &"star", &"reveal", &"crate", &"spring", &"checkpoint", &"sizzle", &"whistle"]

static var _cache: Dictionary[StringName, AudioStreamWAV] = {}


## A named, cached sound for level props.
static func sound(sound_name: StringName) -> AudioStreamWAV:
	if not _cache.has(sound_name):
		_cache[sound_name] = _build(sound_name)
	return _cache[sound_name]


## Builds every sound in [constant NAMES] now (call while loading).
static func prepare() -> void:
	for sound_name in NAMES:
		sound(sound_name)


## Plays [param stream] at [param position] in the world of [param context],
## on a temporary positional player that frees itself when done.
static func play_at(context: Node, stream: AudioStream, position: Vector3, volume_db := -6.0, pitch := 1.0) -> void:
	if stream == null or not context.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.unit_size = 8.0
	var tree := context.get_tree()
	var parent: Node = tree.current_scene if tree.current_scene else tree.root
	parent.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	# Backup in case "finished" never arrives (e.g. with no audio device).
	tree.create_timer(stream.get_length() / maxf(pitch, 0.01) + 0.5).timeout.connect(player.queue_free)
	player.play()


static func _build(sound_name: StringName) -> AudioStreamWAV:
	match sound_name:
		&"coin":
			return to_stream(mix([sweep(0.07, 1320.0, 1320.0, 0.35, 0.0, true), delay(sweep(0.2, 1760.0, 1760.0, 0.35, 0.0, true), 0.06)]))
		&"star":
			var notes: Array[PackedFloat32Array] = []
			for i in 4:
				notes.append(delay(sweep(0.3, 523.25 * pow(2.0, [0, 4, 7, 12][i] / 12.0), 523.25 * pow(2.0, [0, 4, 7, 12][i] / 12.0), 0.3, 6.0, true), 0.09 * i))
			return to_stream(mix(notes))
		&"reveal":
			return to_stream(sweep(0.5, 300.0, 1200.0, 0.35, 9.0, true))
		&"crate":
			return to_stream(mix([noise(0.18, 3000.0, 0.8), sweep(0.1, 240.0, 90.0, 0.7, 0.0)]))
		&"spring":
			return to_stream(sweep(0.35, 180.0, 620.0, 0.45, 11.0, true))
		&"checkpoint":
			return to_stream(mix([sweep(0.12, 660.0, 660.0, 0.3, 0.0, true), delay(sweep(0.25, 990.0, 990.0, 0.3, 0.0, true), 0.1)]))
		&"sizzle":
			return to_stream(noise(0.35, 5000.0, 0.5, true, 30.0))
		&"whistle":
			return to_stream(sweep(0.3, 1400.0, 1400.0, 0.3, 14.0, true))
	push_warning("Synth: unknown sound '%s'." % sound_name)
	return to_stream(PackedFloat32Array([0.0]))


## A pitch sweep with a punchy envelope. Square-ish unless [param pure] (sine).
static func sweep(duration: float, from_hz: float, to_hz: float, volume: float, vibrato_hz: float, pure := false) -> PackedFloat32Array:
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
		samples[i] = wave * volume * envelope(t, duration)
	return samples


## Low-passed white noise. [param swell] fades it in and out (a whoosh);
## [param tremolo_hz] pulses it.
static func noise(duration: float, cutoff_hz: float, volume: float, swell := false, tremolo_hz := 0.0) -> PackedFloat32Array:
	var count := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var smoothing := 1.0 - exp(-TAU * cutoff_hz / RATE)
	var filtered := 0.0
	for i in count:
		var t := float(i) / count
		filtered += smoothing * (randf_range(-1.0, 1.0) - filtered)
		var gain := sin(PI * t) if swell else envelope(t, duration)
		if tremolo_hz > 0.0:
			gain *= 0.6 + 0.4 * sin(TAU * tremolo_hz * i / RATE)
		samples[i] = filtered * volume * gain * 2.0
	return samples


## Quick attack, then an exponential-ish decay.
static func envelope(t: float, duration: float) -> float:
	var attack := minf(0.005 / duration, 0.2)
	if t < attack:
		return t / attack
	return pow(1.0 - (t - attack) / (1.0 - attack), 1.6)


## Sums sample buffers of any lengths.
static func mix(layers: Array[PackedFloat32Array]) -> PackedFloat32Array:
	var mixed := PackedFloat32Array()
	for layer in layers:
		if layer.size() > mixed.size():
			mixed.resize(layer.size())
		for i in layer.size():
			mixed[i] += layer[i]
	return mixed


## Prepends [param seconds] of silence.
static func delay(samples: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var padded := PackedFloat32Array()
	padded.resize(int(seconds * RATE))
	padded.append_array(samples)
	return padded


static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
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
