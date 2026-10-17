class_name Crosshair
extends Control
## Dynamic crosshair: the four ticks open with weapon spread, hide when aiming down sights, and a
## hit marker (X) flashes when a shot hits a player.

const GAP_MIN := 4.0
const LENGTH := 9.0
const HIT_TIME := 0.18

var _gap := GAP_MIN
var _ads := 0.0
var _hit_left := 0.0
var _hit_strong := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_state(spread_px: float, ads: float) -> void:
	_gap = GAP_MIN + spread_px
	_ads = ads
	queue_redraw()


func show_hit(strong: bool = false) -> void:
	_hit_left = HIT_TIME
	_hit_strong = strong


func _process(delta: float) -> void:
	if _hit_left > 0.0:
		_hit_left = maxf(_hit_left - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var color := Color(1, 1, 1, 0.9 * (1.0 - _ads))
	if color.a > 0.02:
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(dir * _gap, dir * (_gap + LENGTH), color, 2.0)
		draw_circle(Vector2.ZERO, 1.5, color)
	if _hit_left > 0.0:
		var a := _hit_left / HIT_TIME
		var c := Color(1, 0.25, 0.25, a) if _hit_strong else Color(1, 1, 1, a)
		var outer := 18.0 if _hit_strong else 14.0
		for diag in [Vector2(1, 1), Vector2(1, -1)]:
			draw_line(diag * 6.0, diag * outer, c, 2.5)
			draw_line(-diag * 6.0, -diag * outer, c, 2.5)
