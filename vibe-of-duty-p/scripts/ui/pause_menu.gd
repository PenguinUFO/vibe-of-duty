class_name PauseMenu
extends CanvasLayer
## In-game menu on Esc. It does not stop the game (it is online); it only frees the mouse so the
## player stops sending input. Resume / Settings / Leave match.

var _root: Control
var _menu_box: VBoxContainer
var _settings: SettingsPanel


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_menu_box = VBoxContainer.new()
	_menu_box.custom_minimum_size = Vector2(300, 0)
	_menu_box.add_theme_constant_override("separation", 10)
	center.add_child(_menu_box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	_menu_box.add_child(title)
	_add_button("Resume", close)
	_add_button("Settings", _open_settings)
	_add_button("Leave match", _leave)
	_add_button("Quit game", get_tree().quit)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	_root.add_child(_settings)


func is_open() -> bool:
	return _root != null and _root.visible


func open() -> void:
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_focus_first(_menu_box)


func close() -> void:
	_close_settings()
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# Opens on "pause" (Esc / Start); while open, "ui_cancel" (Esc / B) also goes back. B alone is crouch in game.
	if not (event.is_action_pressed("pause") or (is_open() and event.is_action_pressed("ui_cancel"))):
		return
	get_viewport().set_input_as_handled()
	if _settings.visible:
		Settings.save_settings()
		_close_settings()
	elif is_open():
		close()
	else:
		open()


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void:
		Audio.play("ui_click")
		action.call())
	_menu_box.add_child(button)


func _open_settings() -> void:
	_menu_box.get_parent().visible = false
	_settings.visible = true
	_focus_first(_settings)


func _close_settings() -> void:
	_settings.visible = false
	_menu_box.get_parent().visible = true
	if is_open():
		_focus_first(_menu_box)


## With a gamepad, put the focus on the first button so the d-pad / stick can move through the menu.
func _focus_first(container: Control) -> void:
	if not Settings.has_gamepad():
		return
	for child in container.find_children("*", "BaseButton", true, false):
		(child as Control).grab_focus.call_deferred()
		return


func _leave() -> void:
	Net.leave()  # emits Net.disconnected -> NetWorld returns to the main menu
