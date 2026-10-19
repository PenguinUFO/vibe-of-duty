class_name HeadshotMark
extends Control
## The kill feed's headshot sign, drawn: a head (circle) with a crosshair on it.

const SIZE := Vector2(18, 18)


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var c := SIZE * 0.5
	draw_circle(c, 6.5, UiTheme.HIGHLIGHT, false, 2.0, true)
	draw_circle(c, 1.8, UiTheme.HIGHLIGHT, true, -1.0, true)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * 5.0, c + dir * 9.0, UiTheme.HIGHLIGHT, 2.0)
