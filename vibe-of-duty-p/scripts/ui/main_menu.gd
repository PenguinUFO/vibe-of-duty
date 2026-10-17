extends Control
## Main menu: host a game, join by IP, or quit.

@onready var _name_edit: LineEdit = %NameEdit
@onready var _ip_edit: LineEdit = %IpEdit
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _quit_button: Button = %QuitButton
@onready var _settings_button: Button = %SettingsButton
@onready var _center: Control = $Center
@onready var _status: Label = %Status


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_name_edit.text = Settings.player_name
	_host_button.pressed.connect(_on_host)
	_join_button.pressed.connect(_on_join)
	_quit_button.pressed.connect(get_tree().quit)
	_settings_button.pressed.connect(_open_settings)
	for button in [_host_button, _join_button, _quit_button, _settings_button]:
		button.pressed.connect(func() -> void: Audio.play("ui_click"))
	Audio.play_music_id("menu")
	Net.connected_to_server.connect(_start_game)
	Net.connection_failed.connect(_on_connection_failed)
	if Game.auto_join != "":
		_connect(Game.auto_join)


func _apply_name() -> void:
	var entered := _name_edit.text.strip_edges()
	if entered != "":
		Settings.player_name = entered
		Settings.save_settings()


func _on_host() -> void:
	_apply_name()
	var err := Net.host(Game.launch_port)
	if err != OK:
		_status.text = "Could not host: %s" % error_string(err)
		return
	_start_game()


func _on_join() -> void:
	_apply_name()
	_connect(_ip_edit.text.strip_edges())


func _connect(address: String) -> void:
	_set_buttons_disabled(true)
	_status.text = "Connecting to %s..." % address
	var err := Net.join(address, Game.launch_port)
	if err != OK:
		_on_connection_failed()


func _on_connection_failed() -> void:
	_set_buttons_disabled(false)
	_status.text = "Connection failed."


func _set_buttons_disabled(disabled: bool) -> void:
	_host_button.disabled = disabled
	_join_button.disabled = disabled


func _start_game() -> void:
	get_tree().change_scene_to_file(Game.LEVEL_SCENE)


func _open_settings() -> void:
	_center.visible = false
	var panel := SettingsPanel.new()
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_center.visible = true)
	add_child(panel)
