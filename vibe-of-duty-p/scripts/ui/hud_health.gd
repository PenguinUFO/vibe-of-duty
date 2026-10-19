class_name HudHealth
extends Control
## Bottom-left health readout: a medical cross, the number and a bar split into 25 HP cells. Damage leaves a light
## "just lost" stretch on the bar that drains after a moment; at low health the number and bar turn red and pulse.

const SIZE := Vector2(300, 58)
const NUMBER_X := 52.0
const BAR_Y := 34.0
const BAR_HEIGHT := 9.0
const CELL := 25.0          # HP per bar cell
const LOW := 0.3            # share of max health counted as low
const TRAIL_HOLD := 0.45    # seconds the lost stretch stays before draining
const TRAIL_SPEED := 1.4    # share of the bar drained per second

var _health := 100.0
var _max := 100.0
var _trail := 100.0         # where the lost stretch ends (>= _health)
var _hold := 0.0
var _flash := 0.0           # 1 right after a hit, fades
var _time := 0.0
var _plate := UiTheme.box(UiTheme.HUD_PLATE, UiTheme.CHAMFER)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE


func set_health(health: float, max_health: float) -> void:
	if health < _health:
		_trail = maxf(_trail, _health)
		_hold = TRAIL_HOLD
		_flash = 1.0
	elif health > _health:
		_trail = health  # healed or respawned: no trail
	_health = health
	_max = maxf(max_health, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta * 3.0, 0.0)
	if _hold > 0.0:
		_hold -= delta
	elif _trail > _health:
		_trail = maxf(_trail - TRAIL_SPEED * _max * delta, _health)
	queue_redraw()


func _draw() -> void:
	draw_style_box(_plate, Rect2(Vector2.ZERO, SIZE))
	var share := clampf(_health / _max, 0.0, 1.0)
	var low := share <= LOW and _health > 0.0
	var pulse := 0.5 + 0.5 * sin(_time * 7.0) if low else 0.0
	var color := UiTheme.TEXT.lerp(UiTheme.DANGER, 1.0 if low else 0.0)
	color = color.lerp(Color.WHITE, maxf(_flash, pulse * 0.35))

	# Medical cross.
	var cross_color := UiTheme.DANGER if low else UiTheme.ACCENT
	draw_rect(Rect2(19, 22, 22, 8), cross_color)
	draw_rect(Rect2(26, 15, 8, 22), cross_color)

	# The number, right-aligned in room for the widest one (max health), so the bar does not move as it changes.
	var font := UiTheme.heavy_font()
	var text := str(ceili(_health))
	var room := font.get_string_size(str(ceili(_max)), HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var pos := Vector2(NUMBER_X + room - width, 44)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 5, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, color)
	var bar_x := NUMBER_X + room + 14.0
	var bar := Rect2(bar_x, BAR_Y, SIZE.x - bar_x - 18.0, BAR_HEIGHT)
	draw_string(UiTheme.bold_font(), Vector2(bar.position.x, 26), "ЗДОРОВЬЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			UiTheme.TEXT_DIM)

	# Bar: dark track, the lost stretch, the current health; cell gaps cut on top.
	draw_rect(bar, Color(0, 0, 0, 0.45))
	var trail_share := clampf(_trail / _max, 0.0, 1.0)
	if trail_share > share:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * trail_share, bar.size.y)), Color(1.0, 0.9, 0.8, 0.75))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), color)
	var cells := ceili(_max / CELL)
	for i in range(1, cells):
		var x := bar.position.x + bar.size.x * i * CELL / _max
		draw_rect(Rect2(x - 1.0, bar.position.y, 2.0, bar.size.y), UiTheme.HUD_PLATE)
