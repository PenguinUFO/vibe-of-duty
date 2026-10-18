class_name HostPanel
extends PanelContainer
## Host settings, opened by the main menu's "Host game": map, match rules (kill limit, match length) and port.
## "Start" emits start_requested after copying the choices into Game (and saving them for next time);
## the menu then opens the server.

signal start_requested
signal closed

var _map: OptionButton
var _score_limit: SpinBox
var _match_minutes: SpinBox
var _port: SpinBox


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.13, 0.95)
	style.set_content_margin_all(22.0)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "HOST GAME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_map = OptionButton.new()
	for path in Game.list_maps():
		_map.add_item(Game.map_name(path))
		_map.set_item_metadata(_map.item_count - 1, path)
		if path == Settings.host_map:
			_map.select(_map.item_count - 1)
	_map.item_selected.connect(func(_i: int) -> void: Audio.play("ui_click"))
	_add_row(box, "Map", _map)
	_score_limit = _add_spin(box, "Kill limit", 1, 100, Settings.host_score_limit, "")
	_match_minutes = _add_spin(box, "Match length", 1, 60, Settings.host_match_minutes, " min")
	_port = _add_spin(box, "Port", 1024, 65535, Settings.host_port, "")

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var back := Button.new()
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void:
		Audio.play("ui_click")
		closed.emit())
	buttons.add_child(back)
	var start := Button.new()
	start.text = "Start"
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_on_start)
	buttons.add_child(start)


func _on_start() -> void:
	Audio.play("ui_click")
	if _map.selected >= 0:
		Settings.host_map = _map.get_item_metadata(_map.selected)
	Settings.host_score_limit = int(_score_limit.value)
	Settings.host_match_minutes = int(_match_minutes.value)
	Settings.host_port = int(_port.value)
	Settings.save_settings()
	Game.map_scene = Settings.host_map if Game.is_map(Settings.host_map) else Game.DEFAULT_MAP
	Game.score_limit = Settings.host_score_limit
	Game.match_time = Settings.host_match_minutes * 60.0
	Game.launch_port = Settings.host_port
	start_requested.emit()


func _add_spin(parent: Container, label_text: String, min_value: int, max_value: int, value: int, suffix: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.value = value
	spin.suffix = suffix
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_row(parent, label_text, spin)
	return spin


func _add_row(parent: Container, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)
