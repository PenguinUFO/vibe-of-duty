class_name HandIK
extends SkeletonModifier3D
## Puts the hands on the weapon. Runs last among the skeleton's modifiers (child order under the Skeleton3D):
## first `place_weapon` positions the gun and fills `targets`, then a two-bone IK bends each listed arm so its palm
## holds the target point, and the hand is turned along the gun.
## Third person: only the left hand (the gun hangs off the animated right hand). First person: both hands.

const ARMS := {  # shoulder, elbow, hand, finger base, finger tip
	"L": ["Shoulder_L", "Elbow_L", "Hand_L", "Finger_01_L", "Finger_03_L"],
	"R": ["Shoulder_R", "Elbow_R", "Hand_R", "Finger_01_R", "Finger_03_R"],
}
const FOREARM_TWIST := 0.6  # share of the hand's roll about the forearm that the forearm takes (no twist bones: the
                            # whole roll at the wrist would wring the skin like a candy wrapper)
const WRIST_TO_PALM := 0.07  # m (unscaled skeleton) from the wrist bone to the middle of the palm, along the fingers

var place_weapon: Callable   # () -> void; positions the weapon and fills `targets`
## side ("L"/"R") -> {"point": palm position, "fingers": direction the fingers point, "palm": direction the palm
## faces (only its part across the fingers counts)}, all in world space. Sides without an entry keep their animated pose.
var targets := {}
var straighten: Array[String] = []  # bones reset to their rest rotation first (first person: keeps the torso square)
var hidden: Array[String] = []      # bones shrunk to nothing (first person: the head, which would block the camera)
var max_stretch := 1.0              # an arm may be lengthened up to this factor to reach its target


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone_name in straighten:
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0:
			skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	for bone_name in hidden:
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0:
			skeleton.set_bone_pose_scale(bone, Vector3.ONE * 0.001)
	if not place_weapon.is_valid():
		return
	place_weapon.call()
	var to_skeleton := skeleton.global_transform.affine_inverse()
	for side in targets:
		var target: Dictionary = targets[side]
		var fingers: Vector3 = (to_skeleton.basis * (target["fingers"] as Vector3)).normalized()
		var wrist_target: Vector3 = to_skeleton * (target["point"] as Vector3) - fingers * WRIST_TO_PALM
		_solve_arm(skeleton, ARMS[side], wrist_target)
		_orient_hand(skeleton, ARMS[side], fingers, to_skeleton.basis * (target["palm"] as Vector3))


## Two-bone IK in skeleton space; the elbow keeps bending the way the animation bends it.
func _solve_arm(skeleton: Skeleton3D, arm: Array, wrist_target: Vector3) -> void:
	var root_bone := skeleton.find_bone(arm[0])
	var mid_bone := skeleton.find_bone(arm[1])
	var end_bone := skeleton.find_bone(arm[2])
	if root_bone < 0 or mid_bone < 0 or end_bone < 0:
		return
	var root_pose := skeleton.get_bone_global_pose(root_bone)
	var shoulder := root_pose.origin
	var elbow := skeleton.get_bone_global_pose(mid_bone).origin
	var wrist := skeleton.get_bone_global_pose(end_bone).origin
	var upper := shoulder.distance_to(elbow)
	var lower := elbow.distance_to(wrist)
	var to_target := wrist_target - shoulder
	if upper < 0.01 or lower < 0.01 or to_target.length() < 0.01:
		return
	var stretch := clampf(to_target.length() / (upper + lower - 0.005), 1.0, max_stretch)
	if stretch > 1.0:
		# Out of reach: lengthen both segments (the skin stretches a little).
		skeleton.set_bone_pose_position(mid_bone, skeleton.get_bone_pose_position(mid_bone) * stretch)
		skeleton.set_bone_pose_position(end_bone, skeleton.get_bone_pose_position(end_bone) * stretch)
		elbow = skeleton.get_bone_global_pose(mid_bone).origin
		wrist = skeleton.get_bone_global_pose(end_bone).origin
		upper *= stretch
		lower *= stretch
	var reach := clampf(to_target.length(), absf(upper - lower) + 0.01, upper + lower - 0.005)
	var along := to_target.normalized()
	var cos_a := clampf((upper * upper + reach * reach - lower * lower) / (2.0 * upper * reach), -1.0, 1.0)
	var bend := (elbow - shoulder) - along * (elbow - shoulder).dot(along)  # where the elbow sticks out now
	bend = bend.normalized() if bend.length() > 0.001 else Vector3.DOWN
	var new_elbow := shoulder + along * (upper * cos_a) + bend * (upper * sqrt(1.0 - cos_a * cos_a))

	# Upper arm onto the new elbow, then the forearm onto the target.
	root_pose.basis = Basis(Quaternion((elbow - shoulder).normalized(), (new_elbow - shoulder).normalized())) * root_pose.basis
	skeleton.set_bone_global_pose(root_bone, root_pose)
	var mid_pose := skeleton.get_bone_global_pose(mid_bone)
	var current := (skeleton.get_bone_global_pose(end_bone).origin - mid_pose.origin).normalized()
	var wanted := (wrist_target - mid_pose.origin).normalized()
	mid_pose.basis = Basis(Quaternion(current, wanted)) * mid_pose.basis
	skeleton.set_bone_global_pose(mid_bone, mid_pose)


