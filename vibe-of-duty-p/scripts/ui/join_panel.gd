class_name JoinPanel
extends PanelContainer
## Join a game, opened by the main menu's "Подключиться": type a server address, or pick one of the recent servers
## (Settings.recent_servers: every address joined successfully, newest first). Each recent server can be given a
## name of the player's choosing, shown next to its address, and removed from the list.

signal join_requested(address: String)
signal closed

var _address: LineEdit
var _connect: Button
var _recent_box: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(580, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.13, 0.95)
	style.set_content_margin_all(22.0)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "ПОДКЛЮЧЕНИЕ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = "Адрес сервера"
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)
	_address = LineEdit.new()
	_address.text = Settings.server_address
	_address.placeholder_text = "например, 192.168.1.10"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.text_submitted.connect(func(_t: String) -> void: _join(_address.text))
	row.add_child(_address)
	box.add_child(row)

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
	_connect = Button.new()
	_connect.text = "Подключиться"
	_connect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connect.pressed.connect(func() -> void: _join(_address.text))
	buttons.add_child(_connect)

	_recent_box = VBoxContainer.new()
	_recent_box.add_theme_constant_override("separation", 6)
	box.add_child(_recent_box)
	_build_recent()
	if Settings.has_gamepad():
		_connect.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Esc / B: back to the main menu
		get_viewport().set_input_as_handled()
		closed.emit()


func _join(address: String) -> void:
	address = address.strip_edges()
	if address == "":
		_address.grab_focus()
		return
	Audio.play("ui_click")
	Settings.server_address = address
	Settings.save_settings()
	join_requested.emit(address)


## The recent servers: [name field] address [Войти] [×]. The name is saved as it is typed.
func _build_recent() -> void:
	for child in _recent_box.get_children():
		child.queue_free()
	if Settings.recent_servers.is_empty():
		return
	var heading := Label.new()
	heading.text = "Недавние серверы"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	_recent_box.add_child(heading)
	for entry in Settings.recent_servers:
		var address: String = entry["address"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_edit := LineEdit.new()
		name_edit.text = entry["name"]
		name_edit.placeholder_text = "Название"
		name_edit.max_length = 32
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.text_changed.connect(func(text: String) -> void: Settings.rename_server(address, text))
		name_edit.text_submitted.connect(func(_t: String) -> void: name_edit.release_focus())
		row.add_child(name_edit)
		var address_label := Label.new()
		address_label.text = address
		address_label.custom_minimum_size = Vector2(150, 0)
		address_label.clip_text = true
		row.add_child(address_label)
		var go := Button.new()
		go.text = "Войти"
		go.pressed.connect(func() -> void: _join(address))
		row.add_child(go)
		var remove := Button.new()
		remove.text = "×"
		remove.tooltip_text = "Убрать из списка"
		remove.pressed.connect(func() -> void:
			Audio.play("ui_click")
			Settings.forget_server(address)
			_build_recent.call_deferred())
		row.add_child(remove)
		_recent_box.add_child(row)
