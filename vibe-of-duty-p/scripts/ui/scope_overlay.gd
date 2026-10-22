class_name ScopeOverlay
extends Control
## Looking through a magnified scope (WeaponDef.scope, the PSO-1): black around the eyepiece's circle and the PSO
## reticle - the aiming chevron at screen centre (where shots go), three hold-over chevrons under it, the windage scale
## and the range finder (a 1.7 m tall target fits between its line and curve at 200..1000 m). The field of view itself
## is zoomed by the weapon's ads_zoom (Player). While the aim comes up the screen blinks dark, and the gun model is
## hidden under that blink (hides_view) - the eyepiece would fill the screen otherwise.

const RADIUS := 0.44              # the circle, share of the screen height
const MIL := RADIUS / 52.0        # reticle unit (a real PSO's circle is ~105 mil across), share of the screen height
const COLOR := Color(0.85, 0.2, 0.1)  # the reticle's lit red

var _amount := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## How far into the scope the eye is (0..1) at this aim blend.
static func amount_at(ads: float) -> float:
	return smoothstep(0.7, 0.95, ads)


## `amount`: amount_at(ads) when aiming a scope, else 0.
func set_amount(amount: float) -> void:
	if is_equal_approx(amount, _amount):
		return
	_amount = amount
	visible = amount > 0.0
	queue_redraw()


## The gun model should be hidden: the eye is at the eyepiece (behind the blink).
func hides_view() -> bool:
	return _amount >= 0.5


func _draw() -> void:
	var screen := get_size()
	var center := screen * 0.5
	var radius := screen.y * RADIUS
	var black := Color(0.0, 0.0, 0.0, _amount)
	# Everything outside the circle: one ring as wide as the screen's diagonal.
	var ring := screen.length()
	draw_arc(center, radius + ring * 0.5, 0.0, TAU, 96, black, ring)
	draw_arc(center, radius + 3.0, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, _amount * 0.6), 8.0)  # soft edge
	var color := Color(COLOR, _amount * 0.9)
	var u := screen.y * MIL
	var width := maxf(1.0, screen.y / 720.0)
	# Aiming chevron, its tip at the centre, and the hold-overs below it.
	for i in 4:
		var tip := center + Vector2(0.0, (0.0 if i == 0 else 3.0 + 2.5 * i) * u)
		var size := (1.6 if i == 0 else 1.0) * u
		draw_polyline([tip + Vector2(-size, size * 1.5), tip, tip + Vector2(size, size * 1.5)], color, width)
	# Windage scale: a tick every unit, longer at 5 and 10.
	for side in [-1.0, 1.0]:
		draw_line(center + Vector2(side * 2.5 * u, 0.0), center + Vector2(side * 10.0 * u, 0.0), color, width)
		for i in range(3, 11):
			var tick := (1.2 if i % 5 == 0 else 0.6) * u
			draw_line(center + Vector2(side * i * u, 0.0), center + Vector2(side * i * u, tick), color, width)
	# Range finder, lower left: the base line and the curve 1.7 m above it (17 / hundreds of metres, in units).
	var base_y := center.y + 12.0 * u
	var x_near := center.x - 4.0 * u
	var x_far := center.x - 15.0 * u
	draw_line(Vector2(x_far, base_y), Vector2(x_near, base_y), color, width)
	var curve: PackedVector2Array = []
	var font := ThemeDB.fallback_font
	var font_size := int(maxf(10.0, 1.1 * u))
	for step in 17:
		var hundreds := 2.0 + step * 0.5
		var x := lerpf(x_near, x_far, (hundreds - 2.0) / 8.0)
		curve.append(Vector2(x, base_y - 17.0 / hundreds * u))
		if step % 4 == 0:
			draw_string(font, Vector2(x - 0.4 * u, base_y + 1.6 * u), str(int(hundreds)), HORIZONTAL_ALIGNMENT_LEFT,
					-1, font_size, color)
	draw_polyline(curve, color, width)
	# Blink while the eye comes to the eyepiece: darkest when the gun model goes.
	var blink := 1.0 - absf(_amount * 2.0 - 1.0)
	if blink > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.0, 0.0, 0.0, blink * 0.85))
