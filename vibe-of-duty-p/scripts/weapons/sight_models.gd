class_name SightModels
extends RefCounted
## Blockout models of the optics a gun can carry (WeaponDef.sight), built in code and put on the gun's model by
## WeaponView. Prefab space as in tools/make_ak_blockout.py: the barrel to +Z, +Y up, +X the shooter's left (the AK's
## side rail is on the left). Each optic sits where WeaponDB.MODULE_GEOMETRY puts its aim line.
##
## A red dot sight (collimator, not magnifying) has a node "Dot" and its window in the optic's metadata: "dot_z" (the
## glass the dot shows on), "window_center" (x, y), "window_radius", "dot_angle" (the dot's angular radius, rad).
## WeaponView puts the dot where the aim line from the eye crosses that glass (WeaponView._aim_dot): it is at
## infinity, so it marks where the gun points from wherever the eye is, and is seen only through the window.

const DOT_RADIUS := 0.0012  # the dot sphere's own radius (WeaponView scales it to dot_angle)


## The optic's model, or null for iron sights / an unknown name.
static func build(sight: String) -> Node3D:
	match sight:
		"kobra":
			return _kobra()
		"pso":
			return _pso()
		"compm":
			return _compm()
	return null


## Kobra red dot: a side-rail bracket, a plate over the dust cover and a box housing with a window; the dot is on the
## aim line (0, 0.15) just behind the glass, so at full aim it is at screen centre.
static func _kobra() -> Node3D:
	var root := Node3D.new()
	root.name = "Sight_Kobra"
	var steel := _material(Color(0.13, 0.13, 0.14), 0.55, 0.45)
	var dark := _material(Color(0.08, 0.08, 0.09), 0.3, 0.6)
	_box(root, Vector3(0.025, 0.02, 0.0), Vector3(0.033, 0.07, 0.12), steel)    # clamp on the side rail
	_box(root, Vector3(0.026, 0.07, 0.02), Vector3(0.034, 0.122, 0.1), steel)   # arm up over the receiver
	_box(root, Vector3(-0.024, 0.105, 0.0), Vector3(0.034, 0.122, 0.11), steel)  # base plate
	_box(root, Vector3(0.016, 0.122, 0.0), Vector3(0.024, 0.178, 0.11), dark)   # housing walls and roof
	_box(root, Vector3(-0.024, 0.122, 0.0), Vector3(-0.016, 0.178, 0.11), dark)
	_box(root, Vector3(-0.024, 0.178, 0.0), Vector3(0.024, 0.19, 0.11), dark)
	_tube(root, 0.008, 0.01, Vector3(-0.029, 0.15, 0.055), steel, Vector3.RIGHT)  # brightness knob, right side
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.62, 0.5, 0.14)
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	_box(root, Vector3(-0.016, 0.122, 0.096), Vector3(0.016, 0.178, 0.098), glass)
	_dot(root, Color(1.0, 0.16, 0.08), 0.094, Vector2(0.0, 0.15), 0.016, 0.004)
	return root


## Aimpoint CompM (CompM2, 1990s-2000s): a red dot sight, no magnification. A 30 mm tube in two rings on a Picatinny
## base, its axis at (0, 0.098) - on the PDW's rail; flared ends, the elevation cap on top, the windage cap and the
## battery with the brightness dial on the right. The tube is hollow (seen through at full aim: a thin ring around the
## dot, the world all round it - no scope view); clear glass at both ends, the dot on the front one.
static func _compm() -> Node3D:
	var root := Node3D.new()
	root.name = "Sight_CompM"
	var paint := _material(Color(0.09, 0.09, 0.095), 0.25, 0.6)
	var steel := _material(Color(0.13, 0.13, 0.14), 0.55, 0.45)
	var y := 0.098  # the tube's axis
	_box(root, Vector3(-0.013, 0.068, -0.045), Vector3(0.013, 0.074, 0.045), steel)  # base on the rail
	for z in [-0.03, 0.03]:
		_box(root, Vector3(-0.008, 0.074, z - 0.008), Vector3(0.008, 0.084, z + 0.008), steel)  # ring riser
		_shell(root, 0.0168, 0.016, Vector3(0.0, y, z), steel)                                  # ring
	_shell(root, 0.015, 0.1, Vector3(0.0, y, 0.0), paint)          # main tube
	_shell(root, 0.0185, 0.014, Vector3(0.0, y, 0.053), paint)     # objective end
	_shell(root, 0.0175, 0.012, Vector3(0.0, y, -0.054), paint)    # ocular end
	_tube(root, 0.0085, 0.012, Vector3(0.0, y + 0.019, 0.0), paint, Vector3.UP)        # elevation cap
	_tube(root, 0.0085, 0.012, Vector3(-0.019, y, 0.0), paint, Vector3.RIGHT)          # windage cap (right)
	_tube(root, 0.008, 0.03, Vector3(-0.02, y + 0.004, -0.032), paint, Vector3.BACK)   # battery tube (right)
	_tube(root, 0.0105, 0.008, Vector3(-0.02, y + 0.004, -0.05), steel, Vector3.BACK)  # brightness dial
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.5, 0.6, 0.7, 0.1)
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	_tube(root, 0.0148, 0.001, Vector3(0.0, y, 0.058), glass)
	_tube(root, 0.0148, 0.001, Vector3(0.0, y, -0.058), glass)
	_dot(root, Color(1.0, 0.08, 0.05), 0.056, Vector2(0.0, y), 0.0135, 0.003)
	return root


