class_name HudAmmo
extends Control
## Bottom-right ammo readout: the weapon name, the rounds in the magazine (big) and in reserve (small), and a row of
## round ticks that go out as the magazine empties (a plain bar for big magazines). The magazine count turns red when
## a quarter or less is left; while reloading the name line says so.

const SIZE := Vector2(250, 80)
const LOW := 0.25
const MAX_TICKS := 40       # bigger magazines get a bar instead of ticks
const ROW := Rect2(18, 62, 214, 8)
const INFINITE := -1        # reserve that never runs out (training): shown as "/ ∞"

var _name := ""
var _mag := 0
var _mag_size := 1
var _reserve := 0
var _reloading := false
var _time := 0.0
var _plate := UiTheme.box(UiTheme.HUD_PLATE, UiTheme.CHAMFER)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE


func set_state(weapon_name: String, mag: int, mag_size: int, reserve: int, reloading: bool) -> void:
	if weapon_name == _name and mag == _mag and mag_size == _mag_size and reserve == _reserve and reloading == _reloading:
		return
	_name = weapon_name
	_mag = mag
	_mag_size = maxi(mag_size, 1)
	_reserve = reserve
	_reloading = reloading
	queue_redraw()


func _process(delta: float) -> void:
	if _reloading:
		_time += delta
		queue_redraw()  # the reload line blinks


func _draw() -> void:
	draw_style_box(_plate, Rect2(Vector2.ZERO, SIZE))
	var right := SIZE.x - 18.0
	var low := float(_mag) <= _mag_size * LOW
	var mag_color := UiTheme.DANGER if low else UiTheme.TEXT

	var small := UiTheme.bold_font()
	if _reloading:
		var blink := 0.55 + 0.45 * absf(sin(_time * 5.0))
		draw_string(small, Vector2(18, 22), "ПЕРЕЗАРЯДКА", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UiTheme.ACCENT, blink))
	else:
		draw_string(small, Vector2(18, 22), _name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.TEXT_DIM)

	# "30 / 90": the reserve right-aligned, the magazine count in front of it.
	var reserve_text := "/ ∞" if _reserve == INFINITE else "/ %d" % _reserve
	var reserve_width := small.get_string_size(reserve_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(small, Vector2(right - reserve_width, 50), reserve_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			UiTheme.TEXT_DIM)
	var big := UiTheme.heavy_font()
	var mag_text := str(_mag)
	var mag_width := big.get_string_size(mag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var mag_pos := Vector2(right - reserve_width - 8.0 - mag_width, 50)
	draw_string_outline(big, mag_pos, mag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, 5, Color(0, 0, 0, 0.6))
	draw_string(big, mag_pos, mag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, mag_color)

	# Rounds row, filled from the right.
	var spent := Color(1, 1, 1, 0.12)
	var full := UiTheme.DANGER if low else UiTheme.ACCENT
	if _mag_size > MAX_TICKS:
		draw_rect(ROW, spent)
		var w := ROW.size.x * _mag / _mag_size
		draw_rect(Rect2(ROW.end.x - w, ROW.position.y, w, ROW.size.y), full)
		return
	var step := minf(ROW.size.x / _mag_size, 9.0)
	var tick := maxf(step - 2.0, 1.0)
	for i in _mag_size:
		var x := ROW.end.x - step * (i + 1) + (step - tick)
		draw_rect(Rect2(x, ROW.position.y, tick, ROW.size.y), full if i < _mag else spent)
