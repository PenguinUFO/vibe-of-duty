class_name AugLegs
extends Node3D
## The leg augmentations below the knee (Docs/LOADOUT.md, "Прыг-Прыг", "Прыг-скок"): the shins and trotters give way to
## a machine, the knee and the height stay (the hitbox and the eyes do not move). Both read from afar by the
## silhouette, not by colour:
##   - JET: the "Прыг-Прыг"'s pneumatic hooves - a fat steel cylinder with a bright rod, a hose from the thigh, a steel
##     hoof with a nozzle in the heel. A lamp on the cylinder is lit while the jump in the air is left (`jump_left`); the
##     jump in the air (air_jump) kicks the rods out and blows the exhaust down from both hooves.
##   - BLADES: the "Прыг-скок"'s running blades - a carbon socket under the knee and a thin J-shaped blade to the
##     ground. They flex with every landing and more with the speed; a strip down the front of each glows with the
##     speed past a sprint (`heat` 0..1, as the HUD's plate).
## Where the leg meets the machine: raw skin and staples, no blood.
##
## Mannequin space; Mannequin places each leg every pose (place_leg) from its knee, ankle and the (hidden) trotter's
## transform - in the ragdoll too.

enum Kind { NONE, JET, BLADES }

const IRON := Color(0.15, 0.15, 0.16)
const STEEL := Color(0.3, 0.31, 0.32)      # Mannequin.CYBER_STEEL: one machine with the "Руки-Хрюки"
const ROD := Color(0.5, 0.51, 0.52)
const HOSE := Color(0.06, 0.06, 0.06)
const CARBON := Color(0.05, 0.05, 0.055)
const RUBBER := Color(0.03, 0.03, 0.03)
const SKIN_RAW := Color(0.62, 0.36, 0.33)  # GrenadeCannon.SKIN_RAW
const STAPLE := Color(0.5, 0.5, 0.52)
const LIGHT_OFF := Color(0.07, 0.05, 0.04)
const STRIP_OFF := Color(0.09, 0.07, 0.06)

const BAND_AT := 0.045       # m under the knee: the raw skin band with the staples
const JET_TOP := 0.09        # the cylinder from here...
const JET_BOTTOM := 0.27     # ...to here
const JET_RADIUS := 0.052
const ROD_RADIUS := 0.02
const KICK := 0.07           # m the rods push the hooves out at a jump in the air
const SOCKET_BOTTOM := 0.17  # the blade's socket from the knee to here
const BLADE_WIDTH := 0.05
const BLADE_THICK := 0.014
const BLADE_SEGMENTS := 7
const BOW := 0.075           # m the blade bows back at rest...
const BOW_FLEX := 0.05       # ...and more, flexing

var kind := Kind.NONE
## JET: the jump in the air is left (the lamp is lit).
var jump_left := true:
	set(value):
		if value != jump_left and _lamp_material != null:
			_lamp_material.albedo_color = Palette.EMBER if value else LIGHT_OFF
		jump_left = value
## BLADES: 0..1, the speed past a sprint (the strips glow).
var heat := 0.0:
	set(value):
		heat = clampf(value, 0.0, 1.0)
		if _strip_material != null:
			_strip_material.albedo_color = STRIP_OFF.lerp(Palette.EMBER, heat)
## BLADES: 0..1+, how far the blades flex (the speed and the landings).
var flex := 0.0

var _legs: Array[Dictionary] = [{}, {}]  # per leg (L, R): its nodes
var _kick := 0.0                          # JET: the rods out, 0..1
var _kick_v := 0.0
var _lamp_material: StandardMaterial3D
var _strip_material: StandardMaterial3D
var _materials := {}


## Which of the two the build has (PartDB.JET_HOOVES / PartDB.BUNNY share the legs' slot).
static func kind_of(parts: Array) -> Kind:
	if parts.has(PartDB.JET_HOOVES):
		return Kind.JET
	if parts.has(PartDB.BUNNY):
		return Kind.BLADES
	return Kind.NONE


