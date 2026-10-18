class_name PlayerVisual
extends Node3D
## Third-person body of a non-local player: a Synty character prefab playing Mixamo clips retargeted onto its
## skeleton (res://assets/animations/synty_mixamo.res, made by tools/retarget_mixamo.gd), the held weapon and a name tag.
## Swap CHARACTER_SCENES to change the models; gameplay does not depend on anything in here.
##
## Animation: an AnimationTree blends idle and the four run directions by the player's velocity (in-place clips,
## played faster or slower to match the speed). Aiming down sights is a layer: the legs keep the hip-fire
## locomotion, the upper body (spine, arms, head) blends to the ADS run clips. AimModifier bends the spine to the aim pitch, HandIK puts the
## weapon in the right hand and the left hand on the handguard.

const CHARACTER_SCENES: Array[String] = [
	"res://assets/Prefabs/Characters/Characters/Character_MilitaryMale_01.tscn",
	"res://assets/Prefabs/Characters/Characters/Character_MercenaryMale_01.tscn",
	"res://assets/Prefabs/Characters/Characters/Character_MilitaryFemale_01.tscn",
	"res://assets/Prefabs/Characters/Characters/Character_MercenaryFemale_01.tscn",
]
const MODEL_YAW_OFFSET := PI  # Synty models face +Z, the player's forward is -Z
const NAME_TAG_HEIGHT := 2.15
const ANIM_LIBRARY := "res://assets/animations/synty_mixamo.res"
const IDLE_CLIP := &"mixamo/rifle_idle_hip"
const RUN_CLIPS := {  # blend position direction -> clip
	Vector2(0, 1): &"mixamo/rifle_run_forward_hip", Vector2(0, -1): &"mixamo/rifle_run_backward_hip",
	Vector2(-1, 0): &"mixamo/rifle_run_left_hip", Vector2(1, 0): &"mixamo/rifle_run_right_hip",
}
const ADS_CLIPS := {
	Vector2(0, 1): &"mixamo/rifle_run_forward_ads", Vector2(0, -1): &"mixamo/rifle_run_backwards_ads",
	Vector2(-1, 0): &"mixamo/rifle_run_left_ads", Vector2(1, 0): &"mixamo/rifle_run_right_ads",
}
const ADS_IDLE_CLIP := &"mixamo/rifle_idle_ads"
const ADS_BLEND_TIME := 0.15  # s to raise / lower the weapon
## Bones (and all their children) that take the ADS layer.
const UPPER_BODY_ROOTS: Array[String] = ["Spine_01"]
const RUN_CLIP_SPEED := 5.25  # m/s the run clips look right at (Player.WALK_SPEED); faster or slower plays them scaled

## How the weapon sits in the hands. Exported so they can be tuned live: run the game, open Remote in the editor's
## Scene dock, select Players/<id>/Visual and edit them in the Inspector; then copy the values here.
## grip and weapon_rotation are measured in the idle clip's pose (see _measure_socket); in every other clip the weapon
## keeps the same hold relative to the right hand.
@export var grip := Vector3(0.0, -0.08, 0.0):  # point of the weapon (view space: x right, y up, -z forward) that sits in the right palm
	set(value):
		grip = value
		_measure_socket()
@export var model_yaw := 10.0  # extra turn of the body in degrees (+ = to the left) while standing still: the idle clip stands turned
@export var aim_pitch_scale := 1.0  # how much of the look pitch the spine follows (1 = all of it)
@export var ads_weapon_rotation := Vector3.ZERO  # degrees, like weapon_rotation, but while aiming (barrel follows the palms line)
@export var foregrip := Vector3(0.0, -0.04, -0.22)  # point of the weapon (view space) that the left palm holds; the left arm is bent to it (IK)
@export var weapon_rotation := Vector3(0.0, -20.0, 0.0):  # extra turn of the weapon in degrees: x = muzzle up/down, y = left/right, z = roll
	set(value):
		weapon_rotation = value
		_measure_socket()

var _model: Node3D
var _weapon := WeaponView.new()
var _tag: Label3D
var _dead := false
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _tree: AnimationTree
var _ads_target := false
var _ads := 0.0                 # 0..1 weight of the ADS upper-body layer
var _blend := Vector2.ZERO      # smoothed blend position: x = right speed, y = forward speed (m/s)
var _socket := Transform3D.IDENTITY  # weapon transform relative to the right hand bone
var _crouch_target := false
var _tag_check := 0.0           # seconds to the next occlusion test of the name tag
var _aim := AimModifier.new()
var _ik := HandIK.new()
var _hand_r := -1
var _hand_l := -1
var _finger_r := -1
var _finger_l := -1


