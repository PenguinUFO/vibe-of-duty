class_name ChestBomb
extends Node3D
## The "Хрях-бабах"'s bomb (Docs/LOADOUT.md): a red bomb strapped to the chest, a black timer box on it. Seen by everybody:
## others read the build by it. Armed (`arm`), the timer counts down and the lamp blinks faster; the blast itself is the
## server's (Grenades).
##
## Frame: -Z out of the chest, +Y up the body, the origin on the skin. Built from primitives, as GrenadeCannon.

const RADIUS := 0.085        # m: the red ball
const RED := Color(0.62, 0.05, 0.03)
const BLACK := Color(0.03, 0.03, 0.03)
const STRAP := Color(0.09, 0.08, 0.07)
const LAMP := Color(1.0, 0.2, 0.02)   # Palette's signal: danger
const IDLE_TEXT := "--"
const VIEW_PRIORITY := 100   # first person: after the blur round an optic's window (ScopeBlur) too

var rise := 0.0              # first person: 0 under the view .. 1 up in it (PlayerView.pose_bomb_view)

var _left := -1.0            # s on the timer, < 0: not armed
var _body: MeshInstance3D
var _face: MeshInstance3D
var _digits: Label3D
var _lamp: MeshInstance3D
var _straps: Array[MeshInstance3D] = []


func _init() -> void:
	var ball := SphereMesh.new()
	ball.radius = RADIUS
	ball.height = RADIUS * 2.0
	ball.radial_segments = 14
	ball.rings = 7
	_body = _add(ball, _matte(RED), Vector3(0.0, 0.0, -RADIUS * 0.55))
	_body.scale = Vector3(1.0, 1.0, 0.75)
	for y in [0.045, -0.045]:  # the straps round the chest
		_straps.append(_add(_box(Vector3(0.28, 0.016, 0.03)), _matte(STRAP), Vector3(0.0, y, -0.018)))
	_face = _add(_box(Vector3(0.09, 0.05, 0.022)), _matte(BLACK), Vector3(0.0, 0.0, -RADIUS * 1.42))
	_digits = Label3D.new()
	_digits.text = IDLE_TEXT
	_digits.pixel_size = 0.0011
	_digits.font_size = 32
	_digits.outline_size = 0
	_digits.modulate = LAMP
	_digits.shaded = false
	_digits.double_sided = false
	_digits.position = Vector3(0.0, 0.0, -RADIUS * 1.42 - 0.0125)
	_digits.rotation.y = PI  # a label faces +Z
	add_child(_digits)
	var dot := SphereMesh.new()
	dot.radius = 0.009
	dot.height = 0.018
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = LAMP
	_lamp = _add(dot, glow, Vector3(0.0, RADIUS * 0.8, -RADIUS * 0.8))
	_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lamp.visible = false


## First person: no chest under it, so no straps; drawn over everything - aiming, the gun covers the bottom of the view.
## Without the depth test the order is by hand: the parts in the order they were added, after the rest of the frame.
func set_view_only() -> void:
	for strap in _straps:
		strap.visible = false
	var priority := VIEW_PRIORITY
	for part in [_body, _face, _lamp]:
		var material := (part as MeshInstance3D).material_override as StandardMaterial3D
		material.no_depth_test = true
		material.render_priority = priority
		priority += 1
	_digits.no_depth_test = true
	_digits.render_priority = priority


## Starts the timer (`seconds` > 0) or puts it out.
func arm(seconds: float) -> void:
	_left = seconds
	_digits.text = IDLE_TEXT
	_lamp.visible = false


func _process(delta: float) -> void:
	if _left < 0.0:
		return
	_left = maxf(_left - delta, 0.0)
	_digits.text = "%.1f" % _left
	_lamp.visible = fmod(_left, clampf(_left * 0.25, 0.06, 0.3)) < 0.05


func _add(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	add_child(part)
	return part


static func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


static func _matte(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material
