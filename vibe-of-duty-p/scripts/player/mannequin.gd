class_name Mannequin
extends Node3D
## Blockout human: a smooth mannequin built from capsules, posed procedurally every frame (no skeleton, no clips).
## Rigid parts - pelvis, torso, neck, head, upper/lower arms, hands, thighs, shins, feet - are placed from joint
## positions that come from a few simple rules:
##   - legs: two-bone IK from the hips to feet planted on the ground (crouching lowers the pelvis, the knees bend);
##   - torso: bends about the spine pivot with the aim pitch (and leans forward when crouching);
##   - weapon: held at the hip or, aiming down sights, with the rear sight under the eye; both arms reach it by IK.
## The head position is a pure function of (pitch, ads, crouch) - head_offset() - which LagComp uses for the head
## hitbox, so the hitbox always matches the body exactly.
##
## Facing: the mannequin looks along -Z (the player's forward). Units: metres. First-person arms reuse the arm parts
## (make_arm / pose_arm), so the hands look the same in both views.

# --- proportions (1.8 m tall) ---
const PELVIS_STAND := 0.95       # pelvis height standing
const PELVIS_CROUCH := 0.45      # ... crouching (knees deep)
const CROUCH_LEAN := 0.6         # rad the torso leans forward when crouching
const SPINE_PIVOT := 0.12        # spine pivot above the pelvis
const SHOULDER_UP := 0.42        # shoulders above the spine pivot
const SHOULDER_X := 0.2
const HEAD_UP := 0.55            # head centre above the spine pivot (standing: 0.95 + 0.12 + 0.55 = 1.62)
const SPINE_SHARE := 0.6         # share of the aim pitch the torso takes (the head takes the rest)
const ADS_HEAD := Vector3(0.03, -0.04, -0.06)  # the cheek goes down onto the stock while aiming (chest frame)
const HIP_X := 0.1
const THIGH := 0.43
const SHIN := 0.41
const ANKLE_H := 0.08
const UPPER_ARM := 0.29
const FOREARM := 0.27
const WRIST_TO_PALM := 0.05
const HEAD_RADIUS := 0.115

# --- weapon holding ---
const HIP_BUTT := Vector3(-0.05, -0.04, -0.05)  # butt of the stock relative to the right shoulder, in the aim frame
const BUTT := Vector3(0.0, -0.005, -0.38)         # butt of the stock in prefab space (shouldered at the hip too)
const EYE := Vector3(0.0, 0.02, -0.08)          # eye relative to the head centre, in the aim frame
## Hand orientation on the gun, in weapon view space (x right, y up, -z forward).
const RIGHT_FINGERS := Vector3(-0.3, -0.5, -0.8)  # round the front of the pistol grip
const RIGHT_PALM := Vector3(-1.0, 0.0, 0.0)       # palm against its right side
const LEFT_FINGERS := Vector3(1.0, 0.15, -0.3)    # across under the handguard, curling up its right side
const LEFT_PALM := Vector3(0.0, 1.0, 0.0)         # palm up
const RIGHT_POLE := Vector3(0.9, -1.0, 0.3)       # where the elbows point (mannequin space)
const LEFT_POLE := Vector3(-0.8, -1.0, -0.1)

# --- colours ---
const SUIT := Color(0.22, 0.24, 0.27)
const SKIN := Color(0.72, 0.72, 0.74)   # mannequin "wood": head
const GLOVE := Color(0.78, 0.76, 0.74)  # hands: light, so they read against the dark gun
const VISOR := Color(0.03, 0.03, 0.04)
const BOOT := Color(0.12, 0.11, 0.1)
const PALETTE: Array[Color] = [
	Color(0.91, 0.45, 0.23), Color(0.23, 0.65, 0.91), Color(0.61, 0.36, 0.9),
	Color(0.48, 0.79, 0.31), Color(0.95, 0.76, 0.3), Color(0.91, 0.29, 0.37),
]

static var _materials := {}

var pitch := 0.0      # aim pitch, radians, + = up
var ads := 0.0        # 0..1
var crouch := 0.0     # 0..1
var weapon: WeaponView
var def: WeaponDef

var _parts := {}      # name -> MeshInstance3D / Node3D
var _right_arm: Dictionary
var _left_arm: Dictionary


## Player colour for a peer (torso and shoulders), so players are easy to tell apart.
static func color_for(peer_id: int) -> Color:
	return PALETTE[absi(peer_id) % PALETTE.size()]


## Head centre over the feet in the mannequin's frame (x right, y up, -z forward). Used by the pose and by LagComp.
static func head_offset(aim_pitch: float, ads_amount: float, crouch_amount: float) -> Vector3:
	var chest := chest_frame(aim_pitch, crouch_amount)
	return chest * (Vector3(0.0, HEAD_UP, 0.0) + ADS_HEAD * ads_amount)


