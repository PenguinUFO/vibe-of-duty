class_name BuildMenu
extends PanelContainer
## Pause menu: pick the build to play among the saved ones (Settings.builds; editing them is the main menu's,
## BuildPanel). In a match it is played from the next life (as BuildPicker after death), on a training map at once.

signal closed
signal picked

var world: NetWorld

var _box: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(540, 0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)

	var title := Label.new()
	title.text = "СБОРКА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "PanelTitle"
	_box.add_child(title)
	for i in Settings.BUILD_COUNT:
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, BuildPicker.describe(i)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # the build's name is the player's
		button.toggle_mode = true
		button.button_pressed = i == Settings.build_index
		button.pressed.connect(_on_pick.bind(i))
		_box.add_child(button)
	var hint := Label.new()
	hint.text = "Сразу — на стрельбище; в матче — со следующей жизни." if Game.training \
			else "Со следующей жизни (после смерти или в новом матче)."
	hint.theme_type_variation = "Hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(hint)
	var back := Button.new()
	back.text = "Назад"
	back.pressed.connect(func() -> void: closed.emit())
	_box.add_child(back)


func _on_pick(index: int) -> void:
	Audio.play("ui_click")
	BuildPicker.pick(world, index)
	picked.emit()
