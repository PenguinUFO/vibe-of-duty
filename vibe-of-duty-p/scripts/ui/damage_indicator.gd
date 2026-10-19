class_name DamageIndicator
extends Control
## Red arcs around the screen centre pointing to where hits came from. Each arc keeps pointing at the shooter's position
## (at the time of the shot) as the player turns, and fades out.

const LIFE := 1.6           # seconds an arc stays
const RADIUS := 120.0
const SPAN := 0.55          # arc length, radians
const MAX_ARCS := 6

var camera: Camera3D        # the view the arcs are relative to
var _arcs: Array[Dictionary] = []  # {from: Vector3, left: float}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)


## A hit from a shooter standing at `from` (world position).
func add(from: Vector3) -> void:
	for arc in _arcs:
		if arc["from"].distance_to(from) < 1.0:  # the same shooter again: refresh the arc instead of stacking
			arc["from"] = from
			arc["left"] = LIFE
			return
	_arcs.append({"from": from, "left": LIFE})
	if _arcs.size() > MAX_ARCS:
		_arcs.pop_front()


func clear() -> void:
	_arcs.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _arcs.is_empty():
		return
	for arc in _arcs:
		arc["left"] -= delta
	_arcs = _arcs.filter(func(arc: Dictionary) -> bool: return arc["left"] > 0.0)
	queue_redraw()


func _draw() -> void:
	if camera == null:
		return
	var xform := camera.global_transform
	for arc in _arcs:
		var local: Vector3 = xform.basis.inverse() * (arc["from"] - xform.origin)
		var flat := Vector2(local.x, -local.z)  # x right, y ahead
		if flat.length_squared() < 0.01:
			continue
		var angle := atan2(flat.x, flat.y) - PI * 0.5  # screen angle: ahead is up (-90 degrees)
		var fade: float = clampf(arc["left"] / LIFE * 1.6, 0.0, 1.0)
		var red := Color(UiTheme.DANGER, 0.85 * fade)
		draw_arc(Vector2.ZERO, RADIUS + 6.0, angle - SPAN * 0.6, angle + SPAN * 0.6, 24, Color(red, red.a * 0.25), 16.0, true)
		draw_arc(Vector2.ZERO, RADIUS, angle - SPAN * 0.5, angle + SPAN * 0.5, 24, red, 7.0, true)
		# A small pointer on the outside of the arc's middle.
		var dir := Vector2.from_angle(angle)
		var tip := dir * (RADIUS + 22.0)
		var side := dir.orthogonal() * 7.0
		draw_colored_polygon(PackedVector2Array([tip, dir * (RADIUS + 8.0) + side, dir * (RADIUS + 8.0) - side]), red)
