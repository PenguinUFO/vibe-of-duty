class_name FirstPersonArms
extends Node3D
## First-person arms of the local player: the same Synty character as the player's third-person body, child of the
## camera, with its head shrunk away and the torso kept square behind the camera so only the arms show. The arms are
## not animated on their own: HandIK bends them onto the viewmodel weapon (right palm on `grip`, left palm on
## `foregrip`, the same points the third-person body uses), so ADS, recoil, sway, reload dip and wall retraction of
## WeaponView carry the hands along. The idle clips only give the fingers and elbows a natural shape.

const EYE_FROM_HEAD := Vector3(0.0, 0.09, 0.1)   # eye position relative to the Head bone (skeleton space, +Z forward)
const BODY_BACK := -0.2   # m (unscaled) the body sits behind the eye: negative = forward. Shoulders end up just in front
                          # of the camera but far below the view, so the arms reach the gun and the chest never shows.
const ARMS_SCALE := 0.85  # a bit bigger than the 0.7 viewmodel weapon: first-person arms are always "too long"
const MAX_STRETCH := 1.2  # the IK may lengthen an arm by up to 20% to reach the foregrip
const STRAIGHTEN: Array[String] = ["Hips", "Spine_01", "Spine_02", "Spine_03", "Neck"]
const HIDDEN: Array[String] = ["Head"]
## How the hands hold the gun, in weapon space (x right, y up, -z forward); shared with the third-person body.
## Fingers run across the part they hold and curl round it (the clips leave them half closed).
const RIGHT_FINGERS := Vector3(-0.2, -0.3, -1.0)  # round the front of the pistol grip...
const RIGHT_PALM := Vector3(-1.0, 0.0, 0.0)       # ...palm against its right side
const LEFT_FINGERS := Vector3(1.0, 0.1, -0.35)    # across under the handguard, curling up its right side...
const LEFT_PALM := Vector3(0.0, 1.0, 0.0)         # ...palm up against its bottom, thumb along the left side
const ANIM_BLEND := 0.15

var _model: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _ik := HandIK.new()
var _weapon: WeaponView
var _visual: PlayerVisual   # holds the grip / foregrip tuning
var _ads := false


func setup(peer_id: int, weapon: WeaponView, visual: PlayerVisual) -> void:
	_weapon = weapon
	_visual = visual
	scale = Vector3.ONE * ARMS_SCALE
	_model = PlayerVisual.make_character(peer_id)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	for mesh in _model.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # floating arms would cast an odd shadow
	# The model faces +Z; turn it to the camera's -Z and put its eye at the camera.
	_model.rotation.y = PI
	var head := _skeleton.find_bone("Head")
	var eye := _rest_global(head).origin + EYE_FROM_HEAD
	_model.position = Vector3(0.0, 0.0, BODY_BACK) - _model.basis * eye
	add_child(_model)

	var library_path := PlayerVisual.ANIM_LIBRARY
	if ResourceLoader.exists(library_path):
		var players := _model.find_children("*", "AnimationPlayer", true, false)
		_player = players[0] if not players.is_empty() else AnimationPlayer.new()
		if players.is_empty():
			_model.add_child(_player)
		_player.root_node = _player.get_path_to(_model)
		_player.add_animation_library(&"mixamo", load(library_path))
		_player.play(PlayerVisual.IDLE_CLIP)
	_ik.straighten = STRAIGHTEN
	_ik.hidden = HIDDEN
	_ik.max_stretch = MAX_STRETCH
	_ik.place_weapon = _hand_targets
	_skeleton.add_child(_ik)


func set_ads(aiming: bool) -> void:
	if aiming == _ads or _player == null:
		return
	_ads = aiming
	_player.play(PlayerVisual.ADS_IDLE_CLIP if aiming else PlayerVisual.IDLE_CLIP, ANIM_BLEND)


func _hand_targets() -> void:
	_ik.targets = {}
	if _weapon == null or not _weapon.visible or _visual == null:
		return
	var xform := _weapon.global_transform
	var s := WeaponView.VIEWMODEL_SCALE  # grip / foregrip are tuned on the full-size third-person weapon
	_ik.targets = {
		"R": {"point": xform * (_visual.grip * s), "fingers": xform.basis * RIGHT_FINGERS, "palm": xform.basis * RIGHT_PALM},
		"L": {"point": xform * (_visual.foregrip_for(_weapon.weapon_index) * s), "fingers": xform.basis * LEFT_FINGERS, "palm": xform.basis * LEFT_PALM},
	}


func _rest_global(bone: int) -> Transform3D:
	var xform := Transform3D.IDENTITY
	while bone >= 0:
		xform = _skeleton.get_bone_rest(bone) * xform
		bone = _skeleton.get_bone_parent(bone)
	return xform