## Fingers along `fingers`, then rolled about them so the palm faces `palm_dir` (skeleton space). The palm side is
## where the (animated, slightly curled) fingers bend to.
func _orient_hand(skeleton: Skeleton3D, arm: Array, fingers: Vector3, palm_dir: Vector3) -> void:
	var hand := skeleton.find_bone(arm[2])
	var knuckle := skeleton.find_bone(arm[3])
	var tip := skeleton.find_bone(arm[4])
	if hand < 0 or knuckle < 0:
		return
	var pose := skeleton.get_bone_global_pose(hand)
	var before := pose.basis
	var now_fingers := (skeleton.get_bone_global_pose(knuckle).origin - pose.origin).normalized()
	pose.basis = Basis(Quaternion(now_fingers, fingers)) * pose.basis
	skeleton.set_bone_global_pose(hand, pose)
	if tip < 0:
		return
	pose = skeleton.get_bone_global_pose(hand)
	var now_palm := skeleton.get_bone_global_pose(tip).origin - skeleton.get_bone_global_pose(knuckle).origin
	now_palm = now_palm - fingers * now_palm.dot(fingers)
	var want := palm_dir - fingers * palm_dir.dot(fingers)
	if want.length() < 0.001 or now_palm.length() < 0.001:
		return
	pose.basis = Basis(Quaternion(now_palm.normalized(), want.normalized())) * pose.basis
	skeleton.set_bone_global_pose(hand, pose)
	_share_twist(skeleton, skeleton.find_bone(arm[1]), hand, before)


## Moves part of the hand's roll about the forearm axis (relative to `before`, its pose as the IK left it) into the
## forearm bone, keeping the hand where it is.
func _share_twist(skeleton: Skeleton3D, elbow: int, hand: int, before: Basis) -> void:
	if elbow < 0:
		return
	var hand_pose := skeleton.get_bone_global_pose(hand)
	var elbow_pose := skeleton.get_bone_global_pose(elbow)
	var axis := hand_pose.origin - elbow_pose.origin
	if axis.length() < 0.001:
		return
	axis = axis.normalized()
	var delta := (hand_pose.basis.orthonormalized() * before.orthonormalized().inverse()).get_rotation_quaternion()
	var projected := Vector3(delta.x, delta.y, delta.z).dot(axis)
	var twist := Quaternion(axis.x * projected, axis.y * projected, axis.z * projected, delta.w)
	if twist.length() < 0.0001:
		return
	twist = twist.normalized()
	var share := Quaternion.IDENTITY.slerp(twist, FOREARM_TWIST)
	elbow_pose.basis = Basis(share) * elbow_pose.basis
	skeleton.set_bone_global_pose(elbow, elbow_pose)
	skeleton.set_bone_global_pose(hand, hand_pose)  # back to the wanted hand pose
