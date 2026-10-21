class_name KidModeEntry
extends HBoxContainer
## Menu item "Kid mode" with a 4-digit code field beside it (main menu and pause menu). With the right code typed in,
## the button emits `open_requested` (the caller opens KidPanel); otherwise it only shakes off. The code is not kept:
## the field is cleared once the panel opens.

signal open_requested

const CODE := "0451"

var _button: Button
var _code: LineEdit


func _init() -> void:
	add_theme_constant_override("separation", 10)
	_button = Button.new()
	_button.theme_type_variation = "BigButton"
	_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button.pressed.connect(_on_pressed)
	add_child(_button)
	_code = LineEdit.new()
	_code.max_length = CODE.length()
	_code.secret = true
	_code.placeholder_text = "код"
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.custom_minimum_size = Vector2(76, 0)
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code.text_changed.connect(_on_code_changed)
	_code.text_submitted.connect(func(_t: String) -> void: _on_pressed())
	add_child(_code)
	refresh()


## Shows whether kid mode is on (call after KidPanel closes).
func refresh() -> void:
	_button.text = "Детский режим" + (": вкл" if Settings.kid_mode else "")


func _on_code_changed(text: String) -> void:
	var digits := ""
	for c in text:
		if c >= "0" and c <= "9":
			digits += c
	if digits != text:
		_code.text = digits
		_code.caret_column = digits.length()


func _on_pressed() -> void:
	Audio.play("ui_click")
	if _code.text == CODE:
		_code.text = ""
		open_requested.emit()
		return
	_code.text = ""
	_code.grab_focus()
	var x := _code.position.x
	var tween := _code.create_tween()
	for offset in [8.0, -8.0, 5.0, -5.0, 0.0]:
		tween.tween_property(_code, "position:x", x + offset, 0.04)
