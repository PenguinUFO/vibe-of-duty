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
		"acog":
			return _acog()
		"ring":
			return _ring()
	return null


## Kobra EKP-1S-03 red dot on its AK side mount (owner, 2026-10-26: after photos, detailed, not a box). Life size,
## 135 mm long. The mount: a plate on the receiver's left with a window, three screws and the clamp lever under it, a
## rolled top edge and a deck over the dust cover; the sight's foot on the deck. The sight: in front the hood - an
## arch over straight sides, the round window (r 14.5 mm, amber glass, its bezel); behind it the low body with a
## trough on top for the line of sight between a round ridge on the left and a wall on the right (the battery cap on
## it). On the right: the side panel (four screws, the reticle lever, a button) and the toothed brightness wheel at the
## back; on the hood's left a slotted knob. The dot is on the aim line (0, 0.15) just behind the glass, so at full aim
## it is at screen centre; the ridge and the wall stay out of the window from the eye.
static func _kobra() -> Node3D:
	var root := Node3D.new()
	root.name = "Sight_Kobra"
	var steel := _material(Color(0.13, 0.13, 0.14), 0.55, 0.45)
	var steel_light := _material(Color(0.24, 0.24, 0.25), 0.6, 0.4)
	var hole := _material(Color(0.03, 0.03, 0.035), 0.2, 0.8)
	var paint := _material(Color(0.085, 0.085, 0.09), 0.2, 0.6)
	paint.resource_name = "polymer"  # WeaponSkin: the paint's fine grit, not the steel's mottle
	var c := Vector2(0.0, 0.15)  # the window's centre: the aim line
	# The mount: the plate on the receiver's left (prefab +x), its window between the posts, the deck over the cover.
	_box(root, Vector3(0.028, 0.07, -0.004), Vector3(0.035, 0.108, 0.094), steel)    # plate, top bar
	_box(root, Vector3(0.028, 0.015, -0.004), Vector3(0.035, 0.028, 0.094), steel)   # bottom bar
	_box(root, Vector3(0.028, 0.028, -0.004), Vector3(0.035, 0.07, 0.012), steel)    # rear post
	_box(root, Vector3(0.028, 0.028, 0.078), Vector3(0.035, 0.07, 0.094), steel)     # front post
	_box(root, Vector3(0.0295, 0.04, 0.03), Vector3(0.0325, 0.07, 0.06), steel)      # a rib across the window
	for z in [0.018, 0.045, 0.072]:
		_tube(root, 0.0052, 0.0016, Vector3(0.0352, 0.089, z), hole, Vector3.RIGHT)  # screw recess
		_tube(root, 0.0034, 0.0024, Vector3(0.0352, 0.089, z), steel_light, Vector3.RIGHT)
	_tube(root, 0.0068, 0.098, Vector3(0.0315, 0.112, 0.045), steel)                 # rolled top edge
	_box(root, Vector3(-0.02, 0.108, 0.0), Vector3(0.03, 0.118, 0.09), steel)        # deck over the dust cover
	_box(root, Vector3(-0.014, 0.118, 0.008), Vector3(0.014, 0.122, 0.082), steel)   # the sight's foot
	_tube(root, 0.0042, 0.008, Vector3(0.038, 0.014, 0.086), steel_light, Vector3.RIGHT)  # clamp lever: pivot,
	_box(root, Vector3(0.0355, 0.008, -0.012), Vector3(0.0395, 0.0135, 0.09), steel_light)  # bar,
	_box(root, Vector3(0.0355, 0.0065, -0.024), Vector3(0.05, 0.0135, -0.012), steel_light)  # bent-out tip
	# The hood: an arch over straight sides, the window through it; the bezel round the window in front.
	_prism(root, _arch(c, 0.02, 0.122, 40), 0.085, 0.125, paint, _arch(c, 0.0, 0.0, 40, 0.0145))
	_prism(root, _arch(c, 0.0, 0.0, 40, 0.0172), 0.125, 0.1275, paint, _arch(c, 0.0, 0.0, 40, 0.0145))
	for x in [0.0202, -0.0202]:
		for z in [0.093, 0.117]:
			_tube(root, 0.0014, 0.0012, Vector3(x, 0.127, z), steel_light, Vector3.RIGHT)
	_tube(root, 0.0085, 0.005, Vector3(0.0225, 0.134, 0.104), paint, Vector3.RIGHT)  # slotted knob, left
	_box(root, Vector3(0.0248, 0.1295, 0.1032), Vector3(0.0254, 0.1385, 0.1048), hole)
	# The body behind it, low, and the trough on top: the round ridge on the left, the wall on the right. All of them
	# over 15 mm from the aim line - wider than the window (14.5 mm), so they stay out of it from any eye.
	_prism(root, PackedVector2Array([Vector2(-0.018, 0.122), Vector2(0.018, 0.122), Vector2(0.018, 0.131),
			Vector2(0.015, 0.134), Vector2(-0.015, 0.134), Vector2(-0.018, 0.131)]), 0.0, 0.085, paint)
	_tube(root, 0.0055, 0.085, Vector3(0.0145, 0.1355, 0.0425), paint)
	_prism(root, PackedVector2Array([Vector2(-0.019, 0.13), Vector2(-0.014, 0.13), Vector2(-0.014, 0.141),
			Vector2(-0.017, 0.141), Vector2(-0.019, 0.139)]), 0.0, 0.085, paint)
	_tube(root, 0.004, 0.003, Vector3(-0.0165, 0.1425, 0.016), steel, Vector3.UP)     # battery cap
	_box(root, Vector3(-0.0195, 0.1395, 0.0225), Vector3(-0.017, 0.142, 0.029), steel)  # its catch
	# The right side: the panel with its screws, lever and button; the brightness wheel at the back.
	_box(root, Vector3(-0.0198, 0.1235, 0.03), Vector3(-0.0188, 0.1415, 0.078), paint)
	for y in [0.1255, 0.1395]:
		for z in [0.033, 0.075]:
			_tube(root, 0.0011, 0.001, Vector3(-0.0201, y, z), steel_light, Vector3.RIGHT)
	_box_turned(root, Vector3(-0.0205, 0.1325, 0.06), Vector3(0.0025, 0.0028, 0.012), steel_light,
			Vector3(deg_to_rad(-30.0), 0.0, 0.0))                                   # reticle lever
	_tube(root, 0.0022, 0.0022, Vector3(-0.0204, 0.1325, 0.042), steel_light, Vector3.RIGHT)  # button
	_tube(root, 0.0092, 0.005, Vector3(-0.0215, 0.132, 0.013), paint, Vector3.RIGHT)  # brightness wheel
	for i in 16:
		var angle := TAU * i / 16.0
		_box_turned(root, Vector3(-0.0215, 0.132 + cos(angle) * 0.0094, 0.013 + sin(angle) * 0.0094),
				Vector3(0.005, 0.0022, 0.0022), paint, Vector3(-angle, 0.0, 0.0))
	_tube(root, 0.0035, 0.0012, Vector3(-0.0242, 0.132, 0.013), steel_light, Vector3.RIGHT)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.95, 0.62, 0.12, 0.16)  # the amber coat
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	_tube(root, 0.0145, 0.001, Vector3(c.x, c.y, 0.112), glass)
	_dot(root, Color(1.0, 0.16, 0.08), 0.11, c, 0.0145, 0.004)
	return root