func _init(leg_kind: Kind) -> void:
	kind = leg_kind
	if kind == Kind.JET:
		_lamp_material = _glow(Palette.EMBER)
	else:
		_strip_material = _glow(STRIP_OFF)
	for i in 2:
		var leg := {}
		leg["band"] = _band()
		if kind == Kind.JET:
			_build_jet(leg)
		else:
			_build_blade(leg)
		_legs[i] = leg


## The jump in the air: the rods kick the hooves out and back.
func air_jump() -> void:
	_kick_v += 14.0


func advance(delta: float) -> void:
	if kind != Kind.JET or delta <= 0.0:
		return
	var s := Mannequin.spring(Vector2(_kick, 0.0), Vector2(_kick_v, 0.0), Vector2.ZERO, 4.0, 0.6, minf(delta, 0.05))
	_kick = clampf(s[0].x, 0.0, 1.0)
	_kick_v = s[1].x


## The hooves' nozzles (world), where the exhaust comes out.
func nozzles() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for leg in _legs:
		if leg.has("nozzle"):
			out.append((leg["nozzle"] as Node3D).global_position)
	return out


## Places leg `i` (0 = left): `hip`, `knee`, `ankle` and the trotter's transform `foot` (its origin half the ankle's
## height over the sole), all in mannequin space.
func place_leg(i: int, hip: Vector3, knee: Vector3, ankle: Vector3, foot: Transform3D) -> void:
	var leg := _legs[i]
	var up := (knee - ankle).normalized()
	var back := foot.basis.z.slide(up).normalized()
	if back.length() < 0.5:
		back = Vector3.BACK.slide(up).normalized()
	var shin := Basis(up.cross(back), up, back)  # y up the shin, z backwards
	_put(leg["band"], Transform3D(shin, knee - up * BAND_AT))
	if kind == Kind.JET:
		_place_jet(leg, shin, hip, knee, ankle, foot)
	else:
		_place_blade(leg, shin, knee, foot)


# --- shared --------------------------------------------------------------------------------------------------------

## The seam under the knee: a band of raw skin and six staples across it. Origin at the band's middle.
func _band() -> Node3D:
	var band := Node3D.new()
	add_child(band)
	_mesh(band, _cylinder(0.058, 0.054, 0.035), SKIN_RAW, false)
	for k in 6:
		var angle := TAU * (k + 0.5) / 6.0
		var staple := _mesh(band, _box(Vector3(0.004, 0.026, 0.004)), STAPLE, true,
				Vector3(cos(angle) * 0.058, 0.0, sin(angle) * 0.058))
		staple.rotation.y = -angle
	return band


# --- the "Прыг-Прыг": pneumatic hooves ------------------------------------------------------------------------------

