extends Control
## Main menu: host a game (HostPanel: map, rules, port), join one (JoinPanel: address or a recent server; the server
## sends its map and rules), train alone (TrainingPanel: the training maps), edit builds (BuildPanel), or quit.

const MENU_LEFT := 96.0  # the column's left edge (as in the scene)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _random_name_button: Button = %RandomNameButton
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _training_button: Button = %TrainingButton
@onready var _quit_button: Button = %QuitButton
@onready var _settings_button: Button = %SettingsButton
@onready var _column: Control = $Column
@onready var _pig: Control = $Pig  # hidden with the column while a panel is open
@onready var _status: Label = %Status
@onready var _version: Label = %Version  # bottom right: the build version (raised by addons/version_bump on export)

var _kid_entry := KidModeEntry.new()  # under Settings
var _build_button := Button.new()     # above Settings
var _joining := ""  # address being connected to; remembered in Settings.recent_servers once it works


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tag := str(ProjectSettings.get_setting("application/config/version_tag", ""))
	_version.text = "v%s%s" % [ProjectSettings.get_setting("application/config/version", ""), "-" + tag if tag != "" else ""]
	_name_edit.text = Settings.player_name
	_build_button.text = "Сборка"
	_build_button.theme_type_variation = "BigButton"
	_column.add_child(_build_button)
	_column.move_child(_build_button, _settings_button.get_index())
	_build_button.pressed.connect(_open_builds)
	_column.add_child(_kid_entry)
	_column.move_child(_kid_entry, _settings_button.get_index() + 1)
	_kid_entry.open_requested.connect(_open_kid_panel)
	_host_button.pressed.connect(_on_host)
	_join_button.pressed.connect(_on_join)
	_random_name_button.pressed.connect(_on_random_name)
	_training_button.pressed.connect(_on_training)
	_quit_button.pressed.connect(get_tree().quit)
	_settings_button.pressed.connect(_open_settings)
	Game.training = false
	for button in [_host_button, _join_button, _training_button, _quit_button, _settings_button, _random_name_button,
			_build_button]:
		button.pressed.connect(func() -> void: Audio.play("ui_click"))
	Audio.play_music_id("menu")
	_show_menu()
	if Settings.has_gamepad():
		_host_button.grab_focus.call_deferred()  # d-pad / stick navigation needs a focused control
	Net.connected_to_server.connect(_on_connected)
	Net.map_received.connect(func(_path: String) -> void: _start_game())
	Net.connection_failed.connect(_on_connection_failed)
	if Game.auto_join != "":
		_connect(Game.auto_join)
	elif Game.auto_training != "":
		_start_training.call_deferred(Game.MAPS_DIR.path_join(Game.auto_training + ".tscn"))


## Shows the menu column again (at start and back from a panel), sliding in from the left.
func _show_menu() -> void:
	_column.visible = true
	_pig.visible = true
	_column.position.x = MENU_LEFT - 40.0
	var tween := _column.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_column, "position:x", MENU_LEFT, 0.3)
	UiTheme.stagger_in(_column)


func _on_connected() -> void:
	_status.text = "Подключено, загрузка карты..."
	if _joining != "" and Game.auto_join == "":  # test launches (--join) do not fill the player's list
		Settings.remember_server(_joining)


## Puts another random nickname into the name field (saved like a typed name, when a game starts).
func _on_random_name() -> void:
	var current := _name_edit.text
	for i in 5:  # a different one than shown
		_name_edit.text = Settings.pick_nickname()
		if _name_edit.text != current:
			break


func _apply_name() -> void:
	var entered := _name_edit.text.strip_edges()
	if entered != "":
		Settings.player_name = entered
	Settings.name_chosen = true  # the name played with, typed or the random one, is kept from now on
	Settings.save_settings()


func _on_host() -> void:
	_apply_name()
	_column.visible = false
	_pig.visible = false
	var panel := HostPanel.new()
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_show_menu()
		if Settings.has_gamepad():
			_host_button.grab_focus.call_deferred())
	panel.start_requested.connect(func() -> void:
		panel.queue_free()
		_show_menu()
		_start_server())
	add_child(panel)
	UiTheme.pop_in(panel)


func _start_server() -> void:
	var err := Net.host(Game.launch_port)
	if err != OK:
		_status.text = "Не удалось создать игру на порту %d: %s" % [Game.launch_port, error_string(err)]
		return
	_start_game()


func _on_join() -> void:
	_apply_name()
	_column.visible = false
	_pig.visible = false
	var panel := JoinPanel.new()
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_show_menu()
		if Settings.has_gamepad():
			_join_button.grab_focus.call_deferred())
	panel.join_requested.connect(func(address: String) -> void:
		panel.queue_free()
		_show_menu()
		_connect(address))
	add_child(panel)
	UiTheme.pop_in(panel)


func _on_training() -> void:
	_apply_name()
	_column.visible = false
	_pig.visible = false
	var panel := TrainingPanel.new()
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_show_menu()
		if Settings.has_gamepad():
			_training_button.grab_focus.call_deferred())
	panel.start_requested.connect(func(path: String) -> void:
		panel.queue_free()
		_show_menu()
		_start_training(path))
	add_child(panel)
	UiTheme.pop_in(panel)


## Plays a training map alone: a server only this computer can reach, no match clock (a day-long "match").
func _start_training(path: String) -> void:
	var base := path.get_file().get_basename()
	if not (Game.list_training_maps().has(path) or (Game.TEST_MAPS.has(base) and Game.is_map(path))):
		_status.text = "Нет такой тренировки: %s" % path.get_file().get_basename()
		return
	Game.training = true
	Game.map_scene = path
	Game.match_time = 86400.0
	var err := Net.host_training()
	if err != OK:
		Game.training = false
		_status.text = "Не удалось запустить тренировку: %s" % error_string(err)
		return
	_start_game()


func _connect(address: String) -> void:
	_joining = address
	_set_buttons_disabled(true)
	_status.text = "Подключение к %s..." % address
	var err := Net.join(address, Game.launch_port)
	if err != OK:
		_on_connection_failed()


func _on_connection_failed() -> void:
	_set_buttons_disabled(false)
	_status.text = "Не удалось подключиться."


func _set_buttons_disabled(disabled: bool) -> void:
	_host_button.disabled = disabled
	_join_button.disabled = disabled
	_training_button.disabled = disabled


func _start_game() -> void:
	get_tree().change_scene_to_file(Game.map_scene)


func _open_settings() -> void:
	_column.visible = false
	_pig.visible = false
	var panel := SettingsPanel.new()
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_show_menu())
	add_child(panel)
	UiTheme.pop_in(panel)


func _open_builds() -> void:
	_column.visible = false
	_pig.visible = false
	var panel := BuildPanel.new()
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_show_menu()
		if Settings.has_gamepad():
			_build_button.grab_focus.call_deferred())
	add_child(panel)
	UiTheme.pop_in(panel)


## The code was typed beside "Kid mode" (KidModeEntry).
func _open_kid_panel() -> void:
	_column.visible = false
	_pig.visible = false
	var panel := KidPanel.new()
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_kid_entry.refresh()
		_show_menu())
	add_child(panel)
	UiTheme.pop_in(panel)