## Aimpoint CompM (CompM2/M4, owner 2026-10-26: after photos, detailed): a red dot sight, no magnification, life size,
## 122 mm long, on the PDW's rail, its axis at (0, 0.098). One turned body, hollow through (at full aim: a thin ring
## round the dot, the world all round it - no scope view): the ocular ring, the 30 mm tube, the objective flaring to
## 40 mm with the lens set back in it (red-amber coat). Round the tube's middle the saddle - a rounded square - with the
## knurled elevation cap on top (a cross on it) and the windage cap on the right; the battery tube along its upper
## left with a knurled cap at each end (front: the battery, back: the brightness dial). No flip covers (owner,
## 2026-10-26). Under it the QRP mount: a clamp on the rail, a spacer with its row of holes, the big knurled knob on
## the right.
static func _compm() -> Node3D:
	var root := Node3D.new()
	root.name = "Sight_CompM"
	var paint := _material(Color(0.09, 0.09, 0.095), 0.25, 0.6)
	paint.resource_name = "polymer"  # WeaponSkin: the anodised finish's fine grit, not the steel's mottle
	var steel := _material(Color(0.13, 0.13, 0.14), 0.55, 0.45)
	var hole := _material(Color(0.03, 0.03, 0.035), 0.2, 0.8)
	var y := 0.098  # the tube's axis
	var bore := 0.0145  # the hole through it: the window
	# The body, turned: (radius, z) round the outside from the back, then back along the bore.
	_lathe(root, PackedVector2Array([
		Vector2(bore, -0.06), Vector2(0.0172, -0.06), Vector2(0.0178, -0.0594), Vector2(0.0178, -0.0476),
		Vector2(0.0168, -0.046), Vector2(0.015, -0.0455), Vector2(0.015, 0.018), Vector2(0.0158, 0.022),
		Vector2(0.0188, 0.03), Vector2(0.0198, 0.033), Vector2(0.0198, 0.0605), Vector2(0.0191, 0.062),
		Vector2(0.0175, 0.062), Vector2(0.0175, 0.052), Vector2(bore, 0.05)]), Vector3(0.0, y, 0.0), paint)
	_lathe(root, PackedVector2Array([Vector2(0.0199, 0.036), Vector2(0.0202, 0.036), Vector2(0.0202, 0.0375),
			Vector2(0.0199, 0.0375)]), Vector3(0.0, y, 0.0), paint)  # the groove's edge on the bell
	# The saddle round the middle and its foot down to the mount.
	_prism(root, _rounded(Vector2(0.0, y), 0.0188, 40), -0.024, 0.016, paint, _arch(Vector2(0.0, y), 0.0, 0.0, 40, bore))
	_box(root, Vector3(-0.0135, 0.0755, -0.022), Vector3(0.0135, 0.086, 0.014), paint)
	var top := y + 0.0188
	_tube(root, 0.0095, 0.003, Vector3(0.0, top + 0.0015, -0.004), paint, Vector3.UP)          # elevation: collar,
	_knurled(root, 0.0085, 0.0065, Vector3(0.0, top + 0.00625, -0.004), paint, Vector3.UP)    # knurled cap,
	_box(root, Vector3(-0.006, top + 0.0094, -0.0048), Vector3(0.006, top + 0.0098, -0.0032), hole)  # its cross
	_box(root, Vector3(-0.0008, top + 0.0094, -0.01), Vector3(0.0008, top + 0.0098, 0.002), hole)
	_tube(root, 0.0095, 0.003, Vector3(-0.0203, y, -0.004), paint, Vector3.RIGHT)              # windage (right)
	_knurled(root, 0.0085, 0.0065, Vector3(-0.0251, y, -0.004), paint, Vector3.RIGHT)
	_box(root, Vector3(-0.0287, y - 0.0008, -0.01), Vector3(-0.0283, y + 0.0008, 0.002), hole)
	# The battery along the upper left (prefab +x), knurled at both ends; the brightness dial's pointer behind.
	var battery := Vector3(0.0165, y + 0.0165, 0.0)
	_tube(root, 0.0075, 0.036, battery + Vector3(0.0, 0.0, -0.006), paint)
	_box_turned(root, Vector3(0.0135, y + 0.0135, -0.006), Vector3(0.008, 0.006, 0.03), paint,
			Vector3(0.0, 0.0, PI * 0.25))  # its web onto the saddle, outside the bore
	_knurled(root, 0.0085, 0.009, battery + Vector3(0.0, 0.0, 0.0165), paint, Vector3.BACK)  # battery cap
	_knurled(root, 0.0088, 0.008, battery + Vector3(0.0, 0.0, -0.028), paint, Vector3.BACK)  # brightness dial
	_box(root, battery + Vector3(-0.0008, 0.004, -0.0325), battery + Vector3(0.0008, 0.0075, -0.0318), steel)
	# The QRP mount: the clamp on the rail, the spacer with its holes, the knob on the right.
	_box(root, Vector3(-0.016, 0.068, -0.03), Vector3(0.016, 0.0755, 0.022), steel)
	for x in [0.0145, -0.0145]:
		_box(root, Vector3(minf(x, x + signf(x) * 0.0035), 0.059, -0.03),
				Vector3(maxf(x, x + signf(x) * 0.0035), 0.068, 0.022), steel)  # jaws round the rail
	for i in 6:
		_tube(root, 0.0016, 0.001, Vector3(0.0162, 0.0718, -0.024 + i * 0.0078), hole, Vector3.RIGHT)
	_tube(root, 0.0035, 0.008, Vector3(-0.0215, 0.0655, -0.004), steel, Vector3.RIGHT)  # the knob's screw
	_knurled(root, 0.0082, 0.011, Vector3(-0.0305, 0.0655, -0.004), steel, Vector3.RIGHT, 22)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.95, 0.3, 0.12, 0.16)  # the objective's red-amber coat
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	_tube(root, 0.0175, 0.001, Vector3(0.0, y, 0.051), glass)
	var ocular := glass.duplicate() as StandardMaterial3D
	ocular.albedo_color = Color(0.5, 0.6, 0.7, 0.08)
	_tube(root, bore, 0.001, Vector3(0.0, y, -0.0585), ocular)
	_dot(root, Color(1.0, 0.08, 0.05), 0.049, Vector2(0.0, y), 0.0135, 0.003)
	return root