func _build_jet(leg: Dictionary) -> void:
	var body := Node3D.new()
	add_child(body)
	leg["body"] = body
	var length := JET_BOTTOM - JET_TOP
	_mesh(body, _cylinder(JET_RADIUS + 0.008, JET_RADIUS + 0.008, 0.04), IRON, true, Vector3(0.0, -JET_TOP + 0.01, 0.0))
	_mesh(body, _cylinder(JET_RADIUS, JET_RADIUS * 0.92, length), STEEL, true,
			Vector3(0.0, -JET_TOP - length * 0.5, 0.0))
	for y in [JET_TOP + 0.06, JET_BOTTOM - 0.015]:  # hose clamps / the gland
		_mesh(body, _cylinder(JET_RADIUS + 0.005, JET_RADIUS + 0.005, 0.012), IRON, true, Vector3(0.0, -y, 0.0))
	var bolt := _sphere(0.006)
	for k in 4:
		var angle := TAU * k / 4.0 + 0.4
		_mesh(body, bolt, IRON, true, Vector3(cos(angle), 0.0, sin(angle)) * (JET_RADIUS + 0.008)
				+ Vector3(0.0, -JET_TOP + 0.01, 0.0))
	var lamp := MeshInstance3D.new()
	lamp.mesh = _sphere(0.009)
	lamp.material_override = _lamp_material
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.position = Vector3(0.0, -JET_TOP - 0.035, -JET_RADIUS - 0.002)
	body.add_child(lamp)
	var rod := _mesh(self, _cylinder(ROD_RADIUS, ROD_RADIUS, 1.0), ROD, true)
	leg["rod"] = rod
	var hose := _mesh(self, _cylinder(0.009, 0.009, 1.0), HOSE, false)
	leg["hose"] = hose
	# The hoof: a steel trotter (the same shape as the skin one) with two steel toes and a nozzle in the heel.
	var hoof := Node3D.new()
	add_child(hoof)
	leg["hoof"] = hoof
	_mesh(hoof, _cylinder(0.05, 0.046, Mannequin.ANKLE_H), STEEL, true)
	for s in [-1.0, 1.0]:
		var toe := _mesh(hoof, _cylinder(0.036, 0.02, 0.12), STEEL, true, Vector3(0.027 * s, -0.008, -0.055))
		toe.rotation = Vector3(-PI * 0.5, 0.06 * s, 0.0)
		toe.scale = Vector3(1.0, 1.0, 0.85)
	var nozzle := _mesh(hoof, _cylinder(0.024, 0.017, 0.03), IRON, true, Vector3(0.0, -0.025, 0.05))
	nozzle.rotation.x = -0.9  # down and back, out of the heel
	_mesh(nozzle, _cylinder(0.013, 0.013, 0.004), RUBBER, false, Vector3(0.0, -0.016, 0.0))
	leg["nozzle"] = nozzle


func _place_jet(leg: Dictionary, shin: Basis, hip: Vector3, knee: Vector3, ankle: Vector3, foot: Transform3D) -> void:
	var up := shin.y
	var out := -up * KICK * _kick  # the kick: the rod slides out, the hoof with it
	_put(leg["body"], Transform3D(shin, knee))
	var rod_top := knee - up * (JET_BOTTOM - 0.02)
	_span(leg["rod"], rod_top, ankle + out)
	_put(leg["hoof"], Transform3D(foot.basis, foot.origin + out))
	# The hose: from the back of the thigh into the cylinder's top, at its back.
	var thigh_point := knee.lerp(hip, 0.35) + shin.z * 0.075
	_span(leg["hose"], thigh_point, knee + shin * Vector3(0.0, -JET_TOP - 0.03, JET_RADIUS + 0.004))


# --- the "Прыг-скок": running blades -------------------------------------------------------------------------------

func _build_blade(leg: Dictionary) -> void:
	var socket := Node3D.new()
	add_child(socket)
	leg["socket"] = socket
	var depth := SOCKET_BOTTOM - BAND_AT - 0.015
	_mesh(socket, _cylinder(0.064, 0.042, depth), CARBON, true, Vector3(0.0, -BAND_AT - 0.015 - depth * 0.5, 0.0))
	_mesh(socket, _cylinder(0.067, 0.067, 0.014), IRON, true, Vector3(0.0, -BAND_AT - 0.02, 0.0))  # the rim
	_mesh(socket, _box(Vector3(0.03, 0.02, 0.03)), IRON, true, Vector3(0.0, -SOCKET_BOTTOM - 0.005, 0.0))  # the clamp
	var segments: Array[MeshInstance3D] = []
	var strips: Array[MeshInstance3D] = []
	for k in BLADE_SEGMENTS:
		segments.append(_mesh(self, _box(Vector3(BLADE_WIDTH, 1.0, BLADE_THICK)), CARBON, true))
		var strip := MeshInstance3D.new()
		strip.mesh = _box(Vector3(0.012, 1.0, 0.003))
		strip.material_override = _strip_material
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(strip)
		strips.append(strip)
	leg["segments"] = segments
	leg["strips"] = strips
	leg["pad"] = _mesh(self, _box(Vector3(BLADE_WIDTH + 0.006, 0.012, 0.11)), RUBBER, false)


