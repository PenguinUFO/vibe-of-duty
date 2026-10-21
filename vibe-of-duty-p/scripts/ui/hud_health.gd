class_name HudHealth
extends Control
## Bottom-left health readout: a medical cross and a solid bar - no number (the owner's call: health is felt, not
## counted). Damage leaves a light "just lost" stretch on the bar that drains after a moment; at low health the bar
## turns red and pulses. Everything sits PAD from the plate's edges.

const SIZE := Vector2(160, 58)
const PAD := 18.0
const CROSS := 22.0         # cross size; the bar starts a gap after it
const BAR_X := PAD + CROSS + 12.0
const BAR_HEIGHT := 9.0
const BAR_Y := SIZE.y - PAD - BAR_HEIGHT
const LABEL_BASELINE := PAD + 8.0  # the label's caps (11 px font) start at PAD
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
	draw_rect(Rect2(PAD, PAD + (CROSS - 8.0) * 0.5, CROSS, 8), cross_color)
	draw_rect(Rect2(PAD + (CROSS - 8.0) * 0.5, PAD, 8, CROSS), cross_color)

	var bar := Rect2(BAR_X, BAR_Y, SIZE.x - BAR_X - PAD, BAR_HEIGHT)
	draw_string(UiTheme.bold_font(), Vector2(bar.position.x, LABEL_BASELINE), "ЗДОРОВЬЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			UiTheme.TEXT_DIM)

	# Bar: dark track, the lost stretch, the current health.
	draw_rect(bar, Color(0, 0, 0, 0.45))
	var trail_share := clampf(_trail / _max, 0.0, 1.0)
	if trail_share > share:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * trail_share, bar.size.y)), Color(1.0, 0.9, 0.8, 0.75))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), color)
