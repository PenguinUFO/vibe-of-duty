class_name TrainingPanel
extends PanelContainer
## Training, opened by the main menu's "Тренировка": the training maps (Game.TRAINING_MAPS), one button each with a
## short description. Picking one emits start_requested(path); the menu plays it alone (Net.host_training).

signal start_requested(path: String)
signal closed


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(520, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var title := Label.new()
	title.text = "ТРЕНИРОВКА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "PanelTitle"
	box.add_child(title)

	var first: Button = null
	for path in Game.list_training_maps():
		var button := Button.new()
		button.text = Game.map_name(path)
		button.theme_type_variation = "BigButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void:
			Audio.play("ui_click")
			start_requested.emit(path))
		box.add_child(button)
		var info := Label.new()
		info.text = Game.TRAINING_INFO.get(path.get_file().get_basename(), "")
		info.theme_type_variation = "Hint"
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(info)
		if first == null:
			first = button

	var back := Button.new()
	back.text = "Назад"
	back.pressed.connect(func() -> void:
		Audio.play("ui_click")
		closed.emit())
	box.add_child(back)
	if Settings.has_gamepad() and first != null:
		first.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Esc / B: back to the main menu
		get_viewport().set_input_as_handled()
		closed.emit()
