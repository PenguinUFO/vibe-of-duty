class_name KidPanel
extends PanelContainer
## Kid mode settings: everything a kid player gets that a normal one does not (Settings.kid_*). Opened from
## KidModeEntry with the code, in the main menu or mid-match from the pause menu. Changes apply at once: aim assist
## locally, health, regeneration and damage from behind through the server (NetWorld sends them).
## Saved when closed with Back.

signal closed

var _box: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(540, 0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)
	_build()


func _build() -> void:
	var title := Label.new()
	title.text = "ДЕТСКИЙ РЕЖИМ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "PanelTitle"
	_box.add_child(title)

	var on := CheckBox.new()
	on.text = "Включён"
	on.button_pressed = Settings.kid_mode
	on.toggled.connect(func(v: bool) -> void: Settings.kid_mode = v)
	_box.add_child(on)

	SettingsPanel.add_heading(_box, "Здоровье")
	SettingsPanel.add_slider(_box, "Запас здоровья", PlayerBase.MAX_HEALTH, PlayerBase.KID_HEALTH_MAX, 10.0,
			Settings.kid_health, func(v: float) -> void: Settings.kid_health = int(v), "%d")
	SettingsPanel.add_slider(_box, "Лечение начинается через", 0.0, PlayerBase.REGEN_DELAY, 0.25,
			Settings.kid_regen_delay, func(v: float) -> void: Settings.kid_regen_delay = v, "%.2f с")
	SettingsPanel.add_slider(_box, "Урон в спину", 0.0, 1.0, 0.05, Settings.kid_back_damage,
			func(v: float) -> void: Settings.kid_back_damage = v, "%d%%", true)

	SettingsPanel.add_heading(_box, "Помощь в прицеливании")
	SettingsPanel.add_slider(_box, "Сила", 1.0, Settings.KID_ASSIST_MULT_MAX, 0.1, Settings.kid_assist_mult,
			func(v: float) -> void: Settings.kid_assist_mult = v, "×%.1f")
	SettingsPanel.add_slider(_box, "Ширина зоны", 1.0, Settings.KID_ASSIST_MULT_MAX, 0.1, Settings.kid_assist_reach,
			func(v: float) -> void: Settings.kid_assist_reach = v, "×%.1f")
	SettingsPanel.add_slider(_box, "Доводка в прицеле", 0.0, Settings.KID_ADS_PULL_MAX, 0.5, Settings.kid_ads_pull,
			func(v: float) -> void: Settings.kid_ads_pull = v, "%.1f")
	var unlimited := CheckBox.new()
	unlimited.text = "Без предела дальности (иначе %d м)" % AimAssist.RANGE
	unlimited.button_pressed = Settings.kid_assist_unlimited
	unlimited.toggled.connect(func(v: bool) -> void: Settings.kid_assist_unlimited = v)
	_box.add_child(unlimited)
	var hint := Label.new()
	hint.text = "Помощь работает только с геймпадом и умножает общую настройку «Помощь в прицеливании»."
	hint.theme_type_variation = "Hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(hint)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	_box.add_child(buttons)
	var reset := Button.new()
	reset.text = "По умолчанию"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)
	var back := Button.new()
	back.text = "Назад"
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_on_back)
	buttons.add_child(back)


func _ready() -> void:
	_focus_first()


func _focus_first() -> void:
	if Settings.has_gamepad():  # d-pad / stick navigation needs a focused control
		for child in find_children("*", "BaseButton", true, false):
			(child as Control).grab_focus.call_deferred()
			return


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):  # Esc / B
		get_viewport().set_input_as_handled()
		_on_back()


## Defaults for the parameters; on / off stays as it is.
func _on_reset() -> void:
	Audio.play("ui_click")
	Settings.reset_kid()
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_build()
	_focus_first()


func _on_back() -> void:
	Audio.play("ui_click")
	Settings.save_settings()
	closed.emit()
