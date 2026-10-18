class_name SettingsPanel
extends PanelContainer
## Settings editor: controls (mouse sensitivity, FOV), graphics (preset, anti-aliasing, shadows, render
## scale, VSync) and volumes. Changes apply immediately and are saved when the panel is closed with
## Back. Used by the main menu and the in-game pause menu.

signal closed

const SENSITIVITY_UNIT := 0.0025  # Settings.mouse_sensitivity (rad/pixel) that counts as "1.00"
const VOLUME_BUSES: Array[StringName] = [&"Master", &"SFX", &"Music", &"UI"]
const PRESET_NAMES: Array[String] = ["Low", "Medium", "High", "Custom"]
const PRESETS: Array[Dictionary] = [
	{"aa": 0, "shadows": 0},  # Low
	{"aa": 0, "shadows": 1},  # Medium
	{"aa": 1, "shadows": 2},  # High
]

var _preset: OptionButton
var _aa: OptionButton
var _shadows: OptionButton


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(540, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.13, 0.95)
	style.set_content_margin_all(22.0)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_add_slider(box, "Mouse sensitivity", 0.1, 4.0, 0.05, Settings.mouse_sensitivity / SENSITIVITY_UNIT,
			func(v: float) -> void: Settings.mouse_sensitivity = v * SENSITIVITY_UNIT, "%.2f")
	_add_slider(box, "Stick sensitivity", 0.2, 3.0, 0.05, Settings.stick_sensitivity,
			func(v: float) -> void: Settings.stick_sensitivity = v, "%.2f")
	_add_slider(box, "Field of view", 60.0, 120.0, 1.0, Settings.fov,
			func(v: float) -> void: Settings.fov = v, "%d")

	_add_heading(box, "Graphics")
	_preset = _add_option(box, "Preset", PRESET_NAMES, _current_preset(), _on_preset)
	_aa = _add_option(box, "Anti-aliasing", ["Off", "FXAA"], Settings.antialiasing, func(i: int) -> void:
		Settings.antialiasing = i
		_graphics_changed())
	_shadows = _add_option(box, "Shadows", ["Off", "Medium", "High"], Settings.shadow_quality, func(i: int) -> void:
		Settings.shadow_quality = i
		_graphics_changed())
	_add_slider(box, "Render scale", 0.5, 1.0, 0.05, Settings.render_scale, func(v: float) -> void:
		Settings.render_scale = v
		Settings.apply_graphics(), "%d%%", true)
	var vsync := CheckBox.new()
	vsync.text = "VSync"
	vsync.button_pressed = Settings.vsync
	vsync.toggled.connect(func(on: bool) -> void:
		Settings.vsync = on
		Settings.apply_graphics())
	box.add_child(vsync)

	_add_heading(box, "Audio")
	for bus in VOLUME_BUSES:
		_add_slider(box, "%s volume" % bus, 0.0, 1.0, 0.01, Settings.volumes.get(bus, 1.0),
				func(v: float) -> void: Settings.set_volume(bus, v), "%d%%", true, true)

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_on_back)
	box.add_child(back)


func _ready() -> void:
	if Settings.has_gamepad():  # d-pad / stick navigation needs a focused control
		for child in find_children("*", "Range", true, false):
			(child as Control).grab_focus.call_deferred()
			break


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):  # Esc / B
		get_viewport().set_input_as_handled()
		_on_back()


func _on_back() -> void:
	Audio.play("ui_click")
	Settings.save_settings()
	closed.emit()


func _on_preset(index: int) -> void:
	if index >= PRESETS.size():
		return  # "Custom": keep whatever is set
	Settings.antialiasing = PRESETS[index]["aa"]
	Settings.shadow_quality = PRESETS[index]["shadows"]
	_aa.select(Settings.antialiasing)
	_shadows.select(Settings.shadow_quality)
	Settings.apply_graphics()


## After a manual change: show the matching preset, or "Custom".
func _graphics_changed() -> void:
	Settings.apply_graphics()
	_preset.select(_current_preset())


func _current_preset() -> int:
	for i in PRESETS.size():
		if PRESETS[i]["aa"] == Settings.antialiasing and PRESETS[i]["shadows"] == Settings.shadow_quality:
			return i
	return PRESETS.size()


func _add_heading(parent: Container, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	parent.add_child(heading)


func _add_option(parent: Container, label_text: String, items: Array, selected: int, on_select: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(190, 0)
	row.add_child(label)
	var option := OptionButton.new()
	for item in items:
		option.add_item(item)
	option.select(selected)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.item_selected.connect(on_select)
	row.add_child(option)
	parent.add_child(row)
	return option


func _add_slider(parent: Container, label_text: String, min_value: float, max_value: float, step: float,
		value: float, on_change: Callable, format: String, percent: bool = false, click: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(190, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(180, 0)
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(64, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	var show_value := func(v: float) -> void:
		readout.text = format % (v * 100.0 if percent else v)
	show_value.call(value)
	slider.value_changed.connect(func(v: float) -> void:
		show_value.call(v)
		on_change.call(v))
	if click:
		slider.drag_ended.connect(func(_changed: bool) -> void: Audio.play("ui_click"))  # audible feedback
	parent.add_child(row)