## The red dot of a collimator (see the top of the file); its rest place is on the aim line at `z`.
static func _dot(root: Node3D, color: Color, z: float, center: Vector2, window_radius: float, angle: float) -> void:
	var dot := MeshInstance3D.new()
	dot.name = "Dot"
	var sphere := SphereMesh.new()
	sphere.radius = DOT_RADIUS
	sphere.height = DOT_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = color
	sphere.material = red
	dot.mesh = sphere
	dot.position = Vector3(center.x, center.y, z)
	root.add_child(dot)
	root.set_meta("dot_z", z)
	root.set_meta("window_center", center)
	root.set_meta("window_radius", window_radius)
	root.set_meta("dot_angle", angle)


## PSO-1 4x: a side-rail bracket on the left and the scope over it, its axis at (0.035, 0.155): objective forward,
## eyepiece and rubber cup back, the elevation turret on top and the windage one on the left.
static func _pso() -> Node3D:
	var root := Node3D.new()
	root.name = "Sight_PSO"
	var steel := _material(Color(0.13, 0.13, 0.14), 0.55, 0.45)
	var paint := _material(Color(0.1, 0.1, 0.1), 0.2, 0.55)
	var rubber := _material(Color(0.05, 0.05, 0.05), 0.0, 0.9)
	var x := 0.035  # the scope's axis: x, y
	var y := 0.155
	_box(root, Vector3(0.025, 0.02, -0.02), Vector3(0.033, 0.07, 0.14), steel)  # clamp on the side rail
	_box(root, Vector3(0.028, 0.07, 0.0), Vector3(0.042, 0.142, 0.12), steel)   # bracket up to the tube
	_tube(root, 0.013, 0.19, Vector3(x, y, 0.035), paint)    # main tube
	_tube(root, 0.017, 0.03, Vector3(x, y, 0.145), paint)    # neck to the objective
	_tube(root, 0.021, 0.08, Vector3(x, y, 0.2), paint)      # objective bell
	_tube(root, 0.018, 0.07, Vector3(x, y, -0.095), paint)   # eyepiece
	_tube(root, 0.02, 0.03, Vector3(x, y, -0.145), rubber)   # eye cup
	_tube(root, 0.011, 0.016, Vector3(x, y + 0.021, 0.035), paint, Vector3.UP)     # elevation turret
	_tube(root, 0.011, 0.016, Vector3(x + 0.021, y, 0.035), paint, Vector3.RIGHT)  # windage turret
	var lens := _material(Color(0.06, 0.09, 0.12), 0.9, 0.08)
	_tube(root, 0.0185, 0.002, Vector3(x, y, 0.241), lens)
	return root


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _box(parent: Node3D, from: Vector3, to: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = (to - from).abs()
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = (from + to) * 0.5
	parent.add_child(node)


## A hollow tube (no wall thickness, both sides drawn, open ends) of `radius` and `length` along the barrel.
static func _shell(parent: Node3D, radius: float, length: float, center: Vector3, material: StandardMaterial3D) -> void:
	var mesh := TubeTrailMesh.new()
	mesh.radius = radius
	mesh.radial_steps = 16
	mesh.sections = 2  # the least it takes
	mesh.section_length = length * 0.5
	mesh.section_rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var both_sides := material.duplicate() as StandardMaterial3D
	both_sides.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = both_sides
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.rotation.x = PI * 0.5
	node.position = center
	parent.add_child(node)


## A cylinder of `radius` and `length` around `center`, along `axis` (BACK: the barrel's direction, UP or RIGHT).
static func _tube(parent: Node3D, radius: float, length: float, center: Vector3, material: Material,
		axis := Vector3.BACK) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if axis == Vector3.BACK:
		node.rotation.x = PI * 0.5
	elif axis == Vector3.RIGHT:
		node.rotation.z = PI * 0.5
	node.position = center
	parent.add_child(node)
