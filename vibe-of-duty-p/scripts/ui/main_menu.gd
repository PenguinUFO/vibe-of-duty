extends Control
## Main menu: host a game (HostPanel: map, rules, port), join one (JoinPanel: address or a recent server; the server
## sends its map and rules), or quit.

const KID_MODE_CODE := "0451"

@onready var _name_edit: LineEdit = %NameEdit
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _quit_button: Button = %QuitButton
@onready var _settings_button: Button = %SettingsButton
@onready var _kid_mode_check: CheckButton = %KidModeCheck
@onready var _center: Control = $Center
@onready var _status: Label = %Status

var _joining := ""  # address being connected to; remembered in Settings.recent_servers once it works


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_name_edit.text = Settings.player_name
	_kid_mode_check.set_pressed_no_signal(Settings.kid_mode)
	_kid_mode_check.toggled.connect(_on_kid_mode_toggled)
	_host_button.pressed.connect(_on_host)
	_join_button.pressed.connect(_on_join)
	_quit_button.pressed.connect(get_tree().quit)
	_settings_button.pressed.connect(_open_settings)
	for button in [_host_button, _join_button, _quit_button, _settings_button]:
		button.pressed.connect(func() -> void: Audio.play("ui_click"))
	Audio.play_music_id("menu")
	if Settings.has_gamepad():
		_host_button.grab_focus.call_deferred()  # d-pad / stick navigation needs a focused control
	Net.connected_to_server.connect(_on_connected)
	Net.map_received.connect(func(_path: String) -> void: _start_game())
	Net.connection_failed.connect(_on_connection_failed)
	if Game.auto_join != "":
		_connect(Game.auto_join)


func _on_connected() -> void:
	_status.text = "Подключено, загрузка карты..."
	if _joining != "" and Game.auto_join == "":  # test launches (--join) do not fill the player's list
		Settings.remember_server(_joining)


func _apply_name() -> void:
	var entered := _name_edit.text.strip_edges()
	if entered != "":
		Settings.player_name = entered
	Settings.save_settings()


## Turning kid mode on needs the code; a wrong code (or cancel) closes the dialog and leaves it off. Turning it off is free.
func _on_kid_mode_toggled(on: bool) -> void:
	if not on:
		Settings.kid_mode = false
		Settings.save_settings()
		return
	_kid_mode_check.set_pressed_no_signal(false)
	_center.process_mode = Node.PROCESS_MODE_DISABLED  # keeps the menu from taking input behind the dialog
	var dialog := PinDialog.new(KID_MODE_CODE)
	dialog.finished.connect(func(ok: bool) -> void:
		_center.process_mode = Node.PROCESS_MODE_INHERIT
		if ok:
			Settings.kid_mode = true
			Settings.save_settings()
			_kid_mode_check.set_pressed_no_signal(true)
		_kid_mode_check.grab_focus.call_deferred())
	add_child(dialog)


func _on_host() -> void:
	_apply_name()
	_center.visible = false
	var panel := HostPanel.new()
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_center.visible = true
		if Settings.has_gamepad():
			_host_button.grab_focus.call_deferred())
	panel.start_requested.connect(func() -> void:
		panel.queue_free()
		_center.visible = true
		_start_server())
	add_child(panel)


func _start_server() -> void:
	var err := Net.host(Game.launch_port)
	if err != OK:
		_status.text = "Не удалось создать игру на порту %d: %s" % [Game.launch_port, error_string(err)]
		return
	_start_game()


func _on_join() -> void:
	_apply_name()
	_center.visible = false
	var panel := JoinPanel.new()
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_center.visible = true
		if Settings.has_gamepad():
			_join_button.grab_focus.call_deferred())
	panel.join_requested.connect(func(address: String) -> void:
		panel.queue_free()
		_center.visible = true
		_connect(address))
	add_child(panel)


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


func _start_game() -> void:
	get_tree().change_scene_to_file(Game.map_scene)


func _open_settings() -> void:
	_center.visible = false
	var panel := SettingsPanel.new()
	panel.closed.connect(func() -> void:
		panel.queue_free()
		_center.visible = true)
	add_child(panel)
