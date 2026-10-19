class_name Crosshair
extends Control
## Dynamic crosshair: the four ticks open with weapon spread and hide when aiming down sights; a ring around it fills
## while reloading. Hit markers (X): white for a hit, yellow for a headshot, a bigger red one for a kill.

const GAP_MIN := 4.0
const LENGTH := 9.0
const HIT_TIME := 0.18
const KILL_TIME := 0.4
const RING_RADIUS := 24.0

var _gap := GAP_MIN
var _ads := 0.0
var _reload := -1.0   # 0..1 while reloading, else < 0
var _hit_left := 0.0
var _hit_time := HIT_TIME
var _hit_kind := 0    # 0 hit, 1 headshot, 2 kill


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func update_state(spread_px: float, ads: float, reload := -1.0) -> void:
	_gap = GAP_MIN + spread_px
	_ads = ads
	_reload = reload
	queue_redraw()


func show_hit(killed: bool = false, head: bool = false) -> void:
	_hit_kind = 2 if killed else (1 if head else 0)
	_hit_time = KILL_TIME if killed else HIT_TIME
	_hit_left = _hit_time


func _process(delta: float) -> void:
	if _hit_left > 0.0:
		_hit_left = maxf(_hit_left - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var color := Color(1, 1, 1, 0.9 * (1.0 - _ads))
	if color.a > 0.02:
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(dir * _gap, dir * (_gap + LENGTH), Color(0, 0, 0, color.a * 0.5), 4.0)  # dark edge for bright skies
			draw_line(dir * _gap, dir * (_gap + LENGTH), color, 2.0)
		draw_circle(Vector2.ZERO, 1.5, color)
	if _reload >= 0.0:
		draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 48, Color(0, 0, 0, 0.35), 4.0, true)
		draw_arc(Vector2.ZERO, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * _reload, 48, UiTheme.ACCENT, 3.0, true)
	if _hit_left > 0.0:
		var a := _hit_left / _hit_time
		var c: Color = [Color.WHITE, UiTheme.HIGHLIGHT, UiTheme.DANGER][_hit_kind]
		c.a = a
		var inner := 8.0
		var outer := 18.0
		var width := 2.5
		if _hit_kind == 1:
			outer = 22.0
		elif _hit_kind == 2:
			var grow := 1.0 - a  # the kill marker opens out as it fades
			inner = 9.0 + grow * 5.0
			outer = 26.0 + grow * 8.0
			width = 3.5
		for diag in [Vector2(1, 1), Vector2(1, -1)]:
			var d := (diag as Vector2).normalized()
			draw_line(d * inner, d * outer, Color(0, 0, 0, a * 0.5), width + 2.0)
			draw_line(-d * inner, -d * outer, Color(0, 0, 0, a * 0.5), width + 2.0)
			draw_line(d * inner, d * outer, c, width)
			draw_line(-d * inner, -d * outer, c, width)
