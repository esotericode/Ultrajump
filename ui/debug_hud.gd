class_name DebugHud
extends CanvasLayer
## On-screen readouts and tools for tuning movement.
##
## F1 controls & move list · F2 tuning panel · F3 slow motion ·
## F4 trajectory trail · F5 hide/show the readout.

signal time_scale_changed(scale: float)

const TIME_SCALES: Array[float] = [1.0, 0.5, 0.25, 0.1]
const HISTORY_LENGTH := 8

const HELP := """[b]CONTROLS[/b]   keyboard · gamepad
[color=#ffd479]WASD[/color] · L-stick   move
[color=#ffd479]Mouse, arrows[/color] · R-stick   camera
[color=#ffd479]Space[/color] · A   jump
[color=#ffd479]Shift, C[/color] · LT, RT, B   crouch
[color=#ffd479]E, left click[/color] · X   dive
[color=#ffd479]Q, right click[/color] · Y, RB   spin
[color=#ffd479]Ctrl[/color]   walk      [color=#ffd479]R[/color] · Back   respawn
[color=#ffd479]Tab, middle click[/color] · LB   recenter camera
[color=#ffd479]Esc[/color] · Start   free the mouse

[b]MOVES[/b]
[color=#9fe870]Double / triple jump[/color]  jump again as you land
[color=#9fe870]Backflip[/color]  crouch, then jump
[color=#9fe870]Long jump[/color]  run, crouch, jump
[color=#9fe870]Side flip[/color]  reverse while running, jump
[color=#9fe870]Dive → rollout[/color]  dive, jump as you land
[color=#9fe870]Ground pound[/color]  crouch in the air
     then jump (big jump) or dive (cancel)
[color=#9fe870]Wall kick[/color]  jump into a wall, jump
[color=#9fe870]Ledge grab[/color]  push in, jump, or pull away
[color=#9fe870]Spin[/color]  in the air, once per jump

[b]DEBUG[/b]  F1 help · F2 tuning · F3 slow-mo
F4 trail · F5 readout · 1-9 teleport"""

@export var player: Player
@export var trail: TrajectoryTrail

## Names of the teleport stations, listed in the help.
var station_names: PackedStringArray = []:
	set(value):
		station_names = value
		_refresh_help()

var _readout: Label
var _history: Label
var _help: RichTextLabel
var _help_panel: PanelContainer
var _tuning: TuningPanel
var _events: Array[String] = []
var _time_scale_index := 0
var _clock := 0.0


func _ready() -> void:
	layer = 10
	_build()
	if player:
		player.state_changed.connect(_on_state_changed)
		_tuning.setup(player.settings)
	_tuning.visible = false
	if trail:
		trail.visible = false


func _process(delta: float) -> void:
	_clock += delta / maxf(Engine.time_scale, 0.001)
	if player:
		_readout.text = _describe()


## True while the tuning panel is being used, so gameplay should ignore input.
func wants_input() -> bool:
	return _tuning.wants_input


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			_help_panel.visible = not _help_panel.visible
			if _help_panel.visible:
				_tuning.visible = false
		KEY_F2:
			_tuning.visible = not _tuning.visible
			# The panel and the help share the right side of the screen.
			if _tuning.visible:
				_help_panel.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _tuning.visible else Input.MOUSE_MODE_CAPTURED
		KEY_F3:
			_time_scale_index = (_time_scale_index + 1) % TIME_SCALES.size()
			Engine.time_scale = TIME_SCALES[_time_scale_index]
			time_scale_changed.emit(Engine.time_scale)
		KEY_F4:
			if trail:
				trail.visible = not trail.visible
				trail.clear()
		KEY_F5:
			_readout.get_parent().visible = not _readout.get_parent().visible
			_history.visible = _readout.get_parent().visible
		_:
			return
	get_viewport().set_input_as_handled()


func _describe() -> String:
	var state := player.state_machine.current
	var state_label := String(state.name)
	var kind: Variant = state.get(&"kind")
	if kind != null:
		state_label += " (%s)" % kind
	var lines: Array[String] = [
		"State   %s" % state_label,
		"Speed   %5.2f m/s   vertical %+6.2f m/s" % [player.horizontal_speed(), player.velocity.y],
		"Chain   %d    spin %s    ground %s" % [player.jump_chain, "ready" if player.air_spin_available else "used", "yes" if player.is_on_floor() else "no"],
		"Last air   %.2f m high · %.2f m far · %.2f s" % [player.last_air_height, player.last_air_distance, player.last_air_time],
		"%d fps · time ×%s%s" % [Engine.get_frames_per_second(), Engine.time_scale, "   [trail]" if trail and trail.visible else ""],
	]
	return "\n".join(lines)


func _on_state_changed(_previous: StringName, current: StringName) -> void:
	_events.push_front("%7.2f  %s" % [_clock, current])
	if _events.size() > HISTORY_LENGTH:
		_events.resize(HISTORY_LENGTH)
	_history.text = "\n".join(_events)


func _refresh_help() -> void:
	if _help == null:
		return
	var text := HELP
	if not station_names.is_empty():
		text += "\n\n[b]STATIONS[/b]"
		for i in station_names.size():
			text += "\n%d  %s" % [i + 1, station_names[i]]
	_help.text = text


func _build() -> void:
	var font_settings := LabelSettings.new()
	font_settings.font_size = 14
	font_settings.outline_size = 4
	font_settings.outline_color = Color(0, 0, 0, 0.8)

	var readout_panel := _panel(Color(0.05, 0.06, 0.09, 0.6))
	readout_panel.position = Vector2(12, 12)
	add_child(readout_panel)
	_readout = Label.new()
	_readout.label_settings = font_settings
	_readout.add_theme_font_override(&"font", _monospace())
	readout_panel.add_child(_readout)

	_history = Label.new()
	_history.label_settings = font_settings.duplicate()
	_history.label_settings.font_color = Color(1, 1, 1, 0.7)
	_history.add_theme_font_override(&"font", _monospace())
	_history.position = Vector2(20, 150)
	add_child(_history)

	# Top-right, clear of the character in the middle of the screen.
	_help_panel = _panel(Color(0.05, 0.06, 0.09, 0.7))
	_help_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 12)
	_help_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_help_panel)
	_help = RichTextLabel.new()
	_help.bbcode_enabled = true
	_help.fit_content = true
	_help.scroll_active = false
	_help.autowrap_mode = TextServer.AUTOWRAP_OFF
	_help.custom_minimum_size = Vector2(300, 0)
	_help.add_theme_font_size_override(&"normal_font_size", 12)
	_help.add_theme_font_size_override(&"bold_font_size", 12)
	_help_panel.add_child(_help)
	_refresh_help()

	_tuning = TuningPanel.new()
	_tuning.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_MINSIZE, 12)
	_tuning.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_tuning)


func _panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(8)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override(&"panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _monospace() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "Liberation Mono", "monospace"])
	return font
