class_name FirstPersonArms
extends Node3D
## First-person arms of the local player: the mannequin's arm parts (Mannequin.make_arm), child of the camera.
## They are not animated on their own: every frame, after WeaponView has posed the viewmodel (hip / ADS blend,
## recoil, sway, reload dip, wall retraction), both arms reach for the weapon by IK - right palm on the pistol grip,
## left palm under the handguard (WeaponDef.right_hand / left_hand) - so the hands follow the gun.

const SHOULDER_R := Vector3(0.19, -0.27, 0.05)  # camera space; below and just behind the eye, out of view
const SHOULDER_L := Vector3(-0.2, -0.27, 0.05)
const LENGTH_SCALE := 1.3   # first-person arms are always "too long": the gun sits further out than in real life
const THICKNESS := 0.8      # and a bit slimmer, or they fill the screen
const RIGHT_POLE := Vector3(1.0, -1.0, 0.25)
const LEFT_POLE := Vector3(-0.6, -1.0, 0.0)

var _weapon: WeaponView
var _right: Dictionary
var _left: Dictionary


func setup(peer_id: int, weapon: WeaponView) -> void:
	_weapon = weapon
	var accent := Mannequin.color_for(peer_id)
	_right = Mannequin.make_arm(self, "R", accent, LENGTH_SCALE, THICKNESS)
	_left = Mannequin.make_arm(self, "L", accent, LENGTH_SCALE, THICKNESS)
	for mesh in find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # floating arms


## Call after the viewmodel has been posed for this frame.
func pose() -> void:
	if _weapon == null or _weapon.weapon_index < 0:
		return
	var def := WeaponDB.get_def(_weapon.weapon_index)
	var xform := transform.affine_inverse() * _weapon.transform  # both are children of the camera
	var s := WeaponView.VIEWMODEL_SCALE
	var right := Mannequin._view_point(def.right_hand) * s
	var left := Mannequin._view_point(def.left_hand) * s
	Mannequin.pose_arm(_right, SHOULDER_R, xform * right, xform.basis * Mannequin.RIGHT_FINGERS,
			xform.basis * Mannequin.RIGHT_PALM, RIGHT_POLE)
	Mannequin.pose_arm(_left, SHOULDER_L, xform * left, xform.basis * Mannequin.LEFT_FINGERS,
			xform.basis * Mannequin.LEFT_PALM, LEFT_POLE)