## Trijicon ACOG TA01 4x32 (owner, 2026-10-26: after photos, as detailed as the others) on the ACR's rail, life size,
## 147 mm long, its axis at (0, 0.131) - 36 mm over the rail. Magnified 4x (weapons.cfg ads_zoom), but seen as a
## collimator, not as the PSO: the model stays at full aim and the world shows through its hollow tube, the red chevron
## on the objective. From the back: the rubber eyepiece ring, the square flange with its four bolts, the adjuster block
## with the ribbed elevation cap on top and the windage cap on the right, the 36 mm body, the hood round the 32 mm
## objective - an arch over a flat bottom, cut aslant (its top reaches further forward), a red fibre along its top. Under
## it the integral base and a Picatinny clamp with its thumb nut on the right.
static func _acog() -> Node3D:
	var root := Node3D.new()
	root.name = "Sight_ACOG"
	var paint := _material(Color(0.1, 0.1, 0.105), 0.25, 0.6)
	paint.resource_name = "polymer"  # WeaponSkin: the anodised finish's fine grit
	var rubber := _material(Color(0.05, 0.05, 0.05), 0.0, 0.9)
	rubber.resource_name = "rubber"
	var steel := _material(Color(0.13, 0.13, 0.14), 0.55, 0.45)
	var hole := _material(Color(0.03, 0.03, 0.035), 0.2, 0.8)
	var y := 0.131  # the axis
	var c := Vector2(0.0, y)
	var axis := Vector3(0.0, y, 0.0)
	# The eyepiece's rubber ring and the body, turned and hollow: (radius, z) round the outside, back along the bore.
	_lathe(root, PackedVector2Array([Vector2(0.0118, -0.0755), Vector2(0.0152, -0.0755), Vector2(0.0158, -0.0742),
			Vector2(0.0158, -0.064), Vector2(0.0118, -0.064)]), axis, rubber)
	_lathe(root, PackedVector2Array([Vector2(0.0118, -0.064), Vector2(0.0148, -0.064), Vector2(0.0148, -0.05),
			Vector2(0.016, -0.047), Vector2(0.016, -0.018), Vector2(0.018, -0.014), Vector2(0.018, 0.027),
			Vector2(0.0186, 0.027), Vector2(0.0186, 0.03), Vector2(0.0165, 0.03), Vector2(0.0118, -0.04)]), axis, paint)
	# The flange behind the adjusters and its four bolts; the adjuster block.
	_prism(root, _rounded(c, 0.019, 40), -0.0515, -0.0445, paint, _arch(c, 0.0, 0.0, 40, 0.0146))
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var at: Vector2 = c + corner * 0.0138
		_tube(root, 0.0032, 0.003, Vector3(at.x, at.y, -0.053), steel)
		_box(root, Vector3(at.x - 0.0016, at.y - 0.0004, -0.0546), Vector3(at.x + 0.0016, at.y + 0.0004, -0.0544), hole)
	_prism(root, _rounded(c, 0.0175, 40), -0.0445, -0.012, paint, _arch(c, 0.0, 0.0, 40, 0.0155))
	var top := y + 0.0175
	_tube(root, 0.0085, 0.003, Vector3(0.0, top + 0.0015, -0.028), paint, Vector3.UP)        # elevation: collar,
	_knurled(root, 0.0098, 0.0075, Vector3(0.0, top + 0.00675, -0.028), paint, Vector3.UP, 30)  # ribbed cap,
	_tube(root, 0.0082, 0.001, Vector3(0.0, top + 0.011, -0.028), hole, Vector3.UP)           # its recessed top
	_tube(root, 0.0085, 0.003, Vector3(-0.019, y, -0.028), paint, Vector3.RIGHT)              # windage (right)
	_knurled(root, 0.0098, 0.0075, Vector3(-0.02425, y, -0.028), paint, Vector3.RIGHT, 30)
	_tube(root, 0.0082, 0.001, Vector3(-0.0285, y, -0.028), hole, Vector3.RIGHT)
	_tube(root, 0.0075, 0.004, Vector3(0.0195, y, -0.028), paint, Vector3.RIGHT)             # plug on the left
	# The hood round the objective, cut aslant; the red fibre on its top.
	_prism(root, _arch(c, 0.0225, 0.108, 40), 0.022, 0.06, paint, _arch(c, 0.0, 0.0, 40, 0.0186), 0.55)
	var fibre := StandardMaterial3D.new()
	fibre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fibre.albedo_color = Color(0.95, 0.12, 0.08)
	_tube(root, 0.0012, 0.05, Vector3(0.0, y + 0.0232, 0.045), fibre)
	# The integral base and the clamp on the rail (the rail's top at 0.095, 11 mm each side).
	_prism(root, PackedVector2Array([Vector2(-0.012, 0.104), Vector2(0.012, 0.104), Vector2(0.0095, 0.114),
			Vector2(-0.0095, 0.114)]), -0.042, 0.056, paint)
	_box(root, Vector3(-0.0125, 0.095, -0.03), Vector3(0.0125, 0.104, 0.05), steel)
	for x in [0.0125, -0.0125]:
		_box(root, Vector3(minf(x, x + signf(x) * 0.0028), 0.087, -0.03),
				Vector3(maxf(x, x + signf(x) * 0.0028), 0.096, 0.05), steel)  # jaws round the rail
	_tube(root, 0.0028, 0.034, Vector3(0.0, 0.0915, 0.032), steel, Vector3.RIGHT)  # the cross bolt
	_knurled(root, 0.0068, 0.006, Vector3(-0.0205, 0.0915, 0.032), steel, Vector3.RIGHT, 20)  # its thumb nut
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.9, 0.35, 0.15, 0.14)  # the objective's coat
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	_tube(root, 0.0186, 0.001, Vector3(0.0, y, 0.031), glass)
	var ocular := glass.duplicate() as StandardMaterial3D
	ocular.albedo_color = Color(0.5, 0.6, 0.7, 0.08)
	_tube(root, 0.0118, 0.001, Vector3(0.0, y, -0.0705), ocular)
	# The field stop behind the objective: the view ~7 degrees across from the eye, as the real one's, and the folded
	# front sight's base (32 mm under the axis) stays under it.
	_prism(root, _arch(c, 0.0, 0.0, 40, 0.0186), 0.0288, 0.0294, hole, _arch(c, 0.0, 0.0, 40, 0.011))
	_dot(root, Color(1.0, 0.1, 0.05), 0.0305, c, 0.011, 0.006, "chevron")
	return root