static func preload_scenes() -> void:
	for path in CHARACTER_SCENES:
		load(path)
	if ResourceLoader.exists(ANIM_LIBRARY):
		load(ANIM_LIBRARY)


## The Synty character of a player, ready to animate (also used for the first-person arms).
static func make_character(peer_id: int) -> Node3D:
	var scene: PackedScene = load(CHARACTER_SCENES[peer_id % CHARACTER_SCENES.size()])
	var model: Node3D = scene.instantiate()
	# The prefab root is a physics body with its own collider; the player already has one.
	if model is CollisionObject3D:
		model.collision_layer = 0
		model.collision_mask = 0
	for shape in model.find_children("*", "CollisionShape3D", true, false):
		shape.queue_free()
	# The prefab carries every character variant and attachment as hidden meshes; drop what is never shown.
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if not (mesh as MeshInstance3D).visible:
			mesh.get_parent().remove_child(mesh)
			mesh.queue_free()
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	for mesh in skeleton.find_children("*", "MeshInstance3D", false, false):
		(mesh as MeshInstance3D).skeleton = NodePath("..")  # the prefab saved an empty path: skinning was off
	return model


func setup(peer_id: int, display_name: String) -> void:
	_model = make_character(peer_id)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_model.rotation.y = MODEL_YAW_OFFSET
	add_child(_model)

	var tag := Label3D.new()
	_tag = tag
	tag.text = display_name
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0007
	tag.outline_size = 8
	tag.position.y = NAME_TAG_HEIGHT
	add_child(tag)

	_weapon.position = Vector3(0.2, 1.25, -0.2)
	add_child(_weapon)
	_setup_animation()


func _setup_animation() -> void:
	if not ResourceLoader.exists(ANIM_LIBRARY):
		return
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		_player = AnimationPlayer.new()
		_model.add_child(_player)
	else:
		_player = players[0]
	_player.root_node = _player.get_path_to(_model)
	_player.add_animation_library(&"mixamo", load(ANIM_LIBRARY))
	_tree = AnimationTree.new()
	_model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.tree_root = _build_tree()
	_tree.active = true
	_hand_r = _skeleton.find_bone("Hand_R")
	_hand_l = _skeleton.find_bone("Hand_L")
	_finger_r = _skeleton.find_bone("Finger_01_R")
	_finger_l = _skeleton.find_bone("Finger_01_L")
	_weapon.top_level = true
	_aim.barrel = _barrel_in_skeleton
	_skeleton.add_child(_aim)
	_ik.place_weapon = _place_weapon
	_skeleton.add_child(_ik)  # after _aim: sees the bent spine
	_measure_socket()


## Measures how the weapon sits in the right hand, in the idle clip's first frame (straight from the clip data, so it
## does not matter what the body is doing right now): grip in the right palm, barrel along the line to the left palm,
## turned by weapon_rotation.
func _measure_socket() -> void:
	if _skeleton == null or _player == null or _hand_r < 0 or _hand_l < 0:
		return
	var pose := _clip_pose(_player.get_animation(IDLE_CLIP), 0.0)
	var right: Vector3 = (pose[_hand_r] as Transform3D).origin.lerp((pose[_finger_r] as Transform3D).origin, 0.6)
	var left: Vector3 = (pose[_hand_l] as Transform3D).origin.lerp((pose[_finger_l] as Transform3D).origin, 0.6)
	var basis := Basis.looking_at((left - right).normalized(), Vector3.UP) * Basis.from_euler(weapon_rotation * (PI / 180.0))
	_socket = (pose[_hand_r] as Transform3D).affine_inverse() * Transform3D(basis, right - basis * grip)


