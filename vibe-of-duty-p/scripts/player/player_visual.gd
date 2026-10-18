class_name PlayerVisual
extends Node3D
## Third-person body of a non-local player: a Synty character prefab playing Mixamo clips retargeted onto its
## skeleton (res://assets/animations/synty_mixamo.res, made by tools/retarget_mixamo.gd), the held weapon and a name tag. Swap CHARACTER_SCENES to change the models; gameplay does not
## depend on anything in here.

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

## How the weapon sits in the hands. Exported so they can be tuned live: run the game, open Remote in the editor's
## Scene dock, select Players/<id>/Visual and edit them in the Inspector; then copy the values here.
@export var grip := Vector3(0.0, 0.02, 0.0)       # point of the weapon (view space: x right, y up, -z forward) that sits in the right palm
@export var model_yaw := 0.0:  # extra turn of the whole body in degrees (+ = to the left), e.g. when a clip stands turned
	set(value):
		model_yaw = value
		if _model:
			_model.rotation.y = MODEL_YAW_OFFSET + deg_to_rad(model_yaw)
@export var aim_pitch_scale := 1.0  # how much of the look pitch the spine follows (1 = all of it)
@export var weapon_rotation := Vector3(0.0, 0.0, 0.0)  # extra turn of the weapon in degrees: x = muzzle up/down, y = left/right, z = roll

var _model: Node3D
var _weapon := WeaponView.new()
var _tag: Label3D
var _dead := false
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _aim := AimModifier.new()
var _hand_r := -1
var _hand_l := -1
var _finger_r := -1
var _finger_l := -1


static func preload_scenes() -> void:
	for path in CHARACTER_SCENES:
		load(path)
	if ResourceLoader.exists(ANIM_LIBRARY):
		load(ANIM_LIBRARY)


func setup(peer_id: int, display_name: String) -> void:
	var scene: PackedScene = load(CHARACTER_SCENES[peer_id % CHARACTER_SCENES.size()])
	_model = scene.instantiate()
	# The prefab root is a physics body with its own collider; the player already has one.
	if _model is CollisionObject3D:
		_model.collision_layer = 0
		_model.collision_mask = 0
	for shape in _model.find_children("*", "CollisionShape3D", true, false):
		shape.queue_free()
	# The prefab carries every character variant and attachment as hidden meshes; drop what is never shown.
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		if not (mesh as MeshInstance3D).visible:
			mesh.get_parent().remove_child(mesh)
			mesh.queue_free()
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	for mesh in _skeleton.find_children("*", "MeshInstance3D", false, false):
		(mesh as MeshInstance3D).skeleton = NodePath("..")  # the prefab saved an empty path: skinning was off
	_model.rotation.y = MODEL_YAW_OFFSET + deg_to_rad(model_yaw)
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
	_player.play(IDLE_CLIP)
	# The weapon follows the hands: grip in the right hand, barrel along the line to the left hand.
	_hand_r = _skeleton.find_bone("Hand_R")
	_hand_l = _skeleton.find_bone("Hand_L")
	_finger_r = _skeleton.find_bone("Finger_01_R")
	_finger_l = _skeleton.find_bone("Finger_01_L")
	_weapon.top_level = true
	_skeleton.add_child(_aim)
	_skeleton.skeleton_updated.connect(_place_weapon)


func _place_weapon() -> void:
	if _dead or _hand_r < 0 or _hand_l < 0:
		return
	var right := _palm(_hand_r, _finger_r)
	var left := _palm(_hand_l, _finger_l)
	var forward := (left - right).normalized()
	var basis := Basis.looking_at(forward, Vector3.UP) * Basis.from_euler(weapon_rotation * (PI / 180.0))
	_weapon.global_transform = Transform3D(basis, right - basis * grip)


## World position of the middle of the palm: halfway from the wrist to the base of the middle finger.
func _palm(hand: int, finger: int) -> Vector3:
	var wrist := _skeleton.get_bone_global_pose(hand).origin
	var knuckle := _skeleton.get_bone_global_pose(finger).origin if finger >= 0 else wrist
	return _skeleton.global_transform * wrist.lerp(knuckle, 0.6)


func set_crouched(crouched: bool) -> void:
	if _player:
		return  # the clips will handle crouching
	# Placeholder until real crouch animations exist.
	if _model and not _dead:
		_model.scale.y = lerpf(_model.scale.y, 0.65 if crouched else 1.0, 0.3)


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
