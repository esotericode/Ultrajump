class_name TuningPanel
extends PanelContainer
## Live editor for [MovementSettings], built automatically from its exported
## properties: every number gets a slider, grouped like in the inspector.
## Changes apply instantly while you play. "Save" writes them back to the
## resource file (only possible when running from the editor / project folder).

## True while the mouse is over the panel or its search box has focus;
## gameplay input should pause meanwhile.
var wants_input := false

var _settings: MovementSettings
var _defaults := MovementSettings.new()
var _rows: Dictionary[StringName, Control] = {}
var _editors: Dictionary[StringName, Range] = {}
var _toggles: Dictionary[StringName, CheckBox] = {}
var _search: LineEdit
var _status: Label
var _list: VBoxContainer


func setup(settings: MovementSettings) -> void:
	_settings = settings
	_build()


func _process(_delta: float) -> void:
	if _search == null:
		return
	wants_input = visible and (get_global_rect().has_point(get_global_mouse_position()) or _search.has_focus())


func _build() -> void:
	custom_minimum_size = Vector2(430, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override(&"panel", style)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 6)
	add_child(layout)

	var title := Label.new()
	title.text = "Movement Tuning"
	title.add_theme_font_size_override(&"font_size", 18)
	layout.add_child(title)
	var source := Label.new()
	source.text = _settings.resource_path if _settings.resource_path else "(unsaved resource)"
	source.modulate = Color(1, 1, 1, 0.6)
	layout.add_child(source)

	var buttons := HBoxContainer.new()
	layout.add_child(buttons)
	for entry in [["Save", _save], ["Revert", _revert], ["Defaults", _reset_to_defaults]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		buttons.add_child(button)

	_search = LineEdit.new()
	_search.placeholder_text = "Filter (e.g. jump, dive, wall)…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(_filter)
	layout.add_child(_search)

	_status = Label.new()
	_status.modulate = Color(0.6, 1.0, 0.6)
	layout.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var group := ""
	var header_added := false
	for property in _settings.get_property_list():
		var usage: int = property.usage
		if usage & PROPERTY_USAGE_GROUP:
			group = property.name
			header_added = false
		elif usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR:
			# Headers are added lazily so groups without tunable values (like Resource's) are skipped.
			if not header_added and not group.is_empty():
				var header := Label.new()
				header.text = group.to_upper()
				header.add_theme_color_override(&"font_color", Color(1.0, 0.75, 0.4))
				_list.add_child(header)
				header_added = true
			_add_row(property, group)


func _add_row(property: Dictionary, group: String) -> void:
	var key: StringName = property.name
	var row := HBoxContainer.new()
	row.set_meta(&"group", group)
	var label := Label.new()
	label.text = String(key).capitalize()
	label.custom_minimum_size.x = 190
	label.clip_text = true
	label.tooltip_text = String(key)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)

	match property.type:
		TYPE_BOOL:
			var toggle := CheckBox.new()
			toggle.button_pressed = _settings.get(key)
			toggle.focus_mode = Control.FOCUS_NONE
			toggle.toggled.connect(func(on: bool) -> void: _settings.set(key, on))
			row.add_child(toggle)
			_toggles[key] = toggle
		TYPE_FLOAT, TYPE_INT:
			var hint := _parse_range(property)
			var slider := HSlider.new()
			slider.min_value = hint.min
			slider.max_value = hint.max
			slider.step = hint.step
			slider.value = _settings.get(key)
			slider.scrollable = false
			slider.focus_mode = Control.FOCUS_NONE
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(slider)
			var value_label := Label.new()
			value_label.custom_minimum_size.x = 84
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(value_label)
			var display := func(value: float) -> void:
				value_label.text = ("%d" if property.type == TYPE_INT else "%.2f") % value + (" " + hint.suffix if hint.suffix else "")
			display.call(slider.value)
			slider.value_changed.connect(func(value: float) -> void:
				_settings.set(key, int(value) if property.type == TYPE_INT else value)
				display.call(value))
			_editors[key] = slider
		_:
			return
	_rows[key] = row
	_list.add_child(row)


## Reads "min,max,step,suffix:unit" from an @export_range hint.
func _parse_range(property: Dictionary) -> Dictionary:
	var result := {"min": 0.0, "max": 100.0, "step": 0.01, "suffix": ""}
	if property.hint != PROPERTY_HINT_RANGE:
		var current := float(_settings.get(property.name))
		result.max = maxf(absf(current) * 4.0, 10.0)
		return result
	var parts := String(property.hint_string).split(",")
	if parts.size() >= 2:
		result.min = parts[0].to_float()
		result.max = parts[1].to_float()
	if parts.size() >= 3 and parts[2].is_valid_float():
		result.step = parts[2].to_float()
	for part in parts:
		if part.begins_with("suffix:"):
			result.suffix = part.trim_prefix("suffix:")
	return result


func _filter(text: String) -> void:
	var query := text.strip_edges().to_lower()
	for child in _list.get_children():
		if child is Label:
			child.visible = query.is_empty()
			continue
		var key := String(_rows.find_key(child))
		var group := String(child.get_meta(&"group", "")).to_lower()
		child.visible = query.is_empty() or key.to_lower().contains(query) or group.contains(query)


func _refresh() -> void:
	for key in _editors:
		_editors[key].set_value_no_signal(_settings.get(key))
		_editors[key].value_changed.emit(_editors[key].value)
	for key in _toggles:
		_toggles[key].set_pressed_no_signal(_settings.get(key))


func _save() -> void:
	if _settings.resource_path.is_empty():
		_show_status("This settings resource has no file to save to.", false)
		return
	var error := ResourceSaver.save(_settings)
	if error == OK:
		_show_status("Saved to %s" % _settings.resource_path, true)
	else:
		_show_status("Couldn't save (%s). Exported games can't write to res://." % error_string(error), false)


func _revert() -> void:
	if _settings.resource_path.is_empty():
		return
	var saved := ResourceLoader.load(_settings.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MovementSettings
	if saved == null:
		_show_status("Couldn't reload %s" % _settings.resource_path, false)
		return
	_copy_from(saved)
	_show_status("Reverted to the saved values.", true)


func _reset_to_defaults() -> void:
	_copy_from(_defaults)
	_show_status("Reset to the script defaults (not saved yet).", true)


func _copy_from(source: MovementSettings) -> void:
	for key in _rows:
		_settings.set(key, source.get(key))
	_refresh()


func _show_status(message: String, ok: bool) -> void:
	_status.text = message
	_status.modulate = Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.5)
