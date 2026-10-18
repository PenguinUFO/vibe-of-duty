class_name AimModifier
extends SkeletonModifier3D
## Bends a third-person character's spine to the player's aim, on top of whatever clip is playing.
## Runs after the AnimationTree (SkeletonModifier3D); the weapon follows the right hand, so it turns too.
## Hip fire: the spine just tilts by the aim pitch. Aiming down sights (weight `ads`): the spine is also turned and
## tilted so that the barrel points exactly along the aim.

## Share of the bend taken by each bone (applied parent to child, so the shares add up).
const WEIGHTS := {"Spine_01": 0.2, "Spine_02": 0.3, "Spine_03": 0.3, "Neck": 0.1, "Head": 0.1}
const TURN_WEIGHTS := {"Spine_01": 0.3, "Spine_02": 0.35, "Spine_03": 0.35}
const MAX_TURN := deg_to_rad(70.0)

var pitch := 0.0                # radians, positive = looking up
var ads := 0.0                  # 0..1
var hips_yaw := 0.0             # radians: turns the whole body about the vertical first (squares up a clip that stands turned)
var forward := Vector3(0, 0, 1) # where the player looks, in skeleton space (horizontal)
var barrel: Callable            # () -> Vector3: barrel direction in skeleton space, or Vector3.ZERO if unknown

var _bones := {}                # bone name -> index, filled on first use


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if not is_zero_approx(hips_yaw):
		_rotate(skeleton, {"Hips": 1.0}, Vector3.UP, hips_yaw)
	var tilt := pitch
	if ads > 0.001 and barrel.is_valid():
		var dir: Vector3 = barrel.call()
		if dir != Vector3.ZERO:
			# Turn about the vertical so the barrel is over the look direction.
			var turn := Vector2(forward.x, forward.z).angle_to(Vector2(dir.x, dir.z))
			_rotate(skeleton, TURN_WEIGHTS, Vector3.UP, clampf(turn, -MAX_TURN, MAX_TURN) * ads)
			dir = barrel.call()
			var barrel_pitch := atan2(dir.y, Vector2(dir.x, dir.z).length())
			tilt = lerpf(pitch, pitch - barrel_pitch, ads)
	if not is_zero_approx(tilt):
		# In skeleton space the character looks along +Z, so looking up is a rotation about +X by a negative angle.
		_rotate(skeleton, WEIGHTS, Vector3.RIGHT, -tilt)


func _rotate(skeleton: Skeleton3D, weights: Dictionary, axis: Vector3, angle: float) -> void:
	for bone_name in weights:
		if not _bones.has(bone_name):
			_bones[bone_name] = skeleton.find_bone(bone_name)
		var bone: int = _bones[bone_name]
		if bone < 0:
			continue
		var pose := skeleton.get_bone_global_pose(bone)
		pose.basis = Basis(axis, angle * weights[bone_name]) * pose.basis
		skeleton.set_bone_global_pose(bone, pose)
