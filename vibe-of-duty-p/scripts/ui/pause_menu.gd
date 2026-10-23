class_name PauseMenu
extends CanvasLayer
## In-game menu on Esc. It does not stop the game (it is online); it only frees the mouse so the
## player stops sending input. Resume / Build (BuildMenu) / Settings / Kid mode (with its code, KidModeEntry) /
## Leave match.

var world: NetWorld  # set by NetWorld (BuildMenu sends the build through it)
var _root: Control
var _menu_box: VBoxContainer
var _panel: Control  # the open sub-panel (SettingsPanel or KidPanel; both emit `closed`), or null
var _kid_entry: KidModeEntry


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
	_menu_box.custom_minimum_size = Vector2(320, 0)
	_menu_box.add_theme_constant_override("separation", 8)
	center.add_child(_menu_box)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.theme_type_variation = "PanelTitle"
	title.add_theme_font_size_override("font_size", 40)
	_menu_box.add_child(title)
	_add_button("Продолжить", close)
	if not world.random_weapons_on():  # FFA random weapon: the server picks every life's weapon
		_add_button("Сборка", _open_builds)
	_add_button("Настройки", func() -> void: _open_panel(SettingsPanel.new()))
	_kid_entry = KidModeEntry.new()
	_kid_entry.open_requested.connect(func() -> void: _open_panel(KidPanel.new()))
	_menu_box.add_child(_kid_entry)
	_add_button("Покинуть матч", _leave)
	_add_button("Выйти из игры", get_tree().quit)


func is_open() -> bool:
	return _root != null and _root.visible


func open() -> void:
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	UiTheme.stagger_in(_menu_box, 0.03)
	_focus_first(_menu_box)


func close() -> void:
	_close_panel()
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# Opens on "pause" (Esc / Start); while open, "ui_cancel" (Esc / B) also goes back. B alone is crouch in game.
	if not (event.is_action_pressed("pause") or (is_open() and event.is_action_pressed("ui_cancel"))):
		return
	get_viewport().set_input_as_handled()
	if _panel != null:
		Settings.save_settings()
		_close_panel()
	elif is_open():
		close()
	else:
		open()


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = "BigButton"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void:
		Audio.play("ui_click")
		action.call())
	_menu_box.add_child(button)


func _open_panel(panel: Control) -> void:
	_close_panel()
	_menu_box.get_parent().visible = false
	_panel = panel
	panel.connect("closed", _close_panel)
	_root.add_child(panel)
	UiTheme.pop_in(panel)
	_focus_first(panel)


func _open_builds() -> void:
	var menu := BuildMenu.new()
	menu.world = world
	menu.picked.connect(close)  # back to the game: on a training map the new build is already in the hands
	_open_panel(menu)


func _close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	_kid_entry.refresh()
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