## Skeleton-space transforms of all bones in `clip` at `time` (bones without tracks keep their rest pose).
func _clip_pose(clip: Animation, time: float) -> Dictionary:
	var local := {}
	for bone in _skeleton.get_bone_count():
		local[bone] = _skeleton.get_bone_rest(bone)
	var prefix := String(_model.get_path_to(_skeleton))
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		if String(path.get_concatenated_names()) != prefix:
			continue
		var bone := _skeleton.find_bone(String(path.get_subname(0)))
		if bone < 0:
			continue
		var xform: Transform3D = local[bone]
		match clip.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				xform.basis = Basis(clip.rotation_track_interpolate(track, time))
			Animation.TYPE_POSITION_3D:
				xform.origin = clip.position_track_interpolate(track, time)
		local[bone] = xform
	var out := {}
	var stack: Array[int] = []
	for bone in _skeleton.get_bone_count():
		if _skeleton.get_bone_parent(bone) < 0:
			stack.append(bone)
	while not stack.is_empty():
		var bone: int = stack.pop_back()
		var parent := _skeleton.get_bone_parent(bone)
		out[bone] = (out[parent] if parent >= 0 else Transform3D.IDENTITY) * (local[bone] as Transform3D)
		stack.append_array(_skeleton.get_bone_children(bone))
	return out


## move (hip locomotion, whole body) and move_ads (ADS locomotion) -> ads (Blend2 filtered to the upper body)
## -> speed (TimeScale) -> output.
func _build_tree() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	tree.add_node(&"move", _locomotion_space(IDLE_CLIP, RUN_CLIPS))
	tree.add_node(&"move_ads", _locomotion_space(ADS_IDLE_CLIP, ADS_CLIPS))
	var layer := AnimationNodeBlend2.new()
	layer.filter_enabled = true
	for bone in _upper_body_bones():
		layer.set_filter_path(NodePath("%s:%s" % [_model.get_path_to(_skeleton), bone]), true)
	tree.add_node(&"ads", layer)
	tree.connect_node(&"ads", 0, &"move")
	tree.connect_node(&"ads", 1, &"move_ads")
	tree.add_node(&"speed", AnimationNodeTimeScale.new())
	tree.connect_node(&"speed", 0, &"ads")
	tree.connect_node(&"output", 0, &"speed")
	return tree


func _locomotion_space(idle_clip: StringName, runs: Dictionary) -> AnimationNodeBlendSpace2D:
	var space := AnimationNodeBlendSpace2D.new()
	space.min_space = Vector2(-1.5, -1.5) * RUN_CLIP_SPEED
	space.max_space = Vector2(1.5, 1.5) * RUN_CLIP_SPEED
	space.sync = true  # keep the run cycles in step while blending between directions
	space.add_blend_point(_clip(idle_clip), Vector2.ZERO, -1, &"idle")
	for direction in runs:
		space.add_blend_point(_clip(runs[direction]), direction * RUN_CLIP_SPEED, -1, String(runs[direction]).get_file())
	return space


func _upper_body_bones() -> Array[String]:
	var out: Array[String] = []
	var stack: Array[int] = []
	for bone_name in UPPER_BODY_ROOTS:
		stack.append(_skeleton.find_bone(bone_name))
	while not stack.is_empty():
		var bone: int = stack.pop_back()
		if bone < 0:
			continue
		out.append(_skeleton.get_bone_name(bone))
		stack.append_array(_skeleton.get_bone_children(bone))
	return out


## Whether the player aims down sights (from the snapshot flags); the upper body blends over.
func set_ads(aiming: bool) -> void:
	_ads_target = aiming


