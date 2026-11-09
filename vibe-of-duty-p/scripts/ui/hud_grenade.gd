class_name HudGrenade
extends Control
## Bottom-left, over the health plate: the grenade (owner, 2026-11-09: the only sign left of the augmentations' row).
## A small plate with the cast-iron ball and its lamp; it dims once the life's grenade is thrown.

const PLATE := 40.0
const GAP := 6.0
const SIZE := Vector2(PLATE, PLATE)
const INK := UiTheme.TEXT
const SPENT := Color(UiTheme.TEXT_DIM, 0.6)

var _loaded := true
var _plate := UiTheme.box(UiTheme.HUD_PLATE, UiTheme.CHAMFER)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE


## `loaded`: the grenade is still there this life.
func set_loaded(loaded: bool) -> void:
	if loaded != _loaded:
		_loaded = loaded
		queue_redraw()


func _draw() -> void:
	var half := SIZE * 0.5
	draw_set_transform(half)
	draw_style_box(_plate, Rect2(-half, SIZE))
	draw_circle(Vector2(0, 2), 10.0, INK if _loaded else SPENT)
	draw_circle(Vector2(0, -8), 3.0, UiTheme.DANGER if _loaded else SPENT)  # its lamp (Grenade.LAMP)
	draw_set_transform(Vector2.ZERO)