## The torso's frame: origin at the spine pivot, rotated by the aim pitch and the crouch lean.
static func chest_frame(aim_pitch: float, crouch_amount: float) -> Transform3D:
	var pelvis_y := lerpf(PELVIS_STAND, PELVIS_CROUCH, crouch_amount)
	var angle := aim_pitch * SPINE_SHARE - CROUCH_LEAN * crouch_amount  # + tilts back (looking up)
	return Transform3D(Basis(Vector3.RIGHT, angle), Vector3(0.0, pelvis_y + SPINE_PIVOT, 0.0))


func build(accent: Color) -> void:
	_part("Pelvis", _capsule(0.14, 0.36), SUIT)
	_part("Torso", _capsule(0.2, 0.64), accent)
	_part("Neck", _capsule(0.05, 0.16), SUIT)
	_part("Head", _sphere(HEAD_RADIUS), SKIN)
	var visor := _box(Vector3(0.17, 0.045, 0.06))
	_attach(_parts["Head"], visor, VISOR, Vector3(0.0, 0.015, -0.09))
	for side in ["L", "R"]:
		_part("Hip" + side, _sphere(0.085), SUIT)
		_part("Thigh" + side, _limb(0.085, 0.065, THIGH), SUIT)
		_part("Knee" + side, _sphere(0.066), SUIT)
		_part("Shin" + side, _limb(0.062, 0.045, SHIN), SUIT)
		_part("Foot" + side, _box(Vector3(0.1, 0.08, 0.25)), BOOT)
	_right_arm = make_arm(self, "R", accent)
	_left_arm = make_arm(self, "L", accent)
	(_parts["Torso"] as Node3D).scale = Vector3(1.0, 1.0, 0.62)
	(_parts["Pelvis"] as Node3D).scale = Vector3(1.0, 1.0, 0.7)


## Poses the whole body (call every frame, after the weapon's owner has set pitch / ads / crouch).
func pose() -> void:
	var chest := chest_frame(pitch, crouch)
	var pelvis_y := chest.origin.y - SPINE_PIVOT
	_place(_parts["Pelvis"], Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.0, pelvis_y, 0.0)))
	_place(_parts["Torso"], chest * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.2, 0.0)))
	var head := head_offset(pitch, ads, crouch)
	var neck_base := chest * Vector3(0.0, SHOULDER_UP + 0.02, 0.0)
	_segment(_parts["Neck"], neck_base, head - Vector3(0.0, HEAD_RADIUS * 0.6, 0.0))
	# The head looks where the player aims (the torso took only part of the pitch).
	_place(_parts["Head"], Transform3D(Basis(Vector3.RIGHT, pitch), head))

	# Legs: feet planted under the hips (a slightly staggered stance), knees bend forward.
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		var hip := Vector3(HIP_X * s, pelvis_y - 0.05, 0.0)
		var ankle := Vector3(0.13 * s, ANKLE_H, -0.12 if side == "L" else 0.1)
		var knee := two_bone(hip, ankle, THIGH, SHIN, Vector3(0.15 * s, 0.0, -1.0))
		_place(_parts["Hip" + side], Transform3D(Basis.IDENTITY, hip))
		_segment(_parts["Thigh" + side], hip, knee)
		_place(_parts["Knee" + side], Transform3D(Basis.IDENTITY, knee))
		_segment(_parts["Shin" + side], knee, ankle)
		_place(_parts["Foot" + side], Transform3D(Basis.IDENTITY, Vector3(ankle.x, ANKLE_H * 0.5, ankle.z - 0.06)))

	# Weapon: at the hip, or with the rear sight under the eye; blended by ads.
	var shoulder_r := chest * Vector3(SHOULDER_X, SHOULDER_UP, 0.0)
	var shoulder_l := chest * Vector3(-SHOULDER_X, SHOULDER_UP, 0.0)
	if weapon == null or def == null or not weapon.visible:
		return
	var aim := Basis(Vector3.RIGHT, pitch)
	var right_view := _view_point(def.right_hand)
	var hip_xform := Transform3D(aim, shoulder_r + aim * HIP_BUTT - aim * _view_point(BUTT))
	var eye := head + aim * EYE
	var rear_view := _view_point(def.rear_sight)
	var ads_xform := Transform3D(aim, eye + aim * Vector3(0.0, 0.0, -def.eye_relief) - aim * rear_view)
	var weapon_local := hip_xform.interpolate_with(ads_xform, ads)
	weapon.global_transform = global_transform * weapon_local
	pose_arm(_right_arm, shoulder_r, weapon_local * right_view, aim * RIGHT_FINGERS, aim * RIGHT_PALM, RIGHT_POLE)
	pose_arm(_left_arm, shoulder_l, weapon_local * _view_point(def.left_hand), aim * LEFT_FINGERS, aim * LEFT_PALM, LEFT_POLE)


## Prefab space (barrel +Z) -> weapon view space (barrel -Z), as WeaponView turns the model.
static func _view_point(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, -p.z)


# --- arms (shared with the first-person arms) ---------------------------------------------------------------------------