## The blade from under the socket to the sole: down and bowed back, round at the bottom and forward along the
## ground (the toe). The more it flexes, the deeper the bow.
func _place_blade(leg: Dictionary, shin: Basis, knee: Vector3, foot: Transform3D) -> void:
	_put(leg["socket"], Transform3D(shin, knee))
	var top := knee - shin.y * (SOCKET_BOTTOM + 0.01)
	var ground := foot * Vector3(0.0, -Mannequin.ANKLE_H * 0.5, 0.0)
	var down := ground - top
	var height := down.length()
	if height < 0.05:
		return
	down /= height
	var back := foot.basis.z.slide(down).normalized()
	if back.length() < 0.5:
		back = shin.z
	var bow := BOW + BOW_FLEX * clampf(flex, 0.0, 1.5)
	# The profile: [share of the height down, share of the bow back, m back on top of it]; the last two run along the
	# ground forward (the toe), whatever the bow.
	var profile := [[0.0, 0.0, 0.0], [0.25, 0.35, 0.0], [0.5, 0.8, 0.0], [0.72, 1.0, 0.0], [0.88, 0.75, 0.0],
			[0.97, 0.25, 0.0], [1.0, 0.0, -0.03], [1.0, 0.0, -0.13]]
	var points: Array[Vector3] = []
	for p: Array in profile:
		points.append(top + down * height * p[0] + back * (bow * p[1] + p[2]))
	var side := down.cross(back)  # across the blade
	for k in BLADE_SEGMENTS:
		var a := points[k]
		var b := points[k + 1]
		var along := b - a
		var length := along.length()
		var y := along / length
		var x := side.slide(y).normalized()
		var z := x.cross(y)  # out of the blade's face; the front is the side against `back`
		var front := -z if z.dot(back) > 0.0 else z
		var basis := Basis(x, y, z)
		var segment: MeshInstance3D = leg["segments"][k]
		segment.transform = Transform3D(basis.scaled_local(Vector3(1.0, length + 0.008, 1.0)), (a + b) * 0.5)
		var strip: MeshInstance3D = leg["strips"][k]
		strip.transform = Transform3D(basis.scaled_local(Vector3(1.0, length * 0.9, 1.0)),
				(a + b) * 0.5 + front * (BLADE_THICK * 0.5 + 0.001))
		strip.visible = k < BLADE_SEGMENTS - 1  # not under the toe, on the ground
	var toe := points[BLADE_SEGMENTS]
	var heel := points[BLADE_SEGMENTS - 1]
	var pad_z := (heel - toe).normalized()
	var pad_y := (-down).slide(pad_z).normalized()
	var pad := Basis(pad_y.cross(pad_z), pad_y, pad_z)
	(leg["pad"] as Node3D).transform = Transform3D(pad, (toe + heel) * 0.5 - pad_y * (BLADE_THICK * 0.5 + 0.006))


# --- helpers -------------------------------------------------------------------------------------------------------

static func _put(node: Node3D, xform: Transform3D) -> void:
	node.transform = xform


## A unit-height cylinder part (axis Y) stretched from `a` to `b`.
static func _span(part: Node3D, a: Vector3, b: Vector3) -> void:
	var along := b - a
	var length := along.length()
	if length < 0.001:
		part.visible = false
		return
	part.visible = true
	var y := along / length
	var x := Vector3.FORWARD.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	part.transform = Transform3D(Basis(x, y, x.cross(y)).scaled_local(Vector3(1.0, length, 1.0)), (a + b) * 0.5)


func _mesh(parent: Node3D, mesh: Mesh, color: Color, metal: bool, pos := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = _material(color, metal)
	part.position = pos
	parent.add_child(part)
	return part


func _material(color: Color, metal: bool) -> StandardMaterial3D:
	var key := "%s|%s" % [color, metal]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		# Dark and sharp like the chip and the cannon (a soft metal goes brown in the build screen's orange rim light).
		m.metallic = 0.75 if metal else 0.0
		m.roughness = 0.4 if metal else 0.6
		m.metallic_specular = 0.2 if metal else 0.5
		_materials[key] = m
	return _materials[key]


static func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh
