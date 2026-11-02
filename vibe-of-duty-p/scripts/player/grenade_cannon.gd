class_name GrenadeCannon
extends Node3D
## The "Гренадир"'s chest cannon (Docs/LOADOUT.md): a short cast-iron barrel set into the middle of the chest - a third
## of the cartoon one's length. The shirt is torn round it, the bare skin sewn to an iron collar with staples, dried
## blood running down from the seam; two hydraulic rods push the barrel out. Folded it is a stub in its collar, small
## but seen from outside (others read the build by it); launching, the barrel slides out (`extend`). A red lamp on the
## collar is lit while the grenade is in (`loaded`).
##
## Frame: -Z out of the chest, +Y up the body, the origin on the skin. Built from primitives; the third-person body
## (Mannequin) and the first-person view (PlayerView) use the same one.

const IN := 0.035            # m the barrel stands out of the collar folded...
const OUT := 0.13            # ...and out
const BARREL_RADIUS := 0.034
const LIP_RADIUS := 0.045
const BORE_RADIUS := 0.026
const COLLAR_RADIUS := 0.052
const PATCH_RADIUS := 0.085  # the bare skin round the collar, where the shirt is torn
const IRON := Color(0.15, 0.15, 0.16)
const SKIN_RAW := Color(0.62, 0.36, 0.33)  # the skin round the wound: raw, pinker than Mannequin.SKIN
const SCAR := Color(0.42, 0.13, 0.11)
const BLOOD := Color(0.24, 0.03, 0.02)
const STAPLE := Color(0.5, 0.5, 0.52)
const LAMP := Color(1.0, 0.2, 0.02)   # Palette's signal: danger
const STAPLES := 7
const RODS := [Vector2(-0.04, 0.0), Vector2(0.04, 0.0)]  # where the rods sit on the collar (x, y)

var extend := 0.0:
	set(value):
		extend = clampf(value, 0.0, 1.0)
		_place_barrel()
var loaded := true:
	set(value):
		loaded = value
		if _lamp != null:
			_lamp.visible = value

var _barrel: Node3D
var _rods: Array[MeshInstance3D] = []
var _lamp: MeshInstance3D


func _init() -> void:
	var iron := _metal(IRON)
	# Bare raw skin where the shirt is torn, a swollen scar round the collar, staples across it, blood running down.
	_add(_disc(PATCH_RADIUS, 0.012), _flesh(SKIN_RAW), Vector3(0.0, 0.0, 0.002))
	var scar := TorusMesh.new()
	scar.inner_radius = COLLAR_RADIUS - 0.002
	scar.outer_radius = COLLAR_RADIUS + 0.016
	scar.rings = 16
	scar.ring_segments = 5
	var scar_part := _add(scar, _flesh(SCAR), Vector3(0.0, 0.0, -0.004))
	scar_part.rotation.x = PI * 0.5
	scar_part.scale = Vector3(1.0, 0.45, 1.0)
	var staple_mesh := _box(Vector3(0.026, 0.004, 0.005))
	var steel := _metal(STAPLE)
	for k in STAPLES:
		var angle := TAU * (k + 0.5) / STAPLES
		var staple := _add(staple_mesh, steel, Vector3(cos(angle), sin(angle), 0.0) * (COLLAR_RADIUS + 0.007)
				+ Vector3(0.0, 0.0, -0.01))
		staple.rotation.z = angle
	var blood := _flesh(BLOOD)
	for drip: Vector3 in [Vector3(-0.022, 0.07, 0.008), Vector3(0.015, 0.1, 0.007), Vector3(0.034, 0.05, 0.006)]:
		var streak := _add(_box(Vector3(drip.z, drip.y, 0.004)), blood,
				Vector3(drip.x, -COLLAR_RADIUS - 0.005 - drip.y * 0.5, -0.003))
		streak.rotation.z = drip.x * 2.0
	# The collar: an iron ring bolted through the skin.
	var collar := _add(_disc(COLLAR_RADIUS, 0.026), iron, Vector3(0.0, 0.0, -0.01))
	collar.name = "Collar"
	var bolt := _sphere(0.006)
	for k in 6:
		var angle := TAU * k / 6.0 + 0.3
		_add(bolt, iron, Vector3(cos(angle), sin(angle), 0.0) * (COLLAR_RADIUS - 0.009) + Vector3(0.0, 0.0, -0.024))
	_lamp = _add(_sphere(0.007), _glow(LAMP), Vector3(0.0, COLLAR_RADIUS - 0.012, -0.026))
	_lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The barrel (slides out): the tube, a flared lip, the dark bore.
	_barrel = Node3D.new()
	add_child(_barrel)
	var tube := _cylinder(BARREL_RADIUS, 1.0)
	var tube_part := MeshInstance3D.new()
	tube_part.name = "Tube"
	tube_part.mesh = tube
	tube_part.material_override = iron
	tube_part.rotation.x = PI * 0.5
	_barrel.add_child(tube_part)
	var lip := MeshInstance3D.new()
	lip.name = "Lip"
	lip.mesh = _cylinder(LIP_RADIUS, 0.02)
	lip.material_override = iron
	lip.rotation.x = PI * 0.5
	_barrel.add_child(lip)
	var bore := MeshInstance3D.new()
	bore.name = "Bore"
	bore.mesh = _cylinder(BORE_RADIUS, 0.004)
	bore.material_override = _flesh(Color(0.01, 0.01, 0.01))
	bore.rotation.x = PI * 0.5
	_barrel.add_child(bore)
	for rod_at: Vector2 in RODS:
		var rod := MeshInstance3D.new()
		rod.mesh = _cylinder(0.005, 1.0)
		rod.material_override = steel
		add_child(rod)
		rod.set_meta("at", rod_at)
		_rods.append(rod)
	_place_barrel()


