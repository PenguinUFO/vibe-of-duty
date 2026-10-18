class_name HandIK
extends SkeletonModifier3D
## Puts the weapon in the hands and the left hand on the handguard. Runs after AimModifier (child order under the
## Skeleton3D): first `place_weapon` (PlayerVisual) positions the gun from the animated right hand, then a two-bone
## IK moves the left arm so its palm holds `target` (world space, refreshed by place_weapon every update).

const ARM := ["Shoulder_L", "Elbow_L", "Hand_L"]
const WRIST_TO_PALM := 0.07  # m from the wrist bone to the middle of the palm, along the fingers

var place_weapon: Callable   # () -> void; sets `target` and `forward`
var target := Vector3.INF    # world point the left palm should hold
var forward := Vector3.FORWARD  # world direction the left hand's fingers should point (the barrel)
var palm_up := Vector3.UP       # world direction the back of the left hand should face (over the handguard)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not place_weapon.is_valid():
		return
	place_weapon.call()
	if target == Vector3.INF:
		return
	var to_skeleton := skeleton.global_transform.affine_inverse()
	var wrist_target := to_skeleton * (target - forward * WRIST_TO_PALM)
	_solve_arm(skeleton, wrist_target)
	_orient_hand(skeleton, to_skeleton.basis * forward, to_skeleton.basis * palm_up)


## Two-bone IK in skeleton space; the elbow keeps bending the way the animation bends it.
func _solve_arm(skeleton: Skeleton3D, wrist_target: Vector3) -> void:
	var root_bone := skeleton.find_bone(ARM[0])
	var mid_bone := skeleton.find_bone(ARM[1])
	var end_bone := skeleton.find_bone(ARM[2])
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


## Fingers along `fingers`, then rolled so the back of the hand faces `back` (both skeleton space).
func _orient_hand(skeleton: Skeleton3D, fingers: Vector3, back: Vector3) -> void:
	var hand := skeleton.find_bone(ARM[2])
	var knuckle := skeleton.find_bone("Finger_01_L")
	var thumb := skeleton.find_bone("Thumb_01_L")
	if hand < 0 or knuckle < 0:
		return
	var pose := skeleton.get_bone_global_pose(hand)
	var now_fingers := (skeleton.get_bone_global_pose(knuckle).origin - pose.origin).normalized()
	pose.basis = Basis(Quaternion(now_fingers, fingers.normalized())) * pose.basis
	skeleton.set_bone_global_pose(hand, pose)
	if thumb < 0:
		return
	# Roll about the finger axis: the thumb goes to the side away from `back` x fingers... approximated by keeping
	# the thumb below the fingers line (palm under the handguard).
	pose = skeleton.get_bone_global_pose(hand)
	var axis := fingers.normalized()
	var thumb_dir := skeleton.get_bone_global_pose(thumb).origin - pose.origin
	thumb_dir = (thumb_dir - axis * thumb_dir.dot(axis)).normalized()
	var want := -back - axis * (-back).dot(axis)
	if want.length() < 0.001 or thumb_dir.length() < 0.001:
		return
	pose.basis = Basis(Quaternion(thumb_dir, want.normalized())) * pose.basis
	skeleton.set_bone_global_pose(hand, pose)
