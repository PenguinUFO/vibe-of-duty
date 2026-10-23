class_name HostPanel
extends PanelContainer
## Host settings, opened by the main menu's "Создать игру": map, match rules (kill limit, match length) and, under
## the folded "Дополнительно", the port. Below it, "Тестирование" behind the kid mode code (KidModeEntry): the
## right code opens a section of test modes - for now "FFA random weapon" (Game.random_weapons).
## "Start" emits start_requested after copying the choices into Game (and saving them for next time);
## the menu then opens the server.

signal start_requested
signal closed

## The test modes chosen this run (not saved: a restart turns them off, the section stays locked until the code).
static var unlocked := false
static var random_weapons := false

var _map: OptionButton
var _score_limit: SpinBox
var _match_minutes: SpinBox
var _port: SpinBox
var _random_weapons: CheckBox


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(480, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "СОЗДАТЬ ИГРУ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "PanelTitle"
	box.add_child(title)

	_map = OptionButton.new()
	for path in Game.list_maps():
		_map.add_item(Game.map_name(path))
		_map.set_item_metadata(_map.item_count - 1, path)
		if path == Settings.host_map:
			_map.select(_map.item_count - 1)
	_map.item_selected.connect(func(_i: int) -> void: Audio.play("ui_click"))
	_add_row(box, "Карта", _map)
	_score_limit = _add_spin(box, "Лимит убийств", 1, 100, Settings.host_score_limit, "")
	_match_minutes = _add_spin(box, "Длительность матча", 1, 60, Settings.host_match_minutes, " мин")
	# Rarely needed settings, folded away: the port (only when 27015 is taken or a router forwards another one).
	var advanced := FoldableContainer.new()
	advanced.title = "Дополнительно"
	advanced.folded = true
	box.add_child(advanced)
	var advanced_box := VBoxContainer.new()
	advanced_box.add_theme_constant_override("separation", 10)
	advanced.add_child(advanced_box)
	_port = _add_spin(advanced_box, "Порт", 1024, 65535, Settings.host_port, "")
	_add_testing(box)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var back := Button.new()
	back.text = "Назад"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void:
		Audio.play("ui_click")
		closed.emit())
	buttons.add_child(back)
	var start := Button.new()
	start.text = "Начать"
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_on_start)
	buttons.add_child(start)
	if Settings.has_gamepad():
		start.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Esc / B: back to the main menu
		get_viewport().set_input_as_handled()
		closed.emit()


func _on_start() -> void:
	Audio.play("ui_click")
	if _map.selected >= 0:
		Settings.host_map = _map.get_item_metadata(_map.selected)
	Settings.host_score_limit = int(_score_limit.value)
	Settings.host_match_minutes = int(_match_minutes.value)
	Settings.host_port = int(_port.value)
	Settings.save_settings()
	Game.map_scene = Settings.host_map if Game.list_maps().has(Settings.host_map) else Game.DEFAULT_MAP
	Game.score_limit = Settings.host_score_limit
	Game.match_time = Settings.host_match_minutes * 60.0
	Game.launch_port = Settings.host_port
	Game.training = false
	random_weapons = _random_weapons.button_pressed
	Game.random_weapons = random_weapons
	start_requested.emit()


## "Тестирование": locked behind the code like kid mode; once opened, a folding section like "Дополнительно".
func _add_testing(box: Container) -> void:
	var testing := FoldableContainer.new()
	testing.title = "Тестирование"
	testing.visible = unlocked
	box.add_child(testing)
	var testing_box := VBoxContainer.new()
	testing_box.add_theme_constant_override("separation", 10)
	testing.add_child(testing_box)
	_random_weapons = CheckBox.new()
	_random_weapons.text = "Игровой режим: FFA рандомное оружие"
	_random_weapons.button_pressed = random_weapons
	_random_weapons.toggled.connect(func(_on: bool) -> void: Audio.play("ui_click"))
	testing_box.add_child(_random_weapons)
	if unlocked:
		return
	var entry := KidModeEntry.new("Тестирование")
	box.add_child(entry)
	entry.open_requested.connect(func() -> void:
		unlocked = true
		entry.queue_free()
		testing.visible = true
		testing.folded = false
		_random_weapons.grab_focus())


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
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)