## Builds an arm's parts under `parent`; returns the parts for pose_arm. `length_scale` lengthens the bones
## (first-person arms are always "too long").
static func make_arm(parent: Node3D, side: String, accent: Color, length_scale: float = 1.0, thickness: float = 1.0) -> Dictionary:
	var arm := {"side": side, "upper": UPPER_ARM * length_scale, "fore": FOREARM * length_scale}
	arm["shoulder"] = _new_part(parent, "Shoulder" + side, _sphere(0.075 * thickness), accent)
	arm["upper_mesh"] = _new_part(parent, "UpperArm" + side, _limb(0.058 * thickness, 0.046 * thickness, arm["upper"]), SUIT)
	arm["elbow"] = _new_part(parent, "Elbow" + side, _sphere(0.047 * thickness), SUIT)
	arm["fore_mesh"] = _new_part(parent, "Forearm" + side, _limb(0.045 * thickness, 0.033 * thickness, arm["fore"]), SUIT)
	var hand := Node3D.new()
	hand.name = "Hand" + side
	parent.add_child(hand)
	arm["hand"] = hand
	# Hand frame: origin at the wrist, +Y along the fingers, +Z out of the palm.
	var s := -1.0 if side == "R" else 1.0  # thumb side
	_attach(hand, _box(Vector3(0.08, 0.085, 0.032)), GLOVE, Vector3(0.0, 0.045, 0.0))
	var fingers := _attach(hand, _box(Vector3(0.075, 0.06, 0.026)), GLOVE, Vector3(0.0, 0.1, 0.022))
	fingers.rotation.x = 1.1  # curled towards the palm: a gripping hand
	var thumb := _attach(hand, _box(Vector3(0.026, 0.06, 0.026)), GLOVE, Vector3(0.045 * s, 0.05, 0.02))
	thumb.rotation = Vector3(0.6, 0.0, -0.5 * s)
	return arm


## Poses an arm (all in the parent's space): two-bone IK from `shoulder` so the palm reaches `palm`, then the hand
## turns so its fingers run along `fingers` with the palm facing `palm_dir`; the elbow points towards `pole`.
static func pose_arm(arm: Dictionary, shoulder: Vector3, palm: Vector3, fingers: Vector3, palm_dir: Vector3, pole: Vector3) -> void:
	var f := fingers.normalized()
	var p := (palm_dir - f * palm_dir.dot(f)).normalized()
	var wrist := palm - f * WRIST_TO_PALM
	var elbow := two_bone(shoulder, wrist, arm["upper"], arm["fore"], pole)
	var reached := elbow + (wrist - elbow).normalized() * float(arm["fore"])
	_place(arm["shoulder"], Transform3D(Basis.IDENTITY, shoulder))
	_segment(arm["upper_mesh"], shoulder, elbow)
	_place(arm["elbow"], Transform3D(Basis.IDENTITY, elbow))
	_segment(arm["fore_mesh"], elbow, reached)
	var hand: Node3D = arm["hand"]
	hand.transform = Transform3D(Basis(f.cross(p).normalized(), f, p), reached)


## Middle joint of a two-bone chain from `root` towards `target` (clamped to reach), bending towards `pole`.
static func two_bone(root: Vector3, target: Vector3, a: float, b: float, pole: Vector3) -> Vector3:
	var to_target := target - root
	var dist := clampf(to_target.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := to_target.normalized() if to_target.length() > 0.0001 else Vector3.DOWN
	var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var bend := pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.FORWARD
	return root + dir * (a * cos_a) + bend * (a * sqrt(1.0 - cos_a * cos_a))


# --- parts ------------------------------------------------------------------------------------------------------------

func _part(part_name: String, mesh: Mesh, color: Color) -> void:
	_parts[part_name] = _new_part(self, part_name, mesh, color)


static func _new_part(parent: Node3D, part_name: String, mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


static func _attach(parent: Node3D, mesh: Mesh, color: Color, offset: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = offset
	parent.add_child(instance)
	return instance


## Places a capsule part so it spans from `a` to `b` (its axis is local Y), keeping its scale.
static func _segment(part: Node3D, a: Vector3, b: Vector3) -> void:
	var y := b - a
	if y.length() < 0.0001:
		return
	y = y.normalized()
	var x := Vector3.FORWARD.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	_place(part, Transform3D(Basis(x, y, z), (a + b) * 0.5))


static func _place(part: Node3D, xform: Transform3D) -> void:
	var s := part.scale
	part.transform = xform
	part.scale = s


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 3
	return mesh


## A limb segment: a cylinder tapering from `proximal` to `distal` radius along local Y (from -Y to +Y, i.e. from
## the joint it hangs from towards the next one); the joints are spheres placed separately.
static func _limb(proximal: float, distal: float, length: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = proximal
	mesh.top_radius = distal
	mesh.height = length
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.2
	mesh.radial_segments = 14
	mesh.rings = 7
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8 if color != VISOR else 0.25
		_materials[color] = material
	return _materials[color]
