class_name PinDialog
extends Control
## Modal 4-digit code prompt. Emits `finished(true)` on the right code; a wrong code or Cancel / Esc / B closes it with
## `finished(false)`.

signal finished(ok: bool)

const CODE_LENGTH := 4

var _code: String
var _edit: LineEdit


func _init(code: String = "") -> void:
	_code = code
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # blocks the menu behind

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.13, 0.98)
	style.set_content_margin_all(22.0)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Введите код из 4 цифр"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	_edit = LineEdit.new()
	_edit.max_length = CODE_LENGTH
	_edit.secret = true
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_edit.text_changed.connect(_on_text_changed)
	_edit.text_submitted.connect(func(_t: String) -> void: _submit())
	box.add_child(_edit)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var ok := Button.new()
	ok.text = "ОК"
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_submit)
	buttons.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: _finish(false))
	buttons.add_child(cancel)


func _ready() -> void:
	_edit.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # Esc / B
		get_viewport().set_input_as_handled()
		_finish(false)


## Digits only; checks the code as soon as the last digit is typed.
func _on_text_changed(text: String) -> void:
	var digits := ""
	for c in text:
		if c >= "0" and c <= "9":
			digits += c
	if digits != text:
		_edit.text = digits
		_edit.caret_column = digits.length()
	if digits.length() == CODE_LENGTH:
		_submit()


func _submit() -> void:
	_finish(_edit.text == _code)


func _finish(ok: bool) -> void:
	finished.emit(ok)
	queue_free()