## First person: only the barrel and its rods (the skin, the collar and the lamp are under the view, seen from behind).
func set_barrel_only() -> void:
	for child in get_children():
		if child != _barrel and not child in _rods:
			(child as Node3D).visible = false
	_lamp = null


## The muzzle (world): where the grenade comes out.
func muzzle_global_position() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, -_length() - 0.012)


func _length() -> float:
	return lerpf(IN, OUT, extend) + 0.02  # from the skin: the collar's depth too


func _place_barrel() -> void:
	if _barrel == null:
		return
	var length := _length()
	var tube := _barrel.get_node("Tube") as Node3D
	tube.scale = Vector3(1.0, length, 1.0)
	tube.position = Vector3(0.0, 0.0, -length * 0.5)
	(_barrel.get_node("Lip") as Node3D).position = Vector3(0.0, 0.0, -length + 0.008)
	(_barrel.get_node("Bore") as Node3D).position = Vector3(0.0, 0.0, -length - 0.0005)
	# The rods: from the collar's face to the lip, beside the barrel; folded they hide in the collar.
	for rod in _rods:
		var at: Vector2 = rod.get_meta("at")
		var from := Vector3(at.x, at.y, -0.02)
		var to := Vector3(at.x * 1.05, at.y, -length + 0.012)
		var span := from.distance_to(to)
		rod.visible = span > 0.02
		rod.position = (from + to) * 0.5
		rod.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		rod.scale = Vector3(1.0, maxf(span, 0.001), 1.0)


func _add(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = pos
	add_child(part)
	return part


## A flat cylinder facing -Z (along the cannon), `depth` thick.
static func _disc(radius: float, depth: float) -> Mesh:
	var mesh := _cylinder(radius, depth)
	var arrays := mesh.get_mesh_arrays()
	var turned := ArrayMesh.new()
	var basis := Basis(Vector3.RIGHT, PI * 0.5)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = basis * verts[i]
		normals[i] = basis * normals[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	turned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return turned


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
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


## Cast iron: dark and sharp, like the "Инженер"'s chip (a soft one goes brown in the build screen's orange rim light).
static func _metal(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.75
	m.roughness = 0.45
	m.metallic_specular = 0.2
	return m


static func _flesh(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	return m


static func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m