## The P90's integral ring sight (MC-10-80): no magnification, in the gun's own housing (tools/make_p90_blockout.py) -
## here only its glass and the reticle: a ring with a dot in its middle, lit red (the daylight one is black; red reads
## on any background). The window 26 x 19.5 mm, its middle on the aim line (0, 0.0871), from z -0.0272 to 0.1254.
static func _ring() -> Node3D:
	var root := Node3D.new()
	root.name = "Sight_Ring"
	var c := Vector2(0.0, 0.0871)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.85, 0.55, 0.25, 0.12)  # the objective's amber coat
	glass.roughness = 0.05
	glass.metallic_specular = 1.0
	_box(root, Vector3(-0.0128, c.y - 0.0096, 0.1225), Vector3(0.0128, c.y + 0.0096, 0.1235), glass)
	var ocular := glass.duplicate() as StandardMaterial3D
	ocular.albedo_color = Color(0.5, 0.6, 0.7, 0.08)
	_box(root, Vector3(-0.0128, c.y - 0.0096, -0.0262), Vector3(0.0128, c.y + 0.0096, -0.0256), ocular)
	_dot(root, Color(1.0, 0.12, 0.06), 0.122, c, 0.0095, 0.014, "ring")
	return root


## A knurled cap: a cylinder of `radius` and `length` along `axis` with `ridges` small ribs round it.
static func _knurled(parent: Node3D, radius: float, length: float, center: Vector3, material: Material,
		axis := Vector3.BACK, ridges := 18) -> void:
	_tube(parent, radius, length, center, material, axis)
	for i in ridges:
		var a := TAU * i / ridges
		var rib := 0.0014
		if axis == Vector3.UP:
			_box_turned(parent, center + Vector3(cos(a), 0.0, sin(a)) * radius, Vector3(rib, length, rib), material,
					Vector3(0.0, -a, 0.0))
		elif axis == Vector3.RIGHT:
			_box_turned(parent, center + Vector3(0.0, cos(a), sin(a)) * radius, Vector3(length, rib, rib), material,
					Vector3(a, 0.0, 0.0))
		else:
			_box_turned(parent, center + Vector3(cos(a), sin(a), 0.0) * radius, Vector3(rib, rib, length), material,
					Vector3(0.0, 0.0, a))


