extends SceneTree
## Retargets Mixamo clips (res://assets/animations/**/*.fbx, mixamorig_* skeleton) onto the Synty character skeleton
## and saves them as one AnimationLibrary: res://assets/animations/synty_mixamo.res (clip name = file name, lower case).
## Run: Godot_v4.7.2.exe --headless --path vibe-of-duty-p --script res://tools/retarget_mixamo.gd
##
## Method: both skeletons stand in a T-pose at rest, so every mapped bone copies the source bone's rotation change
## from its rest pose, measured in model space: target_global = source_global * source_rest_global^-1 * target_rest_global.
## The hips also take the source's translation, scaled by the hip-height ratio.

const SOURCE_DIR := "res://assets/animations"
const TARGET_SCENE := "res://assets/Prefabs/Characters/Characters/Character_MilitaryMale_01.tscn"
const OUTPUT := "res://assets/animations/synty_mixamo.res"
const FPS := 30.0

const MAP := {  # Synty bone -> Mixamo bone (without the "mixamorig_" prefix)
	"Hips": "Hips", "Spine_01": "Spine", "Spine_02": "Spine1", "Spine_03": "Spine2", "Neck": "Neck", "Head": "Head",
	"Clavicle_L": "LeftShoulder", "Shoulder_L": "LeftArm", "Elbow_L": "LeftForeArm", "Hand_L": "LeftHand",
	"Clavicle_R": "RightShoulder", "Shoulder_R": "RightArm", "Elbow_R": "RightForeArm", "Hand_R": "RightHand",
	"UpperLeg_L": "LeftUpLeg", "LowerLeg_L": "LeftLeg", "Ankle_L": "LeftFoot", "Ball_L": "LeftToeBase",
	"UpperLeg_R": "RightUpLeg", "LowerLeg_R": "RightLeg", "Ankle_R": "RightFoot", "Ball_R": "RightToeBase",
	"Thumb_01_L": "LeftHandThumb1", "Thumb_02_L": "LeftHandThumb2", "Thumb_03_L": "LeftHandThumb3",
	"IndexFinger_01_L": "LeftHandIndex1", "IndexFinger_02_L": "LeftHandIndex2", "IndexFinger_03_L": "LeftHandIndex3",
	"Finger_01_L": "LeftHandMiddle1", "Finger_02_L": "LeftHandMiddle2", "Finger_03_L": "LeftHandMiddle3",
	"Thumb_01_R": "RightHandThumb1", "Thumb_02_R": "RightHandThumb2", "Thumb_03_R": "RightHandThumb3",
	"IndexFinger_01_R": "RightHandIndex1", "IndexFinger_02_R": "RightHandIndex2", "IndexFinger_03_R": "RightHandIndex3",
	"Finger_01_R": "RightHandMiddle1", "Finger_02_R": "RightHandMiddle2", "Finger_03_R": "RightHandMiddle3",
}


func _initialize() -> void:
	var target: Skeleton3D = (load(TARGET_SCENE) as PackedScene).instantiate().find_children("*", "Skeleton3D", true, false)[0]
	var library := AnimationLibrary.new()
	for path in _find_fbx(SOURCE_DIR):
		var scene: Node = (load(path) as PackedScene).instantiate()
		var source: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var clip: Animation = player.get_animation(player.get_animation_list()[0])
		var name := path.get_file().get_basename().to_lower()
		library.add_animation(name, _retarget(clip, source, target))
		print("retargeted ", path, " -> ", name, " (", clip.length, " s)")
		scene.free()
	ResourceSaver.save(library, OUTPUT)
	print("saved ", OUTPUT, ": ", library.get_animation_list())
	quit()


func _find_fbx(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.get_extension().to_lower() == "fbx":
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_find_fbx(dir.path_join(sub)))
	return out


