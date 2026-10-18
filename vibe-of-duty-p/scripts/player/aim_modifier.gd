class_name AimModifier
extends SkeletonModifier3D
## Bends a third-person character's spine to the player's aim pitch, on top of whatever clip is playing.
## Runs after the AnimationPlayer (SkeletonModifier3D); the weapon follows the hands, so it tilts too.

## Share of the bend taken by each bone (applied parent to child, so the shares add up).
const WEIGHTS := {"Spine_01": 0.2, "Spine_02": 0.3, "Spine_03": 0.3, "Neck": 0.1, "Head": 0.1}

var pitch := 0.0  # radians, positive = looking up


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or is_zero_approx(pitch):
		return
	for bone_name in WEIGHTS:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var pose := skeleton.get_bone_global_pose(bone)
		# In skeleton space the character looks along +Z, so looking up is a rotation about +X by a negative angle.
		pose.basis = Basis(Vector3.RIGHT, -pitch * WEIGHTS[bone_name]) * pose.basis
		skeleton.set_bone_global_pose(bone, pose)