## A rounded square of `half` round `c` (a superellipse, as the CompM's saddle), `count` points on rays like _arch.
static func _rounded(c: Vector2, half: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * i / count
		var ray := Vector2(cos(angle), sin(angle))
		points.append(c + ray * half / pow(pow(absf(ray.x), 4.0) + pow(absf(ray.y), 4.0), 0.25))
	return points


## A body turned round the barrel's axis through `center`: `profile` a closed loop of (radius, z) - round the outside
## and back along the bore for a hollow one. Smooth round the axis; along the profile sharp where it turns over 35
## degrees (shoulders, ends), smooth where it bends gently.
static func _lathe(parent: Node3D, profile: PackedVector2Array, center: Vector3, material: Material,
		steps := 32) -> void:
	var n := profile.size()
	var area := 0.0
	for i in n:
		var a := profile[i]
		var b := profile[(i + 1) % n]
		area += a.y * b.x - b.y * a.x  # in (z, r): positive - the loop runs counter-clockwise
	var normals: Array[Vector2] = []  # (radial, z) of each segment, outward
	for i in n:
		var d := profile[(i + 1) % n] - profile[i]
		var normal := Vector2(-d.y, d.x).normalized()
		normals.append(normal if area > 0.0 else -normal)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a := profile[i]
		var b := profile[(i + 1) % n]
		var own := normals[i]
		var na := own
		var nb := own
		if own.dot(normals[(i - 1 + n) % n]) > cos(deg_to_rad(35.0)):
			na = (own + normals[(i - 1 + n) % n]).normalized()
		if own.dot(normals[(i + 1) % n]) > cos(deg_to_rad(35.0)):
			nb = (own + normals[(i + 1) % n]).normalized()
		for j in steps:
			var dirs := []
			for k in [j, j + 1]:
				var phi: float = TAU * float(k) / steps
				dirs.append(Vector3(cos(phi), sin(phi), 0.0))
			var p := func(point: Vector2, dir: Vector3) -> Vector3: return dir * point.x + Vector3(0.0, 0.0, point.y)
			var m := func(normal: Vector2, dir: Vector3) -> Vector3: return dir * normal.x + Vector3(0.0, 0.0, normal.y)
			_quad(st, p.call(a, dirs[0]), p.call(a, dirs[1]), p.call(b, dirs[1]), p.call(b, dirs[0]),
					[m.call(na, dirs[0]), m.call(na, dirs[1]), m.call(nb, dirs[1]), m.call(nb, dirs[0])])
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = center
	parent.add_child(node)


## The red dot of a collimator (see the top of the file); its rest place is on the aim line at `z`. `shape` "chevron":
## the ACOG's red chevron instead, its tip on the aim line, DOT_RADIUS to each side (so `angle` sizes it as the dot);
## "ring": the P90's ring, DOT_RADIUS across its outside, a dot in its middle.
static func _dot(root: Node3D, color: Color, z: float, center: Vector2, window_radius: float, angle: float,
		shape := "dot") -> void:
	var dot := MeshInstance3D.new()
	dot.name = "Dot"
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.cull_mode = BaseMaterial3D.CULL_DISABLED
	red.albedo_color = color
	if shape == "ring":
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var flat := func(radius: float, a: float) -> Vector3: return Vector3(cos(a), sin(a), 0.0) * radius
		for i in 32:
			var a0 := TAU * i / 32.0
			var a1 := TAU * (i + 1) / 32.0
			var outer := DOT_RADIUS
			var inner := DOT_RADIUS * 0.86
			var centre := DOT_RADIUS * 0.13
			for v in [flat.call(outer, a0), flat.call(outer, a1), flat.call(inner, a1), flat.call(outer, a0),
					flat.call(inner, a1), flat.call(inner, a0), Vector3.ZERO, flat.call(centre, a0), flat.call(centre, a1)]:
				st.set_normal(Vector3.FORWARD)
				st.add_vertex(v)
		dot.mesh = st.commit()
		dot.mesh.surface_set_material(0, red)
	elif shape == "chevron":
		var r := DOT_RADIUS
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0, 1.0]:  # each arm: a strip from the tip down and out
			var tip_out := Vector3(0.0, 0.0, 0.0)
			var tip_in := Vector3(0.0, -0.45 * r, 0.0)
			var end_out := Vector3(side * r, -1.1 * r, 0.0)
			var end_in := Vector3(side * r, -1.55 * r, 0.0)
			for v in [tip_out, end_out, end_in, tip_out, end_in, tip_in]:
				st.set_normal(Vector3.FORWARD)
				st.add_vertex(v)
		dot.mesh = st.commit()
		dot.mesh.surface_set_material(0, red)
	else:
		var sphere := SphereMesh.new()
		sphere.radius = DOT_RADIUS
		sphere.height = DOT_RADIUS * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
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