func _retarget(clip: Animation, source: Skeleton3D, target: Skeleton3D) -> Animation:
	var src_rest := _globals(source, func(b: int) -> Transform3D: return source.get_bone_rest(b))
	var tgt_rest := _globals(target, func(b: int) -> Transform3D: return target.get_bone_rest(b))
	var src_hips := source.find_bone("mixamorig_Hips")
	var tgt_hips := target.find_bone("Hips")
	var height_ratio: float = (tgt_rest[tgt_hips] as Transform3D).origin.y / (src_rest[src_hips] as Transform3D).origin.y
	#[tgt_hips].origin.y / src_rest[src_hips].origin.y

	# Source tracks by bone.
	var rot_tracks := {}
	var pos_tracks := {}
	for i in clip.get_track_count():
		var bone := source.find_bone(String(clip.track_get_path(i).get_subname(0)))
		if bone < 0:
			continue
		if clip.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			rot_tracks[bone] = i
		elif clip.track_get_type(i) == Animation.TYPE_POSITION_3D:
			pos_tracks[bone] = i

	var out := Animation.new()
	out.length = clip.length
	out.loop_mode = Animation.LOOP_LINEAR
	var skeleton_path := "Skeleton3D"  # relative to the Synty prefab root (AnimationPlayer's root node)
	var out_rot := {}
	for synty_name in MAP:
		var bone := target.find_bone(synty_name)
		var t := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(t, NodePath("%s:%s" % [skeleton_path, synty_name]))
		out_rot[bone] = t
	var hips_pos_track := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_pos_track, NodePath("%s:Hips" % skeleton_path))

	var frames := int(ceil(clip.length * FPS))
	for f in frames + 1:
		var time := minf(f / FPS, clip.length)
		var src_pose := _globals(source, func(b: int) -> Transform3D:
			var rest := source.get_bone_rest(b)
			var rot := rest.basis.get_rotation_quaternion()
			var pos := rest.origin
			if rot_tracks.has(b):
				rot = clip.rotation_track_interpolate(rot_tracks[b], time)
			if pos_tracks.has(b):
				pos = clip.position_track_interpolate(pos_tracks[b], time)
			return Transform3D(Basis(rot), pos))
		# Target global rotations, parent first.
		var tgt_global := {}
		for b in _order(target):
			var parent := target.get_bone_parent(b)
			var parent_global: Basis = tgt_global[parent] if parent >= 0 else Basis.IDENTITY
			var synty_name := target.get_bone_name(b)
			var global_basis: Basis
			if MAP.has(synty_name):
				var s := source.find_bone("mixamorig_" + MAP[synty_name])
				var delta: Basis = src_pose[s].basis.orthonormalized() * src_rest[s].basis.orthonormalized().inverse()
				global_basis = delta * tgt_rest[b].basis.orthonormalized()
				var local := (parent_global.inverse() * global_basis).get_rotation_quaternion()
				out.rotation_track_insert_key(out_rot[b], time, local)
			else:
				global_basis = parent_global * target.get_bone_rest(b).basis.orthonormalized()
			tgt_global[b] = global_basis
		# Hips position: the source hips offset from its rest, scaled, in the target hips' parent space.
		var offset: Vector3 = (src_pose[src_hips].origin - src_rest[src_hips].origin) * height_ratio
		var hips_parent := target.get_bone_parent(tgt_hips)
		var parent_rest: Transform3D = tgt_rest[hips_parent] if hips_parent >= 0 else Transform3D.IDENTITY
		out.position_track_insert_key(hips_pos_track, time,
				target.get_bone_rest(tgt_hips).origin + parent_rest.basis.inverse() * offset)
	return out


## Model-space transforms of all bones, given each bone's local transform.
func _globals(skeleton: Skeleton3D, local: Callable) -> Dictionary:
	var out := {}
	for b in _order(skeleton):
		var parent := skeleton.get_bone_parent(b)
		out[b] = (out[parent] if parent >= 0 else Transform3D.IDENTITY) * (local.call(b) as Transform3D)
	return out


## Bone indices with every parent before its children (Synty's bone order is not like that).
func _order(skeleton: Skeleton3D) -> Array[int]:
	var out: Array[int] = []
	var stack: Array[int] = []
	for b in skeleton.get_bone_count():
		if skeleton.get_bone_parent(b) < 0:
			stack.append(b)
	while not stack.is_empty():
		var b: int = stack.pop_back()
		out.append(b)
		stack.append_array(skeleton.get_bone_children(b))
	return out