func _clip(name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = name
	return node


## Drives the locomotion blend. `local_velocity`: x = right, z = backwards in the player's frame (m/s).
## In the air the step freezes (no jump clips yet), so the pose - and LagComp's hitboxes - keep the run lean.
func update_motion(delta: float, local_velocity: Vector3, on_floor: bool = true) -> void:
	if _model and not _dead:  # crouching squashes the body until there is a crouch clip (matches LagComp.CROUCH_SCALE)
		var squash := LagComp.CROUCH_SCALE if _crouch_target else 1.0
		_model.scale.y = move_toward(_model.scale.y, squash, delta * 4.0)
	if _tree == null or _dead:
		return
	_ads = move_toward(_ads, 1.0 if _ads_target else 0.0, delta / ADS_BLEND_TIME)
	_tree.set("parameters/ads/blend_amount", _ads)
	var horizontal := Vector2(local_velocity.x, -local_velocity.z)
	_blend = _blend.lerp(horizontal, 1.0 - exp(-12.0 * delta))
	var speed := _blend.length()
	# Inside the run ring the blend space scales the step; beyond it play the clips faster.
	var length := maxf(speed, 0.001)
	var position := _blend / maxf(length / RUN_CLIP_SPEED, 1.0)
	_tree.set("parameters/move/blend_position", position)
	_tree.set("parameters/move_ads/blend_position", position)
	_tree.set("parameters/speed/scale", clampf(speed / RUN_CLIP_SPEED, 1.0, 1.5) if on_floor else 0.0)
	_aim.ads = _ads
	# The idle clip stands turned: model_yaw squares it up, fading out as the run clips take over (and while aiming).
	_aim.hips_yaw = deg_to_rad(model_yaw) * (1.0 - clampf(speed / RUN_CLIP_SPEED, 0.0, 1.0)) * (1.0 - _ads)


## Called by HandIK on every skeleton update, after the spine is bent. The weapon is fixed to the right hand
## (`_socket`, see _measure_socket).
func _place_weapon() -> void:
	_ik.targets = {}
	if _dead or _hand_r < 0 or _hand_l < 0:
		return
	var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand_r)
	var weapon := hand * _socket
	weapon.basis = weapon.basis.orthonormalized()
	if _ads > 0.0:
		# Aiming: both hands hold the gun in every ADS clip, so the barrel follows the line between the palms
		# (the right hand's angle on the grip differs from clip to clip).
		var right := _palm(_hand_r, _finger_r)
		var left := _palm(_hand_l, _finger_l)
		var basis := Basis.looking_at((left - right).normalized(), Vector3.UP) * Basis.from_euler(ads_weapon_rotation * (PI / 180.0))
		weapon = weapon.interpolate_with(Transform3D(basis, right - basis * grip), _ads)
	_weapon.global_transform = weapon
	_ik.targets = {"L": {"point": weapon * foregrip_for(_weapon.weapon_index), "fingers": weapon.basis * FirstPersonArms.LEFT_FINGERS,
			"palm": weapon.basis * FirstPersonArms.LEFT_PALM}}


## Barrel direction while aiming, in skeleton space: the line between the palms turned by ads_weapon_rotation
## (the same rule _place_weapon uses).
func _barrel_in_skeleton() -> Vector3:
	if _hand_r < 0 or _hand_l < 0:
		return Vector3.ZERO
	var to_skeleton := _skeleton.global_transform.affine_inverse().basis
	var line := to_skeleton * (_palm(_hand_l, _finger_l) - _palm(_hand_r, _finger_r))
	if line.length() < 0.01:
		return Vector3.ZERO
	var basis := Basis.looking_at(line.normalized(), Vector3.UP) * Basis.from_euler(ads_weapon_rotation * (PI / 180.0))
	return basis * Vector3.FORWARD


## World position of the middle of the palm: halfway from the wrist to the base of the middle finger.
func _palm(hand: int, finger: int) -> Vector3:
	var wrist := _skeleton.get_bone_global_pose(hand).origin
	var knuckle := _skeleton.get_bone_global_pose(finger).origin if finger >= 0 else wrist
	return _skeleton.global_transform * wrist.lerp(knuckle, 0.6)


func set_crouched(crouched: bool) -> void:
	_crouch_target = crouched


## The name tag is drawn over everything, so it is hidden while a wall is between it and the camera.
func _process(delta: float) -> void:
	if _tag == null or _dead:
		return
	_tag_check -= delta
	if _tag_check > 0.0:
		return
	_tag_check = 0.12
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var head := global_position + Vector3.UP * 1.6
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, head, Layers.WORLD)
	_tag.visible = get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func set_weapon(index: int) -> void:
	_weapon.set_weapon(index)


## Pitches the held weapon with the player's aim.
func set_aim_pitch(pitch: float) -> void:
	if _player:
		_aim.pitch = pitch * aim_pitch_scale  # the spine bends; the weapon follows the hands
		return
	_weapon.rotation.x = pitch


func show_shot() -> void:
	_weapon.flash()


func muzzle_global_position() -> Vector3:
	return _weapon.muzzle_global_position()


## Where the left palm holds weapon `index` (view space, full size).
func foregrip_for(index: int) -> Vector3:
	var own := WeaponDB.get_def(index).foregrip if index >= 0 else Vector3.INF
	return foregrip if own == Vector3.INF else own


## Placeholder death pose: the body falls over backwards; no ragdoll yet.
func set_dead(dead: bool) -> void:
	_dead = dead
	_weapon.visible = not dead
	if _tag:
		_tag.visible = not dead
	if _model:
		_model.rotation.x = -PI * 0.5 if dead else 0.0
		_model.position.y = 0.25 if dead else 0.0
		_model.scale.y = 1.0