## A box of `size` round `center`, turned by `rotation` (radians, as Node3D.rotation).
static func _box_turned(parent: Node3D, center: Vector3, size: Vector3, material: Material, rotation: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = center
	node.rotation = rotation
	parent.add_child(node)


## A profile round the window's centre `c`, `count` points, each on the ray from `c` at angle TAU * i / count (so two
## such profiles stitch into a frame, _prism): with `radius` the circle; else an arch of `half_width` over straight
## sides down to `bottom`.
static func _arch(c: Vector2, half_width: float, bottom: float, count: int, radius := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * i / count
		var ray := Vector2(cos(angle), sin(angle))
		var reach := radius if radius > 0.0 else half_width
		if radius <= 0.0 and ray.y < 0.0:  # under the centre: the straight sides and the flat bottom
			reach = minf(half_width / maxf(absf(ray.x), 0.0001), (c.y - bottom) / -ray.y)
		points.append(c + ray * reach)
	return points


## A prism along the barrel, z0..z1, of the convex profile `outer` (x, y): flat ends, its sides smooth where the profile
## bends gently (an arch) and sharp at its corners. With `inner` (as many points, each on the ray of its outer one -
## _arch) it is a frame round a hole, the hole's walls drawn too. `slant`: the front end cut aslant - z1 + slant * the
## height over the profile's middle (the ACOG's hood: its top reaches further forward).
static func _prism(parent: Node3D, outer: PackedVector2Array, z0: float, z1: float, material: Material,
		inner := PackedVector2Array(), slant := 0.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector2.ZERO
	for p in outer:
		centre += p
	centre /= outer.size()
	var front := func(p: Vector2) -> float: return z1 + slant * (p.y - centre.y)
	_walls(st, outer, centre, z0, front, 1.0)
	var n := outer.size()
	for i in n:
		var a := outer[i]
		var b := outer[(i + 1) % n]
		for end in [[front, Vector3(0.0, -slant, 1.0).normalized()], [func(_p: Vector2) -> float: return z0, Vector3.FORWARD]]:
			var z: Callable = end[0]
			var normal: Vector3 = end[1]
			if inner.is_empty():
				_tri(st, Vector3(centre.x, centre.y, z.call(centre)), Vector3(a.x, a.y, z.call(a)), Vector3(b.x, b.y, z.call(b)),
						[normal, normal, normal])
			else:
				var ia := inner[i]
				var ib := inner[(i + 1) % n]
				_quad(st, Vector3(a.x, a.y, z.call(a)), Vector3(b.x, b.y, z.call(b)), Vector3(ib.x, ib.y, z.call(ib)),
						Vector3(ia.x, ia.y, z.call(ia)), [normal, normal, normal, normal])
	if not inner.is_empty():
		var hole_centre := Vector2.ZERO
		for p in inner:
			hole_centre += p
		_walls(st, inner, hole_centre / inner.size(), z0, front, -1.0)
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	parent.add_child(node)


## The side walls of a prism's profile: normals away from `centre` (side 1) or towards it (-1, a hole's walls),
## smoothed across a vertex where the two edges turn less than 35 degrees; the front end at `front`.call(point).
static func _walls(st: SurfaceTool, points: PackedVector2Array, centre: Vector2, z0: float, front: Callable,
		side: float) -> void:
	var n := points.size()
	var edge_normals: Array[Vector2] = []
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		var normal := Vector2(b.y - a.y, a.x - b.x).normalized()
		if normal.dot((a + b) * 0.5 - centre) < 0.0:
			normal = -normal
		edge_normals.append(normal * side)
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		var own := edge_normals[i]
		var na := own
		var nb := own
		if own.dot(edge_normals[(i - 1 + n) % n]) > cos(deg_to_rad(35.0)):
			na = (own + edge_normals[(i - 1 + n) % n]).normalized()
		if own.dot(edge_normals[(i + 1) % n]) > cos(deg_to_rad(35.0)):
			nb = (own + edge_normals[(i + 1) % n]).normalized()
		var na3 := Vector3(na.x, na.y, 0.0)
		var nb3 := Vector3(nb.x, nb.y, 0.0)
		_quad(st, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, front.call(b)),
				Vector3(a.x, a.y, front.call(a)), [na3, nb3, nb3, na3])


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normals: Array) -> void:
	_tri(st, a, b, c, [normals[0], normals[1], normals[2]])
	_tri(st, a, c, d, [normals[0], normals[2], normals[3]])


## One triangle, wound so its front faces the way its normals point (Godot's front face: clockwise as seen).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normals: Array) -> void:
	var facing: Vector3 = normals[0] + normals[1] + normals[2]
	var corners := [[a, normals[0]], [b, normals[1]], [c, normals[2]]]
	if (b - a).cross(c - a).dot(facing) > 0.0:
		corners = [[a, normals[0]], [c, normals[2]], [b, normals[1]]]
	for corner in corners:
		st.set_normal(corner[1])
		st.add_vertex(corner[0])


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
	mesh.radial_segments = 24
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
